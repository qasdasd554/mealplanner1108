import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meal_planner/models/product.dart';

void main() {
  Map<String, dynamic> row() => {
    'id': 'offer',
    'store_id': 'store',
    'product_id': 'food',
    'price': 1.20,
    'currency_code': 'GBP',
    'name_en': 'Plain yoghurt',
    'package_quantity': 450,
    'package_unit': 'g',
    'availability_scope': 'user_submission',
    'price_is_estimated': true,
  };

  test(
    'approved UK submission exposes its real package, not the 100g default',
    () {
      final product = StoreProduct.fromJson(row());
      expect(product.hasRegionalPackage, isTrue);
      expect(product.packageQuantity, 450);
      expect(product.priceIsEstimated, isTrue);
      expect(product.lastVerified, isNull);
    },
  );

  for (final change in [
    'currency',
    'observed',
    'no_package',
    'unknown_scope',
  ]) {
    test('invalid app report does not enable a package: $change', () {
      final json = row();
      if (change == 'currency') json['currency_code'] = 'PLN';
      if (change == 'observed') json['price_is_estimated'] = false;
      if (change == 'no_package') json['package_quantity'] = null;
      if (change == 'unknown_scope') json['availability_scope'] = 'untrusted';
      expect(StoreProduct.fromJson(json).hasRegionalPackage, isFalse);
    });
  }
}
