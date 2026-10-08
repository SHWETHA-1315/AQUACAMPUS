import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'water_math.dart';

const roleNames = ['admin', 'worker', 'warden', 'student', 'teacher'];
const facilityTypes = ['hostel', 'college', 'canteen'];
const activityNames = ['Bathing', 'Laundry', 'Room cleaning', 'Cooking', 'Utensil washing', 'Other'];
const campusId = 'main';
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
  SharedPreferences? _prefs;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _profileSubscription;
  int _counter = 0;

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

  final String _apiKey = const String.fromEnvironment('FIREBASE_API_KEY');
  final String _appId = const String.fromEnvironment('FIREBASE_APP_ID');
  final String _sender = const String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  final String _project = const String.fromEnvironment('FIREBASE_PROJECT_ID');
  String get _memoryKey => 'aquacampus_offline_v2';
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _users => _firestore.collection('users');
  CollectionReference<Map<String, dynamic>> _col(String key) =>
      _firestore.collection('campuses').doc(campusId).collection(key);

  Future<void> initialize() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      cloud = _apiKey.isNotEmpty && _appId.isNotEmpty && _sender.isNotEmpty && _project.isNotEmpty;
      if (cloud) {
        await Firebase.initializeApp(options: FirebaseOptions(
          apiKey: _apiKey, appId: _appId, messagingSenderId: _sender, projectId: _project,
          authDomain: const String.fromEnvironment('FIREBASE_AUTH_DOMAIN'),
        ));
        _authSubscription = FirebaseAuth.instance.authStateChanges().listen(_onAuth, onError: (Object e) {
          message = 'Login service error: $e';
          notifyListeners();
        });
      } else {
        _loadOffline();
      }
    } catch (e) {
      message = 'Startup error: $e';
      cloud = false;
      _loadOffline();
    }
    loading = false;
    notifyListeners();
  }

  void _loadOffline() {
    final saved = _prefs?.getString(_memoryKey);
    if (saved == null) {
      facilities = [
        {'id':'hostel-a','type':'hostel','name':'Hostel A','occupants':100,'floors':3,'restrooms':12,'dailyCapLitres':0},
        {'id':'hostel-b','type':'hostel','name':'Hostel B','occupants':80,'floors':3,'restrooms':9,'dailyCapLitres':0},
        {'id':'college-1','type':'college','name':'Academic Block','occupants':450,'floors':4,'restrooms':16,'dailyCapLitres':0},
        {'id':'canteen-1','type':'canteen','name':'Main Canteen','occupants':0,'floors':1,'restrooms':2,'dailyCapLitres':500},
      ];
      tanks = [
        {'id':'tank-1','name':'Hostel A overhead','facilityId':'hostel-a','shape':'rect','lengthCm':200,'widthCm':150,'heightCm':200,'diameterCm':0,'waterHeightCm':70,'lastMeasuredAt':timestamp()},
        {'id':'tank-2','name':'Hostel B tank','facilityId':'hostel-b','shape':'cylinder','lengthCm':0,'widthCm':0,'heightCm':200,'diameterCm':150,'waterHeightCm':80,'lastMeasuredAt':timestamp()},
        {'id':'tank-3','name':'Academic tank','facilityId':'college-1','shape':'rect','lengthCm':200,'widthCm':200,'heightCm':200,'diameterCm':0,'waterHeightCm':100,'lastMeasuredAt':timestamp()},
        {'id':'tank-4','name':'Canteen tank','facilityId':'canteen-1','shape':'rect','lengthCm':100,'widthCm':100,'heightCm':100,'diameterCm':0,'waterHeightCm':50,'lastMeasuredAt':timestamp()},
      ];
      requests=[]; sos=[]; dailyUsage=[];
      notices=[{'id':'welcome','message':'Welcome to AQUACAMPUS. Tank volumes are estimates based on manual measurements.','targetFacilityId':'','createdAt':timestamp(),'createdBy':'system'}];
      people=[];
      user={}; signedIn=false;
      _persist();
      return;
    }
    try {
      final data=jsonDecode(saved) as Map<String,dynamic>;
      List<Map<String,dynamic>> read(String key) => (data[key] as List? ?? []).map((e) => Map<String,dynamic>.from(e as Map)).toList();
      facilities=read('facilities');tanks=read('tanks');requests=read('requests');notices=read('notices');
      sos=read('sos');people=read('people');dailyUsage=read('dailyUsage');
      user=Map<String,dynamic>.from(data['user'] as Map? ?? {});
      signedIn=data['signedIn']==true;
      _counter=(data['counter'] as num?)?.toInt() ?? 0;
    } catch (e) {
      message='Offline storage could not be loaded: $e';
      user={};signedIn=false;
    }
  }
  void _persist() {
    if (cloud) return;
    _prefs?.setString(_memoryKey, jsonEncode({
      'facilities':facilities,'tanks':tanks,'requests':requests,'notices':notices,
      'sos':sos,'people':people,'dailyUsage':dailyUsage,'user':user,'signedIn':signedIn,'counter':_counter,
    }));
    notifyListeners();
  }
  String _newId() => '${DateTime.now().microsecondsSinceEpoch}-${++_counter}';
  Map<String,dynamic>? facility(String id) {
    for(final item in facilities) {if(item['id']==id)return item;}
    return null;
  }
  String facilityName(String id) => '${facility(id)?['name'] ?? 'Unassigned'}';
  double tankCapacity(Map<String,dynamic> item) => WaterMath.capacityLitres(
    shape:'${item['shape']}',heightCm:nval(item['heightCm']).toDouble(),
    lengthCm:nval(item['lengthCm']).toDouble(),widthCm:nval(item['widthCm']).toDouble(),
    diameterCm:nval(item['diameterCm']).toDouble(),
  );
  double tankAvailable(Map<String,dynamic> item) => WaterMath.availableLitres(
    shape:'${item['shape']}',heightCm:nval(item['heightCm']).toDouble(),
    waterHeightCm:nval(item['waterHeightCm']).toDouble(),
    lengthCm:nval(item['lengthCm']).toDouble(),widthCm:nval(item['widthCm']).toDouble(),
    diameterCm:nval(item['diameterCm']).toDouble(),
  );
  double availableFor(String id) => tanks.where((t)=>t['facilityId']==id).fold(0.0,(sum,t)=>sum+tankAvailable(t));
  double get totalAvailable => tanks.fold(0.0,(sum,t)=>sum+tankAvailable(t));
  int get population => facilities.where((f)=>f['type']=='hostel').fold(0,(a,f)=>a+nval(f['occupants']).toInt());
  List<Map<String,dynamic>> get visibleFacilities => facilities.where((f) {
    if (isStaff) return true;
    if (isStudent || isWarden) return f['id']==myFacilityId;
    if (isTeacher) return f['type']=='college' || f['type']=='canteen';
    return false;
  }).toList();
  List<Map<String,dynamic>> get visibleRequests => requests.where((r) {
    if (isStaff) return true;
    if (isWarden) return r['facilityId']==myFacilityId;
    return r['requestedBy']==uid;
  }).toList()..sort((a,b)=>'${b['createdAt']}'.compareTo('${a['createdAt']}'));
  List<Map<String,dynamic>> get visibleNotices => notices.where((n) =>
    '${n['targetFacilityId']??''}'.isEmpty || isStaff || n['targetFacilityId']==myFacilityId || (isTeacher && facility('${n['targetFacilityId']}')?['type']=='college')
  ).toList()..sort((a,b)=>'${b['createdAt']}'.compareTo('${a['createdAt']}'));
  List<Map<String,dynamic>> get visibleTanks => tanks.where((t)=>isStaff || visibleFacilities.any((f)=>f['id']==t['facilityId'])).toList();
  double dailyUsed(String facilityId) => dailyUsage.where((u)=>u['facilityId']==facilityId && u['day']==dateKey()).fold(0.0,(a,u)=>a+nval(u['usedLitres']).toDouble());

  void loginOffline(String selectedRole, String displayName, {String facilityId='hostel-a', String room='101'}) {
    user={'id':'demo-$selectedRole','name':displayName.trim().isEmpty? 'Demo ${selectedRole.toUpperCase()}':displayName.trim(),
      'role':selectedRole,'facilityId':facilityId,'room':room,'approved':true,'campusId':campusId};
    signedIn=true;
    _persist();
  }
  Future<void> logout() async {
    if (cloud) await FirebaseAuth.instance.signOut();
    else {user={};signedIn=false;_persist();}
  }
  Future<void> emailLogin(String email,String password,{bool create=false,String name=''}) async {
    if(!cloud) throw StateError('Firebase not configured');
    if(create) {
      final result=await FirebaseAuth.instance.createUserWithEmailAndPassword(email:email.trim(),password:password);
      // New members are ALWAYS pending students. Only admin may elevate a role.
      await _users.doc(result.user!.uid).set({'name':name.trim(),'email':email.trim(),'role':'student',
        'facilityId':'','room':'','approved':false,'campusId':campusId,'createdAt':timestamp()});
    } else {
      await FirebaseAuth.instance.signInWithEmailAndPassword(email:email.trim(),password:password);
    }
  }
  void _clearSubscriptions() {
    for(final subscription in _subscriptions){subscription.cancel();}
    _subscriptions.clear();
    _profileSubscription?.cancel();_profileSubscription=null;
  }
  void _onAuth(User? authUser) {
    _clearSubscriptions();
    if(authUser==null) {
      signedIn=false;user={};facilities=[];tanks=[];requests=[];notices=[];sos=[];people=[];dailyUsage=[];
      notifyListeners();return;
    }
    signedIn=true; user={'id':authUser.uid,'role':'student','name':authUser.email ?? 'Member','approved':false};notifyListeners();
    _profileSubscription=_users.doc(authUser.uid).snapshots().listen((snapshot) {
      final newData=snapshot.data();
      if(newData==null) {user={'id':authUser.uid,'role':'student','name':'Awaiting profile','approved':false};notifyListeners();return;}
      final oldApproved=approved;
      final oldRole=role;
      final oldFacility=myFacilityId;
      user={...newData,'id':snapshot.id};notifyListeners();
      if(approved && (!oldApproved || oldRole!=role || oldFacility!=myFacilityId || _subscriptions.isEmpty)){
        for(final s in _subscriptions){s.cancel();}_subscriptions.clear();_subscribeCloud();
      } else if (!approved) {
        for(final s in _subscriptions){s.cancel();}_subscriptions.clear();
        facilities=[];tanks=[];requests=[];notices=[];sos=[];people=[];dailyUsage=[];notifyListeners();
      }
    },onError:(Object e){message='Profile read failed: $e';notifyListeners();});
  }
  void _watch(String collection, void Function(List<Map<String,dynamic>>) handle, [Query<Map<String,dynamic>>? query]) {
    final source=query ?? _col(collection);
    _subscriptions.add(source.snapshots().listen((snapshot) {
      handle(snapshot.docs.map((doc)=>{...doc.data(),'id':doc.id}).toList());
      notifyListeners();
    },onError:(Object e){message='$collection sync failed: $e';notifyListeners();}));
  }
  void _subscribeCloud() {
    _watch('facilities',(v)=>facilities=v);
    _watch('tanks',(v)=>tanks=v);
    _watch('notices',(v)=>notices=v);
    _watch('dailyUsage',(v)=>dailyUsage=v);
    Query<Map<String,dynamic>>? requestQuery;
    if(isStudent || isTeacher) requestQuery=_col('requests').where('requestedBy',isEqualTo:uid);
    if(isWarden) requestQuery=_col('requests').where('facilityId',isEqualTo:myFacilityId);
    _watch('requests',(v)=>requests=v,requestQuery);
    if(isStaff) _watch('sos',(v)=>sos=v);
    if(isAdmin) _subscriptions.add(_users.where('campusId',isEqualTo:campusId).snapshots().listen((snapshot) {
      people=snapshot.docs.map((doc)=>{...doc.data(),'id':doc.id}).toList();notifyListeners();
    },onError:(Object e){message='Member sync failed: $e';notifyListeners();}));
  }

  Future<void> addFacility({required String name,required String type,required int occupants,required int floors,
    required int restrooms,required double dailyCapLitres}) async {
    if(!isAdmin) throw StateError('Admin access required');
    final item={'name':name.trim(),'type':type,'occupants':occupants,'floors':floors,
      'restrooms':restrooms,'dailyCapLitres':dailyCapLitres,'createdAt':timestamp()};
    if(cloud) await _col('facilities').add(item);
    else {facilities.add({...item,'id':_newId()});_persist();}
  }
  Future<void> addTank({required String name,required String facilityId,required String shape,
    required double lengthCm,required double widthCm,required double heightCm,required double diameterCm}) async {
    if(!isAdmin) throw StateError('Admin access required');
    final item={'name':name.trim(),'facilityId':facilityId,'shape':shape,'lengthCm':lengthCm,'widthCm':widthCm,
      'heightCm':heightCm,'diameterCm':diameterCm,'waterHeightCm':0.0,'lastMeasuredAt':'','createdAt':timestamp()};
    if(cloud) await _col('tanks').add(item);
    else {tanks.add({...item,'id':_newId()});_persist();}
  }
  Future<void> recordReading(String tankId,double waterHeightCm) async {
    if(!isStaff) throw StateError('Only water workers and admins can record water levels');
    final tank=tanks.firstWhere((t)=>t['id']==tankId);
    final height=nval(tank['heightCm']).toDouble();
    if(waterHeightCm<0 || waterHeightCm>height) throw StateError('Level must be between 0 and $height cm');
    final values={'waterHeightCm':waterHeightCm,'lastMeasuredAt':timestamp(),'updatedBy':uid};
    if(cloud) await _col('tanks').doc(tankId).update(values);
    else {tank.addAll(values);_persist();}
  }
  Future<void> addRequest({required String facilityId,required String activity,required int peopleCount,
    required double litresPerPerson,required String notes}) async {
    if(!approved) throw StateError('You are awaiting admin approval');
    if(peopleCount<1 || peopleCount>500 || litresPerPerson<=0 || litresPerPerson>1000) throw StateError('Invalid water request');
    // Facility scope is restricted by UI + Firestore rules.
    final quantity=peopleCount*litresPerPerson;
    final data={'facilityId':facilityId,'activity':activity,'peopleCount':peopleCount,
      'litresPerPerson':litresPerPerson,'quantityLitres':quantity,'approvedLitres':0.0,'notes':notes.trim(),
      'requestedBy':uid,'requestedByName':name,'room':room,'status':'pending','createdAt':timestamp(),
      'approvedBy':'','fulfilledBy':'','fulfilledAt':''};
    if(cloud) await _col('requests').add(data);
    else {requests.add({...data,'id':_newId()});_persist();}
  }
  Future<void> decideRequest(String id,{required bool approve,double approvedLitres=0}) async {
    if(!isStaff) throw StateError('Worker or admin access required');
    final request=requests.firstWhere((r)=>r['id']==id);
    if(request['status']!='pending') throw StateError('Only pending requests may be reviewed');
    if(approve && (approvedLitres<=0 || approvedLitres>nval(request['quantityLitres']))) throw StateError('Approval must be > 0 and no more than requested');
    final values={'status':approve?'approved':'rejected','approvedLitres':approve?approvedLitres:0.0,
      'approvedBy':uid,'reviewedAt':timestamp()};
    if(cloud) await _col('requests').doc(id).update(values);
    else {request.addAll(values);_persist();}
  }
  Future<void> fulfillRequest(String id) async {
    if(!isStaff) throw StateError('Worker or admin access required');
    if(cloud){
      final reqRef=_col('requests').doc(id);
      await _firestore.runTransaction((tx) async {
        final reqDoc=await tx.get(reqRef);
        if(!reqDoc.exists) throw StateError('Request not found');
        final r=reqDoc.data()!;
        if(r['status']!='approved') throw StateError('Only approved requests can be supplied');
        final amount=nval(r['approvedLitres']).toDouble();
        if(amount<=0) throw StateError('Invalid allocation');
        final facilityId='${r['facilityId']}';
        final facRef=_col('facilities').doc(facilityId);
        final facDoc=await tx.get(facRef);
        if(!facDoc.exists) throw StateError('Facility unavailable');
        final fac=facDoc.data()!;
        DocumentReference<Map<String,dynamic>>? usageRef;
        double nextUsed=0;
        if(fac['type']=='canteen'){
          usageRef=_col('dailyUsage').doc('${dateKey()}_$facilityId');
          final usedDoc=await tx.get(usageRef);
          nextUsed=nval(usedDoc.data()?['usedLitres']).toDouble()+amount;
          final cap=nval(fac['dailyCapLitres']).toDouble();
          if(cap<=0 || nextUsed>cap+0.0001) throw StateError('Canteen daily supply limit exceeded ($cap L)');
        }
        // All reads above precede writes (Firestore transaction requirement).
        if(usageRef!=null)tx.set(usageRef,{'facilityId':facilityId,'day':dateKey(),'usedLitres':nextUsed,'updatedBy':uid});
        tx.update(reqRef,{'status':'fulfilled','fulfilledAt':timestamp(),'fulfilledBy':uid});
      });
    } else {
      final r=requests.firstWhere((item)=>item['id']==id);
      if(r['status']!='approved') throw StateError('Only approved requests can be supplied');
      final amount=nval(r['approvedLitres']).toDouble();
      final facilityId='${r['facilityId']}';
      final fac=facility(facilityId);
      if(fac?['type']=='canteen'){
        final cap=nval(fac?['dailyCapLitres']).toDouble();
        if(cap<=0 || dailyUsed(facilityId)+amount>cap+0.0001) throw StateError('Canteen daily supply limit exceeded ($cap L)');
        final day=dateKey();
        final existing=dailyUsage.where((u)=>u['facilityId']==facilityId && u['day']==day).toList();
        if(existing.isEmpty)dailyUsage.add({'id':'${day}_$facilityId','facilityId':facilityId,'day':day,'usedLitres':amount});
        else existing.first['usedLitres']=nval(existing.first['usedLitres']).toDouble()+amount;
      }
      r.addAll({'status':'fulfilled','fulfilledAt':timestamp(),'fulfilledBy':uid});
      _persist();
    }
  }
  Future<void> createSOS({required String facilityId,required int floor,required String restroom,required String detail}) async {
    if(!approved) throw StateError('Approval required');
    final data={'facilityId':facilityId,'floor':floor,'restroom':restroom.trim(),'detail':detail.trim(),
      'createdBy':uid,'createdByName':name,'status':'open','createdAt':timestamp(),'resolvedAt':''};
    if(cloud) await _col('sos').add(data);
    else {sos.add({...data,'id':_newId()});_persist();}
  }
  Future<void> closeSOS(String id) async {
    if(!isStaff) throw StateError('Only workers/admin can close SOS');
    final values={'status':'resolved','resolvedAt':timestamp(),'resolvedBy':uid};
    if(cloud) await _col('sos').doc(id).update(values);
    else {sos.firstWhere((a)=>a['id']==id).addAll(values);_persist();}
  }
  Future<void> postNotice(String targetFacilityId,String text) async {
    if(!isAdmin)throw StateError('Admin access required');
    if(text.trim().isEmpty)throw StateError('Enter a message');
    final item={'targetFacilityId':targetFacilityId,'message':text.trim(),'createdBy':uid,'createdAt':timestamp()};
    if(cloud) await _col('notices').add(item);
    else {notices.add({...item,'id':_newId()});_persist();}
  }
  Future<void> changeMember(String memberId,{required bool approved,required String role,
    required String facilityId,required String room}) async {
    if(!isAdmin)throw StateError('Admin access required');
    final values={'approved':approved,'role':role,'facilityId':facilityId,'room':room};
    if(cloud) await _users.doc(memberId).update(values);
    else {
      final member=people.firstWhere((u)=>u['id']==memberId);
      member.addAll(values);_persist();
    }
  }
  void clearMessage(){message=null;notifyListeners();}
  @override
  void dispose() {
    _clearSubscriptions();_authSubscription?.cancel();super.dispose();
  }
}
