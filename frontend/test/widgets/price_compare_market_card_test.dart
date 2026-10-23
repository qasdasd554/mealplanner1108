import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meal_planner/l10n/app_localizations.dart';
import 'package:smart_meal_planner/l10n/market_locale.dart';
import 'package:smart_meal_planner/services/price_compare_service.dart';
import 'package:smart_meal_planner/widgets/store_price_comparison_card.dart';

PriceComparisonResult _result({
  String currency = 'GBP',
  bool complete = true,
  bool estimated = true,
}) => PriceComparisonResult.fromJson({
  'store_id': 'store-1',
  'store_name': 'Lidl',
  'total_price': 12.3,
  'is_cheapest': true,
  'savings_vs_most_expensive': 3,
  'has_estimated_prices': estimated,
  'is_complete': complete,
  'currency_code': currency,
  'missing_products': complete ? <String>[] : ['Milk'],
  'items': [
    {
      'product_name': 'Pasta',
      'quantity_needed': 2,
      'unit': 'opak',
      'price_in_store': 4.5,
      'price_is_estimated': estimated,
      'last_verified': estimated ? null : '2026-10-12T08:30:00Z',
      if (!estimated)
        'price_source': {
          'url': 'https://www.tesco.com/synthetic-test',
          'publisher': 'Synthetic fixture',
          'checked_on': '2026-10-12',
        },
    },
  ],
});

void main() {
  for (final country in ['PL', 'GB']) {
    for (final complete in [true, false]) {
      testWidgets('comparison $country complete=$complete fits 320 px', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var switchCount = 0;
        await tester.pumpWidget(
          MaterialApp(
            locale: localeForMarket(accountCountry: country),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
              child: Scaffold(
                body: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    StorePriceComparisonCard(
                      result: _result(
                        currency: country == 'GB' ? 'GBP' : 'PLN',
                        complete: complete,
                      ),
                      onSwitchStore: () => switchCount++,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text(
            country == 'GB'
                ? (complete ? '~ £12.30' : 'Total unavailable')
                : '~ 12.30 zł',
          ),
          findsOneWidget,
        );
        if (country == 'GB' && !complete) {
          expect(find.textContaining('£0.00'), findsNothing);
          expect(find.text('~ £12.30'), findsNothing);
        }
        expect(find.textContaining(country == 'GB' ? 'zł' : '£'), findsNothing);
        await tester.tap(find.text('Lidl'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          find.text(
            country == 'GB'
                ? '2 pack • estimated price'
                : '2 opak. • cena orientacyjna',
          ),
          findsOneWidget,
        );
        final switchButton = find.text(
          country == 'GB'
              ? 'Switch plan to this shop'
              : 'Przełącz plan na ten sklep',
        );
        if (complete) {
          expect(switchButton, findsOneWidget);
          await tester.ensureVisible(switchButton);
          await tester.tap(switchButton);
          expect(switchCount, 1);
        } else {
          expect(switchButton, findsNothing);
          expect(
            find.textContaining(
              country == 'GB' ? 'Incomplete basket' : 'Niepełny koszyk',
            ),
            findsOneWidget,
          );
          expect(switchCount, 0);
        }
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('checked GBP item shows its checked date, not an estimate', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en', 'GB'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: StorePriceComparisonCard(result: _result(estimated: false)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('£12.30'), findsOneWidget);
    expect(find.text('Cheapest'), findsOneWidget);
    expect(find.textContaining('~'), findsNothing);
    await tester.tap(find.text('Lidl'));
    await tester.pumpAndSettle();
    expect(find.text('2 pack • price checked on 12/10/2026'), findsOneWidget);
    expect(find.text('£4.50'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
