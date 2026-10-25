import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meal_planner/l10n/recipe_content.dart';
import 'package:smart_meal_planner/l10n/system_content_data.dart';
import 'package:smart_meal_planner/models/product.dart';
import 'package:smart_meal_planner/models/recipe.dart';

Recipe fromSource(
  String id,
  Map<String, dynamic> source, {
  String? creator,
  String? name,
  String? description,
  List<String>? instructions,
  bool summary = false,
}) => Recipe(
  id: id,
  name: name ?? source['name'] as String,
  description: description ?? source['description'] as String?,
  mealType: 'obiad',
  servings: 2,
  difficulty: 'łatwy',
  nutritionTotal: NutritionInfo(
    kcal: 222,
    protein: 20,
    fat: 8,
    carbs: 30,
    fiber: 4,
  ),
  isActive: true,
  tags: const [],
  ingredients: const [],
  instructions:
      summary
          ? []
          : instructions ?? (source['instructions'] as List).cast<String>(),
  suggestedSeasonings:
      summary ? [] : (source['suggested_seasonings'] as List).cast<String>(),
  createdByUserId: creator,
);

void main() {
  test(
    'registry covers 137 reviewed system recipes and all 390 catalogue ingredients',
    () {
      expect(systemRecipeText, hasLength(137));
      expect(systemIngredientText, hasLength(390));
    },
  );
  for (final entry in systemRecipeText.entries) {
    test(
      'system display is English without changing canonical content: ${entry.key}',
      () {
        final source = entry.value['source'] as Map<String, dynamic>;
        final english = entry.value['en_GB'] as Map<String, dynamic>;
        final recipe = fromSource(entry.key, source);
        final photoBefore = recipe.realPhotoAsset;
        expect(recipe.nameForLanguage('en_GB'), english['name']);
        expect(recipe.descriptionForLanguage('en_GB'), english['description']);
        expect(
          recipe.instructionsForLanguage('en_GB'),
          english['instructions'],
        );
        expect(
          recipe.seasoningsForLanguage('en_GB'),
          english['suggested_seasonings'],
        );
        expect(recipe.nameForLanguage('pl'), source['name']);
        expect(recipe.instructionsForLanguage('pl'), source['instructions']);
        expect(recipe.name, source['name']);
        expect(recipe.instructions, source['instructions']);
        expect(recipe.nutritionTotal.kcal, 222);
        expect(recipe.servings, 2);
        expect(recipe.realPhotoAsset, photoBefore);
        final summary = fromSource(entry.key, source, summary: true);
        expect(summary.nameForLanguage('en_GB'), english['name']);
        expect(summary.instructionsForLanguage('en_GB'), isEmpty);
      },
    );
  }
  test('same name or seed ID never overrides authored or modified content', () {
    final entry = systemRecipeText.entries.first;
    final source = entry.value['source'] as Map<String, dynamic>;
    for (final recipe in [
      fromSource('not-a-system-id', source),
      fromSource(entry.key, source, creator: 'synthetic-author'),
      fromSource(entry.key, source, name: 'Edited system title'),
      fromSource(entry.key, source, description: 'Edited system description'),
    ]) {
      expect(recipe.nameForLanguage('en_GB'), recipe.name);
      expect(recipe.instructionsForLanguage('en_GB'), recipe.instructions);
    }
    final changedSteps = fromSource(
      entry.key,
      source,
      instructions: ['Edited source step'],
    );
    expect(changedSteps.instructionsForLanguage('en_GB'), [
      'Edited source step',
    ]);
    expect(
      changedSteps.seasoningsForLanguage('en_GB'),
      changedSteps.suggestedSeasonings,
    );
  });
  test('ingredient display uses exact seed identity, never a similar name', () {
    for (final entry in systemIngredientText.entries) {
      final source = entry.value['source']!;
      expect(
        ingredientNameForLanguage(entry.key, source, 'en_GB'),
        entry.value['en_GB'],
      );
      expect(ingredientNameForLanguage(entry.key, source, 'pl'), source);
      expect(ingredientNameForLanguage('user-id', source, 'en_GB'), source);
      expect(
        ingredientNameForLanguage(entry.key, '$source edited', 'en_GB'),
        '$source edited',
      );
    }
    expect(ingredientNameForLanguage('unknown', null, 'en_GB'), isNull);
  });
}
