import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smart_meal_planner/services/api_client.dart';
import 'package:smart_meal_planner/services/barcode_lookup_service.dart';
import 'package:smart_meal_planner/models/barcode_lookup_result.dart';

const _product = <String, dynamic>{
  'code': '5901234123457',
  'product_name_pl': 'Mleko',
  'product_name_en': 'Milk',
  'brands': 'Farm',
  'product_quantity': 500,
  'product_quantity_unit': 'ml',
  'nutriments': {
    'energy-kcal_100g': 60,
    'proteins_100g': 3,
    'fat_100g': 2,
    'carbohydrates_100g': 5,
  },
};

class _Backend extends ApiClient {
  bool fail = false;
  bool complete = false;
  int calls = 0;
  Completer<dynamic>? pending;
  _Backend() : super.forTesting(httpClient: http.Client());
  @override
  Future<dynamic> get(String path, {Duration? timeout}) async {
    calls++;
    if (pending != null) return pending!.future;
    if (fail) throw TimeoutException('backend unavailable');
    return {
      'found': complete,
      'name': 'Local name',
      'unit': 'ml',
      'source': 'catalog',
      'existing_product_id': 'local-product',
      'barcode': '5901234123457',
      'serving_quantity': 500,
      if (complete) ...{
        'kcal_per_100': 60,
        'protein_per_100': 3,
        'fat_per_100': 2,
        'carbs_per_100': 5,
      },
      'price_min': 3,
      'price_max': 6,
    };
  }
}

http.Response _found() => http.Response(
  jsonEncode({
    'status': 'success',
    'result': {'id': 'product_found'},
    'product': _product,
  }),
  200,
);

void main() {
  for (final quantity in [
    '-10 g',
    '−10 g',
    '-2 x -250 ml',
    '0 x 250 ml',
    '1e309 g',
    '1e+309 g',
    '1e-309 g',
    '100001 g',
    '100000 kg',
  ]) {
    test('invalid metric label $quantity never manufactures a package', () {
      final result =
          barcodeResultFromOpenFoodFacts({
            'product_name_en': 'Food',
            'quantity': quantity,
          }, countryCode: 'GB')!;
      expect(result.servingQuantity, isNull);
      expect(result.hasKnownPackageSize, isFalse);
    });
  }

  test('metric package boundary and compact multipack remain valid', () {
    for (final entry in {'100000 g': 100000.0, '6x100g': 600.0}.entries) {
      final result =
          barcodeResultFromOpenFoodFacts({
            'product_name_en': 'Food',
            'quantity': entry.key,
          }, countryCode: 'GB')!;
      expect(result.servingQuantity, entry.value);
      expect(result.unit, 'g');
    }
  });

  test('raw per-serving macros are never labelled as per100', () {
    final result =
        barcodeResultFromOpenFoodFacts({
          'product_name_en': 'Meal',
          'nutrition_data_per': 'serving',
          'nutriments': {
            'energy-kcal': 120,
            'proteins': 2,
            'fat': 4,
            'carbohydrates': 15,
          },
        }, countryCode: 'GB')!;
    expect(result.kcalPer100, isNull);
    expect(result.proteinPer100, isNull);
    expect(result.fatPer100, isNull);
    expect(result.carbsPer100, isNull);
    expect(result.hasCompleteNutrition, isFalse);
  });

  test('unbased raw kJ does not turn into per100 calories', () {
    final result =
        barcodeResultFromOpenFoodFacts({
          'product_name_en': 'Meal',
          'nutriments': {'energy': 500},
        }, countryCode: 'GB')!;
    expect(result.kcalPer100, isNull);
  });

  test('explicit raw per100ml is usable but canonical per100 keys win', () {
    final result =
        barcodeResultFromOpenFoodFacts({
          'product_name_en': 'Milk',
          'nutrition_data_per': '100ml',
          'nutriments': {
            'energy-kcal': 100,
            'energy-kcal_100g': 60,
            'proteins': 3,
            'fat': 2,
            'carbohydrates': 5,
          },
        }, countryCode: 'GB')!;
    expect(result.kcalPer100, 60);
    expect(result.proteinPer100, 3);
    expect(result.hasCompleteNutrition, isTrue);
  });

  test('enrichment adopts whole-pack amount and dimension together', () {
    final result = mergeBarcodeLookupResults(
      const BarcodeLookupResult(
        found: true,
        source: 'catalog',
        name: 'Milk',
        unit: 'g',
      ),
      const BarcodeLookupResult(
        found: true,
        source: 'open_food_facts_direct',
        name: 'Milk',
        unit: 'ml',
        servingQuantity: 500,
      ),
    );
    expect(result.unit, 'ml');
    expect(result.servingQuantity, 500);
  });

  test(
    'invalid local pack cannot override valid external amount or its dimension',
    () {
      final result = mergeBarcodeLookupResults(
        const BarcodeLookupResult(
          found: true,
          source: 'catalog',
          name: 'Milk',
          unit: 'g',
          servingQuantity: double.infinity,
        ),
        const BarcodeLookupResult(
          found: true,
          source: 'open_food_facts_direct',
          name: 'Milk',
          unit: 'ml',
          servingQuantity: 500,
        ),
      );
      expect(result.unit, 'ml');
      expect(result.servingQuantity, 500);
    },
  );

  test('enrichment does not replace a valid known local physical pack', () {
    final result = mergeBarcodeLookupResults(
      const BarcodeLookupResult(
        found: true,
        source: 'catalog',
        name: 'Food',
        unit: 'g',
        servingQuantity: 200,
      ),
      const BarcodeLookupResult(
        found: true,
        source: 'open_food_facts_direct',
        name: 'Food',
        unit: 'ml',
        servingQuantity: 500,
      ),
    );
    expect(result.unit, 'g');
    expect(result.servingQuantity, 200);
  });
  test(
    'v2 fallback stays sequential, bounded and in the same account market',
    () async {
      final requests = <Uri>[];
      final service = BarcodeLookupService(
        apiClient: _Backend(),
        accountCountry: () => 'GB',
        httpClient: MockClient((request) async {
          requests.add(request.url);
          return requests.length == 1
              ? http.Response('{}', 500)
              : http.Response(
                jsonEncode({'status': 1, 'product': _product}),
                200,
              );
        }),
      );
      addTearDown(service.close);
      final result = await service.lookup('5901234123457');
      expect(requests, hasLength(2));
      expect(requests.first.path, contains('/v3/'));
      expect(requests.last.path, contains('/v2/'));
      expect(
        requests.every(
          (uri) =>
              uri.queryParameters['cc'] == 'uk' &&
              uri.queryParameters['lc'] == 'en',
        ),
        isTrue,
      );
      expect(result.name, 'Milk');
    },
  );

  test(
    'whole metric package, not a serving, determines the physical dimension',
    () {
      final result =
          barcodeResultFromOpenFoodFacts({
            ..._product,
            'product_quantity': null,
            'product_quantity_unit': null,
            'quantity': '2 x 250 ml',
            'serving_quantity': 30,
            'serving_quantity_unit': 'g',
          }, countryCode: 'GB')!;
      expect(result.unit, 'ml');
      expect(result.servingQuantity, 500);
    },
  );

  test(
    'normalised quantity uses raw label dimension without multiplying twice',
    () {
      final result =
          barcodeResultFromOpenFoodFacts({
            ..._product,
            'product_quantity': 1500,
            'product_quantity_unit': null,
            'quantity': '1.5 l',
          }, countryCode: 'GB')!;
      expect(result.servingQuantity, 1500);
      expect(result.unit, 'ml');
    },
  );

  for (final value in [double.nan, double.infinity, -5, 100001]) {
    test('invalid package $value never becomes a usable pack', () {
      final result =
          barcodeResultFromOpenFoodFacts({
            ..._product,
            'product_quantity': value,
          }, countryCode: 'GB')!;
      expect(result.servingQuantity, isNull);
    });
  }

  test('a serving does not substitute for unknown whole-pack size', () {
    final result =
        barcodeResultFromOpenFoodFacts({
          ..._product,
          'product_quantity': null,
          'product_quantity_unit': null,
          'serving_quantity': 30,
          'serving_quantity_unit': 'ml',
        }, countryCode: 'GB')!;
    expect(result.servingQuantity, isNull);
    expect(result.unit, 'ml');
  });
  test('UK direct result prefers English and never relabels PLN estimates', () {
    final uk = barcodeResultFromOpenFoodFacts(_product, countryCode: 'GB')!;
    final pl = barcodeResultFromOpenFoodFacts(_product)!;
    expect(uk.name, 'Milk');
    expect(uk.priceMin, isNull);
    expect(uk.priceMax, isNull);
    expect(uk.servingQuantity, 500);
    expect(uk.unit, 'ml');
    expect(pl.name, 'Mleko');
    expect(pl.priceMin, 3);
  });

  test('GB fallback uses world API with uk/en in one request', () async {
    final requests = <Uri>[];
    final service = BarcodeLookupService(
      apiClient: _Backend()..fail = true,
      accountCountry: () => 'GB',
      httpClient: MockClient((request) async {
        requests.add(request.url);
        return _found();
      }),
    );
    addTearDown(service.close);
    final result = await service.lookup('5901234123457');
    expect(requests, hasLength(1));
    expect(requests.single.host, 'world.openfoodfacts.org');
    expect(requests.single.queryParameters['cc'], 'uk');
    expect(requests.single.queryParameters['lc'], 'en');
    expect(result.name, 'Milk');
    expect(result.proteinPer100, 3);
    expect(result.priceMin, isNull);
  });

  test(
    'complete cached GB hit stays fast and loses legacy PLN estimate only',
    () async {
      final api = _Backend()..complete = true;
      var external = 0;
      final service = BarcodeLookupService(
        apiClient: api,
        accountCountry: () => 'GB',
        httpClient: MockClient((_) async {
          external++;
          return _found();
        }),
      );
      addTearDown(service.close);
      final result = await service.lookup('5901234123457');
      expect(api.calls, 1);
      expect(external, 0);
      expect(result.name, 'Local name');
      expect(result.existingProductId, 'local-product');
      expect(result.servingQuantity, 500);
      expect(result.kcalPer100, 60);
      expect(result.priceMin, isNull);
    },
  );

  for (final status in [404, 429, 503]) {
    test(
      'GB status $status does not fan out into another API version',
      () async {
        final requests = <Uri>[];
        final service = BarcodeLookupService(
          apiClient: _Backend(),
          accountCountry: () => 'GB',
          httpClient: MockClient((request) async {
            requests.add(request.url);
            return http.Response('{}', status);
          }),
        );
        addTearDown(service.close);
        final result = await service.lookup('5901234123457');
        expect(requests, hasLength(1));
        expect(requests.single.queryParameters['lc'], 'en');
        expect(result.found, isFalse);
      },
    );
  }

  test(
    'country is captured once per lookup, not read again during fallback',
    () async {
      var country = 'GB';
      final api = _Backend()..pending = Completer<dynamic>();
      final requests = <Uri>[];
      final service = BarcodeLookupService(
        apiClient: api,
        accountCountry: () => country,
        httpClient: MockClient((request) async {
          requests.add(request.url);
          return _found();
        }),
      );
      addTearDown(service.close);
      final pending = service.lookup('5901234123457');
      country = 'PL';
      api.pending!.complete({'found': false});
      await pending;
      expect(requests.single.queryParameters['lc'], 'en');
      await service.lookup('5901234123457');
      expect(requests.last.queryParameters['lc'], 'pl');
    },
  );

  test('unknown imperial numeric unit is not interpreted as grams', () {
    final result =
        barcodeResultFromOpenFoodFacts({
          ..._product,
          'product_quantity': 12,
          'product_quantity_unit': 'oz',
        }, countryCode: 'GB')!;
    expect(result.servingQuantity, isNull);
  });

  test('explicit metric equivalent retains its physical dimension', () {
    final result =
        barcodeResultFromOpenFoodFacts({
          ..._product,
          'product_quantity': 12,
          'product_quantity_unit': 'fl oz',
          'quantity': '12 fl oz (355 ml)',
        }, countryCode: 'GB')!;
    expect(result.servingQuantity, 355);
    expect(result.unit, 'ml');
  });

  test(
    'unsupported country keeps the PL default without interpreting language as region',
    () async {
      final requests = <Uri>[];
      final service = BarcodeLookupService(
        apiClient: _Backend(),
        accountCountry: () => 'en',
        httpClient: MockClient((request) async {
          requests.add(request.url);
          return _found();
        }),
      );
      addTearDown(service.close);
      await service.lookup('5901234123457');
      expect(requests.single.queryParameters['cc'], 'pl');
      expect(requests.single.queryParameters['lc'], 'pl');
    },
  );
}
