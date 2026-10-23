import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:smart_meal_planner/l10n/app_localizations.dart';
import 'package:smart_meal_planner/models/meal_plan.dart';
import 'package:smart_meal_planner/models/store.dart';
import 'package:smart_meal_planner/models/user.dart';
import 'package:smart_meal_planner/models/weekly_plan_automation.dart';
import 'package:smart_meal_planner/providers/auth_provider.dart';
import 'package:smart_meal_planner/providers/meal_plan_provider.dart';
import 'package:smart_meal_planner/providers/store_provider.dart';
import 'package:smart_meal_planner/screens/meal_plan/plan_archive_screen.dart';
import 'package:smart_meal_planner/screens/meal_plan/weekly_plan_automation_screen.dart';
import 'package:smart_meal_planner/services/api_client.dart';
import 'package:smart_meal_planner/services/meal_plan_service.dart';
import 'package:smart_meal_planner/theme/app_theme.dart';
import '../../helpers/product_form_render.dart';

const _proofKey = ValueKey('plan-management-proof');

ThemeData proofTheme(bool dark) {
  final theme = productFormTheme(dark);
  if (!const bool.fromEnvironment('UK_WRITE_UI_PROOF')) return theme;
  return theme.copyWith(
    appBarTheme: theme.appBarTheme.copyWith(
      titleTextStyle: theme.appBarTheme.titleTextStyle?.copyWith(
        fontFamily: 'UKStage8Proof',
      ),
    ),
  );
}

Future<void> capture(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('UK_WRITE_UI_PROOF')) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_proofKey),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('../docs/uk-stage13/evidence/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}

MealPlan plan({String id = 'archived', String status = 'archived'}) => MealPlan(
  id: id,
  userId: 'user',
  storeId: 'shop',
  startDate: '2026-10-01',
  endDate: '2026-10-07',
  durationDays: 7,
  mealsPerDay: 3,
  status: status,
  entries: [],
  createdAt: DateTime.utc(2026, 10),
);

class _Auth extends ChangeNotifier implements AuthProvider {
  User? user;
  _Auth({bool english = true, bool premium = true})
    : user = User(
        id: 'user',
        email: 'test@example.invalid',
        countryCode: english ? 'GB' : 'PL',
        isPremium: premium,
        householdSize: 1,
        createdAt: DateTime.utc(2026),
      );
  @override
  User? get currentUser => user;
  @override
  dynamic noSuchMethod(Invocation call) => super.noSuchMethod(call);
}

class _Stores extends ChangeNotifier implements StoreProvider {
  @override
  List<Store> get stores => [];
  @override
  dynamic noSuchMethod(Invocation call) => super.noSuchMethod(call);
}

class _Plans extends MealPlanService {
  int loads = 0, saves = 0, runs = 0, resumes = 0;
  bool failLoad = false;
  Completer<WeeklyPlanAutomation>? saving;
  Completer<List<MealPlan>>? archive;
  Map<String, dynamic>? saved;
  DateTime? resumedDate;
  WeeklyPlanAutomation value = const WeeklyPlanAutomation(
    enabled: true,
    weekday: 6,
    hour: 18,
    createShoppingList: true,
  );
  @override
  Future<List<MealPlan>> getArchivedPlans() async {
    loads++;
    return archive?.future ?? [plan()];
  }

  @override
  Future<MealPlan> resumePlan(String id, DateTime startDate) async {
    resumes++;
    resumedDate = startDate;
    return plan(id: 'resumed', status: 'active');
  }

  @override
  Future<WeeklyPlanAutomation> getWeeklyAutomation() async {
    loads++;
    if (failLoad) throw ApiException(503, 'unavailable');
    return value;
  }

  @override
  Future<WeeklyPlanAutomation> saveWeeklyAutomation({
    required bool enabled,
    required int weekday,
    required int hour,
    required bool createShoppingList,
  }) async {
    saves++;
    saved = {
      'enabled': enabled,
      'weekday': weekday,
      'hour': hour,
      'create_shopping_list': createShoppingList,
    };
    return saving?.future ?? value;
  }

  @override
  Future<WeeklyPlanAutomation> runWeeklyAutomationNow() async {
    runs++;
    return saving?.future ?? value;
  }
}

Future<_Auth> _open(
  WidgetTester tester,
  _Plans service, {
  bool english = true,
  bool weekly = false,
  bool premium = true,
  bool narrow = false,
  bool branded = false,
  bool dark = false,
}) async {
  tester.view.physicalSize =
      narrow ? const Size(320, 740) : const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final auth = _Auth(english: english, premium: premium);
  final plans = MealPlanProvider(service: service);
  AppTheme.setDark(dark);
  addTearDown(() => AppTheme.setDark(false));
  addTearDown(auth.dispose);
  addTearDown(plans.dispose);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: auth),
        ChangeNotifierProvider<StoreProvider>(create: (_) => _Stores()),
        ChangeNotifierProvider<MealPlanProvider>.value(value: plans),
      ],
      child: MaterialApp(
        theme: branded ? proofTheme(dark) : null,
        locale: english ? const Locale('en', 'GB') : const Locale('pl', 'PL'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        builder:
            (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(narrow ? 1.5 : 1)),
              child: child!,
            ),
        home: RepaintBoundary(
          key: _proofKey,
          child:
              weekly
                  ? WeeklyPlanAutomationScreen(service: service)
                  : PlanArchiveScreen(service: service),
        ),
        routes: {
          '/premium': (_) => const Scaffold(body: Text('opened Premium')),
          '/plan/view': (_) => const Scaffold(body: Text('opened plan')),
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
  return auth;
}

Future<void> reveal(WidgetTester tester, String text) async {
  await tester.scrollUntilVisible(find.text(text), 250, maxScrolls: 20);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadProductFormFonts);
  for (final english in [true, false]) {
    final market = english ? 'GB' : 'PL';
    testWidgets('archive is localised and resumes the chosen date ($market)', (
      tester,
    ) async {
      final service = _Plans();
      await _open(tester, service, english: english);
      expect(
        find.text(english ? 'Plan archive' : 'Archiwum planów'),
        findsOneWidget,
      );
      expect(
        find.text(english ? '7-day plan' : 'Plan na 7 dni'),
        findsOneWidget,
      );
      expect(
        find.text(
          english ? '01/10/2026 – 07/10/2026' : '01.10.2026 – 07.10.2026',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text(english ? 'Resume plan' : 'Wznów plan'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          english ? 'When should the plan start?' : 'Od kiedy wznowić plan?',
        ),
        findsOneWidget,
      );
      final initial =
          tester
              .widget<DatePickerDialog>(find.byType(DatePickerDialog))
              .initialDate;
      await tester.tap(find.text(english ? 'Choose date' : 'Wybierz datę'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining(
          english
              ? 'We will create a new shopping list.'
              : 'Utworzymy nową listę zakupów.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text(english ? 'Resume' : 'Wznów'));
      await tester.pumpAndSettle();
      expect(service.resumes, 1);
      expect(service.resumedDate, initial);
      expect(find.text('opened plan'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
    testWidgets('archive keeps its Premium gate without fetching ($market)', (
      tester,
    ) async {
      final service = _Plans();
      await _open(tester, service, english: english, premium: false);
      expect(service.loads, 0);
      await tester.tap(find.text(english ? 'See Premium' : 'Zobacz Premium'));
      await tester.pumpAndSettle();
      expect(find.text('opened Premium'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
    testWidgets(
      'weekly settings keep API weekday numbers and localised labels ($market)',
      (tester) async {
        final service = _Plans();
        await _open(tester, service, english: english, weekly: true);
        expect(
          find.text(english ? 'Automatic week' : 'Automatyczny tydzień'),
          findsOneWidget,
        );
        expect(find.text(english ? 'Sunday' : 'Niedziela'), findsOneWidget);
        await tester.tap(find.byType(DropdownButtonFormField<int>));
        await tester.pumpAndSettle();
        await tester.tap(find.text(english ? 'Monday' : 'Poniedziałek').last);
        await tester.pumpAndSettle();
        await reveal(tester, english ? 'Save settings' : 'Zapisz ustawienia');
        await tester.tap(
          find.text(english ? 'Save settings' : 'Zapisz ustawienia'),
        );
        await tester.pumpAndSettle();
        expect(service.saved, {
          'enabled': true,
          'weekday': 0,
          'hour': 18,
          'create_shopping_list': true,
        });
        expect(
          find.text(
            english
                ? 'Automatic week is on.'
                : 'Automatyczny tydzień jest włączony.',
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets('weekly load recovers after a transient error ($market)', (
      tester,
    ) async {
      final service = _Plans()..failLoad = true;
      await _open(tester, service, english: english, weekly: true);
      expect(
        find.text(
          english
              ? 'The service is temporarily unavailable. Please try again shortly.'
              : 'Usługa jest chwilowo niedostępna. Spróbuj ponownie za chwilę.',
        ),
        findsOneWidget,
      );
      service.failLoad = false;
      await tester.tap(find.text(english ? 'Retry' : 'Ponów'));
      await tester.pumpAndSettle();
      expect(service.loads, 2);
      expect(
        find.text(english ? 'Generate automatically' : 'Generuj automatycznie'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
    testWidgets('weekly settings fit a narrow enlarged-text screen ($market)', (
      tester,
    ) async {
      await _open(
        tester,
        _Plans(),
        english: english,
        weekly: true,
        narrow: true,
      );
      expect(tester.takeException(), isNull);
      await reveal(tester, english ? 'Save settings' : 'Zapisz ustawienia');
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('repeated save tap sends only one request', (tester) async {
    final service = _Plans()..saving = Completer<WeeklyPlanAutomation>();
    await _open(tester, service, english: false, weekly: true);
    await reveal(tester, 'Zapisz ustawienia');
    await tester.tap(find.text('Zapisz ustawienia'));
    await tester.tap(find.text('Zapisz ustawienia'));
    expect(service.saves, 1);
    service.saving!.complete(service.value);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('run now is single-flight and reflects server disablement', (
    tester,
  ) async {
    final service = _Plans()..saving = Completer<WeeklyPlanAutomation>();
    await _open(tester, service, weekly: true);
    await reveal(tester, 'Generate now');
    await tester.tap(find.text('Generate now'));
    await tester.tap(find.text('Generate now'));
    expect(service.runs, 1);
    service.saving!.complete(
      const WeeklyPlanAutomation(
        enabled: false,
        weekday: 6,
        hour: 18,
        createShoppingList: true,
        lastError:
            'Premium has expired — weekly automation has been turned off.',
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile).first).value,
      isFalse,
    );
    expect(find.text('Generate now'), findsNothing);
    expect(find.text('Your plan is ready. Find it in Home.'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('closing a pending save does not update a disposed screen', (
    tester,
  ) async {
    final service = _Plans()..saving = Completer<WeeklyPlanAutomation>();
    await _open(tester, service, weekly: true);
    await reveal(tester, 'Save settings');
    await tester.tap(find.text('Save settings'));
    await tester.pumpWidget(const SizedBox());
    service.saving!.complete(service.value);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'archive clears preceding account data and reloads for the new account',
    (tester) async {
      final service = _Plans();
      final auth = await _open(tester, service);
      expect(find.text('7-day plan'), findsOneWidget);
      service.archive = Completer<List<MealPlan>>();
      auth.user = User(
        id: 'other-user',
        email: 'other@example.invalid',
        countryCode: 'GB',
        householdSize: 1,
        isPremium: true,
        createdAt: DateTime.utc(2026),
      );
      auth.notifyListeners();
      await tester.pump();
      await tester.pump();
      expect(find.text('7-day plan'), findsNothing);
      service.archive!.complete([]);
      await tester.pumpAndSettle();
      expect(service.loads, 2);
      expect(find.textContaining('No completed plans yet.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'late archive response cannot replace the current account results',
    (tester) async {
      final service = _Plans();
      final auth = await _open(tester, service);
      final old = Completer<List<MealPlan>>();
      final latest = Completer<List<MealPlan>>();
      void switchAccount(String id, Completer<List<MealPlan>> response) {
        service.archive = response;
        auth.user = User(
          id: id,
          email: '$id@example.invalid',
          countryCode: 'GB',
          householdSize: 1,
          isPremium: true,
          createdAt: DateTime.utc(2026),
        );
        auth.notifyListeners();
      }

      switchAccount('second', old);
      await tester.pump();
      await tester.pump();
      switchAccount('third', latest);
      await tester.pump();
      await tester.pump();
      latest.complete([]);
      await tester.pumpAndSettle();
      old.complete([plan(id: 'previous-private-plan')]);
      await tester.pumpAndSettle();
      expect(service.loads, 3);
      expect(find.text('7-day plan'), findsNothing);
      expect(find.textContaining('No completed plans yet.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  for (final english in [true, false]) {
    for (final dark in [true, false]) {
      testWidgets(
        'weekday dropdown stays usable when open (${english ? 'GB' : 'PL'}, $dark)',
        (tester) async {
          await _open(
            tester,
            _Plans(),
            english: english,
            weekly: true,
            narrow: true,
            branded: true,
            dark: dark,
          );
          await tester.ensureVisible(find.byType(DropdownButtonFormField<int>));
          await tester.pumpAndSettle();
          await tester.tap(find.byType(DropdownButtonFormField<int>));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.tap(find.text(english ? 'Wednesday' : 'Środa').last);
          await tester.pumpAndSettle();
          expect(find.text(english ? 'Wednesday' : 'Środa'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await capture(
            tester,
            'weekly-${english ? 'gb' : 'pl'}-320-150-${dark ? 'dark' : 'light'}',
          );
        },
      );
    }
  }
}
