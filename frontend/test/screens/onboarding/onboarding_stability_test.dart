import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:smart_meal_planner/l10n/app_localizations.dart';
import 'package:smart_meal_planner/models/store.dart';
import 'package:smart_meal_planner/providers/auth_provider.dart';
import 'package:smart_meal_planner/providers/store_provider.dart';
import 'package:smart_meal_planner/screens/onboarding/onboarding_screen.dart';

class _Auth extends ChangeNotifier implements AuthProvider {
  int saveCalls = 0;
  int savedHousehold = 0;
  List<String> savedAllergens = [];
  String? savedStore;
  final pendingSave = Completer<bool>();
  @override
  int get lastBonusPoints => 0;
  @override
  String? get errorMessage => null;
  @override
  Future<bool> saveOnboardingPreferences({
    required String storeId,
    required List<String> allergenIds,
    required String diet,
    required int householdSize,
    double? weightKg,
    double? heightCm,
    int? dailyKcalGoal,
  }) {
    saveCalls++;
    savedHousehold = householdSize;
    savedStore = storeId;
    savedAllergens = List.of(allergenIds);
    return pendingSave.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Stores extends ChangeNotifier implements StoreProvider {
  _Stores({this.slow = false});
  final bool slow;
  final pending = Completer<void>();
  int calls = 0;
  bool loading = false;
  bool empty = false;
  String? error;
  @override
  List<Store> get stores =>
      error != null || loading || empty
          ? []
          : [
            Store(
              id: 'synthetic-store',
              name: 'Synthetic shop',
              createdAt: DateTime(2026),
              updatedAt: null,
            ),
          ];
  @override
  bool get isLoading => loading;
  @override
  String? get errorMessage => error;
  @override
  Future<void> loadStores() async {
    calls++;
    if (calls > 1) {
      error = null;
      empty = false;
      notifyListeners();
      return;
    }
    if (!slow) return;
    loading = true;
    notifyListeners();
    await pending.future;
    loading = false;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Routes extends NavigatorObserver {
  int homes = 0;
  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (newRoute?.settings.name == '/home') homes++;
  }
}

Future<void> _open(
  WidgetTester tester,
  bool english,
  _Auth auth,
  _Stores stores,
  _Routes routes,
) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: auth),
        ChangeNotifierProvider<StoreProvider>.value(value: stores),
      ],
      child: MaterialApp(
        locale: english ? const Locale('en', 'GB') : const Locale('pl'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        navigatorObservers: [routes],
        routes: {'/home': (_) => const Scaffold(body: Text('synthetic-home'))},
        home: const OnboardingScreen(),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _toDone(WidgetTester tester, bool english) async {
  final next = find.widgetWithText(ElevatedButton, english ? 'Next' : 'Dalej');
  for (var page = 0; page < 6; page++) {
    await tester.tap(next);
    await tester.pumpAndSettle();
    if (page == 0) {
      await tester.tap(find.text('Gluten'));
      await tester.pumpAndSettle();
    }
    if (page == 2) {
      final increase = find.byIcon(Icons.add);
      await tester.ensureVisible(increase);
      await tester.pumpAndSettle();
      expect(increase.hitTestable(), findsOneWidget);
      await tester.tap(increase);
      await tester.pump();
    }
    if (page == 4) {
      final pantryAction = find.text(
        english ? 'Add products to your pantry' : 'Dodaj produkty do spiżarni',
      );
      await tester.ensureVisible(pantryAction);
      await tester.pumpAndSettle();
      expect(pantryAction.hitTestable(), findsOneWidget);
    }
  }
  expect(
    find.widgetWithText(ElevatedButton, english ? 'Done!' : 'Gotowe!'),
    findsOneWidget,
  );
}

void main() {
  for (final english in [false, true]) {
    for (final empty in [false, true]) {
      testWidgets(
        'store ${empty ? 'empty' : 'failure'} can retry and select EN=$english',
        (tester) async {
          final auth = _Auth();
          final stores = _Stores()..empty = empty;
          if (!empty) stores.error = 'Synthetic unavailable';
          addTearDown(auth.dispose);
          addTearDown(stores.dispose);
          await _open(tester, english, auth, stores, _Routes());
          await tester.pumpAndSettle();
          expect(find.text('Synthetic shop'), findsNothing);
          await tester.tap(
            find.widgetWithText(
              OutlinedButton,
              english ? 'Try again' : 'Spróbuj ponownie',
            ),
          );
          await tester.pumpAndSettle();
          expect(stores.calls, 2);
          await tester.tap(find.text('Synthetic shop'));
          await tester.pump();
          await _toDone(tester, english);
          await tester.tap(
            find.widgetWithText(ElevatedButton, english ? 'Done!' : 'Gotowe!'),
          );
          expect(auth.savedStore, 'synthetic-store');
          auth.pendingSave.complete(true);
          await tester.pumpAndSettle();
          expect(find.text('synthetic-home'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }

    testWidgets(
      'seven steps stay usable at 360x640 with system bars EN=$english',
      (tester) async {
        final auth = _Auth();
        final stores = _Stores();
        addTearDown(auth.dispose);
        addTearDown(stores.dispose);
        await _open(tester, english, auth, stores, _Routes());
        tester.view.physicalSize = const Size(360, 640);
        tester.view.padding = const FakeViewPadding(top: 44, bottom: 24);
        tester.view.viewPadding = const FakeViewPadding(top: 44, bottom: 24);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Synthetic shop'));
        await tester.pump();
        await _toDone(tester, english);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );

    testWidgets(
      'seven steps submit once and preserve progress while saving EN=$english',
      (tester) async {
        final auth = _Auth();
        final stores = _Stores();
        final routes = _Routes();
        addTearDown(auth.dispose);
        addTearDown(stores.dispose);
        await _open(tester, english, auth, stores, routes);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Synthetic shop'));
        await tester.pump();
        await _toDone(tester, english);
        final done = find.widgetWithText(
          ElevatedButton,
          english ? 'Done!' : 'Gotowe!',
        );
        // Two taps before a rebuild must still start exactly one transaction.
        await tester.tap(done);
        await tester.tap(done);
        await tester.pump();
        expect(auth.saveCalls, 1);
        expect(tester.widget<ElevatedButton>(done).onPressed, isNull);
        expect(
          tester
              .widget<TextButton>(
                find.widgetWithText(TextButton, english ? 'Back' : 'Wstecz'),
              )
              .onPressed,
          isNull,
        );
        await tester.binding.handlePopRoute();
        await tester.pump(const Duration(milliseconds: 400));
        expect(done, findsOneWidget);

        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        tester.view.padding = const FakeViewPadding(top: 44, bottom: 24);
        tester.view.viewPadding = const FakeViewPadding(top: 44, bottom: 24);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();
        expect(done, findsOneWidget);
        expect(auth.savedStore, 'synthetic-store');
        expect(auth.savedAllergens, ['gluten']);
        expect(auth.savedHousehold, 2);
        auth.pendingSave.complete(true);
        await tester.pumpAndSettle();
        expect(find.text('synthetic-home'), findsOneWidget);
        expect(routes.homes, 1);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );

    testWidgets(
      'slow failed store loading stays recoverable without a save EN=$english',
      (tester) async {
        final auth = _Auth();
        final stores = _Stores(slow: true);
        addTearDown(auth.dispose);
        addTearDown(stores.dispose);
        await _open(tester, english, auth, stores, _Routes());
        expect(stores.calls, 1);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        stores.error = 'Synthetic unavailable';
        stores.pending.complete();
        await tester.pumpAndSettle();
        expect(find.textContaining('Synthetic unavailable'), findsOneWidget);
        await _toDone(tester, english);
        await tester.tap(
          find.widgetWithText(ElevatedButton, english ? 'Done!' : 'Gotowe!'),
        );
        await tester.pump();
        expect(auth.saveCalls, 0);
        expect(find.byType(SnackBar), findsOneWidget);
        await tester.tap(
          find.widgetWithText(TextButton, english ? 'Back' : 'Wstecz'),
        );
        await tester.pumpAndSettle();
        expect(
          find.widgetWithText(ElevatedButton, english ? 'Next' : 'Dalej'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );

    testWidgets('failed save re-enables completion EN=$english', (
      tester,
    ) async {
      final auth = _Auth();
      final stores = _Stores();
      addTearDown(auth.dispose);
      addTearDown(stores.dispose);
      await _open(tester, english, auth, stores, _Routes());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Synthetic shop'));
      await tester.pump();
      await _toDone(tester, english);
      final done = find.widgetWithText(
        ElevatedButton,
        english ? 'Done!' : 'Gotowe!',
      );
      await tester.tap(done);
      auth.pendingSave.complete(false);
      await tester.pumpAndSettle();
      expect(tester.widget<ElevatedButton>(done).onPressed, isNotNull);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
