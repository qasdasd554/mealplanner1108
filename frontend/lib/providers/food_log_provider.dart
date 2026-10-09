import 'package:flutter/foundation.dart';

import '../models/food_log.dart';
import '../services/api_client.dart';
import '../services/food_log_service.dart';
import '../utils/error_utils.dart';

class FoodLogProvider with ChangeNotifier {
  final FoodLogService _service = FoodLogService();
  final ApiClient _apiClient = ApiClient();
  String? _token;

  List<FoodLogEntry> _logs = [];
  List<FoodLogEntry> _recentEntries = [];
  DailySummary? _summary;
  DateTime _currentDate = DateTime.now();
  bool _isLoading = false;
  String? _error;

  List<FoodLogEntry> get logs => _logs;
  List<FoodLogEntry> get recentEntries => _recentEntries;
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
      final results = await Future.wait<Object>([
        _service.getLogsForDate(date, token),
        _service.getDailySummary(date, token),
      ]);
      _logs = results[0] as List<FoodLogEntry>;
      _summary = results[1] as DailySummary;
    } catch (e) {
      _error = friendlyError(e);
      _logs = [];
      _summary = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchRecentEntries() async {
    final token = await _resolveToken();
    if (token == null) return;
    try {
      _recentEntries = await _service.getRecentEntries(token);
      notifyListeners();
    } catch (_) {
      // Szybkie podpowiedzi są dodatkiem. Ich błąd nie może zasłonić
      // podstawowego formularza ani nadpisać komunikatu Dziennika.
    }
  }

  Future<bool> repeatEntry(FoodLogEntry source) async {
    if (source.recipeId != null) {
      return addRecipeEntry(
        recipeId: source.recipeId!,
        mealType: source.mealType,
        servings: source.servings,
      );
    }
    return addManualEntry(
      mealType: source.mealType,
      foodName: source.displayName,
      calories: source.calories,
      protein: source.protein,
      carbs: source.carbs,
      fat: source.fat,
      amountValue: source.amountValue,
      amountUnit: source.amountUnit,
      portionSize: source.portionSize,
      portionUnit: source.portionUnit,
    );
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
    double? amountValue,
    String? amountUnit,
    double? portionSize,
    String? portionUnit,
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
        amountValue: amountValue,
        amountUnit: amountUnit,
        portionSize: portionSize,
        portionUnit: portionUnit,
      );
      await _service.addFoodLog(entry.toCreateJson(), token);
      await fetchLogsForDate(_currentDate);
      return true;
    } catch (e) {
      _error = friendlyError(e);
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
        'date':
            '${_currentDate.year.toString().padLeft(4, '0')}-'
            '${_currentDate.month.toString().padLeft(2, '0')}-'
            '${_currentDate.day.toString().padLeft(2, '0')}',
        'meal_type': mealType,
        'recipe_id': recipeId,
        'servings': servings,
      }, token);
      await fetchLogsForDate(_currentDate);
      return true;
    } catch (e) {
      _error = friendlyError(e);
      notifyListeners();
      return false;
    }
  }

  /// Loguje posiłek bezpośrednio z pozycji planu posiłków przypisanej do
  /// aktualnie przeglądanego dnia (`_currentDate`) — nie zawsze "dziś".
  Future<bool> addFromMealPlanEntry(
    String mealPlanEntryId, {
    double? servings,
  }) async {
    final token = await _resolveToken();
    if (token == null) {
      _error = 'Musisz być zalogowany, aby dodać wpis.';
      notifyListeners();
      return false;
    }

    try {
      await _service.addFromMealPlanEntry(
        mealPlanEntryId,
        token,
        forDate: _currentDate,
        servings: servings,
      );
      await fetchLogsForDate(_currentDate);
      return true;
    } catch (e) {
      _error = friendlyError(e);
      notifyListeners();
      return false;
    }
  }

  /// Zapisuje skorygowane wartości odżywcze wpisu po edycji składników.
  Future<bool> updateEntryNutrition(
    String logId, {
    required double calories,
    required double protein,
    required double fat,
    required double carbs,
    double? servings,
    double? amountValue,
    String? amountUnit,
    double? portionSize,
    String? portionUnit,
  }) async {
    final token = await _resolveToken();
    if (token == null) return false;

    try {
      await _service.updateFoodLogNutrition(
        logId,
        token,
        calories: calories,
        protein: protein,
        fat: fat,
        carbs: carbs,
        servings: servings,
        amountValue: amountValue,
        amountUnit: amountUnit,
        portionSize: portionSize,
        portionUnit: portionUnit,
      );
      // Przeładowanie dnia, żeby odświeżyło się też podsumowanie kalorii
      // i makroskładników u góry ekranu — sama lista by nie wystarczyła.
      await fetchLogsForDate(_currentDate);
      return true;
    } catch (e) {
      _error = friendlyError(e);
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
      _error = friendlyError(e);
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Czyści cały stan — wywoływane przy wylogowaniu, żeby dane
  /// poprzedniego użytkownika (wpisy dziennika, podsumowanie kalorii)
  /// nie były widoczne po zalogowaniu się jako ktoś inny.
  void clear() {
    _logs = [];
    _recentEntries = [];
    _summary = null;
    _currentDate = DateTime.now();
    _isLoading = false;
    _error = null;
    notifyListeners();
  }
}
