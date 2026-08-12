import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/food_log.dart';

class FoodLogService {
  // Wcześniej było tu zahardkodowane 'http://localhost:8000/api' — adres
  // nieosiągalny z urządzenia mobilnego, w dodatku z innym prefiksem niż
  // reszta aplikacji. Teraz korzystamy ze wspólnej konfiguracji.
  String get baseUrl => ApiConfig.apiUrl;

  final http.Client _client = http.Client();

  String _formatDate(DateTime date) =>
      "${date.year}-${date.month.toString().padLeft(2,'0')}-${date.day.toString().padLeft(2,'0')}";

  Future<List<FoodLogEntry>> getLogsForDate(DateTime date, String token) async {
    // Backend: GET /food-log/?entry_date=YYYY-MM-DD
    final response = await _client.get(
      Uri.parse('$baseUrl/food-log/?entry_date=${_formatDate(date)}'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final List data = json.decode(response.body);
      return data.map((json) => FoodLogEntry.fromJson(json)).toList();
    } else {
      throw Exception('Nie udało się pobrać dziennika żywieniowego');
    }
  }

  Future<DailySummary> getDailySummary(DateTime date, String token) async {
    // Backend: GET /food-log/summary?entry_date=YYYY-MM-DD
    final response = await _client.get(
      Uri.parse('$baseUrl/food-log/summary?entry_date=${_formatDate(date)}'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return DailySummary.fromJson(json.decode(response.body));
    } else {
      throw Exception('Nie udało się pobrać podsumowania dnia');
    }
  }

  Future<FoodLogEntry> addFoodLog(Map<String, dynamic> entryData, String token) async {
    // Backend: POST /food-log/
    final response = await _client.post(
      Uri.parse('$baseUrl/food-log/'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode(entryData),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return FoodLogEntry.fromJson(json.decode(response.body));
    } else {
      throw Exception('Nie udało się dodać wpisu do dziennika');
    }
  }

  Future<void> deleteFoodLog(String logId, String token) async {
    // Backend: DELETE /food-log/{entry_id}
    final response = await _client.delete(
      Uri.parse('$baseUrl/food-log/$logId'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Nie udało się usunąć wpisu z dziennika');
    }
  }
}
