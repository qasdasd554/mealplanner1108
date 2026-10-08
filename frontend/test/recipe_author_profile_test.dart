import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meal_planner/models/recipe.dart';

void main() {
  test('odczytuje TikTok autora przepisu użytkownika', () {
    final recipe = Recipe.fromJson({
      'id': 'recipe-1',
      'name': 'Przepis użytkownika',
      'meal_type': 'obiad',
      'servings': 2,
      'difficulty': 'łatwy',
      'nutrition_total': <String, dynamic>{},
      'is_active': true,
      'created_by_user_id': 'user-1',
      'created_by_name': 'Autor',
      'created_by_tiktok_username': 'autor.kuchni',
    });

    expect(recipe.createdByTikTokUsername, 'autor.kuchni');
    expect(recipe.hasCreatorTikTok, isTrue);
  });

  test('brak TikToka autora pozostaje pusty', () {
    final recipe = Recipe.fromJson({
      'id': 'recipe-2',
      'name': 'Przepis bez TikToka',
      'meal_type': 'obiad',
      'servings': 2,
      'difficulty': 'łatwy',
      'nutrition_total': <String, dynamic>{},
      'is_active': true,
      'created_by_user_id': 'user-2',
      'created_by_name': 'Autor bez TikToka',
    });

    expect(recipe.createdByTikTokUsername, isNull);
    expect(recipe.hasCreatorTikTok, isFalse);
  });

  test('lekki rekord listy działa bez pól szczegółów', () {
    final recipe = Recipe.fromJson({
      'id': 'recipe-summary',
      'name': 'Szybko wczytany przepis',
      'meal_type': 'obiad',
      'servings': 2,
      'difficulty': 'łatwy',
      'nutrition_total': <String, dynamic>{'kcal': 420},
      'is_active': true,
      'created_at': '2026-10-08T10:00:00Z',
    });

    expect(recipe.name, 'Szybko wczytany przepis');
    expect(recipe.nutritionTotal.kcal, 420);
    expect(recipe.ingredients, isEmpty);
    expect(recipe.instructions, isEmpty);
    expect(recipe.photoBase64, isNull);
  });
}
