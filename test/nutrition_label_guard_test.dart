import 'package:flutter_test/flutter_test.dart';
import 'package:value_food_demo/utils/nutrition_label_guard.dart';

void main() {
  test('accepts nutrition facts with amounts including zero', () {
    expect(
      looksLikeNutritionLabel(
        'Nutrition Facts\nCalories 120\nSodium 0 mg\nTotal Sugars 3 g',
      ),
      isTrue,
    );
  });
  test('accepts nutrition information and split OCR rows', () {
    expect(
      looksLikeNutritionLabel(
        'Nutritional Information\nEnergy\n400 kJ\nFat\n2 g\nProtein\n3 g',
      ),
      isTrue,
    );
  });
  test('accepts cropped heading with a serving basis and four nutrients', () {
    expect(
      looksLikeNutritionLabel(
        'Per 100 g\nEnergy 400 kcal\nFat 10 g\nCarbohydrates 20 g\nProtein 5 g',
      ),
      isTrue,
    );
  });
  test(
    'rejects unrelated photos, ingredients, receipts and package claims',
    () {
      for (final text in [
        '',
        'A cat sitting on a chair',
        'Milk 50\nBread 20\nTotal 70',
        'Ingredients: sugar, wheat flour, milk. Contains soy.',
        'High protein 20 g\nLow fat 2 g\nZero sugar 0 g',
        'Nutrition Facts\nUnreadable panel',
        'Calories 120',
      ]) {
        expect(looksLikeNutritionLabel(text), isFalse, reason: text);
      }
    },
  );
  test('does not count saturated fat twice as total fat', () {
    expect(
      looksLikeNutritionLabel(
        'Nutrition Facts\nSaturated Fat 2 g\nProtein 3 g',
      ),
      isFalse,
    );
  });
}
