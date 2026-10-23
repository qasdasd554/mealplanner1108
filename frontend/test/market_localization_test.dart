import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meal_planner/l10n/app_localizations.dart';
import 'package:smart_meal_planner/l10n/market_locale.dart';

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
    expect(localeForMarket(deviceRegion: 'US'), const Locale('pl', 'PL'));
    expect(localeForMarket(), const Locale('pl', 'PL'));
  });

  test('every initial translation has a British and base English value', () {
    Set<String> keys(String locale) =>
        (jsonDecode(File('lib/l10n/app_$locale.arb').readAsStringSync())
                as Map<String, dynamic>)
            .keys
            .where((key) => !key.startsWith('@'))
            .toSet();
    expect(keys('en_GB'), keys('pl'));
    expect(keys('en'), keys('pl'));
  });

  test(
    'provider strings use the supplied persisted country, with safe PL fallback',
    () {
      expect(stringsForAccountCountry('GB').localeName, 'en_GB');
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
        find.text(country == 'GB' ? 'PREMIUM · 2 PTS' : 'PREMIUM · 2 PKT'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
