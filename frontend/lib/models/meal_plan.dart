import 'recipe.dart';

class MealPlanEntry {
  final String id;
  final String mealPlanId;
  final String recipeId;
  final Recipe recipe;
  final int dayNumber;
  final String mealSlot;
  final double servingsMultiplier;

  MealPlanEntry({
    required this.id,
    required this.mealPlanId,
    required this.recipeId,
    required this.recipe,
    required this.dayNumber,
    required this.mealSlot,
    required this.servingsMultiplier,
  });

  factory MealPlanEntry.fromJson(Map<String, dynamic> json) {
    return MealPlanEntry(
      id: json['id'] as String,
      mealPlanId: json['meal_plan_id'] as String? ?? '',
      recipeId: json['recipe_id'] as String? ?? '',
      recipe: Recipe.fromJson(json['recipe'] as Map<String, dynamic>),
      dayNumber: json['day_number'] as int? ?? 1,
      mealSlot: json['meal_slot'] as String? ?? json['meal_type'] as String? ?? 'obiad',
      servingsMultiplier: (json['servings_multiplier'] as num? ?? 1.0).toDouble(),
    );
  }
}

class MealPlan {
  final String id;
  final String userId;
  final String storeId;
  final String? startDate;
  final int durationDays;
  final int mealsPerDay;
  final String status; // 'draft', 'active', 'completed', 'archived'
  final double? estimatedMinBudget;
  final List<MealPlanEntry> entries;
  final DateTime createdAt;

  MealPlan({
    required this.id,
    required this.userId,
    required this.storeId,
    this.startDate,
    required this.durationDays,
    required this.mealsPerDay,
    required this.status,
    this.estimatedMinBudget,
    required this.entries,
    required this.createdAt,
  });

  factory MealPlan.fromJson(Map<String, dynamic> json) {
    return MealPlan(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      storeId: json['store_id'] as String,
      startDate: json['start_date'] as String?,
      durationDays: json['duration_days'] as int? ?? 3,
      mealsPerDay: json['meals_per_day'] as int? ?? 3,
      status: json['status'] as String? ?? 'draft',
      estimatedMinBudget: (json['estimated_min_budget'] as num?)?.toDouble(),
      entries: (json['entries'] as List<dynamic>?)
              ?.map((e) => MealPlanEntry.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  List<MealPlanEntry> entriesForDay(int day) {
    final list = entries.where((e) => e.dayNumber == day).toList();
    // Sortujemy posiłki według standardowego porządku dnia
    final order = {'śniadanie': 0, 'obiad': 1, 'kolacja': 2, 'przekąska': 3};
    list.sort((a, b) {
      final oa = order[a.mealSlot.toLowerCase()] ?? 99;
      final ob = order[b.mealSlot.toLowerCase()] ?? 99;
      return oa.compareTo(ob);
    });
    return list;
  }
}

class MealPlanGenerateRequest {
  final String storeId;
  final int durationDays;
  final int mealsPerDay;
  final double? maxBudget;
  final int? targetKcal;
  final int? householdSize;
  final Map<String, dynamic>? preferences;

  MealPlanGenerateRequest({
    required this.storeId,
    required this.durationDays,
    required this.mealsPerDay,
    this.maxBudget,
    this.targetKcal,
    this.householdSize,
    this.preferences,
  });

  Map<String, dynamic> toJson() => {
        'store_id': storeId,
        'duration_days': durationDays,
        'meals_per_day': mealsPerDay,
        'max_budget': maxBudget,
        'target_kcal': targetKcal,
        'household_size': householdSize,
        'preferences': preferences,
      };
}
