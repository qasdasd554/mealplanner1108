import '../models/shopping_list.dart';
import 'api_client.dart';
import '../config/api_config.dart';

class ShoppingListService {
  final ApiClient _client = ApiClient();

  Future<ShoppingList> getShoppingList(String listId) async {
    final response = await _client.get('${ApiConfig.shoppingLists}$listId');
    return ShoppingList.fromJson(response as Map<String, dynamic>);
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
}
