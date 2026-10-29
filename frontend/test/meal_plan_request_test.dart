import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meal_planner/models/meal_plan.dart';
import 'package:smart_meal_planner/models/recipe.dart';

void main() {
  for (final people in [1, 3, 8]) {
    for (final servings in [1, 2, 4, 7]) {
      test('plan keeps $people people for a $servings-portion recipe', () {
        final entry = MealPlanEntry.fromJson({
          'id': 'entry',
          'recipe': {'id': 'recipe', 'name': 'Meal', 'servings': servings},
          'servings_multiplier': double.parse(
            (people / servings).toStringAsFixed(2),
          ),
        });
        expect(entry.plannedServings, people);
        expect(
          MealPlanGenerateRequest(
            storeId: 'shop',
            durationDays: 7,
            mealsPerDay: 3,
            householdSize: people,
          ).toJson()['household_size'],
          people,
        );
      });
    }
  }
  test('scaling preserves missing nutrition and the original ingredient', () {
    final original = RecipeIngredient(
      id: 'ingredient',
      productId: 'product',
      quantity: 100,
      unit: 'g',
      isOptional: false,
      protein: 20,
    );
    final scaled = original.scaledBy(3);
    expect(scaled.quantity, 300);
    expect(scaled.protein, 60);
    expect(scaled.kcal, isNull);
    expect(original.quantity, 100);
  });
  test('plan domyślnie uwzględnia spiżarnię', () {
    final request = MealPlanGenerateRequest(
      storeId: 'store',
      durationDays: 7,
      mealsPerDay: 3,
    );

    expect(request.toJson()['include_pantry'], isTrue);
  });

  test('można jawnie wygenerować plan bez spiżarni', () {
    final request = MealPlanGenerateRequest(
      storeId: 'store',
      durationDays: 7,
      mealsPerDay: 3,
      includePantry: false,
    );

    expect(request.toJson()['include_pantry'], isFalse);
  });
}
