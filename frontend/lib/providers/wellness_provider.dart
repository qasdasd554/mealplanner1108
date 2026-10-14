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
  final WellnessService _service;

  WellnessProvider({WellnessService? service})
    : _service = service ?? WellnessService();

  DailyWellness _data = DailyWellness.empty();
  DateTime _currentDate = DateTime.now();
  bool _isLoading = false;
  bool _hasLoaded = false;
  String? _errorMessage;
  int _requestGeneration = 0;

  DailyWellness get data => _data;
  bool get isLoading => _isLoading;
  bool get hasLoaded => _hasLoaded;
  String? get errorMessage => _errorMessage;

  /// Kalorie spalone aktywnością — POWIĘKSZAJĄ dzienny limit, bo to,
  /// co użytkownik wypracował, może zjeść dodatkowo.
  int get kcalBurned => _data.totalKcalBurned;

  Future<void> loadForDate(DateTime date) async {
    final generation = ++_requestGeneration;
    _currentDate = date;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final data = await _service.getForDate(date);
      if (generation != _requestGeneration) return;
      _data = data;
    } catch (e) {
      if (generation != _requestGeneration) return;
      _errorMessage = friendlyError(e);
      // Przy błędzie pokazujemy stan pusty zamiast poprzedniego dnia —
      // stare dane wyglądałyby jak prawdziwe i wprowadzały w błąd.
      _data = DailyWellness.empty();
    } finally {
      if (generation == _requestGeneration) {
        _isLoading = false;
        _hasLoaded = true;
        notifyListeners();
      }
    }
  }

  /// Zdejmuje ostatni błąd (po pokazaniu go użytkownikowi), żeby ten sam
  /// komunikat nie wyskakiwał przy każdym kolejnym przerysowaniu ekranu.
  String? consumeError() {
    final e = _errorMessage;
    _errorMessage = null;
    return e;
  }

  Future<void> addWater(int amountMl) async {
    final generation = _requestGeneration;
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
    final appliedDelta = _data.waterMl - previous.waterMl;
    notifyListeners();

    try {
      await _service.addWater(_currentDate, amountMl);
    } catch (e) {
      if (generation != _requestGeneration) return;
      // Cofamy tylko tę operację; inny szybki klik mógł już się zapisać.
      _data = DailyWellness(
        waterMl: (_data.waterMl - appliedDelta).clamp(0, 100000),
        waterGoalMl: _data.waterGoalMl,
        activities: _data.activities,
        totalKcalBurned: _data.totalKcalBurned,
      );
      _errorMessage = friendlyError(e);
      notifyListeners();
    }
  }

  Future<bool> addActivity({
    required String name,
    required int kcalBurned,
    int? durationMin,
  }) async {
    final generation = _requestGeneration;
    try {
      await _service.addActivity(
        _currentDate,
        name: name,
        kcalBurned: kcalBurned,
        durationMin: durationMin,
      );
      if (generation != _requestGeneration) return false;
      await loadForDate(_currentDate);
      return true;
    } catch (e) {
      if (generation != _requestGeneration) return false;
      _errorMessage = friendlyError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteActivity(String id) async {
    final generation = _requestGeneration;
    try {
      await _service.deleteActivity(id);
      if (generation != _requestGeneration) return false;
      await loadForDate(_currentDate);
      return true;
    } catch (e) {
      if (generation != _requestGeneration) return false;
      _errorMessage = friendlyError(e);
      notifyListeners();
      return false;
    }
  }

  void clear() {
    _requestGeneration++;
    _data = DailyWellness.empty();
    _currentDate = DateTime.now();
    _isLoading = false;
    _hasLoaded = false;
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _requestGeneration++;
    super.dispose();
  }
}
