import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:smart_meal_planner/l10n/app_localizations.dart';
import 'package:smart_meal_planner/models/user.dart';
import 'package:smart_meal_planner/models/store.dart';
import 'package:smart_meal_planner/models/weight_log.dart';
import 'package:smart_meal_planner/providers/auth_provider.dart';
import 'package:smart_meal_planner/providers/store_provider.dart';
import 'package:smart_meal_planner/providers/theme_provider.dart';
import 'package:smart_meal_planner/screens/profile/profile_screen.dart';
import 'package:smart_meal_planner/services/weight_log_service.dart';

class _Auth extends ChangeNotifier implements AuthProvider {
  final bool english;
  final String diet;
  Map<String, dynamic>? savedDiet;
  _Auth(this.english, {this.diet = 'Wegetariańska'});
  @override
  User get currentUser => User(
    id: 'user',
    email: 'test@example.invalid',
    displayName: 'Alex',
    countryCode: english ? 'GB' : 'PL',
    householdSize: 2,
    weightKg: 70,
    heightCm: 175,
    dietaryPreferences: {'diet': diet},
    isPremium: true,
    createdAt: DateTime.utc(2026),
  );
  @override
  dynamic noSuchMethod(Invocation call) {
    if (call.memberName == #updateProfile) {
      savedDiet =
          call.namedArguments[#dietaryPreferences] as Map<String, dynamic>?;
      return Future<bool>.value(true);
    }
    if (call.memberName == #loadProfile) return Future<void>.value();
    return super.noSuchMethod(call);
  }
}

class _Stores extends ChangeNotifier implements StoreProvider {
  @override
  List<Store> get stores => [];
  @override
  dynamic noSuchMethod(Invocation call) => super.noSuchMethod(call);
}

class _Weight extends WeightLogService {
  int saves = 0;
  @override
  Future<List<WeightLogEntry>> getLogs({int limit = 30}) async => [];
  @override
  Future<WeightLogEntry> save(DateTime date, double value) async {
    saves++;
    return WeightLogEntry(id: 'test', date: date, weightKg: value);
  }
}

Future<_Auth> open(
  WidgetTester tester, {
  bool english = true,
  bool narrow = false,
  _Weight? weights,
  String diet = 'Wegetariańska',
}) async {
  if (narrow) {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }
  final auth = _Auth(english, diet: diet);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>(create: (_) => auth),
        ChangeNotifierProvider<StoreProvider>(create: (_) => _Stores()),
        ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
      ],
      child: MaterialApp(
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
        home: ProfileScreen(weightLogService: weights ?? _Weight()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return auth;
}

Future<void> reveal(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text));
  await tester.pumpAndSettle();
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'Meal Planner',
      packageName: 'test',
      version: '1',
      buildNumber: '1',
      buildSignature: '',
    );
  });
  for (final entry
      in {
        'Bezglutenowa': 'Gluten-free',
        'Wysokobiałkowa': 'High-protein',
        'Bez laktozy': 'Lactose-free',
      }.entries) {
    testWidgets('profile translates saved onboarding diet ${entry.key}', (
      tester,
    ) async {
      await open(tester, diet: entry.key);
      await reveal(tester, 'Preferences');
      expect(find.text(entry.value), findsOneWidget);
      expect(find.text(entry.key), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  for (final english in [true, false]) {
    testWidgets(
      'profile labels and diet display are ${english ? 'English' : 'Polish'} without changing API codes',
      (tester) async {
        final auth = await open(tester, english: english);
        expect(find.text(english ? 'Profile' : 'Profil'), findsOneWidget);
        await reveal(tester, english ? 'Preferences' : 'Preferencje');
        expect(
          find.text(english ? 'Vegetarian' : 'Wegetariańska'),
          findsOneWidget,
        );
        await reveal(tester, english ? 'Diet' : 'Rodzaj diety');
        await tester.tap(find.text(english ? 'Vegan' : 'Wegańska'));
        await tester.pumpAndSettle();
        expect(auth.savedDiet, {'diet': 'Wegańska'});
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'nickname field survives dialog closing animation after editing',
    (tester) async {
      await open(tester);
      await tester.tap(find.text('Alex'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'New nickname');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'weight rejects NaN before sending a request and keeps the input',
    (tester) async {
      final weights = _Weight();
      await open(tester, weights: weights);
      await reveal(tester, 'Health and goals');
      await tester.ensureVisible(
        find.widgetWithText(TextField, 'Weight (optional)'),
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Weight (optional)'),
        'NaN',
      );
      await tester.ensureVisible(find.text('Save measurement'));
      await tester.tap(find.text('Save measurement'));
      await tester.pumpAndSettle();
      expect(weights.saves, 0);
      expect(find.text('NaN'), findsOneWidget);
      expect(
        find.text('Enter a valid weight between 0.1 and 400 kg.'),
        findsOneWidget,
      );
    },
  );
  testWidgets('profile sections reflow at 320px and enlarged text', (
    tester,
  ) async {
    await open(tester, narrow: true);
    for (final section in [
      'Health and goals',
      'Preferences',
      'Account and privacy',
    ]) {
      await reveal(tester, section);
      expect(tester.takeException(), isNull);
    }
  });
}
