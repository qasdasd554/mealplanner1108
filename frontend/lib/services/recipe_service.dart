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
    bool communityOnly = false,
    // 'name' | 'kcal_asc' | 'kcal_desc' | 'prep_time'
    String? sortBy,
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
      // UWAGA (naprawa): backend oczekuje parametru "tags" (liczba mnoga,
      // list[str] w FastAPI Query) — wysyłanie "tag" (liczba pojedyncza)
      // było CAŁKOWICIE ignorowane przez backend, więc filtrowanie po
      // tagu/diecie nigdy faktycznie nie działało. Nikt tego wcześniej
      // nie zauważył, bo do teraz żaden widoczny filtr w UI z tego nie
      // korzystał.
      params.add('tags=${Uri.encodeComponent(tag)}');
    }
    if (search != null && search.isNotEmpty) {
      params.add('search=${Uri.encodeComponent(search)}');
    }
    if (favoritesOnly) {
      params.add('favorites_only=true');
    }
    if (communityOnly) {
      params.add('community_only=true');
    }
    if (sortBy != null && sortBy.isNotEmpty && sortBy != 'name') {
      params.add('sort_by=${Uri.encodeComponent(sortBy)}');
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
  /// [sortBy]: 'newest' (domyślne), 'name', 'kcal_asc', 'kcal_desc',
  /// 'prep_time' — te same tryby co w [getRecipes], żeby przełącznik
  /// "Moje" nie gubił wybranego sortowania.
  Future<List<Recipe>> getMyRecipes({String? sortBy}) async {
    var path = '${ApiConfig.recipes}mine';
    if (sortBy != null && sortBy.isNotEmpty && sortBy != 'name') {
      path += '?sort_by=${Uri.encodeComponent(sortBy)}';
    }
    final response = await _client.get(path);
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

  /// Lista przepisów oczekujących na akceptację do wspólnego katalogu
  /// (tylko admin) — wcześniej ten endpoint istniał w backendzie, ale
  /// żaden ekran go nie wywoływał, więc admin nie miał jak w ogóle
  /// odkryć, że jakiś przepis czeka na decyzję.
  Future<List<Recipe>> getPendingRecipes() async {
    final response = await _client.get('${ApiConfig.recipes}pending/review');
    if (response is List) {
      return response.map((e) => Recipe.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  /// Sprawdza stan klucza/limitów Gemini API — czy funkcje AI (import
  /// przepisów, skanowanie gazetek) są aktualnie dostępne, czy limit
  /// tokenów/zapytań został wyczerpany (tylko admin).
  Future<Map<String, dynamic>> getAiStatus() async {
    final response = await _client.get('${ApiConfig.recipes}ai-status');
    return response as Map<String, dynamic>;
  }

  /// Usuwa własny przepis (ręcznie dodany albo przez AI). Nie da się
  /// usunąć oficjalnych przepisów dostarczonych z aplikacją.
  Future<void> deleteRecipe(String recipeId) async {
    await _client.delete('${ApiConfig.recipes}$recipeId');
  }

  /// Zgłasza własny, PRYWATNY przepis do publikacji we wspólnym
  /// katalogu — zmienia jego widoczność na "pending" (czeka na
  /// przegląd administratora).
  Future<Recipe> requestPublish(String recipeId) async {
    final response = await _client.put('${ApiConfig.recipes}$recipeId/request-publish');
    return Recipe.fromJson(response as Map<String, dynamic>);
  }

  /// "Co ugotować z tego, co mam" (Premium) — dopasowuje przepisy z
  /// katalogu do posiadanych w domu produktów, posortowane od
  /// najlepiej dopasowanych.
  Future<List<RecipeMatch>> matchByIngredients(List<String> productIds) async {
    final response = await _client.post(
      '${ApiConfig.recipes}match-by-ingredients',
      body: {'product_ids': productIds},
    );
    return (response as List)
        .map((e) => RecipeMatch.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Zgłasza zdjęcie do przepisu. Zdjęcie trafia do moderacji i pojawi
  /// się dopiero po akceptacji administratora.
  Future<void> submitPhoto(String recipeId, String photoBase64) async {
    await _client.post(
      '${ApiConfig.recipes}$recipeId/photo',
      body: {'photo_base64': photoBase64},
    );
  }
}

/// Wynik dopasowania przepisu do posiadanych składników — patrz
/// [RecipeService.matchByIngredients].
class RecipeMatch {
  final Recipe recipe;
  final int matchedCount;
  final int totalRequired;
  final List<String> missingIngredientNames;

  RecipeMatch({
    required this.recipe,
    required this.matchedCount,
    required this.totalRequired,
    required this.missingIngredientNames,
  });

  bool get isFullMatch => missingIngredientNames.isEmpty;

  factory RecipeMatch.fromJson(Map<String, dynamic> json) {
    return RecipeMatch(
      recipe: Recipe.fromJson(json['recipe'] as Map<String, dynamic>),
      matchedCount: json['matched_count'] as int,
      totalRequired: json['total_required'] as int,
      missingIngredientNames: (json['missing_ingredient_names'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
    );
  }
}
