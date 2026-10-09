import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aquacampus/campus_store.dart';
import 'package:aquacampus/main.dart';

class TestStore extends CampusStore {
  TestStore() {
    user = {'id': 'admin', 'name': 'Vishnu', 'role': 'admin', 'approved': true};
  }
  @override
  bool get approved => true;
  @override
  bool get emailVerified => true;
  @override
  bool get backendConnected => true;
}

void main() {
  testWidgets('Clean header, named actions and sign out inside menu', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = TestStore();
    await tester.pumpWidget(MaterialApp(home: AppShell(store: store)));
    expect(find.text('AQUACAMPUS'), findsOneWidget);
    expect(find.byIcon(Icons.cloud_sync_outlined), findsNothing);
    expect(find.byIcon(Icons.logout_rounded), findsNothing);
    await tester.tap(find.text('Buildings').first);
    await tester.pumpAndSettle();
    expect(find.text('Add building'), findsOneWidget);
    await tester.tap(find.text('Add building'));
    await tester.pumpAndSettle();
    expect(find.text('Building name'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    expect(find.text('Sign out'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('People & roles'),
      180,
      scrollable: find
          .descendant(
            of: find.byType(Drawer),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('People & roles'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('People & roles'));
    await tester.pumpAndSettle();
    expect(find.textContaining('To add faculty:'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Requests have a visible button and useful empty instructions', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: RequestsPage(store: TestStore())),
      ),
    );
    expect(find.widgetWithText(FilledButton, 'Request water'), findsOneWidget);
    expect(
      find.textContaining('choose a building, activity and litres'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
