import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meal_planner/l10n/app_localizations.dart';
import 'package:smart_meal_planner/models/recipe.dart';
import 'package:smart_meal_planner/models/recipe_import_job.dart';
import 'package:smart_meal_planner/screens/recipes/recipes_screen.dart';
import 'package:smart_meal_planner/services/recipe_service.dart';

class RecordingRecipes extends RecipeService {
  final calls = <Map<String, dynamic>>[];

  @override
  Future<List<RecipeImportJob>> getRecentRecipeImportJobs() async => [];

  @override
  Future<List<Recipe>> getRecipes({
    String? mealType,
    String? planId,
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
    calls.add({
      'meal_type': mealType,
      'difficulty': difficulty,
      'tags': tag,
      'search': search,
      'limit': limit,
      'skip': skip,
    });
    return [];
  }
}

Future<void> showRecipes(
  WidgetTester tester,
  RecordingRecipes service, {
  Locale locale = const Locale('en', 'GB'),
  double textScale = 1,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      builder:
          (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
      home: RecipesScreen(recipeService: service),
    ),
  );
  // The existing trophy uses an intentionally repeating animation.
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  testWidgets('British search and filters retain the canonical API values', (
    tester,
  ) async {
    final service = RecordingRecipes();
    await showRecipes(tester, service);
    expect(find.text('Recipes'), findsOneWidget);
    expect(find.text('No recipes found'), findsOneWidget);
    expect(service.calls.single['limit'], 30);

    await tester.enterText(find.byType(TextField), 'Alice oats');
    await tester.pump(const Duration(milliseconds: 400));
    expect(service.calls.last['search'], 'Alice oats');
    await tester.tap(find.byTooltip('Clear search'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(service.calls.last['search'], '');

    await tester.tap(find.text('More'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Filters'), findsOneWidget);
    final vegetarian = find.widgetWithText(ChoiceChip, 'Vegetarian');
    await tester.ensureVisible(vegetarian);
    await tester.pump();
    await tester.tap(vegetarian);
    final breakfast = find.widgetWithText(ChoiceChip, 'Breakfast');
    await tester.ensureVisible(breakfast);
    await tester.pump();
    await tester.tap(breakfast);
    final easy = find.widgetWithText(ChoiceChip, 'Easy');
    await tester.ensureVisible(easy);
    await tester.pump();
    await tester.tap(easy);
    await tester.ensureVisible(find.text('Show results'));
    await tester.pump();
    await tester.tap(find.text('Show results'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(service.calls.last['meal_type'], 'śniadanie');
    expect(service.calls.last['difficulty'], 'łatwy');
    expect(service.calls.last['tags'], 'wegetariańskie');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final gb in [false, true]) {
    testWidgets(
      'recipe add actions are unchanged and labelled for ${gb ? 'GB' : 'PL'}',
      (tester) async {
        final service = RecordingRecipes();
        await showRecipes(
          tester,
          service,
          locale: gb ? const Locale('en', 'GB') : const Locale('pl', 'PL'),
        );
        await tester.tap(find.text(gb ? 'Add a recipe' : 'Dodaj przepis'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text(gb ? 'Take a photo' : 'Zrób zdjęcie'), findsOneWidget);
        expect(find.text(gb ? 'Paste text' : 'Wklej tekst'), findsOneWidget);
        expect(find.text(gb ? 'Paste a link' : 'Wklej link'), findsOneWidget);
        expect(
          find.text(gb ? 'Add manually' : 'Dodaj ręcznie'),
          findsOneWidget,
        );
        expect(
          find.text(gb ? 'PREMIUM · 2 PTS' : 'PREMIUM · 2 PKT'),
          findsNWidgets(3),
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets(
    'British add sheet remains usable on a narrow screen with larger text',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 568);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await showRecipes(tester, RecordingRecipes(), textScale: 1.5);
      await tester.tap(find.text('Add a recipe'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      for (final label in [
        'Take a photo',
        'Paste text',
        'Paste a link',
        'Add manually',
      ]) {
        final finder = find.text(label);
        await tester.ensureVisible(finder);
        await tester.pump();
        expect(finder.hitTestable(), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
