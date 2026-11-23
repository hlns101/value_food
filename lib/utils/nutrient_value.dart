String extractNutrientValue(String text, List<String> nutrientNames) {
  final lines =
      text
          .replaceAll('\r', '\n')
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList();

  for (int i = 0; i < lines.length; i++) {
    final line = lines[i];

    for (final nutrient in nutrientNames) {
      final escaped = RegExp.escape(nutrient);

      // Find the nutrient name at the beginning of a line.
      final match = RegExp(
        '^\\s*$escaped\\b\\s*[:\\-]?\\s*(.*)\$',
        caseSensitive: false,
      ).firstMatch(line);

      if (match == null) continue;

      // First, look for a number on the same line.
      final tail = (match.group(1) ?? '').trim();
      final headingUnit = RegExp(
        r'^\(\s*(mg|g|kcal)\s*\)\s*[:\-]?\s*',
        caseSensitive: false,
      ).firstMatch(tail);
      final sameLine = tail.substring(headingUnit?.end ?? 0);
      final value =
          sameLine.trim().isEmpty && i + 1 < lines.length
              ? lines[i + 1]
              : sameLine;
      final amount = RegExp(
        r'^\s*(\d+(?:[.,]\d+)?|O)\s*(mg|g)?(?=\s|$)',
        caseSensitive: false,
      ).firstMatch(value);
      if (amount == null ||
          value.substring(amount.end).trimLeft().startsWith('%'))
        continue;
      final unit = (amount.group(2) ?? headingUnit?.group(1))?.toLowerCase();
      final raw = amount.group(1)!.toUpperCase().replaceAll('O', '0');
      // A lowercase g can be recognized as the digit 9 (e.g. "1g" -> "19").
      // Without a printed unit, the two readings are indistinguishable.
      if (RegExp(
            r'^sugars?$',
          ).hasMatch(nutrient.toLowerCase().replaceFirst('total ', '')) &&
          unit == null &&
          RegExp(r'^\d[\d.,]*9$').hasMatch(raw))
        continue;
      final numeric =
          RegExp(r'^\d{1,3},\d{3}$').hasMatch(raw)
              ? raw.replaceAll(',', '')
              : raw.replaceAll(',', '.');
      final inMg = [
        'sodium',
        'potassium',
        'cholesterol',
      ].contains(nutrient.toLowerCase());
      if (inMg && unit == 'g') return (double.parse(numeric) * 1000).toString();
      if (!inMg && unit == 'mg')
        return (double.parse(numeric) / 1000).toString();
      return numeric;
    }
  }

  return '';
}
