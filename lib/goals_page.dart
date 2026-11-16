import 'widgets/navbar_widget.dart';
import 'widgets/dashboard_header.dart';
import 'utils/goal_timeline.dart';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' hide TextDirection;

class GoalsPage extends StatefulWidget {
  final String userId;
  const GoalsPage({super.key, required this.userId});
  @override
  State<GoalsPage> createState() => _GoalsPageState();
}

class _GoalsPageState extends State<GoalsPage> {
  late Stream<DocumentSnapshot<Map<String, dynamic>>> _profileStream;
  late Stream<QuerySnapshot<Map<String, dynamic>>> _weightsStream;

  void _connectStreams() {
    _profileStream = userRef.snapshots();
    _weightsStream = logRef.snapshots();
  }

  @override
  void initState() {
    super.initState();
    _connectStreams();
  }

  @override
  void didUpdateWidget(covariant GoalsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) _connectStreams();
  }

  bool _kilograms = false;
  String get _unit => _kilograms ? 'kg' : 'lbs';
  double _displayWeight(double pounds) =>
      _kilograms ? pounds / 2.2046226218 : pounds;
  void _setUnit(bool kilograms) => setState(() => _kilograms = kilograms);

  Widget _unitSelector() => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: const Color(0xFFE8F2E5),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        for (final kilograms in [false, true])
          Expanded(
            child: InkWell(
              onTap: () => _setUnit(kilograms),
              borderRadius: BorderRadius.circular(11),
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  color: _kilograms == kilograms ? green : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Text(
                  kilograms ? 'Kilograms (kg)' : 'Pounds (lbs)',
                  style: TextStyle(
                    color: _kilograms == kilograms ? Colors.white : green,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );

  static const green = Color(0xFF287D35);
  static const lime = Color(0xFF7DB848);
  static const blue = Color(0xFF176084);
  static const bg = Color(0xFFF6FAF6);
  final peso = NumberFormat.currency(
    locale: 'en_PH',
    symbol: '₱',
    decimalDigits: 0,
  );
  final dateFormat = DateFormat('MMM d, yyyy');
  DocumentReference<Map<String, dynamic>> get userRef =>
      FirebaseFirestore.instance.collection('users').doc(widget.userId);
  CollectionReference<Map<String, dynamic>> get logRef =>
      userRef.collection('weightLogs');
  double? number(dynamic value) =>
      value is num ? value.toDouble() : double.tryParse('$value');
  DateTime? date(dynamic value) =>
      value is Timestamp
          ? value.toDate()
          : value is DateTime
          ? value
          : DateTime.tryParse('$value');
  void go(Widget page) => Navigator.pushReplacement(
    context,
    MaterialPageRoute(builder: (_) => page),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: bg,
    body: Stack(
      children: [
        SafeArea(
          bottom: false,
          child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: _profileStream,
            builder: (context, profileSnap) {
              final user = profileSnap.data?.data() ?? <String, dynamic>{};
              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _weightsStream,
                builder: (context, logsSnap) {
                  final logs =
                      logsSnap.data?.docs
                          .map((d) {
                            final data = d.data();
                            return _WeightLog(
                              number(data['weightLbs']) ??
                                  ((number(data['weight']) ?? 0) *
                                      2.2046226218),
                              date(data['date']) ?? DateTime(2000),
                            );
                          })
                          .where((e) => e.weight > 0)
                          .toList() ??
                      <_WeightLog>[];
                  logs.sort((a, b) => a.date.compareTo(b.date));
                  final goal =
                      user['weightGoal'] is Map
                          ? Map<String, dynamic>.from(user['weightGoal'] as Map)
                          : <String, dynamic>{};
                  final start =
                      number(goal['startWeight']) ??
                      ((number(user['weight']) ?? 0) * 2.2046226218);
                  final profileWeight = number(user['weight']);
                  final current =
                      profileWeight != null && profileWeight > 0
                          ? profileWeight * 2.2046226218
                          : (logs.isNotEmpty ? logs.last.weight : 0.0);
                  final target = number(goal['targetWeight']) ?? 0;
                  final weeks = (number(goal['weeks']) ?? 8).round().clamp(
                    1,
                    104,
                  );
                  final startDate = date(goal['startDate']) ?? DateTime.now();
                  final deadline =
                      date(goal['targetDate']) ??
                      startDate.add(Duration(days: weeks * 7));
                  final monthly =
                      number(user['budget'] ?? user['monthlyLimit']) ?? 0;
                  final dailyBudget =
                      monthly /
                      DateUtils.getDaysInMonth(
                        DateTime.now().year,
                        DateTime.now().month,
                      );
                  final hasGoal = start > 0 && target > 0 && target < start;
                  final initialLoss =
                      hasGoal ? math.max(0.0, start - target) : 0.0;
                  final lost =
                      hasGoal
                          ? (start - current).clamp(0.0, initialLoss).toDouble()
                          : 0.0;
                  final remaining =
                      hasGoal ? math.max(0.0, current - target) : 0.0;
                  final timelineWeeks = math.max(
                    1.0,
                    deadline.difference(startDate).inDays / 7.0,
                  );
                  final weekly = hasGoal ? initialLoss / timelineWeeks : 0.0;
                  final progress =
                      initialLoss > 0
                          ? (lost / initialLoss).clamp(0.0, 1.0)
                          : 0.0;
                  final planLabel =
                      !hasGoal
                          ? 'Set a weight-loss goal'
                          : weekly <= 1.0
                          ? 'Gradual pace'
                          : 'Review your timeline';
                  return ListView(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      22,
                      16,
                      150 + MediaQuery.of(context).padding.bottom,
                    ),
                    children: [
                      _header(
                        user['firstName']?.toString() ??
                            user['name']?.toString() ??
                            'User',
                      ),
                      const SizedBox(height: 16),
                      _unitSelector(),
                      const SizedBox(height: 17),
                      _goalCard(
                        start,
                        current,
                        target,
                        remaining,
                        lost,
                        initialLoss,
                        progress,
                        hasGoal,
                        () => _editGoal(user, goal, current),
                      ),
                      const SizedBox(height: 14),
                      _timelineCard(
                        start,
                        current,
                        target,
                        startDate,
                        deadline,
                        logs,
                        hasGoal,
                      ),
                      const SizedBox(height: 14),
                      _planCard(
                        weekly,
                        weeks,
                        dailyBudget,
                        planLabel,
                        hasGoal,
                        user,
                      ),
                      const SizedBox(height: 15),
                      SizedBox(
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: () => _logWeight(current),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text("Log Today's Weight"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: green,
                            foregroundColor: Colors.white,
                            shape: const StadiumBorder(),
                          ),
                        ),
                      ),
                      if (profileSnap.hasError || logsSnap.hasError) ...[
                        const SizedBox(height: 12),
                        Text(
                          profileSnap.hasError
                              ? 'Unable to load your profile. Check access to users/{userId}.'
                              : 'Unable to load weight history. Check access to users/{userId}/weightLogs.',
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  );
                },
              );
            },
          ),
        ),
        NavbarWidget(userId: widget.userId, activeTab: NavbarTab.goals),
      ],
    ),
  );

  Widget _header(String name) => DashboardHeader(
    name: name,
    pageTitle: 'Goals',
    subtitle: 'Track weight progress & daily calorie pace',
  );

  Widget _goalCard(
    double start,
    double current,
    double target,
    double remaining,
    double lost,
    double total,
    double progress,
    bool hasGoal,
    VoidCallback edit,
  ) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: lime,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Weight Loss Goal',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: edit,
              icon: const Icon(Icons.edit, size: 14),
              label: const Text('Edit'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.white24,
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _metric(
              'Current',
              current > 0 ? _displayWeight(current).toStringAsFixed(1) : '—',
              _unit,
            ),
            const SizedBox(width: 7),
            _metric(
              'Target',
              hasGoal ? _displayWeight(target).toStringAsFixed(1) : '—',
              _unit,
            ),
            const SizedBox(width: 7),
            _metric(
              'To Lose',
              hasGoal ? _displayWeight(remaining).toStringAsFixed(1) : '—',
              _unit,
            ),
          ],
        ),
        const SizedBox(height: 15),
        Text(
          hasGoal
              ? 'Progress: ${_displayWeight(lost).toStringAsFixed(1)} of ${_displayWeight(total).toStringAsFixed(1)} $_unit'
              : 'Set your target weight to begin',
          style: const TextStyle(color: Colors.white, fontSize: 11),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 9,
            color: Colors.white,
            backgroundColor: Colors.white38,
          ),
        ),
        const SizedBox(height: 3),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '${(progress * 100).round()}%',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _metric(String title, String amount, String unit) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(color: Colors.black54, fontSize: 10),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '$amount $unit',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: blue,
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _timelineCard(
    double start,
    double current,
    double target,
    DateTime startDate,
    DateTime deadline,
    List<_WeightLog> logs,
    bool hasGoal,
  ) {
    final timeline = GoalTimeline(
      start: start,
      current: current,
      target: target,
      begin: startDate,
      end: deadline,
      now: DateTime.now(),
    );
    final active = hasGoal && timeline.valid;
    return _whiteCard(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_month, size: 18, color: green),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Weight Progress',
                  style: TextStyle(
                    color: blue,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (active)
                Text(
                  '${timeline.daysLeft} Days Left',
                  style: const TextStyle(color: green, fontSize: 10),
                ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 240,
            width: double.infinity,
            child: Semantics(
              label:
                  'Weight progress line chart. Solid green line and circular markers show recorded weight in ${_kilograms ? 'kilograms' : 'pounds'} over time.',
              child: CustomPaint(
                painter: _GoalChartPainter(
                  start: start,
                  current: current,
                  target: target,
                  logs: logs,
                  begin: startDate,
                  end: deadline,
                  active: active,
                  kilograms: _kilograms,
                ),
              ),
            ),
          ),
          const SizedBox(height: 9),
          const Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              Text(
                '━  Recorded weight',
                style: TextStyle(
                  color: green,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                active
                    ? 'Start (${_displayWeight(start).toStringAsFixed(1)} $_unit)'
                    : 'Set a goal to begin',
                style: const TextStyle(color: blue, fontSize: 10),
              ),
              Text(
                hasGoal
                    ? '${dateFormat.format(deadline)} (${_displayWeight(target).toStringAsFixed(1)} $_unit)'
                    : 'No target yet',
                style: const TextStyle(color: green, fontSize: 10),
              ),
            ],
          ),
          const Divider(height: 20),
          Text(
            active
                ? '${_kilograms ? timeline.status.replaceAllMapped(RegExp(r"([0-9]+\.[0-9]+) lbs"), (m) => "${(double.parse(m[1]!) / 2.2046226218).toStringAsFixed(1)} kg") : timeline.status}\nLatest saved weight: ${_displayWeight(current).toStringAsFixed(1)} $_unit. Each dot represents a saved measurement; log more weights to extend the line.'
                : 'Tap Edit to choose your target and timeline',
            style: const TextStyle(fontSize: 11, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _planCard(
    double weekly,
    int weeks,
    double dailyBudget,
    String planLabel,
    bool hasGoal,
    Map<String, dynamic> user,
  ) {
    final calories = _estimatedCalories(user, weekly);
    return _whiteCard(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.show_chart, size: 18, color: green),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Recommended Plan',
                  style: TextStyle(
                    color: blue,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                planLabel,
                style: const TextStyle(color: green, fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: const Color(0xFFEDF7E8),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'WEEKLY LOSS TARGET',
                        style: TextStyle(color: Colors.black45, fontSize: 9),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        hasGoal
                            ? '${_displayWeight(weekly).toStringAsFixed(1)} $_unit / week'
                            : 'Not set',
                        style: const TextStyle(
                          color: green,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        hasGoal
                            ? '$weeks-week target timeline'
                            : 'Edit your goal to calculate a plan',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.check_circle, color: green, size: 20),
              ],
            ),
          ),
          if (weekly > 2) ...[
            const SizedBox(height: 7),
            Text(
              'This target is faster than ${_kilograms ? '0.9 kg' : '2 lbs'}/week. Consider a longer timeline and seek professional guidance.',
              style: const TextStyle(color: Colors.deepOrange, fontSize: 11),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _planStat(
                  'Daily Calorie Estimate',
                  calories == null
                      ? 'Not available'
                      : '${calories.round()} kcal',
                  'General estimate; not a prescription',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _planStat(
                  'Food Budget Cap',
                  dailyBudget > 0
                      ? '${peso.format(dailyBudget)}/day'
                      : 'Not set',
                  'Based on monthly budget',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _planStat(String title, String value, String detail) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: const Color(0xFFF6F9F5),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: Colors.black54, fontSize: 9)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: blue,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          detail,
          style: const TextStyle(fontSize: 8, color: Colors.black45),
        ),
      ],
    ),
  );

  // Mifflin-St Jeor estimates resting energy expenditure. Only apply the
  // activity multiplier when required profile inputs are available.
  double? _estimatedCalories(Map<String, dynamic> user, double weeklyLoss) {
    final age = number(user['age']);
    final kg = number(user['weight']);
    final cm = number(user['height']);
    final sex = '${user['sex'] ?? ''}'.toLowerCase();
    if (age == null ||
        age < 18 ||
        kg == null ||
        kg <= 0 ||
        cm == null ||
        cm <= 0 ||
        (sex != 'male' && sex != 'female'))
      return null;
    final bmr = 10 * kg + 6.25 * cm - 5 * age + (sex == 'male' ? 5 : -161);
    final factor = switch ('${user['activityLevel'] ?? ''}'.toLowerCase()) {
      'sedentary' => 1.2,
      'lightly active' => 1.375,
      'moderately active' => 1.55,
      'active' => 1.725,
      'very active' => 1.9,
      _ => null,
    };
    if (factor == null) return null;
    // Do not subtract a calculated deficit here; actual dietary targets require
    // health context not supplied by the app.
    return bmr * factor;
  }

  Widget _whiteCard(Widget child) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: const Color(0xFFE2EDE2)),
      borderRadius: BorderRadius.circular(18),
    ),
    child: child,
  );

  Future<void> _editGoal(
    Map<String, dynamic> user,
    Map<String, dynamic> goal,
    double current,
  ) async {
    final target = await showModalBottomSheet<_GoalInput>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (_) => _GoalEditor(
            kilograms: _kilograms,
            onUnitChanged: _setUnit,
            current: current,
            estimatedCalories: _estimatedCalories(user, 0),
            dailyBudget:
                (number(user['budget'] ?? user['monthlyLimit']) ?? 0) /
                DateUtils.getDaysInMonth(
                  DateTime.now().year,
                  DateTime.now().month,
                ),
            target: number(goal['targetWeight']),
            targetDate:
                date(goal['targetDate']) ??
                (date(goal['startDate']) ?? DateTime.now()).add(
                  Duration(days: (number(goal['weeks']) ?? 8).round() * 7),
                ),
          ),
    );
    if (target == null) return;
    try {
      await userRef.set({
        'weightGoal': {
          'startWeight': current,
          'targetWeight': target.target,
          'weeks': (target.targetDate.difference(DateTime.now()).inDays / 7)
              .ceil()
              .clamp(1, 104),
          'targetDate': Timestamp.fromDate(target.targetDate),
          'startDate': Timestamp.fromDate(DateTime.now()),
        },
      }, SetOptions(merge: true));
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to save goal. Check your connection and Firestore rules.',
            ),
          ),
        );
    }
  }

  Future<void> _logWeight(double current) async {
    final newWeight = await showDialog<double>(
      context: context,
      builder:
          (_) => _LogWeightDialog(
            initial: current,
            kilograms: _kilograms,
            onUnitChanged: _setUnit,
          ),
    );
    if (newWeight == null) return;
    try {
      final batch = FirebaseFirestore.instance.batch();
      batch.set(logRef.doc(), {
        'weightLbs': newWeight,
        'date': Timestamp.now(),
      });
      batch.set(userRef, {
        'weight': newWeight / 2.2046226218,
      }, SetOptions(merge: true));
      await batch.commit();
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not log weight. Check Firestore permissions.'),
          ),
        );
    }
  }
}

class _WeightLog {
  final double weight;
  final DateTime date;
  const _WeightLog(this.weight, this.date);
}

class _GoalInput {
  final double target;
  final DateTime targetDate;

  const _GoalInput({required this.target, required this.targetDate});
}

class _GoalEditor extends StatefulWidget {
  final double current;
  final double? target;
  final DateTime targetDate;
  final double? estimatedCalories;
  final double dailyBudget;

  final bool kilograms;
  final ValueChanged<bool> onUnitChanged;
  const _GoalEditor({
    required this.kilograms,
    required this.onUnitChanged,
    required this.current,
    required this.target,
    required this.targetDate,
    required this.estimatedCalories,
    required this.dailyBudget,
  });

  @override
  State<_GoalEditor> createState() => _GoalEditorState();
}

class _GoalEditorState extends State<_GoalEditor> {
  static const _green = Color(0xFF287D35);
  static const _blue = Color(0xFF176084);
  static const _paleGreen = Color(0xFFF5FAF5);

  bool _kilograms = false;
  static const _poundsPerKg = 2.2046226218;
  String get _unit => _kilograms ? 'kg' : 'lbs';
  double _displayWeight(double pounds) =>
      _kilograms ? pounds / _poundsPerKg : pounds;
  late double _target;
  late DateTime _targetDate;
  int? _selectedPreset;

  @override
  void initState() {
    super.initState();
    _kilograms = widget.kilograms;
    _target =
        (widget.target != null && widget.target! > 0)
            ? widget.target!
            : widget.current > 0
            ? widget.current - 10
            : 0;
    _targetDate =
        widget.targetDate.isAfter(DateTime.now())
            ? widget.targetDate
            : DateTime.now().add(const Duration(days: 60));
    _updatePreset();
  }

  void _updatePreset() {
    final difference = _targetDate.difference(DateTime.now()).inDays;
    if ((difference - 42).abs() <= 1) {
      _selectedPreset = 42;
    } else if ((difference - 60).abs() <= 1) {
      _selectedPreset = 60;
    } else if ((difference - 84).abs() <= 1) {
      _selectedPreset = 84;
    } else {
      _selectedPreset = null;
    }
  }

  void _changeTarget(double step) {
    if (widget.current <= 0) return;
    setState(() {
      _target = (_target + (_kilograms ? step * _poundsPerKg : step)).clamp(
        1.0,
        widget.current - 0.1,
      );
      if (!_kilograms) _target = (10 * _target).roundToDouble() / 10;
    });
  }

  void _choosePreset(int days) {
    setState(() {
      _selectedPreset = days;
      _targetDate = DateTime.now().add(Duration(days: days));
    });
  }

  Future<void> _chooseDate() async {
    final today = DateTime.now();
    final first = DateTime(today.year, today.month, today.day + 1);
    final last = DateTime(today.year + 2, today.month, today.day);
    final initial =
        _targetDate.isBefore(first)
            ? first
            : (_targetDate.isAfter(last) ? last : _targetDate);

    final chosen = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
      helpText: 'TARGET COMPLETION DATE',
      confirmText: 'Set date',
      cancelText: 'Cancel',
      builder: (context, child) {
        final base = Theme.of(context);
        final scheme = ColorScheme.fromSeed(
          seedColor: _green,
          brightness: Brightness.light,
        ).copyWith(
          primary: _green,
          onPrimary: Colors.white,
          surface: const Color(0xFFF7FAF7),
          onSurface: const Color(0xFF26482B),
          onSurfaceVariant: const Color(0xFF64745F),
          secondaryContainer: const Color(0xFFE8F2E5),
        );
        return Theme(
          data: base.copyWith(
            colorScheme: scheme,
            textTheme: ThemeData.light().textTheme.apply(
              fontFamily: 'Poppins',
              bodyColor: const Color(0xFF26482B),
              displayColor: _blue,
            ),
            datePickerTheme: DatePickerThemeData(
              backgroundColor: const Color(0xFFF7FAF7),
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: const BorderSide(color: Color(0xFFDDE9D8)),
              ),
              headerBackgroundColor: const Color(0xFFE8F2E5),
              headerForegroundColor: _blue,
              headerHeadlineStyle: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 28,
                fontWeight: FontWeight.w700,
              ),
              headerHelpStyle: const TextStyle(
                fontFamily: 'Poppins',
                color: _green,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              weekdayStyle: const TextStyle(
                fontFamily: 'Poppins',
                color: _green,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              dayStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 12),
              todayBorder: const BorderSide(color: _green, width: 1.5),
              todayForegroundColor: WidgetStateProperty.resolveWith(
                (states) =>
                    states.contains(WidgetState.selected)
                        ? Colors.white
                        : _green,
              ),
              dayBackgroundColor: WidgetStateProperty.resolveWith(
                (states) =>
                    states.contains(WidgetState.selected) ? _green : null,
              ),
              dayForegroundColor: WidgetStateProperty.resolveWith(
                (states) =>
                    states.contains(WidgetState.disabled)
                        ? const Color(0xFFB7C3B3)
                        : states.contains(WidgetState.selected)
                        ? Colors.white
                        : const Color(0xFF26482B),
              ),
              cancelButtonStyle: TextButton.styleFrom(
                foregroundColor: _green,
                textStyle: const TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                ),
              ),
              confirmButtonStyle: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: _green,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: const Color(0xFFF0F6ED),
              labelStyle: const TextStyle(color: _green),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFDDE9D8)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _green, width: 1.5),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (chosen == null || !mounted) return;
    setState(() {
      _targetDate = chosen;
      _updatePreset();
    });
  }

  @override
  Widget build(BuildContext context) {
    final totalLoss = math.max(0.0, widget.current - _target);
    final days = math.max(1, _targetDate.difference(DateTime.now()).inDays);
    final weeklyLoss = totalLoss / (days / 7);
    final percentLoss =
        widget.current > 0 ? (totalLoss / widget.current) * 100 : 0.0;
    final healthyPace = weeklyLoss > 0 && weeklyLoss <= 2;
    final calorieNote =
        widget.estimatedCalories == null
            ? 'Not available'
            : '${widget.estimatedCalories!.round()} kcal/day';
    final budgetNote =
        widget.dailyBudget > 0
            ? '₱${widget.dailyBudget.toStringAsFixed(0)}/day'
            : 'Not set';

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: FractionallySizedBox(
          heightFactor: 0.88,
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(27)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 9),
                Container(
                  width: 37,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD8D8D8),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(17, 13, 17, 12),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, size: 18),
                        style: IconButton.styleFrom(
                          backgroundColor: _paleGreen,
                        ),
                      ),
                      const Expanded(
                        child: Text(
                          'Edit Weight Goal',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _blue,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F6E7),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Text(
                          _kilograms ? 'KG' : 'LBS',
                          style: const TextStyle(
                            color: _green,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFF0F1F0)),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(17, 18, 17, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F2E5),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              for (final kilograms in [false, true])
                                Expanded(
                                  child: InkWell(
                                    onTap:
                                        () => setState(() {
                                          _kilograms = kilograms;
                                          widget.onUnitChanged(kilograms);
                                        }),
                                    borderRadius: BorderRadius.circular(11),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color:
                                            _kilograms == kilograms
                                                ? _green
                                                : Colors.transparent,
                                        borderRadius: BorderRadius.circular(11),
                                      ),
                                      child: Text(
                                        kilograms
                                            ? 'Kilograms (kg)'
                                            : 'Pounds (lbs)',
                                        style: TextStyle(
                                          color:
                                              _kilograms == kilograms
                                                  ? Colors.white
                                                  : _green,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: _paleGreen,
                            borderRadius: BorderRadius.circular(19),
                            border: Border.all(color: const Color(0xFFE0EDE0)),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'DESIRED WEIGHT',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.black54,
                                    ),
                                  ),
                                  Text(
                                    'Current: ${_displayWeight(widget.current).toStringAsFixed(1)} $_unit',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 13),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  _stepButton(
                                    Icons.remove,
                                    () => _changeTarget(-0.5),
                                  ),
                                  Text.rich(
                                    TextSpan(
                                      children: [
                                        TextSpan(
                                          text: _displayWeight(
                                            _target,
                                          ).toStringAsFixed(1),
                                          style: const TextStyle(
                                            fontSize: 30,
                                            color: Color(0xFF3981A3),
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                        TextSpan(
                                          text: ' $_unit',
                                          style: const TextStyle(
                                            color: Colors.black54,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  _stepButton(
                                    Icons.add,
                                    () => _changeTarget(0.5),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _kilograms
                                    ? '≈ ${_target.toStringAsFixed(2)} lbs'
                                    : '≈ ${(_target / _poundsPerKg).toStringAsFixed(2)} kg',
                                style: const TextStyle(
                                  color: Colors.black54,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                '${_displayWeight(totalLoss).toStringAsFixed(1)} $_unit total loss '
                                '(-${percentLoss.toStringAsFixed(1)}% body weight)',
                                style: const TextStyle(
                                  color: _green,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: const [
                            Text(
                              'Target Timeline',
                              style: TextStyle(
                                fontSize: 13,
                                color: _blue,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              'Tap preset or pick date',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.black45,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _preset('6 Weeks', 42),
                            const SizedBox(width: 7),
                            _preset('60 Days', 60),
                            const SizedBox(width: 7),
                            _preset('12 Weeks', 84),
                          ],
                        ),
                        const SizedBox(height: 11),
                        InkWell(
                          onTap: _chooseDate,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: _paleGreen,
                              border: Border.all(
                                color: const Color(0xFFE0EDE0),
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.calendar_month_outlined,
                                  color: _green,
                                  size: 20,
                                ),
                                const SizedBox(width: 9),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Target Completion Date',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.black54,
                                        ),
                                      ),
                                      Text(
                                        DateFormat(
                                          'MMMM d, yyyy',
                                        ).format(_targetDate),
                                        style: const TextStyle(
                                          color: _blue,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Text(
                                  'Change',
                                  style: TextStyle(
                                    color: _green,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right,
                                  color: _green,
                                  size: 18,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 19),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE9F7EA),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.check_circle,
                                    color: _green,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 9),
                                  Expanded(
                                    child: Text(
                                      '${_displayWeight(weeklyLoss).toStringAsFixed(1)} $_unit / week · '
                                      '${healthyPace ? 'Healthy Rate' : 'Review Timeline'}',
                                      style: const TextStyle(
                                        color: _green,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                healthyPace
                                    ? 'Within a gradual weight-loss range (up to ${_kilograms ? '0.9 kg' : '2 lbs'}/week)'
                                    : 'Consider a longer timeline or consult a qualified professional.',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.black54,
                                ),
                              ),
                              const Divider(height: 24),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Daily Calorie Estimate',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.black54,
                                    ),
                                  ),
                                  Flexible(
                                    child: Text(
                                      calorieNote,
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: _blue,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 7),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Synced Food Budget Cap',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.black54,
                                    ),
                                  ),
                                  Text(
                                    budgetNote,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: _green,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(17, 14, 17, 12),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: Color(0xFFEDF1ED))),
                  ),
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 49,
                        child: ElevatedButton(
                          onPressed:
                              widget.current <= 0 ||
                                      _target <= 0 ||
                                      _target >= widget.current
                                  ? null
                                  : () => Navigator.pop(
                                    context,
                                    _GoalInput(
                                      target: _target,
                                      targetDate: _targetDate,
                                    ),
                                  ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _green,
                            foregroundColor: Colors.white,
                            shape: const StadiumBorder(),
                          ),
                          child: const Text(
                            'Save Weight Goal',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(color: Colors.black54, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _stepButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 46,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE1EAE1)),
        ),
        child: Icon(icon, color: _green),
      ),
    );
  }

  Widget _preset(String text, int days) {
    final selected = _selectedPreset == days;
    return Expanded(
      child: InkWell(
        onTap: () => _choosePreset(days),
        borderRadius: BorderRadius.circular(11),
        child: Container(
          height: 43,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? _green : _paleGreen,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: selected ? _green : const Color(0xFFE1EAE1),
            ),
          ),
          child: Text(
            text,
            style: TextStyle(
              color: selected ? Colors.white : Colors.black45,
              fontSize: 11,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _LogWeightDialog extends StatefulWidget {
  final double initial;
  final bool kilograms;
  final ValueChanged<bool> onUnitChanged;
  const _LogWeightDialog({
    required this.kilograms,
    required this.onUnitChanged,
    required this.initial,
  });
  @override
  State<_LogWeightDialog> createState() => _LogWeightDialogState();
}

class _LogWeightDialogState extends State<_LogWeightDialog> {
  late final TextEditingController controller;
  bool _kilograms = false;
  double? _pounds;
  static const _poundsPerKg = 2.2046226218;

  void _changeUnit(bool kilograms) {
    if (_kilograms == kilograms) return;
    setState(() {
      _kilograms = kilograms;
      widget.onUnitChanged(kilograms);
      if (_pounds != null) {
        final displayed = kilograms ? _pounds! / _poundsPerKg : _pounds!;
        controller.text = displayed.toStringAsFixed(2);
        controller.selection = TextSelection.collapsed(
          offset: controller.text.length,
        );
      }
    });
  }

  String get _conversion {
    if (_pounds == null || !_pounds!.isFinite || _pounds! <= 0)
      return 'Enter a weight to see the conversion';
    return _kilograms
        ? '≈ ${_pounds!.toStringAsFixed(2)} lbs'
        : '≈ ${(_pounds! / _poundsPerKg).toStringAsFixed(2)} kg';
  }

  @override
  void initState() {
    super.initState();
    _kilograms = widget.kilograms;
    _pounds =
        widget.initial > 0
            ? double.parse(widget.initial.toStringAsFixed(1))
            : null;
    controller = TextEditingController(
      text:
          widget.initial > 0
              ? (_kilograms ? _pounds! / _poundsPerKg : _pounds!)
                  .toStringAsFixed(2)
              : '',
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  final _formKey = GlobalKey<FormState>();
  static const _green = Color(0xFF287D35);

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.pop(context, _pounds);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: const Color(0xFFF7FAF7),
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(24),
      side: const BorderSide(color: Color(0xFFE1EADD)),
    ),
    titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
    contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
    actionsPadding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
    title: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F2E5),
            borderRadius: BorderRadius.circular(15),
          ),
          child: const Icon(
            Icons.monitor_weight_outlined,
            color: _green,
            size: 28,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          "Log Today's Weight",
          style: TextStyle(
            color: Color(0xFF176084),
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
    content: SingleChildScrollView(
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add a measurement to track your progress.',
              style: TextStyle(
                color: Color(0xFF64745F),
                fontSize: 12,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F2E5),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  for (final kilograms in [false, true])
                    Expanded(
                      child: InkWell(
                        onTap: () => _changeUnit(kilograms),
                        borderRadius: BorderRadius.circular(11),
                        child: Container(
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          decoration: BoxDecoration(
                            color:
                                _kilograms == kilograms
                                    ? _green
                                    : Colors.transparent,
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: Text(
                            kilograms ? 'Kilograms (kg)' : 'Pounds (lbs)',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color:
                                  _kilograms == kilograms
                                      ? Colors.white
                                      : _green,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: controller,
              onChanged:
                  (value) => setState(() {
                    final parsed = double.tryParse(value);
                    _pounds =
                        parsed == null
                            ? null
                            : (_kilograms ? parsed * _poundsPerKg : parsed);
                  }),
              autofocus: true,
              cursorColor: _green,
              style: const TextStyle(
                color: _green,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _save(),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              validator: (value) {
                final weight = double.tryParse(value ?? '');
                return weight == null ||
                        !weight.isFinite ||
                        weight <= 0 ||
                        _pounds == null ||
                        !_pounds!.isFinite
                    ? 'Enter a valid weight above zero'
                    : null;
              },
              decoration: InputDecoration(
                labelText: 'Current weight',
                labelStyle: const TextStyle(
                  color: Color(0xFF64745F),
                  fontSize: 13,
                ),
                floatingLabelStyle: const TextStyle(
                  color: _green,
                  fontWeight: FontWeight.w600,
                ),
                suffixText: _kilograms ? 'kg' : 'lbs',
                suffixStyle: const TextStyle(color: _green, fontSize: 13),
                filled: true,
                fillColor: const Color(0xFFF0F6ED),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 18,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFDDE9D8)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFDDE9D8)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _green, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Semantics(
              liveRegion: true,
              child: Text(
                _conversion,
                style: const TextStyle(
                  color: _green,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
    actions: [
      Row(
        children: [
          Expanded(
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                foregroundColor: _green,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Cancel'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              onPressed: _save,
              style: FilledButton.styleFrom(
                backgroundColor: _green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text('Save weight'),
            ),
          ),
        ],
      ),
    ],
  );
}

class _GoalChartPainter extends CustomPainter {
  final double start, current, target;
  final DateTime begin, end;
  final List<_WeightLog> logs;
  final bool active;
  final bool kilograms;
  const _GoalChartPainter({
    required this.start,
    required this.current,
    required this.target,
    required this.logs,
    required this.begin,
    required this.end,
    required this.active,
    required this.kilograms,
  });
  @override
  void paint(Canvas canvas, Size size) {
    const green = Color(0xFF287D35);
    const blue = Color(0xFF176084);
    const muted = Color(0xFF71816D);
    final plot = Rect.fromLTRB(46, 20, size.width - 18, size.height - 32);
    if (plot.width <= 0 || plot.height <= 0) return;
    void text(
      String value,
      Offset position, {
      Color color = muted,
      bool centered = false,
    }) {
      final painter = TextPainter(
        text: TextSpan(
          text: value,
          style: TextStyle(color: color, fontSize: 9, fontFamily: 'Poppins'),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(
        canvas,
        centered ? position - Offset(painter.width / 2, 0) : position,
      );
    }

    if (!active) {
      text(
        'Set a goal to view your weight progress',
        Offset(size.width / 2, size.height / 2),
        centered: true,
      );
      return;
    }
    final now = DateTime.now();
    // Plot saved measurements only; the target is a reference, not a measurement.
    final points = <_WeightLog>[
      _WeightLog(start, begin),
      ...logs.where(
        (log) =>
            log.weight.isFinite &&
            log.weight > 0 &&
            !log.date.isBefore(begin) &&
            !log.date.isAfter(now),
      ),
    ]..sort((a, b) => a.date.compareTo(b.date));
    final lastDate = points.last.date;
    final span = math.max(
      const Duration(days: 1).inMilliseconds,
      lastDate.difference(begin).inMilliseconds,
    );
    double display(double pounds) => kilograms ? pounds / 2.2046226218 : pounds;
    final weights = points.map((log) => display(display(log.weight))).toList();
    final minimum = weights.reduce(math.min);
    final maximum = weights.reduce(math.max);
    final padding = math.max(kilograms ? 1.0 : 2.0, (maximum - minimum) * .15);
    final low = minimum - padding, high = maximum + padding;
    double x(DateTime date) =>
        plot.left + date.difference(begin).inMilliseconds / span * plot.width;
    double y(double weight) =>
        plot.bottom - (weight - low) / (high - low) * plot.height;
    final grid =
        Paint()
          ..color = const Color(0xFFE5EEE1)
          ..strokeWidth = 1;
    text(kilograms ? 'kg' : 'lbs', const Offset(8, 0), color: blue);
    for (var i = 0; i <= 4; i++) {
      final weight = low + (high - low) * i / 4;
      final height = y(weight);
      canvas.drawLine(
        Offset(plot.left, height),
        Offset(plot.right, height),
        grid,
      );
      text(weight.toStringAsFixed(1), Offset(1, height - 6));
    }
    final axis =
        Paint()
          ..color = const Color(0xFFBACBB7)
          ..strokeWidth = 1;
    canvas.drawLine(plot.topLeft, plot.bottomLeft, axis);
    canvas.drawLine(plot.bottomLeft, plot.bottomRight, axis);
    for (var i = 0; i <= 3; i++) {
      final date = begin.add(Duration(milliseconds: (span * i / 3).round()));
      final dx = plot.left + plot.width * i / 3;
      canvas.drawLine(
        Offset(dx, plot.bottom),
        Offset(dx, plot.bottom + 5),
        axis,
      );
      text(
        DateFormat('MMM d').format(date),
        Offset(dx, plot.bottom + 12),
        centered: true,
      );
    }
    final line = Path();
    for (var i = 0; i < points.length; i++) {
      final point = Offset(x(points[i].date), y(display(points[i].weight)));
      if (i == 0) {
        line.moveTo(point.dx, point.dy);
      } else {
        line.lineTo(point.dx, point.dy);
      }
    }
    canvas.drawPath(
      line,
      Paint()
        ..color = green
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
    for (final log in points) {
      final point = Offset(x(log.date), y(display(log.weight)));
      canvas.drawCircle(point, 5, Paint()..color = Colors.white);
      canvas.drawCircle(point, 3.5, Paint()..color = green);
    }
    final latest = points.last;
    final labelY =
        (y(display(latest.weight)) - 19)
            .clamp(0.0, plot.bottom - 16)
            .toDouble();
    final labelX =
        x(latest.date).clamp(plot.left + 22, plot.right - 22).toDouble();
    text(
      '${display(latest.weight).toStringAsFixed(1)} ${kilograms ? 'kg' : 'lbs'}',
      Offset(labelX, labelY),
      color: green,
      centered: true,
    );
  }

  @override
  bool shouldRepaint(covariant _GoalChartPainter old) =>
      old.kilograms != kilograms ||
      old.start != start ||
      old.current != current ||
      old.target != target ||
      old.begin != begin ||
      old.end != end ||
      old.active != active ||
      old.logs != logs;
}
