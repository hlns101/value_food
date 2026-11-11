import 'widgets/dashboard_header.dart';
import 'dart:ui';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'utils/page_transitions.dart';
import 'dashboard_page.dart';
import 'budget_page.dart';
import 'label_page.dart';
import 'profile_page.dart';

class GoalsPage extends StatefulWidget {
  final String userId;
  const GoalsPage({super.key, required this.userId});
  @override
  State<GoalsPage> createState() => _GoalsPageState();
}

class _GoalsPageState extends State<GoalsPage> {
  static const green = Color(0xFF287D35);
  static const Color _green = Color(0xFF287D35);
  static const lime = Color(0xFF7DB848);
  static const blue = Color(0xFF176084);
  static const bg = Color(0xFFF6FAF6);
  final peso = NumberFormat.currency(locale: 'en_PH', symbol: '₱', decimalDigits: 0);
  final dateFormat = DateFormat('MMM d, yyyy');
  DocumentReference<Map<String, dynamic>> get userRef => FirebaseFirestore.instance.collection('users').doc(widget.userId);
  CollectionReference<Map<String, dynamic>> get logRef => userRef.collection('weightLogs');
  double? number(dynamic value) => value is num ? value.toDouble() : double.tryParse('$value');
  DateTime? date(dynamic value) => value is Timestamp ? value.toDate() : value is DateTime ? value : DateTime.tryParse('$value');
  void go(Widget page) => Navigator.pushReplacement(context,
      MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: bg,
    body: Stack(children: [
      SafeArea(bottom: false, child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: userRef.snapshots(),
        builder: (context, profileSnap) {
          final user = profileSnap.data?.data() ?? <String, dynamic>{};
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: logRef.snapshots(),
            builder: (context, logsSnap) {
              final logs = logsSnap.data?.docs.map((d) {
                final data = d.data();
                return _WeightLog(number(data['weightLbs']) ?? ((number(data['weight']) ?? 0) * 2.2046226218),
                    date(data['date']) ?? DateTime(2000));
              }).where((e) => e.weight > 0).toList() ?? <_WeightLog>[];
              logs.sort((a,b) => a.date.compareTo(b.date));
              final goal = user['weightGoal'] is Map ? Map<String, dynamic>.from(user['weightGoal'] as Map) : <String, dynamic>{};
              final start = number(goal['startWeight']) ?? ((number(user['weight']) ?? 0) * 2.2046226218);
              final current = logs.isNotEmpty ? logs.last.weight : ((number(user['weight']) ?? 0) * 2.2046226218);
              final target = number(goal['targetWeight']) ?? 0;
              final weeks = (number(goal['weeks']) ?? 8).round().clamp(1, 104);
              final startDate = date(goal['startDate']) ?? DateTime.now();
              final deadline = date(goal['targetDate']) ?? startDate.add(Duration(days: weeks * 7));
              final monthly = number(user['budget'] ?? user['monthlyLimit']) ?? 0;
              final dailyBudget = monthly / DateUtils.getDaysInMonth(DateTime.now().year,
                  DateTime.now().month);
              final hasGoal = start > 0 && target > 0 && target < start;
              final initialLoss = hasGoal ? math.max(0.0, start - target) : 0.0;
              final lost = hasGoal ? (start - current).clamp(0.0,
                  initialLoss).toDouble() : 0.0;
              final remaining = hasGoal ? math.max(0.0, current - target) : 0.0;
              final timelineWeeks = math.max(1.0, deadline.difference(startDate).inDays / 7.0);
              final weekly = hasGoal ? initialLoss / timelineWeeks : 0.0;
              final progress = initialLoss > 0 ? (lost / initialLoss).clamp(0.0, 1.0) : 0.0;
              final planLabel = !hasGoal ? 'Set a weight-loss goal' : weekly <= 1.0 ? 'Gradual pace' : 'Review your timeline';
              return ListView(padding: EdgeInsets.fromLTRB(16, 22, 16,
                  150 + MediaQuery.of(context).padding.bottom), children: [
                _header(user['firstName']?.toString() ?? user['name']?.toString() ?? 'User'),
                const SizedBox(height: 17),
                _goalCard(start, current, target, remaining, lost, initialLoss, progress,
                    hasGoal, () => _editGoal(user, goal, current)),
                const SizedBox(height: 14),
                _timelineCard(start, current, target, startDate, deadline, logs, hasGoal),
                const SizedBox(height: 14),
                _planCard(weekly, weeks, dailyBudget, planLabel, hasGoal, user),
                const SizedBox(height: 15),
                SizedBox(height: 48, child: ElevatedButton.icon(
                  onPressed: () => _logWeight(current),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text("Log Today's Weight"),
                  style: ElevatedButton.styleFrom(backgroundColor: green,
                      foregroundColor: Colors.white, shape: const StadiumBorder()),
                )),
                if (profileSnap.hasError || logsSnap.hasError) ...[
                  const SizedBox(height: 12),
                  Text(
                    profileSnap.hasError
                        ? 'Unable to load your profile. Check access to users/{userId}.'
                        : 'Unable to load weight history. Check access to users/{userId}/weightLogs.',
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ],
              ]);
            },
          );
        },
      )),
      _glassNavigation(),
    ]),
  );

  Widget _header(String name) => DashboardHeader(
    name: name,
    pageTitle: 'Goals',
    subtitle: 'Track weight progress & daily calorie pace',
  );

  Widget _goalCard(double start, double current, double target, double remaining,
      double lost, double total, double progress, bool hasGoal, VoidCallback edit) =>
    Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: lime,
        borderRadius: BorderRadius.circular(18)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [const Expanded(child: Text('Weight Loss Goal',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800))),
        TextButton.icon(onPressed: edit, icon: const Icon(Icons.edit, size: 14),
            label: const Text('Edit'),
          style: TextButton.styleFrom(foregroundColor: Colors.white,
              backgroundColor: Colors.white24, visualDensity: VisualDensity.compact))]),
      const SizedBox(height: 12),
      Row(children: [
        _metric('Current', current > 0 ? current.toStringAsFixed(1) : '—', 'lbs'),
            const SizedBox(width: 7),
        _metric('Target', hasGoal ? target.toStringAsFixed(1) : '—', 'lbs'),
            const SizedBox(width: 7),
        _metric('To Lose', hasGoal ? remaining.toStringAsFixed(1) : '—', 'lbs'),
      ]),
      const SizedBox(height: 15),
      Text(hasGoal ? 'Progress: ${lost.toStringAsFixed(1)} of ${total.toStringAsFixed(1)} lbs' : 'Set your target weight to begin',
          style: const TextStyle(color: Colors.white, fontSize: 11)),
      const SizedBox(height: 6),
      ClipRRect(borderRadius: BorderRadius.circular(15),
          child: LinearProgressIndicator(value: progress, minHeight: 9, color: Colors.white,
          backgroundColor: Colors.white38)),
      const SizedBox(height: 3),
      Align(alignment: Alignment.centerRight, child: Text('${(progress*100).round()}%',
          style: const TextStyle(color: Colors.white, fontSize: 10,
          fontWeight: FontWeight.w700))),
    ]));

  Widget _metric(String title, String amount, String unit) => Expanded(child: Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 12),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(9)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(color: Colors.black54, fontSize: 10)),
      const SizedBox(height: 4),
      FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
          child: Text('$amount $unit', style: const TextStyle(fontSize: 16,
          fontWeight: FontWeight.w800, color: blue))),
    ]),
  ));

  Widget _timelineCard(double start, double current, double target, DateTime startDate,
      DateTime deadline, List<_WeightLog> logs,
      bool hasGoal) => _whiteCard(Column(crossAxisAlignment: CrossAxisAlignment.start,
      children: [
    Row(children: [const Icon(Icons.calendar_month, size: 18, color: green),
        const SizedBox(width: 8),
      const Expanded(child: Text('Timeline & Glide Path', style: TextStyle(color: blue,
          fontSize: 15, fontWeight: FontWeight.w800))),
      if (hasGoal) Text('${math.max(0, deadline.difference(DateTime.now()).inDays)} Days Left',
          style: const TextStyle(color: green, fontSize: 10))]),
    const SizedBox(height: 16),
    SizedBox(height: 150, width: double.infinity,
        child: CustomPaint(painter: _GoalChartPainter(
      start: start, current: current, target: target, logs: logs, begin: startDate,
          end: deadline, active: hasGoal))),
    const SizedBox(height: 9),
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text('Today (${current.toStringAsFixed(1)} lbs)', style: const TextStyle(color: blue,
          fontSize: 10)),
      Text(hasGoal ? '${dateFormat.format(deadline)} (${target.toStringAsFixed(1)} lbs)' : 'No target yet',
          style: const TextStyle(color: green, fontSize: 10)),
    ]),
    const Divider(height: 20),
    Text(hasGoal ? 'Target Date: ${dateFormat.format(deadline)}' : 'Tap Edit to choose your target and timeline',
        style: const TextStyle(fontSize: 11, color: Colors.black54)),
  ]));

  Widget _planCard(double weekly, int weeks, double dailyBudget, String planLabel,
      bool hasGoal, Map<String, dynamic> user) {
    final calories = _estimatedCalories(user, weekly);
    return _whiteCard(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [const Icon(Icons.show_chart, size: 18, color: green),
          const SizedBox(width: 8),
        const Expanded(child: Text('Recommended Plan', style: TextStyle(color: blue,
            fontSize: 15, fontWeight: FontWeight.w800))),
        Text(planLabel, style: const TextStyle(color: green, fontSize: 10))]),
      const SizedBox(height: 12),
      Container(padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(color: const Color(0xFFEDF7E8),
          borderRadius: BorderRadius.circular(12)),
        child: Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          const Text('WEEKLY LOSS TARGET', style: TextStyle(color: Colors.black45,
              fontSize: 9)),
          const SizedBox(height: 3),
          Text(hasGoal ? '${weekly.toStringAsFixed(1)} lbs / week' : 'Not set',
              style: const TextStyle(color: green, fontSize: 18,
              fontWeight: FontWeight.w800)),
          Text(hasGoal ? '$weeks-week target timeline' : 'Edit your goal to calculate a plan',
              style: const TextStyle(fontSize: 10, color: Colors.black54)),
        ])), const Icon(Icons.check_circle, color: green, size: 20)])),
      if (weekly > 2) ...[const SizedBox(height: 7),
          const Text('This target is faster than 2 lbs/week. Consider a longer timeline and seek professional guidance.',
          style: TextStyle(color: Colors.deepOrange, fontSize: 11))],
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: _planStat('Daily Calorie Estimate',
            calories == null ? 'Not available' : '${calories.round()} kcal',
          'General estimate; not a prescription')),
        const SizedBox(width: 8),
        Expanded(child: _planStat('Food Budget Cap',
            dailyBudget > 0 ? '${peso.format(dailyBudget)}/day' : 'Not set',
            'Based on monthly budget')),
      ]),
    ]));
  }

  Widget _planStat(String title, String value,
      String detail) => Container(padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: const Color(0xFFF6F9F5),
        borderRadius: BorderRadius.circular(10)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(color: Colors.black54, fontSize: 9)),
      const SizedBox(height: 4), Text(value, style: const TextStyle(color: blue,
          fontSize: 13, fontWeight: FontWeight.w800)),
      const SizedBox(height: 3), Text(detail, style: const TextStyle(fontSize: 8,
          color: Colors.black45)),
    ]));

  // Mifflin-St Jeor estimates resting energy expenditure. Only apply the
  // activity multiplier when required profile inputs are available.
  double? _estimatedCalories(Map<String, dynamic> user, double weeklyLoss) {
    final age = number(user['age']);
    final kg = number(user['weight']);
    final cm = number(user['height']);
    final sex = '${user['sex'] ?? ''}'.toLowerCase();
    if (age == null || age < 18 || kg == null || kg <= 0 || cm == null || cm <= 0 || (sex != 'male' && sex != 'female')) return null;
    final bmr = 10*kg + 6.25*cm - 5*age + (sex == 'male' ? 5 : -161);
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

  Widget _whiteCard(Widget child) => Container(width: double.infinity,
      padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(color: Colors.white,
        border: Border.all(color: const Color(0xFFE2EDE2)),
        borderRadius: BorderRadius.circular(18)), child: child);

  Future<void> _editGoal(Map<String, dynamic> user, Map<String, dynamic> goal,
      double current) async {
    final target = await showModalBottomSheet<_GoalInput>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _GoalEditor(
        current: current,
        estimatedCalories: _estimatedCalories(user, 0),
        dailyBudget: (number(user['budget'] ?? user['monthlyLimit']) ?? 0) /
            DateUtils.getDaysInMonth(DateTime.now().year, DateTime.now().month),
        target: number(goal['targetWeight']),
        targetDate: date(goal['targetDate']) ??
            (date(goal['startDate']) ?? DateTime.now()).add(
              Duration(days: (number(goal['weeks']) ?? 8).round() * 7),
            ),
      ),
    );
    if (target == null) return;
    try {
      await userRef.set({'weightGoal': {
        'startWeight': current,
        'targetWeight': target.target,
        'weeks': (target.targetDate.difference(DateTime.now()).inDays / 7).ceil().clamp(1, 104),
        'targetDate': Timestamp.fromDate(target.targetDate),
        'startDate': Timestamp.fromDate(DateTime.now()),
      }}, SetOptions(merge: true));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unable to save goal. Check your connection and Firestore rules.')));
    }
  }

  Future<void> _logWeight(double current) async {
    final newWeight = await showDialog<double>(context: context,
        builder: (_) => _LogWeightDialog(initial: current));
    if (newWeight == null) return;
    try {
      await logRef.add({'weightLbs': newWeight, 'date': Timestamp.now()});
      // Maintain user's current weight for existing profile screens.
      await userRef.set({'weight': newWeight / 2.2046226218}, SetOptions(merge: true));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not log weight. Check Firestore permissions.')));
    }
  }

  void _navigate(Widget page) {
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      SmoothPageRoute(page: page),
    );
  }

  Widget _glassNavigation() => Positioned(
    left: 15,
    right: 15,
    bottom: 12 + MediaQuery.of(context).padding.bottom,
    child: SizedBox(
      height: 96,
      child: Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: [
          // Main transparent glass capsule
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 68,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(38),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF287D35).withOpacity(0.10),
                    blurRadius: 22,
                    spreadRadius: -5,
                    offset: const Offset(0, 7),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(38),
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: 3,
                    sigmaY: 3,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(38),

                      // Transparent glass gradient
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withOpacity(0.10),
                          Colors.white.withOpacity(0.03),
                          Colors.white.withOpacity(0.08),
                        ],
                      ),

                      // Subtle glass border
                      border: Border.all(
                        color: Colors.white.withOpacity(0.20),
                        width: 0.5,
                      ),
                    ),
                    child: Stack(
                      children: [
                        Row(
                          children: [
                            _navItem(
                              Icons.home_rounded,
                              'home',
                              false,
                              () => _navigate(
                                DashboardPage(userId: widget.userId),
                              ),
                            ),

                            _navItem(
                              Icons.savings_rounded,
                              'budget',
                              false,
                              () => _navigate(
                                BudgetPage(userId: widget.userId),
                              ),
                            ),

                            const Expanded(child: SizedBox()),

                            _navItem(
                              Icons.flag_rounded,
                              'goals',
                              true,
                              () {},
                            ),

                            _navItem(
                              Icons.person_rounded,
                              'profile',
                              false,
                              () => _navigate(
                                ProfilePage(userId: widget.userId),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Floating Scan Label button
          Positioned(
            top: 0,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => LabelPage(userId: widget.userId),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 61,
                    height: 61,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withOpacity(0.85),
                          const Color(0xFFDEF3E6).withOpacity(0.55),
                        ],
                      ),
                      border: Border.all(
                        color: _green,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF287D35).withOpacity(0.10),
                          blurRadius: 22,
                          spreadRadius: -5,
                          offset: const Offset(0, 7),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Image.asset(
                        'assets/icons/scan_icon.png',
                        height: 29,
                        color: _green,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(
                          Icons.qr_code_scanner_rounded,
                          color: _green,
                          size: 29,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 3),

                  const Text(
                    'SCAN LABEL',
                    style: TextStyle(
                      fontSize: 8,
                      color: _green,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.35,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );  

  Widget _navItem(IconData icon, String label, bool active,
      VoidCallback tap) => Expanded(child: InkWell(onTap: tap,
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(icon, size: 23, color: active ? const Color(0xFF2987B0) : green),
      Text(label, style: TextStyle(fontSize: 10,
          color: active ? const Color(0xFF2987B0) : green)),
    ])));
}

class _WeightLog {
  final double weight;
  final DateTime date;
  const _WeightLog(this.weight, this.date);
}

class _GoalInput {
  final double target;
  final DateTime targetDate;

  const _GoalInput({
    required this.target,
    required this.targetDate,
  });
}

class _GoalEditor extends StatefulWidget {
  final double current;
  final double? target;
  final DateTime targetDate;
  final double? estimatedCalories;
  final double dailyBudget;

  const _GoalEditor({
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

  late double _target;
  late DateTime _targetDate;
  int? _selectedPreset;

  @override
  void initState() {
    super.initState();
    _target = (widget.target != null && widget.target! > 0)
        ? widget.target!
        : widget.current > 0 ? widget.current - 10 : 0;
    _targetDate = widget.targetDate.isAfter(DateTime.now())
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
      _target = (_target + step).clamp(1.0, widget.current - 0.1);
      _target = (10 * _target).roundToDouble() / 10;
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
    final initial = _targetDate.isBefore(first)
        ? first
        : (_targetDate.isAfter(last) ? last : _targetDate);

    final chosen = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
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
    final percentLoss = widget.current > 0
        ? (totalLoss / widget.current) * 100
        : 0.0;
    final healthyPace = weeklyLoss > 0 && weeklyLoss <= 2;
    final calorieNote = widget.estimatedCalories == null
        ? 'Not available'
        : '${widget.estimatedCalories!.round()} kcal/day';
    final budgetNote = widget.dailyBudget > 0
        ? '₱${widget.dailyBudget.toStringAsFixed(0)}/day'
        : 'Not set';

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
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
                        child: const Text(
                          'LBS',
                          style: TextStyle(
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
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: _paleGreen,
                            borderRadius: BorderRadius.circular(19),
                            border: Border.all(color: const Color(0xFFE0EDE0)),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('DESIRED WEIGHT',
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800,
                                      color: Colors.black54)),
                                  Text('Current: ${widget.current.toStringAsFixed(1)} lbs',
                                    style: const TextStyle(fontSize: 10, color: Colors.black54)),
                                ],
                              ),
                              const SizedBox(height: 13),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  _stepButton(Icons.remove, () => _changeTarget(-0.5)),
                                  Text.rich(
                                    TextSpan(
                                      children: [
                                        TextSpan(
                                          text: _target.toStringAsFixed(1),
                                          style: const TextStyle(fontSize: 30,
                                            color: Color(0xFF3981A3), fontWeight: FontWeight.w900),
                                        ),
                                        const TextSpan(text: ' lbs', style: TextStyle(
                                          color: Colors.black54, fontSize: 13)),
                                      ],
                                    ),
                                  ),
                                  _stepButton(Icons.add, () => _changeTarget(0.5)),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                '${totalLoss.toStringAsFixed(1)} lbs total loss '
                                '(-${percentLoss.toStringAsFixed(1)}% body weight)',
                                style: const TextStyle(color: _green,
                                  fontSize: 11, fontWeight: FontWeight.w800),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: const [
                            Text('Target Timeline', style: TextStyle(
                              fontSize: 13, color: _blue, fontWeight: FontWeight.w800)),
                            Text('Tap preset or pick date', style: TextStyle(
                              fontSize: 10, color: Colors.black45)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(children: [
                          _preset('6 Weeks', 42),
                          const SizedBox(width: 7),
                          _preset('60 Days', 60),
                          const SizedBox(width: 7),
                          _preset('12 Weeks', 84),
                        ]),
                        const SizedBox(height: 11),
                        InkWell(
                          onTap: _chooseDate,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              color: _paleGreen,
                              border: Border.all(color: const Color(0xFFE0EDE0)),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(children: [
                              const Icon(Icons.calendar_month_outlined, color: _green, size: 20),
                              const SizedBox(width: 9),
                              Expanded(child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Target Completion Date', style: TextStyle(
                                    fontSize: 10, color: Colors.black54)),
                                  Text(DateFormat('MMMM d, yyyy').format(_targetDate),
                                    style: const TextStyle(color: _blue,
                                      fontSize: 13, fontWeight: FontWeight.w800)),
                                ],
                              )),
                              const Text('Change', style: TextStyle(
                                color: _green, fontSize: 11, fontWeight: FontWeight.w700)),
                              const Icon(Icons.chevron_right, color: _green, size: 18),
                            ]),
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
                              Row(children: [
                                const Icon(Icons.check_circle, color: _green, size: 20),
                                const SizedBox(width: 9),
                                Expanded(child: Text(
                                  '${weeklyLoss.toStringAsFixed(1)} lbs / week · '
                                  '${healthyPace ? 'Healthy Rate' : 'Review Timeline'}',
                                  style: const TextStyle(color: _green,
                                    fontSize: 13, fontWeight: FontWeight.w800),
                                )),
                              ]),
                              const SizedBox(height: 4),
                              Text(
                                healthyPace
                                  ? 'Within a gradual weight-loss range (up to 2 lbs/week)'
                                  : 'Consider a longer timeline or consult a qualified professional.',
                                style: const TextStyle(fontSize: 10, color: Colors.black54),
                              ),
                              const Divider(height: 24),
                              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                const Text('Daily Calorie Estimate', style: TextStyle(
                                  fontSize: 10, color: Colors.black54)),
                                Flexible(child: Text(calorieNote, textAlign: TextAlign.right,
                                  style: const TextStyle(fontSize: 10, color: _blue,
                                    fontWeight: FontWeight.w700))),
                              ]),
                              const SizedBox(height: 7),
                              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                const Text('Synced Food Budget Cap', style: TextStyle(
                                  fontSize: 10, color: Colors.black54)),
                                Text(budgetNote, style: const TextStyle(
                                  fontSize: 10, color: _green, fontWeight: FontWeight.w700)),
                              ]),
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
                          onPressed: widget.current <= 0 || _target <= 0 ||
                                  _target >= widget.current
                              ? null
                              : () => Navigator.pop(context, _GoalInput(
                                  target: _target,
                                  targetDate: _targetDate,
                                )),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _green,
                            foregroundColor: Colors.white,
                            shape: const StadiumBorder(),
                          ),
                          child: const Text('Save Weight Goal', style: TextStyle(
                            fontWeight: FontWeight.w800)),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel', style: TextStyle(
                          color: Colors.black54, fontSize: 11)),
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
            border: Border.all(color: selected ? _green : const Color(0xFFE1EAE1)),
          ),
          child: Text(text, style: TextStyle(
            color: selected ? Colors.white : Colors.black45,
            fontSize: 11,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
          )),
        ),
      ),
    );
  }
}

class _LogWeightDialog extends StatefulWidget {
  final double initial;
  const _LogWeightDialog({required this.initial});
  @override
  State<_LogWeightDialog> createState() => _LogWeightDialogState();
}
class _LogWeightDialogState extends State<_LogWeightDialog> {
  late final TextEditingController controller;
  @override
  void initState() { super.initState(); controller = TextEditingController(text: widget.initial > 0 ? widget.initial.toStringAsFixed(1) : ''); }
  @override
  void dispose() { controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text("Log Today's Weight"),
    content: TextField(controller: controller, autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
      decoration: const InputDecoration(labelText: 'Weight (lbs)',
          border: OutlineInputBorder())),
    actions: [TextButton(onPressed: () => Navigator.pop(context),
        child: const Text('Cancel')),
      FilledButton(onPressed: () {
        final weight = double.tryParse(controller.text);
        if (weight == null || weight <= 0) return;
        Navigator.pop(context, weight);
      }, child: const Text('Save'))],
  );
}

class _GoalChartPainter extends CustomPainter {
  final double start, current, target;
  final DateTime begin, end;
  final List<_WeightLog> logs;
  final bool active;
  const _GoalChartPainter({required this.start, required this.current, required this.target,
      required this.logs, required this.begin, required this.end, required this.active});
  @override
  void paint(Canvas canvas, Size size) {
    final x0 = 17.0, x1 = size.width - 14, y0 = 16.0, y1 = size.height - 20;
    final grid = Paint()..color = const Color(0xFFE8EFE8)..strokeWidth = 1;
    for (var i=0;i<=3;i++) { final y = y0 + (y1-y0)*i/3; canvas.drawLine(Offset(x0,y),
        Offset(x1,y), grid); }
    if (!active) return;
    final low = math.min(target, math.min(current, start)) - 2;
    final high = math.max(start, math.max(current, target)) + 2;
    double fy(double weight) => y1 - ((weight-low)/(high-low))*(y1-y0);
    double fx(DateTime day) => x0 + ((day.difference(begin).inMinutes / math.max(1,
        end.difference(begin).inMinutes)).clamp(0.0,1.0))*(x1-x0);
    final line = Paint()..color=const Color(0xFF287D35)..strokeWidth=2..style=PaintingStyle.stroke;
    final dashed = Paint()..color=const Color(0xFF287D35)..strokeWidth=1.5;
    final startPoint = Offset(x0,fy(start)); final goalPoint=Offset(x1,fy(target));
    const pieces=18;
    for (var i=0;i<pieces;i+=2) {
      final a=i/pieces,b=(i+1)/pieces;
      canvas.drawLine(Offset(startPoint.dx+(goalPoint.dx-startPoint.dx)*a,
          startPoint.dy+(goalPoint.dy-startPoint.dy)*a),
        Offset(startPoint.dx+(goalPoint.dx-startPoint.dx)*b,
            startPoint.dy+(goalPoint.dy-startPoint.dy)*b),dashed);
    }
    if (logs.isNotEmpty) {
      final path = Path()..moveTo(startPoint.dx,startPoint.dy);
      for (final entry in logs) {path.lineTo(fx(entry.date),fy(entry.weight));}
      canvas.drawPath(path,line);
    }
    final circle = Paint()..color=Colors.white..style=PaintingStyle.fill;
    final outline = Paint()..color=const Color(0xFF287D35)..style=PaintingStyle.stroke..strokeWidth=2;
    for (final p in [startPoint,goalPoint]) { canvas.drawCircle(p,4,
        circle); canvas.drawCircle(p,4,outline); }
  }
  @override
  bool shouldRepaint(covariant _GoalChartPainter old) => true;
}
