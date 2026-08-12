import 'api_client.dart';

class PriceCompareItem {
  final String productName;
  final double quantityNeeded;
  final String unit;
  final double priceInStore;

  PriceCompareItem({
    required this.productName,
    required this.quantityNeeded,
    required this.unit,
    required this.priceInStore,
  });

  factory PriceCompareItem.fromJson(Map<String, dynamic> json) {
    return PriceCompareItem(
      productName: json['product_name']?.toString() ?? '',
      quantityNeeded: (json['quantity_needed'] as num?)?.toDouble() ?? 0.0,
      unit: json['unit']?.toString() ?? '',
      priceInStore: (json['price_in_store'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class PriceComparisonResult {
  final String storeId;
  final String storeName;
  final double totalPrice;
  final bool isCheapest;
  final double savingsVsMostExpensive;
  final List<PriceCompareItem> items;

  PriceComparisonResult({
    required this.storeId,
    required this.storeName,
    required this.totalPrice,
    required this.isCheapest,
    required this.savingsVsMostExpensive,
    required this.items,
  });

  factory PriceComparisonResult.fromJson(Map<String, dynamic> json) {
    return PriceComparisonResult(
      storeId: json['store_id']?.toString() ?? '',
      storeName: json['store_name']?.toString() ?? 'Nieznany sklep',
      totalPrice: (json['total_price'] as num?)?.toDouble() ?? 0.0,
      isCheapest: json['is_cheapest'] as bool? ?? false,
      savingsVsMostExpensive:
          (json['savings_vs_most_expensive'] as num?)?.toDouble() ?? 0.0,
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => PriceCompareItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
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
          .map((item) => PriceComparisonResult.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    return [];
  }
}
