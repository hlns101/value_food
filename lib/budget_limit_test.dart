import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:value_food_demo/utils/budget_input.dart';

void main() {
  test(
    'whole-peso budget accepts the maximum and rejects extra digits and decimals',
    () {
      final formatter = BudgetInputFormatter(wholePesos: true);
      TextEditingValue value(String text) => TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
      final maximum = formatter.formatEditUpdate(
        value('10,000'),
        value('100000'),
      );
      expect(maximum.text, '100,000');
      for (final invalid in [
        '100001',
        '999999',
        '1000000',
        '0000001',
        '500.50',
        '-1',
      ]) {
        expect(
          formatter.formatEditUpdate(maximum, value(invalid)),
          maximum,
          reason: invalid,
        );
      }
      expect(formatter.formatEditUpdate(maximum, value('')).text, '');
      expect(
        formatter.formatEditUpdate(value(''), value('12345')).text,
        '12,345',
      );
    },
  );
}
