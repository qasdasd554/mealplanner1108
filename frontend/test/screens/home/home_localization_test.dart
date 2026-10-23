import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_meal_planner/l10n/app_localizations.dart';
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

class _Auth extends ChangeNotifier implements AuthProvider {
  _Auth(this.country);
  final String country;
  @override
  User get currentUser => User(
    id: 'user',
    email: 'test@example.invalid',
    displayName: 'Alex',
    householdSize: 1,
    countryCode: country,
    createdAt: DateTime(2026),
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Plans extends ChangeNotifier implements MealPlanProvider {
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
  List<Store> get stores => [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Logs extends ChangeNotifier implements FoodLogProvider {
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

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final gb in [false, true]) {
    testWidgets('home labels retain actions and layout for ${gb ? 'GB' : 'PL'}', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>(
              create: (_) => _Auth(gb ? 'GB' : 'PL'),
            ),
            ChangeNotifierProvider<MealPlanProvider>(create: (_) => _Plans()),
            ChangeNotifierProvider<FoodLogProvider>(create: (_) => _Logs()),
            ChangeNotifierProvider<StoreProvider>(create: (_) => _Stores()),
            ChangeNotifierProvider<WellnessProvider>(
              create: (_) => WellnessProvider(),
            ),
          ],
          child: MaterialApp(
            locale: gb ? const Locale('en', 'GB') : const Locale('pl', 'PL'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: const HomeTab(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(find.text(gb ? 'Hi, Alex!' : 'Cześć, Alex!'), findsOneWidget);
      expect(
        find.text(gb ? 'Food database' : 'Baza produktów'),
        findsOneWidget,
      );
      expect(find.text(gb ? 'Eaten today' : 'Dziś zjedzono'), findsOneWidget);
      final noPlan = find.text(
        gb ? 'No active meal plan' : 'Brak aktywnego planu posiłków',
      );
      await tester.ensureVisible(noPlan);
      await tester.pump();
      expect(noPlan.hitTestable(), findsOneWidget);
      expect(
        find.text(gb ? 'Create a new meal plan' : 'Stwórz nowy plan posiłków'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      // Dispose the existing notification polling timer before ending the test.
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
