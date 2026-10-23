import '../l10n/app_localizations.dart';
import '../l10n/app_localizations_pl.dart';
import 'wellness_statistics.dart';

enum WeeklyInsightKind { regularity, calories, water, weight }

class WeeklyInsight {
  final WeeklyInsightKind kind;
  final String title;
  final String detail;

  const WeeklyInsight({
    required this.kind,
    required this.title,
    required this.detail,
  });
}

/// Buduje wnioski wyłącznie z bieżącego, siedmiodniowego okna.
///
/// Wcześniej ekran brał po prostu siedem ostatnich rekordów oraz dwa
/// ostatnie pomiary wagi. Przy dniach bez wpisów mogło to opisywać dane
/// starsze niż tydzień jako „ostatnie 7 dni”. Jawne okno dat usuwa tę
/// nieścisłość i pozwala łatwo przetestować zmianę dnia.
List<WeeklyInsight> buildWeeklyInsights(
  WellnessStatistics statistics, {
  DateTime? referenceDate,
  AppLocalizations? strings,
}) {
  final labels = strings ?? AppLocalizationsPl();
  final sourceNow = referenceDate ?? DateTime.now();
  final today = DateTime(sourceNow.year, sourceNow.month, sourceNow.day);
  final firstDay = today.subtract(const Duration(days: 6));
  final dayAfterWindow = today.add(const Duration(days: 1));

  bool isInWindow(DateTime value) {
    final day = DateTime(value.year, value.month, value.day);
    return !day.isBefore(firstDay) && day.isBefore(dayAfterWindow);
  }

  final recent = statistics.days.where((day) => isInWindow(day.date)).toList();
  final active =
      recent.where((day) => day.calories > 0 || day.waterMl > 0).toList();
  final insights = <WeeklyInsight>[
    WeeklyInsight(
      kind: WeeklyInsightKind.regularity,
      title: labels.insightRegularity(active.length),
      detail:
          active.length >= 5
              ? labels.insightEnough
              : labels.insightMoreDays(5 - active.length),
    ),
  ];

  if (active.isNotEmpty) {
    final averageCalories =
        active.fold<double>(0, (sum, day) => sum + day.calories) /
        active.length;
    insights.add(
      WeeklyInsight(
        kind: WeeklyInsightKind.calories,
        title: labels.insightCalories(averageCalories.round()),
        detail: labels.insightCaloriesDetail,
      ),
    );

    final waterDays = active.where((day) => day.waterMl > 0).toList();
    final averageWater =
        waterDays.isEmpty
            ? 0
            : waterDays.fold<int>(0, (sum, day) => sum + day.waterMl) ~/
                waterDays.length;
    insights.add(
      WeeklyInsight(
        kind: WeeklyInsightKind.water,
        title:
            waterDays.isEmpty
                ? labels.insightWaterMissing
                : labels.insightWaterAverage(averageWater),
        detail:
            waterDays.length == 7
                ? labels.insightWaterEveryDay
                : labels.insightWaterDays(waterDays.length),
      ),
    );
  }

  final recentWeights =
      statistics.weights.where((entry) => isInWindow(entry.date)).toList()
        ..sort((first, second) => first.date.compareTo(second.date));
  if (recentWeights.length >= 2) {
    final change = recentWeights.last.weightKg - recentWeights.first.weightKg;
    insights.add(
      WeeklyInsight(
        kind: WeeklyInsightKind.weight,
        title:
            change.abs() < 0.05
                ? labels.insightWeightStable
                : labels.insightWeightChange(
                  '${change > 0 ? '+' : ''}${change.toStringAsFixed(1)}',
                ),
        detail: labels.insightWeightDetail,
      ),
    );
  }

  return insights;
}
