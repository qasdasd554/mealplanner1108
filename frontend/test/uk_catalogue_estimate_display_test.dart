import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meal_planner/models/product.dart';
import 'package:smart_meal_planner/utils/national_price_reference.dart';
import 'package:smart_meal_planner/services/price_compare_service.dart';

const source = <String, dynamic>{
  'provider': 'uk_catalogue_estimate',
  'basis': 'required_quantity_not_shop_price',
  'confirms_store_stock': false,
  'confirms_package': false,
};

void main() {
  test(
    'static catalogue price is not presented as ONS or verified shop offer',
    () {
      expect(
        nationalPriceReferenceLabel(source, english: true),
        contains('Catalogue estimate'),
      );
      expect(
        nationalPriceReferenceLabel(source, english: false),
        contains('Szacunek katalogowy'),
      );
      expect(
        nationalPriceReferenceLabel(source, english: true),
        isNot(contains('ONS')),
      );
      final row = StoreProduct.fromJson({
        'id': 'reference',
        'store_id': 'shop',
        'product_id': 'food',
        'catalogue_kind': 'generic_food',
        'availability_scope': 'generic_food_reference',
        'currency_code': 'GBP',
        'price': 0.30,
        'name_en': 'Eggs',
        'price_basis': 'national_quantity_reference',
        'price_quantity': 1,
        'price_unit': 'szt',
        'price_source': source,
        'product': {'id': 'food', 'name': 'Eggs', 'unit': 'szt'},
      });
      expect(row.hasValidGenericReference, isTrue);
      expect(row.hasRegionalPackage, isFalse);
    },
  );

  test(
    'catalogue assumptions cannot manufacture cheapest-shop claims or savings',
    () {
      final result = PriceComparisonResult.fromJson({
        'store_id': 'shop',
        'store_name': 'Shop',
        'currency_code': 'GBP',
        'total_price': 0.30,
        'is_complete': true,
        'is_cheapest': true,
        'savings_vs_most_expensive': 5.0,
        'items': [
          {
            'product_name': 'Flour',
            'quantity_needed': 500,
            'unit': 'g',
            'price_in_store': 0.30,
            'price_source': source,
          },
        ],
      });
      expect(result.totalPrice, 0.30);
      expect(result.isCheapest, isFalse);
      expect(result.savingsVsMostExpensive, 0);
      expect(result.hasEstimatedPrices, isTrue);
    },
  );
}
