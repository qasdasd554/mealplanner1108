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
    expect(payload['calories'], 120);
    expect(payload['protein'], 5);
    expect(payload['fat'], 4);
    expect(payload['carbs'], 15);
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
