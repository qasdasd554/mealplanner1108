import '../models/wellness_statistics.dart';
import 'api_client.dart';

class WellnessStatisticsService {
  final ApiClient _client;

  WellnessStatisticsService({ApiClient? client})
    : _client = client ?? ApiClient();

  Future<WellnessStatistics> getStatistics({int days = 30}) async {
    try {
      final response = await _client.get('/wellness/stats/overview?days=$days');
      return WellnessStatistics.fromJson(response as Map<String, dynamic>);
    } on ApiException catch (error) {
      // Alias pozostaje obsługiwany przez backend. Dzięki temu ekran nie
      // przestanie działać podczas krótkiego okna wdrożeniowego, gdy frontend
      // i backend aktualizują się w innej kolejności.
      if (error.statusCode != 404) rethrow;
      final response = await _client.get('/wellness/statistics?days=$days');
      return WellnessStatistics.fromJson(response as Map<String, dynamic>);
    }
  }
}
