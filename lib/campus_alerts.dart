import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'campus_store.dart';

/// Public notification text deliberately contains NO names, emails, room
/// numbers, quantities, or unapproved incident content.
class CampusAlertEntry {
  const CampusAlertEntry(this.id, this.title, this.description, this.at);
  final String id, title, description;
  final DateTime at;

  Map<String, dynamic> toJson() =>
      {'id': id, 'title': title, 'description': description,
       'at': at.toIso8601String()};

  factory CampusAlertEntry.fromJson(Map<String, dynamic> map) =>
      CampusAlertEntry('${map['id']}', '${map['title']}',
          '${map['description']}',
          DateTime.tryParse('${map['at']}') ?? DateTime.now());
}

@pragma('vm:entry-point')
Future<void> aquaBackgroundMessage(RemoteMessage message) async {
  // Notification payloads are displayed by Android in the background.
  // Never cache payloads or reveal confidential Firestore details here.
}

/// Per-user local alert history, real-time foreground alerts, and FCM token
/// registration. FCM sender is a *trusted* backend, NEVER the Android APK.
class CampusAlertCenter extends ChangeNotifier {
  CampusAlertCenter._();
  static final CampusAlertCenter instance = CampusAlertCenter._();
  static const native = MethodChannel('aquacampus/alerts');
  CampusStore? _store;
  String _uid = '';
  bool _baseline = false;
  bool _working = false;
  final Set<String> _sirenStarted = {};
  final Map<String, String> _requests = {};
  final Map<String, String> _notices = {};
  final Map<String, String> _tanks = {};
  final Map<String, String> _incidents = {};
  final List<CampusAlertEntry> _history = [];
  StreamSubscription<String>? _tokenRefresh;
  StreamSubscription<RemoteMessage>? _foreground;
  StreamSubscription<RemoteMessage>? _opened;
  String? _deviceId;

  List<CampusAlertEntry> get history => List.unmodifiable(_history);
  bool get isWorker => _store?.isWorker == true;

  Future<void> bind(CampusStore store) async {
    if (identical(_store, store) && _uid == store.uid) return;
    await unbind();
    if (!store.approved || store.uid.isEmpty) return;
    _store = store;
    _uid = store.uid;
    _baseline = false;
    store.addListener(_sync);
    final prefs = await SharedPreferences.getInstance();
    if (_uid != store.uid) return;
    _history.clear();
    for (final raw in prefs.getStringList('aqua-alerts-$_uid') ?? <String>[]) {
      try {
        _history.add(CampusAlertEntry.fromJson(
            jsonDecode(raw) as Map<String, dynamic>));
      } catch (_) {
        // Ignore a malformed private on-device notification history.
      }
    }
    notifyListeners();
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true);
      // Separate native channel controls siren independent of FCM. This
      // optional subscription does not mark push delivery as operational.
      _foreground = FirebaseMessaging.onMessage.listen((message) {
        if (_uid != store.uid) return;
        final type = message.data['kind'] ?? 'update';
        _record('push:${message.messageId ?? DateTime.now().microsecondsSinceEpoch}',
            'Campus update',
            type == 'sos' ? 'A water emergency needs worker attention.' :
            'An update is available in your AquaCampus portal.');
      });
      _opened = FirebaseMessaging.onMessageOpenedApp.listen((_) {
        if (_uid == store.uid) store.refreshOnResume();
      });
      _tokenRefresh = messaging.onTokenRefresh.listen((token) {
        _saveDeviceToken(token);
      });
      final token = await messaging.getToken();
      if (token != null) await _saveDeviceToken(token);
    } catch (error) {
      debugPrint('Push registration unavailable: ${error.runtimeType}');
    }
    _sync();
  }

  Future<void> _saveDeviceToken(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (_uid.isEmpty || user == null || user.uid != _uid ||
        !(_store?.approved ?? false)) return;
    final prefs = await SharedPreferences.getInstance();
    _deviceId ??= prefs.getString('aqua-device-id');
    if (_deviceId == null) {
      final random = Random.secure();
      _deviceId = List.generate(20, (_) => random.nextInt(16)
          .toRadixString(16)).join();
      await prefs.setString('aqua-device-id', _deviceId!);
    }
    try {
      await FirebaseFirestore.instance.collection('users').doc(_uid)
          .collection('devices').doc(_deviceId).set({
        'token': token,
        'platform': 'android',
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (error) {
      debugPrint('Device token sync unavailable: ${error.runtimeType}');
    }
  }

  void _sync() {
    final store = _store;
    if (store == null || !store.approved || store.uid != _uid ||
        !store.backendConnected || _working) return;
    _working = true;
    try {
      final currentRequests = <String, String>{
        for (final e in store.visibleRequests)
          '${e['id']}': '${e['status']}',
      };
      final currentNotices = <String, String>{
        for (final e in store.visibleNotices)
          '${e['id']}': '${e['createdAt']}',
      };
      final currentTanks = <String, String>{
        for (final e in store.visibleTanks)
          '${e['id']}': '${e['lastMeasuredAt'] ?? ''}',
      };
      final currentIncidents = <String, String>{
        for (final e in store.sos)
          '${e['id']}': '${e['status']}',
      };
      if (_baseline) {
        for (final e in currentRequests.entries) {
          if (_requests[e.key] == null && store.isStaff) {
            _record('request:${e.key}', 'New water request',
                'A request is waiting for a water worker or Admin.');
          } else if (_requests[e.key] != null &&
              _requests[e.key] != e.value) {
            _record('request:${e.key}:${e.value}', 'Water request updated',
                'Check the status in your private request list.');
          }
        }
        for (final e in currentNotices.entries) {
          if (!_notices.containsKey(e.key)) {
            _record('notice:${e.key}', 'Campus notice',
                'A notice for your campus or assigned location is available.');
          }
        }
        for (final e in currentTanks.entries) {
          if (_tanks[e.key] != null && _tanks[e.key] != e.value &&
              e.value.isNotEmpty) {
            _record('tank:${e.key}:${e.value}', 'Tank level update',
                'A water-level measurement changed for an authorized site.');
          }
        }
        for (final e in currentIncidents.entries) {
          if (!_incidents.containsKey(e.key) && e.value == 'open') {
            _record('sos:${e.key}', 'Water SOS',
                store.isWorker ? 'Siren active until you silence it.' :
                'Your water emergency report is recorded.');
          }
        }
      }
      _requests..clear()..addAll(currentRequests);
      _notices..clear()..addAll(currentNotices);
      _tanks..clear()..addAll(currentTanks);
      _incidents..clear()..addAll(currentIncidents);
      _baseline = true;
      // An unresolved alarm is urgent even when it was created before
      // opening this app. Android remembers which SOS ids this worker muted.
      if (store.isWorker) {
        for (final e in currentIncidents.entries) {
          if (e.value != 'open' || !_sirenStarted.add(e.key)) continue;
          native.invokeMethod<void>('startSiren',
              {'uid': _uid, 'sosId': e.key}).catchError((Object error) {
            debugPrint('Siren service unavailable: ${error.runtimeType}');
          });
        }
      }
    } finally {
      _working = false;
    }
  }

  Future<void> _record(String id, String title, String description) async {
    if (_uid.isEmpty || _history.any((a) => a.id == id)) return;
    final savedUid = _uid;
    _history.insert(0, CampusAlertEntry(id, title, description, DateTime.now()));
    if (_history.length > 100) _history.removeRange(100, _history.length);
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      if (savedUid != _uid) return;
      await prefs.setStringList('aqua-alerts-$_uid',
          _history.map((e) => jsonEncode(e.toJson())).toList());
      await native.invokeMethod<void>('showUpdate',
          {'title': title, 'description': description, 'notificationId':
           id.hashCode & 0x7fffffff});
    } catch (error) {
      debugPrint('Local notification unavailable: ${error.runtimeType}');
    }
  }

  /// Only an authenticated worker can make this explicit local action.
  /// Future SOS events start the siren again; clearing the screen does NOT
  /// silently disable all alarms.
  Future<void> silenceWorkerSiren() async {
    if (!isWorker || _uid.isEmpty) {
      throw StateError('Only a water worker can silence their own SOS siren.');
    }
    await native.invokeMethod<void>('silenceSiren', {'uid': _uid});
    _record('silence:${DateTime.now().microsecondsSinceEpoch}',
        'Siren silenced', 'This phone is muted for already received SOS alerts.');
  }

  Future<void> unbind() async {
    _store?.removeListener(_sync);
    _store = null;
    _uid = '';
    _baseline = false;
    _sirenStarted.clear();
    _requests.clear();
    _notices.clear();
    _tanks.clear();
    _incidents.clear();
    _history.clear();
    await _tokenRefresh?.cancel();
    await _foreground?.cancel();
    await _opened?.cancel();
    _tokenRefresh = null;
    _foreground = null;
    _opened = null;
    notifyListeners();
  }
}
