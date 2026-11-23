import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'widgets/scan_history_panel.dart';

void main() {
  testWidgets(
    'recent scans, full history, and saved details support older records',
    (tester) async {
      final local = [
        for (var day = 1; day <= 4; day++)
          {
            'id': 'scan$day',
            'scannedAt': DateTime(2026, 11, day).millisecondsSinceEpoch,
            'name': 'Product $day',
            'calories': 160,
            if (day == 4)
              'alternatives': [
                {'name': 'Saved alternative', 'price': 25},
              ],
          },
      ];
      String? deleted;
      final deletedIds = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ScanHistoryPanel(
              recent: const Stream.empty(),
              allScans: () => const Stream.empty(),
              local: local,
              cloudIds: () async => {'remote'},
              onDelete: (id, cloud) async {
                deleted = id;
                expect(cloud, id == 'remote');
                deletedIds.add(id);
              },
            ),
          ),
        ),
      );
      expect(find.text('Product 1'), findsNothing);
      await tester.tap(find.text('Product 4'));
      await tester.pumpAndSettle();
      expect(find.text('Saved alternative'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('View all'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Product 1'));
      await tester.pumpAndSettle();
      expect(find.text('160 kcal'), findsOneWidget);
      expect(
        find.text('Alternative products were not recorded for this scan.'),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Delete scan'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(deleted, isNull);
      await tester.tap(find.byTooltip('Delete scan'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(deleted, 'scan1');
      await tester.tap(find.text('Delete all'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(deleted, 'scan1');
      await tester.tap(find.text('Delete all'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete all'));
      await tester.pumpAndSettle();
      expect(
        deletedIds,
        unorderedEquals(['scan1', 'scan2', 'scan3', 'scan4', 'remote']),
      );
      expect(find.text('Product 2'), findsNothing);
      expect(find.text('Product 3'), findsNothing);
      expect(find.text('Product 1'), findsNothing);
    },
  );
}
