import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:smart_meal_planner/l10n/app_localizations.dart';
import 'package:smart_meal_planner/l10n/app_localizations_en.dart';
import 'package:smart_meal_planner/models/user.dart';
import 'package:smart_meal_planner/models/store.dart';
import 'package:smart_meal_planner/models/promotion.dart';
import 'package:smart_meal_planner/models/wellness_statistics.dart';
import 'package:smart_meal_planner/providers/auth_provider.dart';
import 'package:smart_meal_planner/providers/store_provider.dart';
import 'package:smart_meal_planner/providers/promotion_provider.dart';
import 'package:smart_meal_planner/services/api_client.dart';
import 'package:smart_meal_planner/services/auth_service.dart';
import 'package:smart_meal_planner/services/ad_gate_service.dart';
import 'package:smart_meal_planner/services/promotion_service.dart';
import 'package:smart_meal_planner/services/wellness_statistics_service.dart';
import 'package:smart_meal_planner/screens/ads/ad_gate_screen.dart';
import 'package:smart_meal_planner/screens/recipes/recipe_leaderboard_screen.dart';
import 'package:smart_meal_planner/screens/profile/statistics_screen.dart';
import 'package:smart_meal_planner/screens/promotions/promotions_screen.dart';

class _Auth extends AuthProvider {
  final User user;
  _Auth(bool english, bool premium)
    : user = User(
        id: 'fixture',
        email: 'synthetic@example.test',
        countryCode: english ? 'GB' : 'PL',
        householdSize: 1,
        createdAt: DateTime(2026, 10, 22),
        isPremium: premium,
      ),
      super(readToken: () async => null);
  @override
  User get currentUser => user;
}

class _Authors extends AuthService {
  int weeklyCalls = 0;
  int allCalls = 0;
  bool failWeekly = false;
  bool empty = false;
  @override
  Future<List<Map<String, dynamic>>> getWeeklyRecipeLeaderboard() async {
    weeklyCalls++;
    if (failWeekly) throw ApiException(503, 'Synthetic failure');
    return empty
        ? []
        : [
          {'display_name': 'Unchanged nick', 'recipe_count': 2},
        ];
  }

  @override
  Future<List<Map<String, dynamic>>> getRecipeLeaderboard() async {
    allCalls++;
    return empty
        ? []
        : [
          {'display_name': 'Other nick', 'recipe_count': 1},
        ];
  }
}

class _Ad extends AdGateService {
  int calls = 0;
  Completer<bool>? pending;
  @override
  Future<bool> showAd() async {
    calls++;
    return pending == null ? false : pending!.future;
  }
}

class _Stats extends WellnessStatisticsService {
  bool fail = false;
  int calls = 0;
  @override
  Future<WellnessStatistics> getStatistics({int days = 30}) async {
    calls++;
    if (fail) throw ApiException(503, 'Synthetic failure');
    final today = DateTime.now();
    return WellnessStatistics(
      days: [
        DailyWellnessStatistics(
          date: today,
          calories: 1800,
          protein: 90,
          fat: 60,
          carbs: 200,
          waterMl: 2000,
        ),
      ],
      weights: [],
      favoriteMeal: 'Owsianka użytkownika',
      averageCalories: 1800,
      averageProtein: 90,
      averageFat: 60,
      averageCarbs: 200,
      averageWaterMl: 2000,
    );
  }
}

Promotion _promotion(String name, String store) => Promotion(
  id: name,
  productName: name,
  storeName: store,
  regularPrice: 5,
  promoPrice: 4,
  promoType: 'price_cut',
  promoDescription: 'Buy two',
  validFrom: DateTime(2026, 10, 1),
  validUntil: DateTime(2026, 11, 1),
  requiresLoyaltyCard: false,
  savings: 1,
  savingsPercent: 20,
);

class _Promotions extends PromotionService {
  final List<Promotion> values;
  Completer<List<Promotion>>? pending;
  int calls = 0;
  _Promotions(this.values);
  @override
  Future<List<Promotion>> getPromotions({
    String? storeName,
    String? search,
  }) async {
    calls++;
    return pending == null ? values : pending!.future;
  }
}

class _Stores extends StoreProvider {
  @override
  List<Store> get stores => [
    for (final name in ['Store A', 'Store B'])
      Store(id: name, name: name, createdAt: DateTime(2026), updatedAt: null),
  ];
}

Future<void> _open(
  WidgetTester tester,
  Widget home, {
  bool english = true,
  bool premium = true,
  double scale = 1,
  PromotionProvider? promotions,
}) async {
  final auth = _Auth(english, premium);
  await auth.initialization;
  final stores = _Stores();
  final promos = promotions ?? PromotionProvider(service: _Promotions([]));
  addTearDown(auth.dispose);
  addTearDown(stores.dispose);
  addTearDown(promos.dispose);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: auth),
        ChangeNotifierProvider<StoreProvider>.value(value: stores),
        ChangeNotifierProvider<PromotionProvider>.value(value: promos),
      ],
      child: MaterialApp(
        locale: english ? const Locale('en', 'GB') : const Locale('pl'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
        builder:
            (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final english in [false, true]) {
    testWidgets('ranking tabs keep counts and names EN=$english', (
      tester,
    ) async {
      final authors = _Authors();
      await _open(
        tester,
        RecipeLeaderboardScreen(service: authors),
        english: english,
      );
      expect(
        find.text(
          english ? 'Recipe author ranking' : 'Ranking autorów przepisów',
        ),
        findsOneWidget,
      );
      expect(find.text('Unchanged nick'), findsOneWidget);
      expect(find.text(english ? '2 recipes' : '2 przepisy'), findsOneWidget);
      await tester.tap(find.text(english ? 'All time' : 'Cały czas'));
      await tester.pumpAndSettle();
      expect(find.text('Other nick'), findsOneWidget);
      expect(find.text(english ? '1 recipe' : '1 przepis'), findsOneWidget);
      expect(authors.weeklyCalls, 1);
      expect(authors.allCalls, 1);
      expect(tester.takeException(), isNull);
    });
    testWidgets('ranking retry only reloads failed tab EN=$english', (
      tester,
    ) async {
      final authors = _Authors()..failWeekly = true;
      await _open(
        tester,
        RecipeLeaderboardScreen(service: authors),
        english: english,
      );
      authors.failWeekly = false;
      await tester.tap(find.text(english ? 'Try again' : 'Spróbuj ponownie'));
      await tester.pumpAndSettle();
      expect(find.text('Unchanged nick'), findsOneWidget);
      expect(authors.weeklyCalls, 2);
      expect(authors.allCalls, 1);
      expect(tester.takeException(), isNull);
    });
    testWidgets(
      'ad gate failure remains retryable and cancel returns false EN=$english',
      (tester) async {
        final ad = _Ad();
        bool? result;
        await _open(
          tester,
          Builder(
            builder:
                (context) => TextButton(
                  onPressed: () async {
                    result = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => AdGateScreen(service: ad),
                      ),
                    );
                  },
                  child: const Text('Open'),
                ),
          ),
          english: english,
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.text(english ? 'Watch advert' : 'Obejrzyj reklamę'),
        );
        await tester.pumpAndSettle();
        expect(ad.calls, 1);
        expect(
          find.textContaining(
            english ? 'Could not load' : 'Nie udało się załadować',
          ),
          findsOneWidget,
        );
        await tester.tap(find.text(english ? 'Not now' : 'Nie teraz'));
        await tester.pumpAndSettle();
        expect(result, false);
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets(
      'statistics localizes chrome without translating user meal EN=$english',
      (tester) async {
        await _open(
          tester,
          StatisticsScreen(service: _Stats()),
          english: english,
          premium: false,
        );
        expect(
          find.text(english ? 'Statistics' : 'Statystyki'),
          findsOneWidget,
        );
        expect(find.text('Owsianka użytkownika'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text(
            english ? 'Full report with Premium' : 'Pełny raport w Premium',
          ),
          180,
          scrollable: find.byType(Scrollable).first,
        );
        expect(
          find.text(
            english ? 'Full report with Premium' : 'Pełny raport w Premium',
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets('statistics failure retry does not lose data EN=$english', (
      tester,
    ) async {
      final stats = _Stats()..fail = true;
      await _open(tester, StatisticsScreen(service: stats), english: english);
      stats.fail = false;
      await tester.tap(find.text(english ? 'Try again' : 'Spróbuj ponownie'));
      await tester.pumpAndSettle();
      expect(stats.calls, 2);
      expect(find.text('1800 kcal'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
    testWidgets('promotion empty state is localized EN=$english', (
      tester,
    ) async {
      await _open(tester, const PromotionsScreen(), english: english);
      expect(find.text(english ? 'Promotions' : 'Promocje'), findsOneWidget);
      expect(
        find.text(
          english
              ? 'No active promotions at the moment.'
              : 'Brak aktywnych promocji w tej chwili.',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'Polish promotion filtering preserves PLN amounts and original names',
    (tester) async {
      final service = _Promotions([
        _promotion('First item', 'Store A'),
        _promotion('Second item', 'Store B'),
      ]);
      await _open(
        tester,
        const PromotionsScreen(),
        english: false,
        promotions: PromotionProvider(service: service),
      );
      expect(find.text('4.00 zł'), findsNWidgets(2));
      await tester.tap(find.text('Store A').first);
      await tester.pumpAndSettle();
      expect(find.text('First item'), findsOneWidget);
      expect(find.text('Second item'), findsNothing);
      expect(service.calls, 1);
      expect(tester.takeException(), isNull);
    },
  );
  for (final english in [false, true]) {
    testWidgets('ranking empty tabs remain distinct EN=$english', (
      tester,
    ) async {
      await _open(
        tester,
        RecipeLeaderboardScreen(service: _Authors()..empty = true),
        english: english,
      );
      expect(
        find.textContaining(english ? 'this week yet.' : 'W tym tygodniu nikt'),
        findsOneWidget,
      );
      await tester.tap(find.text(english ? 'All time' : 'Cały czas'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining(
          english ? 'to the shared catalogue yet.' : 'do wspólnego katalogu.',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
    testWidgets(
      'Premium statistics keeps full insights, quantities and dates EN=$english',
      (tester) async {
        await _open(
          tester,
          StatisticsScreen(service: _Stats()),
          english: english,
        );
        await tester.scrollUntilVisible(
          find.text(
            english
                ? 'Average 1800 kcal per day'
                : 'Średnio 1800 kcal dziennie',
          ),
          150,
          scrollable: find.byType(Scrollable).first,
        );
        expect(
          find.text(
            english ? 'Average 2000 ml of water' : 'Średnio 2000 ml wody',
          ),
          findsOneWidget,
        );
        expect(
          find.text(
            english ? 'Full report with Premium' : 'Pełny raport w Premium',
          ),
          findsNothing,
        );
        final today = DateTime.now();
        final date =
            '${today.day.toString().padLeft(2, '0')}${english ? '/' : '.'}${today.month.toString().padLeft(2, '0')}${english ? '/' : '.'}${today.year}';
        await tester.scrollUntilVisible(
          find.text(date),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(
          find.text(english ? 'Water: 2000 ml' : 'Woda: 2000 ml'),
          findsOneWidget,
        );
        expect(
          find.textContaining(english ? 'P 90.0 g' : 'B 90.0 g'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets('statistics narrow 150% text stays scrollable EN=$english', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _open(
        tester,
        StatisticsScreen(service: _Stats()),
        english: english,
        scale: 1.5,
      );
      await tester.scrollUntilVisible(
        find.text(english ? 'Recently logged days' : 'Ostatnie zapisane dni'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'ad gate awaits one completion and returns true only on success',
    (tester) async {
      final ad = _Ad()..pending = Completer();
      bool? result;
      await _open(
        tester,
        Builder(
          builder:
              (context) => TextButton(
                onPressed: () async {
                  result = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => AdGateScreen(service: ad),
                    ),
                  );
                },
                child: const Text('Open'),
              ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Watch advert'));
      await tester.pump();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Not now'))
            .onPressed,
        isNull,
      );
      ad.pending!.complete(true);
      await tester.pumpAndSettle();
      expect(result, true);
      expect(ad.calls, 1);
      expect(tester.takeException(), isNull);
    },
  );
  test('promotion newest response wins without extra requests', () async {
    final service = _Promotions([])..pending = Completer();
    final provider = PromotionProvider(service: service);
    final older = service.pending!;
    final first = provider.loadPromotions(storeName: 'Old');
    service.pending = Completer();
    final second = provider.loadPromotions(storeName: 'New');
    service.pending!.complete([_promotion('New item', 'New')]);
    await second;
    older.complete([_promotion('Old item', 'Old')]);
    await first;
    expect(provider.promotions.single.productName, 'New item');
    await provider.ensureLoadedForStore('New');
    expect(service.calls, 2);
    provider.dispose();
  });
  test('promotion failure is localized and permits retry', () async {
    final service = _Promotions([])..pending = Completer();
    final provider = PromotionProvider(service: service);
    final load = provider.loadPromotions(strings: AppLocalizationsEnGb());
    service.pending!.completeError(ApiException(503, 'Synthetic failure'));
    await load;
    expect(
      provider.error,
      'The service is temporarily unavailable. Please try again shortly.',
    );
    service.pending = null;
    await provider.loadPromotions(strings: AppLocalizationsEnGb());
    expect(provider.error, isNull);
    expect(provider.isLoading, false);
    provider.dispose();
  });
  test(
    'cleared promotion provider ignores response from previous session',
    () async {
      final service = _Promotions([])..pending = Completer();
      final provider = PromotionProvider(service: service);
      final load = provider.loadPromotions();
      provider.clear();
      service.pending!.complete([_promotion('Stale PLN item', 'Store A')]);
      await load;
      expect(provider.promotions, isEmpty);
      expect(provider.error, isNull);
      provider.dispose();
    },
  );
}
