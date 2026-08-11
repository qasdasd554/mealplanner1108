import 'api_client.dart';

class PriceComparisonResult {
  final String storeId;
  final String storeName;
  final double totalPrice;
  final int missingItemsCount;
  final String? storeLogoUrl;

  PriceComparisonResult({
    required this.storeId,
    required this.storeName,
    required this.totalPrice,
    required this.missingItemsCount,
    this.storeLogoUrl,
  });

  factory PriceComparisonResult.fromJson(Map<String, dynamic> json) {
    return PriceComparisonResult(
      storeId: json['store_id']?.toString() ?? '',
      storeName: json['store_name']?.toString() ?? 'Nieznany sklep',
      totalPrice: (json['total_price'] as num?)?.toDouble() ?? 0.0,
      missingItemsCount: json['missing_items_count'] as int? ?? 0,
      storeLogoUrl: json['store_logo_url']?.toString(),
    );
  }
}

class PriceCompareService {
  final ApiClient _apiClient = ApiClient();

  Future<List<PriceComparisonResult>> comparePrices(String mealPlanId) async {
    final response = await _apiClient.get('/api/v1/price-compare/$mealPlanId');
    if (response is List) {
      return response
          .map((item) => PriceComparisonResult.fromJson(item as Map<String, dynamic>))
          .toList();
    } else if (response != null && response['results'] is List) {
      final results = response['results'] as List;
      return results
          .map((item) => PriceComparisonResult.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    return [];
  }
}
