import '../models/product.dart';
import '../models/barcode_lookup_result.dart';
import 'api_client.dart';
import '../config/api_config.dart';

/// Pojedynczy produkt zapisany w spiżarni użytkownika.
class PantryItem {
  final String id;
  final Product product;
  final double? quantity;
  final String? unit;

  PantryItem({
    required this.id,
    required this.product,
    this.quantity,
    this.unit,
  });

  factory PantryItem.fromJson(Map<String, dynamic> json) {
    return PantryItem(
      id: json['id'] as String,
      product: Product.fromJson(json['product'] as Map<String, dynamic>),
      quantity: (json['quantity'] as num?)?.toDouble(),
      unit: json['unit'] as String?,
    );
  }
}

/// Spiżarnia — trwała lista produktów, które użytkownik faktycznie ma w
/// domu, niezależna od żadnego konkretnego planu posiłków. Używana m.in.
/// jako źródło dla "Co ugotować z tego, co mam".
class PantryService {
  final ApiClient _client = ApiClient();

  Future<List<PantryItem>> getPantry() async {
    final response = await _client.get(ApiConfig.pantry);
    return (response as List)
        .map((e) => PantryItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<PantryItem>> addItems(
    List<String> productIds, {
    double? quantity,
    String? unit,
  }) async {
    final response = await _client.post(
      ApiConfig.pantry,
      body: {
        'product_ids': productIds,
        if (quantity != null) 'quantity': quantity,
        if (unit != null) 'unit': unit,
      },
    );
    return (response as List)
        .map((e) => PantryItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<PantryItem> addFromBarcode(
    String barcode, {
    required double quantity,
    required String unit,
    bool batch = false,
    BarcodeLookupResult? lookupResult,
  }) async {
    final response = await _client.post(
      '${ApiConfig.pantry}from-barcode',
      body: {
        'barcode': barcode,
        'quantity': quantity,
        'unit': unit,
        if (batch) 'batch': true,
        if (lookupResult?.name?.trim().isNotEmpty == true)
          'name': lookupResult!.name,
        if (lookupResult?.brand?.trim().isNotEmpty == true)
          'brand': lookupResult!.brand,
        if (lookupResult?.kcalPer100 != null)
          'kcal_per_100': lookupResult!.kcalPer100,
        if (lookupResult?.proteinPer100 != null)
          'protein_per_100': lookupResult!.proteinPer100,
        if (lookupResult?.fatPer100 != null)
          'fat_per_100': lookupResult!.fatPer100,
        if (lookupResult?.carbsPer100 != null)
          'carbs_per_100': lookupResult!.carbsPer100,
      },
      timeout: const Duration(seconds: 15),
    );
    return PantryItem.fromJson(response as Map<String, dynamic>);
  }

  Future<void> deleteItem(String itemId) async {
    await _client.delete('${ApiConfig.pantry}$itemId');
  }

  /// Ustawia/zmienia ilość produktu już zapisanego w spiżarni. `unit`
  /// jest opcjonalne — jeśli pominięte, backend zostawia poprzednią
  /// jednostkę bez zmian (przydatne przy samej korekcie liczby, np.
  /// "zjadłem połowę", bez konieczności podawania jednostki na nowo).
  Future<PantryItem> updateQuantity(
    String itemId, {
    double? quantity,
    String? unit,
  }) async {
    final body = <String, dynamic>{'quantity': quantity};
    if (unit != null) body['unit'] = unit;
    final response = await _client.patch(
      '${ApiConfig.pantry}$itemId',
      body: body,
    );
    return PantryItem.fromJson(response as Map<String, dynamic>);
  }
}
