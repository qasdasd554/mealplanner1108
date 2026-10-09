import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meal_planner/models/weekly_insight.dart';
import 'package:smart_meal_planner/models/wellness_statistics.dart';
import 'package:smart_meal_planner/models/weight_log.dart';

WellnessStatistics _statistics({
  required List<DailyWellnessStatistics> days,
  List<WeightLogEntry> weights = const [],
}) => WellnessStatistics(
  days: days,
  weights: weights,
  favoriteMeal: null,
  averageCalories: 0,
  averageProtein: 0,
  averageFat: 0,
  averageCarbs: 0,
  averageWaterMl: 0,
);

void main() {
  test('raport obejmuje siedem dni kalendarzowych, a nie stare rekordy', () {
    final insights = buildWeeklyInsights(
      _statistics(
        days: [
          DailyWellnessStatistics(
            date: DateTime(2026, 9, 1),
            calories: 5000,
            protein: 0,
            fat: 0,
            carbs: 0,
            waterMl: 0,
          ),
          DailyWellnessStatistics(
            date: DateTime(2026, 10, 9),
            calories: 1800,
            protein: 90,
            fat: 60,
            carbs: 200,
            waterMl: 2000,
          ),
        ],
      ),
      referenceDate: DateTime(2026, 10, 9),
    );

    expect(insights.first.title, 'Regularność: 1 z 7 dni');
    expect(
      insights
          .singleWhere((item) => item.kind == WeeklyInsightKind.calories)
          .title,
      'Średnio 1800 kcal dziennie',
    );
  });

  test('zmiana wagi nie wykorzystuje pomiarów starszych niż tydzień', () {
    final insights = buildWeeklyInsights(
      _statistics(
        days: const [],
        weights: [
          WeightLogEntry(id: 'old', date: DateTime(2026, 9, 1), weightKg: 90),
          WeightLogEntry(
            id: 'recent',
            date: DateTime(2026, 10, 9),
            weightKg: 80,
          ),
        ],
      ),
      referenceDate: DateTime(2026, 10, 9),
    );

    expect(
      insights.where((item) => item.kind == WeeklyInsightKind.weight),
      isEmpty,
    );
  });
}
