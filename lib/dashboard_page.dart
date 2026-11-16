import 'widgets/navbar_widget.dart';
import 'widgets/dashboard_header.dart';

import 'dart:convert';
import 'dart:async';

import 'package:image_picker/image_picker.dart';

import 'utils/app_haptics.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'utils/page_transitions.dart';
import 'budget_page.dart';

class DashboardPage extends StatefulWidget {
  final String userId;

  const DashboardPage({super.key, required this.userId});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  Timer? _dayTimer;
  DateTime _currentDay = DateUtils.dateOnly(DateTime.now());

  @override
  void initState() {
    super.initState();
    _dayTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      final today = DateUtils.dateOnly(DateTime.now());
      if (today != _currentDay && mounted) {
        setState(() => _currentDay = today);
      }
    });

    debugPrint('Firebase UID: ${FirebaseAuth.instance.currentUser?.uid}');

    debugPrint('Dashboard UID: ${widget.userId}');
  }

  @override
  void dispose() {
    _dayTimer?.cancel();
    super.dispose();
  }

  static const _green = Color(0xFF287D35);
  static const _lightGreen = Color(0xFF7DB848);
  static const _blue = Color(0xFF2987B0);
  static const _background = Color(0xFFF7FAF7);
  static const _types = ['All', 'Breakfast', 'Lunch', 'Dinner', 'Snack'];

  String _filter = 'All';
  final _peso = NumberFormat.currency(
    locale: 'en_PH',
    symbol: '₱',
    decimalDigits: 0,
  );
  final _date = DateFormat('MM-dd-yyyy');
  final _time = DateFormat('h:mm a');

  DocumentReference<Map<String, dynamic>> get _userRef =>
      FirebaseFirestore.instance.collection('users').doc(widget.userId);

  CollectionReference<Map<String, dynamic>> get _mealRef =>
      _userRef.collection('mealHistory');

  double _number(dynamic raw) {
    if (raw is num) return raw.toDouble();
    return double.tryParse('$raw') ?? 0;
  }

  DateTime? _readDate(dynamic raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw);
    return null;
  }

  bool _sameMonth(DateTime date, DateTime now) =>
      date.year == now.year && date.month == now.month;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      extendBody: true,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: _userRef.snapshots(),
              builder: (context, userSnapshot) {
                final user = userSnapshot.data?.data() ?? <String, dynamic>{};
                final name =
                    (user['firstName'] ?? user['name'] ?? 'User')
                        .toString()
                        .trim();
                final budget = _number(user['budget'] ?? user['monthlyLimit']);
                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _mealRef.snapshots(),
                  builder: (context, mealSnapshot) {
                    final records = mealSnapshot.data?.docs ?? [];
                    final meals =
                        records
                            .map(
                              (doc) =>
                                  _MealEntry.fromDoc(doc, _readDate, _number),
                            )
                            .where((meal) => meal.date != null)
                            .toList()
                          ..sort((a, b) => b.date!.compareTo(a.date!));
                    final now = DateTime.now();
                    final consumed = meals
                        .where(
                          (meal) =>
                              DateUtils.isSameDay(meal.date!.toLocal(), now),
                        )
                        .fold<double>(
                          0,
                          (sum, meal) =>
                              sum +
                              (meal.calories.isFinite && meal.calories > 0
                                  ? meal.calories
                                  : 0),
                        );
                    final spent = meals
                        .where((meal) => _sameMonth(meal.date!, now))
                        .fold<double>(0, (sum, meal) => sum + meal.cost);
                    final filtered =
                        _filter == 'All'
                            ? meals
                            : meals
                                .where(
                                  (meal) =>
                                      meal.type.toLowerCase() ==
                                      _filter.toLowerCase(),
                                )
                                .toList();

                    return RefreshIndicator(
                      color: _green,
                      onRefresh: () async {
                        await Future.wait([_userRef.get(), _mealRef.get()]);
                      },
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(
                          17,
                          22,
                          17,
                          145 + MediaQuery.of(context).padding.bottom,
                        ),
                        children: [
                          _header(name.isEmpty ? 'User' : name),
                          const SizedBox(height: 21),
                          _budgetCard(
                            budget,
                            spent,
                            userSnapshot.hasError || mealSnapshot.hasError,
                          ),
                          const SizedBox(height: 20),
                          _calorieCard(
                            user,
                            consumed,
                            userSnapshot.hasError || mealSnapshot.hasError,
                            (!userSnapshot.hasData || !mealSnapshot.hasData),
                          ),
                          const SizedBox(height: 20),
                          _historyHeader(),
                          const SizedBox(height: 12),
                          _filters(),
                          const SizedBox(height: 12),
                          if (mealSnapshot.hasError)
                            _messageCard(
                              'Could not load Meal History. Check Firestore permissions and your connection.',
                            )
                          else if (mealSnapshot.connectionState ==
                                  ConnectionState.waiting &&
                              !mealSnapshot.hasData)
                            const Padding(
                              padding: EdgeInsets.all(32),
                              child: Center(
                                child: CircularProgressIndicator(color: _green),
                              ),
                            )
                          else if (filtered.isEmpty)
                            _emptyHistory()
                          else
                            ...filtered.map(_mealCard),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          NavbarWidget(userId: widget.userId, activeTab: NavbarTab.home),
        ],
      ),
    );
  }

  Widget _header(String name) => DashboardHeader(
    name: name,
    subtitle: 'Let’s manage your food and budget today',
  );

  Widget _budgetCard(double budget, double spent, bool hasError) {
    final remaining = budget - spent;
    final progress = budget <= 0 ? 0.0 : (spent / budget).clamp(0.0, 1.0);
    return Container(
      decoration: BoxDecoration(
        color: _lightGreen,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.08),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Monthly Budget',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              IconButton(
                onPressed: () => _navigate(BudgetPage(userId: widget.userId)),
                tooltip: 'View budget',
                icon: const Icon(
                  Icons.edit_square,
                  color: Colors.white,
                  size: 20,
                ),
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _peso.format(budget),
            style: const TextStyle(
              fontSize: 27,
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 13),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Spent: ${_peso.format(spent)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  'Remaining: ${_peso.format(remaining)}',
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 9,
              backgroundColor: const Color(0xFFDBF0D2),
              valueColor: AlwaysStoppedAnimation<Color>(
                remaining < 0 ? Colors.red.shade700 : _green,
              ),
            ),
          ),
          if (!hasError && budget > 0 && spent >= budget * .9) ...[
            const SizedBox(height: 10),
            _limitNotice('Monthly budget', spent, budget, money: true),
          ],
          if (hasError) ...[
            const SizedBox(height: 8),
            const Text(
              'Some budget data could not be loaded.',
              style: TextStyle(color: Colors.white, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  // Match the maintenance-energy estimate used on the Goals page.
  // Conditions and allergies do not imply a calorie deficit or surplus.
  double? _dailyCalorieTarget(Map<String, dynamic> user) {
    final age = _number(user['age']);
    final kg = _number(user['weight']);
    final cm = _number(user['height']);
    final sex = '${user['sex'] ?? ''}'.trim().toLowerCase();
    if (!age.isFinite ||
        age < 18 ||
        !kg.isFinite ||
        kg <= 0 ||
        !cm.isFinite ||
        cm <= 0 ||
        (sex != 'male' && sex != 'female'))
      return null;
    final factor = switch ('${user['activityLevel'] ?? ''}'
        .trim()
        .toLowerCase()) {
      'sedentary' => 1.2,
      'lightly active' => 1.375,
      'moderately active' => 1.55,
      'active' => 1.725,
      'very active' => 1.9,
      _ => null,
    };
    if (factor == null) return null;
    final target =
        (10 * kg + 6.25 * cm - 5 * age + (sex == 'male' ? 5 : -161)) * factor;
    return target.isFinite && target > 0 ? target : null;
  }

  Widget _calorieCard(
    Map<String, dynamic> user,
    double consumed,
    bool hasError,
    bool loading,
  ) {
    final target = _dailyCalorieTarget(user)?.round();
    final format = NumberFormat('#,##0');
    final ready = !hasError && !loading;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _lightGreen,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Daily Calorie Tracker',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          if (ready)
            Text.rich(
              TextSpan(
                style: const TextStyle(color: Colors.white, fontSize: 14),
                children: [
                  const TextSpan(text: 'Consumed: '),
                  TextSpan(
                    text: format.format(consumed),
                    style: const TextStyle(
                      color: _green,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const TextSpan(text: ' / '),
                  TextSpan(
                    text:
                        target == null
                            ? '— KCal'
                            : '${format.format(target)} KCal',
                    style: const TextStyle(
                      color: _blue,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            )
          else
            Text(
              hasError
                  ? 'Calorie data could not be loaded.'
                  : 'Loading calories…',
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value:
                  ready && target != null && target > 0
                      ? (consumed / target).clamp(0.0, 1.0)
                      : 0,
              minHeight: 9,
              backgroundColor: const Color(0xFFE8F2E5),
              valueColor: const AlwaysStoppedAnimation<Color>(_green),
            ),
          ),
          if (ready && target != null && consumed >= target * .9) ...[
            const SizedBox(height: 10),
            _limitNotice('Daily calories', consumed, target.toDouble()),
          ],
          if (ready) ...[
            const SizedBox(height: 7),
            Text(
              target == null
                  ? 'Complete your adult health profile to estimate daily needs.'
                  : 'Estimated daily needs • Based on your health profile',
              style: const TextStyle(color: Colors.white, fontSize: 10),
            ),
          ],
        ],
      ),
    );
  }

  Widget _limitNotice(
    String label,
    double used,
    double limit, {
    bool money = false,
  }) {
    final exceeded = used > limit;
    final reached = used >= limit;
    final amount =
        money
            ? _peso.format((limit - used).abs())
            : '${(limit - used).abs().toStringAsFixed(0)} kcal';
    final accent = reached ? const Color(0xFFAD493D) : _green;
    final title =
        exceeded
            ? 'Over your ${money ? 'budget' : 'daily estimate'}'
            : reached
            ? '${money ? 'Budget' : 'Daily estimate'} reached'
            : '${money ? 'Budget' : 'Daily calories'} heads-up';
    final detail =
        exceeded
            ? '$amount above your ${money ? 'monthly budget' : 'estimated daily needs'}.'
            : reached
            ? (money
                ? 'You have used your monthly budget.'
                : 'You have reached your estimated daily needs.')
            : '$amount left ${money ? 'in your monthly budget' : 'for today'}. You have used ${(used / limit * 100).floor()}%.';
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: const Color(0xFFF7FAF7),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: .8)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: .09),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                money
                    ? Icons.account_balance_wallet_outlined
                    : Icons.local_fire_department_outlined,
                color: accent,
                size: 21,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    detail,
                    style: const TextStyle(
                      color: Color(0xFF526650),
                      fontSize: 11,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _confirmLimits(
    DateTime date,
    double cost,
    double calories,
    String? editingId,
  ) async {
    final user = (await _userRef.get()).data() ?? <String, dynamic>{};
    final records = await _mealRef.get();
    final meals = records.docs
        .where((doc) => doc.id != editingId)
        .map((doc) => _MealEntry.fromDoc(doc, _readDate, _number));
    final daily = meals
        .where(
          (m) => m.date != null && DateUtils.isSameDay(m.date!.toLocal(), date),
        )
        .fold<double>(calories, (total, m) => total + m.calories);
    final monthly = meals
        .where((m) => m.date != null && _sameMonth(m.date!.toLocal(), date))
        .fold<double>(cost, (total, m) => total + m.cost);
    final target = _dailyCalorieTarget(user)?.round();
    final budget = _number(user['budget'] ?? user['monthlyLimit']);
    final warnings = <String>[
      if (target != null && daily > target)
        'Calories on ${DateFormat('MMM d').format(date)} will exceed your estimated daily target by ${(daily - target).toStringAsFixed(0)} kcal.',
      if (budget > 0 && monthly > budget)
        'Spending in ${DateFormat('MMMM yyyy').format(date)} will exceed your monthly budget by ${_peso.format(monthly - budget)}.',
    ];
    if (warnings.isEmpty) return true;
    if (!mounted) return false;
    return await showDialog<bool>(
          context: context,
          builder:
              (ctx) => AlertDialog(
                backgroundColor: _background,
                surfaceTintColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                title: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: Color(0xFFE8F2E5),
                        shape: BoxShape.circle,
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: Icon(
                          Icons.info_outline_rounded,
                          color: _green,
                          size: 28,
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'A quick heads-up',
                      style: TextStyle(
                        color: _green,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'This meal will put you over a target.',
                        style: TextStyle(
                          color: Color(0xFF526650),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 14),
                      for (final warning in warnings)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Container(
                            padding: const EdgeInsets.all(13),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFFE1EED8),
                              ),
                            ),
                            child: Text(
                              warning,
                              style: const TextStyle(
                                color: Color(0xFF526650),
                                fontSize: 12,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    style: TextButton.styleFrom(foregroundColor: _green),
                    child: const Text('Review meal'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: FilledButton.styleFrom(
                      backgroundColor: _green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Save anyway'),
                  ),
                ],
              ),
        ) ??
        false;
  }

  Widget _historyHeader() => Row(
    children: [
      const Expanded(
        child: Text(
          'Meal History',
          style: TextStyle(
            color: _green,
            fontWeight: FontWeight.w800,
            fontSize: 17,
          ),
        ),
      ),
      TextButton.icon(
        onPressed: _showAddMealSheet,
        icon: const Icon(Icons.add_circle_outline, size: 19),
        label: const Text('Add Meal'),
        style: TextButton.styleFrom(
          foregroundColor: _green,
          padding: const EdgeInsets.symmetric(horizontal: 4),
        ),
      ),
    ],
  );

  Widget _filters() => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children:
          _types.map((type) {
            final selected = type == _filter;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: Text(type),
                selected: selected,
                showCheckmark: false,
                labelStyle: TextStyle(
                  fontSize: 11,
                  color: selected ? Colors.white : _green,
                  fontWeight: FontWeight.w600,
                ),
                backgroundColor: const Color(0xFFE8F2E5),
                selectedColor: _green,
                side: BorderSide.none,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 7),
                onSelected: (_) => setState(() => _filter = type),
              ),
            );
          }).toList(),
    ),
  );

  Widget _mealCard(_MealEntry meal) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Container(
      decoration: BoxDecoration(
        color: _lightGreen,
        borderRadius: BorderRadius.circular(13),
      ),
      padding: const EdgeInsets.all(7),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: SizedBox(
              height: 63,
              width: 63,
              child:
                  meal.photoBase64.isNotEmpty
                      ? Image.memory(
                        base64Decode(meal.photoBase64),
                        fit: BoxFit.cover,
                        errorBuilder:
                            (_, __, ___) => _mealPlaceholder(meal.type),
                      )
                      : meal.imageUrl.isNotEmpty
                      ? Image.network(
                        meal.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder:
                            (_, __, ___) => _mealPlaceholder(meal.type),
                      )
                      : _mealPlaceholder(meal.type),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  meal.type,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  meal.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
                const SizedBox(height: 6),
                Text(
                  '${meal.calories.toStringAsFixed(0)} Kcal · ${_peso.format(meal.cost)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _date.format(meal.date!),
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
              Text(
                _time.format(meal.date!),
                style: const TextStyle(color: Colors.white70, fontSize: 9),
              ),
              const SizedBox(height: 17),
              PopupMenuButton<String>(
                tooltip: 'Meal options',
                color: _background,
                surfaceTintColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Color(0xFFE1EED8)),
                ),
                padding: EdgeInsets.zero,
                iconSize: 18,
                icon: const Icon(Icons.more_horiz, color: Colors.white),
                onSelected: (choice) {
                  if (choice == 'edit') _showAddMealSheet(meal: meal);
                  if (choice == 'delete') _confirmDelete(meal);
                },
                itemBuilder:
                    (_) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined, color: _green, size: 20),
                            SizedBox(width: 10),
                            Text('Edit meal', style: TextStyle(color: _green)),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete_outline_rounded,
                              color: Color(0xFFAD493D),
                              size: 20,
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Delete meal',
                              style: TextStyle(color: Color(0xFFAD493D)),
                            ),
                          ],
                        ),
                      ),
                    ],
              ),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _mealPlaceholder(String type) {
    IconData icon;
    switch (type.toLowerCase()) {
      case 'breakfast':
        icon = Icons.free_breakfast_rounded;
        break;
      case 'lunch':
        icon = Icons.lunch_dining_rounded;
        break;
      case 'dinner':
        icon = Icons.dinner_dining_rounded;
        break;
      default:
        icon = Icons.fastfood_rounded;
    }
    return Container(
      color: const Color(0xFFE1EED8),
      child: Icon(icon, color: Color.fromARGB(255, 156, 255, 99), size: 30),
    );
  }

  Widget _emptyHistory() => Container(
    padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 14),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: const Color(0xFFE3EDE2)),
      borderRadius: BorderRadius.circular(15),
    ),
    child: Column(
      children: [
        const Icon(Icons.restaurant_menu_rounded, color: _green, size: 34),
        const SizedBox(height: 8),
        Text(
          _filter == 'All'
              ? 'No meals recorded yet'
              : 'No $_filter meals recorded',
          style: const TextStyle(color: _green, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        const Text(
          'Tap Add Meal to record your food and spending.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.black54, fontSize: 12),
        ),
      ],
    ),
  );

  Widget _messageCard(String message) => Padding(
    padding: const EdgeInsets.all(12),
    child: Text(message, style: const TextStyle(color: Colors.red)),
  );

  Future<void> _confirmDelete(_MealEntry meal) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete meal?'),
            content: Text('Remove ${meal.name} from your Meal History?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
    if (confirmed != true) return;
    try {
      await _mealRef.doc(meal.id).delete();
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Could not delete meal.')));
    }
  }

  InputDecoration _mealInput(String label, IconData icon, {String? hint}) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: const Color(0xFFF2F7EF),
        labelStyle: const TextStyle(color: Color(0xFF526650), fontSize: 12),
        floatingLabelStyle: const TextStyle(
          color: _green,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        hintStyle: const TextStyle(color: Color(0xFF8B9C87), fontSize: 12),
        prefixIcon: Icon(icon, color: _green, size: 20),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
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
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFAD493D)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFAD493D), width: 1.5),
        ),
        errorMaxLines: 2,
      );

  Future<void> _showAddMealSheet({_MealEntry? meal}) async {
    final name = TextEditingController(text: meal?.name);
    final cost = TextEditingController(text: meal?.cost.toString());
    final calories = TextEditingController(text: meal?.calories.toString());
    AppHaptics.selection();
    Uint8List? photo;
    bool capturing = false;
    String type = _types
        .skip(1)
        .firstWhere(
          (v) => v.toLowerCase() == meal?.type.toLowerCase(),
          orElse: () => 'Breakfast',
        );
    DateTime selectedDate = meal?.date?.toLocal() ?? DateTime.now();
    bool saving = false;
    final formKey = GlobalKey<FormState>();
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: _background,
        showDragHandle: true,
        useSafeArea: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        builder:
            (sheetContext) => StatefulBuilder(
              builder: (context, changeSheetState) {
                return Padding(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    18,
                    20,
                    MediaQuery.of(context).viewInsets.bottom + 24,
                  ),
                  child: SingleChildScrollView(
                    child: Form(
                      key: formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            meal == null ? 'Add Meal History' : 'Edit Meal',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 20,
                              color: _green,
                            ),
                          ),
                          const SizedBox(height: 14),
                          if (photo != null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.memory(
                                photo!,
                                height: 160,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: _green,
                                    backgroundColor: const Color(0xFFE8F2E5),
                                    disabledBackgroundColor: const Color(
                                      0xFFF2F7EF,
                                    ),
                                    side: const BorderSide(
                                      color: Color(0xFFCADFC0),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 18,
                                      vertical: 18,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    textStyle: const TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  icon: Container(
                                    padding: const EdgeInsets.all(9),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: .8),
                                      borderRadius: BorderRadius.circular(11),
                                    ),
                                    child:
                                        capturing
                                            ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: _green,
                                              ),
                                            )
                                            : const Icon(
                                              Icons.add_a_photo_outlined,
                                              size: 20,
                                            ),
                                  ),
                                  label: Text(
                                    capturing
                                        ? 'Opening camera...'
                                        : photo == null
                                        ? 'Take food photo'
                                        : 'Retake photo',
                                  ),
                                  onPressed:
                                      saving || capturing
                                          ? null
                                          : () async {
                                            changeSheetState(
                                              () => capturing = true,
                                            );
                                            try {
                                              final image = await ImagePicker()
                                                  .pickImage(
                                                    source: ImageSource.camera,
                                                    maxWidth: 800,
                                                    maxHeight: 800,
                                                    imageQuality: 55,
                                                    requestFullMetadata: false,
                                                  );
                                              if (image != null) {
                                                final bytes =
                                                    await image.readAsBytes();
                                                if (!sheetContext.mounted)
                                                  return;
                                                if (bytes.length > 500000) {
                                                  ScaffoldMessenger.of(
                                                    sheetContext,
                                                  ).showSnackBar(
                                                    const SnackBar(
                                                      content: Text(
                                                        'Photo is too large. Please retake it.',
                                                      ),
                                                    ),
                                                  );
                                                } else {
                                                  changeSheetState(
                                                    () => photo = bytes,
                                                  );
                                                  AppHaptics.selection();
                                                }
                                              }
                                            } catch (_) {
                                              if (sheetContext.mounted)
                                                ScaffoldMessenger.of(
                                                  sheetContext,
                                                ).showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      'Could not open the camera. Check camera permission and try again.',
                                                    ),
                                                  ),
                                                );
                                            } finally {
                                              if (sheetContext.mounted)
                                                changeSheetState(
                                                  () => capturing = false,
                                                );
                                            }
                                          },
                                ),
                              ),
                              if (photo != null)
                                IconButton(
                                  tooltip: 'Remove photo',
                                  onPressed:
                                      saving || capturing
                                          ? null
                                          : () => changeSheetState(
                                            () => photo = null,
                                          ),
                                  icon: const Icon(Icons.close),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: name,
                            cursorColor: _green,
                            style: const TextStyle(
                              color: _green,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                            textCapitalization: TextCapitalization.words,
                            decoration: _mealInput(
                              'Meal / food name',
                              Icons.restaurant_menu_rounded,
                              hint: 'e.g. Chicken and rice',
                            ),
                            validator:
                                (v) =>
                                    v == null || v.trim().isEmpty
                                        ? 'Enter a meal name'
                                        : null,
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: type,
                            dropdownColor: _background,
                            borderRadius: BorderRadius.circular(14),
                            icon: const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: _green,
                            ),
                            style: const TextStyle(
                              color: _green,
                              fontFamily: 'Poppins',
                              fontSize: 13,
                            ),
                            decoration: _mealInput(
                              'Meal type',
                              Icons.lunch_dining_outlined,
                            ),
                            items:
                                _types
                                    .skip(1)
                                    .map(
                                      (v) => DropdownMenuItem(
                                        value: v,
                                        child: Text(v),
                                      ),
                                    )
                                    .toList(),
                            onChanged:
                                (v) => changeSheetState(() => type = v ?? type),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: cost,
                                  cursorColor: _green,
                                  style: const TextStyle(
                                    color: _green,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                      RegExp(r'[0-9.]'),
                                    ),
                                  ],
                                  decoration: _mealInput(
                                    'Cost (₱)',
                                    Icons.payments_outlined,
                                    hint: '0.00',
                                  ),
                                  validator: (v) {
                                    final n = double.tryParse(v ?? '');
                                    return n == null || !n.isFinite || n < 0
                                        ? 'Enter a valid cost'
                                        : null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextFormField(
                                  controller: calories,
                                  cursorColor: _green,
                                  style: const TextStyle(
                                    color: _green,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                      RegExp(r'[0-9.]'),
                                    ),
                                  ],
                                  decoration: _mealInput(
                                    'Calories (kcal)',
                                    Icons.local_fire_department_outlined,
                                    hint: '0',
                                  ),
                                  validator: (v) {
                                    final n = double.tryParse(v ?? '');
                                    return n == null || !n.isFinite || n < 0
                                        ? 'Enter calories'
                                        : null;
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ListTile(
                            tileColor: const Color(0xFFF2F7EF),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: const BorderSide(color: Color(0xFFDDE9D8)),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 4,
                            ),
                            titleTextStyle: const TextStyle(
                              color: _green,
                              fontSize: 12,
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w500,
                            ),
                            leading: const Icon(
                              Icons.calendar_today,
                              color: _green,
                            ),
                            title: Text(
                              DateFormat(
                                'MMM d, yyyy · h:mm a',
                              ).format(selectedDate),
                            ),
                            trailing: const Icon(
                              Icons.edit_calendar_outlined,
                              color: _green,
                              size: 20,
                            ),
                            onTap:
                                saving
                                    ? null
                                    : () async {
                                      final date = await showDatePicker(
                                        context: context,
                                        initialDate: selectedDate,
                                        firstDate: DateTime(2020),
                                        lastDate: DateTime.now(),
                                      );
                                      if (date == null || !context.mounted)
                                        return;
                                      final time = await showTimePicker(
                                        context: context,
                                        initialTime: TimeOfDay.fromDateTime(
                                          selectedDate,
                                        ),
                                      );
                                      if (time == null) return;
                                      changeSheetState(
                                        () =>
                                            selectedDate = DateTime(
                                              date.year,
                                              date.month,
                                              date.day,
                                              time.hour,
                                              time.minute,
                                            ),
                                      );
                                    },
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _green,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                              ),
                              onPressed:
                                  saving || capturing
                                      ? null
                                      : () async {
                                        if (!(formKey.currentState
                                                ?.validate() ??
                                            false))
                                          return;
                                        changeSheetState(() => saving = true);
                                        try {
                                          final allowed = await _confirmLimits(
                                            selectedDate,
                                            double.parse(cost.text),
                                            double.parse(calories.text),
                                            meal?.id,
                                          );
                                          if (!sheetContext.mounted) return;
                                          if (!allowed) {
                                            changeSheetState(
                                              () => saving = false,
                                            );
                                            return;
                                          }
                                          final values = <String, dynamic>{
                                            if (photo != null)
                                              'photoBase64': base64Encode(
                                                photo!,
                                              ),
                                            'mealName': name.text.trim(),
                                            'mealType': type,
                                            'totalCost': double.parse(
                                              cost.text,
                                            ),
                                            'calories': double.parse(
                                              calories.text,
                                            ),
                                            'date': Timestamp.fromDate(
                                              selectedDate,
                                            ),
                                            if (meal == null)
                                              'createdAt':
                                                  FieldValue.serverTimestamp(),
                                            'updatedAt':
                                                FieldValue.serverTimestamp(),
                                          };
                                          if (meal == null) {
                                            await _mealRef.add(values);
                                          } else {
                                            await _mealRef
                                                .doc(meal.id)
                                                .update(values);
                                          }
                                          if (!sheetContext.mounted) return;
                                          AppHaptics.selection();
                                          FocusManager.instance.primaryFocus
                                              ?.unfocus();
                                          Navigator.of(sheetContext).pop();
                                        } catch (_) {
                                          if (sheetContext.mounted)
                                            ScaffoldMessenger.of(
                                              sheetContext,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Could not save meal. Check your connection and Firestore permissions.',
                                                ),
                                              ),
                                            );
                                          if (sheetContext.mounted)
                                            changeSheetState(
                                              () => saving = false,
                                            );
                                        }
                                      },
                              child: Text(
                                saving
                                    ? 'Saving...'
                                    : meal == null
                                    ? 'Add Meal'
                                    : 'Save Changes',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
      );
    } finally {
      await Future<void>.delayed(const Duration(milliseconds: 500));

      name.dispose();
      cost.dispose();
      calories.dispose();
    }
  }

  void _navigate(Widget page) {
    if (!mounted) return;
    AppHaptics.selection();

    Navigator.of(context).pushReplacement(SmoothPageRoute(page: page));
  }
}

class _MealEntry {
  final String id;
  final String type;
  final String name;
  final DateTime? date;
  final double cost;
  final double calories;
  final String imageUrl;
  final String photoBase64;

  const _MealEntry({
    required this.id,
    required this.type,
    required this.name,
    required this.date,
    required this.cost,
    required this.calories,
    required this.imageUrl,
    this.photoBase64 = '',
  });

  factory _MealEntry.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    DateTime? Function(dynamic) readDate,
    double Function(dynamic) readNumber,
  ) {
    final data = doc.data();
    return _MealEntry(
      id: doc.id,
      type: (data['mealType'] ?? data['type'] ?? 'Snack').toString(),
      name:
          (data['mealName'] ?? data['name'] ?? data['productName'] ?? 'Meal')
              .toString(),
      date: readDate(data['date'] ?? data['timestamp'] ?? data['createdAt']),
      cost: readNumber(data['totalCost'] ?? data['amount'] ?? data['cost']),
      calories: readNumber(data['calories'] ?? data['kcal']),
      photoBase64: (data['photoBase64'] ?? '').toString(),
      imageUrl: (data['imageUrl'] ?? data['image'] ?? '').toString(),
    );
  }
}
