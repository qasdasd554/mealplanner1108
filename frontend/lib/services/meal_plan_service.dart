import '../models/meal_plan.dart';
import '../models/weekly_plan_automation.dart';
import 'api_client.dart';
import '../config/api_config.dart';

class MealPlanService {
  final ApiClient _client = ApiClient();

  Future<MealPlan> generatePlan(MealPlanGenerateRequest request) async {
    final response = await _client.post(
      '${ApiConfig.mealPlans}generate',
      body: request.toJson(),
    );
    return MealPlan.fromJson(response as Map<String, dynamic>);
  }

  Future<List<MealPlan>> getPlans() async {
    final response = await _client.get(ApiConfig.mealPlans);
    if (response is List) {
      return response
          .map((e) => MealPlan.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<MealPlan> getPlan(String planId) async {
    final response = await _client.get('${ApiConfig.mealPlans}$planId');
    return MealPlan.fromJson(response as Map<String, dynamic>);
  }

  Future<void> updatePlanStatus(String planId, String status) async {
    await _client.put(
      '${ApiConfig.mealPlans}$planId/status',
      body: {'status': status},
    );
  }

  Future<MealPlan> swapRecipe(
    String planId,
    String entryId,
    String newRecipeId,
  ) async {
    final response = await _client.put(
      '${ApiConfig.mealPlans}$planId/entries/$entryId/swap',
      body: {'recipe_id': newRecipeId},
    );
    return MealPlan.fromJson(response as Map<String, dynamic>);
  }

  /// Zmienia sklep przypisany do planu — backend przelicza listę zakupów
  /// pod nowe ceny/działy automatycznie.
  Future<MealPlan> updateStore(String planId, String storeId) async {
    final response = await _client.put(
      '${ApiConfig.mealPlans}$planId/store',
      body: {'store_id': storeId},
    );
    return MealPlan.fromJson(response as Map<String, dynamic>);
  }

  Future<void> deletePlan(String planId) async {
    await _client.delete('${ApiConfig.mealPlans}$planId');
  }

  Future<WeeklyPlanAutomation> getWeeklyAutomation() async {
    final response = await _client.get('${ApiConfig.mealPlans}automation');
    return WeeklyPlanAutomation.fromJson(response as Map<String, dynamic>);
  }

  Future<WeeklyPlanAutomation> saveWeeklyAutomation({
    required bool enabled,
    required int weekday,
    required int hour,
    required bool createShoppingList,
  }) async {
    final response = await _client.put(
      '${ApiConfig.mealPlans}automation',
      body: {
        'enabled': enabled,
        'weekday': weekday,
        'hour': hour,
        'create_shopping_list': createShoppingList,
      },
    );
    return WeeklyPlanAutomation.fromJson(response as Map<String, dynamic>);
  }

  Future<WeeklyPlanAutomation> runWeeklyAutomationNow() async {
    final response = await _client.post(
      '${ApiConfig.mealPlans}automation/run-now',
      timeout: const Duration(minutes: 3),
    );
    return WeeklyPlanAutomation.fromJson(response as Map<String, dynamic>);
  }
}
