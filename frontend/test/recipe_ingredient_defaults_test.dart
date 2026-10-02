import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meal_planner/utils/recipe_ingredient_defaults.dart';

void main() {
  test('opakowanie domyślnie oznacza jedną sztukę opakowania', () {
    expect(defaultRecipeIngredientQuantity('opak'), 1);
  });

  test('produkty wagowe zachowują praktyczne 100 gramów', () {
    expect(defaultRecipeIngredientQuantity('g'), 100);
    expect(defaultRecipeIngredientQuantity('ml'), 100);
  });
}
