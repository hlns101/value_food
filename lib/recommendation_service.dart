import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'food_products.dart';
import 'product_groups.dart';

class _Scored {
  final FoodProduct product;
  final double distance;
  final double risk;

  _Scored({
    required this.product,
    required this.distance,
    required this.risk,
  });
}

/// Profile-weighted nearest-neighbor recommendation service.
///
/// This is a feature-based nearest-neighbor ranking approach.
/// It is not yet a conventionally trained KNN model.
class RecommendationService {
  static const int _features = 4;

  List<FoodProduct> _catalog = [];

  final List<double> _min = List.filled(_features, 0.0);
  final List<double> _max = List.filled(_features, 1.0);

  bool get isLoaded => _catalog.isNotEmpty;

  int get catalogCount => _catalog.length;

  int get eligibleCount => _catalog
      .where((p) => p.nutritionEligible || p.nutritionEligiblePer100ml)
      .length;

  int get per100gEligibleCount =>
      _catalog.where((p) => p.nutritionEligible).length;

  int get per100mlEligibleCount =>
      _catalog.where((p) => p.nutritionEligiblePer100ml).length;

  List<String> get categories => (_catalog
        .map((p) => p.category.trim())
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList()
      ..sort());

  // ------------------------------------------------------------
  // CATALOG
  // ------------------------------------------------------------

  Future<void> loadCatalog() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('products').get();

      _catalog = snapshot.docs
          .map((doc) => FoodProduct.fromMap(doc.data()))
          .toList();

      final eligiblePer100g = per100gEligibleCount;
      final eligiblePer100ml = per100mlEligibleCount;
      final eligible = eligibleCount;
      final noPrice = _catalog.where((p) => p.price <= 0).length;
      final empty = _catalog.where((p) => p.looksEmpty).length;

      debugPrint('========== CATALOG SUMMARY ==========');
      debugPrint('Total products: ${_catalog.length}');
      debugPrint('Eligible products: $eligible');
      debugPrint('Eligible per 100 g: $eligiblePer100g');
      debugPrint('Eligible per 100 ml: $eligiblePer100ml');
      debugPrint('Products without valid prices: $noPrice');
      debugPrint('Products with empty nutrition: $empty');
      debugPrint('=====================================');
    } on FirebaseException catch (e) {
      debugPrint(
        '[RecommendationService] Firebase error: ${e.code}: ${e.message}',
      );
      _catalog = [];
    } catch (e) {
      debugPrint('[RecommendationService] Unexpected error: $e');
      _catalog = [];
    }
  }

  void setCatalog(List<FoodProduct> items) {
    _catalog = List<FoodProduct>.from(items);
  }

  // ------------------------------------------------------------
  // VALUE PARSING
  // ------------------------------------------------------------

  double _number(dynamic value, {double fallback = 0}) {
    if (value is num) {
      final result = value.toDouble();
      return result.isFinite ? result : fallback;
    }

    if (value is String) {
      final result = double.tryParse(value.replaceAll(',', '').trim());

      if (result != null && result.isFinite) {
        return result;
      }
    }

    return fallback;
  }

  List<String> _stringList(dynamic value) {
    if (value == null) return [];

    final items =
        value is List ? value : value.toString().split(RegExp(r'[,;|]'));

    return items
        .map((item) => item.toString().trim())
        .where((item) =>
            item.isNotEmpty &&
            item.toLowerCase() != 'none' &&
            item.toLowerCase() != 'null')
        .toList();
  }

  // ------------------------------------------------------------
  // USER PROFILE WEIGHTS
  // ------------------------------------------------------------

  List<double> weightsFor(Map<String, dynamic> user) {
    final weights = <double>[1.0, 1.0, 1.0, 1.0];

    final ncds = _stringList(user['ncds'])
        .map((value) => value.toLowerCase())
        .join(' ');

    if (ncds.contains('hypertension')) {
      weights[1] *= 3.0;
    }

    if (ncds.contains('diabetes')) {
      weights[2] *= 3.0;
    }

    final weight = _number(user['weight']);
    final targetWeight = _number(user['targetWeight']);

    if (targetWeight > 0 && weight > targetWeight) {
      weights[0] *= 2.0;
      weights[3] *= 1.5;
    }

    return weights;
  }

  bool _isEligibleForBasis(
    FoodProduct product, {
    required bool per100ml,
  }) {
    return per100ml
        ? product.nutritionEligiblePer100ml
        : product.nutritionEligible;
  }

  // ------------------------------------------------------------
  // NORMALIZATION
  // ------------------------------------------------------------

  void _fitNormalization(
    FoodProduct scanned, {
    required bool per100ml,
  }) {
    // Compare only products with the same nutrition basis and product group.
    final eligibleProducts = _catalog
        .where((p) =>
            _isEligibleForBasis(p, per100ml: per100ml) &&
            _isRelated(scanned, p))
        .toList();
      
      if (eligibleProducts.isEmpty) {
        debugPrint(
          '[RecommendationService] WARNING: '
          'No related catalog products available for normalization.',
        );
      }

    final products = [...eligibleProducts, scanned];

    for (var i = 0; i < _features; i++) {
      final values = products.map((p) => p.vector[i]).toList();

      _min[i] = values.reduce(min);
      _max[i] = values.reduce(max);
    }
  }

  List<double> _normalize(List<double> values) {
    return List.generate(_features, (i) {
      final range = _max[i] - _min[i];

      if (range <= 0) return 0.0;

      return ((values[i] - _min[i]) / range).clamp(0.0, 1.0).toDouble();
    });
  }

  // ------------------------------------------------------------
  // DISTANCE AND NUTRITION RISK
  // ------------------------------------------------------------

  double _distance(
    List<double> a,
    List<double> b,
    List<double> weights,
  ) {
    var sum = 0.0;

    for (var i = 0; i < _features; i++) {
      final difference = a[i] - b[i];
      sum += weights[i] * difference * difference;
    }

    return sqrt(sum);
  }

  double _risk(List<double> normalized, List<double> weights) {
    var sum = 0.0;

    for (var i = 0; i < _features; i++) {
      sum += weights[i] * normalized[i];
    }

    return sum;
  }

  // ------------------------------------------------------------
  // INGREDIENT SIMILARITY
  // ------------------------------------------------------------

  String _clean(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  double _jaccard(List<String> a, List<String> b) {
    final setA = a.map(_clean).where((v) => v.isNotEmpty).toSet();
    final setB = b.map(_clean).where((v) => v.isNotEmpty).toSet();

    final union = setA.union(setB).length;

    if (union == 0) return 0.0;

    return setA.intersection(setB).length / union;
  }

  // ------------------------------------------------------------
  // ALLERGY FILTERING
  // ------------------------------------------------------------

  bool _containsAllergyTerm(String text, String allergy) {
    final cleanText = _clean(text);
    final cleanAllergy = _clean(allergy);

    if (cleanText.isEmpty || cleanAllergy.isEmpty) {
      return false;
    }

    // Match whole words or phrases instead of arbitrary substrings.
    final paddedText = ' $cleanText ';
    final paddedAllergy = ' $cleanAllergy ';

    if (paddedText.contains(paddedAllergy)) {
      return true;
    }

    // Basic common-name equivalents.
    const equivalents = {
      'peanut': ['groundnut'],
      'peanuts': ['groundnuts', 'peanut'],
      'groundnut': ['peanut'],
      'soy': ['soya'],
      'soya': ['soy'],
      'shrimp': ['prawn'],
      'prawn': ['shrimp'],
      'milk': ['whey', 'casein', 'caseinate', 'lactose', 'milk powder'],
      'dairy': ['milk', 'whey', 'casein', 'caseinate', 'cheese'],
      'egg': ['albumin', 'albumen', 'egg white'],
      'eggs': ['egg', 'albumin', 'albumen'],
      'wheat': ['wheat flour', 'semolina', 'durum'],
      'fish': ['tuna', 'salmon', 'sardine', 'anchovy'],
      'shellfish': ['shrimp', 'prawn', 'crab', 'lobster'],
    };

    final alternatives = equivalents[cleanAllergy] ?? [];

    return alternatives.any(
      (term) => paddedText.contains(' ${_clean(term)} '),
    );
  }

  /// Returns terms explicitly detected in visible ingredient/advisory text.
  /// Empty results do NOT establish that a food is allergen-free.
  List<String> matchedAllergies({
    required List<String> userAllergies,
    required List<String> ingredientText,
    List<String> advisoryStatements = const [],
  }) {
    final evidence = [...ingredientText, ...advisoryStatements];
    return _stringList(userAllergies).where((allergy) =>
      evidence.any((line) => _containsAllergyTerm(line, allergy))
    ).toSet().toList();
  }

  bool _hasAllergen(
    FoodProduct product,
    List<String> allergies,
  ) {
    if (allergies.isEmpty) return false;

    final productText = [
      ...product.allergens,
      ...product.ingredients,
    ];

    return allergies.any((allergy) {
      return productText.any(
        (item) => _containsAllergyTerm(item, allergy),
      );
    });
  }

  // ------------------------------------------------------------
  // PRODUCT GROUP MATCHING
  // ------------------------------------------------------------

  String _productGroup(FoodProduct product) {
    final storedGroup = normalizeProductGroup(product.productGroup);
    if (storedGroup.isNotEmpty && storedGroup != 'other') return storedGroup;

    final name = _clean(product.name);

    if (RegExp(
      r'\b(biscuit|biscuits|cookie|cookies|cracker|crackers|wafer|wafers|'
      r'waffle|waffles|mamon|broas|piyaya|cake|cakes|brownie|brownies)\b',
    ).hasMatch(name)) {
      return 'bakery';
    }

    final text = '${_clean(product.name)} ${_clean(product.category)}';
    if (RegExp(r'\b(sardines?|tuna|mackerel|salmon|anchov(y|ies))\b').hasMatch(text)) {
      return 'canned_fish';
    }
    if (RegExp(r'\b(corned beef|luncheon meat|canned beef)\b').hasMatch(text)) {
      return 'canned_beef';
    }
    if (RegExp(r'\b(pork and beans|baked beans)\b').hasMatch(text)) return 'beans';
    if (RegExp(r'\b(noodles?|ramen|pancit)\b').hasMatch(text)) return 'noodles';
    if (RegExp(r'\b(milk|yogurt|cheese)\b').hasMatch(text)) return 'dairy';
    if (RegExp(r'\b(juice|soft drink|soda)\b').hasMatch(text)) return 'beverages';
    if (RegExp(r'\b(marshmallow|mallows|gummy|candy|candies|chocolate bar)\b').hasMatch(text)) return 'snacks';
    if (RegExp(r'\b(coffee mix|instant coffee|drink mix|powdered drink)\b').hasMatch(text)) return 'beverages';
    return '';
  }

  String _foodType(FoodProduct product) {
    final stored = normalizeFoodType(product.foodType);
    if (stored.isNotEmpty) return stored;

    final text = _clean('${product.name} ${product.category}');
    if (RegExp(r'\b(marshmallow|mallows|gummy|candy|candies|chocolate bar|lollipop)\b').hasMatch(text)) {
      return 'confectionery';
    }
    if (RegExp(r'\b(coffee mix|instant coffee|drink mix|powdered drink|chocolate drink mix)\b').hasMatch(text)) {
      return 'beverage_mix';
    }
    if (_productGroup(product) == 'bakery') {
      return 'bakery';
    }
    if (RegExp(r'\b(sardines?|tuna|mackerel|salmon|anchov(y|ies))\b').hasMatch(text)) return 'canned_fish';
    if (RegExp(r'\b(corned beef|luncheon meat|canned beef)\b').hasMatch(text)) return 'canned_beef';
    if (RegExp(r'\b(pork and beans|baked beans)\b').hasMatch(text)) return 'beans';
    if (RegExp(r'\b(noodles?|ramen|pancit)\b').hasMatch(text)) return 'noodles';
    if (RegExp(r'\b(milk|yogurt|cheese)\b').hasMatch(text)) return 'dairy';
    if (RegExp(r'\b(juice|soft drink|soda|ready to drink)\b').hasMatch(text)) return 'ready_to_drink_beverage';
    return '';
  }

  String _foodSubtype(FoodProduct product) {
    final stored = normalizeFoodSubtype(product.foodSubtype);
    if (stored.isNotEmpty) return stored;

    final text = _clean(product.name);
    if (RegExp(r'\b(marshmallow|mallows)\b').hasMatch(text)) return 'marshmallow';
    if (RegExp(r'\b(coffee mix|instant coffee)\b').hasMatch(text)) return 'instant_coffee_mix';
    if (RegExp(r'\b(gummy|gummies)\b').hasMatch(text)) return 'gummy_candy';
    if (RegExp(r'\b(potato chips?|crisps)\b').hasMatch(text)) return 'potato_chips';
    if (RegExp(r'\b(biscuits?|cookies?)\b').hasMatch(text)) return 'biscuits';
    return '';
  }

  
  bool _isRelated(FoodProduct scanned, FoodProduct candidate) {
    final scannedType = _foodType(scanned);
    final candidateType = _foodType(candidate);

    // Reject only when both types are known and conflict.
    if (scannedType.isNotEmpty &&
        candidateType.isNotEmpty &&
        scannedType != candidateType) {
      return false;
    }

    final scannedSubtype = _foodSubtype(scanned);
    final candidateSubtype = _foodSubtype(candidate);

    // Reject only when both subtypes are known and conflict.
    if (scannedSubtype.isNotEmpty &&
        candidateSubtype.isNotEmpty &&
        scannedSubtype != candidateSubtype) {
      return false;
    }

    final scannedConsumption = _clean(scanned.consumptionType);
    final candidateConsumption = _clean(candidate.consumptionType);

    if (scannedConsumption.isNotEmpty &&
        candidateConsumption.isNotEmpty &&
        scannedConsumption != candidateConsumption) {
      return false;
    }

    final scannedGroup = _productGroup(scanned);
    final candidateGroup = _productGroup(candidate);

    if (scannedGroup.isNotEmpty &&
        candidateGroup.isNotEmpty &&
        scannedGroup != candidateGroup) {
      return false;
    }

    // If enough classification information exists, accept the match
    // unless a known classification conflicts.
    if (scannedType.isNotEmpty &&
        candidateType.isNotEmpty &&
        scannedType == candidateType) {
      return true;
    }

    if (scannedSubtype.isNotEmpty &&
        candidateSubtype.isNotEmpty &&
        scannedSubtype == candidateSubtype) {
      return true;
    }

    if (scannedGroup.isNotEmpty &&
        candidateGroup.isNotEmpty &&
        scannedGroup == candidateGroup) {
      return true;
    }

    // Fall back to matching categories.
    final scannedCategory = _clean(scanned.category);
    final candidateCategory = _clean(candidate.category);

    return scannedCategory.isNotEmpty &&
        candidateCategory.isNotEmpty &&
        scannedCategory == candidateCategory;
  }
  
  // ------------------------------------------------------------
  // RECOMMENDATION ENGINE
  // ------------------------------------------------------------

  List<FoodProduct> recommend({
    required FoodProduct scanned,
    required Map<String, dynamic> user,
    required double remainingBudget,
    int limit = 3,
    double ingredientWeight = 0.3,
    List<String>? scannedIngredients,
    
  }) {
    // A scanned product must be eligible under exactly one supported basis.
    final scannedIsPer100g = scanned.nutritionEligible;
    final scannedIsPer100ml = scanned.nutritionEligiblePer100ml;

    if (_catalog.isEmpty ||
        scannedIsPer100g == scannedIsPer100ml ||
        limit <= 0 ||
        remainingBudget <= 0) {
      return [];
    }

    final weights = weightsFor(user);

    final activeIngredients = scannedIngredients ?? scanned.ingredients;

    final allergies = _stringList(user['allergies'])
        .map((value) => value.toLowerCase())
        .toList();

    // Fit min/max values using only products with the scanned product's basis.
    _fitNormalization(
      scanned,
      per100ml: scannedIsPer100ml,
    );

    final scannedVector = _normalize(scanned.vector);
    final scannedRisk = _risk(scannedVector, weights);

    final maxDistance = sqrt(weights.reduce((a, b) => a + b));

    final safeIngredientWeight =
        ingredientWeight.clamp(0.0, 1.0).toDouble();

    int skippedNutrition = 0;
    int skippedCategory = 0;
    int skippedAllergy = 0;
    int skippedHealthier = 0;
    int skippedPrice = 0;
    int skippedBudget = 0;

    final ranked = <_Scored>[];

    for (final product in _catalog) {
      // Never mix per-100 g and per-100 ml nutrition values.
      if (!_isEligibleForBasis(product, per100ml: scannedIsPer100ml)) {
        skippedNutrition++;
        continue;
      }

      if (_clean(product.name) == _clean(scanned.name)) {
        continue;
      }

      if (!_isRelated(scanned, product)) {
        skippedCategory++;
        continue;
      }

      // Unknown catalog ingredient/allergen data cannot be verified for
      // allergy-sensitive users. Exclude these from the shortlist.
      if (allergies.isNotEmpty &&
          product.ingredients.isEmpty && product.allergens.isEmpty) {
        skippedAllergy++;
        continue;
      }

      if (_hasAllergen(product, allergies)) {
        skippedAllergy++;
        continue;
      }

      // A product without a valid price cannot be confirmed affordable.
      if (!product.price.isFinite || product.price <= 0) {
        skippedPrice++;
        continue;
      }

      if (product.price > remainingBudget) {
        skippedBudget++;
        continue;
      }

      final normalized = _normalize(product.vector);
      final risk = _risk(normalized, weights);

      // Lower profile-weighted nutrition risk is required.
      if (risk >= scannedRisk) {
        skippedHealthier++;
        continue;
      }

      final nutritionDistance =
          _distance(scannedVector, normalized, weights) /
              (maxDistance == 0 ? 1 : maxDistance);

      final canCompareIngredients =
          activeIngredients.isNotEmpty && product.ingredients.isNotEmpty;

      final distance = canCompareIngredients
          ? (1 - safeIngredientWeight) * nutritionDistance +
              safeIngredientWeight *
                  (1 - _jaccard(
                    activeIngredients,
                    product.ingredients,
                  ))
          : nutritionDistance;

      ranked.add(
        _Scored(
          product: product,
          distance: distance,
          risk: risk,
        ),
      );
    }

    // Closest nutritional and ingredient profile comes first.
    // Risk is used as a tie-breaker.
    ranked.sort((a, b) {
      final distanceComparison = a.distance.compareTo(b.distance);

      if (distanceComparison != 0) {
        return distanceComparison;
      }

      return a.risk.compareTo(b.risk);
    });

    final results = ranked.take(limit).map((item) => item.product).toList();

    // ----------------------------------------------------------
    // DEBUG SUMMARY
    // ----------------------------------------------------------

    debugPrint('========== RECOMMENDATION DEBUG ==========');
    debugPrint('Scanned product: ${scanned.name}');
    debugPrint('Scanned category: ${scanned.category}');
    debugPrint('Scanned group: ${_productGroup(scanned)}');
    debugPrint(
      'Scanned identity: ${_foodType(scanned)} / ${_foodSubtype(scanned)}',
    );
    
    debugPrint('========== BISCUIT MATCH TEST ==========');

    for (final p in _catalog) {
      if (_clean('${p.name} ${p.category}').contains('biscuit') ||
          _clean('${p.name} ${p.category}').contains('cookie')) {
        debugPrint(
          'Product: ${p.name} | '
          'Group: ${p.productGroup} | '
          'Type: ${p.foodType} | '
          'Subtype: ${p.foodSubtype} | '
          'Normalized type: ${_foodType(p)} | '
          'Normalized subtype: ${_foodSubtype(p)} | '
          'Related: ${_isRelated(scanned, p)} | '
          'Eligible: ${p.nutritionEligible}',
        );
      }
    }

    debugPrint('========================================');

    debugPrint('Scanned basis: ${scannedIsPer100ml ? "per 100 ml" : "per 100 g"}');
    debugPrint('Scanned nutrition risk: $scannedRisk');
    debugPrint('Remaining budget: $remainingBudget');
    debugPrint('Catalog size: ${_catalog.length}');
    debugPrint('Eligible products: $eligibleCount');
    debugPrint('Skipped nutrition: $skippedNutrition');
    debugPrint('Skipped unrelated products: $skippedCategory');
    debugPrint('Skipped allergies: $skippedAllergy');
    debugPrint('Skipped missing/invalid prices: $skippedPrice');
    debugPrint('Skipped over budget: $skippedBudget');
    debugPrint('Skipped not healthier: $skippedHealthier');
    debugPrint('Final recommendations: ${results.length}');
    debugPrint('==========================================');

    return results;
  }
}