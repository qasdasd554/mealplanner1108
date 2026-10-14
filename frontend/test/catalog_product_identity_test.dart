import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meal_planner/models/product.dart';
import 'package:smart_meal_planner/widgets/pick_product_from_catalog_sheet.dart';

Product _product(String id, String? barcode, double package) => Product(
  id: id,
  name: 'Jogurt naturalny',
  brand: 'Marka',
  barcode: barcode,
  unit: 'g',
  defaultQuantity: 1,
  servingQuantity: package,
  nutritionPer100: NutritionInfo(
    kcal: 100,
    protein: 5,
    fat: 2,
    carbs: 15,
    fiber: 0,
  ),
);

void main() {
  test(
    'same label different GTIN products retain their separate package sizes',
    () {
      final products = mergeCatalogProducts([
        [_product('one', '5901234123457', 150)],
        [_product('two', '036000291452', 400)],
      ]);
      expect(products, hasLength(2));
      expect(products.map((p) => p.servingQuantity), containsAll([150, 400]));
    },
  );
  test(
    'same GTIN under UPC and padded GTIN keeps preferred catalog record',
    () {
      final preferred = _product('catalog', '036000291452', 400);
      expect(
        mergeCatalogProducts([
          [preferred],
          [_product('cache', '00036000291452', 400)],
        ]),
        [preferred],
      );
    },
  );
  test(
    'without barcode distinct product IDs cannot be identified by label alone',
    () {
      expect(
        mergeCatalogProducts([
          [_product('one', null, 150)],
          [_product('two', null, 400)],
        ]),
        hasLength(2),
      );
    },
  );
}
