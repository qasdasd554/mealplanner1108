import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meal_planner/models/shopping_list.dart';

void main() {
  test('spiżarnia nie zawyża postępu ani ceny zakupów', () {
    final list = ShoppingList.fromJson({
      'id': '00000000-0000-0000-0000-000000000001',
      'meal_plan_id': '00000000-0000-0000-0000-000000000001',
      'store_id': '00000000-0000-0000-0000-000000000002',
      'store_name': 'Sklep',
      'status': 'pending',
      'total_estimated_price': 6,
      'created_at': '2026-09-21T12:00:00Z',
      'items_by_department': {
        'Nabiał': [
          {
            'id': '1', 'product_name': 'Mleko',
            'required_quantity': 1, 'unit': 'l',
            'estimated_price': 6, 'is_checked': false,
            'is_from_pantry': false,
          },
        ],
        'W spiżarni': [
          {
            'id': '2', 'product_name': 'Mąka',
            'required_quantity': 150, 'unit': 'g',
            'estimated_price': 0, 'is_checked': true,
            'is_from_pantry': true,
          },
        ],
      },
    });

    expect(list.totalItems, 1);
    expect(list.checkedItems, 0);
    expect(list.progress, 0);
    expect(list.remainingPrice, 6);
    expect(list.itemsByDepartment.keys.last, 'W spiżarni');
    expect(list.itemsByDepartment['W spiżarni']!.single.isFromPantry, isTrue);
  });
}
