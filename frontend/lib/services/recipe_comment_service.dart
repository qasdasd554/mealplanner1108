import '../models/recipe_comment.dart';
import 'api_client.dart';

class RecipeCommentService {
  final ApiClient _client = ApiClient();

  Future<List<RecipeComment>> getComments(String recipeId) async {
    final response = await _client.get('/recipes/$recipeId/comments');
    if (response is List) {
      return response.map((e) => RecipeComment.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  /// Dodaje komentarz — [text] i/lub [photoBase64] (przynajmniej jedno
  /// z nich musi być podane, backend odrzuci pusty komentarz).
  Future<RecipeComment> addComment(
    String recipeId, {
    String? text,
    String? photoBase64,
  }) async {
    final response = await _client.post('/recipes/$recipeId/comments', body: {
      if (text != null) 'text': text,
      if (photoBase64 != null) 'photo_base64': photoBase64,
    });
    return RecipeComment.fromJson(response as Map<String, dynamic>);
  }

  Future<void> deleteComment(String recipeId, String commentId) async {
    await _client.delete('/recipes/$recipeId/comments/$commentId');
  }

  Future<void> likeComment(String recipeId, String commentId) async {
    await _client.post('/recipes/$recipeId/comments/$commentId/like');
  }

  Future<void> unlikeComment(String recipeId, String commentId) async {
    await _client.delete('/recipes/$recipeId/comments/$commentId/like');
  }
}
