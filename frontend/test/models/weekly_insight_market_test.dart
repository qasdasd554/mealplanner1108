import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meal_planner/l10n/app_localizations_en.dart';
import 'package:smart_meal_planner/l10n/app_localizations_pl.dart';
import 'package:smart_meal_planner/models/weekly_insight.dart';
import 'package:smart_meal_planner/models/wellness_statistics.dart';
import 'package:smart_meal_planner/models/weight_log.dart';

WellnessStatistics fixture(int days, {bool water = true, double change = -1}) =>
    WellnessStatistics(
      days: [
        for (var index = 0; index < days; index++)
          DailyWellnessStatistics(
            date: DateTime(2026, 10, 22 - index),
            calories: 1800,
            protein: 90,
            fat: 60,
            carbs: 200,
            waterMl: water ? 2000 : 0,
          ),
        DailyWellnessStatistics(
          date: DateTime(2026, 9, 1),
          calories: 9999,
          protein: 1,
          fat: 1,
          carbs: 1,
          waterMl: 9999,
        ),
      ],
      weights: [
        WeightLogEntry(
          id: 'last',
          date: DateTime(2026, 10, 22),
          weightKg: 80 + change,
        ),
        WeightLogEntry(id: 'first', date: DateTime(2026, 10, 16), weightKg: 80),
        WeightLogEntry(id: 'old', date: DateTime(2026, 9, 1), weightKg: 100),
      ],
      favoriteMeal: 'Unchanged recipe',
      averageCalories: 1800,
      averageProtein: 90,
      averageFat: 60,
      averageCarbs: 200,
      averageWaterMl: 2000,
    );
void main() {
  for (final days in [0, 1, 4, 5, 7]) {
    for (final water in [false, true]) {
      test(
        'UK insight translation preserves counts/window/values days=$days water=$water',
        () {
          final stats = fixture(days, water: water);
          final now = DateTime(2026, 10, 22);
          final pl = buildWeeklyInsights(stats, referenceDate: now);
          final explicitPl = buildWeeklyInsights(
            stats,
            referenceDate: now,
            strings: AppLocalizationsPl(),
          );
          final en = buildWeeklyInsights(
            stats,
            referenceDate: now,
            strings: AppLocalizationsEnGb(),
          );
          expect(
            explicitPl.map(
              (item) => '${item.kind}|${item.title}|${item.detail}',
            ),
            pl.map((item) => '${item.kind}|${item.title}|${item.detail}'),
          );
          expect(en.map((item) => item.kind), pl.map((item) => item.kind));
          expect(en.first.title, 'Consistency: $days of 7 days');
          expect(en.last.title, 'Weight change -1.0 kg');
          if (days > 0) {
            expect(
              en
                  .singleWhere(
                    (item) => item.kind == WeeklyInsightKind.calories,
                  )
                  .title,
              'Average 1800 kcal per day',
            );
            expect(
              en
                  .singleWhere((item) => item.kind == WeeklyInsightKind.water)
                  .title,
              water ? 'Average 2000 ml of water' : 'Hydration data is missing',
            );
          }
          expect(
            en.map((item) => item.title).join('|'),
            isNot(contains('9999')),
          );
        },
      );
    }
  }
  for (final change in [0.0, 0.04, 1.0]) {
    test('UK weight wording retains existing threshold and sign $change', () {
      final result = buildWeeklyInsights(
        fixture(1, change: change),
        referenceDate: DateTime(2026, 10, 22),
        strings: AppLocalizationsEnGb(),
      );
      expect(
        result.last.title,
        change < 0.05
            ? 'No significant weight change'
            : 'Weight change +1.0 kg',
      );
    });
  }
}
