import 'package:aquacampus/campus_store.dart';
import 'package:aquacampus/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class OnboardingTestStore extends CampusStore {
  bool verified = false;
  int emailResends = 0;
  int verificationRefreshes = 0;
  int approvalRefreshes = 0;
  int memberSaves = 0;
  String? savedRole;
  bool? savedApproval;

  OnboardingTestStore() {
    user = {'id': 'admin-test', 'name': 'Admin Test', 'role': 'admin'};
    facilities = [
      {'id': 'hostel-1', 'name': 'Hostel One', 'type': 'hostel'},
    ];
    people = [
      {'id': 'admin-test', 'name': 'Admin Test', 'email': 'admin@campus.test',
       'role': 'admin', 'approved': true, 'facilityId': ''},
      {'id': 'member-test', 'name': 'New Member', 'email': 'new@campus.test',
       'role': 'student', 'approved': false, 'facilityId': 'hostel-1', 'room': '5'},
    ];
  }

  @override
  bool get emailVerified => verified;

  @override
  String get registeredEmail => 'new@campus.test';

  @override
  Future<void> resendEmailVerification() async {
    emailResends++;
    verificationDeliveryError = null;
    notifyListeners();
  }

  @override
  Future<bool> refreshEmailVerification() async {
    verificationRefreshes++;
    return verified;
  }

  @override
  void retrySync() { approvalRefreshes++; }

  @override
  Future<void> changeMember(
    String memberId, {
    required bool approved,
    required String role,
    required String facilityId,
    required String room,
  }) async {
    memberSaves++;
    savedApproval = approved;
    savedRole = role;
    expect(memberId, 'member-test');
    expect(facilityId, 'hostel-1');
  }
}

void main() {
  testWidgets('Undelivered verification message remains visible on a small phone', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = OnboardingTestStore();
    store.verificationDeliveryError = 'Firebase rate limit reached';
    await tester.pumpWidget(MaterialApp(home: ApprovalPage(store: store)));
    expect(find.textContaining('Firebase rate limit reached'), findsOneWidget);
    expect(find.textContaining('new@campus.test'), findsOneWidget);
    await tester.ensureVisible(find.text('Resend verification email'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Resend verification email'));
    await tester.pumpAndSettle();
    expect(store.emailResends, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('New registrant automatically checks real verification on a timer',
      (tester) async {
    final store = OnboardingTestStore()..signedIn = true;
    await tester.pumpWidget(MaterialApp(home: ApprovalPage(store: store)));
    expect(store.verificationRefreshes, 0);
    await tester.pump(const Duration(seconds: 31));
    expect(store.verificationRefreshes, 1);
    store.verified = true;
    store.notifyListeners();
    await tester.pump(const Duration(seconds: 31));
    expect(store.verificationRefreshes, 1);
    expect(find.text('Waiting for Admin'), findsOneWidget);
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Verified member can explicitly check Admin approval', (tester) async {
    final store = OnboardingTestStore()..verified = true;
    await tester.pumpWidget(MaterialApp(home: ApprovalPage(store: store)));
    expect(find.text('Waiting for Admin'), findsOneWidget);
    await tester.tap(find.text('Check Admin approval status'));
    await tester.pumpAndSettle();
    expect(store.approvalRefreshes, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Admin can approve a pending registered member with assigned hostel', (tester) async {
    tester.view.physicalSize = const Size(390, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = OnboardingTestStore();
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: MembersPage(store: store))),
    );
    await tester.scrollUntilVisible(
      find.text('Assign / Approve'), 150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Assign / Approve'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Assign / Approve'));
    await tester.pumpAndSettle();
    expect(find.text('Edit New Member'), findsOneWidget);
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save member'));
    await tester.pumpAndSettle();
    expect(store.memberSaves, 1);
    expect(store.savedRole, 'student');
    expect(store.savedApproval, true);
    expect(tester.takeException(), isNull);
  });
}
