import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meal_planner/models/recipe.dart';

void main() {
  test('lista przepisu odczytuje lekką miniaturę użytkownika', () {
    final recipe = Recipe.fromJson({
      'id': 'recipe-1',
      'name': 'Przepis użytkownika',
      'meal_type': 'obiad',
      'servings': 2,
      'difficulty': 'łatwy',
      'nutrition_total': <String, dynamic>{},
      'is_active': true,
      'photo_thumbnail_base64': 'dGh1bWI=',
    });

    expect(recipe.photoThumbnailBase64, 'dGh1bWI=');
    expect(recipe.photoBase64, isNull);
  });
}
