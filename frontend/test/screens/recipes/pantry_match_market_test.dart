import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:smart_meal_planner/l10n/app_localizations.dart';
import '../../helpers/product_form_render.dart';
import 'package:smart_meal_planner/theme/app_theme.dart';
import 'package:smart_meal_planner/models/product.dart';
import 'package:smart_meal_planner/models/recipe.dart';
import 'package:smart_meal_planner/models/user.dart';
import 'package:smart_meal_planner/providers/auth_provider.dart';
import 'package:smart_meal_planner/providers/shopping_list_provider.dart';
import 'package:smart_meal_planner/screens/recipes/ingredient_match_select_screen.dart';
import 'package:smart_meal_planner/screens/recipes/ingredient_match_results_screen.dart';
import 'package:smart_meal_planner/screens/recipes/pantry_screen.dart';
import 'package:smart_meal_planner/services/api_client.dart';
import 'package:smart_meal_planner/services/pantry_service.dart';
import 'package:smart_meal_planner/services/product_search_service.dart';
import 'package:smart_meal_planner/services/recipe_service.dart';

Product _product(String id, {String unit = 'g'}) => Product(
  id: id,
  name: id,
  unit: unit,
  defaultQuantity: 500,
  servingQuantity: 500,
  nutritionPer100: NutritionInfo(
    kcal: 100,
    protein: 5,
    fat: 4,
    carbs: 11,
    fiber: 2,
  ),
);

class _Auth extends AuthProvider {
  final User user;
  _Auth(bool english, bool premium)
    : user = User(
        id: 'user',
        email: 'synthetic@example.test',
        countryCode: english ? 'GB' : 'PL',
        householdSize: 1,
        createdAt: DateTime.now(),
        isPremium: premium,
      ),
      super(readToken: () async => null);
  @override
  User get currentUser => user;
}

class _Pantry extends PantryService {
  List<PantryItem> items;
  bool fail = false;
  Completer<List<PantryItem>>? pendingLoad;
  final deletes = <String>[];
  final pendingDeletes = <String, Completer<void>>{};
  final updates = <(String, double?, String?)>[];
  final additions = <(List<String>, double?, String?)>[];
  _Pantry(this.items);
  @override
  Future<List<PantryItem>> addItems(
    List<String> productIds, {
    double? quantity,
    String? unit,
  }) async {
    additions.add((productIds, quantity, unit));
    final added = [
      for (final id in productIds)
        PantryItem(
          id: 'saved-$id',
          product: _product(id),
          quantity: quantity,
          unit: unit,
        ),
    ];
    items.addAll(added);
    return added;
  }

  @override
  Future<List<PantryItem>> getPantry() async {
    if (fail) throw ApiException(503, 'Synthetic service failure');
    if (pendingLoad != null) return pendingLoad!.future;
    return List.of(items);
  }

  @override
  Future<void> deleteItem(String id) async {
    deletes.add(id);
    if (pendingDeletes[id] != null) await pendingDeletes[id]!.future;
    items.removeWhere((item) => item.id == id);
  }

  @override
  Future<PantryItem> updateQuantity(
    String id, {
    double? quantity,
    String? unit,
  }) async {
    updates.add((id, quantity, unit));
    return PantryItem(
      id: id,
      product: items.firstWhere((item) => item.id == id).product,
      quantity: quantity,
      unit: unit,
    );
  }
}

class _Shopping extends ShoppingListProvider {
  int refreshes = 0;
  @override
  Future<void> loadAllLists({String? preferredListId}) async {
    refreshes++;
  }
}

class _Recipes extends RecipeService {
  List<String>? ids;
  Completer<List<RecipeMatch>>? pending;
  @override
  Future<List<RecipeMatch>> matchByIngredients(List<String> productIds) async {
    ids = productIds;
    if (pending != null) return pending!.future;
    return [];
  }
}

class _Search extends ProductSearchService {
  final calls = <String, Completer<List<Product>>>{};
  @override
  Future<List<Product>> search(String query, {int limit = 20}) =>
      (calls[query] = Completer()).future;
}

Future<_Shopping> _open(
  WidgetTester tester,
  Widget screen, {
  bool english = true,
  bool premium = true,
  double scale = 1,
  bool dark = false,
}) async {
  final auth = _Auth(english, premium);
  await auth.initialization;
  final shopping = _Shopping();
  final baseTheme = productFormTheme(dark);
  final proofTheme =
      const bool.fromEnvironment('UK_WRITE_UI_PROOF')
          ? baseTheme.copyWith(
            appBarTheme: baseTheme.appBarTheme.copyWith(
              titleTextStyle: baseTheme.appBarTheme.titleTextStyle?.copyWith(
                fontFamily: 'UKStage8Proof',
              ),
            ),
          )
          : baseTheme;
  addTearDown(auth.dispose);
  addTearDown(shopping.dispose);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: auth),
        ChangeNotifierProvider<ShoppingListProvider>.value(value: shopping),
      ],
      child: MaterialApp(
        locale: english ? const Locale('en', 'GB') : const Locale('pl', 'PL'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme: proofTheme,
        builder:
            (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: RepaintBoundary(key: productFormProofKey, child: child!),
            ),
        home: screen,
        routes: {
          '/recipe/detail':
              (context) => Scaffold(
                body: Text(
                  'Recipe: ${(ModalRoute.of(context)!.settings.arguments as Recipe).id}',
                ),
              ),
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
  return shopping;
}

void main() {
  setUpAll(loadProductFormFonts);
  for (final english in [false, true]) {
    testWidgets(
      'pantry matching sends selected canonical IDs unchanged: $english',
      (tester) async {
        final pantry = _Pantry([
          for (final id in ['a', 'b'])
            PantryItem(id: 'pantry-$id', product: _product(id)),
        ]);
        final recipes = _Recipes();
        await _open(
          tester,
          IngredientMatchSelectScreen(
            pantryService: pantry,
            recipeService: recipes,
          ),
          english: english,
        );
        expect(
          find.text(
            english ? 'Cook from my pantry' : 'Co ugotować z tego, co mam',
          ),
          findsOneWidget,
        );
        await tester.tap(find.text('b'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.text(english ? 'Find recipes (1)' : 'Szukaj przepisów (1)'),
        );
        await tester.pumpAndSettle();
        expect(recipes.ids, ['a']);
        expect(find.byType(IngredientMatchResultsScreen), findsOneWidget);
        expect(
          find.text(english ? 'Matching recipes' : 'Dopasowane przepisy'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets('standard account retains the Premium gate: $english', (
      tester,
    ) async {
      await _open(
        tester,
        IngredientMatchSelectScreen(
          pantryService: _Pantry([]),
          recipeService: _Recipes(),
        ),
        english: english,
        premium: false,
      );
      expect(
        find.text(english ? 'Premium feature' : 'Funkcja Premium'),
        findsOneWidget,
      );
      expect(find.byType(CheckboxListTile), findsNothing);
      expect(
        find.text(english ? 'See Premium' : 'Zobacz Premium'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
    testWidgets(
      'pantry quantities and successful deletion keep their IDs: $english',
      (tester) async {
        final pantry = _Pantry([
          PantryItem(
            id: 'pantry-a',
            product: _product('a', unit: 'opak'),
            quantity: 2,
            unit: 'opak',
          ),
        ]);
        final shopping = await _open(
          tester,
          PantryScreen(service: pantry),
          english: english,
        );
        expect(find.text(english ? 'Pantry' : 'Spiżarnia'), findsOneWidget);
        expect(find.text(english ? '2 packs' : '2 opakowanie'), findsOneWidget);
        await tester.tap(find.byIcon(Icons.close));
        await tester.pumpAndSettle();
        expect(pantry.deletes, ['pantry-a']);
        expect(shopping.refreshes, 1);
        expect(find.text('a'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final english in [false, true]) {
    testWidgets(
      'search selection adds one known pack and refreshes pantry EN=$english',
      (tester) async {
        final pantry = _Pantry([]);
        final search = _Search();
        final shopping = await _open(
          tester,
          PantryScreen(service: pantry, searchService: search),
          english: english,
        );
        await tester.tap(find.byType(FloatingActionButton));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'Known product');
        await tester.pump();
        search.calls['Known product']!.complete([_product('Known product')]);
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ListTile, 'Known product'));
        await tester.pumpAndSettle();
        await tester.tap(find.text(english ? '1 × pack' : '1 × opakowanie'));
        await tester.pumpAndSettle();
        expect(pantry.additions, hasLength(1));
        expect(pantry.additions.single.$1, ['Known product']);
        expect(pantry.additions.single.$2, 1.0);
        expect(pantry.additions.single.$3, 'opak');
        expect(shopping.refreshes, 1);
        expect(find.text(english ? '1 pack' : '1 opakowanie'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('matching result card lays out and opens its exact recipe', (
    tester,
  ) async {
    final recipe = Recipe(
      id: 'recipe-42',
      name: 'Unchanged soup',
      mealType: 'obiad',
      servings: 2,
      difficulty: 'łatwy',
      isActive: true,
      tags: [],
      ingredients: [],
      nutritionTotal: NutritionInfo(
        kcal: 200,
        protein: 10,
        fat: 8,
        carbs: 22,
        fiber: 3,
      ),
    );
    await _open(
      tester,
      IngredientMatchResultsScreen(
        matches: [
          RecipeMatch(
            recipe: recipe,
            matchedCount: 2,
            totalRequired: 2,
            missingIngredientNames: [],
          ),
        ],
        usedProductNames: const ['Carrots', 'Rice'],
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Ready to cook'), findsOneWidget);
    await tester.tap(find.text('Unchanged soup'));
    await tester.pumpAndSettle();
    expect(find.text('Recipe: recipe-42'), findsOneWidget);
  });

  testWidgets(
    'failed simultaneous pantry removals restore rows without RangeError',
    (tester) async {
      final pantry = _Pantry([
        for (final id in ['a', 'b', 'c'])
          PantryItem(id: id, product: _product(id)),
      ]);
      pantry.pendingDeletes['b'] = Completer();
      pantry.pendingDeletes['c'] = Completer();
      await _open(tester, PantryScreen(service: pantry), english: false);
      await tester.tap(find.byIcon(Icons.close).at(2));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.close).at(1));
      await tester.pump();
      pantry.pendingDeletes['c']!.completeError(
        ApiException(503, 'Synthetic failure'),
      );
      await tester.pumpAndSettle();
      final firstError = tester.takeException();
      pantry.pendingDeletes['b']!.completeError(
        ApiException(503, 'Synthetic failure'),
      );
      await tester.pumpAndSettle();
      expect(firstError, isNull);
      expect(tester.takeException(), isNull);
      for (final id in ['a', 'b', 'c']) {
        expect(find.text(id), findsOneWidget);
      }
    },
  );

  testWidgets('older pantry search cannot overwrite the newer query', (
    tester,
  ) async {
    final search = _Search();
    await _open(
      tester,
      PantryScreen(service: _Pantry([]), searchService: search),
      english: false,
    );
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'older');
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'newer');
    await tester.pump();
    search.calls['newer']!.complete([_product('New result')]);
    await tester.pumpAndSettle();
    search.calls['older']!.complete([_product('Old result')]);
    await tester.pumpAndSettle();
    expect(find.text('New result'), findsOneWidget);
    expect(find.text('Old result'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final english in [false, true]) {
    for (final unit in ['g', 'ml']) {
      testWidgets(
        'editing pantry preserves exact amount and canonical unit $unit EN=$english',
        (tester) async {
          final pantry = _Pantry([
            PantryItem(
              id: 'row-99',
              product: _product('Existing product', unit: unit),
              quantity: 125,
              unit: unit,
            ),
          ]);
          final shopping = await _open(
            tester,
            PantryScreen(service: pantry),
            english: english,
          );
          await tester.tap(find.text('Existing product'));
          await tester.pumpAndSettle();
          final input = find.byType(TextField);
          await tester.scrollUntilVisible(
            input,
            100,
            scrollable: find.byType(Scrollable).last,
          );
          await tester.enterText(input, '175.5');
          await tester.pumpAndSettle();
          await tester.tap(
            find.text(english ? 'Select amount' : 'Wybierz ilość'),
          );
          await tester.pumpAndSettle();
          expect(pantry.updates, [('row-99', 175.5, unit)]);
          expect(shopping.refreshes, 1);
          expect(tester.takeException(), isNull);
        },
      );
    }
    testWidgets(
      'pantry localized error can retry without treating failure as empty EN=$english',
      (tester) async {
        final pantry = _Pantry([
          PantryItem(id: 'row', product: _product('Still here')),
        ])..fail = true;
        await _open(tester, PantryScreen(service: pantry), english: english);
        expect(find.text('Still here'), findsNothing);
        expect(find.text('Synthetic service failure'), findsNothing);
        pantry.fail = false;
        await tester.tap(find.text(english ? 'Try again' : 'Spróbuj ponownie'));
        await tester.pumpAndSettle();
        expect(find.text('Still here'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
    test(
      'localized AI prompts preserve ingredient names and allowance EN=$english',
      () async {
        final strings = await AppLocalizations.delegate.load(
          english ? const Locale('en', 'GB') : const Locale('pl'),
        );
        for (final prompt in [
          strings.matchSelectPrompt('Mąka, Cornflakes'),
          strings.matchResultsPrompt('Mąka, Cornflakes'),
        ]) {
          expect(prompt, contains('Mąka, Cornflakes'));
          expect(prompt, anyOf(contains('2–3'), contains('2-3')));
          expect(prompt, contains(english ? 'ingredients' : 'składniki'));
        }
      },
    );
    for (final dark in [false, true]) {
      testWidgets(
        'matching cards finite at 320px and 150% EN=$english dark=$dark',
        (tester) async {
          AppTheme.setDark(dark);
          addTearDown(() => AppTheme.setDark(false));
          tester.view.physicalSize = const Size(320, 740);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          Recipe recipe(String id, String name) => Recipe(
            id: id,
            name: name,
            mealType: 'obiad',
            servings: 2,
            difficulty: 'łatwy',
            isActive: true,
            tags: [],
            ingredients: [],
            nutritionTotal: NutritionInfo(
              kcal: 200,
              protein: 10,
              fat: 8,
              carbs: 22,
              fiber: 3,
            ),
          );
          await _open(
            tester,
            IngredientMatchResultsScreen(
              matches: [
                RecipeMatch(
                  recipe: recipe(
                    'full',
                    english
                        ? 'Roasted vegetable and lentil soup'
                        : 'Zupa z pieczonych warzyw i soczewicy',
                  ),
                  matchedCount: 2,
                  totalRequired: 2,
                  missingIngredientNames: [],
                ),
                RecipeMatch(
                  recipe: recipe(
                    'partial',
                    english
                        ? 'Rice with herbs and vegetables'
                        : 'Ryż z ziołami i warzywami',
                  ),
                  matchedCount: 1,
                  totalRequired: 3,
                  missingIngredientNames: const ['Mąka', 'Cornflakes'],
                ),
              ],
              usedProductNames: const ['Mąka'],
            ),
            english: english,
            dark: dark,
            scale: 1.5,
          );
          expect(
            find.text(english ? 'Ready to cook' : 'Możesz ugotować teraz'),
            findsOneWidget,
          );
          expect(
            find.text(
              english
                  ? 'Missing: Mąka, Cornflakes'
                  : 'Brakuje: Mąka, Cornflakes',
            ),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
          if (const bool.fromEnvironment('UK_WRITE_UI_PROOF')) {
            final boundary = tester.renderObject<RenderRepaintBoundary>(
              find.byKey(productFormProofKey),
            );
            await tester.runAsync(() async {
              final bitmap = await boundary.toImage(pixelRatio: 1);
              final png = await bitmap.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final file = File(
                '../docs/uk-stage18/evidence/matching-$english-$dark.png',
              );
              await file.parent.create(recursive: true);
              await file.writeAsBytes(png!.buffer.asUint8List());
              bitmap.dispose();
            });
          }
          await tester.tap(
            find.text(
              english
                  ? 'Rice with herbs and vegetables'
                  : 'Ryż z ziołami i warzywami',
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('Recipe: partial'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('clearing pantry query invalidates pending results and spinner', (
    tester,
  ) async {
    final search = _Search();
    await _open(
      tester,
      PantryScreen(service: _Pantry([]), searchService: search),
    );
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'pending');
    await tester.pump();
    await tester.enterText(find.byType(TextField), '');
    await tester.pumpAndSettle();
    expect(find.text('Enter a product name.'), findsOneWidget);
    search.calls['pending']!.complete([_product('Stale result')]);
    await tester.pumpAndSettle();
    expect(find.text('Stale result'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'failed new search cannot expose results from the previous query',
    (tester) async {
      final search = _Search();
      await _open(
        tester,
        PantryScreen(service: _Pantry([]), searchService: search),
      );
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'first');
      await tester.pump();
      search.calls['first']!.complete([_product('Previous result')]);
      await tester.pumpAndSettle();
      expect(find.text('Previous result'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'failed');
      await tester.pump();
      search.calls['failed']!.completeError(
        ApiException(503, 'Synthetic failure'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Previous result'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final refreshCompletesAfterDelete in [false, true]) {
    testWidgets(
      'refresh cannot resurrect deleted pantry row: late=$refreshCompletesAfterDelete',
      (tester) async {
        final row = PantryItem(
          id: 'remove-me',
          product: _product('Removed product'),
        );
        final pantry = _Pantry([row]);
        pantry.pendingDeletes[row.id] = Completer();
        final shopping = await _open(tester, PantryScreen(service: pantry));
        await tester.tap(find.byIcon(Icons.close));
        await tester.pumpAndSettle();
        pantry.pendingLoad = Completer();
        final refresh =
            tester
                .widget<RefreshIndicator>(find.byType(RefreshIndicator))
                .onRefresh();
        await tester.pump();
        if (refreshCompletesAfterDelete) {
          pantry.pendingDeletes[row.id]!.complete();
          await tester.pump();
        }
        pantry.pendingLoad!.complete([row]);
        await refresh;
        await tester.pumpAndSettle();
        expect(find.text('Removed product'), findsNothing);
        if (!refreshCompletesAfterDelete) {
          pantry.pendingDeletes[row.id]!.complete();
          await tester.pumpAndSettle();
        }
        expect(find.text('Removed product'), findsNothing);
        expect(shopping.refreshes, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'finishing deletion must not hide a newly added different product',
    (tester) async {
      final row = PantryItem(
        id: 'remove-me',
        product: _product('Removed product'),
      );
      final pantry = _Pantry([row]);
      pantry.pendingDeletes[row.id] = Completer();
      final search = _Search();
      await _open(tester, PantryScreen(service: pantry, searchService: search));
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'New product');
      await tester.pump();
      search.calls['New product']!.complete([_product('New product')]);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'New product'));
      await tester.pumpAndSettle();
      pantry.pendingLoad = Completer();
      await tester.tap(find.text('1 × pack'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      pantry.pendingDeletes[row.id]!.complete();
      await tester.pump();
      pantry.pendingLoad!.complete(List.of(pantry.items));
      await tester.pumpAndSettle();
      expect(find.text('New product'), findsOneWidget);
      expect(find.text('Removed product'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a re-added product with a fresh pantry row ID is visible', (
    tester,
  ) async {
    final product = _product('Re-added product');
    final pantry = _Pantry([PantryItem(id: 'old-row', product: product)]);
    await _open(tester, PantryScreen(service: pantry));
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    pantry.items.add(
      PantryItem(id: 'fresh-row', product: product, quantity: 2, unit: 'opak'),
    );
    await tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator))
        .onRefresh();
    await tester.pumpAndSettle();
    expect(find.text('Re-added product'), findsOneWidget);
    expect(find.text('2 packs'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'pending matching response keeps submitted names if selection changes',
    (tester) async {
      final pantry = _Pantry([
        for (final id in ['a', 'b']) PantryItem(id: id, product: _product(id)),
      ]);
      final recipes = _Recipes()..pending = Completer();
      await _open(
        tester,
        IngredientMatchSelectScreen(
          pantryService: pantry,
          recipeService: recipes,
        ),
      );
      await tester.tap(find.text('Find recipes (2)'));
      await tester.pump();
      await tester.tap(find.text('b'));
      await tester.pump();
      recipes.pending!.complete([]);
      await tester.pumpAndSettle();
      expect(recipes.ids, ['a', 'b']);
      expect(
        tester
            .widget<IngredientMatchResultsScreen>(
              find.byType(IngredientMatchResultsScreen),
            )
            .usedProductNames,
        ['a', 'b'],
      );
      expect(tester.takeException(), isNull);
    },
  );
}
