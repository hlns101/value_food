import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'food_products.dart';
import 'recommendation_service.dart';
import 'gemini_service.dart';

/// Test harness: runs the KNN + Gemini explanation with hard-coded label
/// values (no camera). Real scanning lives in label_page.dart.
class LabelPageIntegration extends StatefulWidget {
  final String userId;

  const LabelPageIntegration({super.key, required this.userId});

  @override
  State<LabelPageIntegration> createState() => _LabelPageIntegrationState();
}

class _LabelPageIntegrationState extends State<LabelPageIntegration> {
  final RecommendationService _rec = RecommendationService();
  final GeminiService _gemini = GeminiService();

  List<FoodProduct> _alternatives = [];
  String _aiExplanation = '';
  bool _busy = false;
  String? _statusMessage;

  // Fake "scanned" product, per 100 g. Change these to test different cases.
  final FoodProduct _scanned = FoodProduct(
    name: 'Test Item',
    category: 'Snacks',
    price: 0,
    calories: 520,
    sodium: 800,
    sugars: 12,
    satFat: 9,
    ingredients: ['corn', 'palm oil', 'salt', 'sugar'],
  );

  @override
  void initState() {
    super.initState();
    _rec.loadCatalog();
  }

  Future<void> _runRecommendation() async {
    if (_busy) return;

    setState(() {
      _busy = true;
      _aiExplanation = '';
      _statusMessage = null;
    });

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get()
          .timeout(const Duration(seconds: 15));

      final user = doc.data() ?? <String, dynamic>{};
      final budget = double.tryParse((user['budget'] ?? 0).toString()) ?? 0;
      final spent = double.tryParse((user['spent'] ?? 0).toString()) ?? 0;
      final remaining = budget - spent;

      if (!_rec.isLoaded) {
        await _rec.loadCatalog().timeout(const Duration(seconds: 20));
      }

      final alts = _rec.recommend(
        scanned: _scanned,
        user: user,
        remainingBudget: remaining,
      );

      if (!mounted) return;
      setState(() => _alternatives = alts);

      final why = await _gemini
          .explainAlternatives(
            scanned: _scanned,
            alternatives: alts,
            user: user,
          )
          .timeout(
            const Duration(seconds: 20),
            onTimeout: () {
              debugPrint('[integration] Gemini explanation timed out.');
              return null;
            },
          );

      if (!mounted) return;
      setState(() {
        _aiExplanation = why ?? '';
        _statusMessage = why == null
            ? 'Recommendations loaded; AI explanation is temporarily unavailable.'
            : null;
      });
    } catch (e, stackTrace) {
      debugPrint('[integration] Recommendation test failed: $e');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        setState(() {
          _statusMessage =
              'Could not complete the test. Check your connection and try again.';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Product Recommendation')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ElevatedButton(
              onPressed: _busy ? null : _runRecommendation,
              child: Text(_busy ? 'Working...' : 'Run Recommendation Test'),
            ),
            const SizedBox(height: 20),
            const Text(
              'Alternatives:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              _alternatives.isEmpty
                  ? 'No affordable healthier alternative found'
                  : _alternatives
                      .map(
                        (p) =>
                            '${p.name} - ${p.price > 0 ? '₱${p.price.toStringAsFixed(0)}' : 'price not set'}',
                      )
                      .join('\n'),
              style: const TextStyle(fontSize: 16),
            ),
            if (_statusMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _statusMessage!,
                style: const TextStyle(color: Colors.deepOrange),
              ),
            ],
            if (_aiExplanation.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(_aiExplanation, style: const TextStyle(fontSize: 13)),
            ],
          ],
        ),
      ),
    );
  }
}
