import 'product.dart';
import '../data/recipe_photo_map.dart';

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
  final List<String> instructions;
  final List<String> suggestedSeasonings;

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
    this.instructions = const [],
    this.suggestedSeasonings = const [],
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
      instructions: (json['instructions'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      suggestedSeasonings: (json['suggested_seasonings'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }

  int get totalTimeMin => (prepTimeMin ?? 0) + (cookTimeMin ?? 0);

  /// Ścieżka do lokalnej ilustracji kategorii dania (bez zależności od
  /// sieci — nie hotlinkujemy zdjęć z zewnętrznych serwisów, więc nic nie
  /// może się "zepsuć" ani naruszyć praw autorskich cudzych fotografii).
  /// Dopasowanie na podstawie nazwy, tagów i typu kuchni.
  /// Prawdziwe zdjęcie dania (wygenerowane przez AI, dostarczone przez
  /// użytkownika) — jeśli istnieje dla tego przepisu. `null`, jeśli nie ma
  /// (wtedy UI powinno pokazać [categoryImageAsset] jako zapasową ilustrację).
  String? get realPhotoAsset => kRecipePhotoAssets[name];

  String get categoryImageAsset {
    final haystack = ('$name ${tags.join(' ')} ${cuisine ?? ''}').toLowerCase();

    bool has(List<String> words) => words.any((w) => haystack.contains(w));

    if (has(['zupa', 'krem z', 'bulion', 'rosół'])) {
      return 'assets/recipe_categories/soup.svg';
    }
    if (has(['makaron', 'spaghetti', 'penne', 'pasta', 'lasagne'])) {
      return 'assets/recipe_categories/pasta.svg';
    }
    if (has(['sałatka', 'salatka', 'salad'])) {
      return 'assets/recipe_categories/salad.svg';
    }
    if (has(['kanapk', 'tost', 'bułk', 'bulka', 'quesadilla', 'tacos'])) {
      return 'assets/recipe_categories/sandwich.svg';
    }
    if (has(['łosoś', 'losos', 'ryba', 'ryby', 'dorsz', 'tuńczyk', 'tunczyk'])) {
      return 'assets/recipe_categories/fish.svg';
    }
    if (has(['pad thai', 'curry', 'sushi', 'wok', 'azjatyck'])) {
      return 'assets/recipe_categories/asian.svg';
    }
    if (has(['ryż', 'ryz', 'quinoa', 'risotto', 'bowl', 'kasz'])) {
      return 'assets/recipe_categories/rice_bowl.svg';
    }
    if (has([
      'kotlet',
      'schab',
      'kurczak',
      'mielone',
      'wołowin',
      'wolowin',
      'wieprzow',
      'indyk',
      'gulasz',
      'chili con',
    ])) {
      return 'assets/recipe_categories/meat.svg';
    }
    if (has([
      'owsiank',
      'jajecznic',
      'naleśnik',
      'nalesnik',
      'jogurt',
      'granola',
      'omlet',
    ]) ||
        mealType.toLowerCase() == 'śniadanie') {
      return 'assets/recipe_categories/breakfast.svg';
    }
    if (has(['deser', 'ciast', 'mus', 'owoc', 'jabłk', 'jablk', 'malin', 'banan']) ||
        mealType.toLowerCase() == 'przekąska') {
      return 'assets/recipe_categories/sweet_snack.svg';
    }
    return 'assets/recipe_categories/generic.svg';
  }
}
