import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'water_math.dart';
import 'firebase_android_config.dart';

const roleNames = ['admin', 'worker', 'warden', 'student', 'teacher'];
const facilityTypes = ['hostel', 'college', 'canteen'];
const activityNames = [
  'Bathing',
  'Laundry',
  'Room cleaning',
  'Cooking',
  'Utensil washing',
  'Other'
];
const campusId = 'main';
// The only authorized Firebase backend for this AQUACAMPUS deployment.
const aquacampusFirebaseProjectId = 'aquacampus-ed284';
String timestamp() => DateTime.now().toIso8601String();

class CampusStore extends ChangeNotifier {
  bool loading = true;
  bool cloud = false;
  bool signedIn = false;
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

  /// Every active feed must have delivered a fresh, server-backed snapshot.
  bool get backendConnected =>
      cloud && signedIn && approved && _streamOnline.isNotEmpty &&
      _streamOnline.values.every((online) => online);
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      _profileSubscription;

  String get role => '${user['role'] ?? 'student'}';
  String get name => '${user['name'] ?? 'Campus member'}';
  String get uid => '${user['id'] ?? ''}';
  bool get approved => user['approved'] == true;
  bool get isAdmin => role == 'admin';
  bool get isWorker => role == 'worker';
  bool get isStaff => isAdmin || isWorker;
  bool get isWarden => role == 'warden';
  bool get isStudent => role == 'student';
  bool get isTeacher => role == 'teacher';
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
      FirebaseFirestore.instance.settings =
          const Settings(persistenceEnabled: false);
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

  /// Block operations if any required cloud collection is offline or stale.
  void _ensureLive() {
    if (!cloud || !backendConnected) {
      throw StateError('Live water database is unavailable. Nothing saved.');
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
        if (isStudent || isWarden) return f['id'] == myFacilityId;
        if (isTeacher) return f['type'] == 'college' || f['type'] == 'canteen';
        return false;
      }).toList();
  List<Map<String, dynamic>> get visibleRequests => requests.where((r) {
        if (isStaff) return true;
        if (isWarden) return r['facilityId'] == myFacilityId;
        return r['requestedBy'] == uid;
      }).toList()
        ..sort((a, b) => '${b['createdAt']}'.compareTo('${a['createdAt']}'));
  List<Map<String, dynamic>> get visibleNotices => notices
      .where((n) =>
          '${n['targetFacilityId'] ?? ''}'.isEmpty ||
          isStaff ||
          n['targetFacilityId'] == myFacilityId ||
          (isTeacher &&
              facility('${n['targetFacilityId']}')?['type'] == 'college'))
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

  Future<void> resendEmailVerification() async {
    final current = FirebaseAuth.instance.currentUser;
    if (!cloud || current == null) {
      throw StateError('Sign in first to verify your email.');
    }
    if (current.emailVerified) return;
    await current.sendEmailVerification();
  }

  Future<bool> refreshEmailVerification() async {
    final current = FirebaseAuth.instance.currentUser;
    if (!cloud || current == null) {
      throw StateError('Sign in first.');
    }
    await current.reload();
    final verified = FirebaseAuth.instance.currentUser?.emailVerified ?? false;
    notifyListeners();
    return verified;
  }

  Future<void> sendPasswordReset(String email) async {
    if (!cloud) throw StateError('Campus Firebase authentication is unavailable');
    final address = email.trim();
    if (address.isEmpty || !address.contains('@')) {
      throw StateError('Enter your registered email address first');
    }
    await FirebaseAuth.instance.sendPasswordResetEmail(email: address);
  }

  Future<void> emailLogin(String email, String password,
      {bool create = false, String name = ''}) async {
    if (!cloud) throw StateError('Firebase not configured');
    if (create) {
      if (name.trim().length < 2 || name.trim().length > 120) {
        throw StateError('Enter a valid full name (2–120 characters).');
      }
      final result = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email.trim(), password: password);
      // New members are ALWAYS pending students. Only admin may elevate a role.
      await _users.doc(result.user!.uid).set({
        'name': name.trim(),
        'email': email.trim(),
        'role': 'student',
        'facilityId': '',
        'room': '',
        'approved': false,
        'campusId': campusId,
        'createdAt': timestamp()
      });
      // Verify ownership of the email before a trusted Firebase administrator
      // can approve this account. Verification is a real Firebase email.
      try {
        await result.user!.sendEmailVerification();
      } on FirebaseAuthException catch (error) {
        // Account and Firestore profile already exist; do not falsely report
        // the registration as failed. User may resend from Pending screen.
        message = 'Account created. Email verification not sent: ${error.message}';
        notifyListeners();
      }
    } else {
      await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email.trim(), password: password);
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

  void _onAuth(User? authUser) {
    _clearSubscriptions();
    if (authUser == null) {
      signedIn = false;
      user = {};
      notifyListeners();
      return;
    }
    signedIn = true;
    user = {
      'id': authUser.uid,
      'role': 'student',
      'name': authUser.email ?? 'Member',
      'approved': false
    };
    notifyListeners();
    _profileSubscription =
        _users.doc(authUser.uid).snapshots().listen((snapshot) {
      final newData = snapshot.data();
      if (newData == null) {
        for (final subscription in _subscriptions) {
          subscription.cancel();
        }
        _subscriptions.clear();
        _clearCampusData();
        user = {
          'id': authUser.uid,
          'role': 'student',
          'name': 'Awaiting profile',
          'approved': false
        };
        notifyListeners();
        return;
      }
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
    }, onError: (Object e) {
      for (final subscription in _subscriptions) {
        subscription.cancel();
      }
      _subscriptions.clear();
      _clearCampusData();
      user = {...user, 'approved': false};
      message = 'Profile read failed: $e';
      notifyListeners();
    });
  }

  StreamSubscription<dynamic> _watch(
      String collection, void Function(List<Map<String, dynamic>>) handle,
      [Query<Map<String, dynamic>>? query]) {
    final source = query ?? _col(collection);
    _streamOnline[collection] = false;
    final subscription = source.snapshots(includeMetadataChanges: true).listen(
      (snapshot) {
        _streamOnline[collection] =
            !snapshot.metadata.isFromCache && !snapshot.metadata.hasPendingWrites;
        handle(snapshot.docs
            .map((doc) => {...doc.data(), 'id': doc.id}).toList());
        if (message?.startsWith('$collection sync failed:') ?? false) {
          message = null;
        }
        notifyListeners();
      },
      onError: (Object error) {
        _streamOnline[collection] = false;
        // A failed listener must not leave stale campus records on screen.
        handle([]);
        message = '$collection sync failed: $error';
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
        nextDay.difference(now) + const Duration(milliseconds: 50), () {
      if (!signedIn || !approved || !cloud) return;
      _refreshDailyUsageStream();
      _scheduleDayRollover();
    });
  }

  void _subscribeCloud() {
    _watch('facilities', (v) => facilities = v);
    _watch('tanks', (v) => tanks = v);
    // Recent mobile feeds are bounded. Export/long-term history requires
    // explicit paging rather than loading every document at login.
    _watch('notices', (v) => notices = v,
        _col('notices').orderBy('createdAt', descending: true).limit(100));
    _refreshDailyUsageStream();
    _scheduleDayRollover();
    Query<Map<String, dynamic>>? requestQuery;
    if (isStudent || isTeacher) {
      requestQuery = _col('requests').where('requestedBy', isEqualTo: uid);
    }
    if (isWarden) {
      requestQuery =
          _col('requests').where('facilityId', isEqualTo: myFacilityId);
    }
    _watch('requests', (v) => requests = v, requestQuery);
    if (isStaff) {
      _watch('sos', (v) => sos = v);
      _watch('tankReadings', (v) => tankReadings = v,
          _col('tankReadings').orderBy('measuredAt', descending: true).limit(250));
    }
    if (isAdmin) {
      _streamOnline['people'] = false;
      _subscriptions.add(_users
          .where('campusId', isEqualTo: campusId)
          .snapshots(includeMetadataChanges: true)
          .listen((snapshot) {
        _streamOnline['people'] =
            !snapshot.metadata.isFromCache && !snapshot.metadata.hasPendingWrites;
        people =
            snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList();
        notifyListeners();
      }, onError: (Object error) {
        _streamOnline['people'] = false;
        people = [];
        message = 'Member sync failed: $error';
        notifyListeners();
      }));
    }
  }

  // Unconfigured policies are never filled with fabricated water quantities.
  double lowWaterThreshold(Map<String, dynamic> f) =>
      f['lowWaterThresholdLitres'] == null ? 0
      : nval(f['lowWaterThresholdLitres']).toDouble().clamp(0.0, 100000000.0);

  double essentialRate(Map<String, dynamic> f) =>
      f['essentialLitresPerResident'] == null ? 0
      : nval(f['essentialLitresPerResident']).toDouble().clamp(0.0, 1000.0);

  List<Map<String, dynamic>> readingHistory(String tankId) {
    final items = tankReadings.where((r) => r['tankId'] == tankId).toList();
    items.sort((a, b) => '${b['measuredAt'] ?? ''}'.compareTo('${a['measuredAt'] ?? ''}'));
    return items;
  }

  Future<void> addFacility(
      {required String name,
      required String type,
      required int occupants,
      required int floors,
      required int restrooms,
      required double dailyCapLitres,
      required double lowWaterThresholdLitres,
      required double essentialLitresPerResident}) async {
    if (!isAdmin) throw StateError('Admin access required');
    if (name.trim().isEmpty || name.trim().length > 120 ||
        !facilityTypes.contains(type) ||
        occupants < 0 || floors < 1 || restrooms < 0 ||
        (type == 'hostel' && occupants < 1) ||
        !dailyCapLitres.isFinite || dailyCapLitres < 0 ||
        (type == 'canteen' && dailyCapLitres <= 0) ||
        !lowWaterThresholdLitres.isFinite || lowWaterThresholdLitres < 0 ||
        !essentialLitresPerResident.isFinite ||
        essentialLitresPerResident < 1 || essentialLitresPerResident > 1000) {
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
      'createdAt': timestamp()
    };
    _ensureLive();

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
    if (name.trim().isEmpty || floors < 1 || restrooms < 0 ||
        occupants < 0 || !dailyCapLitres.isFinite || dailyCapLitres < 0 ||
        !lowWaterThresholdLitres.isFinite || lowWaterThresholdLitres < 0 ||
        !essentialLitresPerResident.isFinite ||
        essentialLitresPerResident < 1 || essentialLitresPerResident > 1000) {
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
    _ensureLive();

      await _col('facilities').doc(id).update(changes);
    
  }

  Future<void> addTank(
      {required String name,
      required String facilityId,
      required String shape,
      required double lengthCm,
      required double widthCm,
      required double heightCm,
      required double diameterCm}) async {
    if (!isAdmin) throw StateError('Admin access required');
    if (name.trim().isEmpty || name.trim().length > 120 ||
        facility(facilityId) == null ||
        !['rect', 'cylinder'].contains(shape) ||
        !heightCm.isFinite || heightCm <= 0 || heightCm > 100000 ||
        !lengthCm.isFinite || !widthCm.isFinite || !diameterCm.isFinite ||
        lengthCm < 0 || widthCm < 0 || diameterCm < 0 ||
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
      'createdAt': timestamp()
    };
    _ensureLive();

      await _col('tanks').add(item);
    
  }

  Future<void> recordReading(String tankId, double waterHeightCm) async {
    if (!isStaff) throw StateError('Worker/admin access required');
    final tank = tanks.firstWhere((t) => t['id'] == tankId);
    final height = nval(tank['heightCm']).toDouble();
    if (!waterHeightCm.isFinite || waterHeightCm < 0 ||
        height <= 0 || waterHeightCm > height) {
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
    _ensureLive();

      final batch = _firestore.batch();
      batch.update(_col('tanks').doc(tankId), values);
      batch.set(_col('tankReadings').doc(), history);
      await batch.commit();
    
  }

  Future<void> addRequest(
      {required String facilityId,
      required String activity,
      required int peopleCount,
      required double litresPerPerson,
      required String notes}) async {
    if (!approved) throw StateError('You are awaiting admin approval');
    if (peopleCount < 1 || peopleCount > 500 ||
        !litresPerPerson.isFinite || litresPerPerson <= 0 ||
        litresPerPerson > 1000 || !activityNames.contains(activity) ||
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
      'fulfilledAt': ''
    };
    _ensureLive();

      await _col('requests').add(data);
    
  }

  Future<void> decideRequest(String id,
      {required bool approve, double approvedLitres = 0}) async {
    if (!isStaff) throw StateError('Worker or admin access required');
    final request = requests.firstWhere((r) => r['id'] == id);
    if (request['status'] != 'pending') {
      throw StateError('Only pending requests may be reviewed');
    }
    if (approve &&
        (!approvedLitres.isFinite || approvedLitres <= 0 ||
            approvedLitres > nval(request['quantityLitres']))) {
      throw StateError('Approval must be > 0 and no more than requested');
    }
    final values = {
      'status': approve ? 'approved' : 'rejected',
      'approvedLitres': approve ? approvedLitres : 0.0,
      'approvedBy': uid,
      'reviewedAt': timestamp()
    };
    _ensureLive();

      await _col('requests').doc(id).update(values);
    
  }

  Future<void> fulfillRequest(String id) async {
    if (!isStaff) throw StateError('Worker or admin access required');
    _ensureLive();

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
            'updatedBy': uid
          });
        }
        tx.update(reqRef, {
          'status': 'fulfilled',
          'fulfilledAt': timestamp(),
          'fulfilledBy': uid
        });
      });
    
  }

  Future<void> createSOS(
      {required String facilityId,
      required int floor,
      required String restroom,
      required String detail}) async {
    if (!approved) throw StateError('Approval required');
    if (facility(facilityId) == null || floor < 0 ||
        restroom.trim().isEmpty || restroom.trim().length > 120 ||
        detail.trim().length < 5 || detail.trim().length > 2000) {
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
      'resolvedAt': ''
    };
    _ensureLive();

      await _col('sos').add(data);
    
  }

  Future<void> closeSOS(String id) async {
    if (!isStaff) throw StateError('Only workers/admin can close SOS');
    final values = {
      'status': 'resolved',
      'resolvedAt': timestamp(),
      'resolvedBy': uid
    };
    _ensureLive();

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
      'createdAt': timestamp()
    };
    _ensureLive();

      await _col('notices').add(item);
    
  }

  Future<void> changeMember(String memberId,
      {required bool approved,
      required String role,
      required String facilityId,
      required String room}) async {
    if (!isAdmin) throw StateError('Admin access required');
    if (memberId == uid) {
      throw StateError('Cannot alter your own Admin permissions.');
    }
    if (!roleNames.contains(role) || room.length > 80 ||
        (facilityId.isNotEmpty && facility(facilityId) == null)) {
      throw StateError('Invalid member role, room, or facility.');
    }
    final values = {
      'approved': approved,
      'role': role,
      'facilityId': facilityId,
      'room': room
    };
    _ensureLive();

      await _users.doc(memberId).update(values);
    
  }

  void clearMessage() {
    message = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _clearSubscriptions();
    _authSubscription?.cancel();
    super.dispose();
  }
}
