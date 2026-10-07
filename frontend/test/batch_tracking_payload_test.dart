import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meal_planner/models/barcode_lookup_result.dart';
import 'package:smart_meal_planner/utils/batch_tracking_payload.dart';

void main() {
  test('seryjne skanowanie przekazuje kcal i wszystkie makroskładniki', () {
    const result = BarcodeLookupResult(
      found: true,
      name: 'Testowy produkt',
      unit: 'g',
      servingQuantity: 50,
      kcalPer100: 240,
      proteinPer100: 10,
      fatPer100: 8,
      carbsPer100: 30,
    );
    final payload = buildBatchTrackingPayload(
      result: result,
      mealType: 'Przekąska',
      date: DateTime(2026, 9, 28),
    );
    expect(payload['date'], '2026-09-28');
    expect(payload['custom_name'], 'Testowy produkt (1 opakowanie)');
    expect(payload['calories'], 120);
    expect(payload['protein'], 5);
    expect(payload['fat'], 4);
    expect(payload['carbs'], 15);
    expect(payload['amount_value'], 1);
    expect(payload['amount_unit'], 'opak');
    expect(payload['portion_size'], 50);
    expect(payload['portion_unit'], 'g');
  });

  test('produkt bez gramatury nie udaje jednego opakowania', () {
    const result = BarcodeLookupResult(
      found: true,
      name: 'Produkt bez gramatury',
      kcalPer100: 100,
      proteinPer100: 5,
      fatPer100: 2,
      carbsPer100: 12,
    );

    expect(defaultBarcodeQuantity(result), 1);
    expect(barcodePackageNutritionFactor(result), 1);
    final payload = buildBatchTrackingPayload(
      result: result,
      mealType: 'Przekąska',
      date: DateTime(2026, 9, 28),
    );
    expect(hasKnownBarcodePackageSize(result), isFalse);
    expect(payload['custom_name'], 'Produkt bez gramatury (100 g)');
    expect(payload['amount_unit'], 'g');
    expect(payload['amount_value'], 100);
  });

  test('liczby sztuk nie traktuje jako gramów opakowania', () {
    const result = BarcodeLookupResult(
      found: true,
      name: 'Produkt na sztuki',
      unit: 'szt',
      servingQuantity: 1,
      kcalPer100: 100,
      proteinPer100: 5,
      fatPer100: 2,
      carbsPer100: 12,
    );

    expect(barcodePackageNutritionFactor(result), 1);
  });

  test('nie pozwala zapisać produktu bez kompletnego makro', () {
    const result = BarcodeLookupResult(
      found: true,
      name: 'Niepełny produkt',
      kcalPer100: 100,
    );
    expect(
      () => buildBatchTrackingPayload(
        result: result,
        mealType: 'Obiad',
        date: DateTime(2026, 9, 28),
      ),
      throwsArgumentError,
    );
  });
}
