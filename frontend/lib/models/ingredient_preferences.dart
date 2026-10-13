class IngredientChoice {
  final String id;
  final String name;

  const IngredientChoice({required this.id, required this.name});

  factory IngredientChoice.fromJson(Map<String, dynamic> json) =>
      IngredientChoice(id: json['id'] as String, name: json['name'] as String);
}

class IngredientPreferences {
  final List<IngredientChoice> liked;
  final List<IngredientChoice> disliked;

  const IngredientPreferences({
    this.liked = const [],
    this.disliked = const [],
  });

  factory IngredientPreferences.fromJson(
    Map<String, dynamic> json,
  ) => IngredientPreferences(
    liked:
        (json['liked_products'] as List<dynamic>? ?? [])
            .map((e) => IngredientChoice.fromJson(e as Map<String, dynamic>))
            .toList(),
    disliked:
        (json['disliked_products'] as List<dynamic>? ?? [])
            .map((e) => IngredientChoice.fromJson(e as Map<String, dynamic>))
            .toList(),
  );

  Map<String, dynamic> toJson() => {
    'liked_product_ids': liked.map((p) => p.id).toList(),
    'disliked_product_ids': disliked.map((p) => p.id).toList(),
  };
}
