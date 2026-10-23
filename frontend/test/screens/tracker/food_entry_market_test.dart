import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:smart_meal_planner/l10n/app_localizations.dart';
import 'package:smart_meal_planner/models/recipe.dart';
import 'package:smart_meal_planner/models/barcode_lookup_result.dart';
import 'package:smart_meal_planner/providers/food_log_provider.dart';
import 'package:smart_meal_planner/providers/meal_plan_provider.dart';
import 'package:smart_meal_planner/screens/tracker/add_food_entry_screen.dart';
import 'package:smart_meal_planner/services/api_client.dart';
import 'package:smart_meal_planner/services/recipe_service.dart';
import 'package:smart_meal_planner/widgets/pick_product_from_catalog_sheet.dart';
import 'package:smart_meal_planner/widgets/product_name_autocomplete_field.dart';

class _Logs extends FoodLogProvider {
  final saves = <Map<String, dynamic>>[];
  @override
  Future<void> fetchRecentEntries() async {}
  @override
  Future<bool> addManualEntry({
    required String mealType,
    required String foodName,
    required double calories,
    required double protein,
    required double carbs,
    required double fat,
    double? amountValue,
    String? amountUnit,
    double? portionSize,
    String? portionUnit,
  }) async {
    saves.add({
      'meal': mealType,
      'name': foodName,
      'kcal': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'amount': amountValue,
      'unit': amountUnit,
      'portion': portionSize,
      'portionUnit': portionUnit,
    });
    return false;
  }
}

class _Plans extends MealPlanProvider {
  @override
  Future<void> loadPlans() async {}
}

Recipe _recipe(String id) => Recipe.fromJson({
  'id': id,
  'name': id,
  'meal_type': 'obiad',
  'servings': 2,
  'difficulty': 'łatwy',
  'nutrition_total': {'kcal': 400},
  'ingredients': [],
  'instructions': [],
});

class _Recipes extends RecipeService {
  final pending = <String, Completer<List<Recipe>>>{};
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
  }) async => pending[search]?.future ?? [];
}

class _Client extends ApiClient {
  final bool missing;
  _Client({this.missing = false}) : super.forTesting(httpClient: http.Client());
  @override
  Future<dynamic> get(String path, {Duration? timeout}) async =>
      missing
          ? [
            {
              'id': 'food',
              'name': 'Food without nutrients',
              'unit': 'g',
              'default_quantity': 100,
              'nutrition_per_100': <String, dynamic>{},
            },
          ]
          : [];
}

Future<_Logs> _open(
  WidgetTester tester, {
  bool manual = false,
  Locale locale = const Locale('en', 'GB'),
  _Recipes? recipes,
  bool picker = false,
}) async {
  final logs = _Logs(), plans = _Plans();
  addTearDown(logs.dispose);
  addTearDown(plans.dispose);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<FoodLogProvider>.value(value: logs),
        ChangeNotifierProvider<MealPlanProvider>.value(value: plans),
      ],
      child: MaterialApp(
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home:
            manual
                ? const Scaffold(
                  body: SingleChildScrollView(child: ManualEntryForm()),
                )
                : picker
                ? Scaffold(
                  body: PickProductFromCatalogSheet(
                    embedded: true,
                    client: _Client(missing: true),
                  ),
                )
                : AddFoodEntryScreen(
                  recipeService: recipes ?? _Recipes(),
                  productClient: _Client(),
                ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return logs;
}

void main() {
  for (final english in [false, true]) {
    testWidgets(
      'missing recipe nutrition is labelled and cannot be logged as zero, en=$english',
      (tester) async {
        final recipes = _Recipes();
        final pending = Completer<List<Recipe>>();
        recipes.pending['unknown'] = pending;
        final logs = await _open(
          tester,
          recipes: recipes,
          locale: english ? const Locale('en', 'GB') : const Locale('pl', 'PL'),
        );
        await tester.tap(find.text(english ? 'From recipes' : 'Z przepisów'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).first, 'unknown');
        await tester.pump(const Duration(milliseconds: 400));
        pending.complete([
          Recipe.fromJson({
            'id': 'unknown',
            'name': 'Unknown recipe',
            'meal_type': 'obiad',
            'nutrition_total': {
              'kcal': null,
              '_incomplete': true,
              '_missing_ingredients': ['Ingredient'],
            },
          }),
        ]);
        await tester.pumpAndSettle();
        expect(
          find.text(
            english ? 'Nutrition unavailable' : 'Brak danych odżywczych',
          ),
          findsOneWidget,
        );
        await tester.tap(find.text('Unknown recipe'));
        await tester.pumpAndSettle();
        expect(
          find.textContaining(
            english ? 'Complete the ingredient' : 'Uzupełnij składniki',
          ),
          findsOneWidget,
        );
        expect(logs.saves, isEmpty);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  testWidgets('GB entry tabs and no-plan guidance are English', (tester) async {
    await _open(tester);
    expect(find.text('Add a meal'), findsOneWidget);
    expect(find.text('From plan'), findsOneWidget);
    expect(find.text('From recipes'), findsOneWidget);
    expect(find.text('Products'), findsOneWidget);
    expect(find.textContaining('active meal plan'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('PL entry labels remain unchanged', (tester) async {
    await _open(tester, locale: const Locale('pl', 'PL'));
    expect(find.text('Dodaj posiłek'), findsOneWidget);
    expect(find.text('Z planu'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('late recipe search cannot replace newer results', (
    tester,
  ) async {
    final recipes = _Recipes();
    await _open(tester, recipes: recipes, locale: const Locale('pl', 'PL'));
    await tester.tap(find.text('Z przepisów'));
    await tester.pumpAndSettle();
    recipes.pending['old'] = Completer();
    recipes.pending['new'] = Completer();
    final input = find.byType(TextField).first;
    await tester.enterText(input, 'old');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(input, 'new');
    await tester.pump(const Duration(milliseconds: 400));
    recipes.pending['new']!.complete([_recipe('New recipe')]);
    await tester.pumpAndSettle();
    expect(find.text('New recipe'), findsOneWidget);
    recipes.pending['old']!.complete([_recipe('Old recipe')]);
    await tester.pumpAndSettle();
    expect(find.text('New recipe'), findsOneWidget);
    expect(find.text('Old recipe'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  for (final value in ['NaN', 'Infinity', '-1', '1e999']) {
    testWidgets('manual nutrition rejects $value and preserves input', (
      tester,
    ) async {
      final logs = await _open(
        tester,
        manual: true,
        locale: const Locale('pl', 'PL'),
      );
      await tester.enterText(find.byType(TextFormField).at(0), 'X');
      await tester.enterText(find.byType(TextFormField).at(2), value);
      await tester.ensureVisible(find.text('Zapisz do dziennika'));
      await tester.tap(find.text('Zapisz do dziennika'));
      await tester.pumpAndSettle();
      expect(logs.saves, isEmpty);
      expect(find.text('X'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('Polish decimal comma is not silently saved as zero', (
    tester,
  ) async {
    final logs = await _open(
      tester,
      manual: true,
      locale: const Locale('pl', 'PL'),
    );
    await tester.enterText(find.byType(TextFormField).at(0), 'X');
    await tester.enterText(find.byType(TextFormField).at(2), '12,5');
    await tester.ensureVisible(find.text('Zapisz do dziennika'));
    await tester.tap(find.text('Zapisz do dziennika'));
    await tester.pumpAndSettle();
    expect(logs.saves.single['kcal'], 12.5);
    expect(logs.saves.single['meal'], 'Przekąska');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('catalogue picker never renders missing nutrition as zero', (
    tester,
  ) async {
    await _open(tester, picker: true);
    expect(find.textContaining('— kcal'), findsOneWidget);
    expect(find.textContaining('0 kcal'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'manual milk amount is saved as ml with metadata and input retained after failure',
    (tester) async {
      final logs = await _open(tester, manual: true);
      tester
          .widget<ProductNameAutocompleteField>(
            find.byType(ProductNameAutocompleteField),
          )
          .onSelected(
            const BarcodeLookupResult(
              found: true,
              name: 'Milk',
              unit: 'ml',
              kcalPer100: 50,
              proteinPer100: 3,
              fatPer100: 2,
              carbsPer100: 5,
            ),
          );
      await tester.pump();
      await tester.enterText(find.byType(TextFormField).at(1), '250');
      await tester.enterText(find.byType(TextFormField).at(2), '125');
      await tester.ensureVisible(find.text('Save to diary'));
      await tester.tap(find.text('Save to diary'));
      await tester.pumpAndSettle();
      expect(logs.saves.single['name'], 'Milk');
      expect(logs.saves.single['amount'], 250);
      expect(logs.saves.single['unit'], 'ml');
      expect(logs.saves.single['portion'], 1);
      expect(logs.saves.single['kcal'], 125);
      expect(find.text('Milk'), findsOneWidget);
      expect(find.text('Could not add the entry'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'missing suggested nutrition cannot inherit values of a different product',
    (tester) async {
      final logs = await _open(tester, manual: true);
      final field = tester.widget<ProductNameAutocompleteField>(
        find.byType(ProductNameAutocompleteField),
      );
      field.onSelected(
        const BarcodeLookupResult(
          found: true,
          name: 'Known food',
          kcalPer100: 400,
          proteinPer100: 20,
        ),
      );
      await tester.pump();
      field.onSelected(
        const BarcodeLookupResult(found: true, name: 'Unknown food'),
      );
      await tester.pump();
      await tester.ensureVisible(find.text('Save to diary'));
      await tester.tap(find.text('Save to diary'));
      await tester.pumpAndSettle();
      expect(logs.saves, isEmpty);
      expect(find.text('400'), findsNothing);
      expect(find.text('Unknown food'), findsOneWidget);
      expect(find.text('Required'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
