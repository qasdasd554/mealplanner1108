import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meal_planner/models/food_log.dart';
import 'package:smart_meal_planner/providers/food_log_provider.dart';
import 'package:smart_meal_planner/providers/wellness_provider.dart';
import 'package:smart_meal_planner/services/food_log_service.dart';
import 'package:smart_meal_planner/services/wellness_service.dart';
import 'package:smart_meal_planner/providers/meal_plan_provider.dart';
import 'package:smart_meal_planner/services/meal_plan_service.dart';
import 'package:smart_meal_planner/models/meal_plan.dart';

class _Plans extends MealPlanService {
  final pending = Completer<List<MealPlan>>();
  @override
  Future<List<MealPlan>> getPlans() => pending.future;
}

class _FoodService extends FoodLogService {
  final requests = <DateTime, Completer<List<FoodLogEntry>>>{};

  @override
  Future<List<FoodLogEntry>> getLogsForDate(DateTime date, String token) =>
      (requests[date] = Completer<List<FoodLogEntry>>()).future;

  @override
  Future<DailySummary> getDailySummary(DateTime date, String token) async =>
      DailySummary(
        date: date,
        totalCalories: date.day.toDouble(),
        totalProtein: 0,
        totalCarbs: 0,
        totalFat: 0,
        targetCalories: 2000,
      );
}

class _WellnessService extends WellnessService {
  final requests = <DateTime, Completer<DailyWellness>>{};
  final waterRequests = <int, Completer<int>>{};

  @override
  Future<int> addWater(DateTime date, int amountMl) =>
      (waterRequests[amountMl] = Completer<int>()).future;

  @override
  Future<DailyWellness> getForDate(DateTime date) =>
      (requests[date] = Completer<DailyWellness>()).future;
}

DailyWellness _water(int ml) => DailyWellness(
  waterMl: ml,
  waterGoalMl: 2000,
  activities: [],
  totalKcalBurned: 0,
);

void main() {
  final yesterday = DateTime(2026, 10, 13);
  final today = DateTime(2026, 10, 14);
  test('failed water tap does not undo another successful water tap', () async {
    final service = _WellnessService();
    final provider = WellnessProvider(service: service);
    addTearDown(provider.dispose);
    final first = provider.addWater(100);
    final second = provider.addWater(200);
    service.waterRequests[200]!.complete(200);
    await second;
    service.waterRequests[100]!.completeError(StateError('failed water'));
    await first;
    expect(provider.data.waterMl, 200);
  });
  test('meal plan clear cannot be reversed by pending account load', () async {
    final service = _Plans();
    final provider = MealPlanProvider(service: service);
    addTearDown(provider.dispose);
    final request = provider.loadPlans();
    provider.clear();
    service.pending.complete([
      MealPlan(
        id: 'old',
        userId: 'old-user',
        storeId: 'store',
        status: 'draft',
        durationDays: 7,
        mealsPerDay: 3,
        entries: [],
        createdAt: DateTime(2026, 10, 14),
      ),
    ]);
    await request;
    expect(provider.plans, isEmpty);
    expect(provider.hasLoaded, isFalse);
  });

  test(
    'diary ignores previous date response completing after selected date',
    () async {
      final service = _FoodService();
      final provider = FoodLogProvider(
        service: service,
        readToken: () async => 'test',
      );
      addTearDown(provider.dispose);
      final first = provider.fetchLogsForDate(yesterday);
      await Future<void>.delayed(Duration.zero);
      final second = provider.fetchLogsForDate(today);
      await Future<void>.delayed(Duration.zero);
      service.requests[today]!.complete([]);
      await second;
      service.requests[yesterday]!.complete([]);
      await first;
      expect(provider.summary!.date, today);
    },
  );

  test(
    'diary cleared on logout cannot be repopulated by pending response',
    () async {
      final service = _FoodService();
      final provider = FoodLogProvider(
        service: service,
        readToken: () async => 'test',
      );
      addTearDown(provider.dispose);
      final request = provider.fetchLogsForDate(today);
      await Future<void>.delayed(Duration.zero);
      provider.clear();
      service.requests[today]!.complete([]);
      await request;
      expect(provider.summary, isNull);
      expect(provider.logs, isEmpty);
      expect(provider.isLoading, isFalse);
    },
  );

  test('wellness ignores previous date response after selected date', () async {
    final service = _WellnessService();
    final provider = WellnessProvider(service: service);
    addTearDown(provider.dispose);
    final first = provider.loadForDate(yesterday);
    final second = provider.loadForDate(today);
    service.requests[today]!.complete(_water(1400));
    await second;
    service.requests[yesterday]!.complete(_water(300));
    await first;
    expect(provider.data.waterMl, 1400);
  });

  test(
    'wellness clear invalidates pending load and hasLoaded status',
    () async {
      final service = _WellnessService();
      final provider = WellnessProvider(service: service);
      addTearDown(provider.dispose);
      final request = provider.loadForDate(today);
      provider.clear();
      service.requests[today]!.complete(_water(1400));
      await request;
      expect(provider.data.waterMl, 0);
      expect(provider.hasLoaded, isFalse);
    },
  );
}
