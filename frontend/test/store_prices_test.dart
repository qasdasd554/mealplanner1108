import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meal_planner/config/constants.dart';
import 'package:smart_meal_planner/models/product.dart';
import 'package:smart_meal_planner/models/store.dart';
import 'package:smart_meal_planner/services/price_compare_service.dart';
import 'package:smart_meal_planner/utils/store_price_labels.dart';
import 'package:smart_meal_planner/widgets/store_price_comparison_card.dart';

Map<String, dynamic> _comparison({
  String name = 'Stokrotka',
  bool complete = true,
  bool estimated = true,
  double total = 29.98,
}) => {
  'store_id': name,
  'store_name': name,
  'total_price': total,
  'is_cheapest': true,
  'savings_vs_most_expensive': 10,
  'has_estimated_prices': estimated,
  'is_complete': complete,
  'missing_products': complete ? <String>[] : ['Mąka pełnoziarnista'],
  'items': [
    {
      'product_name': 'Mleko',
      'quantity_needed': 0.15,
      'unit': 'l',
      'price_in_store': 2.99,
      'price_is_estimated': estimated,
      'last_verified': estimated ? null : '2026-10-12T08:30:00Z',
    },
  ],
};

void main() {
  test('nowe sieci są obsługiwane przez skaner i model sklepu', () {
    expect(kPromotionScanStores.toSet().length, 7);
    expect(
      kPromotionScanStores,
      containsAll(['Stokrotka', 'Kaufland', 'Auchan']),
    );
    for (final name in kPromotionScanStores) {
      final store = Store.fromJson({
        'id': name,
        'name': name,
        'created_at': '2026-10-12T08:30:00Z',
      });
      expect(store.name, name);
    }
  });

  test('rozróżnia ceny orientacyjne i datę sprawdzenia', () {
    final estimate = PriceComparisonResult.fromJson(_comparison());
    expect(estimate.hasEstimatedPrices, isTrue);
    expect(estimate.items.single.priceIsEstimated, isTrue);
    expect(estimate.items.single.lastVerified, isNull);

    final checked = PriceComparisonResult.fromJson(
      _comparison(estimated: false),
    );
    expect(checked.hasEstimatedPrices, isFalse);
    expect(checked.items.single.priceIsEstimated, isFalse);
    expect(
      checked.items.single.lastVerified,
      DateTime.utc(2026, 10, 12, 8, 30),
    );
    expect(
      priceVerificationLabel(checked.items.single.lastVerified),
      'cena sprawdzona 12.10.2026',
    );
    expect(priceVerificationLabel(null), 'cena orientacyjna');
  });

  test('stary serwer nie udaje potwierdzonych cen bez flag', () {
    final json = _comparison();
    json.remove('has_estimated_prices');
    (json['items'] as List).single.remove('price_is_estimated');
    expect(PriceComparisonResult.fromJson(json).hasEstimatedPrices, isTrue);
  });

  test('niepełny koszyk nie jest najtańszy ani nie obiecuje oszczędności', () {
    final incomplete = PriceComparisonResult.fromJson(
      _comparison(complete: false, total: 1),
    );
    final complete = PriceComparisonResult.fromJson(_comparison());
    expect(incomplete.isComplete, isFalse);
    expect(incomplete.isCheapest, isFalse);
    expect(incomplete.savingsVsMostExpensive, 0);
    final sorted = [incomplete, complete]
      ..sort(PriceComparisonResult.compareForDisplay);
    expect(sorted.first, same(complete));
  });

  test('braki mają pierwszeństwo nad niezgodną flagą kompletności', () {
    final json = _comparison(complete: false)..['is_complete'] = true;
    final result = PriceComparisonResult.fromJson(json);
    expect(result.isComplete, isFalse);
    expect(result.isCheapest, isFalse);
  });

  test('jednostka ceny nie jest zastępowana fikcyjnym opakowaniem', () {
    final product = Product.fromJson({
      'id': 'p',
      'name': 'Mleko',
      'unit': 'ml',
      'default_quantity': 1000,
    });
    expect(storePriceQuantityLabel(product), '/ 1000 ml');
    expect(storePriceQuantityLabel(null), '/ jednostka nieokreślona');
    final storeProduct = StoreProduct.fromJson({
      'id': 'sp',
      'store_id': 's',
      'product_id': 'p',
      'price': 4.99,
    });
    expect(storePriceVerificationLabel(storeProduct), 'cena orientacyjna');
  });

  for (final complete in [true, false]) {
    testWidgets('karta cen mieści się na 320 px, kompletny: $complete', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final result = PriceComparisonResult.fromJson(
        _comparison(complete: complete),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
            child: Scaffold(
              body: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  StorePriceComparisonCard(
                    result: result,
                    onSwitchStore: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Stokrotka'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('0.15 l • cena orientacyjna'), findsOneWidget);
      if (complete) {
        expect(find.text('Najniższy szacunek'), findsOneWidget);
        expect(find.text('Przełącz plan na ten sklep'), findsOneWidget);
      } else {
        expect(find.textContaining('Niepełny koszyk'), findsOneWidget);
        expect(find.textContaining('Mąka pełnoziarnista.'), findsOneWidget);
        expect(find.text('Najniższy szacunek'), findsNothing);
        expect(find.text('Przełącz plan na ten sklep'), findsNothing);
      }
    });
  }
}
