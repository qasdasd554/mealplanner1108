import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meal_planner/l10n/app_localizations.dart';
import 'package:smart_meal_planner/l10n/market_locale.dart';
import 'package:smart_meal_planner/models/shopping_list.dart';
import 'package:smart_meal_planner/services/price_compare_service.dart';
import 'package:smart_meal_planner/utils/national_price_reference.dart';
import 'package:smart_meal_planner/widgets/store_price_comparison_card.dart';

Map<String, dynamic> source() => {
  'provider': 'ons_national_average',
  'period': '2026-09',
  'basis': 'required_quantity_not_shop_price',
  'url':
      'https://www.ons.gov.uk/economy/inflationandpriceindices/articles/shoppingpricescomparisontool/latest',
  'publisher': 'Office for National Statistics',
  'checked_on': '2026-10-24',
};

PriceComparisonResult basket() => PriceComparisonResult.fromJson({
  'store_id': 'store-1',
  'store_name': 'Tesco',
  'total_price': 1.57,
  'is_cheapest': true,
  'savings_vs_most_expensive': 3.0,
  'is_complete': true,
  'currency_code': 'GBP',
  'items': [
    {
      'product_name': 'Rolled oats',
      'quantity_needed': 500,
      'unit': 'g',
      'price_in_store': 1.57,
      'price_is_estimated': true,
      'price_source': source(),
    },
  ],
});

void main() {
  test('national average cannot claim cheapest shop or savings', () {
    expect(basket().totalPrice, 1.57);
    expect(basket().isCheapest, isFalse);
    expect(basket().savingsVsMostExpensive, 0);
    expect(basket().items.single.packageQuantity, isNull);
    expect(basket().items.single.priceIsEstimated, isTrue);
  });
  test(
    'quantity estimate does not manufacture a package on the shopping list',
    () {
      final item = ShoppingListItem.fromJson({
        'id': 'item',
        'product_name': 'Rolled oats',
        'required_quantity': 500,
        'unit': 'g',
        'estimated_price': 1.57,
        'is_checked': false,
        'currency_code': 'GBP',
        'quote_status': 'quoted',
        'price_is_estimated': true,
        'price_source': source(),
      });
      expect(item.estimatedPrice, 1.57);
      expect(item.hasReliablePackage, isFalse);
      expect(item.regionalOfferId, isNull);
    },
  );
  for (final invalid in [
    null,
    <String, dynamic>{},
    {...source(), 'period': '2026-99'},
    {...source(), 'provider': 'product_submission'},
  ]) {
    test('unsupported source has no national label: $invalid', () {
      expect(nationalPriceReferenceLabel(invalid, english: true), isNull);
    });
  }
  for (final country in ['PL', 'GB']) {
    testWidgets('national reference stays clear at 320 px, $country, 150%', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          locale: localeForMarket(accountCountry: country),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
            child: Scaffold(
              body: ListView(
                children: [StorePriceComparisonCard(result: basket())],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tesco'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining(
          country == 'GB' ? 'not a shop price' : 'nie cena sklepu',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
