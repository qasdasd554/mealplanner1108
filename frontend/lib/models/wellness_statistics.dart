import 'weight_log.dart';

class DailyWellnessStatistics {
  final DateTime date;
  final double calories;
  final double protein;
  final double fat;
  final double carbs;
  final int waterMl;

  const DailyWellnessStatistics({
    required this.date,
    required this.calories,
    required this.protein,
    required this.fat,
    required this.carbs,
    required this.waterMl,
  });

  factory DailyWellnessStatistics.fromJson(Map<String, dynamic> json) =>
      DailyWellnessStatistics(
        date: DateTime.parse(json['date'] as String),
        calories: (json['calories'] as num?)?.toDouble() ?? 0,
        protein: (json['protein'] as num?)?.toDouble() ?? 0,
        fat: (json['fat'] as num?)?.toDouble() ?? 0,
        carbs: (json['carbs'] as num?)?.toDouble() ?? 0,
        waterMl: (json['water_ml'] as num?)?.toInt() ?? 0,
      );
}

class WellnessStatistics {
  final List<DailyWellnessStatistics> days;
  final List<WeightLogEntry> weights;
  final String? favoriteMeal;
  final double averageCalories;
  final double averageProtein;
  final double averageFat;
  final double averageCarbs;
  final int averageWaterMl;

  const WellnessStatistics({
    required this.days,
    required this.weights,
    required this.favoriteMeal,
    required this.averageCalories,
    required this.averageProtein,
    required this.averageFat,
    required this.averageCarbs,
    required this.averageWaterMl,
  });

  factory WellnessStatistics.fromJson(Map<String, dynamic> json) {
    final days = (json['days'] as List? ?? const [])
        .map((item) => DailyWellnessStatistics.fromJson(
              item as Map<String, dynamic>,
            ))
        .toList()
      ..sort((first, second) => first.date.compareTo(second.date));

    // Starsza wersja bazy mogła zawierać kilka pomiarów tego samego dnia.
    // Do czasu wykonania migracji po wdrożeniu pokazujemy tylko ostatni wpis,
    // więc wykres nie rysuje kilku punktów dla jednej daty.
    final weightsByDate = <String, WeightLogEntry>{};
    for (final item in (json['weights'] as List? ?? const [])) {
      final entry = WeightLogEntry.fromJson(item as Map<String, dynamic>);
      final key = '${entry.date.year.toString().padLeft(4, '0')}-'
          '${entry.date.month.toString().padLeft(2, '0')}-'
          '${entry.date.day.toString().padLeft(2, '0')}';
      weightsByDate[key] = entry;
    }
    final weights = weightsByDate.values.toList()
      ..sort((first, second) => first.date.compareTo(second.date));

    return WellnessStatistics(
      days: days,
      weights: weights,
      favoriteMeal: json['favorite_meal'] as String?,
      averageCalories:
          (json['average_calories'] as num?)?.toDouble() ?? 0,
      averageProtein: (json['average_protein'] as num?)?.toDouble() ?? 0,
      averageFat: (json['average_fat'] as num?)?.toDouble() ?? 0,
      averageCarbs: (json['average_carbs'] as num?)?.toDouble() ?? 0,
      averageWaterMl: (json['average_water_ml'] as num?)?.toInt() ?? 0,
    );
  }
}
