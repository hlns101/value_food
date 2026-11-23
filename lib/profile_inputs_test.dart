import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:value_food_demo/utils/app_haptics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:value_food_demo/utils/budget_input.dart';
import 'package:value_food_demo/utils/health_conditions.dart';
import 'package:value_food_demo/signup_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('haptics honor the enabled preference', () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          calls.add(call);
          return null;
        });
    AppHaptics.enabled = false;
    AppHaptics.selection();
    await Future<void>.delayed(Duration.zero);
    expect(calls, isEmpty);
    AppHaptics.enabled = true;
    AppHaptics.selection();
    await Future<void>.delayed(Duration.zero);
    expect(calls.single.method, 'HapticFeedback.vibrate');
    expect(calls.single.arguments, 'HapticFeedbackType.heavyImpact');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });
  test('budget groups thousands and keeps numeric storage and maximum', () {
    final formatter = BudgetInputFormatter();
    TextEditingValue value(String s) => TextEditingValue(
      text: s,
      selection: TextSelection.collapsed(offset: s.length),
    );
    final maximum = formatter.formatEditUpdate(
      value('10,000'),
      value('100000'),
    );
    expect(maximum.text, '100,000');
    expect(BudgetInputFormatter.parse(maximum.text), 100000);
    expect(formatter.formatEditUpdate(maximum, value('1000000')), maximum);
    expect(formatter.formatEditUpdate(maximum, value('100000.01')), maximum);
    expect(
      formatter.formatEditUpdate(value(''), value('1234.50')).text,
      '1,234.50',
    );
    expect(formatter.formatEditUpdate(maximum, value('')).text, '');
    expect(formatter.formatEditUpdate(value(''), value('-1')).text, '');
  });
  test(
    'NCDs preserve multiple selections including Hypertension and legacy strings',
    () {
      expect(
        healthConditions([
          'Hypertension',
          'High Cholesterol',
          'Type 2 Diabetes',
        ]),
        ['Hypertension', 'High Cholesterol', 'Type 2 Diabetes'],
      );
      expect(healthConditions('Hypertension'), ['Hypertension']);
      expect(healthConditions('None'), isEmpty);
      expect(healthConditions(null), isEmpty);
      expect(healthConditions(['None', 'Hypertension', 'Hypertension']), [
        'Hypertension',
      ]);
    },
  );
  testWidgets('password eye toggles visibility without changing text', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'secret123');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomTextField(
            label: 'Password',
            hint: '',
            icon: Icons.lock,
            controller: controller,
            isPassword: true,
          ),
        ),
      ),
    );
    expect(
      tester.widget<TextField>(find.byType(TextField)).obscureText,
      isTrue,
    );
    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField)).obscureText,
      isFalse,
    );
    expect(controller.text, 'secret123');
    await tester.tap(find.byTooltip('Hide password'));
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField)).obscureText,
      isTrue,
    );
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
}
