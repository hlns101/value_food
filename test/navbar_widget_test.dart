import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:value_food_demo/widgets/navbar_widget.dart';

void main() {
  testWidgets('active budget tab keeps the current page', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Stack(children: [
      NavbarWidget(userId: 'test', activeTab: NavbarTab.budget),
    ]))));
    expect(find.text('home'), findsOneWidget);
    expect(find.text('budget'), findsOneWidget);
    expect(find.text('goals'), findsOneWidget);
    expect(find.text('profile'), findsOneWidget);
    await tester.tap(find.text('budget'));
    await tester.pumpAndSettle();
    expect(find.byType(NavbarWidget), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('scan uses the page callback and respects processing state', (tester) async {
    var scans = 0;
    Future<void> show(bool enabled) async {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: Stack(children: [
        NavbarWidget(userId: 'test', activeTab: NavbarTab.scan,
          scanEnabled: enabled, onScan: () => scans++),
      ]))));
    }
    await show(true);
    await tester.tap(find.text('SCAN LABEL'));
    await tester.pump();
    expect(scans, 1);
    await show(false);
    await tester.tap(find.text('SCAN LABEL'));
    await tester.pump();
    expect(scans, 1);
    expect(tester.takeException(), isNull);
  });
}
