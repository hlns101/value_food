import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'utils/health_conditions.dart';
import 'utils/budget_input.dart';
import 'utils/app_haptics.dart';

class EditProfilePage extends StatefulWidget {
  final String userId;

  const EditProfilePage({super.key, required this.userId});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  static const _green = Color(0xFF287D35);
  static const _blue = Color(0xFF2987B0);
  static const _navy = Color(0xFF095574);
  static const _background = Color(0xFFF7FAF7);

  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final ageController = TextEditingController();
  final heightController = TextEditingController();
  final weightController = TextEditingController();
  final budgetController = TextEditingController();
  final allergyController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  List<String> allergies = [];
  String selectedSex = 'Male';
  String selectedLevel = 'Sedentary';
  Set<String> selectedNCDs = {};
  bool loading = true;
  bool saving = false;

  static const _activityOptions = [
    'Sedentary',
    'Lightly Active',
    'Moderately Active',
    'Active',
    'Very Active',
  ];

  static const _ncdOptions = [
    'High Cholesterol',
    'Type 1 Diabetes',
    'Type 2 Diabetes',
    'Hypertension',
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  double _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? 0;
  }

  Future<void> _loadData() async {
    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(widget.userId)
              .get();
      final data = doc.data() ?? <String, dynamic>{};
      if (!mounted) return;

      final heightCm = _number(data['height']);
      final weightKg = _number(data['weight']);
      setState(() {
        firstNameController.text = (data['firstName'] ?? '').toString();
        lastNameController.text = (data['lastName'] ?? '').toString();
        ageController.text = '${_number(data['age']).round()}';
        heightController.text = heightCm > 0 ? heightCm.toStringAsFixed(1) : '';
        weightController.text =
            weightKg > 0 ? (weightKg * 2.2046226218).toStringAsFixed(1) : '';
        budgetController.text = NumberFormat(
          '#,##0.##',
          'en_US',
        ).format(_number(data['budget'] ?? data['monthlyLimit']));
        allergies =
            data['allergies'] is List
                ? (data['allergies'] as List).map((a) => '$a').toList()
                : <String>[];
        final sex = (data['sex'] ?? 'Male').toString();
        selectedSex = ['Male', 'Female'].contains(sex) ? sex : 'Male';
        final activity = (data['activityLevel'] ?? 'Sedentary').toString();
        selectedLevel =
            _activityOptions.contains(activity) ? activity : 'Sedentary';
        selectedNCDs = healthConditions(data['ncds']).toSet();
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to load profile information.')),
      );
    }
  }

  void _addAllergy([String? value]) {
    final text = (value ?? allergyController.text).trim();
    if (text.isEmpty) return;
    if (!allergies.any(
      (allergy) => allergy.toLowerCase() == text.toLowerCase(),
    )) {
      setState(() => allergies.add(text));
    }
    allergyController.clear();
  }

  Future<void> _saveChanges() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final heightCm = double.parse(heightController.text);
    final weightLbs = double.parse(weightController.text);
    final monthlyBudget = double.parse(
      budgetController.text.replaceAll(',', ''),
    );

    setState(() => saving = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(widget.userId).set({
        'firstName': firstNameController.text.trim(),
        'lastName': lastNameController.text.trim(),
        'name':
            '${firstNameController.text.trim()} ${lastNameController.text.trim()}'
                .trim(),
        'age': int.parse(ageController.text),
        // Existing profile and Goals logic use centimeters and kilograms.
        'height': heightCm,
        'weight': weightLbs / 2.2046226218,
        'budget': monthlyBudget,
        'monthlyLimit': monthlyBudget,
        'allergies': allergies,
        'sex': selectedSex,
        'activityLevel': selectedLevel,
        'ncds': selectedNCDs.toList(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      AppHaptics.selection();
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save changes. Please try again.'),
        ),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  void dispose() {
    firstNameController.dispose();
    lastNameController.dispose();
    ageController.dispose();
    heightController.dispose();
    weightController.dispose();
    budgetController.dispose();
    allergyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: _green),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Edit Personal Info',
              style: TextStyle(
                color: _navy,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              'Update metrics used for meal & label analysis',
              style: TextStyle(color: Colors.black45, fontSize: 10),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: saving ? null : _loadData,
            child: const Text(
              'Reset',
              style: TextStyle(color: _green, fontSize: 11),
            ),
          ),
        ],
      ),
      body:
          loading
              ? const Center(child: CircularProgressIndicator(color: _green))
              : Form(
                key: _formKey,
                child: Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(17, 12, 17, 20),
                        children: [
                          _section(
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _sectionTitle(
                                  'Body & Budget Metrics',
                                  'Auto-computes BMI',
                                ),
                                const SizedBox(height: 13),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _field(
                                        'First Name',
                                        firstNameController,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _field(
                                        'Last Name',
                                        lastNameController,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 11),
                                _dropdown(
                                  'Sex',
                                  selectedSex,
                                  const ['Male', 'Female'],
                                  (value) =>
                                      setState(() => selectedSex = value),
                                ),
                                const SizedBox(height: 11),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _field(
                                        'Age',
                                        ageController,
                                        suffix: 'years',
                                        integer: true,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _field(
                                        'Height',
                                        heightController,
                                        suffix: 'cm',
                                        numeric: true,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 11),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _field(
                                        'Current Weight',
                                        weightController,
                                        suffix: 'lbs',
                                        numeric: true,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _field(
                                        'Monthly Food Budget',
                                        budgetController,
                                        prefix: '₱ ',
                                        numeric: true,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          _section(
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _sectionTitle(
                                  'Lifestyle & Health Condition',
                                  '',
                                ),
                                const SizedBox(height: 13),
                                _dropdown(
                                  'How often do you exercise?',
                                  selectedLevel,
                                  _activityOptions,
                                  (value) =>
                                      setState(() => selectedLevel = value),
                                ),
                                const SizedBox(height: 13),
                                Text(
                                  'Health Conditions · ${selectedNCDs.length} Active',
                                ),
                                for (final condition in {
                                  ..._ncdOptions,
                                  ...selectedNCDs,
                                })
                                  CheckboxListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(condition),
                                    value: selectedNCDs.contains(condition),
                                    onChanged:
                                        saving
                                            ? null
                                            : (active) {
                                              AppHaptics.selection();
                                              setState(
                                                () =>
                                                    active == true
                                                        ? selectedNCDs.add(
                                                          condition,
                                                        )
                                                        : selectedNCDs.remove(
                                                          condition,
                                                        ),
                                              );
                                            },
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          _section(
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _sectionTitle(
                                  'Food Allergies',
                                  '${allergies.length} Active',
                                ),
                                const Text(
                                  'Flagged when reviewing scanned food labels',
                                  style: TextStyle(
                                    color: Colors.black45,
                                    fontSize: 10,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: allergyController,
                                        textCapitalization:
                                            TextCapitalization.words,
                                        decoration: _inputDecoration(
                                          'e.g. shellfish, soy, tree nuts',
                                        ),
                                        onSubmitted: _addAllergy,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    FilledButton.icon(
                                      onPressed: _addAllergy,
                                      icon: const Icon(Icons.add, size: 17),
                                      label: const Text('Add'),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: _green,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                const Text(
                                  'SELECTED ALLERGENS',
                                  style: TextStyle(
                                    color: Colors.black54,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 10,
                                  ),
                                ),
                                const SizedBox(height: 7),
                                if (allergies.isEmpty)
                                  const Text(
                                    'No allergies added',
                                    style: TextStyle(color: Colors.black45),
                                  )
                                else
                                  Wrap(
                                    spacing: 7,
                                    runSpacing: 6,
                                    children:
                                        allergies
                                            .map(
                                              (allergy) => InputChip(
                                                label: Text(
                                                  allergy,
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                  ),
                                                ),
                                                backgroundColor: const Color(
                                                  0xFFFDECEC,
                                                ),
                                                deleteIcon: const Icon(
                                                  Icons.close,
                                                  size: 15,
                                                ),
                                                onDeleted:
                                                    () => setState(
                                                      () => allergies.remove(
                                                        allergy,
                                                      ),
                                                    ),
                                                side: const BorderSide(
                                                  color: Color(0xFFF5C4C4),
                                                ),
                                              ),
                                            )
                                            .toList(),
                                  ),
                                const SizedBox(height: 15),
                                const Text(
                                  'COMMON QUICK-ADD',
                                  style: TextStyle(
                                    color: Colors.black54,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 10,
                                  ),
                                ),
                                const SizedBox(height: 7),
                                Wrap(
                                  spacing: 7,
                                  runSpacing: 5,
                                  children:
                                      ['Eggs', 'Shellfish', 'Soy', 'Gluten']
                                          .map(
                                            (item) => ActionChip(
                                              label: Text(
                                                '+ $item',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                ),
                                              ),
                                              onPressed:
                                                  () => _addAllergy(item),
                                              backgroundColor: _background,
                                              side: const BorderSide(
                                                color: Color(0xFFE3EDE2),
                                              ),
                                            ),
                                          )
                                          .toList(),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.fromLTRB(
                        17,
                        13,
                        17,
                        10 + MediaQuery.of(context).padding.bottom,
                      ),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        border: Border(
                          top: BorderSide(color: Color(0xFFE3EDE2)),
                        ),
                      ),
                      child: Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            height: 49,
                            child: FilledButton(
                              onPressed: saving ? null : _saveChanges,
                              style: FilledButton.styleFrom(
                                backgroundColor: _green,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(28),
                                ),
                              ),
                              child: Text(
                                saving ? 'Saving...' : 'Save Changes',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed:
                                saving ? null : () => Navigator.pop(context),
                            child: const Text(
                              'Cancel & Discard',
                              style: TextStyle(
                                color: Colors.black45,
                                fontSize: 11,
                              ),
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

  Widget _section(Widget child) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFE3EDE2)),
    ),
    child: child,
  );

  Widget _sectionTitle(String title, String caption) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: const TextStyle(
            color: _navy,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      if (caption.isNotEmpty)
        Text(
          caption,
          style: TextStyle(
            fontSize: 10,
            color:
                caption.contains('Active') ? Colors.redAccent : Colors.black45,
          ),
        ),
    ],
  );

  InputDecoration _inputDecoration(
    String hint, {
    String? suffix,
    String? prefix,
  }) {
    return InputDecoration(
      hintText: hint,
      suffixText: suffix,
      prefixText: prefix,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 13),
      filled: true,
      fillColor: const Color(0xFFF8FAF8),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: const BorderSide(color: Color(0xFFE0EAE0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: const BorderSide(color: Color(0xFFE0EAE0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: const BorderSide(color: _green, width: 1.3),
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    String? suffix,
    String? prefix,
    bool numeric = false,
    bool integer = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: _navy,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType:
              numeric || integer
                  ? TextInputType.numberWithOptions(decimal: !integer)
                  : TextInputType.text,
          inputFormatters:
              controller == budgetController
                  ? [BudgetInputFormatter()]
                  : numeric || integer
                  ? [
                    FilteringTextInputFormatter.allow(
                      RegExp(integer ? r'[0-9]' : r'[0-9.]'),
                    ),
                  ]
                  : null,
          decoration: _inputDecoration('', suffix: suffix, prefix: prefix),
          validator: (value) {
            if ((value ?? '').trim().isEmpty) return 'Required';
            if (numeric || integer) {
              final number = double.tryParse(value!.replaceAll(',', ''));
              if (number == null || !number.isFinite || number <= 0)
                return 'Invalid value';
              if (controller == budgetController && number > 100000)
                return 'Maximum 100,000';
              if (integer && number != number.roundToDouble())
                return 'Whole number only';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _dropdown(
    String label,
    String value,
    List<String> items,
    ValueChanged<String> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: _navy,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: value,
          isExpanded: true,
          decoration: _inputDecoration(''),
          items:
              items
                  .map(
                    (item) => DropdownMenuItem(
                      value: item,
                      child: Text(
                        item,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  )
                  .toList(),
          onChanged:
              saving
                  ? null
                  : (selected) {
                    if (selected != null) onChanged(selected);
                  },
        ),
      ],
    );
  }
}
