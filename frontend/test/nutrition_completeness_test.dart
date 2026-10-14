import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meal_planner/models/barcode_lookup_result.dart';
import 'package:smart_meal_planner/models/product.dart';
import 'package:smart_meal_planner/services/barcode_lookup_service.dart';
import 'package:smart_meal_planner/utils/batch_tracking_payload.dart';

void main() {
  test('missing product macros remain absent when serialized', () {
    final nutrition = NutritionInfo.fromJson({'kcal': 100, 'protein': null});
    expect(nutrition.toJson().containsKey('protein'), isFalse);
    expect(nutrition.toJson().containsKey('fat'), isFalse);
    expect(nutrition.toJson().containsKey('carbs'), isFalse);
  });
  test('explicit product zero stays a known value when serialized', () {
    final nutrition = NutritionInfo.fromJson({
      'kcal': 100,
      'protein': 0,
      'fat': 0,
      'carbs': 25,
    });
    expect(nutrition.toJson()['protein'], 0);
  });
  for (final source in [
    'open_food_facts',
    'open_food_facts_direct',
    'usda_fooddata_central',
    'product_label_ai',
    'product_label_ai_confirmed',
  ]) {
    test(
      'explicit zero nutrition from $source is a real zero calorie product',
      () {
        final result = BarcodeLookupResult(
          found: true,
          source: source,
          name: 'Woda',
          unit: 'ml',
          servingQuantity: 500,
          kcalPer100: 0,
          proteinPer100: 0,
          fatPer100: 0,
          carbsPer100: 0,
        );
        expect(result.hasCompleteNutrition, isTrue);
        expect(
          buildBatchTrackingPayload(
            result: result,
            mealType: 'Przekąska',
            date: DateTime(2026, 10, 14),
          )['calories'],
          0,
        );
      },
    );
  }
  test('negative and nonfinite macro values are incomplete', () {
    for (final protein in [-1.0, double.nan, double.infinity]) {
      expect(
        BarcodeLookupResult(
          found: true,
          kcalPer100: 10,
          proteinPer100: protein,
          fatPer100: 0,
          carbsPer100: 0,
        ).hasCompleteNutrition,
        isFalse,
      );
    }
  });
  test(
    'merging legacy cache with explicit water retains known zero provenance',
    () {
      const old = BarcodeLookupResult(
        found: true,
        source: 'neon_cache',
        name: 'Woda',
        kcalPer100: 0,
        proteinPer100: 0,
        fatPer100: 0,
        carbsPer100: 0,
      );
      const actual = BarcodeLookupResult(
        found: true,
        source: 'open_food_facts_direct',
        name: 'Woda',
        kcalPer100: 0,
        proteinPer100: 0,
        fatPer100: 0,
        carbsPer100: 0,
      );
      expect(
        mergeBarcodeLookupResults(old, actual).hasCompleteNutrition,
        isTrue,
      );
    },
  );
}
