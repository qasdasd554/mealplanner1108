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

  /// Zwraca WYŁĄCZNIE przepisy dodane przez zalogowanego użytkownika (AI).
  Future<List<Recipe>> getMyRecipes() async {
    final response = await _client.get('${ApiConfig.recipes}mine');
    if (response is List) {
      return response.map((e) => Recipe.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  /// Rozpoznaje przepis z wklejonego tekstu przez AI (funkcja Premium).
  Future<Recipe> importRecipeFromText(String text) async {
    final response = await _client.post(
      '${ApiConfig.recipes}ai-import',
      body: {'text': text},
    );
    return Recipe.fromJson(response as Map<String, dynamic>);
  }

  /// Rozpoznaje przepis ze zdjęcia przez AI (funkcja Premium). [photoBase64]
  /// to dane obrazu zakodowane w Base64, bez prefiksu "data:image/...".
  Future<Recipe> importRecipeFromPhoto(String photoBase64) async {
    final response = await _client.post(
      '${ApiConfig.recipes}ai-import',
      body: {'photo_base64': photoBase64},
    );
    return Recipe.fromJson(response as Map<String, dynamic>);
  }

  /// Rozpoznaje przepis na podstawie treści strony pod danym linkiem
  /// (blog kulinarny, TikTok, Instagram itp.) — funkcja Premium.
  Future<Recipe> importRecipeFromUrl(String url) async {
    final response = await _client.post(
      '${ApiConfig.recipes}ai-import',
      body: {'url': url},
    );
    return Recipe.fromJson(response as Map<String, dynamic>);
  }

  /// Tworzy przepis ręcznie wprowadzony przez użytkownika. Domyślnie
  /// prywatny; [requestPublic] (tylko Premium) zgłasza go do wspólnego
  /// katalogu, gdzie czeka na akceptację administratora.
  Future<Recipe> createRecipeManually({
    required String name,
    String? description,
    required String mealType,
    required String difficulty,
    int? prepTimeMin,
    int? cookTimeMin,
    required int servings,
    required List<String> instructions,
    required List<Map<String, dynamic>> ingredients,
    bool requestPublic = false,
  }) async {
    final response = await _client.post(
      ApiConfig.recipes,
      body: {
        'name': name,
        'description': description,
        'meal_type': mealType,
        'difficulty': difficulty,
        'prep_time_min': prepTimeMin,
        'cook_time_min': cookTimeMin,
        'servings': servings,
        'instructions': instructions,
        'ingredients': ingredients,
        'request_public': requestPublic,
      },
    );
    return Recipe.fromJson(response as Map<String, dynamic>);
  }

  /// Akceptuje przepis zgłoszony do wspólnego katalogu (tylko admin).
  Future<Recipe> approveRecipe(String recipeId) async {
    final response = await _client.put('${ApiConfig.recipes}$recipeId/approve');
    return Recipe.fromJson(response as Map<String, dynamic>);
  }

  /// Odrzuca przepis zgłoszony do wspólnego katalogu (tylko admin).
  Future<Recipe> rejectRecipe(String recipeId) async {
    final response = await _client.put('${ApiConfig.recipes}$recipeId/reject');
    return Recipe.fromJson(response as Map<String, dynamic>);
  }
}
