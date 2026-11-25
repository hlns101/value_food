import 'package:flutter_test/flutter_test.dart';
import 'food_products.dart';
import 'utils/nutrient_value.dart';
import 'recommendation_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'crackers and mallows each get a compatible alternative',
    () {
      FoodProduct item(String name, double n) => FoodProduct(
        name: name,
        category: 'Snacks',
        price: 15,
        calories: n,
        sodium: n,
        sugars: n / 10,
        satFat: n / 10,
        nutritionEligible: true,
        nutritionBasis: 'per100g',
      );
      final service =
          RecommendationService()..setCatalog([
            item('Gummy candy', 10),
            item('Wheat crackers', 11),
            item('Soft mallows', 12),
          ]);
      for (final example in [
        ('Plain crackers', 'Wheat crackers'),
        ('Choco mallows', 'Soft mallows'),
      ]) {
        final ranked = service.recommend(
          scanned: item(example.$1, 50),
          user: {},
          remainingBudget: 30,
        );
        expect(ranked.map((p) => p.name), [example.$2]);
      }
    },
  );
  test('sugar units distinguish 1 g from 19 g and withhold ambiguous OCR', () {
    const names = ['Sugar', 'Sugars'];
    expect(extractNutrientValue('Sugars 1g', names), '1');
    expect(extractNutrientValue('Sugar 19 g', names), '19');
    expect(extractNutrientValue('Sugars (g) 19', names), '19');
    expect(extractNutrientValue('Sugars 19', names), '');
    expect(extractNutrientValue('Sugars 19%', names), '');
  });
  test('reads per-serving amounts from photo-style unit headings', () {
    expect(extractNutrientValue('Total Fat (g) 8 12%', ['Total Fat']), '8');
    expect(extractNutrientValue('Sodium (mg) 73', ['Sodium']), '73');
    expect(extractNutrientValue('Trans Fat (g) 0', ['Trans Fat']), '0');
    expect(extractNutrientValue('Total Fat (g) 12%', ['Total Fat']), '');
  });
  test(
    'OCR separates nutrient amounts from percentages and neighboring labels',
    () {
      expect(extractNutrientValue('Sodium 0.25 g 10%', ['Sodium']), '250.0');
      expect(extractNutrientValue('Sodium 10%', ['Sodium']), '');
      expect(extractNutrientValue('Sodium\nProtein 2 g', ['Sodium']), '');
      expect(extractNutrientValue('Protein\n2 g', ['Protein']), '2');
    },
  );
  test(
    'profile milk and soy allergies exclude matching ingredients',
    () {
      FoodProduct food(String name, double value, List<String> ingredients) =>
          FoodProduct(
            name: name,
            category: 'Snacks',
            price: 10,
            nutritionEligible: true,
            nutritionBasis: 'per100g',
            calories: value,
            sodium: value,
            sugars: value / 10,
            satFat: value / 10,
            ingredients: ingredients,
          );
      final service =
          RecommendationService()..setCatalog([
            food('A', 10, ['whey']),
            food('B', 11, ['soy flour']),
            food('C', 12, ['rice']),
          ]);
      final matches = service.recommend(
        scanned: food('Original', 50, ['milk']),
        user: {'allergies': ['milk', 'soy']},
        remainingBudget: 20,
      );
      expect(matches.map((p) => p.name), ['C']);
    },
  );
  test('recommendations respect the remaining budget', () {
    FoodProduct cracker(String name, double price, double calories) =>
        FoodProduct(
          name: name,
          category: 'Snacks',
          price: price,
          calories: calories,
          nutritionEligible: true,
          nutritionBasis: 'per100g',
        );

    final service = RecommendationService()..setCatalog([
      cracker('Wheat crackers', 50, 100),
      cracker('Rice crackers', 51, 90),
    ]);
    final scan = cracker('Plain crackers', 45, 200);
    List<String> namesAt(double budget) => service
        .recommend(scanned: scan, user: {}, remainingBudget: budget)
        .map((product) => product.name)
        .toList();

    expect(namesAt(50), ['Wheat crackers']);
    expect(namesAt(0), isEmpty);
  });
}
