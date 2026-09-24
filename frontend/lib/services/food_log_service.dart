import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/food_log.dart';

class FoodLogService {
  /// Ten sam limit co w ApiClient — patrz komentarz tam. Ten serwis
  /// jest jedynym w aplikacji, który używa WŁASNEGO http.Client zamiast
  /// wspólnego ApiClient, więc nie dziedziczył jego zabezpieczenia:
  /// żądanie do usypiającej się instancji Render (darmowy plan) mogło
  /// wisieć bez końca, bez żadnego komunikatu o błędzie.
  static const Duration _timeout = Duration(seconds: 45);

  // Wcześniej było tu zahardkodowane 'http://localhost:8000/api' — adres
  // nieosiągalny z urządzenia mobilnego, w dodatku z innym prefiksem niż
  // reszta aplikacji. Teraz korzystamy ze wspólnej konfiguracji.
  String get baseUrl => ApiConfig.apiUrl;

  final http.Client _client = http.Client();

  String _formatDate(DateTime date) =>
      "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

  Map<String, String> _headers(String token) => {
    'Authorization': 'Bearer $token',
    'Content-Type': 'application/json',
  };

  Future<List<FoodLogEntry>> getLogsForDate(DateTime date, String token) async {
    // Backend: GET /food-log/?entry_date=YYYY-MM-DD
    final response = await _client
        .get(
          Uri.parse('$baseUrl/food-log/?entry_date=${_formatDate(date)}'),
          headers: _headers(token),
        )
        .timeout(
          _timeout,
          onTimeout:
              () =>
                  throw Exception(
                    'Serwer nie odpowiedział na czas. Spróbuj ponownie za chwilę.',
                  ),
        );

    if (response.statusCode == 200) {
      final List data = json.decode(utf8.decode(response.bodyBytes));
      return data
          .map((e) => FoodLogEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw Exception(
      'Nie udało się pobrać dziennika żywieniowego (${response.statusCode})',
    );
  }

  Future<DailySummary> getDailySummary(DateTime date, String token) async {
    // Backend: GET /food-log/summary?entry_date=YYYY-MM-DD
    final response = await _client
        .get(
          Uri.parse(
            '$baseUrl/food-log/summary?entry_date=${_formatDate(date)}',
          ),
          headers: _headers(token),
        )
        .timeout(
          _timeout,
          onTimeout:
              () =>
                  throw Exception(
                    'Serwer nie odpowiedział na czas. Spróbuj ponownie za chwilę.',
                  ),
        );

    if (response.statusCode == 200) {
      return DailySummary.fromJson(
        json.decode(utf8.decode(response.bodyBytes)),
      );
    }
    throw Exception(
      'Nie udało się pobrać podsumowania dnia (${response.statusCode})',
    );
  }

  /// Dodaje wpis ręczny (z własną nazwą) albo z przepisu (recipe_id +
  /// liczba porcji — makra przeliczy wtedy backend automatycznie, o ile nie
  /// podano ich wprost).
  Future<FoodLogEntry> addFoodLog(
    Map<String, dynamic> entryData,
    String token,
  ) async {
    // Backend: POST /food-log/
    final response = await _client
        .post(
          Uri.parse('$baseUrl/food-log/'),
          headers: _headers(token),
          body: json.encode(entryData),
        )
        .timeout(
          _timeout,
          onTimeout:
              () =>
                  throw Exception(
                    'Serwer nie odpowiedział na czas. Spróbuj ponownie za chwilę.',
                  ),
        );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return FoodLogEntry.fromJson(
        json.decode(utf8.decode(response.bodyBytes)),
      );
    }
    throw Exception(
      _extractError(response) ?? 'Nie udało się dodać wpisu do dziennika',
    );
  }

  /// Loguje posiłek bezpośrednio z pozycji planu posiłków (przycisk
  /// "Zjedzone" przy pozycji planu na dany dzień).
  ///
  /// [forDate] — dzień, pod którym ma się zapisać wpis (np. aktualnie
  /// przeglądany dzień w ekranie śledzenia). Jeśli pominięty, backend
  /// wyliczy datę z harmonogramu planu — ale jawne podanie jest
  /// bezpieczniejsze, żeby wpis zawsze trafiał tam, gdzie użytkownik
  /// faktycznie patrzy.
  Future<FoodLogEntry> addFromMealPlanEntry(
    String mealPlanEntryId,
    String token, {
    DateTime? forDate,
    double? servings,
  }) async {
    final params = <String>[];
    if (forDate != null) {
      params.add(
        'date=${forDate.year.toString().padLeft(4, '0')}-'
        '${forDate.month.toString().padLeft(2, '0')}-'
        '${forDate.day.toString().padLeft(2, '0')}',
      );
    }
    if (servings != null) {
      params.add('servings=$servings');
    }
    final query = params.isEmpty ? '' : '?${params.join('&')}';
    final response = await _client
        .post(
          Uri.parse('$baseUrl/food-log/from-plan-entry/$mealPlanEntryId$query'),
          headers: _headers(token),
        )
        .timeout(
          _timeout,
          onTimeout:
              () =>
                  throw Exception(
                    'Serwer nie odpowiedział na czas. Spróbuj ponownie za chwilę.',
                  ),
        );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return FoodLogEntry.fromJson(
        json.decode(utf8.decode(response.bodyBytes)),
      );
    }
    throw Exception(
      _extractError(response) ?? 'Nie udało się dodać posiłku z planu',
    );
  }

  /// Nadpisuje wartości odżywcze istniejącego wpisu — używane po edycji
  /// składników. Zmienia TYLKO ten jeden wpis użytkownika; przepis
  /// pozostaje nietknięty.
  Future<void> updateFoodLogNutrition(
    String logId,
    String token, {
    required double calories,
    required double protein,
    required double fat,
    required double carbs,
  }) async {
    final response = await _client
        .patch(
          Uri.parse('$baseUrl/food-log/$logId'),
          headers: _headers(token),
          body: jsonEncode({
            'calories': calories,
            'protein': protein,
            'fat': fat,
            'carbs': carbs,
          }),
        )
        .timeout(
          _timeout,
          onTimeout:
              () =>
                  throw Exception(
                    'Serwer nie odpowiedział na czas. Spróbuj ponownie za chwilę.',
                  ),
        );

    if (response.statusCode != 200) {
      throw Exception(
        _extractError(response) ?? 'Nie udało się zaktualizować wpisu',
      );
    }
  }

  Future<void> deleteFoodLog(String logId, String token) async {
    // Backend: DELETE /food-log/{entry_id}
    final response = await _client
        .delete(Uri.parse('$baseUrl/food-log/$logId'), headers: _headers(token))
        .timeout(
          _timeout,
          onTimeout:
              () =>
                  throw Exception(
                    'Serwer nie odpowiedział na czas. Spróbuj ponownie za chwilę.',
                  ),
        );

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception(
        _extractError(response) ?? 'Nie udało się usunąć wpisu z dziennika',
      );
    }
  }

  String? _extractError(http.Response response) {
    try {
      final body = json.decode(utf8.decode(response.bodyBytes));
      if (body is Map && body['detail'] != null)
        return body['detail'].toString();
    } catch (_) {}
    return null;
  }
}
