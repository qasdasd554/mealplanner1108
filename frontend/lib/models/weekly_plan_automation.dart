class WeeklyPlanAutomation {
  final bool enabled;
  final int weekday;
  final int hour;
  final bool createShoppingList;
  final DateTime? lastSuccessAt;
  final String? lastError;
  final String? lastPlanId;

  const WeeklyPlanAutomation({
    required this.enabled,
    required this.weekday,
    required this.hour,
    required this.createShoppingList,
    this.lastSuccessAt,
    this.lastError,
    this.lastPlanId,
  });

  factory WeeklyPlanAutomation.fromJson(Map<String, dynamic> json) {
    return WeeklyPlanAutomation(
      enabled: json['enabled'] as bool? ?? false,
      weekday: json['weekday'] as int? ?? 6,
      hour: json['hour'] as int? ?? 18,
      createShoppingList: json['create_shopping_list'] as bool? ?? true,
      lastSuccessAt:
          json['last_success_at'] == null
              ? null
              : DateTime.tryParse(json['last_success_at'] as String),
      lastError: json['last_error'] as String?,
      lastPlanId: json['last_plan_id'] as String?,
    );
  }
}
