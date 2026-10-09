import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meal_planner/models/meal_plan.dart';

void main() {
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
