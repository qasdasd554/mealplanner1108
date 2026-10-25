import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meal_planner/models/product.dart';

void main() {
  Map<String, dynamic> row({String currency = 'GBP', bool estimated = true}) =>
      {
        'id': 'reviewed-price',
        'store_id': 'uk-lidl',
        'product_id': 'canonical-passata',
        'name_en': 'Tomato Passata',
        'price': 0.45,
        'currency_code': currency,
        'price_is_estimated': estimated,
        'package_quantity': 500,
        'package_unit': 'g',
        'availability_scope': 'store_observation',
      };

  test('reviewed community GBP estimate retains its exact local package', () {
    final product = StoreProduct.fromJson(row());
    expect(product.hasRegionalPackage, isTrue);
    expect(product.packageQuantity, 500);
    expect(product.priceIsEstimated, isTrue);
    expect(product.availabilityScope, 'store_observation');
  });

  test(
    'unknown scope, PLN or an unlabelled observation is not a UK package',
    () {
      expect(
        StoreProduct.fromJson(row(currency: 'PLN')).hasRegionalPackage,
        isFalse,
      );
      expect(
        StoreProduct.fromJson(row(estimated: false)).hasRegionalPackage,
        isFalse,
      );
      expect(
        StoreProduct.fromJson({
          ...row(),
          'availability_scope': 'unknown',
        }).hasRegionalPackage,
        isFalse,
      );
    },
  );
}
