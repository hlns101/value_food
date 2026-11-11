import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class MonthlyPage extends StatefulWidget {
  final String userId;
  const MonthlyPage({super.key, required this.userId});

  @override
  State<MonthlyPage> createState() => _MonthlyPageState();
}

class _MonthlyPageState extends State<MonthlyPage> {
  static const green = Color(0xFF287D35);
  final _controller = TextEditingController();
  final _currency = NumberFormat.currency(
    locale: 'en_PH', symbol: '₱', decimalDigits: 0,
  );
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _mealHistory;
  bool _saving = false;
  double _original = 0;

  @override
  void initState() {
    super.initState();
    _mealHistory = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('mealHistory')
        .snapshots();
    _load();
  }

  Future<void> _load() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users').doc(widget.userId).get();
      final data = doc.data() ?? {};
      final raw = data['budget'] ?? data['monthlyLimit'] ?? 0;
      final value = _asDouble(raw);
      if (!mounted) return;
      setState(() {
        _original = value;
        _controller.text = value.toStringAsFixed(2);
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to load monthly budget.')),
        );
      }
    }
  }

  double _asDouble(dynamic raw) {
    if (raw is num) return raw.toDouble();
    return double.tryParse('$raw'.replaceAll(',', '')) ?? 0;
  }

  DateTime? _asDate(dynamic raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }

  // The Dashboard's Meal History must store a date and a total cost for each
  // expense. Adjust these keys if your groupmate uses different field names.
  double _spentThisMonth(QuerySnapshot<Map<String, dynamic>> snapshot) {
    final now = DateTime.now();
    double total = 0;
    for (final doc in snapshot.docs) {
      final meal = doc.data();
      final date = _asDate(meal['date'] ?? meal['consumedAt'] ?? meal['createdAt']);
      if (date == null || date.year != now.year || date.month != now.month || date.isAfter(now)) {
        continue;
      }
      final cost = _asDouble(meal['totalCost'] ?? meal['amount'] ?? meal['price']);
      if (cost.isFinite && cost > 0) total += cost;
    }
    return total;
  }

  Future<void> _save() async {
    final value = double.tryParse(_controller.text.replaceAll(',', ''));
    if (value == null || !value.isFinite || value <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid monthly budget greater than zero.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(widget.userId).set({
        'budget': value,
        'monthlyLimit': value,
        // Preserve a custom weeklyLimit, if one exists.
      }, SetOptions(merge: true));
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save your budget. Try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entered = double.tryParse(_controller.text.replaceAll(',', '')) ?? 0;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F8F4),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: green),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Edit Monthly Budget', style: TextStyle(
              color: Color(0xFF3981A3), fontWeight: FontWeight.bold, fontSize: 20,
            )),
            Text('Set or adjust your total monthly food budget',
              style: TextStyle(fontSize: 10, color: Colors.black45)),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(17),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(19),
                border: Border.all(color: const Color(0xFFE1EBE1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('AMOUNT (₱)', style: TextStyle(
                    color: green, fontSize: 12, fontWeight: FontWeight.w800,
                  )),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _controller,
                    onChanged: (_) => setState(() {}),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                    style: const TextStyle(
                      color: Color(0xFF287FA7), fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                    decoration: InputDecoration(
                      prefixText: '₱ ',
                      enabledBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: green),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: green, width: 2),
                        borderRadius: BorderRadius.circular(11),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text('Current saved limit: ${_currency.format(_original)}',
                    style: const TextStyle(color: Colors.black54, fontSize: 12)),
                  const SizedBox(height: 12),
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _mealHistory,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return const Text('Unable to load Meal History spending.',
                          style: TextStyle(color: Colors.redAccent, fontSize: 12));
                      }
                      if (!snapshot.hasData) {
                        return const LinearProgressIndicator(color: green);
                      }
                      final spent = _spentThisMonth(snapshot.data!);
                      final progress = entered > 0
                          ? (spent / entered).clamp(0.0, 1.0).toDouble()
                          : 0.0;
                      final remaining = entered - spent;
                      final percentage = entered > 0 ? spent / entered * 100 : 0.0;
                      final overBudget = entered > 0 && spent > entered;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(child: Text(
                                '${_currency.format(spent)} spent this month',
                                style: const TextStyle(fontSize: 12, color: Colors.black54),
                              )),
                              Text(
                                entered > 0 ? '${percentage.toStringAsFixed(0)}% used' : 'Set a budget',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                                  color: overBudget ? Colors.redAccent : green),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 7,
                              color: overBudget ? Colors.redAccent : green,
                              backgroundColor: const Color(0xFFE4F0E2),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            entered <= 0
                                ? 'Enter a monthly budget to see your remaining balance.'
                                : remaining >= 0
                                    ? '${_currency.format(remaining)} remaining from your entered budget'
                                    : '${_currency.format(-remaining)} over your entered budget',
                            style: TextStyle(fontSize: 12,
                              color: overBudget ? Colors.redAccent : green),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                child: Text(_saving ? 'Saving...' : 'Save Monthly Budget'),
              ),
            ),
            TextButton(
              onPressed: _saving ? null : () => Navigator.pop(context),
              child: const Text('Cancel & Discard',
                style: TextStyle(color: Colors.black54)),
            ),
          ],
        ),
      ),
    );
  }
}
