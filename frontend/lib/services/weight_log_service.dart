import '../models/weight_log.dart';
import 'api_client.dart';

class WeightLogService {
  final ApiClient _client = ApiClient();

  Future<List<WeightLogEntry>> getLogs({int limit = 30}) async {
    final response = await _client.get('/wellness/weight?limit=$limit');
    return (response as List)
        .map((item) => WeightLogEntry.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<WeightLogEntry> save(DateTime date, double weightKg) async {
    final day = _formatDate(date);
    final response = await _client.put(
      '/wellness/weight/$day',
      body: {'weight_kg': weightKg},
    );
    return WeightLogEntry.fromJson(response as Map<String, dynamic>);
  }

  String _formatDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
