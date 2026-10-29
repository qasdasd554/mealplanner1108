import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meal_planner/models/shopping_list.dart';
import 'package:smart_meal_planner/providers/shopping_list_provider.dart';
import 'package:smart_meal_planner/services/shopping_list_service.dart';

class _FakeShoppingListService extends ShoppingListService {
  _FakeShoppingListService({this.country = 'PL'});
  final String country;
  bool checked = false;
  bool failToggle = false;
  bool loseNextReply = false;
  bool? requestedState;

  ShoppingList _list() => ShoppingList(
    id: 'list-1',
    mealPlanId: 'plan-1',
    storeId: 'store-1',
    storeName: 'Sklep',
    status: 'active',
    totalEstimatedPrice: 10,
    currencyCode: country == 'GB' ? 'GBP' : 'PLN',
    itemsByDepartment: {
      'Inne': [
        ShoppingListItem(
          id: 'item-1',
          productName: 'Produkt',
          departmentName: 'Inne',
          departmentSortOrder: 1,
          requiredQuantity: 1,
          unit: 'szt',
          currencyCode: country == 'GB' ? 'GBP' : 'PLN',
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
  Future<bool> toggleItemCheck(
    String listId,
    String itemId, {
    bool? isChecked,
  }) async {
    requestedState = isChecked;
    if (failToggle) throw StateError('test error');
    checked = isChecked ?? !checked;
    if (loseNextReply) {
      loseNextReply = false;
      throw StateError('server saved the change but its reply was lost');
    }
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
    expect(service.requestedState, isTrue);
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

  test('logout clears list selector and all cached account lists', () async {
    final provider = ShoppingListProvider(
      shoppingListService: _FakeShoppingListService(),
    );
    addTearDown(provider.dispose);
    await provider.loadAllLists();
    expect(provider.allLists, isNotEmpty);
    provider.clear();
    expect(provider.currentList, isNull);
    expect(provider.allLists, isEmpty);
    expect(provider.selectedListId, isNull);
  });

  for (final country in ['PL', 'GB']) {
    test(
      '$country retry after a lost reply keeps the item bought instead of undoing it',
      () async {
        final service = _FakeShoppingListService(country: country)
          ..loseNextReply = true;
        final provider = ShoppingListProvider(shoppingListService: service);
        addTearDown(provider.dispose);
        await provider.loadAllLists();
        expect(await provider.toggleItem('item-1'), isFalse);
        expect(service.checked, isTrue);
        expect(_item(provider).isChecked, isFalse);
        expect(await provider.toggleItem('item-1'), isTrue);
        expect(service.checked, isTrue);
        expect(_item(provider).isChecked, isTrue);
      },
    );
  }
}
