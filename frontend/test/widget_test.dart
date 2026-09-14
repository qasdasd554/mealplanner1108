import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meal_planner/app.dart';

void main() {
  test('główny widget aplikacji można utworzyć', () {
    const app = SmartMealPlannerApp();
    expect(app, isA<SmartMealPlannerApp>());
  });
}
