import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meal_planner/models/product.dart';
import 'package:smart_meal_planner/utils/product_measures.dart';

// Representative public response fields verified by the backend presentation
// tests. A generic food is not a Polish or an OFF example's branded package.
Map<String, dynamic> genericOats() => {
  'id': 'c65508d5-139b-5f92-9850-1507938eb5e5',
  'name': 'Płatki owsiane',
  'brand': null,
  'unit': 'g',
  'default_quantity': 500,
  'serving_quantity': null,
  'measure_options': [
    {
      'code': 'szklanka',
      'label': 'szklanka',
      'base_quantity': 110,
      'base_unit': 'g',
      'approximate': true,
    },
  ],
  'nutrition_per_100': {'kcal': 389},
};

void main() {
  group('UK generic food response contract', () {
    late Product product;

    setUp(() => product = Product.fromJson(genericOats()));

    test('unknown package is absent but useful portion and grams remain', () {
      final options = effectiveMeasureOptions(product);
      expect(product.brand, isNull);
      expect(options.any((option) => option.code == 'opak'), isFalse);
      expect(
        options.singleWhere((option) => option.code == 'porcja').baseQuantity,
        80,
      );
      expect(
        options.singleWhere((option) => option.code == 'g').baseQuantity,
        1,
      );
      expect(
        options.singleWhere((option) => option.code == 'szklanka').baseQuantity,
        110,
      );
    });

    test('60 grams retains the food calorie calculation without any pack', () {
      final grams = effectiveMeasureOptions(
        product,
      ).singleWhere((option) => option.code == 'g');
      final amount = ProductAmountSelection(quantity: 60, measure: grams);
      expect(amount.baseAmount, 60);
      expect(
        amount.nutritionFactorPer100() * product.nutritionPer100.kcal,
        closeTo(233.4, 0.0001),
      );
    });

    test(
      'confirmed local SKU pack stays separate from the generic product',
      () {
        final offer = StoreProduct.fromJson({
          'id': 'local-offer',
          'store_id': 'uk-shop',
          'product_id': product.id,
          'price': 1.25,
          'currency_code': 'GBP',
          'is_available': true,
          'name_en': 'Synthetic local oats 750g',
          'package_quantity': 750,
          'package_unit': 'g',
          'availability_scope': 'online_catalogue',
          'product': genericOats(),
        });
        expect(offer.hasRegionalPackage, isTrue);
        expect(offer.packageQuantity, 750);
        expect(offer.product!.servingQuantity, isNull);
        expect(offer.product!.nutritionPer100.kcal, 389);
      },
    );
  });
}
