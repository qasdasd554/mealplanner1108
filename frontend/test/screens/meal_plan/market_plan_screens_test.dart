import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:smart_meal_planner/l10n/app_localizations.dart';
import 'package:smart_meal_planner/l10n/market_locale.dart';
import 'package:smart_meal_planner/models/meal_plan.dart';
import 'package:smart_meal_planner/models/recipe.dart';
import 'package:smart_meal_planner/models/store.dart';
import 'package:smart_meal_planner/models/user.dart';
import 'package:smart_meal_planner/providers/auth_provider.dart';
import 'package:smart_meal_planner/providers/meal_plan_provider.dart';
import 'package:smart_meal_planner/providers/store_provider.dart';
import 'package:smart_meal_planner/screens/meal_plan/plan_config_screen.dart';
import 'package:smart_meal_planner/screens/meal_plan/plan_view_screen.dart';
import 'package:smart_meal_planner/services/recipe_service.dart';

Store _store(String country, {String? currency}) => Store(
  id: '$country-shop',
  name: country == 'GB' ? 'Tesco' : 'Biedronka',
  countryCode: country,
  currencyCode: currency ?? (country == 'GB' ? 'GBP' : 'PLN'),
  createdAt: DateTime(2026),
  updatedAt: null,
);

User _user(String country, {int household = 1, int? kcal}) => User(
  id: 'account',
  email: 'example@example.invalid',
  countryCode: country,
  householdSize: household,
  dailyKcalGoal: kcal,
  isPremium: true,
  dietaryPreferences: const {'diet': 'Bez ograniczeń'},
  createdAt: DateTime(2026),
);

MealPlan _plan({
  String country = 'GB',
  String status = 'draft',
  bool expired = false,
  List<MealPlanEntry> entries = const [],
}) => MealPlan(
  id: 'plan',
  userId: 'account',
  storeId: '$country-shop',
  durationDays: 5,
  mealsPerDay: 3,
  status: status,
  endDate: expired ? '2020-01-01' : null,
  estimatedMinBudget: 12.3,
  entries: entries,
  createdAt: DateTime(2026),
);

class _Auth extends ChangeNotifier implements AuthProvider {
  _Auth(this.user);
  User user;
  @override
  User get currentUser => user;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Stores extends ChangeNotifier implements StoreProvider {
  _Stores(this.data);
  final List<Store> data;
  Store? selected;
  @override
  List<Store> get stores => data;
  @override
  Store? get selectedStore => selected;
  @override
  bool get isLoading => false;
  @override
  void selectStoreById(String id) {
    selected = data.where((store) => store.id == id).firstOrNull;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Plans extends ChangeNotifier implements MealPlanProvider {
  MealPlan? plan;
  MealPlanGenerateRequest? sent;
  bool generating = false;
  bool succeed = true;
  String? error;
  String? swappedRecipe;
  int deletions = 0;
  @override
  MealPlan? get currentPlan => plan;
  @override
  bool get isLoading => false;
  @override
  bool get isGenerating => generating;
  @override
  String? get errorMessage => error;
  @override
  Future<bool> generatePlan(MealPlanGenerateRequest request) async {
    sent = request;
    if (succeed) {
      plan = _plan(country: request.storeId.split('-').first);
    }
    return succeed;
  }

  @override
  Future<bool> swapRecipe({
    required String planId,
    required String entryId,
    required String newRecipeId,
  }) async {
    swappedRecipe = newRecipeId;
    return true;
  }

  @override
  Future<bool> deletePlan(String planId) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    deletions++;
    return false;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Recipes extends RecipeService {
  int calls = 0;
  String? requestedType;

  @override
  Future<List<Recipe>> getRecipes({
    String? mealType,
    String? cuisine,
    String? difficulty,
    String? tag,
    String? search,
    bool favoritesOnly = false,
    bool newOnly = false,
    bool communityOnly = false,
    String? sortBy,
    int limit = 200,
    int skip = 0,
  }) async {
    calls++;
    requestedType = mealType;
    return [
      Recipe.fromJson({
        'id': 'replacement',
        'name': 'Rice',
        'meal_type': 'obiad',
        'difficulty': 'łatwy',
        'prep_time_min': 10,
      }),
    ];
  }
}

Widget _app(
  Widget child, {
  required User user,
  required _Plans plans,
  List<Store>? stores,
  Locale? deviceLocale,
  double textScale = 1,
}) => MultiProvider(
  providers: [
    ChangeNotifierProvider<AuthProvider>.value(value: _Auth(user)),
    ChangeNotifierProvider<MealPlanProvider>.value(value: plans),
    ChangeNotifierProvider<StoreProvider>.value(
      value: _Stores(stores ?? [_store('PL'), _store('GB')]),
    ),
  ],
  child: MaterialApp(
    locale: localeForMarket(
      accountCountry: user.countryCode,
      deviceRegion: deviceLocale?.countryCode,
    ),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    builder:
        (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
    home: child,
  ),
);

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  for (final country in ['PL', 'GB']) {
    testWidgets('plan config $country retains defaults and local shops', (
      tester,
    ) async {
      final plans = _Plans();
      await tester.pumpWidget(
        _app(
          const PlanConfigScreen(),
          user: _user(country, household: 10),
          plans: plans,
          deviceLocale: Locale('en', country == 'GB' ? 'PL' : 'GB'),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(country == 'GB' ? 'Tesco' : 'Biedronka'),
        findsOneWidget,
      );
      expect(find.text(country == 'GB' ? 'Biedronka' : 'Tesco'), findsNothing);
      final kcal = tester.widget<TextField>(find.byType(TextField).first);
      expect(kcal.controller!.text, '2000');
      final peopleSlider = tester.widgetList<Slider>(find.byType(Slider)).last;
      expect(peopleSlider.value, 8);
      expect(peopleSlider.max, 8);
      final add = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.add_circle_outline),
      );
      expect(add.onPressed, isNull);
      expect(
        tester
            .widget<TextField>(find.byType(TextField).last)
            .decoration!
            .suffixText,
        country == 'GB' ? 'GBP' : 'PLN',
      );
      expect(plans.sent, isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('plan config $country sends canonical selections and budget', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final plans = _Plans();
      await tester.pumpWidget(
        _app(
          const PlanConfigScreen(),
          user: _user(country, household: 2, kcal: 2300),
          plans: plans,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        '2300',
      );
      await _tapVisible(
        tester,
        find.text(country == 'GB' ? 'Tesco' : 'Biedronka'),
      );
      await _tapVisible(
        tester,
        find.widgetWithText(ChoiceChip, country == 'GB' ? 'Vegan' : 'Wegańska'),
      );
      await _tapVisible(
        tester,
        find.widgetWithText(
          FilterChip,
          country == 'GB' ? 'breakfast' : 'śniadanie',
        ),
      );
      await tester.ensureVisible(find.byType(TextField).last);
      await tester.enterText(find.byType(TextField).last, '25.50');
      tester.testTextInput.hide();
      await _tapVisible(
        tester,
        find.text(country == 'GB' ? 'Include pantry' : 'Uwzględnij spiżarnię'),
      );
      await _tapVisible(
        tester,
        find.text(country == 'GB' ? 'Generate plan!' : 'Wygeneruj plan!'),
      );
      final request = plans.sent!;
      expect(request.storeId, '$country-shop');
      expect(request.householdSize, 2);
      expect(request.targetKcal, 2300);
      expect(request.maxBudget, 25.5);
      expect(request.includePantry, isFalse);
      expect(request.preferences!['diet'], 'Wegańska');
      expect(
        request.preferences!['meal_types'],
        unorderedEquals(['obiad', 'kolacja']),
      );
      expect(request.mealsPerDay, 2);
      expect(
        find.text(country == 'GB' ? '£12.30' : '12.30 zł'),
        findsOneWidget,
      );
      expect(
        find.text(
          country == 'GB'
              ? 'Estimated minimum shopping cost'
              : 'Szacowany minimalny koszt zakupów',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'config rejects a malformed foreign-currency shop in same country',
    (tester) async {
      await tester.pumpWidget(
        _app(
          const PlanConfigScreen(),
          user: _user('GB'),
          plans: _Plans(),
          stores: [_store('GB', currency: 'PLN')],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Tesco'), findsNothing);
      await _tapVisible(tester, find.text('Generate plan!'));
      expect(
        find.text('Choose a shop before generating your plan!'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('config localizes calorie validation and does not submit', (
    tester,
  ) async {
    final plans = _Plans();
    await tester.pumpWidget(
      _app(const PlanConfigScreen(), user: _user('GB'), plans: plans),
    );
    await tester.pumpAndSettle();
    await _tapVisible(tester, find.text('Tesco'));
    await tester.ensureVisible(find.byType(TextField).first);
    await tester.enterText(find.byType(TextField).first, '799');
    tester.testTextInput.hide();
    await _tapVisible(tester, find.text('Generate plan!'));
    expect(plans.sent, isNull);
    expect(
      find.text('Enter between 800 and 6000 kcal per person per day.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'swap translates display without changing category or refetching',
    (tester) async {
      final recipe = Recipe.fromJson({
        'id': 'original',
        'name': 'Pasta',
        'meal_type': 'obiad',
      });
      final entry = MealPlanEntry(
        id: 'entry',
        mealPlanId: 'plan',
        recipeId: recipe.id,
        recipe: recipe,
        dayNumber: 1,
        mealSlot: 'obiad',
        servingsMultiplier: 1,
      );
      final plans = _Plans()..plan = _plan(entries: [entry]);
      final recipes = _Recipes();
      await tester.pumpWidget(
        _app(
          PlanViewScreen(recipeService: recipes),
          user: _user('GB'),
          plans: plans,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.swap_horiz));
      await tester.pumpAndSettle();
      expect(recipes.requestedType, 'obiad');
      expect(recipes.calls, 1);
      expect(find.text('Replace: Pasta'), findsOneWidget);
      expect(find.text('10 min • easy'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'does not exist');
      await tester.pump();
      expect(find.text('No dishes found with this name'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Rice');
      await tester.pump();
      expect(find.widgetWithText(ListTile, 'Rice'), findsOneWidget);
      expect(recipes.calls, 1);
      tester.testTextInput.hide();
      await tester.tap(find.widgetWithText(ListTile, 'Rice'));
      await tester.pumpAndSettle();
      expect(plans.swappedRecipe, 'replacement');
      expect(find.text('Recipe replaced'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final country in ['PL', 'GB']) {
    testWidgets(
      'plan view $country translates canonical slots and navigation',
      (tester) async {
        final recipe = Recipe.fromJson({
          'id': 'recipe',
          'name': 'Pasta',
          'meal_type': 'obiad',
          'servings': 2,
          'nutrition_total': {
            'kcal': 800,
            'protein': 40,
            'fat': 20,
            'carbs': 100,
          },
        });
        final entry = MealPlanEntry(
          id: 'entry',
          mealPlanId: 'plan',
          recipeId: recipe.id,
          recipe: recipe,
          dayNumber: 1,
          mealSlot: 'obiad',
          servingsMultiplier: 1,
        );
        final plans =
            _Plans()..plan = _plan(country: country, entries: [entry]);
        await tester.pumpWidget(
          _app(const PlanViewScreen(), user: _user(country), plans: plans),
        );
        await tester.pumpAndSettle();
        expect(
          find.text(country == 'GB' ? 'Meal plan' : 'Plan posiłków'),
          findsOneWidget,
        );
        expect(find.text(country == 'GB' ? 'LUNCH' : 'OBIAD'), findsOneWidget);
        expect(find.text('400'), findsOneWidget);
        expect(
          find.text(country == 'GB' ? 'Day 1' : 'Dzień 1'),
          findsOneWidget,
        );
        expect(
          find.text(country == 'GB' ? 'Confirm plan' : 'Zatwierdź plan'),
          findsOneWidget,
        );
        expect(entry.mealSlot, 'obiad');
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('plan view $country empty and expired states are localized', (
      tester,
    ) async {
      final plans = _Plans();
      await tester.pumpWidget(
        _app(const PlanViewScreen(), user: _user(country), plans: plans),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(
          country == 'GB'
              ? 'No meal plan found. Generate a new plan.'
              : 'Nie znaleziono planu posiłków. Wygeneruj nowy plan.',
        ),
        findsOneWidget,
      );
      plans.plan = _plan(country: country, expired: true);
      plans.notifyListeners();
      await tester.pumpAndSettle();
      expect(
        find.text(
          country == 'GB'
              ? 'This plan has finished.'
              : 'Ten plan już się zakończył.',
        ),
        findsOneWidget,
      );
      expect(
        find.text(country == 'GB' ? 'Open archive' : 'Otwórz archiwum'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('failed delete keeps plan visible and reports translated error', (
    tester,
  ) async {
    final plans = _Plans()..plan = _plan();
    await tester.pumpWidget(
      _app(const PlanViewScreen(), user: _user('GB'), plans: plans),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(plans.deletions, 1);
    expect(find.text('Meal plan'), findsOneWidget);
    expect(find.text('Could not delete the plan'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final country in ['PL', 'GB']) {
    testWidgets('plan view $country fits 320 px at 150% text', (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final plans = _Plans()..plan = _plan(country: country);
      await tester.pumpWidget(
        _app(
          const PlanViewScreen(),
          user: _user(country),
          plans: plans,
          textScale: 1.5,
        ),
      );
      await tester.pumpAndSettle();
      await tester.pump();
    });
  }
}
