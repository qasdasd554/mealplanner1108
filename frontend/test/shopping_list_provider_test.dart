import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meal_planner/models/shopping_list.dart';
import 'package:smart_meal_planner/providers/shopping_list_provider.dart';
import 'package:smart_meal_planner/services/shopping_list_service.dart';

class _FakeShoppingListService extends ShoppingListService {
  bool checked = false;
  bool failToggle = false;

  ShoppingList _list() => ShoppingList(
    id: 'list-1',
    mealPlanId: 'plan-1',
    storeId: 'store-1',
    storeName: 'Sklep',
    status: 'active',
    totalEstimatedPrice: 10,
    itemsByDepartment: {
      'Inne': [
        ShoppingListItem(
          id: 'item-1',
          productName: 'Produkt',
          departmentName: 'Inne',
          departmentSortOrder: 1,
          requiredQuantity: 1,
          unit: 'szt',
          isChecked: checked,
        ),
      ],
    },
    createdAt: DateTime(2026),
  );

  @override
  Future<List<ShoppingList>> getMyLists() async => [_list()];

  @override
  Future<ShoppingList> getShoppingList(String listId) async => _list();

  @override
  Future<bool> toggleItemCheck(String listId, String itemId) async {
    if (failToggle) throw StateError('test error');
    checked = !checked;
    return checked;
  }
}

ShoppingListItem _item(ShoppingListProvider provider) =>
    provider.currentList!.itemsByDepartment['Inne']!.single;

void main() {
  test('zaznaczenie produktu pozostaje zgodne ze stanem serwera', () async {
    final service = _FakeShoppingListService();
    final provider = ShoppingListProvider(shoppingListService: service);
    addTearDown(provider.dispose);

    await provider.loadAllLists();
    expect(_item(provider).isChecked, isFalse);

    expect(await provider.toggleItem('item-1'), isTrue);
    expect(_item(provider).isChecked, isTrue);
    expect(service.checked, isTrue);
  });

  test('błąd zapisu przywraca poprzedni stan produktu', () async {
    final service = _FakeShoppingListService()..failToggle = true;
    final provider = ShoppingListProvider(shoppingListService: service);
    addTearDown(provider.dispose);

    await provider.loadAllLists();
    expect(await provider.toggleItem('item-1'), isFalse);
    expect(_item(provider).isChecked, isFalse);
    expect(provider.errorMessage, isNotNull);
  });
}
