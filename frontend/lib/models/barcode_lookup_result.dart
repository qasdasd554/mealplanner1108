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
  /// Stare rekordy katalogu/cache mogły zapisać brakujące dane jako cztery
  /// zera. Traktujemy je jak brak, dopóki nie zostaną wzbogacone ze źródła
  /// zewnętrznego. Prawdziwy produkt zerokaloryczny z OFF ma inne źródło
  /// (albo sufiks `_enriched`) i pozostaje poprawnym wynikiem.
  bool get hasCompleteNutrition {
    final values = [kcalPer100, proteinPer100, fatPer100, carbsPer100];
    if (values.any((value) => value == null)) return false;
    if (values.any((value) => value != 0)) return true;
    return source != 'catalog' && source != 'neon_cache';
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
