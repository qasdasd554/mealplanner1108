import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meal_planner/models/barcode_lookup_result.dart';
import 'package:smart_meal_planner/services/barcode_lookup_service.dart';

void main() {
  const product = <String, dynamic>{
    'product_name_pl': 'Jogurt naturalny',
    'code': '5901234123457',
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
    expect(result?.barcode, '5901234123457');
    expect(result?.brand, 'Przykładowa marka');
    expect(result?.kcalPer100, 62);
    expect(result?.proteinPer100, 4.2);
    expect(result?.fatPer100, 2);
    expect(result?.carbsPer100, 6.1);
    expect(result?.priceMin, 2);
    expect(result?.priceMax, 7);
    expect(result?.servingQuantity, 400);
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

  test('rozpoznaje częściowy sukces v3 i angielską nazwę', () {
    final extracted = extractOpenFoodFactsProduct({
      'status': 'success_with_errors',
      'result': {'id': 'product_found'},
      'product': <String, dynamic>{
        'product_name_en': 'Puff pastry',
        'code': '5901234123457',
        'nutriments': {'energy-kcal_100g': 310},
      },
    }, isV3: true);
    final result = barcodeResultFromOpenFoodFacts(extracted!);
    expect(result?.name, 'Puff pastry');
    expect(result?.kcalPer100, 310);
  });

  test('dla skanu wybiera całe opakowanie zamiast pojedynczej porcji', () {
    final result = barcodeResultFromOpenFoodFacts({
      'product_name': 'Jogurt',
      'serving_quantity': 30,
      'serving_quantity_unit': 'g',
      'product_quantity': 150,
      'product_quantity_unit': 'g',
      'nutriments': product['nutriments'],
    });

    expect(result?.servingQuantity, 150);
    expect(result?.unit, 'g');
  });

  test('przelicza litry i kilogramy na ml i g', () {
    final drink = barcodeResultFromOpenFoodFacts({
      'product_name': 'Napój',
      'product_quantity': 1.5,
      'product_quantity_unit': 'l',
    });
    final flour = barcodeResultFromOpenFoodFacts({
      'product_name': 'Mąka',
      'product_quantity': 1,
      'product_quantity_unit': 'kg',
    });

    expect(drink?.unit, 'ml');
    expect(drink?.servingQuantity, 1500);
    expect(flour?.unit, 'g');
    expect(flour?.servingQuantity, 1000);
  });

  test('odczytuje tekstową gramaturę i wielopak', () {
    final multipack = barcodeResultFromOpenFoodFacts({
      'product_name': 'Jogurty',
      'quantity': '6 x 100 g',
    });
    final drink = barcodeResultFromOpenFoodFacts({
      'product_name': 'Napój',
      'quantity': '1,5 l',
    });

    expect(multipack?.servingQuantity, 600);
    expect(drink?.servingQuantity, 1500);
    expect(drink?.unit, 'ml');
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
    expect(result.hasCompleteNutrition, isTrue);
  });

  test('nie uznaje samej nazwy produktu za pełne dane żywieniowe', () {
    const result = BarcodeLookupResult(
      found: true,
      source: 'neon_cache',
      name: 'Produkt bez makro',
    );

    expect(result.hasCompleteNutrition, isFalse);
  });

  test('stare cztery zera w Neon wymagają ponownego uzupełnienia', () {
    const cached = BarcodeLookupResult(
      found: true,
      source: 'neon_cache',
      name: 'Stary produkt',
      kcalPer100: 0,
      proteinPer100: 0,
      fatPer100: 0,
      carbsPer100: 0,
    );

    expect(cached.hasCompleteNutrition, isFalse);
  });

  test('zera bez potwierdzonego źródła nie są pełnym makro', () {
    const unknown = BarcodeLookupResult(
      found: true,
      name: 'Niezweryfikowany produkt',
      kcalPer100: 0,
      proteinPer100: 0,
      fatPer100: 0,
      carbsPer100: 0,
    );
    expect(unknown.hasCompleteNutrition, isFalse);
  });

  test('nawet zewnętrzne cztery zera wymagają uzupełnienia', () {
    const external = BarcodeLookupResult(
      found: true,
      source: 'open_food_facts_direct',
      name: 'Woda',
      kcalPer100: 0,
      proteinPer100: 0,
      fatPer100: 0,
      carbsPer100: 0,
    );

    expect(external.hasCompleteNutrition, isFalse);
  });

  test('zastępuje cztery stare zera makro z zewnętrznej bazy', () {
    const cached = BarcodeLookupResult(
      found: true,
      source: 'neon_cache',
      name: 'Jogurt z cache',
      kcalPer100: 0,
      proteinPer100: 0,
      fatPer100: 0,
      carbsPer100: 0,
    );
    const external = BarcodeLookupResult(
      found: true,
      source: 'open_food_facts_direct',
      name: 'Jogurt z OFF',
      kcalPer100: 62,
      proteinPer100: 4.2,
      fatPer100: 2,
      carbsPer100: 6.1,
    );

    final result = mergeBarcodeLookupResults(cached, external);
    expect(result.kcalPer100, 62);
    expect(result.proteinPer100, 4.2);
    expect(result.fatPer100, 2);
    expect(result.carbsPer100, 6.1);
    expect(result.hasCompleteNutrition, isTrue);
  });

  test('wzbogacony produkt opakowaniowy zachowuje gramaturę OFF', () {
    const cached = BarcodeLookupResult(
      found: true,
      source: 'neon_cache',
      name: 'Jogurt',
      unit: 'opak',
      kcalPer100: 0,
      proteinPer100: 0,
      fatPer100: 0,
      carbsPer100: 0,
    );
    const external = BarcodeLookupResult(
      found: true,
      source: 'open_food_facts_direct',
      name: 'Jogurt',
      unit: 'g',
      servingQuantity: 150,
      kcalPer100: 100,
      proteinPer100: 4,
      fatPer100: 3,
      carbsPer100: 12,
    );

    final result = mergeBarcodeLookupResults(cached, external);
    expect(result.unit, 'g');
    expect(result.servingQuantity, 150);
  });

  test('nie zachowuje fałszywych zer, gdy zewnętrzna baza jest częściowa', () {
    const cached = BarcodeLookupResult(
      found: true,
      source: 'neon_cache',
      name: 'Produkt z cache',
      kcalPer100: 0,
      proteinPer100: 0,
      fatPer100: 0,
      carbsPer100: 0,
    );
    const external = BarcodeLookupResult(
      found: true,
      source: 'open_food_facts_direct',
      name: 'Produkt z OFF',
      kcalPer100: 120,
      proteinPer100: 3,
    );

    final result = mergeBarcodeLookupResults(cached, external);
    expect(result.kcalPer100, 120);
    expect(result.proteinPer100, 3);
    expect(result.fatPer100, isNull);
    expect(result.carbsPer100, isNull);
    expect(result.hasCompleteNutrition, isFalse);
  });
}
