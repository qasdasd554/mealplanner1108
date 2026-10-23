import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:smart_meal_planner/l10n/app_localizations.dart';
import 'package:smart_meal_planner/models/user.dart';
import 'package:smart_meal_planner/providers/auth_provider.dart';
import 'package:smart_meal_planner/screens/tracker/calorie_calculator_screen.dart';
import 'package:smart_meal_planner/services/auth_service.dart';
import 'package:smart_meal_planner/services/api_client.dart';
import 'package:smart_meal_planner/theme/app_theme.dart';

class _Auth extends ChangeNotifier implements AuthProvider {
  final bool english;
  Map<Symbol, dynamic>? saved;
  _Auth({this.english = true});
  @override
  User get currentUser => User(
    id: 'actor',
    email: 'test@example.invalid',
    countryCode: english ? 'GB' : 'PL',
    householdSize: 2,
    createdAt: DateTime.utc(2026),
    weightKg: 70,
    heightCm: 175,
    age: 30,
    gender: 'female',
    activityLevel: 'moderate',
  );
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #updateProfile) {
      saved = invocation.namedArguments;
      return Future<bool>.value(true);
    }
    return super.noSuchMethod(invocation);
  }
}

class _Calculator extends AuthService {
  Map<String, dynamic>? requested;
  bool fail = false;
  @override
  Future<Map<String, int>> calculateCalorieNeeds({
    required double weightKg,
    required double heightCm,
    required int age,
    required String gender,
    required String activityLevel,
  }) async {
    requested = {
      'weight_kg': weightKg,
      'height_cm': heightCm,
      'age': age,
      'gender': gender,
      'activity_level': activityLevel,
    };
    if (fail) throw ApiException(503, 'Synthetic service failure');
    return {'maintenance': 2200, 'weight_loss': 1700, 'weight_gain': 2700};
  }
}

Future<void> _open(
  WidgetTester tester,
  _Auth auth,
  _Calculator service, {
  bool narrow = false,
}) async {
  if (narrow) {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }
  await tester.pumpWidget(
    ChangeNotifierProvider<AuthProvider>.value(
      value: auth,
      child: MaterialApp(
        theme: proofTheme(),
        locale:
            auth.english ? const Locale('en', 'GB') : const Locale('pl', 'PL'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        builder:
            (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(narrow ? 1.5 : 1)),
              child: child!,
            ),
        home: Builder(
          builder:
              (context) => Scaffold(
                body: TextButton(
                  onPressed:
                      () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder:
                              (_) => RepaintBoundary(
                                key: const ValueKey('calculator-proof'),
                                child: CalorieCalculatorScreen(
                                  service: service,
                                ),
                              ),
                        ),
                      ),
                  child: const Text('Open existing calculator'),
                ),
              ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open existing calculator'));
  await tester.pumpAndSettle();
}

ThemeData proofTheme() {
  final base = AppTheme.lightTheme;
  if (!const bool.fromEnvironment('CAPTURE_UK15')) return base;
  ButtonStyle? font(ButtonStyle? style) => style?.copyWith(
    textStyle: WidgetStatePropertyAll(
      (style.textStyle?.resolve({}) ?? base.textTheme.labelLarge!).copyWith(
        fontFamily: 'UK15Proof',
      ),
    ),
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(fontFamily: 'UK15Proof'),
    appBarTheme: base.appBarTheme.copyWith(
      titleTextStyle: base.appBarTheme.titleTextStyle?.copyWith(
        fontFamily: 'UK15Proof',
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: font(base.filledButtonTheme.style),
    ),
    textButtonTheme: TextButtonThemeData(
      style: font(base.textButtonTheme.style),
    ),
  );
}

void main() {
  setUpAll(() async {
    if (const bool.fromEnvironment('CAPTURE_UK15')) {
      final font = Platform.environment['UK15_QA_FONT'];
      if (font == null) {
        throw StateError('Set UK15_QA_FONT to an existing local font file.');
      }
      final bytes = await File(font).readAsBytes();
      await (FontLoader('UK15Proof')
        ..addFont(Future.value(ByteData.sublistView(bytes)))).load();
      final icons = Platform.environment['UK15_QA_ICONS'];
      if (icons == null) {
        throw StateError(
          'Set UK15_QA_ICONS to the existing MaterialIcons font.',
        );
      }
      final iconBytes = await File(icons).readAsBytes();
      await (FontLoader('MaterialIcons')
        ..addFont(Future.value(ByteData.sublistView(iconBytes)))).load();
    }
  });
  if (const bool.fromEnvironment('CAPTURE_UK15')) {
    for (final english in [true, false]) {
      for (final narrow in [true, false]) {
        testWidgets('render calculator proof $english/$narrow', (tester) async {
          tester.view.physicalSize = Size(narrow ? 320 : 390, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await _open(
            tester,
            _Auth(english: english),
            _Calculator(),
            narrow: narrow,
          );
          final calculate = find.text(
            english ? 'Calculate calorie needs' : 'Oblicz zapotrzebowanie',
          );
          await tester.ensureVisible(calculate);
          await tester.tap(calculate);
          await tester.pumpAndSettle();
          await tester.ensureVisible(
            find.text(english ? 'Save as my goal' : 'Zapisz jako mój cel'),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.runAsync(() async {
            final boundary = tester.renderObject<RenderRepaintBoundary>(
              find.byKey(const ValueKey('calculator-proof')),
            );
            final picture = await boundary.toImage(pixelRatio: 1);
            final bytes = await picture.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File(
              '../docs/uk-stage15/calculator-${english ? 'en' : 'pl'}-${narrow ? '320-150' : '390-100'}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            picture.dispose();
          });
        });
      }
    }
  }
  for (final english in [true, false]) {
    testWidgets(
      'calculator result and saved canonical values remain identical: $english',
      (tester) async {
        final auth = _Auth(english: english);
        final service = _Calculator();
        await _open(tester, auth, service, narrow: true);
        await tester.enterText(
          find.widgetWithText(TextField, english ? 'Weight (kg)' : 'Waga (kg)'),
          '70,5',
        );
        await tester.ensureVisible(find.text(english ? 'Male' : 'Mężczyzna'));
        await tester.tap(find.text(english ? 'Male' : 'Mężczyzna'));
        await tester.ensureVisible(
          find.text(english ? 'Lightly active' : 'Lekka aktywność'),
        );
        await tester.tap(
          find.text(english ? 'Lightly active' : 'Lekka aktywność'),
        );
        final calculate = find.text(
          english ? 'Calculate calorie needs' : 'Oblicz zapotrzebowanie',
        );
        await tester.ensureVisible(calculate);
        await tester.tap(calculate);
        await tester.pumpAndSettle();
        expect(service.requested, {
          'weight_kg': 70.5,
          'height_cm': 175.0,
          'age': 30,
          'gender': 'male',
          'activity_level': 'light',
        });
        expect(
          tester
              .widget<Flex>(find.byKey(const ValueKey('calculator-goals')))
              .direction,
          Axis.vertical,
        );
        final loss = find.text(english ? 'Weight loss' : 'Redukcja');
        await tester.ensureVisible(loss);
        await tester.tap(loss);
        await tester.pumpAndSettle();
        expect(
          find.text(
            english
                ? 'Your target: 1700 kcal/day'
                : 'Własna wartość: 1700 kcal/dzień',
          ),
          findsOneWidget,
        );
        for (final macro in ['106g', '57g', '191g']) {
          expect(find.text(macro), findsOneWidget);
        }
        final save = find.text(
          english ? 'Save as my goal' : 'Zapisz jako mój cel',
        );
        await tester.ensureVisible(save);
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect(auth.saved![#dailyKcalGoal], 1700);
        expect(auth.saved![#weightKg], 70.5);
        expect(auth.saved![#heightCm], 175.0);
        expect(auth.saved![#activityLevel], 'light');
        expect(auth.saved![#gender], 'male');
        expect(find.text('Open existing calculator'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'English calculator validates input then displays a retryable server error',
    (tester) async {
      final service = _Calculator()..fail = true;
      await _open(tester, _Auth(), service);
      final weight = find.widgetWithText(TextField, 'Weight (kg)');
      await tester.enterText(weight, '');
      final calculate = find.text('Calculate calorie needs');
      await tester.ensureVisible(calculate);
      await tester.tap(calculate);
      await tester.pumpAndSettle();
      expect(
        find.text('Enter numbers in all fields (weight, height and age).'),
        findsOneWidget,
      );
      expect(service.requested, isNull);
      await tester.ensureVisible(weight);
      await tester.enterText(weight, '70');
      await tester.ensureVisible(calculate);
      await tester.tap(calculate);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('The service is temporarily unavailable.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'UK calculator uses English without changing metric inputs or activity codes',
    (tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => _Auth(),
          child: const MaterialApp(
            locale: Locale('en', 'GB'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: CalorieCalculatorScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Calorie calculator'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Weight (kg)'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, 'Weight (kg)'))
            .controller!
            .text,
        '70',
      );
      expect(find.text('Moderately active'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
