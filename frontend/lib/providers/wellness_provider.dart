import 'package:flutter/material.dart';

import '../services/wellness_service.dart';
import '../utils/error_utils.dart';

/// Stan nawodnienia i aktywności dla oglądanego dnia.
///
/// Trzymany osobno od FoodLogProvider, mimo że oba dotyczą tego samego
/// dnia: dziennik żywieniowy zajmuje się posiłkami, a to są dane
/// uzupełniające. Wciśnięcie ich w jeden provider oznaczałoby, że każde
/// dolanie wody odświeża całą listę posiłków.
class WellnessProvider with ChangeNotifier {
  final WellnessService _service = WellnessService();

  DailyWellness _data = DailyWellness.empty();
  DateTime _currentDate = DateTime.now();
  bool _isLoading = false;
  String? _errorMessage;

  DailyWellness get data => _data;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Kalorie spalone aktywnością — POWIĘKSZAJĄ dzienny limit, bo to,
  /// co użytkownik wypracował, może zjeść dodatkowo.
  int get kcalBurned => _data.totalKcalBurned;

  Future<void> loadForDate(DateTime date) async {
    _currentDate = date;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _data = await _service.getForDate(date);
    } catch (e) {
      _errorMessage = friendlyError(e);
      // Przy błędzie pokazujemy stan pusty zamiast poprzedniego dnia —
      // stare dane wyglądałyby jak prawdziwe i wprowadzały w błąd.
      _data = DailyWellness.empty();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addWater(int amountMl) async {
    // Aktualizacja optymistyczna: pasek nawodnienia reaguje od razu,
    // bez czekania na serwer. Przy błędzie i tak przeładujemy dzień,
    // więc rozjazd nie utrzyma się dłużej niż jedno żądanie.
    final previous = _data;
    _data = DailyWellness(
      waterMl: (_data.waterMl + amountMl).clamp(0, 100000),
      waterGoalMl: _data.waterGoalMl,
      activities: _data.activities,
      totalKcalBurned: _data.totalKcalBurned,
    );
    notifyListeners();

    try {
      await _service.addWater(_currentDate, amountMl);
    } catch (e) {
      _data = previous;
      _errorMessage = friendlyError(e);
      notifyListeners();
    }
  }

  Future<bool> addActivity({
    required String name,
    required int kcalBurned,
    int? durationMin,
  }) async {
    try {
      await _service.addActivity(
        _currentDate,
        name: name,
        kcalBurned: kcalBurned,
        durationMin: durationMin,
      );
      await loadForDate(_currentDate);
      return true;
    } catch (e) {
      _errorMessage = friendlyError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteActivity(String id) async {
    try {
      await _service.deleteActivity(id);
      await loadForDate(_currentDate);
      return true;
    } catch (e) {
      _errorMessage = friendlyError(e);
      notifyListeners();
      return false;
    }
  }
}
