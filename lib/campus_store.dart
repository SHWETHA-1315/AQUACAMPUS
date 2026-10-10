import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'water_math.dart';
import 'firebase_android_config.dart';

// All roles remain centrally assigned by one of the two trusted Admins.
const roleNames = [
  'admin', 'worker', 'warden', 'student', 'teacher',
  'staff', 'canteen', 'gardener', 'driver',
];
const facilityTypes = ['hostel', 'college', 'canteen', 'garden', 'transport'];

/// Site-based roles must be assigned only to facilities they operate.
String? requiredFacilityTypeForRole(String role) => switch (role) {
  'warden' => 'hostel',
  'canteen' => 'canteen',
  'gardener' => 'garden',
  'driver' => 'transport',
  _ => null,
};

bool validRoleFacilityAssignment(
  String role, bool approved, String facilityId, String? facilityType,
) {
  if (!roleNames.contains(role) || role == 'admin') return false;
  if (facilityId.isNotEmpty && facilityType == null) return false;
  if (!approved) return true;
  if (role == 'student' && facilityId.isEmpty) return false;
  final requiredType = requiredFacilityTypeForRole(role);
  return requiredType == null ||
      (facilityId.isNotEmpty && facilityType == requiredType);
}

const activityNames = [
  'Bathing',
  'Laundry',
  'Room cleaning',
  'Cooking',
  'Utensil washing',
  'Garden irrigation',
  'Vehicle washing',
  'Other',
];
const campusId = 'main';
// The only authorized Firebase backend for this AQUACAMPUS deployment.
const aquacampusFirebaseProjectId = 'aquacampus-ed284';
String timestamp() => DateTime.now().toIso8601String();
String friendlyError(Object error) {
  if (error is StateError) return '${error.message}';
  if (error is FirebaseException) {
    switch (error.code) {
      case 'permission-denied':
        return 'Access could not be confirmed. Verify your email and ask Admin to check your account.';
      case 'unavailable':
      case 'network-request-failed':
        return 'Check your internet and try again.';
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'Check your email and password, then try again.';
      case 'email-already-in-use':
        return 'This email already has an account. Tap Sign in or Forgot password.';
      case 'too-many-requests':
      case 'quota-exceeded':
        return 'Firebase temporarily limited email requests. Wait before retrying and ask the project owner to check Authentication limits.';
      case 'operation-not-allowed':
        return 'Email and password sign-in is not enabled in Firebase. Ask the project owner to enable it.';
      case 'invalid-email':
        return 'Enter a valid email address.';
      case 'requires-recent-login':
      case 'user-token-expired':
        return 'Sign out and sign back in, then request verification again.';
      case 'unauthorized-domain':
      case 'invalid-continue-uri':
      case 'unauthorized-continue-uri':
        return 'Firebase email action domain is not authorized. Ask the project owner to check Authentication settings.';
      case 'user-disabled':
        return 'This Firebase account is disabled. Contact the campus Admin.';
      case 'weak-password':
        return 'Use a password with at least 6 characters.';
    }
    return 'Could not complete this step. Please try again.';
  }
  return 'Could not complete this step. Please try again.';
}

class CampusStore extends ChangeNotifier {
  bool loading = true;
  bool cloud = false;
  bool signedIn = false;
  // Incomplete Firebase Auth signups can be restored without Admin privileges.
  bool profileMissing = false;
  // Separate status survives auth-state refreshes and is visible on the
  // verification page even when signup partially succeeded.
  String? verificationDeliveryError;
  DateTime? lastVerificationRequestAcceptedAt;
  DateTime? _nextVerificationRequestAt;
  String? _verificationAccountUid;
  Timer? _emailCooldownTimer;

  bool get canRequestVerificationEmail =>
      _nextVerificationRequestAt == null ||
      !DateTime.now().isBefore(_nextVerificationRequestAt!);

  void _emailRequestAccepted() {
    lastVerificationRequestAcceptedAt = DateTime.now();
    verificationDeliveryError = null;
    _nextVerificationRequestAt =
        lastVerificationRequestAcceptedAt!.add(const Duration(seconds: 60));
    _emailCooldownTimer?.cancel();
    _emailCooldownTimer = Timer(const Duration(seconds: 60), () {
      notifyListeners();
    });
    notifyListeners();
  }

  Future<void> _requestVerificationEmail(User account) async {
    if (!canRequestVerificationEmail) {
      throw StateError(
        'Firebase recently accepted an email request. Wait at least one minute before trying again.',
      );
    }
    try {
      // Successful completion means Firebase accepted a sending request,
      // not that Gmail or a campus mail server delivered the message.
      await account.sendEmailVerification();
      _emailRequestAccepted();
    } on FirebaseException catch (error) {
      verificationDeliveryError =
          '${friendlyError(error)} (Firebase: ${error.code})';
      notifyListeners();
      rethrow;
    } catch (_) {
      verificationDeliveryError =
          'Firebase could not accept this verification request. Check your internet and retry.';
      notifyListeners();
      rethrow;
    }
  }

  String? message;
  Map<String, dynamic> user = {};
  List<Map<String, dynamic>> facilities = [];
  List<Map<String, dynamic>> tanks = [];
  List<Map<String, dynamic>> requests = [];
  List<Map<String, dynamic>> notices = [];
  List<Map<String, dynamic>> sos = [];
  List<Map<String, dynamic>> people = [];
  List<Map<String, dynamic>> dailyUsage = [];
  List<Map<String, dynamic>> tankReadings = [];
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  final Map<String, bool> _streamOnline = <String, bool>{};
  StreamSubscription<dynamic>? _dailyUsageSubscription;
  Timer? _dayRolloverTimer;
  String _currentUsageDay = dateKey();
  int _authGeneration = 0;

  /// Every active feed must have delivered a fresh, server-backed snapshot.
  bool get backendConnected =>
      cloud &&
      signedIn &&
      approved &&
      _streamOnline.isNotEmpty &&
      _streamOnline.values.every((online) => online);
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _profileSubscription;

  String get registeredEmail => FirebaseAuth.instance.currentUser?.email ?? '';
  String get role => '${user['role'] ?? 'student'}';
  String get name => '${user['name'] ?? 'Campus member'}';
  String get uid => '${user['id'] ?? ''}';
  // Email verification is required before any campus data becomes accessible.
  // The Firebase email-verification token is also enforced by Firestore rules.
  bool get approved =>
      user['approved'] == true &&
      (FirebaseAuth.instance.currentUser?.emailVerified ?? false);
  bool get isAdmin => role == 'admin';
  int get adminCount => people.where((person) =>
      person['approved'] == true && person['role'] == 'admin').length;
  bool get isWorker => role == 'worker';
  bool get isStaff => isAdmin || isWorker;
  bool get isWarden => role == 'warden';
  bool get isStudent => role == 'student';
  bool get isTeacher => role == 'teacher';
  bool get isGeneralStaff => role == 'staff';
  bool get isCanteen => role == 'canteen';
  bool get isGardener => role == 'gardener';
  bool get isDriver => role == 'driver';
  bool get isAssignedSiteStaff => isWarden || isCanteen || isGardener || isDriver;
  bool get hasAcademicAccess => isTeacher || isGeneralStaff;

  String get roleSummary => switch (role) {
    'admin' => 'Manage all campus water operations and member roles.',
    'worker' => 'Update tank readings, review water requests and resolve SOS.',
    'warden' => 'Monitor your hostel, requests, rooms and water issues.',
    'student' => 'Request water, report leaks and monitor assigned buildings.',
    'teacher' => 'Manage water needs for academic buildings and the canteen.',
    'staff' => 'Request and track water for college and canteen work.',
    'canteen' => 'Manage your assigned canteen water demand and complaints.',
    'gardener' => 'Request irrigation water and report garden water issues.',
    'driver' => 'Request vehicle wash water and report transport-area leaks.',
    _ => 'Contact campus Admin to assign your role.',
  };
  String get myFacilityId => '${user['facilityId'] ?? ''}';
  String get room => '${user['room'] ?? ''}';

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');
  CollectionReference<Map<String, dynamic>> _col(String key) =>
      _firestore.collection('campuses').doc(campusId).collection(key);

  /// Production-only. No fabricated levels or role-switch login.
  Future<void> initialize() async {
    if (AquaCampusFirebaseConfig.projectId != aquacampusFirebaseProjectId) {
      message = 'Firebase project configuration mismatch.';
      loading = false;
      notifyListeners();
      return;
    }
    try {
      await Firebase.initializeApp(options: AquaCampusFirebaseConfig.options);
      cloud = true;
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: false,
      );
      _authSubscription = FirebaseAuth.instance.authStateChanges().listen(
        _onAuth,
        onError: (Object error) {
          message = 'Login service error: $error';
          notifyListeners();
        },
      );
    } catch (error) {
      message = 'Firebase connection failed: $error';
      cloud = false;
    }
    loading = false;
    notifyListeners();
  }

  /// Gate writes on fresh server-backed data for their required collections.
  /// A failed unrelated feed must not disable another role's valid workflow.
  void _ensureLive({List<String> feeds = const []}) {
    if (!cloud || !signedIn || !approved) {
      throw StateError('Sign in to an approved account to save campus data.');
    }
    final required = feeds.isEmpty ? _streamOnline.keys.toList() : feeds;
    final missing = required.where((key) => _streamOnline[key] != true).toList();
    if (missing.isNotEmpty || required.isEmpty) {
      throw StateError(
        'Live campus data is not ready (${missing.isEmpty ? 'loading' : missing.join(', ')}). '
        'Check your internet, tap Try again, and retry. Nothing was saved.',
      );
    }
  }

  Map<String, dynamic>? facility(String id) {
    for (final item in facilities) {
      if (item['id'] == id) return item;
    }
    return null;
  }

  String facilityName(String id) => '${facility(id)?['name'] ?? 'Unassigned'}';
  double tankCapacity(Map<String, dynamic> item) => WaterMath.capacityLitres(
    shape: '${item['shape']}',
    heightCm: nval(item['heightCm']).toDouble(),
    lengthCm: nval(item['lengthCm']).toDouble(),
    widthCm: nval(item['widthCm']).toDouble(),
    diameterCm: nval(item['diameterCm']).toDouble(),
  );
  double tankAvailable(Map<String, dynamic> item) => WaterMath.availableLitres(
    shape: '${item['shape']}',
    heightCm: nval(item['heightCm']).toDouble(),
    waterHeightCm: nval(item['waterHeightCm']).toDouble(),
    lengthCm: nval(item['lengthCm']).toDouble(),
    widthCm: nval(item['widthCm']).toDouble(),
    diameterCm: nval(item['diameterCm']).toDouble(),
  );
  List<Map<String, dynamic>> tanksFor(String facilityId) =>
      tanks.where((t) => t['facilityId'] == facilityId).toList();

  bool hasCompleteReadingsFor(String facilityId) {
    final assigned = tanksFor(facilityId);
    return assigned.isNotEmpty &&
        assigned.every((tank) => '${tank['lastMeasuredAt'] ?? ''}'.isNotEmpty);
  }

  int missingReadingsFor(String facilityId) =>
      tanksFor(facilityId)
          .where((tank) => '${tank['lastMeasuredAt'] ?? ''}'.isEmpty)
          .length;

  String facilityWaterSummary(String facilityId) {
    final assigned = tanksFor(facilityId);
    if (assigned.isEmpty) return 'No tanks registered';
    final measured = assigned.length - missingReadingsFor(facilityId);
    if (measured == 0) return 'Awaiting manual readings';
    final amount = availableFor(facilityId).toStringAsFixed(1);
    if (measured != assigned.length) {
      return '$amount L (partial: $measured/${assigned.length} tanks)';
    }
    return '$amount L (all ${assigned.length} tanks measured)';
  }

  double availableFor(String id) => tanks
      .where((t) => t['facilityId'] == id)
      .fold(0.0, (total, t) => total + tankAvailable(t));
  double get totalAvailable =>
      tanks.fold(0.0, (total, t) => total + tankAvailable(t));
  int get population => facilities
      .where((f) => f['type'] == 'hostel')
      .fold(0, (a, f) => a + nval(f['occupants']).toInt());
  List<Map<String, dynamic>> get visibleFacilities => facilities.where((f) {
    if (isStaff) return true;
    if (isStudent || isAssignedSiteStaff) return f['id'] == myFacilityId;
    if (hasAcademicAccess) {
      return f['type'] == 'college' || f['type'] == 'canteen';
    }
    return false;
  }).toList();

  // Students can additionally report a leak in college/canteen facilities.
  List<Map<String, dynamic>> get reportableFacilities => facilities.where((f) {
    if (isStaff) return true;
    if (isStudent) {
      return f['id'] == myFacilityId ||
          f['type'] == 'college' ||
          f['type'] == 'canteen';
    }
    return visibleFacilities.any((site) => site['id'] == f['id']);
  }).toList();

  List<Map<String, dynamic>> get visibleRequests =>
      requests.where((r) {
          if (isStaff) return true;
          if (isAssignedSiteStaff) return r['facilityId'] == myFacilityId;
          return r['requestedBy'] == uid;
        }).toList()
        ..sort((a, b) => '${b['createdAt']}'.compareTo('${a['createdAt']}'));
  List<Map<String, dynamic>> get visibleNotices =>
      notices
          .where(
            (n) =>
                '${n['targetFacilityId'] ?? ''}'.isEmpty ||
                isStaff ||
                n['targetFacilityId'] == myFacilityId ||
                (hasAcademicAccess &&
                    ['college', 'canteen']
                        .contains(facility('${n['targetFacilityId']}')?['type'])),
          )
          .toList()
        ..sort((a, b) => '${b['createdAt']}'.compareTo('${a['createdAt']}'));
  List<Map<String, dynamic>> get visibleTanks {
    if (isStaff) return tanks;
    final allowedIds = visibleFacilities.map((f) => f['id']).toSet();
    return tanks.where((t) => allowedIds.contains(t['facilityId'])).toList();
  }

  double dailyUsed(String facilityId) => dailyUsage
      .where((u) => u['facilityId'] == facilityId && u['day'] == dateKey())
      .fold(0.0, (a, u) => a + nval(u['usedLitres']).toDouble());

  /// Refresh data after Android returns from background. The device can
  /// sleep past midnight or lose connectivity while Firebase is suspended.
  void refreshOnResume() {
    if (!signedIn || !cloud) return;
    if (!approved) {
      retrySync();
      return;
    }
    if (_currentUsageDay != dateKey()) {
      _refreshDailyUsageStream();
      _scheduleDayRollover();
    } else if (!backendConnected) {
      retrySync();
    }
  }

  /// Re-establishes live Firestore listeners without changing the signed-in
  /// identity or copying cached/offline data into campus records.
  void retrySync() {
    if (!cloud) {
      message = 'Firebase has not initialized; restart the app.';
      notifyListeners();
      return;
    }
    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null) {
      message = 'Please sign in again to resume live campus data.';
      notifyListeners();
      return;
    }
    message = null;
    _onAuth(authUser);
  }

  Future<void> logout() async {
    if (!cloud) return;
    await FirebaseAuth.instance.signOut();
  }

  /// Request a genuine Firebase password-reset email; no passwords or
  /// verification codes are stored in the campus database.
  bool get emailVerified =>
      FirebaseAuth.instance.currentUser?.emailVerified ?? false;

  /// Recover a missing self-owned Firestore account created by a partial signup.
  /// A transaction never overwrites an existing Admin/member profile.
  Future<void> restoreMissingProfile() async {
    final current = FirebaseAuth.instance.currentUser;
    if (!cloud || current == null || current.email == null) {
      throw StateError('Sign in first to restore your campus profile.');
    }
    final email = current.email!.trim();
    final ref = _users.doc(current.uid);
    await _firestore.runTransaction<void>((tx) async {
      final existing = await tx.get(ref);
      if (existing.exists) return;
      tx.set(ref, {
        'name': current.displayName?.trim().isNotEmpty == true
            ? current.displayName!.trim()
            : email.split('@').first,
        'email': email,
        'role': 'student',
        'facilityId': '',
        'room': '',
        'approved': false,
        'campusId': campusId,
        'createdAt': timestamp(),
      });
    });
    profileMissing = false;
    await _onAuth(FirebaseAuth.instance.currentUser);
  }

  Future<void> resendEmailVerification() async {
    final current = FirebaseAuth.instance.currentUser;
    if (!cloud || current == null) {
      throw StateError('Sign in first to verify your email.');
    }
    if (!canRequestVerificationEmail) {
      throw StateError(
        'Verification request already accepted. Please wait one minute before resending.',
      );
    }
    try {
      // Reload first: clicking Resend after verifying a link should refresh
      // the account instead of sending an unnecessary extra email.
      await current.reload();
      final refreshed = FirebaseAuth.instance.currentUser;
      if (refreshed == null) throw StateError('Please sign in again.');
      if (refreshed.emailVerified) {
        verificationDeliveryError = null;
        await _onAuth(refreshed);
        return;
      }
      await _requestVerificationEmail(refreshed);
    } on FirebaseException catch (error) {
      verificationDeliveryError =
          '${friendlyError(error)} (Firebase: ${error.code})';
      notifyListeners();
      rethrow;
    }
  }

  Future<bool> refreshEmailVerification() async {
    final current = FirebaseAuth.instance.currentUser;
    if (!cloud || current == null) {
      throw StateError('Sign in first.');
    }
    await current.reload();
    final refreshedUser = FirebaseAuth.instance.currentUser;
    final verified = refreshedUser?.emailVerified ?? false;
    if (verified && refreshedUser != null) {
      verificationDeliveryError = null;
      await refreshedUser.getIdToken(true);
      // Start subscriptions now that the Firebase ID token has the verified
      // email claim. Previously denied listeners must not remain stale.
      _onAuth(refreshedUser);
    } else {
      notifyListeners();
    }
    return verified;
  }

  Future<void> sendPasswordReset(String email) async {
    if (!cloud) {
      throw StateError('Campus Firebase authentication is unavailable');
    }
    final address = email.trim();
    if (address.isEmpty || !address.contains('@')) {
      throw StateError('Enter your registered email address first');
    }
    await FirebaseAuth.instance.sendPasswordResetEmail(email: address);
  }

  Future<void> emailLogin(
    String email,
    String password, {
    bool create = false,
    String name = '',
  }) async {
    if (!cloud) throw StateError('Firebase not configured');
    final address = email.trim().toLowerCase();
    if (address.isEmpty || !address.contains('@')) {
      throw StateError('Enter a valid email address.');
    }
    if (create) {
      if (name.trim().length < 2 || name.trim().length > 120) {
        throw StateError('Enter a valid full name (2–120 characters).');
      }
      verificationDeliveryError = null;
      final result = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: address,
        password: password,
      );
      final authUser = result.user;
      if (authUser == null) {
        throw StateError('Firebase did not return an account. Please sign in again.');
      }
      // Do not depend on a successful Firestore profile write to request
      // ownership verification: Firebase Auth signup already succeeded.
      _verificationAccountUid = authUser.uid;
      final registeredAddress = authUser.email ?? address;
      try {
        await _requestVerificationEmail(authUser);
      } catch (_) {
        // Registration still exists. Expose the exact Firebase request error
        // on the pending screen, where the person can resend safely.
      }
      try {
        await _users.doc(authUser.uid).set({
          'name': name.trim(),
          'email': registeredAddress,
          'role': 'student',
          'facilityId': '',
          'room': '',
          'approved': false,
          'campusId': campusId,
          'createdAt': timestamp(),
        });
      } on FirebaseException catch (error) {
        throw StateError(
          'Your Firebase login was created, but the campus profile did not save '
          '(${friendlyError(error)}). Use Restore my account profile; do not register again.',
        );
      }
      notifyListeners();
    } else {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: address,
        password: password,
      );
      // Do not carry an old registration email error into another session.
      verificationDeliveryError = null;
    }
  }

  void _clearCampusData() {
    _streamOnline.clear();
    facilities = [];
    tanks = [];
    requests = [];
    notices = [];
    sos = [];
    people = [];
    dailyUsage = [];
    tankReadings = [];
  }

  void _clearSubscriptions() {
    _dayRolloverTimer?.cancel();
    _dayRolloverTimer = null;
    _dailyUsageSubscription?.cancel();
    _dailyUsageSubscription = null;
    _clearCampusData();
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
    _profileSubscription?.cancel();
    _profileSubscription = null;
  }

  Future<void> _onAuth(User? authUser) async {
    final generation = ++_authGeneration;
    _clearSubscriptions();
    profileMissing = false;
    if (authUser == null) {
      verificationDeliveryError = null;
      lastVerificationRequestAcceptedAt = null;
      _nextVerificationRequestAt = null;
      _verificationAccountUid = null;
      _emailCooldownTimer?.cancel();
      signedIn = false;
      user = {};
      notifyListeners();
      return;
    }
    if (_verificationAccountUid != authUser.uid) {
      // A different signed-in Firebase account must never inherit the
      // previous user's resend cooldown or verification errors.
      _verificationAccountUid = authUser.uid;
      verificationDeliveryError = null;
      lastVerificationRequestAcceptedAt = null;
      _nextVerificationRequestAt = null;
      _emailCooldownTimer?.cancel();
    }
    // Reload verification and refresh the token BEFORE campus listeners start.
    // Firestore checks the token claim, not just the local User flag.
    try {
      await authUser.reload();
      if (generation != _authGeneration) return;
      final current = FirebaseAuth.instance.currentUser;
      if (current == null || current.uid != authUser.uid) return;
      await current.getIdToken(true);
      if (generation != _authGeneration) return;
    } catch (error) {
      if (generation != _authGeneration) return;
      signedIn = true;
      user = {'id': authUser.uid, 'approved': false, 'name': authUser.email};
      message = 'Cannot check your account. Check your internet and try again.';
      debugPrint('Account refresh failed: $error');
      notifyListeners();
      return;
    }
    message = null;
    signedIn = true;
    user = {
      'id': authUser.uid,
      'role': 'student',
      'name': authUser.email ?? 'Member',
      'approved': false,
    };
    notifyListeners();
    _profileSubscription = _users
        .doc(authUser.uid)
        .snapshots()
        .listen(
          (snapshot) {
            if (generation != _authGeneration) return;
            final newData = snapshot.data();
            if (newData == null) {
              profileMissing = true;
              for (final subscription in _subscriptions) {
                subscription.cancel();
              }
              _subscriptions.clear();
              _clearCampusData();
              user = {
                'id': authUser.uid,
                'role': 'student',
                'name': 'Awaiting profile',
                'approved': false,
              };
              notifyListeners();
              return;
            }
            profileMissing = false;
            final oldApproved = approved;
            final oldRole = role;
            final oldFacility = myFacilityId;
            user = {...newData, 'id': snapshot.id};
            if (approved &&
                (!oldApproved ||
                    oldRole != role ||
                    oldFacility != myFacilityId ||
                    _subscriptions.isEmpty)) {
              for (final s in _subscriptions) {
                s.cancel();
              }
              _subscriptions.clear();
              _clearCampusData();
              _subscribeCloud();
            } else if (!approved) {
              for (final s in _subscriptions) {
                s.cancel();
              }
              _subscriptions.clear();
              _clearCampusData();
            }
            notifyListeners();
          },
          onError: (Object e) {
            if (generation != _authGeneration) return;
            for (final subscription in _subscriptions) {
              subscription.cancel();
            }
            _subscriptions.clear();
            _clearCampusData();
            user = {...user, 'approved': false};
            debugPrint('Profile read failed: $e');
            message = 'Cannot load your account. Please try again.';
            notifyListeners();
          },
        );
  }

  StreamSubscription<dynamic> _watch(
    String collection,
    void Function(List<Map<String, dynamic>>) handle, [
    Query<Map<String, dynamic>>? query,
  ]) {
    final generation = _authGeneration;
    final source = query ?? _col(collection);
    _streamOnline[collection] = false;
    final subscription = source
        .snapshots(includeMetadataChanges: true)
        .listen(
          (snapshot) {
            if (generation != _authGeneration) return;
            _streamOnline[collection] =
                !snapshot.metadata.isFromCache &&
                !snapshot.metadata.hasPendingWrites;
            handle(
              snapshot.docs
                  .map((doc) => {...doc.data(), 'id': doc.id})
                  .toList(),
            );
            if (backendConnected) {
              message = null;
            }
            notifyListeners();
          },
          onError: (Object error) {
            if (generation != _authGeneration) return;
            _streamOnline[collection] = false;
            // A failed listener must not leave stale campus records on screen.
            handle([]);
            _connectionError(error, collection: collection);
            notifyListeners();
          },
        );
    _subscriptions.add(subscription);
    return subscription;
  }

  void _refreshDailyUsageStream() {
    _dailyUsageSubscription?.cancel();
    if (_dailyUsageSubscription != null) {
      _subscriptions.remove(_dailyUsageSubscription);
    }
    _currentUsageDay = dateKey();
    dailyUsage = [];
    _streamOnline['dailyUsage'] = false;
    _dailyUsageSubscription = _watch(
      'dailyUsage',
      (data) => dailyUsage = data,
      _col('dailyUsage').where('day', isEqualTo: _currentUsageDay),
    );
    notifyListeners();
  }

  void _scheduleDayRollover() {
    _dayRolloverTimer?.cancel();
    final now = DateTime.now();
    final nextDay = DateTime(now.year, now.month, now.day + 1);
    _dayRolloverTimer = Timer(
      nextDay.difference(now) + const Duration(milliseconds: 50),
      () {
        if (!signedIn || !approved || !cloud) return;
        _refreshDailyUsageStream();
        _scheduleDayRollover();
      },
    );
  }

  void _connectionError(Object error, {String collection = 'campus'}) {
    debugPrint('Campus $collection connection: $error');
    final reason = error is FirebaseException && error.code == 'permission-denied'
        ? 'Permission denied. Confirm Firebase rules, email verification and Admin approval.'
        : error is FirebaseException && error.code == 'failed-precondition'
        ? 'Firestore needs an index for this query. Ask the project owner to check database indexes.'
        : 'Check your internet and Firebase service, then retry.';
    message = 'Cannot sync $collection. $reason';
  }

  void _subscribeCloud() {
    final generation = _authGeneration;
    _watch('facilities', (v) => facilities = v);
    _watch('tanks', (v) => tanks = v);
    // Recent mobile feeds are bounded. Export/long-term history requires
    // explicit paging rather than loading every document at login.
    _watch(
      'notices',
      (v) => notices = v,
      _col('notices').orderBy('createdAt', descending: true).limit(100),
    );
    _refreshDailyUsageStream();
    _scheduleDayRollover();
    Query<Map<String, dynamic>>? requestQuery;
    if (isStudent || hasAcademicAccess) {
      requestQuery = _col('requests').where('requestedBy', isEqualTo: uid);
    }
    if (isAssignedSiteStaff) {
      requestQuery = _col('requests')
          .where('facilityId', isEqualTo: myFacilityId);
    }
    _watch('requests', (v) => requests = v, requestQuery);
    if (isStaff) {
      _watch('sos', (v) => sos = v);
      _watch(
        'tankReadings',
        (v) => tankReadings = v,
        _col('tankReadings').orderBy('measuredAt', descending: true).limit(250),
      );
    }
    if (isAdmin) {
      _streamOnline['people'] = false;
      _subscriptions.add(
        _users
            .where('campusId', isEqualTo: campusId)
            .snapshots(includeMetadataChanges: true)
            .listen(
              (snapshot) {
                if (generation != _authGeneration) return;
                _streamOnline['people'] =
                    !snapshot.metadata.isFromCache &&
                    !snapshot.metadata.hasPendingWrites;
                people = snapshot.docs
                    .map((doc) => {...doc.data(), 'id': doc.id})
                    .toList();
                if (backendConnected) message = null;
                notifyListeners();
              },
              onError: (Object error) {
                if (generation != _authGeneration) return;
                _streamOnline['people'] = false;
                people = [];
                _connectionError(error, collection: 'people');
                notifyListeners();
              },
            ),
      );
    }
  }

  // Unconfigured policies are never filled with fabricated water quantities.
  double lowWaterThreshold(Map<String, dynamic> f) =>
      f['lowWaterThresholdLitres'] == null
      ? 0
      : nval(f['lowWaterThresholdLitres']).toDouble().clamp(0.0, 100000000.0);

  double essentialRate(Map<String, dynamic> f) =>
      f['essentialLitresPerResident'] == null
      ? 0
      : nval(f['essentialLitresPerResident']).toDouble().clamp(0.0, 1000.0);

  List<Map<String, dynamic>> readingHistory(String tankId) {
    final items = tankReadings.where((r) => r['tankId'] == tankId).toList();
    items.sort(
      (a, b) =>
          '${b['measuredAt'] ?? ''}'.compareTo('${a['measuredAt'] ?? ''}'),
    );
    return items;
  }

  Future<void> addFacility({
    required String name,
    required String type,
    required int occupants,
    required int floors,
    required int restrooms,
    required double dailyCapLitres,
    required double lowWaterThresholdLitres,
    required double essentialLitresPerResident,
  }) async {
    if (!isAdmin) throw StateError('Admin access required');
    if (name.trim().isEmpty ||
        name.trim().length > 120 ||
        !facilityTypes.contains(type) ||
        occupants < 0 ||
        floors < 1 ||
        restrooms < 0 ||
        (type == 'hostel' && occupants < 1) ||
        !dailyCapLitres.isFinite ||
        dailyCapLitres < 0 ||
        (type == 'canteen' && dailyCapLitres <= 0) ||
        !lowWaterThresholdLitres.isFinite ||
        lowWaterThresholdLitres < 0 ||
        !essentialLitresPerResident.isFinite ||
        essentialLitresPerResident < 1 ||
        essentialLitresPerResident > 1000) {
      throw StateError('Enter valid facility information and water policies.');
    }
    final item = {
      'name': name.trim(),
      'type': type,
      'occupants': occupants,
      'floors': floors,
      'restrooms': restrooms,
      'dailyCapLitres': dailyCapLitres,
      'lowWaterThresholdLitres': lowWaterThresholdLitres,
      'essentialLitresPerResident': essentialLitresPerResident,
      'createdAt': timestamp(),
    };
    _ensureLive(feeds: ['facilities']);

    await _col('facilities').add(item);
  }

  Future<void> updateFacility(
    String id, {
    required String name,
    required int occupants,
    required int floors,
    required int restrooms,
    required double dailyCapLitres,
    required double lowWaterThresholdLitres,
    required double essentialLitresPerResident,
  }) async {
    if (!isAdmin) throw StateError('Admin access required');
    if (facility(id) == null) throw StateError('Facility not found');
    if (name.trim().isEmpty ||
        floors < 1 ||
        restrooms < 0 ||
        occupants < 0 ||
        !dailyCapLitres.isFinite ||
        dailyCapLitres < 0 ||
        !lowWaterThresholdLitres.isFinite ||
        lowWaterThresholdLitres < 0 ||
        !essentialLitresPerResident.isFinite ||
        essentialLitresPerResident < 1 ||
        essentialLitresPerResident > 1000) {
      throw StateError('Invalid facility settings');
    }
    final changes = <String, dynamic>{
      'name': name.trim(),
      'occupants': occupants,
      'floors': floors,
      'restrooms': restrooms,
      'dailyCapLitres': dailyCapLitres,
      'lowWaterThresholdLitres': lowWaterThresholdLitres,
      'essentialLitresPerResident': essentialLitresPerResident,
      'updatedBy': uid,
      'updatedAt': timestamp(),
    };
    _ensureLive(feeds: ['facilities']);

    await _col('facilities').doc(id).update(changes);
  }

  Future<void> addTank({
    required String name,
    required String facilityId,
    required String shape,
    required double lengthCm,
    required double widthCm,
    required double heightCm,
    required double diameterCm,
  }) async {
    if (!isAdmin) throw StateError('Admin access required');
    if (name.trim().isEmpty ||
        name.trim().length > 120 ||
        facility(facilityId) == null ||
        !['rect', 'cylinder'].contains(shape) ||
        !heightCm.isFinite ||
        heightCm <= 0 ||
        heightCm > 100000 ||
        !lengthCm.isFinite ||
        !widthCm.isFinite ||
        !diameterCm.isFinite ||
        lengthCm < 0 ||
        widthCm < 0 ||
        diameterCm < 0 ||
        (shape == 'rect' && (lengthCm <= 0 || widthCm <= 0)) ||
        (shape == 'cylinder' && diameterCm <= 0)) {
      throw StateError('Enter valid measured tank dimensions.');
    }
    final item = {
      'name': name.trim(),
      'facilityId': facilityId,
      'shape': shape,
      'lengthCm': lengthCm,
      'widthCm': widthCm,
      'heightCm': heightCm,
      'diameterCm': diameterCm,
      'waterHeightCm': 0.0,
      'lastMeasuredAt': '',
      'createdAt': timestamp(),
    };
    _ensureLive(feeds: ['facilities', 'tanks']);

    await _col('tanks').add(item);
  }

  Future<void> recordReading(String tankId, double waterHeightCm) async {
    if (!isStaff) throw StateError('Worker/admin access required');
    final tank = tanks.firstWhere((t) => t['id'] == tankId);
    final height = nval(tank['heightCm']).toDouble();
    if (!waterHeightCm.isFinite ||
        waterHeightCm < 0 ||
        height <= 0 ||
        waterHeightCm > height) {
      throw StateError('Water height must be within tank dimensions');
    }
    final now = timestamp();
    final values = <String, dynamic>{
      'waterHeightCm': waterHeightCm,
      'lastMeasuredAt': now,
      'updatedBy': uid,
    };
    final history = <String, dynamic>{
      'tankId': tankId,
      'facilityId': tank['facilityId'],
      'waterHeightCm': waterHeightCm,
      'estimatedLitres': tankAvailable({...tank, ...values}),
      'measuredAt': now,
      'recordedBy': uid,
    };
    _ensureLive(feeds: ['tanks']);

    final batch = _firestore.batch();
    batch.update(_col('tanks').doc(tankId), values);
    batch.set(_col('tankReadings').doc(), history);
    await batch.commit();
  }

  Future<void> addRequest({
    required String facilityId,
    required String activity,
    required int peopleCount,
    required double litresPerPerson,
    required String notes,
  }) async {
    if (!approved) throw StateError('You are awaiting admin approval');
    if (peopleCount < 1 ||
        peopleCount > 500 ||
        !litresPerPerson.isFinite ||
        litresPerPerson <= 0 ||
        litresPerPerson > 1000 ||
        !activityNames.contains(activity) ||
        notes.length > 2000 ||
        !visibleFacilities.any((f) => f['id'] == facilityId)) {
      throw StateError('Invalid water request or assigned facility.');
    }
    // Facility scope is restricted by UI + Firestore rules.
    final quantity = peopleCount * litresPerPerson;
    final data = {
      'facilityId': facilityId,
      'activity': activity,
      'peopleCount': peopleCount,
      'litresPerPerson': litresPerPerson,
      'quantityLitres': quantity,
      'approvedLitres': 0.0,
      'notes': notes.trim(),
      'requestedBy': uid,
      'requestedByName': name,
      'room': room,
      'status': 'pending',
      'createdAt': timestamp(),
      'approvedBy': '',
      'fulfilledBy': '',
      'fulfilledAt': '',
    };
    _ensureLive(feeds: ['facilities', 'requests']);

    await _col('requests').add(data);
  }

  Future<void> decideRequest(
    String id, {
    required bool approve,
    double approvedLitres = 0,
  }) async {
    if (!isStaff) throw StateError('Worker or admin access required');
    final request = requests.firstWhere((r) => r['id'] == id);
    if (request['status'] != 'pending') {
      throw StateError('Only pending requests may be reviewed');
    }
    if (approve &&
        (!approvedLitres.isFinite ||
            approvedLitres <= 0 ||
            approvedLitres > nval(request['quantityLitres']))) {
      throw StateError('Approval must be > 0 and no more than requested');
    }
    final values = {
      'status': approve ? 'approved' : 'rejected',
      'approvedLitres': approve ? approvedLitres : 0.0,
      'approvedBy': uid,
      'reviewedAt': timestamp(),
    };
    _ensureLive(feeds: ['requests']);

    await _col('requests').doc(id).update(values);
  }

  Future<void> fulfillRequest(String id) async {
    if (!isStaff) throw StateError('Worker or admin access required');
    _ensureLive(feeds: ['requests', 'facilities', 'dailyUsage']);

    final reqRef = _col('requests').doc(id);
    await _firestore.runTransaction((tx) async {
      final reqDoc = await tx.get(reqRef);
      if (!reqDoc.exists) throw StateError('Request not found');
      final r = reqDoc.data()!;
      if (r['status'] != 'approved') {
        throw StateError('Only approved requests can be supplied');
      }
      final amount = nval(r['approvedLitres']).toDouble();
      if (amount <= 0) throw StateError('Invalid allocation');
      final facilityId = '${r['facilityId']}';
      final facRef = _col('facilities').doc(facilityId);
      final facDoc = await tx.get(facRef);
      if (!facDoc.exists) throw StateError('Facility unavailable');
      final fac = facDoc.data()!;
      DocumentReference<Map<String, dynamic>>? usageRef;
      double nextUsed = 0;
      if (fac['type'] == 'canteen') {
        usageRef = _col('dailyUsage').doc('${dateKey()}_$facilityId');
        final usedDoc = await tx.get(usageRef);
        nextUsed = nval(usedDoc.data()?['usedLitres']).toDouble() + amount;
        final cap = nval(fac['dailyCapLitres']).toDouble();
        if (cap <= 0 || nextUsed > cap + 0.0001) {
          throw StateError('Canteen daily supply limit exceeded ($cap L)');
        }
      }
      // All reads above precede writes (Firestore transaction requirement).
      if (usageRef != null) {
        tx.set(usageRef, {
          'facilityId': facilityId,
          'day': dateKey(),
          'usedLitres': nextUsed,
          'updatedBy': uid,
        });
      }
      tx.update(reqRef, {
        'status': 'fulfilled',
        'fulfilledAt': timestamp(),
        'fulfilledBy': uid,
      });
    });
  }

  Future<void> createSOS({
    required String facilityId,
    required int floor,
    required String restroom,
    required String detail,
  }) async {
    if (!approved) throw StateError('Approval required');
    if (!reportableFacilities.any((site) => site['id'] == facilityId) ||
        floor < 0 ||
        restroom.trim().isEmpty ||
        restroom.trim().length > 120 ||
        detail.trim().length < 5 ||
        detail.trim().length > 2000) {
      throw StateError('Provide a valid location and leak description.');
    }
    final data = {
      'facilityId': facilityId,
      'floor': floor,
      'restroom': restroom.trim(),
      'detail': detail.trim(),
      'createdBy': uid,
      'createdByName': name,
      'status': 'open',
      'createdAt': timestamp(),
      'resolvedAt': '',
    };
    _ensureLive(feeds: ['facilities']);

    await _col('sos').add(data);
  }

  Future<void> closeSOS(String id) async {
    if (!isStaff) throw StateError('Only workers/admin can close SOS');
    final values = {
      'status': 'resolved',
      'resolvedAt': timestamp(),
      'resolvedBy': uid,
    };
    _ensureLive(feeds: ['sos']);

    await _col('sos').doc(id).update(values);
  }

  Future<void> postNotice(String targetFacilityId, String text) async {
    if (!isAdmin) throw StateError('Admin access required');
    if (text.trim().isEmpty || text.trim().length > 2000) {
      throw StateError('Enter a notice of 1–2000 characters.');
    }
    if (targetFacilityId.isNotEmpty && facility(targetFacilityId) == null) {
      throw StateError('Selected notice location does not exist.');
    }
    final item = {
      'targetFacilityId': targetFacilityId,
      'message': text.trim(),
      'createdBy': uid,
      'createdAt': timestamp(),
    };
    _ensureLive(feeds: ['notices', 'facilities']);

    await _col('notices').add(item);
  }

  Future<void> changeMember(
    String memberId, {
    required bool approved,
    required String role,
    required String facilityId,
    required String room,
  }) async {
    if (!isAdmin) throw StateError('Admin access required');
    if (memberId == uid) {
      throw StateError('Cannot alter your own Admin permissions.');
    }
    final target = people.where((p) => p['id'] == memberId).toList();
    if (target.isEmpty) {
      throw StateError('Member not loaded. Refresh People & roles and retry.');
    }
    if (target.first['role'] == 'admin') {
      throw StateError('Co-admin accounts are protected. Only the Firebase project owner can change administrators.');
    }
    if (role == 'admin') {
      throw StateError('Admin access requires project-owner activation and a verified account.');
    }
    if (!validRoleFacilityAssignment(
          role, approved, facilityId, facility(facilityId)?['type'] as String?,
        ) ||
        room.length > 80) {
      throw StateError('Invalid member role, room, or facility.');
    }
    final values = {
      'approved': approved,
      'role': role,
      'facilityId': facilityId,
      'room': room,
    };
    _ensureLive(feeds: ['people', 'facilities']);

    await _users.doc(memberId).update(values);
  }

  void clearMessage() {
    message = null;
    notifyListeners();
  }

  @override
  void dispose() {
    ++_authGeneration;
    _emailCooldownTimer?.cancel();
    _clearSubscriptions();
    _authSubscription?.cancel();
    super.dispose();
  }
}
