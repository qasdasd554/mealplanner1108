import 'api_client.dart';
import '../utils/market_money.dart';
import '../models/shopping_list.dart';

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
  final String? regionalOfferId;
  final double? packageQuantity;
  final String? packageUnit;
  final int? packageCount;
  final double? purchasedQuantity;
  final double? pricePerPackage;
  final Map<String, dynamic>? priceSource;
  final String? offerFingerprint;
  final bool isFromPantry;
  final bool isChecked;

  PriceCompareItem({
    required this.productName,
    required this.quantityNeeded,
    required this.unit,
    required this.priceInStore,
    this.priceIsEstimated = true,
    this.lastVerified,
    this.storeBrandName,
    this.regionalOfferId,
    this.packageQuantity,
    this.packageUnit,
    this.packageCount,
    this.purchasedQuantity,
    this.pricePerPackage,
    this.priceSource,
    this.offerFingerprint,
    this.isFromPantry = false,
    this.isChecked = false,
  });

  factory PriceCompareItem.fromJson(
    Map<String, dynamic> json, {
    bool requirePrice = false,
  }) {
    final price = (json['price_in_store'] as num?)?.toDouble();
    final fromPantry = json['is_from_pantry'] as bool? ?? false;
    if (requirePrice &&
        (price == null ||
            !price.isFinite ||
            (fromPantry ? price != 0 : price <= 0))) {
      throw const FormatException(
        'A quoted GBP item requires a positive price',
      );
    }
    final verified = DateTime.tryParse(json['last_verified']?.toString() ?? '');
    final source = json['price_source'] as Map<String, dynamic>?;
    final sourceUri = Uri.tryParse(source?['url']?.toString() ?? '');
    final checkedOn = source?['checked_on']?.toString();
    final hasCheckedSource =
        verified != null &&
        sourceUri != null &&
        sourceUri.scheme == 'https' &&
        sourceUri.host.isNotEmpty &&
        (source?['publisher']?.toString().trim().isNotEmpty ?? false) &&
        checkedOn == verified.toIso8601String().substring(0, 10);
    return PriceCompareItem(
      productName: json['product_name']?.toString() ?? '',
      quantityNeeded: (json['quantity_needed'] as num?)?.toDouble() ?? 0.0,
      unit: json['unit']?.toString() ?? '',
      priceInStore: price ?? 0.0,
      // A false flag alone is not price provenance. A missing/invalid checked
      // date must remain visibly estimated even on a partially upgraded API.
      priceIsEstimated:
          !fromPantry &&
          ((json['price_is_estimated'] as bool? ?? true) ||
              verified == null ||
              (requirePrice && !hasCheckedSource)),
      lastVerified: verified,
      storeBrandName: json['store_brand_name'] as String?,
      regionalOfferId: json['regional_offer_id'] as String?,
      packageQuantity: (json['package_quantity'] as num?)?.toDouble(),
      packageUnit: json['package_unit'] as String?,
      packageCount: (json['package_count'] as num?)?.toInt(),
      purchasedQuantity: (json['purchased_quantity'] as num?)?.toDouble(),
      pricePerPackage: (json['price_per_package'] as num?)?.toDouble(),
      priceSource: source,
      offerFingerprint: json['offer_fingerprint'] as String?,
      isFromPantry: fromPantry,
      isChecked: json['is_checked'] as bool? ?? false,
    );
  }

  /// Nazwa do wyświetlenia — z marką sklepową, jeśli dostępna.
  String get displayName =>
      storeBrandName != null ? '$productName ($storeBrandName)' : productName;
}

class PriceComparisonResult {
  final String storeId;
  final String storeName;
  final double? totalPrice;
  final bool isCheapest;
  final double savingsVsMostExpensive;
  final List<PriceCompareItem> items;
  final bool hasEstimatedPrices;
  final bool isComplete;
  final List<String> missingProducts;
  final String currencyCode;

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
    this.currencyCode = 'PLN',
  });

  factory PriceComparisonResult.fromJson(Map<String, dynamic> json) {
    final currency = supportedCurrencyCode(
      json['currency_code']?.toString() ?? 'PLN',
    );
    final rawTotal = (json['total_price'] as num?)?.toDouble();
    if (rawTotal != null && (!rawTotal.isFinite || rawTotal < 0)) {
      throw const FormatException('Invalid basket total');
    }
    final items =
        (json['items'] as List<dynamic>?)
            ?.map(
              (e) => PriceCompareItem.fromJson(
                e as Map<String, dynamic>,
                requirePrice: currency == 'GBP',
              ),
            )
            .toList() ??
        <PriceCompareItem>[];
    final missingProducts =
        (json['missing_products'] as List<dynamic>?)
            ?.map((name) => name.toString())
            .toList() ??
        <String>[];
    final isComplete =
        (json['is_complete'] as bool? ?? missingProducts.isEmpty) &&
        missingProducts.isEmpty &&
        (currency != 'GBP' || rawTotal != null);
    return PriceComparisonResult(
      storeId: json['store_id']?.toString() ?? '',
      storeName: json['store_name']?.toString() ?? 'Nieznany sklep',
      // GB partial totals are deliberately absent, not a price of zero.
      // Preserve legacy PLN subtotal presentation for existing clients/data.
      totalPrice: currency == 'GBP' && !isComplete ? null : rawTotal ?? 0.0,
      isCheapest: isComplete && (json['is_cheapest'] as bool? ?? false),
      savingsVsMostExpensive:
          isComplete
              ? (json['savings_vs_most_expensive'] as num?)?.toDouble() ?? 0.0
              : 0.0,
      items: items,
      hasEstimatedPrices:
          (json['has_estimated_prices'] as bool? ?? true) ||
          items.any((item) => item.priceIsEstimated),
      isComplete: isComplete,
      missingProducts: missingProducts,
      // Legacy responses predate international markets and always mean PLN.
      currencyCode: currency,
    );
  }

  /// Nie porównuj ceny części koszyka z ceną pełnej listy zakupów.
  static int compareForDisplay(
    PriceComparisonResult a,
    PriceComparisonResult b,
  ) {
    if (supportedCurrencyCode(a.currencyCode) !=
        supportedCurrencyCode(b.currencyCode)) {
      throw const FormatException('Cannot compare different currencies');
    }
    if (a.isComplete != b.isComplete) return a.isComplete ? -1 : 1;
    final left = a.totalPrice;
    final right = b.totalPrice;
    if (left == null || right == null) {
      if (left == null && right == null)
        return a.storeName.compareTo(b.storeName);
      return left == null ? 1 : -1;
    }
    return left.compareTo(right);
  }
}

class PriceCompareService {
  PriceCompareService({ApiClient? client}) : _apiClient = client ?? ApiClient();

  final ApiClient _apiClient;

  Future<List<PriceComparisonResult>> comparePrices(
    String mealPlanId, {
    String expectedCurrencyCode = 'PLN',
  }) async {
    // ApiClient.get() sam dokleja prefiks /api/v1 (patrz ApiConfig.apiUrl).
    // Wcześniej był on doklejony tutaj DRUGI RAZ, więc żądanie leciało pod
    // /api/v1/api/v1/price-compare/... i backend zawsze odpowiadał 404.
    return _readComparison('/price-compare/$mealPlanId', expectedCurrencyCode);
  }

  /// Public shopping-list API identifiers use ShoppingList.mealPlanId, even
  /// for technical/manual lists; this endpoint reads their actual item rows.
  Future<List<PriceComparisonResult>> compareShoppingList(
    String shoppingListId, {
    required String expectedCurrencyCode,
  }) => _readComparison(
    '/price-compare/shopping-list/$shoppingListId',
    expectedCurrencyCode,
  );

  Future<ShoppingList> switchShoppingListStore(
    String shoppingListId,
    String storeId, {
    required String expectedCurrencyCode,
  }) async {
    final currency = supportedCurrencyCode(expectedCurrencyCode);
    final response = await _apiClient.put(
      '/shopping-lists/$shoppingListId/store',
      body: {'store_id': storeId},
    );
    final updated = ShoppingList.fromJson(
      response as Map<String, dynamic>,
      expectedCurrencyCode: currency,
    );
    if (updated.mealPlanId != shoppingListId || updated.storeId != storeId) {
      throw const FormatException(
        'Shopping-list switch response identity mismatch',
      );
    }
    return updated;
  }

  Future<List<PriceComparisonResult>> _readComparison(
    String path,
    String expectedCurrencyCode,
  ) async {
    final expectedCurrency = supportedCurrencyCode(expectedCurrencyCode);
    final response = await _apiClient.get(path);
    if (response is List) {
      final results =
          response
              .map(
                (item) => PriceComparisonResult.fromJson(
                  item as Map<String, dynamic>,
                ),
              )
              .toList();
      // Do not sort, total or relabel stale/foreign-market responses. The
      // backend also enforces this boundary; the client must not hide mistakes.
      if (results.any((result) => result.currencyCode != expectedCurrency)) {
        throw const FormatException('Price comparison currency mismatch');
      }
      return results;
    }
    return [];
  }
}
