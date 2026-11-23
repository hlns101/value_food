import 'widgets/navbar_widget.dart';
import 'widgets/dashboard_header.dart';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'monthly_page.dart';

const _green = Color(0xFF287D35);
const _lightGreen = Color(0xFF7DB848);
const _lime = Color(0xFF75B43E);
const _ink = Color(0xFF095574);
const _budgetBlue = Color(0xFF3981A3);
const _canvas = Color(0xFFF4F8F4);

class BudgetPage extends StatefulWidget {
  final String userId;
  const BudgetPage({super.key, required this.userId});

  @override
  State<BudgetPage> createState() => _BudgetPageState();
}

class _MealExpense {
  final DateTime date;
  final String name;
  final double amount;
  const _MealExpense(this.date, this.name, this.amount);

  // IMPORTANT: align these keys with the Dashboard team's Meal History schema.
  // Expected path: users/{userId}/mealHistory/{entryId}.
  static _MealExpense? fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final rawDate = data['date'] ?? data['eatenAt'] ?? data['createdAt'];
    DateTime? date;
    if (rawDate is Timestamp) date = rawDate.toDate();
    if (rawDate is DateTime) date = rawDate;
    if (rawDate is String) date = DateTime.tryParse(rawDate);
    if (date == null) return null;

    final rawAmount =
        data['totalCost'] ?? data['amount'] ?? data['price'] ?? data['cost'];
    final amount =
        rawAmount is num
            ? rawAmount.toDouble()
            : double.tryParse(rawAmount?.toString() ?? '');
    if (amount == null || !amount.isFinite || amount < 0) return null;
    final name =
        (data['mealName'] ??
                data['name'] ??
                data['foodName'] ??
                data['productName'] ??
                'Meal')
            .toString();
    return _MealExpense(date, name, amount);
  }
}

class _BudgetPageState extends State<BudgetPage> {
  bool _monthly = false;
  DateTime _selectedDay = DateUtils.dateOnly(DateTime.now());
  final _money = NumberFormat.currency(
    locale: 'en_PH',
    symbol: '₱',
    decimalDigits: 0,
  );

  late Stream<DocumentSnapshot<Map<String, dynamic>>> _userStream;
  late Stream<QuerySnapshot<Map<String, dynamic>>> _historyStream;

  @override
  void initState() {
    super.initState();
    _connectStreams();
  }

  void _connectStreams() {
    final user = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId);
    _userStream = user.snapshots();
    _historyStream = user.collection('mealHistory').snapshots();
  }

  @override
  void didUpdateWidget(covariant BudgetPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) _connectStreams();
  }

  double _number(dynamic raw) =>
      raw is num ? raw.toDouble() : double.tryParse(raw?.toString() ?? '') ?? 0;

  bool _sameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  double _spentOn(List<_MealExpense> expenses, DateTime day) => expenses
      .where((e) => _sameDate(e.date, day))
      .fold<double>(0, (sum, e) => sum + e.amount);

  double _spentBetween(
    List<_MealExpense> expenses,
    DateTime start,
    DateTime end,
  ) => expenses
      .where((e) => !e.date.isBefore(start) && e.date.isBefore(end))
      .fold<double>(0, (sum, e) => sum + e.amount);

  Color _status(double spent, double limit) {
    if (limit <= 0 || spent <= 0) return const Color(0xFFB8C7B5);
    if (spent > limit) return const Color(0xFFE24B44);
    if (spent >= limit * .8) return const Color(0xFFF09022);
    return _lime;
  }

  DateTime get _weekStart => DateTime(
    _selectedDay.year,
    _selectedDay.month,
    _selectedDay.day - _selectedDay.weekday % 7,
  );
  double _swipeDistance = 0;
  int _weekDirection = 1;

  void _changeWeek(int direction) => setState(() {
    _weekDirection = direction;
    _selectedDay = DateTime(
      _selectedDay.year,
      _selectedDay.month,
      _selectedDay.day + direction * 7,
    );
  });

  Widget _weekBrowser({required String title, required Widget child}) {
    final start = _weekStart;
    final end = DateTime(start.year, start.month, start.day + 6);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: (_) => _swipeDistance = 0,
      onHorizontalDragUpdate: (details) => _swipeDistance += details.delta.dx,
      onHorizontalDragEnd: (details) {
        if (_swipeDistance.abs() >= 35 ||
            (details.primaryVelocity ?? 0).abs() >= 250) {
          final direction =
              _swipeDistance.abs() >= 35
                  ? _swipeDistance
                  : details.primaryVelocity!;
          _changeWeek(direction < 0 ? 1 : -1);
        }
      },
      child: _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TextButton(
                  onPressed:
                      () => setState(() {
                        final today = DateUtils.dateOnly(DateTime.now());
                        _weekDirection = today.isBefore(_selectedDay) ? -1 : 1;
                        _selectedDay = today;
                      }),
                  style: TextButton.styleFrom(foregroundColor: _green),
                  child: const Text(
                    'This week',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                IconButton(
                  tooltip: 'Previous week',
                  onPressed: () => _changeWeek(-1),
                  icon: const Icon(Icons.chevron_left, color: _green),
                ),
                Expanded(
                  child: Text(
                    '${DateFormat('MMM d, yyyy').format(start)} – ${DateFormat('MMM d, yyyy').format(end)}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: _green,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Next week',
                  onPressed: () => _changeWeek(1),
                  icon: const Icon(Icons.chevron_right, color: _green),
                ),
              ],
            ),
            ClipRect(
              child: AnimatedSwitcher(
                duration:
                    MediaQuery.of(context).disableAnimations
                        ? Duration.zero
                        : const Duration(milliseconds: 280),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (content, animation) {
                  final incoming = content.key == ValueKey(start);
                  final offset = (incoming ? 1.0 : -1.0) * _weekDirection;
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: Offset(offset * .16, 0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: content,
                    ),
                  );
                },
                child: KeyedSubtree(key: ValueKey(start), child: child),
              ),
            ),
            const SizedBox(height: 10),
            const Center(
              child: Text(
                'Swipe left or right to change week',
                style: TextStyle(color: Colors.black45, fontSize: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _canvas,
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _userStream,
          builder: (context, userSnapshot) {
            final data = userSnapshot.data?.data() ?? <String, dynamic>{};
            final fullName =
                (data['name'] ??
                        data['fullName'] ??
                        data['firstName'] ??
                        'User')
                    .toString()
                    .trim();
            final firstName =
                fullName.isEmpty ? 'User' : fullName.split(' ').first;
            final monthlyLimit = _number(
              data['budget'] ?? data['monthlyLimit'],
            );
            final weeklyLimit =
                _number(data['weeklyLimit']) > 0
                    ? _number(data['weeklyLimit'])
                    : monthlyLimit / 4;
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _historyStream,
              builder: (context, historySnapshot) {
                final expenses =
                    historySnapshot.data?.docs
                        .map(_MealExpense.fromDocument)
                        .whereType<_MealExpense>()
                        .toList() ??
                    <_MealExpense>[];
                return Stack(
                  children: [
                    RefreshIndicator(
                      onRefresh: () async {
                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(widget.userId)
                            .get();
                      },
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(18, 20, 18, 130),
                        children: [
                          _header(firstName),
                          const SizedBox(height: 16),
                          _tabs(),
                          const SizedBox(height: 16),
                          if (userSnapshot.hasError || historySnapshot.hasError)
                            _notice(
                              'Could not load all budget information. Check your connection.',
                            ),
                          if (!historySnapshot.hasData &&
                              historySnapshot.connectionState ==
                                  ConnectionState.waiting)
                            const LinearProgressIndicator(color: _green),
                          if (_monthly) ...[
                            _monthOverview(monthlyLimit, expenses),
                            const SizedBox(height: 12),
                            _calendar(monthlyLimit, expenses),
                            const SizedBox(height: 10),
                            _dayDetails(expenses),
                            const SizedBox(height: 12),
                            _rhythm(weeklyLimit, monthlyLimit, expenses),
                          ] else ...[
                            _weekOverview(monthlyLimit, weeklyLimit, expenses),
                            const SizedBox(height: 12),
                            _calendar(monthlyLimit, expenses),
                            const SizedBox(height: 10),
                            _dayDetails(expenses),
                            const SizedBox(height: 12),
                            _statistics(monthlyLimit, expenses),
                          ],
                        ],
                      ),
                    ),
                    NavbarWidget(
                      userId: widget.userId,
                      activeTab: NavbarTab.budget,
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _header(String firstName) => DashboardHeader(
    name: firstName,
    pageTitle: 'Budget',
    subtitle: 'Helps you manage your food spending',
  );

  Widget _tabs() => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: const Color(0xFFE7F4E9),
      borderRadius: BorderRadius.circular(32),
    ),
    child: Row(
      children: [
        _tab('Weekly', !_monthly, () => setState(() => _monthly = false)),
        _tab('Monthly', _monthly, () => setState(() => _monthly = true)),
      ],
    ),
  );

  Widget _tab(String title, bool active, VoidCallback onTap) => Expanded(
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: active ? _green : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
        ),
        alignment: Alignment.center,
        child: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: active ? Colors.white : _green,
          ),
        ),
      ),
    ),
  );

  Widget _card({required Widget child, Color color = Colors.white}) =>
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(19),
          border: Border.all(color: Colors.white.withOpacity(0.28), width: 0.7),
        ),
        child: child,
      );

  Widget _statTile(String label, double value, {Color color = _green}) =>
      Expanded(
        child: Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 11, color: Colors.black54),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  _money.format(value),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _progress(
    double used,
    double limit, {
    Color track = const Color(0xFFB9DD9C),
  }) => ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: LinearProgressIndicator(
      value: limit > 0 ? (used / limit).clamp(0.0, 1.0) : 0,
      minHeight: 8,
      color: Colors.white,
      backgroundColor: track,
    ),
  );

  Widget _weekOverview(
    double monthlyLimit,
    double weeklyLimit,
    List<_MealExpense> expenses,
  ) {
    final start = _weekStart;
    final spent = _spentBetween(
      expenses,
      start,
      start.add(const Duration(days: 7)),
    );
    return _card(
      color: _lime,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Budget Overview',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _statTile('Monthly Limit', monthlyLimit),
              const SizedBox(width: 9),
              _statTile('Weekly Budget', weeklyLimit),
            ],
          ),
          const SizedBox(height: 11),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Spent: ${_money.format(spent)}',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
              Text(
                'Remaining: ${_money.format(math.max(0, weeklyLimit - spent))}',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _progress(spent, weeklyLimit),
        ],
      ),
    );
  }

  Widget _calendar(double monthlyLimit, List<_MealExpense> expenses) {
    final start = DateTime(_selectedDay.year, _selectedDay.month);
    final days = DateUtils.getDaysInMonth(start.year, start.month);
    final offset = start.weekday % 7;
    void changeMonth(int delta) {
      final month = DateTime(start.year, start.month + delta);
      final day = math.min(
        _selectedDay.day,
        DateUtils.getDaysInMonth(month.year, month.month),
      );
      setState(() => _selectedDay = DateTime(month.year, month.month, day));
    }

    return _card(
      child: Column(
        children: [
          const Text(
            'Spending Calendar',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          Row(
            children: [
              IconButton(
                tooltip: 'Previous month',
                onPressed: () => changeMonth(-1),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text(
                  DateFormat.yMMMM().format(start),
                  textAlign: TextAlign.center,
                ),
              ),
              IconButton(
                tooltip: 'Next month',
                onPressed: () => changeMonth(1),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          Row(
            children: List.generate(
              7,
              (i) => Expanded(
                child: Center(
                  child: Text(
                    ['S', 'M', 'T', 'W', 'T', 'F', 'S'][i],
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          for (var row = 0; row * 7 < offset + days; row++)
            Row(
              children: List.generate(7, (i) {
                final day = row * 7 + i - offset + 1;
                if (day < 1 || day > days) return const Spacer();
                final date = DateTime(start.year, start.month, day);
                final spent = _spentOn(expenses, date);
                final selected = _sameDate(date, _selectedDay);
                final dailyLimit =
                    monthlyLimit /
                    DateUtils.getDaysInMonth(date.year, date.month);
                return Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () => setState(() => _selectedDay = date),
                    child: SizedBox(
                      height: 52,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: selected ? _green : Colors.transparent,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '${date.day}',
                              style: TextStyle(
                                color: selected ? Colors.white : Colors.black87,
                                fontSize: 12,
                                fontWeight:
                                    selected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color:
                                  spent > 0
                                      ? _status(spent, dailyLimit)
                                      : Colors.transparent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 5,
            children: [
              _legend(_lime, 'Under Budget'),
              _legend(const Color(0xFFF09022), 'Near Limit'),
              _legend(const Color(0xFFE24B44), 'Over Budget'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legend(Color color, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      CircleAvatar(radius: 3, backgroundColor: color),
      const SizedBox(width: 5),
      Text(label, style: const TextStyle(fontSize: 10, color: Colors.black54)),
    ],
  );

  Widget _dayDetails(List<_MealExpense> expenses) {
    final items =
        expenses.where((e) => _sameDate(e.date, _selectedDay)).toList();
    final total = items.fold<double>(0, (sum, e) => sum + e.amount);
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('EEEE, MMM d').format(_selectedDay),
                style: const TextStyle(
                  color: _ink,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE9F6E9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_money.format(total)} spent',
                  style: const TextStyle(
                    color: _green,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          if (items.isEmpty)
            const Text(
              'No meals logged for this day.',
              style: TextStyle(color: Colors.black45, fontSize: 12),
            )
          else
            ...items.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(
                  children: [
                    const Icon(
                      Icons.restaurant_rounded,
                      size: 14,
                      color: _green,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        e.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    Text(
                      _money.format(e.amount),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _green,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _statistics(double monthlyLimit, List<_MealExpense> expenses) {
    final start = _weekStart;
    final days = List.generate(
      7,
      (i) => DateTime(start.year, start.month, start.day + i),
    );
    final targets =
        days
            .map(
              (date) =>
                  monthlyLimit /
                  DateUtils.getDaysInMonth(date.year, date.month),
            )
            .toList();
    final values = days.map((date) => _spentOn(expenses, date)).toList();
    final ceiling = math.max(
      targets.fold<double>(0, math.max),
      values.fold<double>(0, math.max),
    );
    return _weekBrowser(
      title: 'Weekly Statistics',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Weekly spending: ${_money.format(values.fold<double>(0, (total, value) => total + value))}',
            style: const TextStyle(
              color: _green,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 128,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (i) {
                final height = ceiling <= 0 ? 0.0 : values[i] / ceiling * 63;
                return Expanded(
                  child: Tooltip(
                    message:
                        '${DateFormat('MMM d').format(days[i])}: ${_money.format(values[i])} / ${_money.format(targets[i])} daily target',
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        FittedBox(
                          child: Text(
                            _money.format(values[i]),
                            style: const TextStyle(color: _green, fontSize: 9),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Container(
                          height: math.max(3.0, height),
                          width: 19,
                          decoration: BoxDecoration(
                            color:
                                values[i] == 0
                                    ? const Color(0xFFE4EFE4)
                                    : _status(values[i], targets[i]),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          ['S', 'M', 'T', 'W', 'T', 'F', 'S'][i],
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 10,
                          ),
                        ),
                        Text(
                          '${days[i].day}',
                          style: const TextStyle(
                            color: Colors.black45,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _monthOverview(double monthlyLimit, List<_MealExpense> expenses) {
    final first = DateTime(_selectedDay.year, _selectedDay.month);
    final spent = _spentBetween(
      expenses,
      first,
      DateTime(first.year, first.month + 1),
    );
    final progress = monthlyLimit > 0 ? spent / monthlyLimit : 0.0;
    return _card(
      color: _lime,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${DateFormat('MMMM yyyy').format(first)} Overview',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed:
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MonthlyPage(userId: widget.userId),
                      ),
                    ),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.white24,
                  visualDensity: VisualDensity.compact,
                ),
                label: const Text('Edit'),
                icon: const Icon(Icons.edit, size: 13),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _statTile('Total Spent', spent, color: const Color(0xFF287FAD)),
              const SizedBox(width: 9),
              _statTile('Remaining', math.max(0, monthlyLimit - spent)),
            ],
          ),
          const SizedBox(height: 13),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Limit: ${_money.format(monthlyLimit)}',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
              Text(
                '${(progress * 100).toStringAsFixed(0)}% Used',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _progress(spent, monthlyLimit),
        ],
      ),
    );
  }

  Widget _rhythm(
    double weeklyLimit,
    double monthlyLimit,
    List<_MealExpense> expenses,
  ) {
    final first = DateTime(_selectedDay.year, _selectedDay.month);
    final monthEnd = DateTime(first.year, first.month + 1);
    final now = DateTime.now();
    final monthSpent = _spentBetween(expenses, first, monthEnd);
    final daysInMonth = monthEnd.difference(first).inDays;
    final elapsedDays = now.difference(first).inDays + 1;
    final projectedSpent =
        monthSpent / elapsedDays.clamp(1, daysInMonth) * daysInMonth;
    final projectedSavings = monthlyLimit - projectedSpent;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '4-Week Spending Rhythm',
            style: TextStyle(
              fontSize: 15,
              color: _ink,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            'Target: ${_money.format(weeklyLimit)} / week',
            style: const TextStyle(color: Colors.black45, fontSize: 11),
          ),
          const SizedBox(height: 13),
          ...List.generate(4, (i) {
            final start = first.add(Duration(days: i * 7));
            final end =
                i == 3 ? monthEnd : first.add(Duration(days: (i + 1) * 7));
            final spent = _spentBetween(expenses, start, end);
            final current = !now.isBefore(start) && now.isBefore(end);
            final future = now.isBefore(start);
            final diff = weeklyLimit - spent;
            return Container(
              margin: const EdgeInsets.only(bottom: 9),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: current ? const Color(0xFFF0F8E8) : Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Week ${i + 1} (${DateFormat('MMM d').format(start)}–${DateFormat('d').format(end.subtract(const Duration(days: 1)))})${current ? ' • Current' : ''}',
                          style: TextStyle(
                            color: current ? _green : _ink,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(
                        future
                            ? '${_money.format(weeklyLimit)} budget'
                            : _money.format(spent),
                        style: TextStyle(
                          fontSize: 11,
                          color: future ? Colors.black45 : _green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value:
                          weeklyLimit > 0
                              ? (spent / weeklyLimit).clamp(0.0, 1.0)
                              : 0,
                      minHeight: 7,
                      backgroundColor: const Color(0xFFE7F1E0),
                      color: _status(spent, weeklyLimit),
                    ),
                  ),
                  if (!future && weeklyLimit > 0) ...[
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        diff >= 0
                            ? '${_money.format(diff)} under target'
                            : '${_money.format(-diff)} over target',
                        style: const TextStyle(
                          color: Colors.black45,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
          const Divider(),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF5FAF5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.circle, color: _green, size: 9),
                const SizedBox(width: 8),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(
                          text: 'Forecast: End month at ',
                          style: TextStyle(color: _ink),
                        ),
                        TextSpan(
                          text: _money.format(projectedSpent),
                          style: const TextStyle(
                            color: _green,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        TextSpan(
                          text:
                              projectedSavings >= 0
                                  ? ' (Saving ${_money.format(projectedSavings)}!)'
                                  : ' (Over budget by ${_money.format(-projectedSavings)})',
                          style: TextStyle(
                            color:
                                projectedSavings >= 0 ? _ink : Colors.redAccent,
                          ),
                        ),
                      ],
                    ),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _notice(String message) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      message,
      style: const TextStyle(color: Colors.redAccent, fontSize: 12),
    ),
  );

  // A frosted, floating navigation bar with translucent highlights and
  // background blur, inspired by iOS liquid-glass surfaces.
}
