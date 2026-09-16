import '../models/friend.dart';
import '../models/recipe.dart';
import '../models/shopping_list.dart';
import 'api_client.dart';

class FriendService {
  final ApiClient _client = ApiClient();

  Future<List<FriendEntry>> getFriends() async {
    final response = await _client.get('/friends/');
    return (response as List)
        .map((item) => FriendEntry.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<FriendEntry>> getInvitations() async {
    final response = await _client.get('/friends/invitations');
    return (response as List)
        .map((item) => FriendEntry.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<FriendEntry> invite(String identifier) async {
    final response = await _client.post(
      '/friends/invitations',
      body: {'identifier': identifier},
    );
    return FriendEntry.fromJson(response as Map<String, dynamic>);
  }

  Future<void> accept(String connectionId) async {
    await _client.post('/friends/invitations/$connectionId/accept');
  }

  Future<void> declineOrCancel(String connectionId) async {
    await _client.delete('/friends/invitations/$connectionId');
  }

  Future<void> removeFriend(String userId) async {
    await _client.delete('/friends/$userId');
  }

  Future<List<Recipe>> getRecipes(String userId) async {
    final response = await _client.get('/friends/$userId/recipes');
    return (response as List)
        .map((item) => Recipe.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<ShoppingList>> getShoppingLists(String userId) async {
    final response = await _client.get('/friends/$userId/shopping-lists');
    return (response as List)
        .map((item) => ShoppingList.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}
