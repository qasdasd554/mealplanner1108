import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import '../../helpers/product_form_render.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:smart_meal_planner/l10n/app_localizations.dart';
import 'package:smart_meal_planner/l10n/app_localizations_en.dart';
import 'package:smart_meal_planner/l10n/system_content_data.dart';
import 'package:smart_meal_planner/models/recipe.dart';
import 'package:smart_meal_planner/models/meal_plan.dart';
import 'package:smart_meal_planner/models/recipe_comment.dart';
import 'package:smart_meal_planner/models/user.dart';
import 'package:smart_meal_planner/providers/auth_provider.dart';
import 'package:smart_meal_planner/providers/store_provider.dart';
import 'package:smart_meal_planner/models/store.dart';
import 'package:smart_meal_planner/models/shopping_list.dart';
import 'package:smart_meal_planner/services/shopping_list_service.dart';
import 'package:smart_meal_planner/widgets/dish_shopping_list_button.dart';
import 'package:smart_meal_planner/widgets/recipe_variant_editor_sheet.dart';
import 'package:smart_meal_planner/screens/recipes/recipe_detail_screen.dart';
import 'package:smart_meal_planner/services/recipe_service.dart';
import 'package:smart_meal_planner/services/api_client.dart';
import 'package:smart_meal_planner/services/recipe_comment_service.dart';
import 'package:smart_meal_planner/widgets/ai_recipe_edit_sheet.dart';
import 'package:smart_meal_planner/widgets/recipe_delete_button.dart';
import 'package:smart_meal_planner/widgets/recipe_publish_button.dart';
import 'package:smart_meal_planner/widgets/submit_recipe_photo_button.dart';
import 'package:smart_meal_planner/theme/app_theme.dart';

Recipe recipe({bool full = true, String id = 'recipe', double quantity = 50}) =>
    Recipe.fromJson({
      'id': id,
      'name': 'Zupa autora',
      'description': 'Oryginalny opis',
      'meal_type': 'obiad',
      'servings': 2,
      'difficulty': 'łatwy',
      'prep_time_min': 10,
      'cook_time_min': 5,
      'nutrition_total': {'kcal': 400, 'protein': 20, 'fat': 10, 'carbs': 30},
      'is_active': true,
      'is_own_recipe': true,
      'visibility': 'private',
      'created_by_name': 'Kuchnia Autora',
      if (full) 'instructions': ['Nie tłumacz autorskich kroków'],
      if (full)
        'ingredients': [
          {
            'id': 'ingredient',
            'product_id': 'salt',
            'product_name': 'Sól autora',
            'quantity': quantity,
            'unit': 'g',
            'is_optional': false,
            'kcal': 100,
          },
        ],
    });

class _Auth extends AuthProvider {
  final int points;
  int loads = 0;
  _Auth({this.points = 3}) : super(readToken: () async => null);
  @override
  User get currentUser => User(
    id: 'user',
    email: 'test@example.test',
    countryCode: 'GB',
    householdSize: 1,
    premiumPoints: points,
    isPremium: true,
    createdAt: DateTime.utc(2026),
  );
  @override
  Future<void> loadProfile() async {
    loads++;
  }
}

class _Recipes extends RecipeService {
  Object? failure;
  Recipe? response;
  bool fail = false;
  int reads = 0;
  Completer<Recipe>? pending;
  final prompts = <String>[];
  Object? variantFailure;
  final variants = <List<RecipeIngredient>>[];
  @override
  Future<Recipe> saveVariant(
    String id,
    List<RecipeIngredient> ingredients,
  ) async {
    variants.add(ingredients);
    if (variantFailure != null) throw variantFailure!;
    return recipe(id: 'saved-variant', quantity: ingredients.single.quantity);
  }

  @override
  Future<Recipe> getRecipe(String id) async {
    reads++;
    if (fail) throw Exception('offline');
    return pending?.future ?? response ?? recipe();
  }

  @override
  Future<Recipe> editRecipeWithAi(String id, String prompt) async {
    prompts.add(prompt);
    if (failure != null) throw failure!;
    if (fail) throw Exception('offline');
    return pending?.future ?? recipe();
  }
}

class _Shopping extends ShoppingListService {
  final submitted = <List<String>>[];
  int? servings;
  @override
  Future<List<ShoppingList>> getMyLists() async => [];
  @override
  Future<ShoppingList> createFromRecipes({
    required List<String> recipeIds,
    required String storeId,
    String? existingListId,
    int? servings,
  }) async {
    submitted.add(recipeIds);
    this.servings = servings;
    // Stop at the tested boundary, without navigation or a real request.
    throw ApiException(503, 'Local test boundary');
  }
}

class _Comments extends RecipeCommentService {
  @override
  Future<List<RecipeComment>> getComments(String recipeId) async => [];
}

Widget _app(
  _Auth auth,
  Widget home, {
  bool english = true,
  bool dark = false,
  double scale = 1,
}) => MultiProvider(
  providers: [
    ChangeNotifierProvider<AuthProvider>.value(value: auth),
    ChangeNotifierProvider<StoreProvider>(
      create:
          (_) =>
              StoreProvider()..selectStore(
                Store(
                  id: 'store',
                  name: 'Test store',
                  createdAt: DateTime.utc(2026),
                  updatedAt: null,
                ),
              ),
    ),
  ],
  child: MaterialApp(
    locale: english ? const Locale('en', 'GB') : const Locale('pl', 'PL'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    theme: productFormTheme(dark),
    builder:
        (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: RepaintBoundary(key: productFormProofKey, child: child!),
        ),
    home: Scaffold(body: home),
  ),
);

Future<void> _openDetail(
  WidgetTester tester,
  _Auth auth,
  _Recipes service, {
  bool full = true,
  bool english = true,
  bool dark = false,
  double scale = 1,
  ShoppingListService? shoppingService,
  Object? routeRecipe,
}) async {
  await tester.pumpWidget(
    _app(
      auth,
      Builder(
        builder:
            (context) => TextButton(
              onPressed:
                  () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      settings: RouteSettings(
                        arguments: routeRecipe ?? recipe(full: full),
                      ),
                      builder:
                          (_) => RecipeDetailScreen(
                            service: service,
                            shoppingService: shoppingService,
                            commentService: _Comments(),
                          ),
                    ),
                  ),
              child: const Text('Open'),
            ),
      ),
      english: english,
      dark: dark,
      scale: scale,
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1000));
}

void main() {
  for (final english in [true, false]) {
    testWidgets(
      'plan recipe shows household ingredients after refresh: $english',
      (tester) async {
        final auth = _Auth();
        addTearDown(auth.dispose);
        final service = _Recipes();
        final shopping = _Shopping();
        final entry = MealPlanEntry(
          id: 'entry',
          mealPlanId: 'plan',
          recipeId: 'recipe',
          recipe: recipe(),
          dayNumber: 1,
          mealSlot: 'obiad',
          servingsMultiplier: 1.5,
        );
        await _openDetail(
          tester,
          auth,
          service,
          english: english,
          routeRecipe: entry,
          shoppingService: shopping,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('3'), findsOneWidget);
        final ingredients = find.text('Sól autora');
        await tester.scrollUntilVisible(
          ingredients,
          250,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        expect(find.text('75 g (150 kcal)'), findsOneWidget);
        expect(entry.recipe.ingredients.single.quantity, 50);
        final listButton = find.byType(DishShoppingListButton);
        await tester.scrollUntilVisible(
          listButton,
          -250,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: listButton,
            matching: find.byType(OutlinedButton),
          ),
        );
        await tester.pumpAndSettle();
        expect(shopping.submitted, [
          ['recipe'],
        ]);
        expect(shopping.servings, 3);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  for (final english in [true, false]) {
    for (final partial in [false, true]) {
      testWidgets(
        'nutrition recovery is labelled; EN=$english partial=$partial',
        (tester) async {
          final auth = _Auth();
          addTearDown(auth.dispose);
          final item = Recipe.fromJson({
            'id': 'nutrition-recovery',
            'name': 'Chicken',
            'meal_type': 'obiad',
            'servings': 4,
            'is_own_recipe': true,
            'instructions': ['Cook.'],
            'nutrition_total':
                partial
                    ? {
                      'kcal': null,
                      '_incomplete': true,
                      '_missing_ingredients': ['Oil'],
                      '_known_totals': {'kcal': 720, 'protein': 132},
                    }
                    : {
                      'kcal': 968,
                      'protein': 132,
                      'fat': 45,
                      'carbs': 0,
                      '_estimated': true,
                      '_estimated_ingredients': ['Oil'],
                    },
            'ingredients': [
              {
                'id': 'chicken',
                'product_id': 'chicken',
                'product_name': 'Chicken',
                'quantity': 600,
                'unit': 'g',
                'kcal': 720,
              },
            ],
          });
          await _openDetail(
            tester,
            auth,
            _Recipes()..response = item,
            routeRecipe: item,
            english: english,
            scale: 1.5,
          );
          await tester.scrollUntilVisible(
            find.byKey(const ValueKey('recipe-nutrition-status')),
            250,
            scrollable: find.byType(Scrollable).first,
          );
          expect(
            find.text(partial ? '≥ 180 kcal' : '~ 242 kcal'),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('recipe-nutrition-status')),
            findsOneWidget,
          );
          expect(find.text('0 kcal'), findsNothing);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }
  Recipe authored({required bool preview, bool full = false}) =>
      Recipe.fromJson({
        'id': 'authored',
        'name': 'Author recipe',
        'meal_type': 'obiad',
        'servings': 2,
        'difficulty': 'łatwy',
        'nutrition_total': {'kcal': 300},
        'is_active': true,
        'created_by_user_id': 'author',
        if (preview) ...{
          'created_by_profile_loaded': true,
          'created_by_name': 'Kitchen author',
          'created_by_tiktok_username': 'kitchen.author',
        },
        if (full)
          'ingredients': [
            {
              'id': 'ingredient',
              'product_id': 'product',
              'product_name': 'Carrot',
              'quantity': 100,
              'unit': 'g',
              'is_optional': false,
            },
          ],
      });
  for (final english in [false, true]) {
    testWidgets(
      'unknown ingredient is readable, never shown as zero kcal, en=$english',
      (tester) async {
        tester.view.physicalSize = const Size(320, 740);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final missing = Recipe.fromJson({
          'id': 'missing',
          'name': 'Recipe',
          'meal_type': 'obiad',
          'servings': 2,
          'nutrition_total': {
            'kcal': null,
            'protein': null,
            'fat': null,
            'carbs': null,
            '_incomplete': true,
            '_missing_ingredients': ['Filo pastry'],
          },
          'instructions': ['Prepare ingredients.'],
          'ingredients': [
            {
              'id': 'ingredient',
              'product_id': 'private-product',
              'product_name': 'Filo pastry',
              'quantity': 200,
              'unit': 'g',
              'kcal': null,
            },
          ],
        });
        final auth = _Auth();
        addTearDown(auth.dispose);
        final service = _Recipes()..response = missing;
        await _openDetail(
          tester,
          auth,
          service,
          english: english,
          scale: 1.5,
          routeRecipe: missing,
        );
        expect(find.text('0 kcal'), findsNothing);
        await tester.ensureVisible(
          find.byKey(const ValueKey('recipe-missing-nutrition')),
        );
        await tester.pumpAndSettle();
        expect(
          find.textContaining(
            english ? 'Nutrition unavailable' : 'Brak danych odżywczych',
          ),
          findsWidgets,
        );
        expect(
          find.text(
            '200 g\n${english ? 'Nutrition unavailable' : 'Brak danych odżywczych'}',
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
    testWidgets(
      'legacy author failure offers retry without losing route, en=$english',
      (tester) async {
        final service = _Recipes()..fail = true;
        final auth = _Auth();
        addTearDown(auth.dispose);
        await _openDetail(
          tester,
          auth,
          service,
          english: english,
          routeRecipe: authored(preview: false),
        );
        expect(find.byKey(const Key('recipe-author-loading')), findsOneWidget);
        expect(find.byType(CustomScrollView), findsNothing);
        service.fail = false;
        service.response = authored(preview: true, full: true);
        await tester.tap(find.byType(OutlinedButton));
        await tester.pumpAndSettle();
        expect(
          find.text(
            english ? 'Added by Kitchen author' : 'Dodane przez Kitchen author',
          ),
          findsOneWidget,
        );
        expect(service.reads, 2);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
    testWidgets('legacy authored route waits for author, en=$english', (
      tester,
    ) async {
      final service = _Recipes()..pending = Completer<Recipe>();
      await _openDetail(
        tester,
        _Auth(),
        service,
        english: english,
        routeRecipe: authored(preview: false),
      );
      expect(find.byKey(const Key('recipe-author-loading')), findsOneWidget);
      expect(find.byType(CustomScrollView), findsNothing);
      service.pending!.complete(authored(preview: true, full: true));
      await tester.pumpAndSettle();
      expect(
        find.text(
          english ? 'Added by Kitchen author' : 'Dodane przez Kitchen author',
        ),
        findsOneWidget,
      );
      expect(find.text('@kitchen.author'), findsOneWidget);
      expect(service.reads, 1);
      await tester.pumpWidget(const SizedBox());
    });
    testWidgets(
      'preview author is in first page and survives detail load, en=$english',
      (tester) async {
        final service = _Recipes()..pending = Completer<Recipe>();
        await _openDetail(
          tester,
          _Auth(),
          service,
          english: english,
          routeRecipe: authored(preview: true),
        );
        final author = find.text(
          english ? 'Added by Kitchen author' : 'Dodane przez Kitchen author',
        );
        expect(author, findsOneWidget);
        expect(find.text('@kitchen.author'), findsOneWidget);
        final element = tester.element(author);
        final scrollable = tester.state<ScrollableState>(
          find.byType(Scrollable).first,
        );
        scrollable.position.jumpTo(120);
        await tester.pump();
        service.pending!.complete(authored(preview: true, full: true));
        await tester.pumpAndSettle();
        expect(tester.element(author), same(element));
        expect(
          tester.state<ScrollableState>(find.byType(Scrollable).first),
          same(scrollable),
        );
        expect(scrollable.position.pixels, 120);
        expect(service.reads, 1);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  for (final english in [false, true]) {
    for (final saveFails in [false, true]) {
      testWidgets(
        'shopping uses displayed variant, en=$english saveFails=$saveFails',
        (tester) async {
          final service = _Recipes();
          if (saveFails) service.variantFailure = ApiException(503, 'offline');
          final shopping = _Shopping();
          await _openDetail(
            tester,
            _Auth(),
            service,
            english: english,
            shoppingService: shopping,
          );
          await Scrollable.ensureVisible(
            tester.element(
              find.widgetWithIcon(TextButton, Icons.edit_outlined),
            ),
            alignment: 0.5,
          );
          await tester.pumpAndSettle();
          await tester.tap(
            find.widgetWithIcon(TextButton, Icons.edit_outlined),
          );
          await tester.pumpAndSettle();
          final editor = tester.element(find.byType(RecipeVariantEditorSheet));
          Navigator.of(editor).pop([
            RecipeIngredient(
              id: 'ingredient',
              productId: 'salt',
              productName: 'Sól autora',
              quantity: 125,
              unit: 'g',
              isOptional: false,
            ),
          ]);
          await tester.pumpAndSettle();
          tester
              .state<ScrollableState>(find.byType(Scrollable).first)
              .position
              .jumpTo(0);
          await tester.pumpAndSettle();
          await Scrollable.ensureVisible(
            tester.element(find.byType(DishShoppingListButton)),
            alignment: 0.5,
          );
          await tester.pumpAndSettle();
          await tester.tap(
            find.descendant(
              of: find.byType(DishShoppingListButton),
              matching: find.byType(OutlinedButton),
            ),
          );
          await tester.pumpAndSettle();
          expect(service.variants, hasLength(1));
          expect(service.variants.single.single.quantity, 125);
          expect(
            shopping.submitted,
            saveFails
                ? isEmpty
                : equals([
                  ['saved-variant'],
                ]),
          );
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
  setUpAll(loadProductFormFonts);
  testWidgets(
    'English AI edit failure stays English without changing the authored prompt',
    (tester) async {
      final auth = _Auth();
      addTearDown(auth.dispose);
      final service =
          _Recipes()..failure = ApiException(503, 'raw unavailable');
      await tester.pumpWidget(
        _app(
          auth,
          Builder(
            builder:
                (context) => TextButton(
                  onPressed:
                      () => showAiRecipeEditSheet(
                        context,
                        recipe(),
                        service: service,
                      ),
                  child: const Text('Open'),
                ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField),
        'Keep this original prompt',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.tap(
        find.byWidgetPredicate((widget) => widget is FilledButton),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(AppLocalizationsEnGb().errorUnavailable),
        findsOneWidget,
      );
      expect(service.prompts, ['Keep this original prompt']);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );
  for (final english in [true, false]) {
    testWidgets(
      'actual system recipe detail displays reviewed content EN=$english',
      (tester) async {
        tester.view.physicalSize = const Size(320, 740);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final entry = systemRecipeText.entries.first;
        final source = entry.value['source'] as Map<String, dynamic>;
        final shown =
            english ? entry.value['en_GB'] as Map<String, dynamic> : source;
        final potato = systemIngredientText.entries.firstWhere(
          (row) => row.value['en_GB'] == 'Potatoes',
        );
        final actual = Recipe.fromJson({
          'id': entry.key,
          ...source,
          'meal_type': 'obiad',
          'is_active': true,
          'nutrition_total': {'kcal': 222},
          'servings': 2,
          'tags': <String>[],
          'ingredients': [
            {
              'id': 'synthetic-ingredient',
              'product_id': potato.key,
              'product_name': potato.value['source'],
              'quantity': 300,
              'unit': 'g',
              'is_optional': false,
              'kcal': 222,
            },
          ],
        });
        final auth = _Auth();
        final service = _Recipes()..response = actual;
        addTearDown(auth.dispose);
        await _openDetail(tester, auth, service, english: english, scale: 1.5);
        expect(find.text(shown['name'] as String), findsOneWidget);
        expect(find.text(english ? 'Potatoes' : 'Ziemniaki'), findsOneWidget);
        final firstStep = (shown['instructions'] as List).first as String;
        await tester.ensureVisible(find.text(firstStep));
        await tester.pumpAndSettle();
        expect(find.text(firstStep), findsOneWidget);
        expect(actual.name, source['name']);
        expect(actual.ingredients.single.quantity, 300);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );
  }
  for (final english in [true, false]) {
    for (final dark in [true, false]) {
      testWidgets('detail narrow layout EN=$english dark=$dark', (
        tester,
      ) async {
        AppTheme.setDark(dark);
        addTearDown(() => AppTheme.setDark(false));
        final handler = FlutterError.onError;
        FlutterError.onError = (details) {
          FlutterError.dumpErrorToConsole(details, forceReport: true);
          handler?.call(details);
        };
        addTearDown(() => FlutterError.onError = handler);
        tester.view.physicalSize = const Size(320, 740);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final auth = _Auth();
        addTearDown(auth.dispose);
        await _openDetail(
          tester,
          auth,
          _Recipes(),
          english: english,
          dark: dark,
          scale: 1.5,
        );
        await tester.scrollUntilVisible(
          find.text(english ? 'Nutrition' : 'Wartości odżywcze'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pump(const Duration(milliseconds: 1000));
        expect(tester.takeException(), isNull);
        if (const bool.fromEnvironment('UK_WRITE_UI_PROOF')) {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(productFormProofKey),
          );
          await tester.runAsync(() async {
            final image = await boundary.toImage(pixelRatio: 1);
            final png = await image.toByteData(format: ui.ImageByteFormat.png);
            final file = File(
              '../docs/uk-stage10/evidence/detail-$english-$dark.png',
            );
            await file.parent.create(recursive: true);
            await file.writeAsBytes(png!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.pumpWidget(const SizedBox());
      });
    }
  }

  for (final english in [true, false]) {
    testWidgets(
      'detail labels use locale=$english but preserve recipe author content',
      (tester) async {
        final auth = _Auth();
        addTearDown(auth.dispose);
        final service = _Recipes();
        await _openDetail(tester, auth, service, english: english);
        expect(find.text('Zupa autora'), findsOneWidget);
        expect(find.text('Oryginalny opis'), findsOneWidget);
        expect(
          find.text(
            english ? 'Added by Kuchnia Autora' : 'Dodane przez Kuchnia Autora',
          ),
          findsOneWidget,
        );
        expect(find.text(english ? 'easy' : 'łatwy'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text(english ? 'Nutrition' : 'Wartości odżywcze'),
          220,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('200 kcal'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text(english ? 'Method' : 'Sposób przygotowania'),
          220,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('Nie tłumacz autorskich kroków'), findsOneWidget);
        expect(service.reads, 1);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    'light summary shows English loading state then fresh ingredients',
    (tester) async {
      final auth = _Auth();
      addTearDown(auth.dispose);
      final service = _Recipes()..pending = Completer<Recipe>();
      await _openDetail(tester, auth, service, full: false);
      await tester.scrollUntilVisible(
        find.text('Loading ingredients and method…'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      service.pending!.complete(recipe());
      await tester.pumpAndSettle();
      expect(find.text('Sól autora'), findsOneWidget);
      expect(find.text('Loading ingredients and method…'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('failed fresh detail keeps summary and offers a working retry', (
    tester,
  ) async {
    final auth = _Auth();
    addTearDown(auth.dispose);
    final service = _Recipes()..fail = true;
    await _openDetail(tester, auth, service, full: false);
    await tester.scrollUntilVisible(
      find.text('Try loading the details again'),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    service.fail = false;
    await tester.tap(find.text('Try loading the details again'));
    await tester.pumpAndSettle();
    expect(find.text('Sól autora'), findsOneWidget);
    expect(service.reads, 2);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'owner actions translate without changing their visibility gates',
    (tester) async {
      final auth = _Auth();
      addTearDown(auth.dispose);
      await tester.pumpWidget(
        _app(
          auth,
          Column(
            children: [
              RecipeDeleteButton(recipe: recipe()),
              RecipePublishButton(recipe: recipe()),
              const SubmitRecipePhotoButton(recipeId: 'recipe'),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Delete recipe'), findsOneWidget);
      expect(find.text('Publish recipe'), findsOneWidget);
      expect(find.text('Add photo'), findsOneWidget);
      await tester.tap(find.text('Publish recipe'));
      await tester.pumpAndSettle();
      expect(find.text('Publish recipe?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    },
  );

  testWidgets(
    'AI edit keeps one-point cost, prevents duplicate submission and returns recipe',
    (tester) async {
      final auth = _Auth();
      addTearDown(auth.dispose);
      final service = _Recipes()..pending = Completer<Recipe>();
      Recipe? changed;
      await tester.pumpWidget(
        _app(
          auth,
          Builder(
            builder:
                (context) => TextButton(
                  onPressed: () async {
                    changed = await showAiRecipeEditSheet(
                      context,
                      recipe(),
                      service: service,
                    );
                  },
                  child: const Text('Open'),
                ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Adjust recipe with AI'), findsOneWidget);
      expect(
        find.text(
          'A successful update costs 1 Premium point. Your balance: 3 points.',
        ),
        findsOneWidget,
      );
      await tester.enterText(find.byType(TextField), 'Add tofu');
      await tester.tap(find.text('Update recipe · 1 point'));
      await tester.pump();
      expect(service.prompts, ['Add tofu']);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      service.pending!.complete(recipe());
      await tester.pumpAndSettle();
      expect(auth.loads, 1);
      expect(changed!.id, 'recipe');
    },
  );

  testWidgets('zero points disables AI edit while leaving a points entry', (
    tester,
  ) async {
    final auth = _Auth(points: 0);
    addTearDown(auth.dispose);
    await tester.pumpWidget(
      _app(
        auth,
        Builder(
          builder:
              (context) => TextButton(
                onPressed:
                    () => showAiRecipeEditSheet(
                      context,
                      recipe(),
                      service: _Recipes(),
                    ),
                child: const Text('Open'),
              ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Buy points'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
  });
}
