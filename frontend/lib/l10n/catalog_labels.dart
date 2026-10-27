import 'app_localizations.dart';

/// Display labels only. The Polish values remain the API/storage identifiers.
extension CatalogLabels on AppLocalizations {
  /// Diary headings and controls keep existing Polish capitalisation.
  String diaryMealTypeLabel(String value) {
    if (!localeName.startsWith('en')) return value;
    final label = mealTypeLabel(value);
    return label.isEmpty
        ? label
        : '${label[0].toUpperCase()}${label.substring(1)}';
  }

  String mealTypeLabel(String value) => switch (value.toLowerCase()) {
    'śniadanie' => mealBreakfast,
    'obiad' => mealLunch,
    'kolacja' => mealDinner,
    'przekąska' => mealSnack,
    'deser' => mealDessert,
    _ => value,
  };

  String difficultyLabel(String value) => switch (value.toLowerCase()) {
    'łatwy' => difficultyEasy,
    'średni' => difficultyMedium,
    'trudny' => difficultyHard,
    _ => value,
  };

  String dietName(String value) => switch (value) {
    'Bez ograniczeń' => dietNoRestrictions,
    'Wegetariańska' => dietVegetarian,
    'Wegańska' => dietVegan,
    'Bezglutenowa' => dietGlutenFree,
    'Keto' => dietKeto,
    'Wysokobiałkowa' => dietHighProtein,
    _ => value,
  };

  String dietDescription(String value) => switch (value) {
    'Bez ograniczeń' => dietNoRestrictionsDescription,
    'Wegetariańska' => dietVegetarianDescription,
    'Wegańska' => dietVeganDescription,
    'Bezglutenowa' => dietGlutenFreeDescription,
    'Keto' => dietKetoDescription,
    'Wysokobiałkowa' => dietHighProteinDescription,
    _ => value,
  };

  String planStatusLabel(String value) => switch (value) {
    'active' => planStatusActive,
    'draft' => planStatusDraft,
    'completed' => planStatusCompleted,
    'archived' => planStatusArchived,
    _ => value,
  };

  String unitLabel(String value) => switch (value) {
    'opak' => priceCompareUnitPack,
    'porcja' => priceCompareUnitServing,
    'szt' || 'szt.' => priceCompareUnitPiece,
    'lyzeczka' ||
    'łyżeczka' ||
    'łyżeczki' ||
    'łyżeczek' => priceCompareUnitTeaspoon,
    'lyzka' ||
    'łyżka' ||
    'łyżki' ||
    'łyżek' => localeName.startsWith('en') ? 'tbsp' : 'łyżka',
    'szklanka' => priceCompareUnitCup,
    _ => value,
  };
}
