import '../models/ingredient_preferences.dart';
import 'api_client.dart';

class IngredientPreferencesService {
  final ApiClient _client = ApiClient();

  Future<IngredientPreferences> load() async {
    final response = await _client.get('/users/me/ingredient-preferences');
    return IngredientPreferences.fromJson(response as Map<String, dynamic>);
  }

  Future<IngredientPreferences> save(IngredientPreferences preferences) async {
    final response = await _client.put(
      '/users/me/ingredient-preferences',
      body: preferences.toJson(),
    );
    return IngredientPreferences.fromJson(response as Map<String, dynamic>);
  }
}
