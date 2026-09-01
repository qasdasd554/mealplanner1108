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
}
