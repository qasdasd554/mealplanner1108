import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meal_planner/l10n/app_localizations.dart';
import 'package:smart_meal_planner/l10n/market_locale.dart';
import 'package:smart_meal_planner/utils/market_money.dart';

void main() {
  test('registered country wins over later phone region changes', () {
    expect(
      localeForMarket(accountCountry: 'PL', deviceRegion: 'GB'),
      const Locale('pl', 'PL'),
    );
    expect(
      localeForMarket(accountCountry: 'GB', deviceRegion: 'PL'),
      const Locale('en', 'GB'),
    );
    expect(localeForMarket(deviceRegion: 'GB'), const Locale('en', 'GB'));
    expect(localeForMarket(deviceRegion: 'DE'), const Locale('de', 'DE'));
    expect(
      localeForMarket(accountCountry: 'DE', deviceRegion: 'PL'),
      const Locale('de', 'DE'),
    );
    expect(
      localeForMarket(accountCountry: 'PL', deviceRegion: 'DE'),
      const Locale('pl', 'PL'),
    );
    expect(localeForMarket(deviceRegion: 'US'), const Locale('pl', 'PL'));
    expect(localeForMarket(), const Locale('pl', 'PL'));
  });

  test('all supported translations cover the same keys', () {
    Set<String> keys(String locale) =>
        (jsonDecode(File('lib/l10n/app_$locale.arb').readAsStringSync())
                as Map<String, dynamic>)
            .keys
            .where((key) => !key.startsWith('@'))
            .toSet();
    expect(keys('en_GB'), keys('pl'));
    expect(keys('en'), keys('pl'));
    expect(keys('de'), keys('pl'));
  });

  test(
    'provider strings use the supplied persisted country, with safe PL fallback',
    () {
      expect(stringsForAccountCountry('GB').localeName, 'en_GB');
      expect(stringsForAccountCountry('DE').localeName, 'de');
      expect(stringsForAccountCountry('PL').localeName, 'pl');
      expect(stringsForAccountCountry(null).localeName, 'pl');
      expect(stringsForAccountCountry('US').localeName, 'pl');
      expect(
        identical(
          stringsForAccountCountry('GB'),
          stringsForAccountCountry('GB'),
        ),
        isTrue,
      );
    },
  );

  testWidgets(
    'German copy and euro prices resolve from the existing delegates',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: localeForMarket(accountCountry: 'DE'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Builder(
            builder:
                (context) => Scaffold(
                  body: Column(
                    children: [
                      Text(context.strings.planNewTitle),
                      Text(context.strings.receiptSaved(2)),
                      Text(formatMarketMoney(2.5, currencyCode: 'EUR')),
                    ],
                  ),
                ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Neuer Essensplan'), findsOneWidget);
      expect(find.text('2 Artikel im Vorrat gespeichert.'), findsOneWidget);
      expect(find.textContaining('2,50'), findsOneWidget);
      expect(find.textContaining('€'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final country in ['PL', 'GB']) {
    testWidgets('same actions and Polish/English wording for $country', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: localeForMarket(accountCountry: country),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Builder(
            builder:
                (context) => Scaffold(
                  body: Column(
                    children: [
                      Text(context.strings.home),
                      Text(context.strings.recipes),
                      Text(context.strings.diary),
                      Text(context.strings.scanProduct),
                      Text(context.strings.premiumTwoPoints),
                    ],
                  ),
                ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(country == 'GB' ? 'Home' : 'Start'), findsOneWidget);
      expect(
        find.text(country == 'GB' ? 'Recipes' : 'Przepisy'),
        findsOneWidget,
      );
      expect(
        find.text(country == 'GB' ? 'Food diary' : 'Dziennik'),
        findsOneWidget,
      );
      expect(
        find.text(country == 'GB' ? 'Scan a product' : 'Zeskanuj produkt'),
        findsOneWidget,
      );
      expect(
        find.text(
          country == 'GB' ? 'Premium or 2 points' : 'Premium lub 2 pkt',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
