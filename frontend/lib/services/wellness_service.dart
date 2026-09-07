import 'api_client.dart';

/// Pojedyncza aktywność fizyczna zapisana danego dnia.
class ActivityEntry {
  final String id;
  final String name;
  final int kcalBurned;
  final int? durationMin;

  ActivityEntry({
    required this.id,
    required this.name,
    required this.kcalBurned,
    this.durationMin,
  });

  factory ActivityEntry.fromJson(Map<String, dynamic> json) => ActivityEntry(
        id: json['id'] as String,
        name: json['name'] as String,
        kcalBurned: json['kcal_burned'] as int,
        durationMin: json['duration_min'] as int?,
      );
}

/// Nawodnienie i aktywności z jednego dnia.
class DailyWellness {
  final int waterMl;
  final int waterGoalMl;
  final List<ActivityEntry> activities;
  final int totalKcalBurned;

  DailyWellness({
    required this.waterMl,
    required this.waterGoalMl,
    required this.activities,
    required this.totalKcalBurned,
  });

  factory DailyWellness.empty() => DailyWellness(
        waterMl: 0,
        waterGoalMl: 2000,
        activities: const [],
        totalKcalBurned: 0,
      );

  factory DailyWellness.fromJson(Map<String, dynamic> json) {
    final water = json['water'] as Map<String, dynamic>? ?? {};
    return DailyWellness(
      waterMl: water['amount_ml'] as int? ?? 0,
      waterGoalMl: water['goal_ml'] as int? ?? 2000,
      activities: ((json['activities'] as List?) ?? [])
          .map((e) => ActivityEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalKcalBurned: json['total_kcal_burned'] as int? ?? 0,
    );
  }
}

class WellnessService {
  final ApiClient _client = ApiClient();

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<DailyWellness> getForDate(DateTime date) async {
    final response = await _client.get('/wellness/${_fmt(date)}');
    return DailyWellness.fromJson(response as Map<String, dynamic>);
  }

  /// `amountMl` może być ujemne — służy do cofnięcia omyłkowego dodania.
  Future<int> addWater(DateTime date, int amountMl) async {
    final response = await _client.post(
      '/wellness/${_fmt(date)}/water',
      body: {'amount_ml': amountMl},
    );
    return (response as Map<String, dynamic>)['amount_ml'] as int? ?? 0;
  }

  Future<void> addActivity(
    DateTime date, {
    required String name,
    required int kcalBurned,
    int? durationMin,
  }) async {
    await _client.post(
      '/wellness/${_fmt(date)}/activities',
      body: {
        'name': name,
        'kcal_burned': kcalBurned,
        if (durationMin != null) 'duration_min': durationMin,
      },
    );
  }

  Future<void> deleteActivity(String activityId) async {
    await _client.delete('/wellness/activities/$activityId');
  }
}
