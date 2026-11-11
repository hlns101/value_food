import 'widgets/dashboard_header.dart';
import 'dart:math' as math;
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'utils/page_transitions.dart';
import 'dashboard_page.dart';
import 'goals_page.dart';
import 'label_page.dart';
import 'monthly_page.dart';
import 'profile_page.dart';

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
  static _MealExpense? fromDocument(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final rawDate = data['date'] ?? data['eatenAt'] ?? data['createdAt'];
    DateTime? date;
    if (rawDate is Timestamp) date = rawDate.toDate();
    if (rawDate is DateTime) date = rawDate;
    if (rawDate is String) date = DateTime.tryParse(rawDate);
    if (date == null) return null;

    final rawAmount = data['totalCost'] ?? data['amount'] ?? data['price'] ?? data['cost'];
    final amount = rawAmount is num
        ? rawAmount.toDouble()
        : double.tryParse(rawAmount?.toString() ?? '');
    if (amount == null || !amount.isFinite || amount < 0) return null;
    final name = (data['mealName'] ?? data['name'] ?? data['foodName'] ??
            data['productName'] ?? 'Meal')
        .toString();
    return _MealExpense(date, name, amount);
  }
}

class _BudgetPageState extends State<BudgetPage> {
  bool _monthly = false;
  DateTime _calendarMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selectedDay = DateUtils.dateOnly(DateTime.now());
  final _money = NumberFormat.currency(locale: 'en_PH', symbol: '₱', decimalDigits: 0);

  Stream<DocumentSnapshot<Map<String, dynamic>>> get _userStream =>
      FirebaseFirestore.instance.collection('users').doc(widget.userId).snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> get _historyStream =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('mealHistory')
          .snapshots();

  double _number(dynamic raw) => raw is num
      ? raw.toDouble()
      : double.tryParse(raw?.toString() ?? '') ?? 0;

  bool _sameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  double _spentOn(List<_MealExpense> expenses, DateTime day) => expenses
      .where((e) => _sameDate(e.date, day))
      .fold<double>(0, (sum, e) => sum + e.amount);

  double _spentBetween(List<_MealExpense> expenses, DateTime start, DateTime end) =>
      expenses.where((e) => !e.date.isBefore(start) && e.date.isBefore(end))
          .fold<double>(0, (sum, e) => sum + e.amount);

  Color _status(double spent, double limit) {
    if (limit <= 0 || spent <= 0) return const Color(0xFFB8C7B5);
    if (spent > limit) return const Color(0xFFE24B44);
    if (spent >= limit * .8) return const Color(0xFFF09022);
    return _lime;
  }

  void _changeMonth(int direction) {
    setState(() {
      _calendarMonth = DateTime(_calendarMonth.year, _calendarMonth.month + direction);
      _selectedDay = DateTime(_calendarMonth.year, _calendarMonth.month, 1);
    });
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
            final fullName = (data['name'] ?? data['fullName'] ??
                    data['firstName'] ?? 'User').toString().trim();
            final firstName = fullName.isEmpty ? 'User' : fullName.split(' ').first;
            final monthlyLimit = _number(data['budget'] ?? data['monthlyLimit']);
            final weeklyLimit = _number(data['weeklyLimit']) > 0
                ? _number(data['weeklyLimit'])
                : monthlyLimit / 4;
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _historyStream,
              builder: (context, historySnapshot) {
                final expenses = historySnapshot.data?.docs
                        .map(_MealExpense.fromDocument)
                        .whereType<_MealExpense>()
                        .toList() ??
                    <_MealExpense>[];
                return Stack(
                  children: [
                    RefreshIndicator(
                      onRefresh: () async {
                        await FirebaseFirestore.instance.collection('users')
                            .doc(widget.userId).get();
                      },
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(18, 20, 18, 130),
                        children: [
                          _header(firstName),
                          const SizedBox(height: 16),
                          _tabs(),
                          const SizedBox(height: 16),
                          if (userSnapshot.hasError || historySnapshot.hasError)
                            _notice('Could not load all budget information. Check your connection.'),
                          if (historySnapshot.connectionState == ConnectionState.waiting)
                            const LinearProgressIndicator(color: _green),
                          if (_monthly) ...[
                            _monthOverview(monthlyLimit, expenses),
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
                    _glassNavigation(),
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
        decoration: BoxDecoration(color: const Color(0xFFE7F4E9),
            borderRadius: BorderRadius.circular(32)),
        child: Row(children: [
          _tab('Weekly', !_monthly, () => setState(() => _monthly = false)),
          _tab('Monthly', _monthly, () => setState(() => _monthly = true)),
        ]),
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
            child: Text(title, style: TextStyle(fontWeight: FontWeight.w600,
                color: active ? Colors.white : _green)),
          ),
        ),
      );

  Widget _card({required Widget child, Color color = Colors.white}) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(19),
          border: Border.all(
            color: Colors.white.withOpacity(0.28),
            width: 0.7,
          )),
        child: child,
      );

  Widget _statTile(String label, double value, {Color color = _green}) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(color: Colors.white,
              borderRadius: BorderRadius.circular(12)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)),
            const SizedBox(height: 4),
            FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
              child: Text(_money.format(value), style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w800, color: color))),
          ]),
        ),
      );

  Widget _progress(double used, double limit, {Color track = const Color(0xFFB9DD9C)}) =>
      ClipRRect(borderRadius: BorderRadius.circular(12),
        child: LinearProgressIndicator(
          value: limit > 0 ? (used / limit).clamp(0.0, 1.0) : 0,
          minHeight: 8, color: Colors.white,
          backgroundColor: track,
        ),
      );

  Widget _weekOverview(double monthlyLimit, double weeklyLimit, List<_MealExpense> expenses) {
    final now = DateTime.now();
    final start = DateUtils.dateOnly(now.subtract(Duration(days: now.weekday % 7)));
    final spent = _spentBetween(expenses, start, start.add(const Duration(days: 7)));
    return _card(color: _lime, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Budget Overview', style: TextStyle(color: Colors.white,
          fontWeight: FontWeight.w800, fontSize: 16)),
      const SizedBox(height: 12),
      Row(children: [
        _statTile('Monthly Limit', monthlyLimit),
        const SizedBox(width: 9),
        _statTile('Weekly Budget', weeklyLimit),
      ]),
      const SizedBox(height: 11),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('Spent: ${_money.format(spent)}', style: const TextStyle(color: Colors.white, fontSize: 12)),
        Text('Remaining: ${_money.format(math.max(0, weeklyLimit - spent))}',
            style: const TextStyle(color: Colors.white, fontSize: 12)),
      ]),
      const SizedBox(height: 6),
      _progress(spent, weeklyLimit),
    ]));
  }

  Widget _calendar(double monthlyLimit, List<_MealExpense> expenses) {
    final first = DateTime(_calendarMonth.year, _calendarMonth.month);
    final count = DateUtils.getDaysInMonth(first.year, first.month);
    final leading = first.weekday % 7;
    final rows = ((leading + count) / 7).ceil();
    final dailyLimit = monthlyLimit / count;
    return _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Expanded(child: Text('Spending Calendar', style: TextStyle(
            fontWeight: FontWeight.w800, color: _ink, fontSize: 15))),
        IconButton(visualDensity: VisualDensity.compact,
            onPressed: () => _changeMonth(-1), icon: const Icon(Icons.chevron_left, color: _green)),
        Text(DateFormat('MMM yyyy').format(first),
            style: const TextStyle(fontSize: 12, color: _green, fontWeight: FontWeight.w700)),
        IconButton(visualDensity: VisualDensity.compact,
            onPressed: () => _changeMonth(1), icon: const Icon(Icons.chevron_right, color: _green)),
      ]),
      const SizedBox(height: 8),
      Row(children: ['S', 'M', 'T', 'W', 'T', 'F', 'S'].map((d) => Expanded(
        child: Center(child: Text(d, style: const TextStyle(fontSize: 12, color: Colors.black54))))).toList()),
      const SizedBox(height: 6),
      ...List.generate(rows, (row) => Row(children: List.generate(7, (col) {
        final day = row * 7 + col - leading + 1;
        if (day < 1 || day > count) return const Expanded(child: SizedBox(height: 46));
        final date = DateTime(first.year, first.month, day);
        final spent = _spentOn(expenses, date);
        final selected = _sameDate(date, _selectedDay);
        final hasData = spent > 0;
        return Expanded(child: InkWell(
          borderRadius: BorderRadius.circular(50),
          onTap: () => setState(() => _selectedDay = date),
          child: SizedBox(height: 46, child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(width: 29, height: 29, alignment: Alignment.center,
              decoration: BoxDecoration(color: selected ? _green : Colors.transparent,
                  shape: BoxShape.circle),
              child: Text('$day', style: TextStyle(fontSize: 12,
                  color: selected ? Colors.white : Colors.black87,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal))),
            Container(width: 5, height: 5, decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: hasData ? _status(spent, dailyLimit) : Colors.transparent)),
          ])),
        ));
      }))),
      const SizedBox(height: 12),
      Wrap(spacing: 12, runSpacing: 5, children: [
        _legend(_lime, 'Under Budget'),
        _legend(const Color(0xFFF09022), 'Near Limit'),
        _legend(const Color(0xFFE24B44), 'Over Budget'),
      ]),
      const SizedBox(height: 6),
      const Text('Status is based on daily meal costs versus the daily budget target.',
          style: TextStyle(fontSize: 10, color: Colors.black45)),
    ]));
  }

  Widget _legend(Color color, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
    CircleAvatar(radius: 3, backgroundColor: color),
    const SizedBox(width: 5),
    Text(label, style: const TextStyle(fontSize: 10, color: Colors.black54)),
  ]);

  Widget _dayDetails(List<_MealExpense> expenses) {
    final items = expenses.where((e) => _sameDate(e.date, _selectedDay)).toList();
    final total = items.fold<double>(0, (sum, e) => sum + e.amount);
    return _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(DateFormat('EEEE, MMM d').format(_selectedDay), style: const TextStyle(
            color: _ink, fontWeight: FontWeight.w800, fontSize: 13)),
        Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(color: const Color(0xFFE9F6E9), borderRadius: BorderRadius.circular(20)),
          child: Text('${_money.format(total)} spent', style: const TextStyle(
              color: _green, fontWeight: FontWeight.bold, fontSize: 11))),
      ]),
      const SizedBox(height: 9),
      if (items.isEmpty)
        const Text('No meals logged for this day.',
            style: TextStyle(color: Colors.black45, fontSize: 12))
      else
        ...items.map((e) => Padding(padding: const EdgeInsets.only(bottom: 5),
            child: Row(children: [
              const Icon(Icons.restaurant_rounded, size: 14, color: _green),
              const SizedBox(width: 6),
              Expanded(child: Text(e.name, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12))),
              Text(_money.format(e.amount), style: const TextStyle(fontSize: 12,
                  fontWeight: FontWeight.bold, color: _green)),
            ]))),
    ]));
  }

  Widget _statistics(double monthlyLimit, List<_MealExpense> expenses) {
    final start = DateUtils.dateOnly(DateTime.now().subtract(
      Duration(days: DateTime.now().weekday % 7)));
    final dailyLimit = monthlyLimit /
        DateUtils.getDaysInMonth(DateTime.now().year, DateTime.now().month);
    final values = List.generate(7, (i) => _spentOn(expenses, start.add(Duration(days: i))));
    final ceiling = math.max(dailyLimit, values.fold<double>(0, math.max));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Statistics', style: TextStyle(color: _green, fontWeight: FontWeight.w800)),
          Text('${DateFormat('MMM d').format(start)} – ${DateFormat('MMM d').format(start.add(const Duration(days: 6)))}',
            style: const TextStyle(color: Colors.black45, fontSize: 11)),
        ])),
      const SizedBox(height: 6),
      _card(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text('Daily Target ${_money.format(dailyLimit)}', style: const TextStyle(
            color: _lime, fontSize: 10)),
        const SizedBox(height: 7),
        SizedBox(height: 88, child: Row(crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(7, (i) {
            final height = ceiling <= 0 ? 0.0 : values[i] / ceiling * 63;
            return Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
              Container(height: math.max(3.0, height), width: 19,
                decoration: BoxDecoration(color: values[i] == 0
                    ? const Color(0xFFE4EFE4) : _status(values[i], dailyLimit),
                    borderRadius: BorderRadius.circular(4))),
              const SizedBox(height: 6),
              Text(['S', 'M', 'T', 'W', 'T', 'F', 'S'][i],
                style: const TextStyle(color: Colors.black54, fontSize: 10)),
            ]));
          }))),
      ])),
    ]);
  }

  Widget _monthOverview(double monthlyLimit, List<_MealExpense> expenses) {
    final first = DateTime(DateTime.now().year, DateTime.now().month);
    final spent = _spentBetween(expenses, first, DateTime(first.year, first.month + 1));
    final progress = monthlyLimit > 0 ? spent / monthlyLimit : 0.0;
    return _card(color: _lime, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text('${DateFormat('MMMM yyyy').format(first)} Overview',
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800))),
        TextButton.icon(onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => MonthlyPage(userId: widget.userId))),
          style: TextButton.styleFrom(foregroundColor: Colors.white,
              backgroundColor: Colors.white24, visualDensity: VisualDensity.compact),
          label: const Text('Edit'), icon: const Icon(Icons.edit, size: 13)),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        _statTile('Total Spent', spent, color: const Color(0xFF287FAD)),
        const SizedBox(width: 9),
        _statTile('Remaining', math.max(0, monthlyLimit - spent)),
      ]),
      const SizedBox(height: 13),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('Limit: ${_money.format(monthlyLimit)}',
            style: const TextStyle(color: Colors.white, fontSize: 12)),
        Text('${(progress * 100).toStringAsFixed(0)}% Used',
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
      ]),
      const SizedBox(height: 6),
      _progress(spent, monthlyLimit),
    ]));
  }

  Widget _rhythm(double weeklyLimit, double monthlyLimit, List<_MealExpense> expenses) {
    final first = DateTime(DateTime.now().year, DateTime.now().month);
    final monthEnd = DateTime(first.year, first.month + 1);
    final now = DateTime.now();
    final monthSpent = _spentBetween(expenses, first, monthEnd);
    final daysInMonth = monthEnd.difference(first).inDays;
    final elapsedDays = now.difference(first).inDays + 1;
    final projectedSpent = monthSpent / elapsedDays.clamp(1, daysInMonth) * daysInMonth;
    final projectedSavings = monthlyLimit - projectedSpent;
    return _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('4-Week Spending Rhythm', style: TextStyle(
          fontSize: 15, color: _ink, fontWeight: FontWeight.w800)),
      Text('Target: ${_money.format(weeklyLimit)} / week',
          style: const TextStyle(color: Colors.black45, fontSize: 11)),
      const SizedBox(height: 13),
      ...List.generate(4, (i) {
        final start = first.add(Duration(days: i * 7));
        final end = i == 3 ? monthEnd : first.add(Duration(days: (i + 1) * 7));
        final spent = _spentBetween(expenses, start, end);
        final current = !now.isBefore(start) && now.isBefore(end);
        final future = now.isBefore(start);
        final diff = weeklyLimit - spent;
        return Container(margin: const EdgeInsets.only(bottom: 9),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: current ? const Color(0xFFF0F8E8) : Colors.white,
            borderRadius: BorderRadius.circular(10),
          ), child: Column(children: [
            Row(children: [
              Expanded(child: Text('Week ${i + 1} (${DateFormat('MMM d').format(start)}–${DateFormat('d').format(end.subtract(const Duration(days: 1)))})${current ? ' • Current' : ''}',
                style: TextStyle(color: current ? _green : _ink,
                    fontSize: 12, fontWeight: FontWeight.bold))),
              Text(future ? '${_money.format(weeklyLimit)} budget' : _money.format(spent),
                style: TextStyle(fontSize: 11, color: future ? Colors.black45 : _green,
                    fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 7),
            ClipRRect(borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(value: weeklyLimit > 0
                  ? (spent / weeklyLimit).clamp(0.0, 1.0) : 0,
                minHeight: 7, backgroundColor: const Color(0xFFE7F1E0),
                color: _status(spent, weeklyLimit))),
            if (!future && weeklyLimit > 0) ...[
              const SizedBox(height: 4),
              Align(alignment: Alignment.centerRight, child: Text(
                  diff >= 0 ? '${_money.format(diff)} under target' : '${_money.format(-diff)} over target',
                  style: const TextStyle(color: Colors.black45, fontSize: 10))),
            ],
          ]));
      }),
      const Divider(),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 10),
        decoration: BoxDecoration(color: const Color(0xFFF5FAF5),
            borderRadius: BorderRadius.circular(10)),
        child: Row(children: [
          const Icon(Icons.circle, color: _green, size: 9),
          const SizedBox(width: 8),
          Expanded(child: Text.rich(TextSpan(children: [
            const TextSpan(text: 'Forecast: End month at ',
                style: TextStyle(color: _ink)),
            TextSpan(text: _money.format(projectedSpent),
                style: const TextStyle(color: _green, fontWeight: FontWeight.w800)),
            TextSpan(text: projectedSavings >= 0
                ? ' (Saving ${_money.format(projectedSavings)}!)'
                : ' (Over budget by ${_money.format(-projectedSavings)})',
                style: TextStyle(color: projectedSavings >= 0 ? _ink : Colors.redAccent)),
          ]), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),),
        ]),
      ),
    ]));
  }

  Widget _notice(String message) => Padding(padding: const EdgeInsets.only(bottom: 10),
    child: Text(message, style: const TextStyle(color: Colors.redAccent, fontSize: 12)));

  // A frosted, floating navigation bar with translucent highlights and
  // background blur, inspired by iOS liquid-glass surfaces.
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

                      // More transparent glass
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withOpacity(0.10),
                          Colors.white.withOpacity(0.03),
                          Colors.white.withOpacity(0.08),
                        ],
                      ),

                      // Subtle reflective glass edge
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
                              true,
                              () => _navigate(
                                BudgetPage(userId: widget.userId),
                              ),
                            ),

                            const Expanded(child: SizedBox()),

                            _navItem(
                              Icons.flag_rounded,
                              'goals',
                              false,
                              () => _navigate(
                                GoalsPage(userId: widget.userId),
                              ),
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

    Widget _navItem(IconData icon, String label, bool active, VoidCallback action) =>
      Expanded(child: InkWell(onTap: action, child: Column(
        mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: active ? const Color(0xFF2987B0) : _green, size: 23),
          Text(label, style: TextStyle(fontSize: 10,
              color: active ? const Color(0xFF2987B0) : _green)),
        ],
      )));

  void _navigate(Widget page) {
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      SmoothPageRoute(page: page),
    );
  }
}