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
import 'package:smart_meal_planner/models/recipe_comment.dart';
import 'package:smart_meal_planner/models/user.dart';
import 'package:smart_meal_planner/providers/auth_provider.dart';
import 'package:smart_meal_planner/screens/recipes/recipe_detail_screen.dart';
import 'package:smart_meal_planner/services/recipe_service.dart';
import 'package:smart_meal_planner/services/api_client.dart';
import 'package:smart_meal_planner/services/recipe_comment_service.dart';
import 'package:smart_meal_planner/widgets/ai_recipe_edit_sheet.dart';
import 'package:smart_meal_planner/widgets/recipe_delete_button.dart';
import 'package:smart_meal_planner/widgets/recipe_publish_button.dart';
import 'package:smart_meal_planner/widgets/submit_recipe_photo_button.dart';
import 'package:smart_meal_planner/theme/app_theme.dart';

Recipe recipe({bool full = true}) => Recipe.fromJson({
  'id': 'recipe',
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
        'quantity': 50,
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
}) => ChangeNotifierProvider<AuthProvider>.value(
  value: auth,
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
                      settings: RouteSettings(arguments: recipe(full: full)),
                      builder:
                          (_) => RecipeDetailScreen(
                            service: service,
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
