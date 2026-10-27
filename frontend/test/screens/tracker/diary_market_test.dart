import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:smart_meal_planner/l10n/app_localizations.dart';
import 'package:smart_meal_planner/models/food_log.dart';
import 'package:smart_meal_planner/providers/food_log_provider.dart';
import 'package:smart_meal_planner/providers/wellness_provider.dart';
import 'package:smart_meal_planner/screens/tracker/calorie_tracker_screen.dart';
import 'package:smart_meal_planner/services/wellness_service.dart';

class Logs extends FoodLogProvider {
  DateTime selected = DateTime.now();
  final List<DateTime> requests = [];
  List<FoodLogEntry> entries = [];
  final updates = <Map<String, dynamic>>[];
  @override
  DateTime get currentDate => selected;
  @override
  List<FoodLogEntry> get logs => entries;
  @override
  String? get error => null;
  @override
  bool get isLoading => false;
  @override
  Future<void> fetchLogsForDate(DateTime date) async {
    selected = date;
    requests.add(date);
  }

  @override
  void setDate(DateTime date) {
    selected = date;
    requests.add(date);
    notifyListeners();
  }

  @override
  Future<bool> updateEntryNutrition(
    String logId, {
    required double calories,
    required double protein,
    required double fat,
    required double carbs,
    double? servings,
    double? amountValue,
    String? amountUnit,
    double? portionSize,
    String? portionUnit,
  }) async {
    updates.add({
      'id': logId,
      'calories': calories,
      'amount': amountValue,
      'unit': amountUnit,
      'portionSize': portionSize,
      'portionUnit': portionUnit,
    });
    return true;
  }
}

class Wellness extends WellnessProvider {
  int waterMl = 0;
  final List<DateTime> requests = [];
  int added = 0;
  final waters = <int>[];
  @override
  bool get hasLoaded => true;
  @override
  bool get isLoading => false;
  @override
  DailyWellness get data => DailyWellness(
    waterMl: waterMl,
    waterGoalMl: 2000,
    activities: const [],
    totalKcalBurned: 0,
  );
  @override
  Future<void> loadForDate(DateTime date) async {
    requests.add(date);
  }

  @override
  Future<bool> addActivity({
    required String name,
    required int kcalBurned,
    int? durationMin,
  }) async {
    added++;
    return true;
  }

  @override
  Future<void> addWater(int amountMl) async {
    waters.add(amountMl);
  }
}

Future<(Logs, Wellness)> openDiary(
  WidgetTester tester,
  Locale locale, {
  bool withFood = false,
  double textScale = 1,
  int waterMl = 0,
}) async {
  final logs = Logs(), wellness = Wellness();
  wellness.waterMl = waterMl;
  addTearDown(logs.dispose);
  addTearDown(wellness.dispose);
  if (withFood) {
    logs.entries = [
      FoodLogEntry(
        id: 'item',
        userId: 'user',
        date: DateTime.now(),
        mealType: 'Śniadanie',
        customName: 'Milk bottle',
        servings: 1,
        calories: 200,
        protein: 10,
        carbs: 20,
        fat: 8,
        amountValue: 1,
        amountUnit: 'opak',
        portionSize: 500,
        portionUnit: 'ml',
      ),
    ];
  }
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<FoodLogProvider>.value(value: logs),
        ChangeNotifierProvider<WellnessProvider>.value(value: wellness),
      ],
      child: MaterialApp(
        theme:
            const bool.fromEnvironment('PARITY_UI_PROOF')
                ? ThemeData(fontFamily: 'ParityProof')
                : null,
        builder:
            (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!,
            ),
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: const RepaintBoundary(
          key: ValueKey('diary-parity-proof'),
          child: CalorieTrackerScreen(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (logs, wellness);
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('en_GB');
    if (const bool.fromEnvironment('PARITY_UI_PROOF')) {
      await (FontLoader('ParityProof')..addFont(
        File(
          'C:/Windows/Fonts/arial.ttf',
        ).readAsBytes().then(ByteData.sublistView),
      )).load();
      await (FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    }
  });
  for (final locale in [const Locale('en', 'GB'), const Locale('pl', 'PL')]) {
    testWidgets(
      'water controls retain internal padding at 320px / 150% $locale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 1100);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await openDiary(tester, locale, textScale: 1.5, waterMl: 750);
        final label = find.text(
          locale.languageCode == 'en' ? 'Custom amount' : 'Inna ilość',
        );
        await tester.ensureVisible(label);
        final button =
            find
                .ancestor(of: label, matching: find.byType(OutlinedButton))
                .first;
        final labelRect = tester.getRect(label),
            buttonRect = tester.getRect(button);
        expect(labelRect.left, greaterThanOrEqualTo(buttonRect.left + 10));
        expect(labelRect.right, lessThanOrEqualTo(buttonRect.right - 10));
        expect(tester.takeException(), isNull);
        if (const bool.fromEnvironment('PARITY_UI_PROOF')) {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const ValueKey('diary-parity-proof')),
          );
          await tester.runAsync(() async {
            final bitmap = await boundary.toImage(pixelRatio: 1);
            final png = await bitmap.toByteData(format: ui.ImageByteFormat.png);
            final file = File(
              '../docs/audit/parity-ui/diary-${locale.languageCode}-320-text150.png',
            );
            await file.parent.create(recursive: true);
            await file.writeAsBytes(png!.buffer.asUint8List());
            bitmap.dispose();
          });
        }
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  testWidgets(
    'GB diary uses English labels and moves both providers to selected day',
    (tester) async {
      final (logs, wellness) = await openDiary(
        tester,
        const Locale('en', 'GB'),
      );
      expect(find.text('Calorie diary'), findsOneWidget);
      expect(
        find.text(
          'Today, ${DateFormat('dd MMMM yyyy', 'en_GB').format(logs.currentDate)}',
        ),
        findsOneWidget,
      );
      expect(find.text('kcal remaining'), findsOneWidget);
      final today = logs.currentDate;
      await tester.tap(find.byTooltip('Previous day'));
      await tester.pumpAndSettle();
      expect(logs.currentDate.day, today.subtract(const Duration(days: 1)).day);
      expect(wellness.requests.last, logs.currentDate);
      expect(find.text('Back to today'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('PL diary retains existing labels', (tester) async {
    await openDiary(tester, const Locale('pl', 'PL'));
    expect(find.text('Dziennik kalorii'), findsOneWidget);
    expect(find.text('kcal pozostało'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'activity dialog can close after entry without disposing a live controller',
    (tester) async {
      final (_, wellness) = await openDiary(tester, const Locale('en', 'GB'));
      await tester.ensureVisible(find.text('Add activity'));
      await tester.tap(find.text('Add activity'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0), 'Cycling');
      await tester.enterText(find.byType(TextField).at(1), '120');
      await tester.tap(find.widgetWithText(FilledButton, 'Add'));
      await tester.pumpAndSettle();
      expect(wellness.added, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'English quantity labels keep original meals, pack size and API unit',
    (tester) async {
      final (logs, _) = await openDiary(
        tester,
        const Locale('en', 'GB'),
        withFood: true,
      );
      await tester.scrollUntilVisible(
        find.text('Milk bottle'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Breakfast'), findsOneWidget);
      expect(find.text('1 pack · 1 pack = 500 ml'), findsOneWidget);
      await tester.tap(find.text('Milk bottle'));
      await tester.pumpAndSettle();
      expect(find.text('Edit amount'), findsOneWidget);
      expect(find.text('1 pack = 500 ml'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), '2');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(logs.updates.single, {
        'id': 'item',
        'calories': 400.0,
        'amount': 2.0,
        'unit': 'opak',
        'portionSize': 500.0,
        'portionUnit': 'ml',
      });
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('invalid diary quantity is rejected without saving or crashing', (
    tester,
  ) async {
    final (logs, _) = await openDiary(
      tester,
      const Locale('en', 'GB'),
      withFood: true,
    );
    await tester.scrollUntilVisible(
      find.text('Milk bottle'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Milk bottle'));
    await tester.pumpAndSettle();
    for (final value in ['NaN', 'Infinity', '1e999']) {
      await tester.enterText(find.byType(TextFormField), value);
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pump();
      expect(logs.updates, isEmpty);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('water dialog closes safely and retains millilitres', (
    tester,
  ) async {
    final (_, wellness) = await openDiary(tester, const Locale('en', 'GB'));
    await tester.ensureVisible(find.text('Custom amount'));
    await tester.tap(find.text('Custom amount'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '300');
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();
    expect(wellness.waters, [300]);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
