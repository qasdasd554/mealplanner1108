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
  });

  /// Czy dane pochodzą z Waszego własnego katalogu (a nie z zewnętrznej
  /// bazy) — wtedy zwykle najbardziej wiarygodne, bo ktoś już to
  /// zweryfikował wcześniej.
  bool get isFromOwnCatalog => source == 'catalog';

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
    );
  }

}
