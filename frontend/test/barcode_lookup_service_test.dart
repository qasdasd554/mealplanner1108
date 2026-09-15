import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meal_planner/models/barcode_lookup_result.dart';
import 'package:smart_meal_planner/services/barcode_lookup_service.dart';

void main() {
  const product = <String, dynamic>{
    'product_name_pl': 'Jogurt naturalny',
    'brands': 'Przykładowa marka, Druga marka',
    'product_quantity': 400,
    'product_quantity_unit': 'g',
    'categories_tags': ['en:yogurts'],
    'nutriments': {
      'energy-kcal_100g': 62,
      'proteins_100g': '4.2',
      'fat_100g': 2.0,
      'carbohydrates_100g': 6.1,
    },
  };

  test('rozpoznaje aktualną odpowiedź Open Food Facts v3', () {
    final extracted = extractOpenFoodFactsProduct({
      'status': 'success',
      'result': {'id': 'product_found'},
      'product': product,
    }, isV3: true);

    final result = barcodeResultFromOpenFoodFacts(extracted!);
    expect(result?.name, 'Jogurt naturalny');
    expect(result?.brand, 'Przykładowa marka');
    expect(result?.kcalPer100, 62);
    expect(result?.proteinPer100, 4.2);
    expect(result?.fatPer100, 2);
    expect(result?.carbsPer100, 6.1);
    expect(result?.priceMin, 2);
    expect(result?.priceMax, 7);
  });

  test('rozpoznaje odpowiedź zapasowego API v2', () {
    final extracted = extractOpenFoodFactsProduct({
      'status': 1,
      'product': product,
    }, isV3: false);
    expect(
      barcodeResultFromOpenFoodFacts(extracted!)?.name,
      'Jogurt naturalny',
    );
  });

  test('nie uznaje pustej odpowiedzi za produkt', () {
    expect(
      extractOpenFoodFactsProduct({
        'status': 'success',
        'result': {'id': 'product_not_found'},
        'product': <String, dynamic>{},
      }, isV3: true),
      isNull,
    );
  });

  test('uzupełnia brakujące makro produktu z katalogu', () {
    const catalog = BarcodeLookupResult(
      found: true,
      source: 'catalog',
      name: 'Jogurt z katalogu',
      brand: 'Marka katalogowa',
      priceMin: 2,
      priceMax: 7,
    );
    const external = BarcodeLookupResult(
      found: true,
      source: 'open_food_facts_direct',
      name: 'Jogurt z API',
      kcalPer100: 62,
      proteinPer100: 4.2,
      fatPer100: 2,
      carbsPer100: 6.1,
      priceMin: 3,
      priceMax: 9,
    );

    final result = mergeBarcodeLookupResults(catalog, external);
    expect(result.name, 'Jogurt z katalogu');
    expect(result.brand, 'Marka katalogowa');
    expect(result.kcalPer100, 62);
    expect(result.proteinPer100, 4.2);
    expect(result.fatPer100, 2);
    expect(result.carbsPer100, 6.1);
    expect(result.priceMin, 2);
    expect(result.priceMax, 7);
  });
}
