import 'package:aquacampus/campus_store.dart';
import 'package:aquacampus/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class RoleStore extends CampusStore {
  RoleStore(String selectedRole, String site) {
    user = {
      'id': 'member-1',
      'name': 'Role Test',
      'role': selectedRole,
      'facilityId': site,
      'approved': true,
    };
    facilities = [
      {'id':'hostel-1','name':'North Hostel','type':'hostel'},
      {'id':'college-1','name':'Academic Building','type':'college'},
      {'id':'canteen-1','name':'Main Canteen','type':'canteen'},
      {'id':'garden-1','name':'Garden','type':'garden'},
      {'id':'transport-1','name':'Vehicle Wash','type':'transport'},
    ];
    requests = [
      for(final f in facilities)
        {'id':'request-${f['id']}','facilityId':f['id'],
         'requestedBy':'member-other','createdAt':'2026-10-10T10:00:00'},
      {'id':'mine','facilityId':'college-1',
       'requestedBy':'member-1','createdAt':'2026-10-10T10:00:00'},
    ];
    tanks = [
      for(final f in facilities)
        {'id':'tank-${f['id']}','facilityId':f['id']},
    ];
  }
  @override
  bool get approved => true;
  @override
  bool get emailVerified => true;
  @override
  bool get backendConnected => true;
}

void main() {
  test('every requested role exists and existing roles are retained', () {
    for (final role in [
      'admin','teacher','staff','canteen','student','warden',
      'worker','gardener','driver',
    ]) {
      expect(roleNames, contains(role));
    }
    expect(facilityTypes, containsAll(['garden','transport']));
    expect(activityNames, containsAll(['Garden irrigation','Vehicle washing']));
  });

  test('guard valid Admin member assignments by site type', () {
    for(final pair in [
      ['canteen','canteen'],
      ['gardener','garden'],
      ['driver','transport'],
      ['warden','hostel'],
    ]) {
      expect(validRoleFacilityAssignment(pair[0],true,'area-1',pair[1]),isTrue);
      expect(validRoleFacilityAssignment(pair[0],true,'area-1','college'),isFalse);
      expect(validRoleFacilityAssignment(pair[0],true,'',null),isFalse);
    }
    expect(validRoleFacilityAssignment('student',true,'hostel-1','hostel'),isTrue);
    expect(validRoleFacilityAssignment('student',true,'',null),isFalse);
    expect(validRoleFacilityAssignment('staff',true,'',null),isTrue);
    expect(validRoleFacilityAssignment('teacher',true,'',null),isTrue);
    expect(validRoleFacilityAssignment('worker',true,'',null),isTrue);
    expect(validRoleFacilityAssignment('admin',true,'',null),isFalse);
    expect(validRoleFacilityAssignment('made-up',true,'',null),isFalse);
  });

  test('site roles see only their site water requests and tanks', () {
    for(final choice in [
      ['canteen','canteen-1'],
      ['gardener','garden-1'],
      ['driver','transport-1'],
      ['warden','hostel-1'],
    ]){
      final store=RoleStore(choice[0],choice[1]);
      expect(store.visibleFacilities.map((x)=>x['id']),[choice[1]]);
      expect(store.visibleTanks.map((x)=>x['facilityId']),[choice[1]]);
      expect(store.visibleRequests.map((x)=>x['facilityId']),[choice[1]]);
      expect(store.reportableFacilities.map((x)=>x['id']),[choice[1]]);
      expect(store.isAdmin,isFalse);
      expect(store.isStaff,isFalse);
    }
  });

  test('academic staff and teacher see academic sites, but only own requests', () {
    for(final role in ['teacher','staff']){
      final store=RoleStore(role,'');
      expect(store.visibleFacilities.map((x)=>x['type']),['college','canteen']);
      expect(store.visibleRequests.map((x)=>x['id']),['mine']);
      expect(store.reportableFacilities.map((x)=>x['type']),['college','canteen']);
    }
  });

  test('student can report college leaks without reading private requests', () {
    final store=RoleStore('student','hostel-1');
    expect(store.visibleFacilities.map((x)=>x['id']),['hostel-1']);
    expect(store.visibleRequests.map((x)=>x['id']),['mine']);
    expect(store.reportableFacilities.map((x)=>x['type']),
      ['hostel','college','canteen']);
  });

  testWidgets('gardeners and drivers have a role-focused home and no Admin menu', (tester) async {
    tester.view.physicalSize=const Size(390,850);
    tester.view.devicePixelRatio=1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for(final pair in [['gardener','irrigation water'],['driver','vehicle wash water']]){
      final store=RoleStore(pair[0],pair[0]=='gardener'?'garden-1':'transport-1');
      await tester.pumpWidget(MaterialApp(home:AppShell(store:store)));
      expect(find.textContaining(pair[1],findRichText:true),findWidgets);
      expect(find.text('People & roles'),findsNothing);
      expect(tester.takeException(),isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });
}
