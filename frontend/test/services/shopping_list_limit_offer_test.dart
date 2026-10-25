import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:smart_meal_planner/l10n/app_localizations.dart';
import 'package:smart_meal_planner/models/user.dart';
import 'package:smart_meal_planner/providers/auth_provider.dart';
import 'package:smart_meal_planner/services/api_client.dart';
import 'package:smart_meal_planner/services/shopping_list_limit_offer.dart';

class _Auth extends AuthProvider {
  final User user;
  _Auth(String country, {bool premium = false, String suffix = ''})
    : user = User(
        id: 'limit-$country-$premium-$suffix',
        email: 'fixture@example.test',
        countryCode: country,
        householdSize: 1,
        isPremium: premium,
        createdAt: DateTime.utc(2026, 10, 23),
      ),
      super(readToken: () async => null);
  @override
  User get currentUser => user;
}

String quota(String country) =>
    country == 'GB'
        ? 'A Standard account can create one shopping list per week (Monday–Sunday). You can still add products to your existing list, or upgrade to Premium.'
        : 'Konto standardowe może utworzyć jedną listę zakupów w tygodniu (poniedziałek–niedziela). Możesz nadal dodać produkty do istniejącej listy albo skorzystać z Premium.';

void main() {
  for (final country in ['PL', 'GB']) {
    for (final scenario in [
      'return',
      'append-limit',
      'late-session',
      'presentation-error',
    ]) {
      testWidgets('$country limit recovery: $scenario', (tester) async {
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        final auth = _Auth(country, suffix: scenario);
        await auth.initialization;
        addTearDown(auth.dispose);
        final api = ApiClient.forTesting(httpClient: http.Client());
        final input = TextEditingController(text: 'Keep my recipe selection');
        addTearDown(input.dispose);
        late BuildContext target;
        Object? listTab;
        await tester.pumpWidget(
          ChangeNotifierProvider<AuthProvider>.value(
            value: auth,
            child: MaterialApp(
              locale:
                  country == 'GB'
                      ? const Locale('en', 'GB')
                      : const Locale('pl'),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              routes: {
                '/home': (context) {
                  listTab = ModalRoute.of(context)?.settings.arguments;
                  return const Scaffold(body: Text('Existing shopping list'));
                },
              },
              home: Builder(
                builder: (context) {
                  target = context;
                  return Scaffold(body: TextField(controller: input));
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final error = ApiException(
          403,
          scenario == 'append-limit'
              ? country == 'GB'
                  ? 'A Standard account can create one shopping list per week. Adding more recipes to an existing list is available with Premium.'
                  : 'Konto standardowe może utworzyć jedną listę zakupów w tygodniu. Dodawanie kolejnych przepisów do istniejącej listy jest dostępne w Premium.'
              : quota(country),
        );
        final handled = await ShoppingListLimitOffer.handle(
          target,
          error,
          client: api,
          present: (_) async {
            if (scenario == 'presentation-error')
              throw StateError('route failed');
            if (scenario == 'late-session') api.invalidateSession();
            return 'shopping-list';
          },
        );
        await tester.pumpAndSettle();
        expect(handled, scenario != 'presentation-error');
        if (scenario == 'return' || scenario == 'append-limit') {
          expect(find.text('Existing shopping list'), findsOneWidget);
          expect(listTab, 2);
          Navigator.of(target).pop();
          await tester.pumpAndSettle();
        } else {
          expect(find.text('Existing shopping list'), findsNothing);
        }
        if (scenario == 'presentation-error') {
          var retried = false;
          expect(
            await ShoppingListLimitOffer.handle(
              target,
              error,
              client: api,
              present: (_) async {
                retried = true;
                return null;
              },
            ),
            isTrue,
          );
          expect(retried, isTrue);
        }
        expect(input.text, 'Keep my recipe selection');
        expect(find.byType(TextField), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }
    test('$country recognises only the actual weekly quota', () {
      expect(
        isWeeklyShoppingListLimit(ApiException(403, quota(country))),
        isTrue,
      );
      expect(
        isWeeklyShoppingListLimit(ApiException(500, quota(country))),
        isFalse,
      );
      expect(
        isWeeklyShoppingListLimit(ApiException(403, 'Premium required')),
        isFalse,
      );
      expect(
        isWeeklyShoppingListLimit(ApiException(403, 'Access denied')),
        isFalse,
      );
      expect(isWeeklyShoppingListLimit(StateError(quota(country))), isFalse);
    });
    for (final premium in [true, false]) {
      testWidgets('$country limit prompt once per session; Premium=$premium', (
        tester,
      ) async {
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        final auth = _Auth(country, premium: premium);
        await auth.initialization;
        addTearDown(auth.dispose);
        final api = ApiClient.forTesting(httpClient: http.Client());
        final input = TextEditingController(text: 'My selected recipe');
        addTearDown(input.dispose);
        late BuildContext target;
        await tester.pumpWidget(
          ChangeNotifierProvider<AuthProvider>.value(
            value: auth,
            child: MaterialApp(
              locale:
                  country == 'GB'
                      ? const Locale('en', 'GB')
                      : const Locale('pl'),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              home: Builder(
                builder: (context) {
                  target = context;
                  return Scaffold(body: TextField(controller: input));
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        var presentations = 0;
        Future<dynamic> present(BuildContext _) async {
          presentations++;
          return null;
        }

        final error = ApiException(403, quota(country));
        expect(
          await ShoppingListLimitOffer.handle(
            target,
            error,
            client: api,
            present: present,
          ),
          !premium,
        );
        expect(presentations, premium ? 0 : 1);
        await ShoppingListLimitOffer.handle(
          target,
          error,
          client: api,
          present: present,
        );
        await tester.pumpAndSettle();
        expect(presentations, premium ? 0 : 1);
        if (!premium)
          expect(
            find.text(
              country == 'GB'
                  ? "You have reached this week's list limit. Create more lists with Premium."
                  : 'Tygodniowy limit list został wykorzystany. Z Premium tworzysz kolejne bez limitu.',
            ),
            findsOneWidget,
          );
        expect(input.text, 'My selected recipe');
        api.invalidateSession();
        await ShoppingListLimitOffer.handle(
          target,
          error,
          client: api,
          present: present,
        );
        expect(presentations, premium ? 0 : 2);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}
