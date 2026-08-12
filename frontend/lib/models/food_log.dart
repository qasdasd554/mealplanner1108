/// UWAGA: wcześniej ten model czytał/wysyłał pola `food_name` i
/// `portion_size` — których backend w ogóle nie zna (tam są `custom_name`
/// i `servings`). Efekt: zapis ręcznego wpisu zawsze kończył się błędem
/// 400, a odczyt istniejących wpisów pokazywałby puste nazwy i 0g. Teraz
/// pola dokładnie odpowiadają kontraktowi backendu.
class FoodLogEntry {
  final String id;
  final String userId;
  final DateTime date;
  final String mealType; // np. śniadanie, obiad, kolacja, przekąska
  final String? recipeId;
  final String? recipeName;
  final String? customName;
  final double servings;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;

  FoodLogEntry({
    required this.id,
    required this.userId,
    required this.date,
    required this.mealType,
    this.recipeId,
    this.recipeName,
    this.customName,
    required this.servings,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  /// Nazwa do wyświetlenia — przepis (jeśli wpis z przepisu) albo własna
  /// nazwa (wpis ręczny).
  String get displayName => recipeName ?? customName ?? 'Posiłek';

  factory FoodLogEntry.fromJson(Map<String, dynamic> json) {
    return FoodLogEntry(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      date: DateTime.parse(json['date'] as String),
      mealType: json['meal_type'] as String? ?? 'przekąska',
      recipeId: json['recipe_id']?.toString(),
      recipeName: json['recipe_name'] as String?,
      customName: json['custom_name'] as String?,
      servings: (json['servings'] as num?)?.toDouble() ?? 1.0,
      calories: (json['calories'] as num?)?.toDouble() ?? 0.0,
      protein: (json['protein'] as num?)?.toDouble() ?? 0.0,
      carbs: (json['carbs'] as num?)?.toDouble() ?? 0.0,
      fat: (json['fat'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toCreateJson() {
    return {
      'date': '${date.year.toString().padLeft(4, '0')}-'
          '${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')}',
      'meal_type': mealType,
      if (recipeId != null) 'recipe_id': recipeId,
      if (customName != null) 'custom_name': customName,
      'servings': servings,
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
    };
  }
}

class DailySummary {
  final DateTime date;
  final double totalCalories;
  final double totalProtein;
  final double totalCarbs;
  final double totalFat;
  final double targetCalories;

  DailySummary({
    required this.date,
    required this.totalCalories,
    required this.totalProtein,
    required this.totalCarbs,
    required this.totalFat,
    required this.targetCalories,
  });

  factory DailySummary.fromJson(Map<String, dynamic> json) {
    return DailySummary(
      date: DateTime.parse(json['date'] as String),
      totalCalories: (json['total_calories'] as num?)?.toDouble() ?? 0.0,
      totalProtein: (json['total_protein'] as num?)?.toDouble() ?? 0.0,
      totalCarbs: (json['total_carbs'] as num?)?.toDouble() ?? 0.0,
      totalFat: (json['total_fat'] as num?)?.toDouble() ?? 0.0,
      // Backend nie zwraca dziennego celu kalorycznego (nie ma go jeszcze
      // jako preferencji użytkownika) — używamy rozsądnej wartości domyślnej.
      targetCalories: (json['target_calories'] as num?)?.toDouble() ?? 2000.0,
    );
  }
}
