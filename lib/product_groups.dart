/// Single source of truth for product-group naming.
///
/// Gemini and the Firestore catalog historically used different names for
/// the same group (e.g. "canned_meat" vs "canned_beef"). Both
/// GeminiService and RecommendationService call [normalizeProductGroup],
/// so the two can never drift apart again.
///
/// Add new aliases here (left side = what you might receive, right side =
/// the catalog's canonical name).
const Map<String, String> _groupAliases = {
  // Meat
  'canned_meat': 'canned_beef',
  'canned_meats': 'canned_beef',
  'corned_beef': 'canned_beef',

  // Beans
  'canned_beans': 'beans',
  'canned_bean': 'beans',
  'baked_beans': 'beans',
  'pork_and_beans': 'beans',

  // Fish
  'canned_sardines': 'canned_fish',
  'canned_tuna': 'canned_fish',
  'fish': 'canned_fish',

  // Noodles
  'instant_noodles': 'noodles',
  'noodle': 'noodles',

  // Dairy
  'milk': 'dairy',
  'dairy_products': 'dairy',

  // Beverages
  'beverage': 'beverages',
  'drinks': 'beverages',
  'juice': 'beverages',
  'juices': 'beverages',
  'soft_drinks': 'beverages',

  // Specific identity types (kept separate from broad catalog categories).
  'marshmallow': 'confectionery',
  'sweets': 'confectionery',
  'candy': 'confectionery',
  'candies': 'confectionery',
  'chocolate_candy': 'confectionery',
  'instant_coffee': 'beverage_mix',
  'coffee_mix': 'beverage_mix',
  'powdered_drink': 'beverage_mix',
  'drink_mix': 'beverage_mix',
};

/// Lower-cases, converts spaces/hyphens to underscores, strips other
/// symbols, then maps known aliases to the catalog's canonical name.
///
/// Returns '' for empty input. Unknown groups are returned cleaned but
/// otherwise unchanged, so catalog groups we don't list here still work.
String normalizeProductGroup(String raw) {
  final key = raw
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[\s\-]+'), '_')
      .replaceAll(RegExp(r'[^a-z0-9_]'), '');

  if (key.isEmpty) return '';

  return _groupAliases[key] ?? key;
}
/// Canonicalizes the more specific identity type used for compatibility.
String normalizeFoodType(String raw) {
  final key = raw
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[\s\-]+'), '_')
      .replaceAll(RegExp(r'[^a-z0-9_]'), '');

  if (key.isEmpty || key == 'unknown' || key == 'other' || key == 'n/a') {
    return '';
  }

  return _groupAliases[key] ?? key;
}

/// Canonicalizes a product subtype without guessing missing values.
String normalizeFoodSubtype(String raw) {
  final key = raw
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[\s\-]+'), '_')
      .replaceAll(RegExp(r'[^a-z0-9_]'), '');

  if (key.isEmpty || key == 'unknown' || key == 'other' || key == 'n/a') {
    return '';
  }

  const aliases = {
    'coffee_mix': 'instant_coffee_mix',
    'instant_coffee': 'instant_coffee_mix',
    'marshmallows': 'marshmallow',
    'choco_mallows': 'marshmallow',

    // Biscuit aliases
    'biscuit': 'biscuits',
    'cookie': 'biscuits',
    'cookies': 'biscuits',
  };


  return aliases[key] ?? key;
}

/// Product form is descriptive only; it is not used as the sole match key.
String normalizeProductForm(String raw) {
  final key = raw
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[\s\-]+'), '_')
      .replaceAll(RegExp(r'[^a-z0-9_]'), '');

  if (key.isEmpty || key == 'unknown' || key == 'other' || key == 'n/a') {
    return '';
  }
  return key;
}
