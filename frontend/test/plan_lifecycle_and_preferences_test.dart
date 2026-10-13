import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:smart_meal_planner/models/user.dart';
import 'package:smart_meal_planner/models/product.dart';
import 'package:smart_meal_planner/models/meal_plan.dart';
import 'package:smart_meal_planner/models/ingredient_preferences.dart';
import 'package:smart_meal_planner/providers/auth_provider.dart';
import 'package:smart_meal_planner/providers/store_provider.dart';
import 'package:smart_meal_planner/providers/meal_plan_provider.dart';
import 'package:smart_meal_planner/services/ingredient_preferences_service.dart';
import 'package:smart_meal_planner/services/product_search_service.dart';
import 'package:smart_meal_planner/services/meal_plan_service.dart';
import 'package:smart_meal_planner/services/api_client.dart';
import 'package:smart_meal_planner/screens/profile/ingredient_preferences_screen.dart';
import 'package:smart_meal_planner/screens/meal_plan/plan_archive_screen.dart';
import 'package:smart_meal_planner/utils/plan_defaults.dart';
import 'package:smart_meal_planner/theme/app_theme.dart';

User _user({bool premium = true, int size = 1, int? kcal}) => User(
  id: 'user',
  email: 'test@example.com',
  householdSize: size,
  dailyKcalGoal: kcal,
  isPremium: premium,
  createdAt: DateTime(2026),
);

MealPlan _plan({
  String id = 'plan',
  String status = 'archived',
  String? start = '2026-10-01',
  String? end = '2026-10-07',
}) => MealPlan(
  id: id,
  userId: 'user',
  storeId: 'store',
  startDate: start,
  endDate: end,
  durationDays: 7,
  mealsPerDay: 3,
  status: status,
  entries: [],
  createdAt: DateTime(2026, 10, 1),
);

class _Auth extends ChangeNotifier implements AuthProvider {
  User? user;
  _Auth(this.user);
  @override
  User? get currentUser => user;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Preferences extends IngredientPreferencesService {
  int loads = 0;
  bool failSave = false;
  IngredientPreferences data;
  _Preferences({this.data = const IngredientPreferences()});
  @override
  Future<IngredientPreferences> load() async {
    loads++;
    return data;
  }

  @override
  Future<IngredientPreferences> save(IngredientPreferences value) async {
    if (failSave) throw ApiException(503, 'Serwer jest chwilowo niedostępny.');
    data = value;
    return data;
  }
}

class _Search extends ProductSearchService {
  @override
  Future<List<Product>> search(String query, {int limit = 20}) async => [
    Product(
      id: 'broccoli',
      name: 'Brokuły',
      unit: 'g',
      defaultQuantity: 500,
      nutritionPer100: NutritionInfo(
        kcal: 34,
        protein: 3,
        carbs: 5,
        fat: 0.4,
        fiber: 3,
      ),
    ),
  ];
}

class _Plans extends MealPlanService {
  int loads = 0;
  int resumes = 0;
  Completer<MealPlan>? resumeCompletion;
  List<MealPlan> archive = [_plan()];
  List<MealPlan> active = [];
  int getPlanFailure = 404;
  @override
  Future<List<MealPlan>> getArchivedPlans() async {
    loads++;
    return archive;
  }

  @override
  Future<List<MealPlan>> getPlans() async => active;
  @override
  Future<MealPlan> getPlan(String id) async =>
      throw ApiException(
        getPlanFailure,
        getPlanFailure == 404
            ? 'Plan zakończony'
            : 'Serwer chwilowo niedostępny',
      );
  @override
  Future<MealPlan> resumePlan(String id, DateTime start) async {
    resumes++;
    return resumeCompletion?.future ??
        Future.value(
          _plan(
            id: 'new',
            status: 'active',
            start: '2026-10-13',
            end: '2026-10-19',
          ),
        );
  }
}

Widget _app(
  Widget screen, {
  required _Auth auth,
  MealPlanProvider? plans,
  double scale = 1,
}) => MultiProvider(
  providers: [
    ChangeNotifierProvider<AuthProvider>.value(value: auth),
    ChangeNotifierProvider<StoreProvider>(create: (_) => StoreProvider()),
    ChangeNotifierProvider<MealPlanProvider>.value(
      value: plans ?? MealPlanProvider(service: _Plans()),
    ),
  ],
  child: MaterialApp(
    theme: _proofTheme(),
    builder:
        (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
    home: RepaintBoundary(key: const ValueKey('plan-ui-proof'), child: screen),
    routes: {
      '/premium': (_) => const Scaffold(body: Text('Premium ekran')),
      '/plan/view': (_) => const Scaffold(body: Text('Wznowiony plan')),
    },
  ),
);

ThemeData _proofTheme() {
  final base = AppTheme.lightTheme;
  if (!const bool.fromEnvironment('CAPTURE_PLAN_UI')) return base;
  ButtonStyle? font(ButtonStyle? style) => style?.copyWith(
    textStyle: WidgetStatePropertyAll(
      style.textStyle?.resolve({})?.copyWith(fontFamily: 'PlanProof'),
    ),
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(fontFamily: 'PlanProof'),
    appBarTheme: base.appBarTheme.copyWith(
      titleTextStyle: base.appBarTheme.titleTextStyle?.copyWith(
        fontFamily: 'PlanProof',
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      labelStyle: base.chipTheme.labelStyle?.copyWith(fontFamily: 'PlanProof'),
      secondaryLabelStyle: base.chipTheme.secondaryLabelStyle?.copyWith(
        fontFamily: 'PlanProof',
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: font(base.filledButtonTheme.style),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: font(base.outlinedButtonTheme.style),
    ),
    textButtonTheme: TextButtonThemeData(
      style: font(base.textButtonTheme.style),
    ),
  );
}

void main() {
  test('ostatni dzień planu włącznie; zakończenie następnego dnia', () {
    final plan = _plan(status: 'active');
    expect(plan.isInUseAt(DateTime(2026, 10, 7, 23, 59)), isTrue);
    expect(plan.isInUseAt(DateTime(2026, 10, 8)), isFalse);
    expect(_plan().isInUseAt(DateTime(2026, 10, 3)), isFalse);
    expect(_plan(end: null).lastDay, DateTime(2026, 10, 7));
  });

  test(
    'przyszły plan nie ma dzisiejszych posiłków, dni liczymy niezależnie od DST',
    () {
      final plan = _plan(
        status: 'active',
        start: '2026-10-24',
        end: '2026-10-30',
      );
      expect(plan.startsAfter(DateTime(2026, 10, 13)), isTrue);
      expect(plan.dayNumberAt(DateTime(2026, 10, 13)), isNull);
      expect(plan.dayNumberAt(DateTime(2026, 10, 25, 20)), 2);
      expect(plan.dayNumberAt(DateTime(2026, 10, 26)), 3);
      expect(plan.dayNumberAt(DateTime(2026, 10, 30)), 7);
      expect(plan.dayNumberAt(DateTime(2026, 10, 31)), isNull);
    },
  );

  test('formularz bierze cel z kalkulatora i ogranicza osoby do ośmiu', () {
    expect(calorieGoalForPlan(_user(kcal: 2340)), 2340);
    expect(calorieGoalForPlan(_user()), 2000);
    expect(calorieGoalForPlan(null), 2000);
    expect(householdSizeForPlan(10), 8);
    expect(householdSizeForPlan(0), 1);
    expect(
      MealPlanGenerateRequest(
        storeId: 's',
        durationDays: 7,
        mealsPerDay: 3,
        householdSize: 10,
      ).toJson()['household_size'],
      8,
    );
  });

  test('nie zostawia poprzedniego planu po 404 innego planu', () async {
    final provider = MealPlanProvider(service: _Plans());
    provider.selectPlan(_plan(id: 'wrong', status: 'active'));
    await provider.loadPlan('ended');
    expect(provider.currentPlan, isNull);
    expect(provider.errorMessage, isNotNull);
    expect(provider.lastPlanLoadNotFound, isTrue);
  });

  test('503 jest błędem pobierania, nie zakończeniem planu', () async {
    final provider = MealPlanProvider(service: _Plans()..getPlanFailure = 503);
    provider.selectPlan(_plan(id: 'wrong', status: 'active'));
    await provider.loadPlan('unavailable');
    expect(provider.currentPlan, isNull);
    expect(provider.errorMessage, isNotNull);
    expect(provider.lastPlanLoadNotFound, isFalse);
  });

  test('wznowienie nie może się wysłać dwa razy naraz', () async {
    final service = _Plans()..resumeCompletion = Completer<MealPlan>();
    final provider = MealPlanProvider(service: service);
    final first = provider.resumePlan('plan', DateTime(2026, 10, 13));
    expect(await provider.resumePlan('plan', DateTime(2026, 10, 13)), isNull);
    expect(service.resumes, 1);
    service.resumeCompletion!.complete(_plan(id: 'resumed', status: 'active'));
    expect((await first)?.id, 'resumed');
    expect(provider.isLoading, isFalse);
  });

  testWidgets(
    'konto standardowe widzi powód blokady i nie pobiera preferencji',
    (tester) async {
      final service = _Preferences();
      await tester.pumpWidget(
        _app(
          IngredientPreferencesScreen(service: service),
          auth: _Auth(_user(premium: false)),
        ),
      );
      await tester.pumpAndSettle();
      expect(service.loads, 0);
      expect(find.text('Zobacz Premium'), findsOneWidget);
      await tester.tap(find.text('Zobacz Premium'));
      await tester.pumpAndSettle();
      expect(find.text('Premium ekran'), findsOneWidget);
    },
  );

  testWidgets(
    'preferencje po zakupie wracają z blokady bez wiecznego ładowania',
    (tester) async {
      final auth = _Auth(_user(premium: false));
      final service = _Preferences();
      await tester.pumpWidget(
        _app(IngredientPreferencesScreen(service: service), auth: auth),
      );
      await tester.pumpAndSettle();
      auth.user = _user();
      auth.notifyListeners();
      await tester.pumpAndSettle();
      expect(service.loads, 1);
      expect(find.text('Szukaj składnika'), findsOneWidget);
    },
  );

  testWidgets(
    '320px, duży tekst, klawiatura: zapis widoczny, błąd nie usuwa wyboru',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = _Preferences()..failSave = true;
      await tester.pumpWidget(
        _app(
          IngredientPreferencesScreen(
            service: service,
            searchService: _Search(),
          ),
          auth: _Auth(_user()),
          scale: 1.5,
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byType(TextField),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(find.byType(TextField), 'bro');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Brokuły'),
        160,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Brokuły'));
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        tester.getBottomRight(find.text('Zapisz preferencje')).dy,
        lessThan(440),
      );
      await tester.tap(find.text('Zapisz preferencje'));
      await tester.pumpAndSettle();
      expect(service.data.liked, isEmpty);
      expect(find.text('Zapisz preferencje'), findsOneWidget);
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, 900),
      );
      await tester.pumpAndSettle();
      expect(find.widgetWithText(InputChip, 'Brokuły'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'archiwum Premium ma podgląd i wznowienie na 320px przy 150% tekstu',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        _app(
          PlanArchiveScreen(service: _Plans()),
          auth: _Auth(_user()),
          scale: 1.5,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Podgląd'), findsOneWidget);
      expect(find.text('Wznów plan'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'archiwum dla standardowego konta pokazuje blokadę bez pobierania',
    (tester) async {
      final service = _Plans();
      await tester.pumpWidget(
        _app(
          PlanArchiveScreen(service: service),
          auth: _Auth(_user(premium: false)),
        ),
      );
      await tester.pumpAndSettle();
      expect(service.loads, 0);
      expect(find.text('Zobacz Premium'), findsOneWidget);
      expect(find.text('Wznów plan'), findsNothing);
    },
  );

  testWidgets(
    'wznowienie wybiera datę, wyjaśnia listę zakupów i otwiera nowy plan',
    (tester) async {
      final service = _Plans();
      await tester.pumpWidget(
        _app(
          PlanArchiveScreen(service: service),
          auth: _Auth(_user()),
          plans: MealPlanProvider(service: service),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Wznów plan'));
      await tester.pumpAndSettle();
      expect(find.text('Od kiedy wznowić plan?'), findsOneWidget);
      await tester.tap(find.text('Wybierz datę'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Utworzymy nową listę zakupów.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Wznów'));
      await tester.pumpAndSettle();
      expect(service.resumes, 1);
      expect(find.text('Wznowiony plan'), findsOneWidget);
    },
  );

  testWidgets('render proof preferences and archive 390px', (tester) async {
    if (const bool.fromEnvironment('CAPTURE_PLAN_UI') && Platform.isWindows) {
      await tester.runAsync(() async {
        final bytes = await File('C:/Windows/Fonts/arial.ttf').readAsBytes();
        final loader = FontLoader('PlanProof')
          ..addFont(Future.value(ByteData.sublistView(bytes)));
        await loader.load();
        final icons =
            await File(
              'C:/Users/AdamCygan/AppData/Local/Temp/flutter-security-audit-20260930/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
            ).readAsBytes();
        final iconLoader = FontLoader('MaterialIcons')
          ..addFont(Future.value(ByteData.sublistView(icons)));
        await iconLoader.load();
      });
    }
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = _Preferences(
      data: const IngredientPreferences(
        liked: [
          IngredientChoice(id: '1', name: 'Brokuły'),
          IngredientChoice(id: '2', name: 'Kurczak'),
        ],
        disliked: [IngredientChoice(id: '3', name: 'Pieczarki')],
      ),
    );
    await tester.pumpWidget(
      _app(IngredientPreferencesScreen(service: service), auth: _Auth(_user())),
    );
    await tester.pumpAndSettle();
    if (const bool.fromEnvironment('CAPTURE_PLAN_UI'))
      await expectLater(
        find.byKey(const ValueKey('plan-ui-proof')),
        matchesGoldenFile('plan-ui-proof/ingredient_preferences.png'),
      );
    await tester.pumpWidget(
      _app(PlanArchiveScreen(service: _Plans()), auth: _Auth(_user())),
    );
    await tester.pumpAndSettle();
    if (const bool.fromEnvironment('CAPTURE_PLAN_UI'))
      await expectLater(
        find.byKey(const ValueKey('plan-ui-proof')),
        matchesGoldenFile('plan-ui-proof/plan_archive.png'),
      );
    expect(tester.takeException(), isNull);
  });
}
