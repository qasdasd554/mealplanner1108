import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:smart_meal_planner/services/api_client.dart';
import 'package:smart_meal_planner/services/price_compare_service.dart';

Map<String, dynamic> _result({String? currency = 'PLN'}) => {
  'store_id': 'store-1',
  'store_name': 'Lidl',
  'total_price': 20,
  'is_cheapest': true,
  'savings_vs_most_expensive': 3,
  'has_estimated_prices': true,
  'items': <dynamic>[],
  if (currency != null) 'currency_code': currency,
};

class _Client extends ApiClient {
  _Client(this.response) : super.forTesting(httpClient: http.Client());
  final dynamic response;
  String? requestedPath;

  @override
  Future<dynamic> get(String path, {Duration? timeout}) async {
    requestedPath = path;
    return response;
  }
}

void main() {
  group('price comparison market boundaries', () {
    for (final currency in ['PLN', 'GBP']) {
      test(
        '$currency missing or partial total never becomes a zero-price basket',
        () {
          for (final rawTotal in [null, 0, 12.3]) {
            final result = PriceComparisonResult.fromJson(
              _result(currency: currency)
                ..['total_price'] = rawTotal
                ..['is_complete'] = false
                ..['missing_products'] = ['Milk'],
            );
            expect(result.totalPrice, isNull);
            expect(result.isCheapest, isFalse);
            expect(result.savingsVsMostExpensive, 0);
          }
        },
      );
    }
    test(
      'unknown GBP total never becomes a free basket or a cheapest offer',
      () {
        final payload = _result(currency: 'GBP')..['total_price'] = null;
        final result = PriceComparisonResult.fromJson(payload);
        expect(result.totalPrice, isNull);
        expect(result.isComplete, isFalse);
        expect(result.isCheapest, isFalse);
        expect(result.savingsVsMostExpensive, 0);
      },
    );

    test('a partial GBP sum is not presented as the whole basket total', () {
      final payload =
          _result(currency: 'GBP')
            ..['is_complete'] = false
            ..['missing_products'] = ['Milk'];
      final result = PriceComparisonResult.fromJson(payload);
      expect(result.totalPrice, isNull);
      expect(result.isCheapest, isFalse);
    });

    test('old Polish response remains PLN', () {
      final result = PriceComparisonResult.fromJson(_result(currency: null));
      expect(result.currencyCode, 'PLN');
      expect(result.totalPrice, 20);
    });

    test('GBP response preserves amount and estimate flag', () {
      final result = PriceComparisonResult.fromJson(_result(currency: 'GBP'));
      expect(result.currencyCode, 'GBP');
      expect(result.totalPrice, 20);
      expect(result.hasEstimatedPrices, isTrue);
    });

    test(
      'local package snapshot is preserved, not replaced by a default size',
      () {
        final payload = _result(currency: 'GBP')
          ..['items'] = [
            {
              'product_name': 'UK pack',
              'quantity_needed': 600,
              'unit': 'g',
              'price_in_store': 2.10,
              'regional_offer_id': 'sku-250',
              'package_quantity': 250,
              'package_unit': 'g',
              'package_count': 3,
              'purchased_quantity': 750,
              'price_per_package': 0.7,
              'price_source': {'publisher': 'Fixture'},
              'offer_fingerprint': 'checked',
            },
          ];
        final item = PriceComparisonResult.fromJson(payload).items.single;
        expect(item.quantityNeeded, 600);
        expect(item.packageQuantity, 250);
        expect(item.packageCount, 3);
        expect(item.purchasedQuantity, 750);
        expect(item.priceInStore, 2.10);
        expect(item.regionalOfferId, 'sku-250');
        expect(item.priceSource!['publisher'], 'Fixture');
      },
    );

    test('missing GBP item prices cannot be disguised as zero', () {
      for (final price in [null, 0, -1, double.nan]) {
        final payload = _result(currency: 'GBP')
          ..['items'] = [
            {
              'product_name': 'Unknown price',
              'quantity_needed': 100,
              'unit': 'g',
              'price_in_store': price,
            },
          ];
        expect(
          () => PriceComparisonResult.fromJson(payload),
          throwsFormatException,
        );
      }
    });

    test(
      'unknown GBP totals sort after complete ones and never compare as zero',
      () {
        final unknown = PriceComparisonResult.fromJson(
          _result(currency: 'GBP')..['total_price'] = null,
        );
        final complete = PriceComparisonResult.fromJson(
          _result(currency: 'GBP'),
        );
        final rows = [unknown, complete]
          ..sort(PriceComparisonResult.compareForDisplay);
        expect(rows.first, same(complete));
      },
    );

    test(
      'a checked-price flag without a valid checked date stays estimated',
      () {
        for (final date in [null, 'invalid-date']) {
          final payload =
              _result(currency: 'GBP')
                ..['has_estimated_prices'] = false
                ..['items'] = [
                  {
                    'product_name': 'Pasta',
                    'quantity_needed': 1,
                    'unit': 'opak',
                    'price_in_store': 2,
                    'price_is_estimated': false,
                    'last_verified': date,
                  },
                ];
          final result = PriceComparisonResult.fromJson(payload);
          expect(result.items.single.priceIsEstimated, isTrue);
          expect(result.hasEstimatedPrices, isTrue);
        }
      },
    );

    test('missing basket provenance does not become a confirmed price', () {
      final payload = _result()..remove('has_estimated_prices');
      expect(
        PriceComparisonResult.fromJson(payload).hasEstimatedPrices,
        isTrue,
      );
    });

    test(
      'GBP observed price needs a matching source, not just a checked-date flag',
      () {
        for (final source in [
          null,
          <String, dynamic>{},
          {
            'url': 'https://www.tesco.com/fixture',
            'publisher': 'Fixture',
            'checked_on': '2026-10-11',
          },
        ]) {
          final payload = _result(currency: 'GBP')
            ..['items'] = [
              {
                'product_name': 'Rice',
                'quantity_needed': 100,
                'unit': 'g',
                'price_in_store': 1.25,
                'price_is_estimated': false,
                'last_verified': '2026-10-12',
                'price_source': source,
              },
            ];
          expect(
            PriceComparisonResult.fromJson(
              payload,
            ).items.single.priceIsEstimated,
            isTrue,
          );
        }
      },
    );

    test('rejects explicit unknown currency', () {
      expect(
        () => PriceComparisonResult.fromJson(_result(currency: 'USD')),
        throwsFormatException,
      );
    });

    test('does not sort unlike currencies as if their amounts were equal', () {
      final gb = PriceComparisonResult.fromJson(_result(currency: 'GBP'));
      final pl = PriceComparisonResult.fromJson(_result());
      expect(
        () => PriceComparisonResult.compareForDisplay(pl, gb),
        throwsFormatException,
      );
    });

    test('accepts one supported market and keeps API path unchanged', () async {
      final client = _Client([_result(currency: 'GBP')]);
      final service = PriceCompareService(client: client);
      final results = await service.comparePrices(
        'plan-1',
        expectedCurrencyCode: 'GBP',
      );
      expect(client.requestedPath, '/price-compare/plan-1');
      expect(results.single.currencyCode, 'GBP');
    });

    test('rejects a foreign market instead of relabelling its values', () {
      final service = PriceCompareService(
        client: _Client([_result(currency: 'GBP')]),
      );
      expect(service.comparePrices('plan-1'), throwsFormatException);
    });

    test('rejects missing currency for GB: old payload is PLN, not GBP', () {
      final service = PriceCompareService(
        client: _Client([_result(currency: null)]),
      );
      expect(
        service.comparePrices('plan-1', expectedCurrencyCode: 'GBP'),
        throwsFormatException,
      );
    });

    test('rejects mixed currencies even if the first row is expected', () {
      final service = PriceCompareService(
        client: _Client([_result(), _result(currency: 'GBP')]),
      );
      expect(service.comparePrices('plan-1'), throwsFormatException);
    });
  });
}
