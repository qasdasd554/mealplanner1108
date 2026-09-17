import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meal_planner/models/product.dart';

void main() {
  test('rozpoznaje produkt zapamiętany po skanowaniu', () {
    final product = Product.fromJson({
      'id': 'cache-1',
      'name': 'Produkt zeskanowany',
      'brand': 'Marka',
      'unit': 'g',
      'default_quantity': 100,
      'nutrition_per_100': {
        'kcal': 250,
        'protein': 8,
        'fat': 10,
        'carbs': 30,
      },
      'source': 'scan',
    });

    expect(product.source, 'scan');
    expect(product.nutritionPer100.kcal, 250);
    expect(product.defaultQuantity, 100);
  });
}
