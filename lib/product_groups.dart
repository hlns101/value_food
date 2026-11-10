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