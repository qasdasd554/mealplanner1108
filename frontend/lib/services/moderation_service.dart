import 'api_client.dart';

/// Zarządzanie zgłoszeniami treści (Guideline 1.2 Apple) — wyłącznie dla
/// kont z rolą "admin" (backend odrzuci zwykłe konto kodem 403).
class ModerationService {
  final ApiClient _client = ApiClient();

  /// `status`: "pending" (domyślnie), "resolved", "dismissed", albo "all".
  Future<List<Map<String, dynamic>>> getReports({String status = 'pending'}) async {
    final response = await _client.get('/users/admin/reports?status=$status');
    return (response as List).cast<Map<String, dynamic>>();
  }

  Future<void> updateReportStatus(String reportId, String status) async {
    await _client.patch('/users/admin/reports/$reportId', body: {'status': status});
  }

  /// Lista wszystkich komentarzy w aplikacji (z wyszukiwarką).
  Future<List<Map<String, dynamic>>> getAllComments({String? search}) async {
    var path = '/users/admin/comments?limit=200';
    if (search != null && search.trim().isNotEmpty) {
      path += '&search=${Uri.encodeComponent(search.trim())}';
    }
    final response = await _client.get(path);
    return (response as List).cast<Map<String, dynamic>>();
  }

  /// Usunięcie komentarza korzysta z istniejącego endpointu przepisów —
  /// administrator ma tam uprawnienie do kasowania cudzych komentarzy.
  Future<void> deleteComment(String recipeId, String commentId) async {
    await _client.delete('/recipes/$recipeId/comments/$commentId');
  }

  /// Lista kont z wyszukiwarką; `onlyBanned` zawęża do zablokowanych.
  Future<List<Map<String, dynamic>>> getUsers({
    String? search,
    bool onlyBanned = false,
  }) async {
    var path = '/users/admin/all?limit=200';
    if (onlyBanned) path += '&only_banned=true';
    if (search != null && search.trim().isNotEmpty) {
      path += '&search=${Uri.encodeComponent(search.trim())}';
    }
    final response = await _client.get(path);
    return (response as List).cast<Map<String, dynamic>>();
  }

  Future<void> banUser(String userId, {String? reason}) async {
    await _client.post('/users/admin/$userId/ban', body: {'reason': reason});
  }

  Future<void> unbanUser(String userId) async {
    await _client.post('/users/admin/$userId/unban');
  }

  /// Zdjęcia przepisów zgłoszone przez użytkowników, czekające na decyzję.
  Future<List<Map<String, dynamic>>> getPendingPhotos() async {
    final response = await _client.get('/recipes/admin/pending-photos');
    return (response as List).cast<Map<String, dynamic>>();
  }

  Future<void> approvePhoto(String recipeId) async {
    await _client.post('/recipes/$recipeId/photo/approve');
  }

  Future<void> rejectPhoto(String recipeId) async {
    await _client.post('/recipes/$recipeId/photo/reject');
  }
}
