import 'package:aquacampus/campus_store.dart';
import 'package:aquacampus/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Cross-role rendering smoke tests. These isolate Android UI behavior from
/// production Firebase: actual cloud rules, email and mobile network still
/// require separate owner-authorized device testing.
class PortalAuditStore extends CampusStore {
  PortalAuditStore(String selectedRole) {
    final site = <String, String>{
      'warden': 'hostel-1',
      'student': 'hostel-1',
      'canteen': 'canteen-1',
      'gardener': 'garden-1',
      'driver': 'transport-1',
    }[selectedRole] ?? '';
    signedIn = true;
    cloud = true;
    user = {
      'id': 'user-test',
      'name': 'Portal tester',
      'email': 'tester@example.test',
      'role': selectedRole,
      'facilityId': site,
      'approved': true,
      'room': selectedRole == 'student' ? '101' : '',
    };
    facilities = [
      for (final pair in <List<String>>[
        ['hostel-1', 'North Hostel', 'hostel'],
        ['college-1', 'Academic Building', 'college'],
        ['canteen-1', 'Main Canteen', 'canteen'],
        ['garden-1', 'Main Garden', 'garden'],
        ['transport-1', 'Vehicle Wash', 'transport'],
      ])
        {
          'id': pair[0],
          'name': pair[1],
          'type': pair[2],
          'occupants': pair[2] == 'hostel' ? 100 : 0,
          'floors': pair[2] == 'hostel' ? 3 : 1,
          'restrooms': pair[2] == 'hostel' ? 8 : 0,
          'essentialLitresPerResident': 60.0,
          'dailyCapLitres': pair[2] == 'canteen' ? 1200.0 : 0.0,
          'lowWaterThresholdLitres': 50.0,
        },
    ];
    people = [
      {
        'id': 'admin-test', 'name': 'Existing Admin',
        'role': 'admin', 'approved': true, 'email': 'admin@example.test',
        'facilityId': '', 'room': '',
      },
      {
        'id': 'member-test', 'name': 'Pending Member',
        'role': 'student', 'approved': false, 'email': 'member@example.test',
        'facilityId': 'hostel-1', 'room': '',
      },
    ];
  }

  @override
  bool get approved => true;
  @override
  bool get emailVerified => true;
  @override
  bool get backendConnected => true;
}

class MemberAuditStore extends PortalAuditStore {
  MemberAuditStore() : super('admin');
  String? savedRole;
  String? savedFacility;
  bool? savedApproval;

  @override
  Future<void> changeMember(
    String memberId, {
    required bool approved,
    required String role,
    required String facilityId,
    required String room,
  }) async {
    expect(memberId, 'member-test');
    savedRole = role;
    savedFacility = facilityId;
    savedApproval = approved;
  }
}

void main() {
  test('Academic and site staff cannot be approved for an unrelated site', () {
    for (final role in ['teacher', 'staff']) {
      expect(validRoleFacilityAssignment(role, true, '', null), isTrue);
      expect(validRoleFacilityAssignment(role, true, 'academic', 'college'), isTrue);
      expect(validRoleFacilityAssignment(role, true, 'kitchen', 'canteen'), isTrue);
      expect(validRoleFacilityAssignment(role, true, 'hostel', 'hostel'), isFalse);
      expect(validRoleFacilityAssignment(role, true, 'garden', 'garden'), isFalse);
    }
  });

  for (final role in roleNames) {
    testWidgets('$role: all permitted screens render without mobile overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = PortalAuditStore(role);
      final screens = <Widget>[
        OverviewPage(store: store),
        PlannerPage(store: store),
        FacilitiesPage(store: store),
        TanksPage(store: store),
        RequestsPage(store: store),
        SOSPage(store: store),
        NoticesPage(store: store),
        if (role == 'admin' || role == 'worker' || role == 'warden' ||
            role == 'student')
          RoomDemandPage(store: store),
        if (role == 'admin') MembersPage(store: store),
      ];
      for (final screen in screens) {
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(body: screen),
        ));
        await tester.pump();
        expect(tester.takeException(), isNull,
            reason: '$role failed to render ${screen.runtimeType}');
        await tester.pumpWidget(const SizedBox.shrink());
      }
      await tester.pumpWidget(MaterialApp(home: AppShell(store: store)));
      await tester.pump();
      expect(find.text('AQUACAMPUS'), findsOneWidget);
      await tester.tap(find.byTooltip('Open navigation menu'));
      await tester.pumpAndSettle();
      expect(find.byType(Drawer), findsOneWidget);
      expect(find.text('People & roles'),
          role == 'admin' ? findsOneWidget : findsNothing);
      expect(find.text('Sign out'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Admin role switch clears incompatible old building and saves selected site',
      (tester) async {
    tester.view.physicalSize = const Size(390, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = MemberAuditStore();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: MembersPage(store: store)),
    ));
    await tester.scrollUntilVisible(
      find.text('Assign / Approve'), 220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Assign / Approve'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Assign / Approve'));
    await tester.pumpAndSettle();
    expect(find.text('Edit Pending Member'), findsOneWidget);

    // The member previously had a hostel; Canteen Staff must not retain it.
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Canteen staff').last);
    await tester.pumpAndSettle();
    expect(find.text('None / all buildings'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byType(DropdownButtonFormField<String>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Main Canteen').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save member'));
    await tester.pumpAndSettle();
    expect(store.savedRole, 'canteen');
    expect(store.savedFacility, 'canteen-1');
    expect(store.savedApproval, isTrue);
    expect(tester.takeException(), isNull);
  });
}
