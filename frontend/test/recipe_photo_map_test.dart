import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meal_planner/data/recipe_photo_map.dart';
import 'package:smart_meal_planner/models/product.dart';
import 'package:smart_meal_planner/models/recipe.dart';

Recipe _recipe({String? authorId}) => Recipe(
  id: 'test',
  name: 'Tost z awokado i pomidorem',
  mealType: 'śniadanie',
  servings: 1,
  difficulty: 'łatwy',
  nutritionTotal: NutritionInfo(
    kcal: 0,
    protein: 0,
    fat: 0,
    carbs: 0,
    fiber: 0,
  ),
  isActive: true,
  tags: const [],
  ingredients: const [],
  createdByUserId: authorId,
);

void main() {
  test('każdy oficjalny przepis ma istniejący plik zdjęcia', () {
    expect(kRecipePhotoAssets, hasLength(137));
    for (final entry in kRecipePhotoAssets.entries) {
      expect(
        File(entry.value).existsSync(),
        isTrue,
        reason: 'Brak zdjęcia dla: ${entry.key} (${entry.value})',
      );
    }
  });

  test('zdjęcia systemowe nie są przypisywane przepisom użytkowników', () {
    expect(_recipe().realPhotoAsset, isNotNull);
    expect(_recipe(authorId: 'user-1').realPhotoAsset, isNull);
  });
}
