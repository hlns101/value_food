import 'widgets/dashboard_header.dart';
import 'dart:math' as math;
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'utils/page_transitions.dart';
import 'budget_page.dart';
import 'dashboard_page.dart';
import 'edit_profile_page.dart';
import 'goals_page.dart';
import 'label_page.dart';
import 'login_page.dart';
import 'utils/health_conditions.dart';
import 'utils/app_haptics.dart';

class ProfilePage extends StatefulWidget {
  final String userId;

  const ProfilePage({super.key, required this.userId});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  static const _green = Color(0xFF287D35);
  static const _lightGreen = Color(0xFF7DB848);
  static const _blue = Color(0xFF2987B0);
  static const _navy = Color(0xFF095574);
  static const _background = Color(0xFFF7FAF7);

  final _peso = NumberFormat.currency(
    locale: 'en_PH',
    symbol: '₱',
    decimalDigits: 0,
  );

  DocumentReference<Map<String, dynamic>> get _userRef =>
      FirebaseFirestore.instance.collection('users').doc(widget.userId);

  double _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? 0;
  }

  Future<void> _editProfile() async {
    AppHaptics.selection();
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditProfilePage(userId: widget.userId)),
    );
    // Profile data is streamed, so edits are reflected without a manual reload.
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Log out?'),
            content: const Text('Are you sure you want to log out?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Log out'),
              ),
            ],
          ),
    );

    if (confirmed != true) return;
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }

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
              builder: (context, snapshot) {
                final data = snapshot.data?.data() ?? <String, dynamic>{};
                final name =
                    (data['firstName'] ?? data['name'] ?? 'User')
                        .toString()
                        .trim();
                final lastName = (data['lastName'] ?? '').toString().trim();
                final age = _number(data['age']).round();
                final heightCm = _number(data['height']);
                final weightKg = _number(data['weight']);
                final monthlyBudget = _number(
                  data['budget'] ?? data['monthlyLimit'],
                );
                final allergies =
                    (data['allergies'] is List)
                        ? (data['allergies'] as List).map((a) => '$a').toList()
                        : <String>[];
                final activity =
                    (data['activityLevel'] ?? 'Sedentary').toString();
                final conditions = healthConditions(data['ncds']);
                final condition =
                    conditions.isEmpty ? 'None' : conditions.join(', ');
                final bmi =
                    heightCm > 0 && weightKg > 0
                        ? weightKg / math.pow(heightCm / 100, 2)
                        : 0.0;
                final bmiText = bmi == 0 ? '—' : bmi.toStringAsFixed(1);
                final bmiLabel =
                    bmi == 0
                        ? 'Unavailable'
                        : bmi < 18.5
                        ? 'Underweight'
                        : bmi < 25
                        ? 'Normal'
                        : bmi < 30
                        ? 'Overweight'
                        : 'Obese';

                return ListView(
                  padding: EdgeInsets.fromLTRB(
                    17,
                    22,
                    17,
                    142 + MediaQuery.of(context).padding.bottom,
                  ),
                  children: [
                    _header(name.isEmpty ? 'User' : name),
                    const SizedBox(height: 22),
                    if (snapshot.hasError) ...[
                      const Text(
                        'Unable to load your profile. Check your connection or Firestore access.',
                        style: TextStyle(color: Colors.red),
                      ),
                      const SizedBox(height: 12),
                    ],
                    _personalCard(
                      name: name,
                      lastName: lastName,
                      age: age,
                      heightCm: heightCm,
                      weightKg: weightKg,
                    ),
                    const SizedBox(height: 12),
                    _bmiCard(bmi, bmiText, bmiLabel),
                    const SizedBox(height: 12),
                    _budgetCard(monthlyBudget),
                    const SizedBox(height: 12),
                    _allergyCard(activity, condition, allergies),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFE3EDE2)),
                      ),
                      child: SwitchListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        activeThumbColor: Colors.white,
                        activeTrackColor: _green,
                        inactiveThumbColor: _green,
                        inactiveTrackColor: const Color(0xFFEAF5EA),
                        secondary: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAF5EA),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.vibration_rounded,
                            color: _green,
                            size: 22,
                          ),
                        ),
                        title: const Text(
                          'Haptic Feedback',
                          style: TextStyle(
                            color: _navy,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        subtitle: const Text(
                          'Vibrate for selections and actions',
                          style: TextStyle(color: Colors.black54, fontSize: 11),
                        ),
                        value: data['hapticsEnabled'] != false,
                        onChanged:
                            !snapshot.hasData
                                ? null
                                : (enabled) async {
                                  final previous = AppHaptics.enabled;
                                  AppHaptics.enabled = enabled;
                                  try {
                                    await _userRef.set({
                                      'hapticsEnabled': enabled,
                                    }, SetOptions(merge: true));
                                    AppHaptics.selection();
                                  } catch (_) {
                                    AppHaptics.enabled = previous;
                                    if (context.mounted)
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Could not save haptic preference.',
                                          ),
                                        ),
                                      );
                                  }
                                },
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton.icon(
                      onPressed: _logout,
                      icon: const Icon(Icons.logout_rounded, size: 18),
                      label: const Text('Log out'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red.shade600,
                      ),
                    ),
                  ],
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
    pageTitle: 'Profile',
    subtitle: 'Manage your personal & health information',
  );

  Widget _personalCard({
    required String name,
    required String lastName,
    required int age,
    required double heightCm,
    required double weightKg,
  }) {
    final heightInches = heightCm / 2.54;
    final feet = heightInches ~/ 12;
    final inches = (heightInches - feet * 12).round();
    final pounds = weightKg * 2.2046226218;
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: _lightGreen,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 20,
                backgroundColor: Colors.white,
                child: Icon(Icons.person_outline, color: _green),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Personal Info',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '${name.isEmpty ? 'User' : name} ${lastName.isEmpty ? '' : lastName} · Health & nutrition profile',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: _editProfile,
                icon: const Icon(Icons.edit_outlined, size: 14),
                label: const Text('Edit'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.white24,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _summaryTile('Age', '$age', 'yrs'),
              const SizedBox(width: 7),
              _summaryTile(
                'Height',
                heightCm == 0 ? '—' : '${heightInches.round()}″',
                heightCm == 0 ? '' : '($feet′${inches % 12}″)',
              ),
              const SizedBox(width: 7),
              _summaryTile(
                'Weight',
                weightKg == 0 ? '—' : pounds.toStringAsFixed(0),
                'lbs',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryTile(String label, String value, String suffix) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(color: Colors.black45, fontSize: 10),
            ),
            const SizedBox(height: 5),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: value,
                      style: const TextStyle(
                        color: _green,
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                      ),
                    ),
                    TextSpan(
                      text: ' $suffix',
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 10,
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
  }

  Widget _sectionCard(Widget child) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE3EDE2)),
      ),
      child: child,
    );
  }

  Widget _bmiCard(double bmi, String value, String label) {
    final position = bmi <= 0 ? 0.5 : ((bmi - 15) / 25).clamp(0.0, 1.0);
    return _sectionCard(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Body Mass Index (BMI)',
                  style: TextStyle(
                    color: _navy,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
              _pill(label, const Color(0xFFE9F5EA), _green),
            ],
          ),
          const SizedBox(height: 9),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: _green,
                  fontSize: 27,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Adult BMI reference: 18.5–24.9',
                  style: TextStyle(color: Colors.black45, fontSize: 10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Row(
                    children: [
                      _bmiSegment(const Color(0xFF3287A8), 3),
                      _bmiSegment(const Color(0xFF51B35B), 3),
                      _bmiSegment(const Color(0xFFF1A231), 3),
                      _bmiSegment(const Color(0xFFE84B49), 3),
                    ],
                  ),
                  if (bmi > 0)
                    Positioned(
                      left: math.max(0.0, constraints.maxWidth * position - 7),
                      top: -4,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: _green, width: 2),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '<18.5 Under',
                style: TextStyle(color: Colors.black45, fontSize: 9),
              ),
              Text(
                '18.5–24.9 Normal',
                style: TextStyle(color: _green, fontSize: 9),
              ),
              Text(
                '25–29.9 Over',
                style: TextStyle(color: Colors.black45, fontSize: 9),
              ),
              Text(
                '30+ Obese',
                style: TextStyle(color: Colors.black45, fontSize: 9),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bmiSegment(Color color, int flex) => Expanded(
    flex: flex,
    child: Container(
      height: 7,
      margin: const EdgeInsets.only(right: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(7),
      ),
    ),
  );

  Widget _pill(String text, Color bg, Color fg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.w700),
    ),
  );

  Widget _budgetCard(double budget) {
    return _sectionCard(
      InkWell(
        onTap: () => _navigate(BudgetPage(userId: widget.userId)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  radius: 17,
                  backgroundColor: Color(0xFFEAF5EA),
                  child: Icon(Icons.savings_outlined, color: _green, size: 19),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Grocery Budget',
                        style: TextStyle(color: Colors.black45, fontSize: 11),
                      ),
                      Text(
                        _peso.format(budget),
                        style: const TextStyle(
                          color: _green,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                _pill('Monthly Budget', const Color(0xFFE9F5EA), _green),
              ],
            ),
            const Divider(height: 23),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Monthly food limit: ${_peso.format(budget)}',
                    style: const TextStyle(color: Colors.black54, fontSize: 11),
                  ),
                ),
                const Icon(Icons.chevron_right, size: 19, color: _green),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _allergyCard(
    String activity,
    String condition,
    List<String> allergies,
  ) {
    return _sectionCard(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.health_and_safety_outlined,
                color: Colors.redAccent,
                size: 18,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Health & Food Allergies',
                  style: TextStyle(
                    color: _navy,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
              _pill('Scan Guard', const Color(0xFFE9F5EA), _green),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _detailTile('Exercise Frequency', activity)),
              const SizedBox(width: 7),
              Expanded(child: _detailTile('Current NCD', condition)),
            ],
          ),
          const Divider(height: 24),
          const Text(
            'Recorded Food Allergies',
            style: TextStyle(
              color: _navy,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Text(
            'Triggers to consider when reviewing packaged food labels',
            style: TextStyle(color: Colors.black45, fontSize: 10),
          ),
          const SizedBox(height: 10),
          if (allergies.isEmpty)
            const Text(
              'No food allergies recorded',
              style: TextStyle(color: Colors.black54, fontSize: 12),
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 5,
              children:
                  allergies
                      .map(
                        (a) => _pill(
                          '• $a',
                          const Color(0xFFFCEBEB),
                          Colors.red.shade700,
                        ),
                      )
                      .toList(),
            ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _editProfile,
            icon: const Icon(Icons.edit_outlined, size: 15),
            label: const Text('Manage Allergies'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _green,
              side: const BorderSide(color: Color(0xFFE3EDE2)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailTile(String label, String value) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: _background,
      borderRadius: BorderRadius.circular(11),
      border: Border.all(color: const Color(0xFFE3EDE2)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.black45, fontSize: 10),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: const TextStyle(
            color: _navy,
            fontWeight: FontWeight.w700,
            fontSize: 11,
          ),
        ),
      ],
    ),
  );

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
                  filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(38),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withOpacity(0.10),
                          Colors.white.withOpacity(0.03),
                          Colors.white.withOpacity(0.08),
                        ],
                      ),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.20),
                        width: 0.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        _navItem(
                          Icons.home_rounded,
                          'home',
                          false,
                          () => _navigate(DashboardPage(userId: widget.userId)),
                        ),
                        _navItem(
                          Icons.savings_rounded,
                          'budget',
                          false,
                          () => _navigate(BudgetPage(userId: widget.userId)),
                        ),
                        const Expanded(child: SizedBox()),
                        _navItem(
                          Icons.flag_rounded,
                          'goals',
                          false,
                          () => _navigate(GoalsPage(userId: widget.userId)),
                        ),
                        _navItem(Icons.person_rounded, 'profile', true, () {}),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
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
                            (_, __, ___) => const Icon(
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
                      letterSpacing: .35,
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
  ) {
    return Expanded(
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
  }

  void _navigate(Widget page) {
    if (!mounted) return;
    AppHaptics.selection();

    Navigator.of(context).pushReplacement(SmoothPageRoute(page: page));
  }
}
