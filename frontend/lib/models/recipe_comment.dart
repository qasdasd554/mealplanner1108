class RecipeComment {
  final String id;
  final String recipeId;
  final String userId;
  final String authorName;
  final String? text;
  // Dane zdjęcia zakodowane w Base64 (bez prefiksu "data:image/..."),
  // dokładnie tak, jak zwraca je backend — zdjęcie jest przechowywane w
  // bazie danych, nie jako URL do pliku (Render nie ma trwałego dysku).
  final String? photoBase64;
  final DateTime createdAt;
  final int likeCount;
  final bool likedByMe;

  RecipeComment({
    required this.id,
    required this.recipeId,
    required this.userId,
    required this.authorName,
    this.text,
    this.photoBase64,
    required this.createdAt,
    this.likeCount = 0,
    this.likedByMe = false,
  });

  factory RecipeComment.fromJson(Map<String, dynamic> json) {
    return RecipeComment(
      id: json['id'] as String,
      recipeId: json['recipe_id'] as String,
      userId: json['user_id'] as String,
      authorName: json['author_name'] as String? ?? 'Użytkownik',
      text: json['text'] as String?,
      photoBase64: json['photo_base64'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      likeCount: json['like_count'] as int? ?? 0,
      likedByMe: json['liked_by_me'] as bool? ?? false,
    );
  }

  /// Kopia komentarza z podmienionym stanem polubienia — do optymistycznej
  /// aktualizacji UI (nie czekamy na odpowiedź serwera, żeby serce
  /// zareagowało natychmiast po dotknięciu).
  RecipeComment copyWithLike({required bool likedByMe, required int likeCount}) {
    return RecipeComment(
      id: id,
      recipeId: recipeId,
      userId: userId,
      authorName: authorName,
      text: text,
      photoBase64: photoBase64,
      createdAt: createdAt,
      likeCount: likeCount,
      likedByMe: likedByMe,
    );
  }
}
