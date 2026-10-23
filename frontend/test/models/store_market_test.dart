import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meal_planner/models/store.dart';

Map<String, dynamic> _storeJson() => {
  'id': 'store-1',
  'name': 'Example store',
  'created_at': '2026-10-15T00:00:00Z',
};

void main() {
  test('legacy stores default to Poland and PLN', () {
    final store = Store.fromJson(_storeJson());
    expect(store.countryCode, 'PL');
    expect(store.currencyCode, 'PLN');
  });

  test('British store market and currency survive serialization', () {
    final store = Store.fromJson({
      ..._storeJson(),
      'country_code': 'GB',
      'currency_code': 'GBP',
    });
    expect(store.countryCode, 'GB');
    expect(store.currencyCode, 'GBP');
    final restored = Store.fromJson(store.toJson());
    expect(restored.countryCode, 'GB');
    expect(restored.currencyCode, 'GBP');
  });
}
