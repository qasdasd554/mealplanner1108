class NutritionInfo {
  final double kcal;
  final double protein;
  final double fat;
  final double carbs;
  final double fiber;

  NutritionInfo({
    required this.kcal,
    required this.protein,
    required this.fat,
    required this.carbs,
    required this.fiber,
  });

  factory NutritionInfo.fromJson(Map<String, dynamic> json) {
    return NutritionInfo(
      kcal: (json['kcal'] as num? ?? 0.0).toDouble(),
      protein: (json['protein'] as num? ?? 0.0).toDouble(),
      fat: (json['fat'] as num? ?? 0.0).toDouble(),
      carbs: (json['carbs'] as num? ?? 0.0).toDouble(),
      fiber: (json['fiber'] as num? ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'kcal': kcal,
        'protein': protein,
        'fat': fat,
        'carbs': carbs,
        'fiber': fiber,
      };
}

class Product {
  final String id;
  final String name;
  final String? brand;
  final String unit;
  final double defaultQuantity;
  final String? barcode;
  final NutritionInfo nutritionPer100;
  final String? imageUrl;

  Product({
    required this.id,
    required this.name,
    this.brand,
    required this.unit,
    required this.defaultQuantity,
    this.barcode,
    required this.nutritionPer100,
    this.imageUrl,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as String,
      name: json['name'] as String,
      brand: json['brand'] as String?,
      unit: json['unit'] as String? ?? 'szt',
      defaultQuantity: (json['default_quantity'] as num? ?? 1.0).toDouble(),
      barcode: json['barcode'] as String?,
      nutritionPer100: NutritionInfo.fromJson(
        json['nutrition_per_100'] as Map<String, dynamic>? ?? {},
      ),
      imageUrl: json['image_url'] as String?,
    );
  }
}

class StoreProduct {
  final String id;
  final String storeId;
  final String productId;
  final String? departmentId;
  final double price;
  final bool isAvailable;
  final Product? product;

  StoreProduct({
    required this.id,
    required this.storeId,
    required this.productId,
    this.departmentId,
    required this.price,
    required this.isAvailable,
    this.product,
  });

  factory StoreProduct.fromJson(Map<String, dynamic> json) {
    return StoreProduct(
      id: json['id'] as String,
      storeId: json['store_id'] as String,
      productId: json['product_id'] as String,
      departmentId: json['department_id'] as String?,
      price: (json['price'] as num? ?? 0.0).toDouble(),
      isAvailable: json['is_available'] as bool? ?? true,
      product: json['product'] != null
          ? Product.fromJson(json['product'] as Map<String, dynamic>)
          : null,
    );
  }
}
