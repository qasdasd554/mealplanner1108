/// Wynik wyszukiwania produktu po kodzie kreskowym — patrz
/// `BarcodeLookupResponse` w backendzie (app/api/v1/products.py).
class BarcodeLookupResult {
  final bool found;
  final String? source; // "catalog" | "open_food_facts" | null
  final String? name;
  final String? brand;
  final String unit;
  final double? kcalPer100;
  final double? proteinPer100;
  final double? fatPer100;
  final double? carbsPer100;
  final String? existingProductId;

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
  });

  /// Czy dane pochodzą z Waszego własnego katalogu (a nie z zewnętrznej
  /// bazy) — wtedy zwykle najbardziej wiarygodne, bo ktoś już to
  /// zweryfikował wcześniej.
  bool get isFromOwnCatalog => source == 'catalog';

  factory BarcodeLookupResult.fromJson(Map<String, dynamic> json) {
    return BarcodeLookupResult(
      found: json['found'] as bool? ?? false,
      source: json['source'] as String?,
      name: json['name'] as String?,
      brand: json['brand'] as String?,
      unit: json['unit'] as String? ?? 'g',
      kcalPer100: (json['kcal_per_100'] as num?)?.toDouble(),
      proteinPer100: (json['protein_per_100'] as num?)?.toDouble(),
      fatPer100: (json['fat_per_100'] as num?)?.toDouble(),
      carbsPer100: (json['carbs_per_100'] as num?)?.toDouble(),
      existingProductId: json['existing_product_id'] as String?,
    );
  }
}
