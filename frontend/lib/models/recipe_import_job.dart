class RecipeImportJob {
  final String id;
  final String status;
  final String? recipeId;
  final String? error;

  const RecipeImportJob({
    required this.id,
    required this.status,
    this.recipeId,
    this.error,
  });

  bool get isActive => status == 'queued' || status == 'processing';

  factory RecipeImportJob.fromJson(Map<String, dynamic> json) => RecipeImportJob(
        id: json['id'] as String,
        status: json['status'] as String,
        recipeId: json['recipe_id'] as String?,
        error: json['error'] as String?,
      );
}
