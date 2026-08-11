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
  final String? substitutedForName;

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
    this.substitutedForName,
  });

  factory ShoppingListItem.fromJson(Map<String, dynamic> json) {
    return ShoppingListItem(
      id: json['id'] as String,
      productId: json['product_id'] as String?,
      productName: json['product_name'] as String,
      brand: json['brand'] as String?,
      departmentName: json['department_name'] as String? ?? 'Inne',
      departmentSortOrder: json['department_sort_order'] as int? ?? 99,
      requiredQuantity: (json['required_quantity'] as num? ?? 0.0).toDouble(),
      unit: json['unit'] as String? ?? 'szt',
      estimatedPrice: json['estimated_price'] != null
          ? (json['estimated_price'] as num).toDouble()
          : null,
      isChecked: json['is_checked'] as bool? ?? false,
      substitutedForName: json['substituted_for_name'] as String?,
    );
  }
}

class ShoppingList {
  final String id;
  final String mealPlanId;
  final String storeId;
  final String storeName;
  final String status;
  final double totalEstimatedPrice;
  final Map<String, List<ShoppingListItem>> itemsByDepartment;
  final DateTime createdAt;

  ShoppingList({
    required this.id,
    required this.mealPlanId,
    required this.storeId,
    required this.storeName,
    required this.status,
    required this.totalEstimatedPrice,
    required this.itemsByDepartment,
    required this.createdAt,
  });

  factory ShoppingList.fromJson(Map<String, dynamic> json) {
    final rawGrouped = json['items_by_department'] as Map<String, dynamic>? ?? {};
    final parsedGrouped = <String, List<ShoppingListItem>>{};

    rawGrouped.forEach((key, value) {
      if (value is List) {
        parsedGrouped[key] = value
            .map((item) => ShoppingListItem.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    });

    return ShoppingList(
      id: json['id'] as String,
      mealPlanId: json['meal_plan_id'] as String,
      storeId: json['store_id'] as String,
      storeName: json['store_name'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      totalEstimatedPrice: (json['total_estimated_price'] as num? ?? 0.0).toDouble(),
      itemsByDepartment: parsedGrouped,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  int get totalItems {
    return itemsByDepartment.values.fold(0, (sum, list) => sum + list.length);
  }

  int get checkedItems {
    return itemsByDepartment.values.fold(
      0,
      (sum, list) => sum + list.where((item) => item.isChecked).length,
    );
  }

  double get progress {
    final total = totalItems;
    if (total == 0) return 0.0;
    return checkedItems / total;
  }
}
