import '../models/user.dart';

int householdSizeForPlan(int? value) => (value ?? 1).clamp(1, 8);

int calorieGoalForPlan(User? user) =>
    (user?.dailyKcalGoal ?? 0) > 0 ? user!.dailyKcalGoal! : 2000;
