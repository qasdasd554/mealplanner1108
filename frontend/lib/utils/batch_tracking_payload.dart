import '../models/barcode_lookup_result.dart';

String supportedBarcodeUnit(BarcodeLookupResult result) {
  const supported = {'g', 'kg', 'ml', 'l', 'szt'};
  return supported.contains(result.unit) ? result.unit : 'szt';
}

double defaultBarcodeQuantity(BarcodeLookupResult result) {
  final known = result.servingQuantity;
  if (known != null && known > 0) return known;
  return supportedBarcodeUnit(result) == 'szt' ? 1 : 100;
}

Map<String, dynamic> buildBatchTrackingPayload({
  required BarcodeLookupResult result,
  required String mealType,
  required DateTime date,
}) {
  if (!result.hasCompleteNutrition) {
    throw ArgumentError(
      'Produkt nie ma kompletnego zestawu wartości odżywczych.',
    );
  }
  final amount = defaultBarcodeQuantity(result);
  final unit = supportedBarcodeUnit(result);
  final nutritionFactor =
      unit == 'szt' && result.servingQuantity == null ? 1.0 : amount / 100;
  final formattedDate =
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
  return {
    'date': formattedDate,
    'meal_type': mealType,
    'custom_name': result.name,
    'servings': 1,
    'calories': result.kcalPer100! * nutritionFactor,
    'protein': result.proteinPer100! * nutritionFactor,
    'fat': result.fatPer100! * nutritionFactor,
    'carbs': result.carbsPer100! * nutritionFactor,
  };
}
