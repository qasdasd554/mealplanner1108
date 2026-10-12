import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_meal_planner/data/recipe_photo_map.dart';
import 'package:smart_meal_planner/models/food_log.dart';
import 'package:smart_meal_planner/models/meal_plan.dart';
import 'package:smart_meal_planner/models/recipe.dart';
import 'package:smart_meal_planner/models/store.dart';
import 'package:smart_meal_planner/models/user.dart';
import 'package:smart_meal_planner/providers/auth_provider.dart';
import 'package:smart_meal_planner/providers/food_log_provider.dart';
import 'package:smart_meal_planner/providers/meal_plan_provider.dart';
import 'package:smart_meal_planner/providers/store_provider.dart';
import 'package:smart_meal_planner/providers/wellness_provider.dart';
import 'package:smart_meal_planner/screens/home/home_screen.dart';
import 'package:smart_meal_planner/screens/tracker/calorie_tracker_screen.dart';
import 'package:smart_meal_planner/services/wellness_service.dart';
import 'package:smart_meal_planner/theme/app_theme.dart';
import 'package:smart_meal_planner/widgets/planner_components.dart';

class _Auth extends ChangeNotifier implements AuthProvider {
  @override
  User get currentUser => User(
    id: 'fixture',
    email: 'fixture@example.test',
    displayName: 'Anna',
    householdSize: 1,
    createdAt: DateTime(2026),
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Recipe _recipe(int i) => Recipe.fromJson({
  'id': 'r$i',
  'name': kRecipePhotoAssets.keys.elementAt(i),
  'servings': 2,
  'prep_time_min': 25,
  'difficulty': 'łatwy',
  'nutrition_total': {'kcal': 840},
});

class _Plans extends ChangeNotifier implements MealPlanProvider {
  final _plan = MealPlan(
    id: 'p',
    userId: 'u',
    storeId: 's',
    durationDays: 7,
    mealsPerDay: 3,
    status: 'active',
    createdAt: DateTime.now(),
    entries: List.generate(
      3,
      (i) => MealPlanEntry(
        id: 'e$i',
        mealPlanId: 'p',
        recipeId: 'r$i',
        recipe: _recipe(i),
        dayNumber: 1,
        mealSlot: ['Śniadanie', 'Obiad', 'Kolacja'][i],
        servingsMultiplier: 1,
      ),
    ),
  );
  @override
  MealPlan get currentPlan => _plan;
  @override
  MealPlan get activePlan => _plan;
  @override
  List<MealPlan> get plans => [_plan];
  @override
  List<MealPlan> get activePlans => [_plan];
  @override
  bool get isLoading => false;
  @override
  bool get hasLoaded => true;
  @override
  String? get errorMessage => null;
  @override
  Future<void> loadPlans() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Food extends ChangeNotifier implements FoodLogProvider {
  @override
  DateTime get currentDate => DateTime.now();
  @override
  bool get isLoading => false;
  @override
  String? get error => null;
  @override
  DailySummary get summary => DailySummary(
    date: currentDate,
    totalCalories: 1350,
    totalProtein: 82,
    totalCarbs: 165,
    totalFat: 40,
    targetCalories: 2000,
  );
  @override
  List<FoodLogEntry> get logs => [
    FoodLogEntry(
      id: 'entry',
      userId: 'fixture',
      date: currentDate,
      mealType: 'śniadanie',
      customName: 'Jogurt naturalny z owocami',
      servings: 1,
      calories: 340,
      protein: 18,
      carbs: 42,
      fat: 11,
      amountValue: 250,
      amountUnit: 'g',
      portionSize: 250,
      portionUnit: 'g',
    ),
  ];
  @override
  Future<void> fetchLogsForDate(DateTime date) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Wellness extends ChangeNotifier implements WellnessProvider {
  @override
  bool get hasLoaded => true;
  @override
  bool get isLoading => false;
  @override
  String? get errorMessage => null;
  @override
  int get kcalBurned => 0;
  @override
  DailyWellness get data => DailyWellness(
    waterMl: 1200,
    waterGoalMl: 2000,
    activities: [],
    totalKcalBurned: 0,
  );
  @override
  Future<void> loadForDate(DateTime date) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Stores extends ChangeNotifier implements StoreProvider {
  @override
  List<Store> get stores => [];
  @override
  Future<void> loadStores() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() async {
    final font = Platform.environment['UI_FONT_PATH'];
    if (font != null) {
      final loader = FontLoader('UiPreview');
      loader.addFont(
        Future.value(ByteData.sublistView(await File(font).readAsBytes())),
      );
      await loader.load();
      final icons = Platform.environment['UI_ICON_FONT_PATH'];
      if (icons != null) {
        final iconLoader = FontLoader('MaterialIcons');
        iconLoader.addFont(
          Future.value(ByteData.sublistView(await File(icons).readAsBytes())),
        );
        await iconLoader.load();
      }
    }
  });

  Future<void> open(
    WidgetTester tester,
    Widget screen,
    double width,
    double scale,
    bool dark,
    GlobalKey boundaryKey,
  ) async {
    SharedPreferences.setMockInitialValues({});
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      AppTheme.setDark(false);
      await tester.binding.setSurfaceSize(null);
    });
    AppTheme.setDark(dark);
    await tester.binding.setSurfaceSize(Size(width, 900));
    var theme = dark ? AppTheme.darkTheme : AppTheme.lightTheme;
    if (Platform.environment['UI_FONT_PATH'] != null) {
      ButtonStyle? previewStyle(ButtonStyle? value) => value?.copyWith(
        textStyle: WidgetStatePropertyAll(
          (value.textStyle?.resolve({}) ?? const TextStyle()).copyWith(
            fontFamily: 'UiPreview',
          ),
        ),
      );
      theme = theme.copyWith(
        textTheme: theme.textTheme.apply(fontFamily: 'UiPreview'),
        primaryTextTheme: theme.primaryTextTheme.apply(fontFamily: 'UiPreview'),
        appBarTheme: theme.appBarTheme.copyWith(
          titleTextStyle: theme.appBarTheme.titleTextStyle?.copyWith(
            fontFamily: 'UiPreview',
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: previewStyle(theme.textButtonTheme.style),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: previewStyle(theme.filledButtonTheme.style),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: previewStyle(theme.elevatedButtonTheme.style),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: previewStyle(theme.outlinedButtonTheme.style),
        ),
        chipTheme: theme.chipTheme.copyWith(
          labelStyle: theme.chipTheme.labelStyle?.copyWith(
            fontFamily: 'UiPreview',
          ),
        ),
      );
    }
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>(create: (_) => _Auth()),
          ChangeNotifierProvider<MealPlanProvider>(create: (_) => _Plans()),
          ChangeNotifierProvider<StoreProvider>(create: (_) => _Stores()),
          ChangeNotifierProvider<FoodLogProvider>(create: (_) => _Food()),
          ChangeNotifierProvider<WellnessProvider>(create: (_) => _Wellness()),
        ],
        child: MaterialApp(
          theme: theme,
          builder:
              (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(scale),
                  disableAnimations: true,
                ),
                child: RepaintBoundary(key: boundaryKey, child: child!),
              ),
          home: screen,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
    final directory = Platform.environment['UI_CAPTURE_DIR'];
    if (directory == null) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 250)),
    );
    await tester.pump();
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final picture = await boundary.toImage(pixelRatio: 2);
      final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
      await Directory(directory).create(recursive: true);
      await File(
        '$directory/$name.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      picture.dispose();
    });
  }

  for (final dark in [false, true]) {
    testWidgets('Premium and recipe components render together / dark $dark', (
      tester,
    ) async {
      final key = GlobalKey();
      await open(
        tester,
        Scaffold(
          appBar: AppBar(title: const Text('Premium')),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const PremiumBenefitPreview(),
                const SizedBox(height: 24),
                PremiumPlanCard(
                  title: 'Premium miesięczne',
                  price: '24,99 zł',
                  period: '/ miesiąc',
                  hasTrial: true,
                  highlight: true,
                  onTap: () {},
                ),
              ],
            ),
          ),
        ),
        390,
        1,
        dark,
        key,
      );
      expect(tester.takeException(), isNull);
      await capture(tester, key, 'premium-${dark ? 'dark' : 'light'}');
      await open(
        tester,
        Scaffold(
          appBar: AppBar(title: const Text('Przepisy')),
          body: GridView.builder(
            padding: const EdgeInsets.all(20),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 16,
              mainAxisExtent: 265,
            ),
            itemCount: 6,
            itemBuilder:
                (_, i) => RecipeLibraryCard(recipe: _recipe(i), onTap: () {}),
          ),
        ),
        390,
        1,
        dark,
        key,
      );
      expect(tester.takeException(), isNull);
      await capture(tester, key, 'recipes-${dark ? 'dark' : 'light'}');
    });
    for (final scale in [1.0, 1.6]) {
      for (final screen in ['start', 'journal']) {
        testWidgets(
          '$screen fits on narrow mobile, scale $scale / dark $dark',
          (tester) async {
            final key = GlobalKey();
            await open(
              tester,
              screen == 'start'
                  ? const HomeScreen()
                  : const CalorieTrackerScreen(),
              scale == 1 ? 390 : 320,
              scale,
              dark,
              key,
            );
            expect(tester.takeException(), isNull);
            if (scale == 1)
              await capture(tester, key, '$screen-${dark ? 'dark' : 'light'}');
            if (screen == 'journal') {
              await tester.scrollUntilVisible(
                find.byType(DiaryEntryRow),
                200,
                scrollable: find.byType(Scrollable).first,
              );
              expect(tester.takeException(), isNull);
              await tester.ensureVisible(find.byTooltip('Usuń z Dziennika'));
              await tester.pumpAndSettle();
              await tester.tap(find.byTooltip('Usuń z Dziennika'));
              await tester.pumpAndSettle();
              expect(find.text('Usunąć posiłek?'), findsOneWidget);
              await tester.tap(find.text('Anuluj'));
              await tester.pumpAndSettle();
              expect(find.byType(DiaryEntryRow), findsOneWidget);
            } else {
              await tester.tap(find.text('Dodaj'));
              await tester.pumpAndSettle();
              expect(find.text('Dodaj przepis z AI'), findsOneWidget);
              expect(tester.takeException(), isNull);
            }
            await tester.pumpWidget(const SizedBox());
            await tester.pump();
            AppTheme.setDark(false);
            await tester.binding.setSurfaceSize(null);
          },
        );
      }
    }
  }
}
