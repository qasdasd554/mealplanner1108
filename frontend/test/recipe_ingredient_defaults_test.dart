import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meal_planner/utils/recipe_ingredient_defaults.dart';

void main() {
  for (final unit in ['opak', 'szt', 'g', 'ml', 'kg', 'l']) {
    test('recipe quantity boundary agrees with API for $unit', () {
      final maximum = unit == 'opak' || unit == 'szt' ? 50.0 : 20000.0;
      expect(validRecipeIngredientQuantity(maximum, unit), isTrue);
      expect(validRecipeIngredientQuantity(maximum + 0.1, unit), isFalse);
      for (final invalid in [0.0, -1.0, double.nan, double.infinity, 1e308]) {
        expect(validRecipeIngredientQuantity(invalid, unit), isFalse);
      }
    });
  }
  test('opakowanie domyślnie oznacza jedną sztukę opakowania', () {
    expect(defaultRecipeIngredientQuantity('opak'), 1);
  });

  test('produkty wagowe zachowują praktyczne 100 gramów', () {
    expect(defaultRecipeIngredientQuantity('g'), 100);
    expect(defaultRecipeIngredientQuantity('ml'), 100);
  });
}
