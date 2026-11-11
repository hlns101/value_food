import 'widgets/dashboard_header.dart';
import 'dart:ui';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'utils/app_haptics.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:value_food_demo/goals_page.dart';

import 'utils/page_transitions.dart';
import 'budget_page.dart';
import 'label_page.dart';
import 'profile_page.dart';

class DashboardPage extends StatefulWidget {
  final String userId;

  const DashboardPage({super.key, required this.userId});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  @override
  void initState() {
    super.initState();

    debugPrint('Firebase UID: ${FirebaseAuth.instance.currentUser?.uid}');

    debugPrint('Dashboard UID: ${widget.userId}');
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
          _glassNavigation(),
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
                selectedColor:
                    type == 'Snack' ? const Color(0xFF176084) : _lightGreen,
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
                padding: EdgeInsets.zero,
                iconSize: 18,
                icon: const Icon(Icons.more_horiz, color: Colors.white),
                onSelected: (choice) {
                  if (choice == 'delete') _confirmDelete(meal);
                },
                itemBuilder:
                    (_) => [
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete meal'),
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
      child: Icon(icon, color: _green, size: 30),
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

  Future<void> _showAddMealSheet() async {
    final name = TextEditingController();
    final cost = TextEditingController();
    final calories = TextEditingController();
    AppHaptics.selection();
    Uint8List? photo;
    bool capturing = false;
    String type = 'Breakfast';
    DateTime selectedDate = DateTime.now();
    bool saving = false;
    final formKey = GlobalKey<FormState>();
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
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
                          const Text(
                            'Add Meal History',
                            style: TextStyle(
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
                                  icon: const Icon(Icons.camera_alt_outlined),
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
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              labelText: 'Meal / food name',
                              border: OutlineInputBorder(),
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
                            decoration: const InputDecoration(
                              labelText: 'Meal type',
                              border: OutlineInputBorder(),
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
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                      RegExp(r'[0-9.]'),
                                    ),
                                  ],
                                  decoration: const InputDecoration(
                                    labelText: 'Cost (₱)',
                                    border: OutlineInputBorder(),
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
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                      RegExp(r'[0-9.]'),
                                    ),
                                  ],
                                  decoration: const InputDecoration(
                                    labelText: 'Calories (kcal)',
                                    border: OutlineInputBorder(),
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
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(
                              Icons.calendar_today,
                              color: _green,
                            ),
                            title: Text(
                              DateFormat(
                                'MMM d, yyyy · h:mm a',
                              ).format(selectedDate),
                            ),
                            trailing: const Icon(Icons.edit_calendar),
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
                                          await _mealRef.add({
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
                                            'createdAt':
                                                FieldValue.serverTimestamp(),
                                          });
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
                              child: Text(saving ? 'Saving...' : 'Add Meal'),
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
                  filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
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
                              true,
                              () => _navigate(
                                DashboardPage(userId: widget.userId),
                              ),
                            ),

                            _navItem(
                              Icons.savings_rounded,
                              'budget',
                              false,
                              () =>
                                  _navigate(BudgetPage(userId: widget.userId)),
                            ),

                            const Expanded(child: SizedBox()),

                            _navItem(
                              Icons.flag_rounded,
                              'goals',
                              false,
                              () => _navigate(GoalsPage(userId: widget.userId)),
                            ),

                            _navItem(
                              Icons.person_rounded,
                              'profile',
                              false,
                              () =>
                                  _navigate(ProfilePage(userId: widget.userId)),
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
              onTap:
                  () => Navigator.push(
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
                      border: Border.all(color: _green, width: 2),
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
                        errorBuilder:
                            (context, error, stackTrace) => const Icon(
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

  Widget _navItem(
    IconData icon,
    String label,
    bool active,
    VoidCallback action,
  ) => Expanded(
    child: InkWell(
      onTap: action,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: active ? _blue : _green, size: 23),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: active ? _blue : _green),
          ),
        ],
      ),
    ),
  );

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
