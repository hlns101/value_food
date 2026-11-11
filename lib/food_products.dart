class FoodProduct {
  final String name;
  final String category;
  final String productGroup;

  // More precise product identity. These are optional so older Firestore
  // documents and existing constructor calls remain backward compatible.
  final String foodType;
  final String foodSubtype;
  final String productForm;
  final String consumptionType;

  final double price;

  final double calories;
  final double sodium;
  final double sugars;
  final double satFat;

  final double fat;
  final double carbs;
  final double protein;

  // Null means the catalog does not provide a trans-fat value.
  final double? transFat;

  final List<String> allergens;
  final List<String> ingredients;

  final String nutritionBasis;

  // Per-100-g and per-100-ml products are kept in separate eligibility groups.
  // Do not compare their nutrition vectors in the same KNN distance calculation.
  final bool nutritionEligible;
  final bool nutritionEligiblePer100ml;
  final String nutritionSource;
  final bool nutritionIsEstimated;

  // Indicates whether all three macro values were actually supplied.
  // The numeric fields remain doubles for compatibility with existing UI code.
  final bool hasMacroData;

  FoodProduct({
    required this.name,
    this.category = 'Other',
    this.productGroup = 'other',
    this.foodType = '',
    this.foodSubtype = '',
    this.productForm = '',
    this.consumptionType = '',
    this.price = 0,
    this.calories = 0,
    this.sodium = 0,
    this.sugars = 0,
    this.satFat = 0,
    this.fat = 0,
    this.carbs = 0,
    this.protein = 0,
    this.transFat,
    this.allergens = const [],
    this.ingredients = const [],
    this.nutritionBasis = '',
    this.nutritionEligible = false,
    this.nutritionEligiblePer100ml = false,
    this.nutritionSource = '',
    this.nutritionIsEstimated = false,
    this.hasMacroData = false,
  });

  List<double> get vector => [
        calories,
        sodium,
        sugars,
        satFat,
      ];

  bool get looksEmpty =>
      calories == 0 && sodium == 0 && sugars == 0 && satFat == 0;

  double get macroTotal => fat + carbs + protein;

  static const double _maxMacroTotal = 105.0;

  // Normalizes field names so that "saturated_fat",
  // "saturatedFat", and "Saturated Fat" can be matched.
  static String _key(String value) {
    return value.toLowerCase().replaceAll(
          RegExp(r'[^a-z0-9]'),
          '',
        );
  }

  static Map<String, dynamic> _flatten(Map<String, dynamic> source) {
    final result = <String, dynamic>{};

    source.forEach((key, value) {
      result[_key(key)] = value;
    });

    return result;
  }

  static dynamic _find(
    Map<String, dynamic> map,
    List<String> aliases,
  ) {
    for (final alias in aliases) {
      final key = _key(alias);

      if (map.containsKey(key) && map[key] != null) {
        return map[key];
      }
    }

    return null;
  }

  static double? _toNullableNum(dynamic value) {
    if (value == null) return null;

    if (value is num) {
      final result = value.toDouble();
      return result.isFinite ? result : null;
    }

    if (value is String) {
      final cleaned = value
          .replaceAll(',', '')
          .replaceAll(RegExp(r'[^0-9.\-]'), '')
          .trim();

      if (cleaned.isEmpty || cleaned == '-' || cleaned == '.') {
        return null;
      }

      final result = double.tryParse(cleaned);

      if (result == null || !result.isFinite) {
        return null;
      }

      return result;
    }

    return null;
  }

  static double _toNum(dynamic value, {double fallback = 0}) {
    return _toNullableNum(value) ?? fallback;
  }

  static List<String> _toList(dynamic value) {
    if (value == null) return [];

    final values = value is List
        ? value
        : value.toString().split(RegExp(r'[,;|]'));

    return values
        .map((item) => item.toString().trim().toLowerCase())
        .where((item) =>
            item.isNotEmpty &&
            item != 'none' &&
            item != 'null' &&
            item != 'n/a')
        .toSet()
        .toList();
  }

  static bool _isPer100g(String basis) {
    final normalized = _key(basis);

    return normalized == 'per100g' ||
        normalized == '100g' ||
        normalized == 'per100grams' ||
        normalized == '100grams';
  }

  static bool _isPer100ml(String basis) {
    final normalized = _key(basis);

    return normalized == 'per100ml' ||
        normalized == '100ml' ||
        normalized == 'per100milliliter' ||
        normalized == '100milliliter' ||
        normalized == 'per100milliliters' ||
        normalized == '100milliliters';
  }

  static bool _isEstimatedNutrition(String source) {
    return _key(source).contains('estimate');
  }

  static bool _isValidCoreNutrition({
    required double calories,
    required double sodium,
    required double sugars,
    required double satFat,
  }) {
    return calories >= 0 &&
        calories <= 900 &&
        sodium >= 0 &&
        sodium <= 10000 &&
        sugars >= 0 &&
        sugars <= 100 &&
        satFat >= 0 &&
        satFat <= 100;
  }

  static bool _isValidMacros({
    required double? fat,
    required double? carbs,
    required double? protein,
  }) {
    final values = [fat, carbs, protein];

    // Macro values are optional for core recommendation eligibility.
    // If any are supplied, all three must be present and valid.
    if (values.every((value) => value == null)) {
      return true;
    }

    if (values.any((value) => value == null)) {
      return false;
    }

    if (values.any((value) => value! < 0 || value > 100)) {
      return false;
    }

    final total = fat! + carbs! + protein!;

    return total <= _maxMacroTotal;
  }

  static bool _hasMissingNutritionIssue(List<String> issues) {
    final text = issues.join(' ').toLowerCase();

    return text.contains('missing calories') ||
        text.contains('missing calorie') ||
        text.contains('missing sodium') ||
        text.contains('missing sugar') ||
        text.contains('missing saturated fat') ||
        text.contains('missing core nutrition');
  }

  // Reads nutrition values from the legacy rawNutriFacts object.
  static Map<String, double?> _fromRaw(Map<String, dynamic> raw) {
    final calories = _toNullableNum(
      _find(raw, [
        'caloriesKcal',
        'calories',
        'energyKcal',
        'energyKcal100g',
      ]),
    );

    final sodiumMg = _toNullableNum(
      _find(raw, [
        'sodiumMg',
        'sodium_mg',
      ]),
    );

    final sodiumG = _toNullableNum(
      _find(raw, [
        'sodiumG',
        'sodium_g',
      ]),
    );

    final sodium = _toNullableNum(
      _find(raw, ['sodium']),
    );

    final saltG = _toNullableNum(
      _find(raw, [
        'saltG',
        'salt_g',
        'salt',
      ]),
    );

    double? resolvedSodium;

    if (sodiumMg != null) {
      resolvedSodium = sodiumMg;
    } else if (sodiumG != null) {
      resolvedSodium = sodiumG * 1000;
    } else if (sodium != null) {
      resolvedSodium = sodium * 1000;
    } else if (saltG != null) {
      resolvedSodium = saltG * 400;
    }

    return {
      'calories': calories,
      'sodium': resolvedSodium,
      'sugars': _toNullableNum(
        _find(raw, ['sugarsG', 'sugars', 'sugar']),
      ),
      'satFat': _toNullableNum(
        _find(raw, [
          'saturatedFatG',
          'saturatedFat',
          'satFat',
        ]),
      ),
    };
  }

  factory FoodProduct.fromMap(Map<String, dynamic> data) {
    final flat = _flatten(data);

    final nutritionValue = _find(data, ['nutrition']);
    final nutrition = nutritionValue is Map
        ? _flatten(Map<String, dynamic>.from(nutritionValue))
        : <String, dynamic>{};

    final rawValue = _find(data, [
      'rawNutriFacts',
      'raw_nutri_facts',
    ]);

    final raw = rawValue is Map
        ? _flatten(Map<String, dynamic>.from(rawValue))
        : <String, dynamic>{};

    final rawNutrition = _fromRaw(raw);

    // New nested catalog values take priority.
    // Legacy top-level values are next, followed by rawNutriFacts.
    // Explicit zero values are preserved.
    double? readNutrition(
      List<String> nestedAliases,
      List<String> topLevelAliases,
      double? rawFallback,
    ) {
      return _toNullableNum(_find(nutrition, nestedAliases)) ??
          _toNullableNum(_find(flat, topLevelAliases)) ??
          rawFallback;
    }

    final caloriesValue = readNutrition(
      ['caloriesKcal', 'calories', 'energyKcal'],
      ['calories', 'caloriesKcal', 'energyKcal'],
      rawNutrition['calories'],
    );

    final sodiumValue = readNutrition(
      ['sodiumMg', 'sodium'],
      ['sodiumMg', 'sodium'],
      rawNutrition['sodium'],
    );

    final sugarsValue = readNutrition(
      ['sugarsG', 'sugars', 'sugar'],
      ['sugars', 'sugarsG', 'sugar'],
      rawNutrition['sugars'],
    );

    final satFatValue = readNutrition(
      ['saturatedFatG', 'saturatedFat', 'satFat'],
      ['satFat', 'saturatedFat', 'saturatedFatG'],
      rawNutrition['satFat'],
    );

    final fatValue = readNutrition(
      ['fatG', 'fat'],
      ['fat', 'fatG', 'totalFat'],
      null,
    );

    final carbsValue = readNutrition(
      ['carbsG', 'carbs', 'carbohydrates'],
      ['carbs', 'carbsG', 'carbohydrates'],
      null,
    );

    final proteinValue = readNutrition(
      ['proteinG', 'protein'],
      ['protein', 'proteinG'],
      null,
    );

    final transFatValue = readNutrition(
      ['transFatG', 'transFat'],
      ['transFat', 'transFatG'],
      null,
    );

    final calories = caloriesValue ?? 0;
    final sodium = sodiumValue ?? 0;
    final sugars = sugarsValue ?? 0;
    final satFat = satFatValue ?? 0;

    final fat = fatValue ?? 0;
    final carbs = carbsValue ?? 0;
    final protein = proteinValue ?? 0;

    final hasAllCoreNutrition = caloriesValue != null &&
        sodiumValue != null &&
        sugarsValue != null &&
        satFatValue != null;

    final hasMacroData = fatValue != null &&
        carbsValue != null &&
        proteinValue != null;

    final basisValue = _find(nutrition, ['basis']) ??
        _find(flat, [
          'nutritionBasis',
          'nutrition_basis',
        ]);

    final nutritionBasis = basisValue?.toString().trim() ?? '';

    final sourceValue = _find(flat, [
      'nutritionSource',
      'nutrition_source',
    ]);
    final nutritionSource = sourceValue?.toString().trim() ?? '';
    final nutritionIsEstimated = _isEstimatedNutrition(nutritionSource);

    final issueValue = _find(flat, ['issues']);
    final issues = _toList(issueValue);

    final isPer100g = _isPer100g(nutritionBasis);
    final isPer100ml = _isPer100ml(nutritionBasis);

    final validCoreNutrition = hasAllCoreNutrition &&
        _isValidCoreNutrition(
          calories: calories,
          sodium: sodium,
          sugars: sugars,
          satFat: satFat,
        );

    final validMacros = _isValidMacros(
      fat: fatValue,
      carbs: carbsValue,
      protein: proteinValue,
    );

    final hasMissingIssue = _hasMissingNutritionIssue(issues);

    // Recalculate eligibility from the actual values instead of blindly
    // trusting the draft's preliminary nutritionEligibleCandidate flag.
    // Explicitly estimated nutrition is excluded from both recommendation
    // groups. Label-derived values remain eligible if they pass validation.
    final commonNutritionChecks = validCoreNutrition &&
        validMacros &&
        !hasMissingIssue &&
        !nutritionIsEstimated;

    // Keep the existing property restricted to per-100-g products so the
    // current KNN service cannot accidentally mix per-100-g and per-100-ml
    // nutrition vectors.
    final nutritionEligible = isPer100g && commonNutritionChecks;

    // Beverage candidates are tracked separately. RecommendationService
    // must filter to this group separately before using it for KNN.
    final nutritionEligiblePer100ml =
        isPer100ml && commonNutritionChecks;

    final name = (_find(flat, [
              'name',
              'productName',
              'productNameEn',
              'title',
            ]) ??
            'Unnamed Product')
        .toString()
        .trim();

    final category = (_find(flat, [
              'category',
              'categories',
              'productCategory',
            ]) ??
            'Other')
        .toString()
        .trim();

    final productGroup = (_find(flat, [
              'productGroup',
              'product_group',
            ]) ??
            'other')
        .toString()
        .trim()
        .toLowerCase();

    final foodType = (_find(flat, ['foodType', 'food_type']) ?? '')
        .toString()
        .trim()
        .toLowerCase();
    final foodSubtype = (_find(flat, ['foodSubtype', 'food_subtype']) ?? '')
        .toString()
        .trim()
        .toLowerCase();
    final productForm = (_find(flat, ['productForm', 'product_form']) ?? '')
        .toString()
        .trim()
        .toLowerCase();
    final consumptionType =
        (_find(flat, ['consumptionType', 'consumption_type']) ?? '')
            .toString()
            .trim()
            .toLowerCase();

    final price = _toNum(
      _find(flat, ['price', 'estimatedPrice']),
    );

    final allergens = _toList(
      _find(flat, ['allergens', 'allergy']),
    );

    final ingredients = _toList(
      _find(flat, ['ingredients', 'ingredientList']),
    );

    return FoodProduct(
      name: name,
      category: category.isEmpty ? 'Other' : category,
      productGroup: productGroup.isEmpty ? 'other' : productGroup,
      foodType: foodType,
      foodSubtype: foodSubtype,
      productForm: productForm,
      consumptionType: consumptionType,
      price: price,
      calories: calories,
      sodium: sodium,
      sugars: sugars,
      satFat: satFat,
      fat: fat,
      carbs: carbs,
      protein: protein,
      transFat: transFatValue,
      allergens: allergens,
      ingredients: ingredients,
      nutritionBasis: nutritionBasis,
      nutritionEligible: nutritionEligible,
      nutritionEligiblePer100ml: nutritionEligiblePer100ml,
      nutritionSource: nutritionSource,
      nutritionIsEstimated: nutritionIsEstimated,
      hasMacroData: hasMacroData,
    );
  }
}