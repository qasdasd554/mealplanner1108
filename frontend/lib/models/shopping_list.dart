import '../utils/market_money.dart';

class ShoppingListItem {
  final String id;
  final String? productId;
  final String productName;
  final String? brand;
  final String departmentName;
  final int departmentSortOrder;
  final double requiredQuantity;
  final String unit;
  final double? estimatedPrice;
  bool isChecked;
  final bool isFromPantry;
  final String? substitutedForName;
  final String currencyCode;
  final bool priceIsEstimated;
  final String? quoteStatus;
  final double? packageQuantity;
  final String? packageUnit;
  final int? packageCount;
  final double? purchasedQuantity;
  final String? regionalOfferId;
  final Map<String, dynamic>? priceSource;

  ShoppingListItem({
    required this.id,
    this.productId,
    required this.productName,
    this.brand,
    required this.departmentName,
    required this.departmentSortOrder,
    required this.requiredQuantity,
    required this.unit,
    this.estimatedPrice,
    required this.isChecked,
    this.isFromPantry = false,
    this.substitutedForName,
    this.currencyCode = 'PLN',
    this.priceIsEstimated = true,
    this.quoteStatus,
    this.packageQuantity,
    this.packageUnit,
    this.packageCount,
    this.purchasedQuantity,
    this.regionalOfferId,
    this.priceSource,
  });

  factory ShoppingListItem.fromJson(Map<String, dynamic> json) {
    final currency = supportedCurrencyCode(
      json['currency_code']?.toString() ?? 'PLN',
    );
    final status = json['quote_status'] as String?;
    if (status != null &&
        !const {'quoted', 'unpriced', 'pantry'}.contains(status)) {
      throw const FormatException('Unsupported shopping quote status');
    }
    final price = (json['estimated_price'] as num?)?.toDouble();
    if (price != null && (!price.isFinite || price < 0)) {
      throw const FormatException('Invalid shopping price');
    }
    final pantry = json['is_from_pantry'] as bool? ?? false;
    final source = json['price_source'] as Map<String, dynamic>?;
    final checkedOn = source?['checked_on']?.toString() ?? '';
    final checkedDate = DateTime.tryParse(checkedOn);
    final sourceUri = Uri.tryParse(source?['url']?.toString() ?? '');
    final hasCheckedSource =
        checkedDate != null &&
        checkedDate.toIso8601String().substring(0, 10) == checkedOn &&
        sourceUri != null &&
        const {'http', 'https'}.contains(sourceUri.scheme) &&
        sourceUri.host.isNotEmpty &&
        (source?['publisher']?.toString().trim().isNotEmpty ?? false);
    final hasBritishPrice =
        (status == 'quoted' && price != null && price > 0) ||
        (status == 'pantry' && pantry && price == 0);
    return ShoppingListItem(
      id: json['id'] as String,
      productId: json['product_id'] as String?,
      productName: json['product_name'] as String,
      brand: json['brand'] as String?,
      departmentName: json['department_name'] as String? ?? 'Inne',
      departmentSortOrder: json['department_sort_order'] as int? ?? 99,
      requiredQuantity: (json['required_quantity'] as num? ?? 0.0).toDouble(),
      unit: json['unit'] as String? ?? 'szt',
      estimatedPrice: currency == 'GBP' && !hasBritishPrice ? null : price,
      isChecked: json['is_checked'] as bool? ?? false,
      isFromPantry: pantry,
      substitutedForName: json['substituted_for_name'] as String?,
      currencyCode: currency,
      priceIsEstimated:
          (json['price_is_estimated'] as bool? ?? true) ||
          (currency == 'GBP' && !pantry && !hasCheckedSource),
      quoteStatus: status,
      packageQuantity: (json['package_quantity'] as num?)?.toDouble(),
      packageUnit: json['package_unit'] as String?,
      packageCount: json['package_count'] as int?,
      purchasedQuantity: (json['purchased_quantity'] as num?)?.toDouble(),
      regionalOfferId: json['regional_offer_id'] as String?,
      priceSource: source,
    );
  }

  /// Package display is based only on the explicit regional snapshot. It never
  /// borrows a Polish Product's default quantity or invents a 100 g package.
  bool get hasReliablePackage =>
      packageQuantity != null &&
      packageQuantity!.isFinite &&
      packageQuantity! > 0 &&
      const {'g', 'ml'}.contains(packageUnit) &&
      packageCount != null &&
      packageCount! > 0 &&
      purchasedQuantity != null &&
      purchasedQuantity!.isFinite &&
      (purchasedQuantity! - packageQuantity! * packageCount!).abs() < 0.001;
}

class ShoppingList {
  final String id;
  final String mealPlanId;
  final String storeId;
  final String storeName;
  final String status;
  final double? totalEstimatedPrice;
  final String currencyCode;
  final bool hasUnpricedItems;
  final Map<String, List<ShoppingListItem>> itemsByDepartment;
  final DateTime createdAt;

  ShoppingList({
    required this.id,
    required this.mealPlanId,
    required this.storeId,
    required this.storeName,
    required this.status,
    required this.totalEstimatedPrice,
    this.currencyCode = 'PLN',
    this.hasUnpricedItems = false,
    required this.itemsByDepartment,
    required this.createdAt,
  });

  factory ShoppingList.fromJson(
    Map<String, dynamic> json, {
    String? expectedCurrencyCode,
  }) {
    // A legacy payload always means PLN, even on a British device/account.
    final currency = supportedCurrencyCode(
      json['currency_code']?.toString() ?? 'PLN',
    );
    if (expectedCurrencyCode != null &&
        supportedCurrencyCode(expectedCurrencyCode) != currency) {
      throw const FormatException(
        'Shopping list currency does not match account market',
      );
    }
    final rawGrouped =
        json['items_by_department'] as Map<String, dynamic>? ?? {};
    final parsedGrouped = <String, List<ShoppingListItem>>{};

    rawGrouped.forEach((key, value) {
      if (value is List) {
        parsedGrouped[key] =
            value
                .map(
                  (item) =>
                      ShoppingListItem.fromJson(item as Map<String, dynamic>),
                )
                .toList();
      }
    });
    final items = parsedGrouped.values.expand((items) => items);
    if (items.any((item) => item.currencyCode != currency)) {
      throw const FormatException('Cannot mix shopping list currencies');
    }
    final incomplete =
        (json['has_unpriced_items'] as bool? ?? false) ||
        items.any((item) => !item.isFromPantry && item.estimatedPrice == null);
    final total = (json['total_estimated_price'] as num?)?.toDouble();
    if (total != null && (!total.isFinite || total < 0)) {
      throw const FormatException('Invalid shopping list total');
    }

    return ShoppingList(
      id: json['id'] as String,
      mealPlanId: json['meal_plan_id'] as String,
      storeId: json['store_id'] as String,
      storeName: json['store_name'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      totalEstimatedPrice: incomplete ? null : total,
      currencyCode: currency,
      hasUnpricedItems: incomplete,
      itemsByDepartment: parsedGrouped,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  int get totalItems {
    return itemsByDepartment.values.fold(
      0,
      (sum, list) => sum + list.where((item) => !item.isFromPantry).length,
    );
  }

  /// Kwota za produkty JESZCZE NIEKUPIONE — czyli ile realnie zostało
  /// do zapłaty przy kasie.
  ///
  /// `totalEstimatedPrice` przychodzi z serwera jako suma CAŁEJ listy
  /// i nie zmienia się przy odhaczaniu, więc licznik stał w miejscu
  /// mimo wrzucania kolejnych rzeczy do koszyka. Tę wartość liczymy
  /// lokalnie z pozycji, dzięki czemu maleje natychmiast po odhaczeniu,
  /// bez czekania na odpowiedź serwera.
  double get remainingPrice {
    var sum = 0.0;
    for (final items in itemsByDepartment.values) {
      for (final item in items) {
        if (!item.isFromPantry && !item.isChecked) {
          sum += item.estimatedPrice ?? 0;
        }
      }
    }
    return sum;
  }

  double? get remainingQuotedPrice => hasUnknownPrices ? null : remainingPrice;

  bool get hasUnknownPrices =>
      (currencyCode == 'GBP' && hasUnpricedItems) ||
      itemsByDepartment.values.any(
        (items) => items.any(
          (item) =>
              !item.isFromPantry &&
              !item.isChecked &&
              item.estimatedPrice == null,
        ),
      );

  /// Czy wszystko na liście jest już odhaczone (i lista nie jest pusta).
  bool get isFullyChecked => totalItems > 0 && checkedItems == totalItems;

  int get checkedItems {
    return itemsByDepartment.values.fold(
      0,
      (sum, list) =>
          sum +
          list.where((item) => !item.isFromPantry && item.isChecked).length,
    );
  }

  double get progress {
    final total = totalItems;
    if (total == 0) return 0.0;
    return checkedItems / total;
  }
}
