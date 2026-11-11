import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_page.dart';
import 'package:flutter/services.dart';
import 'utils/budget_input.dart';
import 'utils/app_haptics.dart';
import 'utils/health_conditions.dart';
import 'package:intl/intl.dart';
import 'main.dart' show AuthGate;
import 'widgets/welcome_brand.dart';

class SignupPage extends StatefulWidget {
  final String? existingUserId;
  final Map<String, dynamic> initialData;
  const SignupPage({
    super.key,
    this.existingUserId,
    this.initialData = const {},
  });
  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final ageController = TextEditingController();
  final heightController = TextEditingController();
  final weightController = TextEditingController();
  final allergyController = TextEditingController();
  final budgetController = TextEditingController();
  final _scroll = ScrollController();
  final Set<String> _allergies = {};
  final Set<String> _conditions = {};
  int _step = 0;
  bool _saving = false;
  String? _createdUserId;
  String _sex = 'Male';
  String _activity = 'Sedentary';
  static const _titles = [
    'Create Account',
    'Create Profile',
    'Add Food Allergies',
    'Health Conditions (NCDs)',
    'Budget',
  ];

  @override
  void initState() {
    super.initState();
    final data = widget.initialData;
    firstNameController.text = '${data['firstName'] ?? ''}';
    lastNameController.text = '${data['lastName'] ?? ''}';
    if (widget.existingUserId != null) {
      emailController.text = FirebaseAuth.instance.currentUser?.email ?? '';
    }
    ageController.text = '${data['age'] ?? ''}';
    heightController.text = '${data['height'] ?? ''}';
    weightController.text = '${data['weight'] ?? ''}';
    final initialBudget = BudgetInputFormatter.parse('${data['budget'] ?? ''}');
    budgetController.text =
        initialBudget == null
            ? ''
            : NumberFormat('#,##0.##', 'en_US').format(initialBudget);
    _sex = data['sex'] == 'Female' ? 'Female' : 'Male';
    const activities = [
      'Sedentary',
      'Lightly Active',
      'Moderately Active',
      'Active',
      'Very Active',
    ];
    if (activities.contains(data['activityLevel']))
      _activity = data['activityLevel'];
    for (final key in ['allergies', 'ncds']) {
      if (key == 'ncds') {
        _conditions.addAll(healthConditions(data[key]));
        continue;
      }
      final raw = data[key];
      final values =
          raw is List
              ? raw.map((e) => '$e')
              : <String>[if (raw != null && raw != 'None') '$raw'];
      (key == 'allergies' ? _allergies : _conditions).addAll(values);
    }
    if (widget.existingUserId != null) _step = 1;
  }

  @override
  void dispose() {
    for (final controller in [
      firstNameController,
      lastNameController,
      emailController,
      passwordController,
      confirmPasswordController,
      ageController,
      heightController,
      weightController,
      allergyController,
      budgetController,
    ]) {
      controller.dispose();
    }
    _scroll.dispose();
    super.dispose();
  }

  void _message(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  void _move(int step) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    FocusScope.of(context).unfocus();
    AppHaptics.selection();
    setState(() => _step = step);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  bool _validate() {
    if (_step == 0) {
      if ([
        firstNameController,
        lastNameController,
        emailController,
        passwordController,
        confirmPasswordController,
      ].any((c) => c.text.trim().isEmpty)) {
        _message('Please fill all fields');
        return false;
      }
      if (!RegExp(
        r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
      ).hasMatch(emailController.text.trim())) {
        _message('Please enter a valid email address');
        return false;
      }
      if (passwordController.text.length < 6) {
        _message('Use a password with at least 6 characters');
        return false;
      }
      if (passwordController.text != confirmPasswordController.text) {
        _message('Passwords do not match');
        return false;
      }
    }
    if (_step == 1) {
      final age = int.tryParse(ageController.text.trim());
      final height = double.tryParse(heightController.text.trim());
      final weight = double.tryParse(weightController.text.trim());
      if (firstNameController.text.trim().isEmpty ||
          lastNameController.text.trim().isEmpty ||
          age == null ||
          age <= 0 ||
          height == null ||
          !height.isFinite ||
          height <= 0 ||
          weight == null ||
          !weight.isFinite ||
          weight <= 0) {
        _message('Enter your name and valid age, height, and weight');
        return false;
      }
    }
    if (_step == 4) {
      final budget = BudgetInputFormatter.parse(budgetController.text.trim());
      if (budget == null ||
          !budget.isFinite ||
          budget <= 0 ||
          budget > 100000) {
        _message('Enter a monthly food budget between 0.01 and 100,000');
        return false;
      }
    }
    return true;
  }

  void _addAllergy() {
    final allergy = allergyController.text.trim();
    if (allergy.isEmpty) return;
    AppHaptics.selection();
    setState(() {
      _allergies.add(allergy);
      allergyController.clear();
    });
  }

  Future<void> _next() async {
    if (_saving || !_validate()) return;
    if (_step == 2) _addAllergy();
    if (_step < 4) {
      _move(_step + 1);
      return;
    }
    setState(() => _saving = true);
    try {
      var uid = widget.existingUserId ?? _createdUserId;
      if (uid == null) {
        final credential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(
              email: emailController.text.trim(),
              password: passwordController.text,
            );
        uid = credential.user!.uid;
        _createdUserId =
            uid; // Retry the profile write without creating another account.
      }
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'firstName': firstNameController.text.trim(),
        'lastName': lastNameController.text.trim(),
        'name':
            '${firstNameController.text.trim()} ${lastNameController.text.trim()}',
        'age': int.parse(ageController.text.trim()),
        'height': double.parse(heightController.text.trim()),
        'weight': double.parse(weightController.text.trim()),
        'sex': _sex,
        'activityLevel': _activity,
        'allergies': _allergies.toList(),
        'ncds': _conditions.toList(),
        'budget': BudgetInputFormatter.parse(budgetController.text.trim())!,
        'onboardingComplete': true,
      }, SetOptions(merge: true));
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthGate()),
        (_) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      _message(e.message ?? 'Could not create your account. Please try again.');
      if (e.code == 'email-already-in-use' ||
          e.code == 'invalid-email' ||
          e.code == 'weak-password')
        _move(0);
    } catch (_) {
      if (mounted)
        _message(
          'Could not save your profile. Check your connection and try again.',
        );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving && _step == 0,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop && !_saving && _step > 0) _move(_step - 1);
    },
    child: Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final headerHeight = (constraints.maxHeight * .36).clamp(
              190.0,
              280.0,
            );
            return SingleChildScrollView(
              controller: _scroll,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(
                children: [
                  SizedBox(
                    height: headerHeight,
                    width: double.infinity,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: WelcomeBrand(),
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - headerHeight,
                    ),
                    decoration: const BoxDecoration(
                      color: Color(0xFF7AB84D),
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(40),
                      ),
                    ),
                    padding: EdgeInsets.fromLTRB(
                      28,
                      24,
                      28,
                      20 + MediaQuery.paddingOf(context).bottom,
                    ),
                    child: Column(
                      children: [
                        Text(
                          _titles[_step],
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Start your nutrition tracking journey',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white, fontSize: 11),
                        ),
                        const SizedBox(height: 16),
                        Semantics(
                          label: 'Step ${_step + 1} of 5: ${_titles[_step]}',
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              5,
                              (index) => Container(
                                width: 22,
                                height: 5,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 3,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      index == _step
                                          ? const Color(0xFF206589)
                                          : const Color(0xFFD7E9C9),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        AbsorbPointer(
                          absorbing: _saving,
                          child: Column(
                            key: ValueKey(_step),
                            children: _fields(),
                          ),
                        ),
                        const SizedBox(height: 26),
                        SizedBox(
                          width: double.infinity,
                          height: 46,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2E7D32),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: _saving ? null : _next,
                            child:
                                _saving
                                    ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                    : Text(
                                      _step == 4 ? 'Create Account' : 'Next →',
                                    ),
                          ),
                        ),
                        if (_step > 0)
                          TextButton(
                            onPressed: _saving ? null : () => _move(_step - 1),
                            child: const Text(
                              'Back',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        if (_step == 0 &&
                            widget.existingUserId == null &&
                            _createdUserId == null)
                          TextButton(
                            onPressed:
                                () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const LoginPage(),
                                  ),
                                ),
                            child: const Text(
                              'Already have an account? Log In',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    ),
  );

  Widget _field(
    String label,
    TextEditingController controller, {
    String hint = '',
    bool password = false,
    TextInputType? keyboard,
    Widget? suffix,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: CustomTextField(
      label: label,
      hint: hint,
      icon:
          password
              ? Icons.lock_outline
              : label == 'Email'
              ? Icons.email_outlined
              : Icons.edit_outlined,
      controller: controller,
      isPassword: password,
      keyboardType: keyboard,
      suffix: suffix,
      inputFormatters:
          controller == budgetController ? [BudgetInputFormatter()] : null,
    ),
  );

  Widget _dropdown(
    String label,
    String value,
    List<String> choices,
    ValueChanged<String> change,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 5),
        DropdownButtonFormField<String>(
          initialValue: value,
          isExpanded: true,
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF8FBF5),
            isDense: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
          style: const TextStyle(fontSize: 12, color: Colors.black87),
          items:
              choices
                  .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                  .toList(),
          onChanged: (v) {
            if (v != null) setState(() => change(v));
          },
        ),
      ],
    ),
  );

  List<Widget> _fields() {
    if (_step == 0) {
      return [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _field('First Name', firstNameController, hint: 'John'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _field('Last Name', lastNameController, hint: 'Doe'),
            ),
          ],
        ),
        _field(
          'Email',
          emailController,
          hint: 'your@email.com',
          keyboard: TextInputType.emailAddress,
        ),
        _field(
          'Password',
          passwordController,
          hint: '••••••••',
          password: true,
        ),
        _field(
          'Confirm Password',
          confirmPasswordController,
          hint: '••••••••',
          password: true,
        ),
      ];
    }
    if (_step == 1) {
      return [
        if (widget.existingUserId != null) ...[
          _field('First Name', firstNameController),
          _field('Last Name', lastNameController),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _field(
                'Age',
                ageController,
                hint: '23',
                keyboard: TextInputType.number,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _field(
                'Height (cm)',
                heightController,
                hint: '180',
                keyboard: const TextInputType.numberWithOptions(decimal: true),
              ),
            ),
          ],
        ),
        _field(
          'Weight (kg)',
          weightController,
          hint: '65',
          keyboard: const TextInputType.numberWithOptions(decimal: true),
        ),
        _dropdown('Sex', _sex, ['Male', 'Female'], (v) => _sex = v),
        _dropdown('How often do you exercise?', _activity, [
          'Sedentary',
          'Lightly Active',
          'Moderately Active',
          'Active',
          'Very Active',
        ], (v) => _activity = v),
      ];
    }
    if (_step == 2) {
      return [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _field(
                'Food allergy',
                allergyController,
                hint: 'e.g. Dairy',
                suffix: IconButton(
                  onPressed: _addAllergy,
                  tooltip: 'Add allergy',
                  icon: const Icon(Icons.add_circle, color: Color(0xFF2E7D32)),
                ),
              ),
            ),
          ],
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children:
              {
                    ...['Peanuts', 'Dairy', 'Shellfish'],
                    ..._allergies,
                  }
                  .map(
                    (allergy) => FilterChip(
                      label: Text(allergy),
                      selected: _allergies.contains(allergy),
                      onSelected:
                          (selected) => setState(() {
                            AppHaptics.selection();
                            selected
                                ? _allergies.add(allergy)
                                : _allergies.remove(allergy);
                          }),
                    ),
                  )
                  .toList(),
        ),
        const SizedBox(height: 10),
        const Text(
          'No food allergies? Leave these unselected and tap Next.',
          style: TextStyle(color: Colors.white, fontSize: 11),
        ),
      ];
    }
    if (_step == 3) {
      return [
        for (final condition in [
          'Hypertension',
          'High Cholesterol',
          'Type 1 Diabetes',
          'Type 2 Diabetes',
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: const Color(0xFFF8FBF5),
              borderRadius: BorderRadius.circular(8),
              child: CheckboxListTile(
                dense: true,
                title: Text(condition, style: const TextStyle(fontSize: 12)),
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: const Color(0xFF2E7D32),
                value: _conditions.contains(condition),
                onChanged:
                    (selected) => setState(() {
                      AppHaptics.selection();
                      selected == true
                          ? _conditions.add(condition)
                          : _conditions.remove(condition);
                    }),
              ),
            ),
          ),
        const Text(
          'None? Leave these unselected and tap Next.',
          style: TextStyle(color: Colors.white, fontSize: 11),
        ),
      ];
    }
    final budget = BudgetInputFormatter.parse(budgetController.text) ?? 0;
    final days = DateUtils.getDaysInMonth(
      DateTime.now().year,
      DateTime.now().month,
    );
    return [
      _field(
        'Monthly Budget (PHP)',
        budgetController,
        hint: 'Up to 100,000',
        keyboard: const TextInputType.numberWithOptions(decimal: true),
      ),
      ValueListenableBuilder<TextEditingValue>(
        valueListenable: budgetController,
        builder: (context, value, _) {
          final monthly = BudgetInputFormatter.parse(value.text) ?? budget;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Automated Daily Budget (PHP)',
                style: TextStyle(fontSize: 11, color: Colors.white),
              ),
              const SizedBox(height: 5),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FBF5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  monthly.isFinite && monthly > 0
                      ? (monthly / days).toStringAsFixed(2)
                      : 'Monthly budget ÷ days this month',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ),
            ],
          );
        },
      ),
    ];
  }
}

class CustomTextField extends StatefulWidget {
  final String label;
  final String hint;
  final IconData icon;
  final bool isPassword;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final Widget? suffix;
  final List<TextInputFormatter>? inputFormatters;
  const CustomTextField({
    super.key,
    required this.label,
    required this.hint,
    required this.icon,
    required this.controller,
    this.isPassword = false,
    this.keyboardType,
    this.autofillHints,
    this.suffix,
    this.inputFormatters,
  });
  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  bool _visible = false;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        widget.label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      const SizedBox(height: 5),
      TextField(
        controller: widget.controller,
        inputFormatters: widget.inputFormatters,
        obscureText: widget.isPassword && !_visible,
        keyboardType: widget.keyboardType,
        autofillHints: widget.autofillHints,
        autocorrect: !widget.isPassword,
        enableSuggestions: !widget.isPassword,
        style: const TextStyle(fontSize: 12),
        decoration: InputDecoration(
          isDense: true,
          prefixIcon: Icon(widget.icon, size: 19, color: Colors.black45),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 36,
            minHeight: 40,
          ),
          hintText: widget.hint,
          suffixIcon:
              widget.isPassword
                  ? IconButton(
                    tooltip: _visible ? 'Hide password' : 'Show password',
                    onPressed: () => setState(() => _visible = !_visible),
                    icon: Icon(
                      _visible ? Icons.visibility_off : Icons.visibility,
                    ),
                  )
                  : widget.suffix,
          filled: true,
          fillColor: const Color(0xFFF8FBF5),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    ],
  );
}
