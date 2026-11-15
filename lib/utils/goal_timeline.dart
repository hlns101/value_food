import 'dart:math' as math;

class GoalTimeline {
  final double start, current, target;
  final DateTime begin, end, now;
  const GoalTimeline({required this.start, required this.current,
    required this.target, required this.begin, required this.end, required this.now});

  static DateTime day(DateTime value) => DateTime.utc(value.year, value.month, value.day);
  int get durationDays => day(end).difference(day(begin)).inDays;
  bool get valid => start.isFinite && current.isFinite && target.isFinite &&
      start > target && target > 0 && current > 0 && durationDays > 0;
  double get elapsed => valid
      ? (day(now).difference(day(begin)).inDays / durationDays).clamp(0.0, 1.0)
      : 0.0;
  int get daysLeft => math.max(0, day(end).difference(day(now)).inDays);
  double get plannedWeight => start + (target - start) * elapsed;
  String get status {
    if (!valid) return 'Set a target date after your start date';
    if (current <= target) return 'Target reached';
    if (day(now).isBefore(day(begin))) return 'Your timeline has not started yet';
    if (day(now).isAfter(day(end))) return 'Target date passed Â· Review your goal';
    final difference = current - plannedWeight;
    if (difference.abs() < 0.5) return 'Saved weight is on the planned path';
    return 'Saved weight is ${difference.abs().toStringAsFixed(1)} lbs ${difference > 0 ? "above" : "below"} the planned path';
  }
}
