import 'product.dart';

class RecipeIngredient {
  final String id;
  final String productId;
  final String? productName;
  final double quantity;
  final String unit;
  final bool isOptional;
  final int? kcal;
  final Product? product;

  RecipeIngredient({
    required this.id,
    required this.productId,
    this.productName,
    required this.quantity,
    required this.unit,
    required this.isOptional,
    this.kcal,
    this.product,
  });

  factory RecipeIngredient.fromJson(Map<String, dynamic> json) {
    return RecipeIngredient(
      id: json['id'] as String,
      productId: json['product_id'] as String,
      productName: json['product_name'] as String?,
      quantity: (json['quantity'] as num? ?? 0.0).toDouble(),
      unit: json['unit'] as String? ?? 'g',
      isOptional: json['is_optional'] as bool? ?? false,
      kcal: json['kcal'] as int?,
      product: json['product'] != null
          ? Product.fromJson(json['product'] as Map<String, dynamic>)
          : null,
    );
  }
}

class Recipe {
  final String id;
  final String name;
  final String? description;
  final String? cuisine;
  final String mealType; // 'śniadanie', 'obiad', 'kolacja', 'przekąska'
  final int? prepTimeMin;
  final int? cookTimeMin;
  final int servings;
  final String difficulty;
  final NutritionInfo nutritionTotal;
  final String? imageUrl;
  final bool isActive;
  final List<String> tags;
  final List<RecipeIngredient> ingredients;

  Recipe({
    required this.id,
    required this.name,
    this.description,
    this.cuisine,
    required this.mealType,
    this.prepTimeMin,
    this.cookTimeMin,
    required this.servings,
    required this.difficulty,
    required this.nutritionTotal,
    this.imageUrl,
    required this.isActive,
    required this.tags,
    required this.ingredients,
  });

  factory Recipe.fromJson(Map<String, dynamic> json) {
    return Recipe(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      cuisine: json['cuisine'] as String?,
      mealType: json['meal_type'] as String? ?? 'obiad',
      prepTimeMin: json['prep_time_min'] as int?,
      cookTimeMin: json['cook_time_min'] as int?,
      servings: json['servings'] as int? ?? 2,
      difficulty: json['difficulty'] as String? ?? 'średni',
      nutritionTotal: NutritionInfo.fromJson(
        json['nutrition_total'] as Map<String, dynamic>? ?? {},
      ),
      imageUrl: json['image_url'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
      ingredients: (json['ingredients'] as List<dynamic>?)
              ?.map((e) => RecipeIngredient.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  int get totalTimeMin => (prepTimeMin ?? 0) + (cookTimeMin ?? 0);

  String get mealTypeEmoji => switch (mealType.toLowerCase()) {
        'śniadanie' => '🌅',
        'obiad' => '☀️',
        'kolacja' => '🌙',
        'przekąska' => '🍎',
        _ => '🍽️',
      };
}
