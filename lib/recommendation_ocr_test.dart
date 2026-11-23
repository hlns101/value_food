import 'package:flutter_test/flutter_test.dart';
import 'food_products.dart';
import 'utils/nutrient_value.dart';
import 'recommendation_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'bread sticks and chocolate mallows prefer different compatible foods',
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
            item('Dried mangoes', 10),
            item('Wheat crackers', 11),
            item('Soft marshmallows', 12),
          ]);
      for (final example in [
        ('Bread Stix', 'Wheat crackers'),
        ('Choco Mallow', 'Soft marshmallows'),
      ]) {
        final name = service.printedFoodHint(example.$1)!;
        final ranked = service.recommend(
          scanned: item(name, 50),
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
    'shared milk and soy evidence excludes otherwise eligible alternatives',
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
            food('B', 11, ['soybeans']),
            food('C', 12, ['rice']),
          ]);
      final matches = service.recommend(
        scanned: food('Original', 50, ['milk']),
        scannedAdvisories: ['May contain soy'],
        user: {},
        remainingBudget: 20,
      );
      expect(matches.map((p) => p.name), ['C']);
    },
  );
  test(
    'OCR scan can find related products from the bundled catalog without Firebase',
    () async {
      final service = RecommendationService();
      await service.loadCatalog();
      final scan = FoodProduct(
        name: 'Scanned Item',
        category: '',
        productGroup: 'other',
        calories: 570,
        sodium: 900,
        sugars: 18,
        satFat: 16,
        nutritionEligible: true,
        nutritionBasis: 'per100g',
      );
      expect(service.needsCategory(scan), isTrue);
      expect(
        service.recommend(scanned: scan, user: {}, remainingBudget: 50),
        isNotEmpty,
      );
      final printed = service.identifyPrintedProduct(
        'Oishi Fishda 22G Kropek\nNutrition Facts',
      );
      expect(printed, isNotNull);
      expect(
        service.identifyPrintedProduct('Nutrition facts serving size 36 g'),
        isNull,
      );
      final identifiedScan = FoodProduct(
        name: printed!.name,
        category: printed.category,
        productGroup: printed.productGroup,
        calories: scan.calories,
        sodium: scan.sodium,
        sugars: scan.sugars,
        satFat: scan.satFat,
        nutritionEligible: true,
      );
      final matches = service.recommend(
        scanned: identifiedScan,
        user: {},
        remainingBudget: 50,
      );
      expect(matches, isNotEmpty);
      expect(
        matches.every(
          (p) =>
              p.category == 'Snacks' &&
              p.price > 0 &&
              p.price <= 50 &&
              p.nutritionEligible,
        ),
        isTrue,
      );
      expect(
        service.recommend(
          scanned: identifiedScan,
          user: {},
          remainingBudget: 0,
        ),
        isEmpty,
      );
    },
  );
}
