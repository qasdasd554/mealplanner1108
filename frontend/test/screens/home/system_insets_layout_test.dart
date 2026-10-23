import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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
import 'package:smart_meal_planner/screens/recipes/manual_add_recipe_screen.dart';
import 'package:smart_meal_planner/services/wellness_service.dart';

// Same completed synthetic provider states as the Home localization/ticker
// fixtures. No account, storage, native activity, or backend is exercised.
class _Auth extends ChangeNotifier implements AuthProvider {
  @override
  User get currentUser => User(
    id: 'synthetic-user',
    email: 'synthetic@example.invalid',
    displayName: 'Alex',
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

Widget _app(Widget home) => MaterialApp(
  locale: const Locale('en', 'GB'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  home: home,
);

void _setInsets(WidgetTester tester, double bottom, {bool keyboard = false}) {
  tester.view.viewPadding = FakeViewPadding(top: 44, bottom: bottom);
  tester.view.padding = FakeViewPadding(top: 44, bottom: keyboard ? 0 : bottom);
  tester.view.viewInsets = FakeViewPadding(bottom: keyboard ? 300 : 0);
}

void _expectUsable(WidgetTester tester, Finder finder, double bottom) {
  expect(finder.hitTestable(), findsOneWidget);
  final rect = tester.getRect(finder);
  expect(rect.top, greaterThanOrEqualTo(44));
  expect(rect.bottom, lessThanOrEqualTo(bottom));
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  for (final bottom in [24.0, 48.0]) {
    testWidgets('Home controls avoid cutout and bottom inset $bottom', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      _setInsets(tester, bottom);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>(create: (_) => _Auth()),
            ChangeNotifierProvider<MealPlanProvider>(create: (_) => _Plans()),
            ChangeNotifierProvider<StoreProvider>(create: (_) => _Stores()),
            ChangeNotifierProvider<FoodLogProvider>(create: (_) => _Logs()),
            ChangeNotifierProvider<WellnessProvider>(
              create: (_) => _Wellness(),
            ),
          ],
          child: _app(const HomeScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      _expectUsable(tester, find.text('Hi, Alex!'), 844 - bottom);
      final nav = find.byType(BottomNavigationBar);
      for (final item in tester.widget<BottomNavigationBar>(nav).items) {
        _expectUsable(
          tester,
          find.descendant(of: nav, matching: find.text(item.label!)),
          844 - bottom,
        );
      }
      _expectUsable(
        tester,
        find.widgetWithText(OutlinedButton, 'Add'),
        844 - bottom,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('Manual recipe survives keyboard and keeps Save usable $bottom', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      _setInsets(tester, bottom);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_app(const ManualAddRecipeScreen()));
      await tester.pumpAndSettle();
      final name = find.widgetWithText(TextFormField, 'Recipe name');
      _expectUsable(tester, name, 844 - bottom);
      await tester.enterText(name, 'Synthetic family lasagne');

      _setInsets(tester, bottom, keyboard: true);
      await tester.pumpAndSettle();
      expect(find.text('Synthetic family lasagne'), findsOneWidget);
      _expectUsable(tester, name, 844 - 300);
      expect(
        tester
            .widget<EditableText>(
              find.descendant(of: name, matching: find.byType(EditableText)),
            )
            .focusNode
            .hasFocus,
        isTrue,
      );

      final save = find.widgetWithText(ElevatedButton, 'Save recipe');
      final scrollable =
          find
              .descendant(
                of: find.byType(ListView),
                matching: find.byType(Scrollable),
              )
              .first;
      await tester.scrollUntilVisible(save, 200, scrollable: scrollable);
      await tester.pumpAndSettle();
      _expectUsable(tester, save, 844 - 300);
      await tester.tap(save);
      await tester.pump();
      // A named recipe without ingredients is rejected locally, proving that
      // the visible Save hit target invokes the real handler without a request.
      expect(find.byType(SnackBar), findsOneWidget);

      _setInsets(tester, bottom);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(name, -200, scrollable: scrollable);
      await tester.pumpAndSettle();
      expect(find.text('Synthetic family lasagne'), findsOneWidget);
      _expectUsable(tester, name, 844 - bottom);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
