import '../models/shopping_list.dart';
import 'api_client.dart';
import '../config/api_config.dart';

class ShoppingListService {
  final ApiClient _client = ApiClient();

  Future<ShoppingList> getShoppingList(String listId) async {
    final response = await _client.get('${ApiConfig.shoppingLists}$listId');
    return ShoppingList.fromJson(response as Map<String, dynamic>);
  }

  /// Twoje zarządzalne listy zakupów (utworzone z wybranych przepisów) —
  /// te, do których można dopisywać kolejne przepisy, i które liczą się
  /// do limitu (1 dla standardu, 5 dla Premium).
  Future<List<ShoppingList>> getMyLists() async {
    final response = await _client.get('${ApiConfig.shoppingLists}mine');
    return (response as List)
        .map((e) => ShoppingList.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Usuwa zarządzalną listę zakupów — zwalnia miejsce w limicie.
  Future<void> deleteList(String listId) async {
    await _client.delete('${ApiConfig.shoppingLists}$listId');
  }

  Future<void> toggleItemCheck(String listId, String itemId) async {
    await _client.put('${ApiConfig.shoppingLists}$listId/items/$itemId/check');
  }

  Future<void> substituteItem(String listId, String itemId, String substituteProductId) async {
    await _client.put(
      '${ApiConfig.shoppingLists}$listId/items/$itemId/substitute',
      body: {'substitute_product_id': substituteProductId},
    );
  }

  Future<Map<String, dynamic>> getSummary(String listId) async {
    final response = await _client.get('${ApiConfig.shoppingLists}$listId/summary');
    return response as Map<String, dynamic>;
  }

  /// Tworzy NOWĄ listę zakupów na konkretne danie/dania (podlega
  /// limitowi: 1 dla standardu, 5 dla Premium) — ALBO, jeśli podano
  /// [existingListId], dopisuje przepisy do JUŻ ISTNIEJĄCEJ listy (nie
  /// zużywa limitu).
  Future<ShoppingList> createFromRecipes({
    required List<String> recipeIds,
    required String storeId,
    String? existingListId,
  }) async {
    final body = <String, dynamic>{'recipe_ids': recipeIds, 'store_id': storeId};
    if (existingListId != null) body['existing_list_id'] = existingListId;
    final response = await _client.post(
      '${ApiConfig.shoppingLists}from-recipes',
      body: body,
    );
    return ShoppingList.fromJson(response as Map<String, dynamic>);
  }
}
