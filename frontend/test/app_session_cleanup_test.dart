import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_meal_planner/app.dart';
import 'package:smart_meal_planner/models/user.dart';
import 'package:smart_meal_planner/providers/auth_provider.dart';
import 'package:smart_meal_planner/providers/theme_provider.dart';
import 'package:smart_meal_planner/providers/food_log_provider.dart';
import 'package:smart_meal_planner/providers/meal_plan_provider.dart';
import 'package:smart_meal_planner/providers/wellness_provider.dart';
import 'package:smart_meal_planner/providers/shopping_list_provider.dart';
import 'package:smart_meal_planner/providers/promotion_provider.dart';
import 'package:smart_meal_planner/providers/store_provider.dart';

class _Auth extends ChangeNotifier implements AuthProvider {
  bool authenticated = false;
  @override
  bool get isAuthenticated => authenticated;
  @override
  bool get isInitialized => true;
  @override
  bool get isLoading => false;
  @override
  String? get errorMessage => null;
  @override
  User? get currentUser => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  void setAuth(bool value) {
    authenticated = value;
    notifyListeners();
  }
}

class _Food extends FoodLogProvider {
  int clears = 0;
  @override
  void clear() {
    clears++;
    super.clear();
  }
}

class _Plans extends MealPlanProvider {
  int clears = 0;
  @override
  void clear() {
    clears++;
    super.clear();
  }
}

class _Wellness extends WellnessProvider {
  int clears = 0;
  @override
  void clear() {
    clears++;
    super.clear();
  }
}

class _Shopping extends ShoppingListProvider {
  int clears = 0;
  @override
  void clear() {
    clears++;
    super.clear();
  }
}

class _Promotions extends PromotionProvider {
  int clears = 0;
  @override
  void clear() {
    clears++;
    super.clear();
  }
}

class _Stores extends StoreProvider {
  int clears = 0;
  @override
  void clear() {
    clears++;
    super.clear();
  }
}

void main() {
  testWidgets(
    'any ended session clears account data and removes authenticated routes',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final auth = _Auth();
      final food = _Food();
      final plans = _Plans();
      final wellness = _Wellness();
      final shopping = _Shopping();
      final promotions = _Promotions();
      final stores = _Stores();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: auth),
            ChangeNotifierProvider<FoodLogProvider>.value(value: food),
            ChangeNotifierProvider<MealPlanProvider>.value(value: plans),
            ChangeNotifierProvider<WellnessProvider>.value(value: wellness),
            ChangeNotifierProvider<ShoppingListProvider>.value(value: shopping),
            ChangeNotifierProvider<PromotionProvider>.value(value: promotions),
            ChangeNotifierProvider<StoreProvider>.value(value: stores),
            ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ],
          child: SmartMealPlannerApp(
            testRoutes: {
              '/': (_) => const Scaffold(body: Text('Start')),
              '/login': (_) => const Scaffold(body: Text('Login')),
            },
          ),
        ),
      );
      await tester.pump();
      final navigator = SmartMealPlannerApp.navigatorKey.currentState!;
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Private route')),
        ),
      );
      await tester.pump();
      auth.setAuth(true);
      auth.setAuth(false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pumpAndSettle();
      expect([
        food.clears,
        plans.clears,
        wellness.clears,
        shopping.clears,
        promotions.clears,
        stores.clears,
      ], everyElement(1));
      expect(navigator.canPop(), isFalse);
      expect(find.text('Private route'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      for (final provider in [
        auth,
        food,
        plans,
        wellness,
        shopping,
        promotions,
        stores,
      ]) {
        provider.dispose();
      }
    },
  );
}
