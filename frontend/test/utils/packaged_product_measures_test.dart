import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meal_planner/models/product.dart';
import 'package:smart_meal_planner/utils/product_measures.dart';

void main() {
  for (final name in ['Neutral product', 'Produkt testowy']) {
    test('persisted ml package is retained for $name', () {
      final product = Product(
        id: 'local',
        name: name,
        unit: 'opak',
        defaultQuantity: 1,
        servingQuantity: 500,
        nutritionPer100: NutritionInfo.fromJson({'kcal': 60}),
        measureOptions: const [
          ProductMeasureOption(
            code: 'ml',
            label: 'ml',
            baseQuantity: 1,
            baseUnit: 'ml',
          ),
          ProductMeasureOption(
            code: 'opak',
            label: 'pack',
            baseQuantity: 500,
            baseUnit: 'ml',
          ),
          ProductMeasureOption(
            code: 'porcja',
            label: 'portion',
            baseQuantity: 175,
            baseUnit: 'ml',
          ),
        ],
      );
      final options = effectiveMeasureOptions(product);
      final pack = options.singleWhere((o) => o.code == 'opak');
      expect(pack.baseUnit, 'ml');
      expect(pack.baseQuantity, 500);
      expect(recommendedPortionQuantity(product), 175);
      expect(
        ProductAmountSelection(
              quantity: 1,
              measure: pack,
            ).nutritionFactorPer100() *
            60,
        300,
      );
      expect(options.any((o) => o.code == 'g'), isFalse);
    });
  }
  test('explicit gram basis wins over a liquid word in the name', () {
    final product = Product(
      id: 'powder',
      name: 'Mleko w proszku',
      unit: 'g',
      defaultQuantity: 100,
      servingQuantity: 400,
      nutritionPer100: NutritionInfo.fromJson({'kcal': 480}),
    );
    expect(
      effectiveMeasureOptions(
        product,
      ).singleWhere((o) => o.code == 'opak').baseUnit,
      'g',
    );
  });
}
