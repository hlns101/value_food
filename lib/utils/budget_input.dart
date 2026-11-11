import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class BudgetInputFormatter extends TextInputFormatter {
  static double? parse(String text) =>
      double.tryParse(text.replaceAll(',', ''));
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (!newValue.composing.isCollapsed) return newValue;
    final raw = newValue.text.replaceAll(',', '');
    if (raw.isEmpty) return const TextEditingValue();
    if (!RegExp(r'^\d+(\.\d{0,2})?$').hasMatch(raw)) return oldValue;
    final amount = double.tryParse(raw);
    if (amount == null || amount > 100000) return oldValue;
    final parts = raw.split('.');
    final text =
        NumberFormat('#,##0', 'en_US').format(int.parse(parts.first)) +
        (parts.length > 1 ? '.${parts[1]}' : '');
    final digitsAfterCursor =
        newValue.text
            .substring(newValue.selection.end.clamp(0, newValue.text.length))
            .replaceAll(',', '')
            .length;
    var cursor = text.length;
    var remaining = digitsAfterCursor;
    while (cursor > 0 && remaining > 0) {
      cursor--;
      if (text[cursor] != ',') remaining--;
    }
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: cursor),
    );
  }
}
