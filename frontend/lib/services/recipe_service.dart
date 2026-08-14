import '../models/recipe.dart';
import 'api_client.dart';
import '../config/api_config.dart';

class RecipeService {
  final ApiClient _client = ApiClient();

  Future<List<Recipe>> getRecipes({
    String? mealType,
    String? cuisine,
    String? difficulty,
    String? tag,
    String? search,
    bool favoritesOnly = false,
  }) async {
    var path = '${ApiConfig.recipes}?';
    final params = <String>[];
    if (mealType != null && mealType.isNotEmpty) {
      params.add('meal_type=${Uri.encodeComponent(mealType)}');
    }
    if (cuisine != null && cuisine.isNotEmpty) {
      params.add('cuisine=${Uri.encodeComponent(cuisine)}');
    }
    if (difficulty != null && difficulty.isNotEmpty) {
      params.add('difficulty=${Uri.encodeComponent(difficulty)}');
    }
    if (tag != null && tag.isNotEmpty) {
      params.add('tag=${Uri.encodeComponent(tag)}');
    }
    if (search != null && search.isNotEmpty) {
      params.add('search=${Uri.encodeComponent(search)}');
    }
    if (favoritesOnly) {
      params.add('favorites_only=true');
    }
    // Backend domyślnie zwraca tylko 50 przepisów (paginacja). Baza ma ich
    // teraz ~80, więc bez podania limitu część z nich byłaby niewidoczna
    // w aplikacji. 200 to maksimum akceptowane przez backend.
    params.add('limit=200');

    path += params.join('&');
    final response = await _client.get(path);
    if (response is List) {
      return response.map((e) => Recipe.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  Future<Recipe> getRecipe(String recipeId) async {
    final response = await _client.get('${ApiConfig.recipes}$recipeId');
    return Recipe.fromJson(response as Map<String, dynamic>);
  }

  Future<List<Recipe>> getAvailableRecipes(String storeId) async {
    final response = await _client.get('${ApiConfig.recipesAvailable}?store_id=$storeId');
    if (response is List) {
      return response.map((e) => Recipe.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  Future<void> addFavorite(String recipeId) async {
    await _client.post('${ApiConfig.recipes}$recipeId/favorite');
  }

  Future<void> removeFavorite(String recipeId) async {
    await _client.delete('${ApiConfig.recipes}$recipeId/favorite');
  }
}
