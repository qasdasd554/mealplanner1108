import '../models/shopping_list.dart';
import 'api_client.dart';
import '../config/api_config.dart';

/// Zaproszenie/udostępnienie listy zakupów — dwuetapowe (pending ->
/// accepted). Jedna klasa obsługuje oba kierunki (kto komu udostępnił),
/// pola shared_by_name/shared_with_name są opcjonalne w zależności od
/// kontekstu (patrz backend, ShoppingListShareResponse).
class ShoppingListShare {
  final String id;
  final String mealPlanId;
  final String status;
  final DateTime createdAt;
  final String? sharedByName;
  final String? sharedWithName;
  final String? sharedWithEmail;

  ShoppingListShare({
    required this.id,
    required this.mealPlanId,
    required this.status,
    required this.createdAt,
    this.sharedByName,
    this.sharedWithName,
    this.sharedWithEmail,
  });

  factory ShoppingListShare.fromJson(Map<String, dynamic> json) {
    return ShoppingListShare(
      id: json['id'] as String,
      mealPlanId: json['meal_plan_id'] as String,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      sharedByName: json['shared_by_name'] as String?,
      sharedWithName: json['shared_with_name'] as String?,
      sharedWithEmail: json['shared_with_email'] as String?,
    );
  }
}

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

  /// Udostępnia listę zakupów innemu użytkownikowi po adresie e-mail —
  /// tworzy ZAPROSZENIE (status "pending"), druga strona musi je
  /// zaakceptować, zanim dostanie faktyczny dostęp do listy.
  Future<ShoppingListShare> shareList(String listId, String email) async {
    final response = await _client.post(
      '${ApiConfig.shoppingLists}$listId/share',
      body: {'email': email},
    );
    return ShoppingListShare.fromJson(response as Map<String, dynamic>);
  }

  /// Zaproszenia oczekujące NA CIEBIE (do zaakceptowania/odrzucenia).
  Future<List<ShoppingListShare>> getPendingShares() async {
    final response = await _client.get('${ApiConfig.shoppingLists}shares/pending');
    return (response as List).map((e) => ShoppingListShare.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Listy, które ktoś Ci udostępnił i które już zaakceptowałeś.
  Future<List<ShoppingListShare>> getSharedWithMe() async {
    final response = await _client.get('${ApiConfig.shoppingLists}shares/shared-with-me');
    return (response as List).map((e) => ShoppingListShare.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<ShoppingListShare> acceptShare(String shareId) async {
    final response = await _client.post('${ApiConfig.shoppingLists}shares/$shareId/accept');
    return ShoppingListShare.fromJson(response as Map<String, dynamic>);
  }

  /// Odrzuca zaproszenie / usuwa udostępnienie / opuszcza współdzieloną
  /// listę — to ten sam endpoint dla wszystkich trzech przypadków
  /// (patrz komentarz w backendzie).
  Future<void> deleteShare(String shareId) async {
    await _client.delete('${ApiConfig.shoppingLists}shares/$shareId');
  }
}
