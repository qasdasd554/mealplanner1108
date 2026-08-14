class AppNotification {
  final String id;
  final String notificationType;
  final String message;
  final String? recipeId;
  final String? recipeName;
  final String? commentId;
  final bool isRead;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    required this.notificationType,
    required this.message,
    this.recipeId,
    this.recipeName,
    this.commentId,
    required this.isRead,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      notificationType: json['notification_type'] as String? ?? 'recipe_comment',
      message: json['message'] as String? ?? '',
      recipeId: json['recipe_id'] as String?,
      recipeName: json['recipe_name'] as String?,
      commentId: json['comment_id'] as String?,
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
