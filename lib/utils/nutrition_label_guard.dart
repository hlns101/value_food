/// Requires a panel heading or serving basis plus several distinct nutrient rows.
/// Product names, front-of-pack claims, and ingredient lists are insufficient.
bool looksLikeNutritionLabel(String text, {String? alignedRows}) {
  final normalized = text.toLowerCase().replaceAll('\r', '\n');
  final layout = alignedRows?.toLowerCase();
  final heading = RegExp(
    r'\b(?:nutrition(?:al)?\s+(?:facts|information|values)|nutrition\s+label)\b',
  ).hasMatch([normalized, if (layout != null) layout].join('\n'));
  final serving = RegExp(
    r'\b(?:serving\s+size|amount\s+per\s+serving|per\s+serving|per\s+100\s*(?:g|ml)\b)',
  ).hasMatch([normalized, if (layout != null) layout].join('\n'));
  const nutrients = [
    r'(?:calories|energy)',
    r'(?:total\s+)?fat',
    r'saturated\s+fat',
    r'sodium',
    r'(?:total\s+)?carbohydrates?',
    r'(?:total\s+)?sugars?',
    r'protein',
    r'(?:dietary\s+)?fib(?:er|re)',
    r'cholesterol',
  ];
  final rows =
      nutrients
          .where(
            (nutrient) => RegExp(
              // Anchor to a row so prose such as "low fat" is not a nutrient row.
              '^\\s*$nutrient\\b[^\\n\\d]{0,24}\\n?\\s*\\d+(?:[.,]\\d+)?',
              multiLine: true,
            ).hasMatch([normalized, if (layout != null) layout].join('\n')),
          )
          .length;
  return (heading && rows >= 3) || (serving && rows >= 4);
}
