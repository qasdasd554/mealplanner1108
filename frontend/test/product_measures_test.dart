import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meal_planner/models/product.dart';
import 'package:smart_meal_planner/utils/product_measures.dart';

Product product({
  required String name,
  required String unit,
  double defaultQuantity = 1,
  double? servingQuantity,
}) => Product(
  id: '1',
  name: name,
  unit: unit,
  defaultQuantity: defaultQuantity,
  servingQuantity: servingQuantity,
  nutritionPer100: NutritionInfo(
    kcal: 100,
    protein: 10,
    fat: 5,
    carbs: 20,
    fiber: 2,
  ),
);

void main() {
  test('mleko ma opakowanie, lyzeczke i szklanke', () {
    final options = effectiveMeasureOptions(
      product(
        name: 'Mleko 2%',
        unit: 'l',
        defaultQuantity: 1,
        servingQuantity: 1000,
      ),
    );
    final byCode = {for (final option in options) option.code: option};

    expect(byCode['opak']!.baseQuantity, 1000);
    expect(byCode['lyzeczka']!.baseQuantity, 5);
    expect(byCode['szklanka']!.baseQuantity, 250);
  });

  test('mieso nie dostaje sztucznej szklanki ani lyzeczki', () {
    final codes = effectiveMeasureOptions(
      product(
        name: 'Pierś z kurczaka',
        unit: 'g',
        defaultQuantity: 500,
        servingQuantity: 500,
      ),
    ).map((option) => option.code);

    expect(codes, isNot(contains('szklanka')));
    expect(codes, isNot(contains('lyzeczka')));
  });

  test('wybrana jednostka liczy poprawny mnoznik makro', () {
    const selection = ProductAmountSelection(
      quantity: 2,
      measure: ProductMeasureOption(
        code: 'szklanka',
        label: 'szklanka',
        baseQuantity: 250,
        baseUnit: 'ml',
      ),
    );

    expect(selection.baseAmount, 500);
    expect(selection.nutritionFactorPer100(), 5);
  });

  test('nie zgaduje masy sztuki bez przelicznika z serwera', () {
    final codes = effectiveMeasureOptions(
      product(name: 'Nieznany produkt', unit: 'szt'),
    ).map((option) => option.code);

    expect(codes, isNot(contains('szt')));
    expect(codes, contains('g'));
  });
}
