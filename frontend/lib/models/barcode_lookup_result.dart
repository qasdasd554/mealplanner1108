/// Wynik wyszukiwania produktu po kodzie kreskowym — patrz
/// `BarcodeLookupResponse` w backendzie (app/api/v1/products.py).
class BarcodeLookupResult {
  final bool found;
  final String? source;
  final String? name;
  final String? brand;
  final String unit;
  final double? kcalPer100;
  final double? proteinPer100;
  final double? fatPer100;
  final double? carbsPer100;
  final String? existingProductId;
  final String? barcode;
  final double? priceMin;
  final double? priceMax;
  final double? servingQuantity;

  const BarcodeLookupResult({
    required this.found,
    this.source,
    this.name,
    this.brand,
    this.unit = 'g',
    this.kcalPer100,
    this.proteinPer100,
    this.fatPer100,
    this.carbsPer100,
    this.existingProductId,
    this.barcode,
    this.priceMin,
    this.priceMax,
    this.servingQuantity,
  });

  /// Czy dane pochodzą z Waszego własnego katalogu (a nie z zewnętrznej
  /// bazy) — wtedy zwykle najbardziej wiarygodne, bo ktoś już to
  /// zweryfikował wcześniej.
  bool get isFromOwnCatalog =>
      source == 'catalog' || source == 'catalog_enriched';

  /// Pełny zestaw wartości potrzebny do zapisania produktu w Śledzeniu.
  /// Stare zera katalogu/cache mogą być brakiem danych. Jawne wartości
  /// z zewnętrznej bazy lub potwierdzonej etykiety obejmują też np. wodę.
  bool get hasCompleteNutrition {
    final values = [kcalPer100, proteinPer100, fatPer100, carbsPer100];
    if (values.any((value) => value == null || !value.isFinite || value < 0)) {
      return false;
    }
    return values.any((value) => value! > 0) ||
        const {
          'open_food_facts',
          'open_food_facts_direct',
          'usda_fooddata_central',
          'product_label_ai',
          'product_label_ai_confirmed',
        }.contains(source);
  }

  static double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.replaceAll(',', '.'));
    return null;
  }

  factory BarcodeLookupResult.fromJson(Map<String, dynamic> json) {
    return BarcodeLookupResult(
      found: json['found'] as bool? ?? false,
      source: json['source'] as String?,
      name: json['name'] as String?,
      brand: json['brand'] as String?,
      unit: json['unit'] as String? ?? 'g',
      kcalPer100: _asDouble(json['kcal_per_100']),
      proteinPer100: _asDouble(json['protein_per_100']),
      fatPer100: _asDouble(json['fat_per_100']),
      carbsPer100: _asDouble(json['carbs_per_100']),
      existingProductId: json['existing_product_id'] as String?,
      barcode: json['barcode'] as String?,
      priceMin: _asDouble(json['price_min']),
      priceMax: _asDouble(json['price_max']),
      servingQuantity: _asDouble(json['serving_quantity']),
    );
  }
}
