import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meal_planner/models/product.dart';

Map<String, dynamic> generic() => {
  'id': 'reference',
  'store_id': 'tesco',
  'product_id': 'oats',
  'currency_code': 'GBP',
  'price': null,
  'is_available': null,
  'catalogue_kind': 'generic_food',
  'availability_scope': 'generic_food_reference',
  'name_en': 'Oats',
  'price_basis': 'unknown',
  'product': {'id': 'oats', 'name': 'Oats', 'unit': 'g'},
};

void main() {
  test('unknown price and stock stay unknown, not zero or available', () {
    final row = StoreProduct.fromJson(generic());
    expect(row.hasValidGenericReference, isTrue);
    expect(row.price, isNull);
    expect(row.isAvailable, isNull);
    expect(row.hasRegionalPackage, isFalse);
  });
  for (final change
      in <String, dynamic>{
        'currency_code': 'PLN',
        'is_available': true,
        'package_quantity': 100,
        'package_unit': 'g',
        'price': 0,
        'price_basis': 'package',
        'availability_scope': 'online_catalogue',
        'name_en': '',
      }.entries) {
    test('generic reference rejects misleading ${change.key}', () {
      final data = generic()..[change.key] = change.value;
      expect(StoreProduct.fromJson(data).hasValidGenericReference, isFalse);
    });
  }
  test('national average requires explicit source and non-pack basis', () {
    final data =
        generic()..addAll({
          'price': 0.20,
          'price_basis': 'national_quantity_reference',
          'price_quantity': 100,
          'price_unit': 'g',
          'price_is_estimated': true,
          'price_source': {
            'provider': 'ons_national_average',
            'confirms_store_stock': false,
            'confirms_package': false,
          },
        });
    expect(StoreProduct.fromJson(data).hasValidGenericReference, isTrue);
    data['price_source'] = {'provider': 'unknown'};
    expect(StoreProduct.fromJson(data).hasValidGenericReference, isFalse);
  });
}
