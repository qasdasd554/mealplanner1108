import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meal_planner/models/weekly_plan_automation.dart';

void main() {
  test('odczytuje ustawienia i status automatycznego tygodnia', () {
    final automation = WeeklyPlanAutomation.fromJson({
      'enabled': true,
      'weekday': 5,
      'hour': 9,
      'create_shopping_list': false,
      'last_success_at': '2026-09-30T10:15:00Z',
      'last_plan_id': 'plan-1',
    });

    expect(automation.enabled, isTrue);
    expect(automation.weekday, 5);
    expect(automation.hour, 9);
    expect(automation.createShoppingList, isFalse);
    expect(automation.lastSuccessAt, DateTime.utc(2026, 9, 30, 10, 15));
    expect(automation.lastPlanId, 'plan-1');
  });
}
