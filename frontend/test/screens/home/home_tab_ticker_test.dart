import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_meal_planner/l10n/app_localizations.dart';
import 'package:smart_meal_planner/services/wellness_service.dart';
import 'package:smart_meal_planner/models/food_log.dart';
import 'package:smart_meal_planner/models/meal_plan.dart';
import 'package:smart_meal_planner/models/store.dart';
import 'package:smart_meal_planner/models/user.dart';
import 'package:smart_meal_planner/providers/auth_provider.dart';
import 'package:smart_meal_planner/providers/food_log_provider.dart';
import 'package:smart_meal_planner/providers/meal_plan_provider.dart';
import 'package:smart_meal_planner/providers/store_provider.dart';
import 'package:smart_meal_planner/providers/wellness_provider.dart';
import 'package:smart_meal_planner/screens/home/home_screen.dart';
import 'package:smart_meal_planner/screens/recipes/recipes_screen.dart';

class _Auth extends ChangeNotifier implements AuthProvider {
  @override
  User get currentUser => User(
    id: 'synthetic-user',
    email: 'synthetic@example.invalid',
    householdSize: 1,
    countryCode: 'GB',
    createdAt: DateTime(2026),
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Plans extends ChangeNotifier implements MealPlanProvider {
  @override
  Future<void> loadPlans() async {}
  @override
  bool get hasLoaded => true;
  @override
  bool get isLoading => false;
  @override
  String? get errorMessage => null;
  @override
  List<MealPlan> get plans => [];
  @override
  MealPlan? get currentPlan => null;
  @override
  MealPlan? get activePlan => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Stores extends ChangeNotifier implements StoreProvider {
  @override
  Future<void> loadStores() async {}
  @override
  List<Store> get stores => [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Logs extends ChangeNotifier implements FoodLogProvider {
  @override
  Future<void> fetchLogsForDate(DateTime date) async {}
  @override
  bool get isLoading => false;
  @override
  String? get error => null;
  @override
  DailySummary get summary => DailySummary(
    date: DateTime.now(),
    totalCalories: 400,
    totalProtein: 20,
    totalCarbs: 40,
    totalFat: 10,
    targetCalories: 2000,
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Wellness extends ChangeNotifier implements WellnessProvider {
  @override
  Future<void> loadForDate(DateTime date) async {}
  @override
  bool get isLoading => false;
  @override
  bool get hasLoaded => true;
  @override
  DailyWellness get data => DailyWellness.empty();
  @override
  String? get errorMessage => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('hidden recipe animation stops ticking and tab state survives', (
    tester,
  ) async {
    // The test binding blocks all HTTP, so real tab widgets use no account or
    // backend data. Failed recipe requests are handled by the screen itself.
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>(create: (_) => _Auth()),
          ChangeNotifierProvider<MealPlanProvider>(create: (_) => _Plans()),
          ChangeNotifierProvider<StoreProvider>(create: (_) => _Stores()),
          ChangeNotifierProvider<FoodLogProvider>(create: (_) => _Logs()),
          ChangeNotifierProvider<WellnessProvider>(create: (_) => _Wellness()),
        ],
        child: const MaterialApp(
          locale: Locale('en', 'GB'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: HomeScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    final navigation = find.byType(BottomNavigationBar);
    await tester.tap(
      find.descendant(of: navigation, matching: find.text('Recipes')),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    final recipeState = tester.state(find.byType(RecipesScreen));
    expect(tester.binding.transientCallbackCount, greaterThan(0));

    await tester.enterText(find.byType(TextField), 'synthetic oats');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    await tester.tap(
      find.descendant(of: navigation, matching: find.text('Home')),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 5),
    );

    expect(
      tester.binding.transientCallbackCount,
      0,
      reason: 'The hidden trophy must not keep scheduling frames.',
    );
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(
      tester.state(find.byType(RecipesScreen, skipOffstage: false)),
      same(recipeState),
    );

    await tester.tap(
      find.descendant(of: navigation, matching: find.text('Recipes')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.state(find.byType(RecipesScreen)), same(recipeState));
    expect(find.text('synthetic oats'), findsOneWidget);
    expect(
      tester.binding.transientCallbackCount,
      greaterThan(0),
      reason: 'The visible trophy should resume its existing animation.',
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
