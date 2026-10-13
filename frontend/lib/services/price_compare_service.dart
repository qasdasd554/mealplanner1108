import 'api_client.dart';

class PriceCompareItem {
  final String productName;
  final double quantityNeeded;
  final String unit;
  final double priceInStore;
  final bool priceIsEstimated;
  final DateTime? lastVerified;
  // Marka własna sklepu dla tego produktu (np. "Mleczna Dolina"), jeśli
  // potwierdzona — null, jeśli sklep nie ma marki własnej w tej kategorii.
  final String? storeBrandName;

  PriceCompareItem({
    required this.productName,
    required this.quantityNeeded,
    required this.unit,
    required this.priceInStore,
    this.priceIsEstimated = true,
    this.lastVerified,
    this.storeBrandName,
  });

  factory PriceCompareItem.fromJson(Map<String, dynamic> json) {
    return PriceCompareItem(
      productName: json['product_name']?.toString() ?? '',
      quantityNeeded: (json['quantity_needed'] as num?)?.toDouble() ?? 0.0,
      unit: json['unit']?.toString() ?? '',
      priceInStore: (json['price_in_store'] as num?)?.toDouble() ?? 0.0,
      priceIsEstimated: json['price_is_estimated'] as bool? ?? true,
      lastVerified: DateTime.tryParse(json['last_verified']?.toString() ?? ''),
      storeBrandName: json['store_brand_name'] as String?,
    );
  }

  /// Nazwa do wyświetlenia — z marką sklepową, jeśli dostępna.
  String get displayName =>
      storeBrandName != null ? '$productName ($storeBrandName)' : productName;
}

class PriceComparisonResult {
  final String storeId;
  final String storeName;
  final double totalPrice;
  final bool isCheapest;
  final double savingsVsMostExpensive;
  final List<PriceCompareItem> items;
  final bool hasEstimatedPrices;
  final bool isComplete;
  final List<String> missingProducts;

  PriceComparisonResult({
    required this.storeId,
    required this.storeName,
    required this.totalPrice,
    required this.isCheapest,
    required this.savingsVsMostExpensive,
    required this.items,
    this.hasEstimatedPrices = true,
    this.isComplete = true,
    this.missingProducts = const [],
  });

  factory PriceComparisonResult.fromJson(Map<String, dynamic> json) {
    final items =
        (json['items'] as List<dynamic>?)
            ?.map((e) => PriceCompareItem.fromJson(e as Map<String, dynamic>))
            .toList() ??
        <PriceCompareItem>[];
    final missingProducts =
        (json['missing_products'] as List<dynamic>?)
            ?.map((name) => name.toString())
            .toList() ??
        <String>[];
    final isComplete =
        (json['is_complete'] as bool? ?? missingProducts.isEmpty) &&
        missingProducts.isEmpty;
    return PriceComparisonResult(
      storeId: json['store_id']?.toString() ?? '',
      storeName: json['store_name']?.toString() ?? 'Nieznany sklep',
      totalPrice: (json['total_price'] as num?)?.toDouble() ?? 0.0,
      isCheapest: isComplete && (json['is_cheapest'] as bool? ?? false),
      savingsVsMostExpensive:
          isComplete
              ? (json['savings_vs_most_expensive'] as num?)?.toDouble() ?? 0.0
              : 0.0,
      items: items,
      hasEstimatedPrices:
          (json['has_estimated_prices'] as bool? ?? false) ||
          items.any((item) => item.priceIsEstimated),
      isComplete: isComplete,
      missingProducts: missingProducts,
    );
  }

  /// Nie porównuj ceny części koszyka z ceną pełnej listy zakupów.
  static int compareForDisplay(
    PriceComparisonResult a,
    PriceComparisonResult b,
  ) {
    if (a.isComplete != b.isComplete) return a.isComplete ? -1 : 1;
    return a.totalPrice.compareTo(b.totalPrice);
  }
}

class PriceCompareService {
  final ApiClient _apiClient = ApiClient();

  Future<List<PriceComparisonResult>> comparePrices(String mealPlanId) async {
    // ApiClient.get() sam dokleja prefiks /api/v1 (patrz ApiConfig.apiUrl).
    // Wcześniej był on doklejony tutaj DRUGI RAZ, więc żądanie leciało pod
    // /api/v1/api/v1/price-compare/... i backend zawsze odpowiadał 404.
    final response = await _apiClient.get('/price-compare/$mealPlanId');
    if (response is List) {
      return response
          .map(
            (item) =>
                PriceComparisonResult.fromJson(item as Map<String, dynamic>),
          )
          .toList();
    }
    return [];
  }
}
