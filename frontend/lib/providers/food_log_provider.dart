import 'package:flutter/foundation.dart';
import '../models/food_log.dart';
import '../services/api_client.dart';
import '../services/food_log_service.dart';

class FoodLogProvider with ChangeNotifier {
  final FoodLogService _service = FoodLogService();
  final ApiClient _apiClient = ApiClient();
  String? _token;

  List<FoodLogEntry> _logs = [];
  DailySummary? _summary;
  DateTime _currentDate = DateTime.now();
  bool _isLoading = false;
  String? _error;

  List<FoodLogEntry> get logs => _logs;
  DailySummary? get summary => _summary;
  DateTime get currentDate => _currentDate;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void updateAuth(String? token) {
    _token = token;
    if (_token != null) {
      fetchLogsForDate(_currentDate);
    }
  }

  /// Pobiera token sesji — najpierw ten ustawiony ręcznie przez [updateAuth],
  /// a w razie jego braku bezpośrednio z [ApiClient].
  Future<String?> _resolveToken() async {
    final token = _token ?? await _apiClient.getToken();
    return token;
  }

  void setDate(DateTime date) {
    _currentDate = date;
    fetchLogsForDate(date);
  }

  Future<void> fetchLogsForDate(DateTime date) async {
    final token = await _resolveToken();
    if (token == null) {
      _error = 'Musisz być zalogowany, aby zobaczyć dziennik.';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    // UWAGA: wcześniej błąd (jakikolwiek — także 401 czy chwilowy problem
    // sieci) był po cichu zamieniany na ZMYŚLONE dane testowe, więc
    // użytkownik widział fałszywy dziennik i nie wiedział, że coś nie
    // działa. Teraz błąd jest pokazywany wprost, a dziennik zostaje pusty.
    try {
      _logs = await _service.getLogsForDate(date, token);
      _summary = await _service.getDailySummary(date, token);
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      _logs = [];
      _summary = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Dodaje wpis ręczny. Zwraca `true` po sukcesie — w razie błędu ustawia
  /// [error] i zwraca `false`, zamiast (jak wcześniej) po cichu dodawać
  /// zmyślony wpis, który i tak zniknąłby po ponownym otwarciu aplikacji.
  Future<bool> addManualEntry({
    required String mealType,
    required String foodName,
    required double calories,
    required double protein,
    required double carbs,
    required double fat,
  }) async {
    final token = await _resolveToken();
    if (token == null) {
      _error = 'Musisz być zalogowany, aby dodać wpis.';
      notifyListeners();
      return false;
    }

    try {
      final entry = FoodLogEntry(
        id: '',
        userId: '',
        date: _currentDate,
        mealType: mealType,
        customName: foodName,
        servings: 1.0,
        calories: calories,
        protein: protein,
        carbs: carbs,
        fat: fat,
      );
      await _service.addFoodLog(entry.toCreateJson(), token);
      await fetchLogsForDate(_currentDate);
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  /// Dodaje wpis na podstawie przepisu z bazy — makra przelicza backend
  /// automatycznie na podstawie wartości odżywczych przepisu i liczby porcji.
  Future<bool> addRecipeEntry({
    required String recipeId,
    required String mealType,
    required double servings,
  }) async {
    final token = await _resolveToken();
    if (token == null) {
      _error = 'Musisz być zalogowany, aby dodać wpis.';
      notifyListeners();
      return false;
    }

    try {
      await _service.addFoodLog({
        'date': '${_currentDate.year.toString().padLeft(4, '0')}-'
            '${_currentDate.month.toString().padLeft(2, '0')}-'
            '${_currentDate.day.toString().padLeft(2, '0')}',
        'meal_type': mealType,
        'recipe_id': recipeId,
        'servings': servings,
      }, token);
      await fetchLogsForDate(_currentDate);
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  /// Loguje posiłek bezpośrednio z pozycji planu posiłków przypisanej do
  /// aktualnie przeglądanego dnia (`_currentDate`) — nie zawsze "dziś".
  Future<bool> addFromMealPlanEntry(String mealPlanEntryId) async {
    final token = await _resolveToken();
    if (token == null) {
      _error = 'Musisz być zalogowany, aby dodać wpis.';
      notifyListeners();
      return false;
    }

    try {
      await _service.addFromMealPlanEntry(mealPlanEntryId, token, forDate: _currentDate);
      await fetchLogsForDate(_currentDate);
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<void> deleteEntry(String logId) async {
    final token = await _resolveToken();
    if (token == null) return;

    try {
      await _service.deleteFoodLog(logId, token);
      await fetchLogsForDate(_currentDate);
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
