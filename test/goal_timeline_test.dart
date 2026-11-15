import 'package:flutter_test/flutter_test.dart';
import 'package:value_food_demo/utils/goal_timeline.dart';

void main() {
  GoalTimeline plan(DateTime now, {double current = 150, DateTime? end}) =>
    GoalTimeline(start: 160, current: current, target: 140,
      begin: DateTime(2026, 11, 1), end: end ?? DateTime(2026, 11, 21), now: now);
  test('midpoint uses calendar dates and compares saved weight to plan', () {
    final t = plan(DateTime(2026, 11, 11, 23));
    expect(t.elapsed, 0.5);
    expect(t.plannedWeight, 150);
    expect(t.daysLeft, 10);
    expect(t.status, contains('on the planned path'));
    expect(plan(DateTime(2026, 11, 11), current: 153).status, contains('3.0 lbs above'));
  });
  test('clamps before and after timeline and handles completion', () {
    expect(plan(DateTime(2026, 10, 1)).elapsed, 0);
    final overdue = plan(DateTime(2026, 12, 1));
    expect(overdue.elapsed, 1);
    expect(overdue.daysLeft, 0);
    expect(overdue.status, contains('Target date passed'));
    expect(plan(DateTime(2026, 11, 11), current: 139).status, 'Target reached');
  });
  test('invalid dates do not divide by zero', () {
    final t = plan(DateTime(2026, 11, 1), end: DateTime(2026, 11, 1));
    expect(t.valid, false);
    expect(t.elapsed, 0);
  });
}
