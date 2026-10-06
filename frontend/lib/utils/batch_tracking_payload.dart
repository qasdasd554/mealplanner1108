import '../models/barcode_lookup_result.dart';

String supportedBarcodeUnit(BarcodeLookupResult result) {
  const supported = {'g', 'kg', 'ml', 'l', 'szt'};
  return supported.contains(result.unit) ? result.unit : 'szt';
}

double defaultBarcodeQuantity(BarcodeLookupResult result) {
  return 1;
}

const String barcodePackageUnit = 'opak';

double barcodePackageNutritionFactor(BarcodeLookupResult result) {
  final packageSize = result.servingQuantity;
  if (packageSize != null &&
      packageSize > 0 &&
      const {'g', 'ml'}.contains(result.unit)) {
    return packageSize / 100;
  }
  // Jeżeli baza nie zna masy opakowania, nie udajemy, że „1 opakowanie”
  // to 1 gram. Pokazujemy wartości na znaną bazę 100 g/ml.
  return 1;
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
  final nutritionFactor = barcodePackageNutritionFactor(result);
  final formattedDate =
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
  return {
    'date': formattedDate,
    'meal_type': mealType,
    'custom_name': '${result.name} (1 opakowanie)',
    'servings': 1,
    'calories': result.kcalPer100! * nutritionFactor,
    'protein': result.proteinPer100! * nutritionFactor,
    'fat': result.fatPer100! * nutritionFactor,
    'carbs': result.carbsPer100! * nutritionFactor,
    // Pierwszy zapis ma przedstawiać cały produkt, a nie liczbę gramów.
    // Gramatura zostaje w `portion_size`, dzięki czemu późniejsza zmiana
    // na g/ml nadal poprawnie przelicza kcal i makro.
    'amount_value': 1,
    'amount_unit': barcodePackageUnit,
    if (result.servingQuantity != null && result.servingQuantity! > 0)
      'portion_size': result.servingQuantity,
    if (result.servingQuantity != null && result.servingQuantity! > 0)
      'portion_unit': result.unit == 'ml' ? 'ml' : 'g',
  };
}
