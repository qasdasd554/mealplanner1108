import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:smart_meal_planner/l10n/app_localizations.dart';
import 'package:smart_meal_planner/models/store.dart';
import 'package:smart_meal_planner/models/user.dart';
import 'package:smart_meal_planner/providers/auth_provider.dart';
import 'package:smart_meal_planner/providers/store_provider.dart';
import 'package:smart_meal_planner/screens/auth/email_verification_screen.dart';
import 'package:smart_meal_planner/screens/auth/forgot_password_screen.dart';
import 'package:smart_meal_planner/screens/onboarding/onboarding_screen.dart';
import 'package:smart_meal_planner/screens/onboarding/welcome_bonus_screen.dart';

class _Auth extends ChangeNotifier implements AuthProvider {
  _Auth(this.country);

  final String country;
  String? requestedEmail;
  String? savedDiet;
  List<String>? savedAllergens;

  @override
  bool get isLoading => false;

  @override
  String? get errorMessage => null;

  @override
  int get lastBonusPoints => 0;

  @override
  User get currentUser => User(
    id: 'user-1',
    email: 'user@example.invalid',
    householdSize: 1,
    countryCode: country,
    createdAt: DateTime.utc(2026, 10, 15),
  );

  @override
  Future<bool> forgotPassword(String email) async {
    requestedEmail = email;
    return true;
  }

  @override
  Future<bool> saveOnboardingPreferences({
    required String storeId,
    required List<String> allergenIds,
    required String diet,
    required int householdSize,
    double? weightKg,
    double? heightCm,
    int? dailyKcalGoal,
  }) async {
    savedDiet = diet;
    savedAllergens = List.of(allergenIds);
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Stores extends StoreProvider {
  @override
  List<Store> get stores => [
    Store(
      id: 'store-1',
      name: 'Tesco',
      countryCode: 'GB',
      currencyCode: 'GBP',
      createdAt: DateTime.utc(2026, 10, 15),
      updatedAt: null,
    ),
  ];

  @override
  Future<void> loadStores() async {}
}

Widget _app(Widget screen, Locale locale, _Auth auth) => MultiProvider(
  providers: [
    ChangeNotifierProvider<AuthProvider>.value(value: auth),
    ChangeNotifierProvider<StoreProvider>(create: (_) => _Stores()),
  ],
  child: MaterialApp(
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: screen,
    routes: {'/home': (_) => const Scaffold(body: Text('home-destination'))},
  ),
);

void main() {
  for (final english in [false, true]) {
    final locale =
        english ? const Locale('en', 'GB') : const Locale('pl', 'PL');
    final country = english ? 'GB' : 'PL';

    testWidgets('verification labels and validation follow $locale', (
      tester,
    ) async {
      final auth = _Auth(country);
      addTearDown(auth.dispose);
      await tester.pumpWidget(
        _app(const EmailVerificationScreen(), locale, auth),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(english ? 'Verify your email' : 'Potwierdź swój e-mail'),
        findsOneWidget,
      );
      expect(find.textContaining('user@example.invalid'), findsOneWidget);
      await tester.tap(find.text(english ? 'Verify' : 'Potwierdź'));
      await tester.pump();
      expect(
        find.text(
          english
              ? 'The code must contain exactly 6 digits.'
              : 'Kod musi mieć dokładnie 6 cyfr.',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets(
      'password reset keeps the email and translates steps in $locale',
      (tester) async {
        final auth = _Auth(country);
        addTearDown(auth.dispose);
        await tester.pumpWidget(
          _app(const ForgotPasswordScreen(), locale, auth),
        );
        await tester.pumpAndSettle();
        expect(
          find.text(english ? 'Forgot password' : 'Zapomniałem hasła'),
          findsOneWidget,
        );
        await tester.enterText(
          find.byType(TextField),
          'account@example.invalid',
        );
        await tester.tap(find.text(english ? 'Send code' : 'Wyślij kod'));
        await tester.pumpAndSettle();
        expect(auth.requestedEmail, 'account@example.invalid');
        expect(find.textContaining('account@example.invalid'), findsOneWidget);
        expect(
          find.text(english ? 'Change password' : 'Zmień hasło'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('welcome points and Premium label are translated in $locale', (
      tester,
    ) async {
      final auth = _Auth(country);
      addTearDown(auth.dispose);
      await tester.pumpWidget(
        _app(const WelcomeBonusScreen(points: 4), locale, auth),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(english ? 'You are all set!' : 'Wszystko gotowe!'),
        findsOneWidget,
      );
      expect(
        find.textContaining(english ? '4 premium points' : '4 punkty premium'),
        findsOneWidget,
      );
      expect(
        find.text(english ? 'PREMIUM · 2 PTS' : 'PREMIUM · 2 PKT'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'English onboarding saves Polish canonical diet and allergen IDs',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(430, 932);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final auth = _Auth('GB');
      addTearDown(auth.dispose);
      await tester.pumpWidget(
        _app(const OnboardingScreen(), const Locale('en', 'GB'), auth),
      );
      await tester.pumpAndSettle();
      expect(find.text('Where do you shop?'), findsOneWidget);
      await tester.tap(find.text('Tesco'));
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lactose'));
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Vegetarian'));
      // Household, optional profile, optional pantry, then AI discovery.
      for (var page = 0; page < 4; page++) {
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
      }
      expect(find.text('PREMIUM • OR POINTS'), findsOneWidget);
      expect(find.text('Import a recipe with AI'), findsOneWidget);
      await tester.tap(find.text('Done!'));
      await tester.pumpAndSettle();
      expect(auth.savedDiet, 'Wegetariańska');
      expect(auth.savedAllergens, ['laktoza']);
      expect(find.text('home-destination'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
