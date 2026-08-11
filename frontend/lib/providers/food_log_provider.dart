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
  /// a w razie jego braku bezpośrednio z [ApiClient]. Wcześniej `updateAuth`
  /// nie było wywoływane nigdzie w aplikacji, więc `_token` zawsze pozostawał
  /// pusty i dziennik kalorii pokazywał wyłącznie dane testowe (mock).
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
    if (token == null) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _logs = await _service.getLogsForDate(date, token);
      _summary = await _service.getDailySummary(date, token);
    } catch (e) {
      // Mock data for UI development if backend is not ready
      _generateMockData(date);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addFoodEntry({
    required String mealType,
    required String foodName,
    required double portionSize,
    required double calories,
    required double protein,
    required double carbs,
    required double fat,
  }) async {
    final token = await _resolveToken();
    if (token == null) return;

    try {
      final newEntry = await _service.addFoodLog(
        {
          'date': _currentDate.toIso8601String(),
          'meal_type': mealType,
          'food_name': foodName,
          'portion_size': portionSize,
          'calories': calories,
          'protein': protein,
          'carbs': carbs,
          'fat': fat,
        },
        token,
      );
      
      _logs.add(newEntry);
      
      // Update summary locally to avoid extra API call, or re-fetch
      await fetchLogsForDate(_currentDate);
    } catch (e) {
      // Mock flow
      final entry = FoodLogEntry(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: '123',
        date: _currentDate,
        mealType: mealType,
        foodName: foodName,
        portionSize: portionSize,
        calories: calories,
        protein: protein,
        carbs: carbs,
        fat: fat,
      );
      _logs.add(entry);
      _updateMockSummary();
      notifyListeners();
    }
  }
  
  Future<void> deleteEntry(String logId) async {
    final token = await _resolveToken();
    if (token == null) return;

    try {
      await _service.deleteFoodLog(logId, token);
      await fetchLogsForDate(_currentDate);
    } catch (e) {
      // Mock flow
      _logs.removeWhere((l) => l.id == logId);
      _updateMockSummary();
      notifyListeners();
    }
  }

  void _generateMockData(DateTime date) {
    _logs = [
      FoodLogEntry(id: '1', userId: '123', date: date, mealType: 'Śniadanie', foodName: 'Owsianka z owocami', portionSize: 300, calories: 350, protein: 12, carbs: 55, fat: 8),
      FoodLogEntry(id: '2', userId: '123', date: date, mealType: 'Obiad', foodName: 'Kurczak z ryżem i warzywami', portionSize: 450, calories: 600, protein: 45, carbs: 70, fat: 15),
    ];
    _updateMockSummary();
  }

  void _updateMockSummary() {
    double totalCal = 0, totalP = 0, totalC = 0, totalF = 0;
    for (var log in _logs) {
      totalCal += log.calories;
      totalP += log.protein;
      totalC += log.carbs;
      totalF += log.fat;
    }
    _summary = DailySummary(
      date: _currentDate,
      totalCalories: totalCal,
      totalProtein: totalP,
      totalCarbs: totalC,
      totalFat: totalF,
      targetCalories: 2200,
    );
  }
}
