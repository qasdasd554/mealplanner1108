import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meal_planner/models/recipe.dart';

void main() {
  test('unknown recipe nutrition stays unknown instead of a real zero', () {
    final recipe = Recipe.fromJson({
      'id': 'private',
      'name': 'Recipe',
      'meal_type': 'obiad',
      'nutrition_total': {
        'kcal': null,
        'protein': null,
        'fat': null,
        'carbs': null,
        '_incomplete': true,
        '_missing_ingredients': ['Filo pastry'],
      },
      'ingredients': [
        {
          'id': 'ingredient',
          'product_id': 'private-product',
          'product_name': 'Filo pastry',
          'quantity': 200,
          'unit': 'g',
          'kcal': null,
        },
      ],
    });
    expect(recipe.hasIncompleteNutrition, isTrue);
    expect(recipe.missingNutritionIngredients, ['Filo pastry']);
    expect(recipe.nutritionTotal.knownValue('kcal'), isNull);
    expect(recipe.ingredients.single.kcal, isNull);
    expect(recipe.ingredients.single.quantity, 200);
  });
}
