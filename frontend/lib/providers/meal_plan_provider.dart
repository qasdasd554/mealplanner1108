import 'package:flutter/material.dart';
import '../models/meal_plan.dart';
import '../services/meal_plan_service.dart';
import '../services/app_review_service.dart';
import '../services/api_client.dart';
import '../utils/error_utils.dart';

class MealPlanProvider with ChangeNotifier {
  final MealPlanService _mealPlanService;
  final ErrorStringsResolver? errorStrings;

  MealPlanProvider({MealPlanService? service, this.errorStrings})
    : _mealPlanService = service ?? MealPlanService();

  MealPlan? _currentPlan;
  List<MealPlan> _plans = [];
  bool _isLoading = false;
  bool _hasLoaded = false;
  bool _isGenerating = false;
  bool _isRefreshing = false;
  String? _errorMessage;
  Object? _generationFailure;
  Object? get generationFailure => _generationFailure;
  bool _lastPlanLoadNotFound = false;
  int _sessionGeneration = 0;
  int _detailGeneration = 0;

  MealPlan? get currentPlan => _currentPlan;
  List<MealPlan> get plans => _plans;
  bool get isLoading => _isLoading;
  bool get hasLoaded => _hasLoaded;
  bool get isGenerating => _isGenerating;
  String? get errorMessage => _errorMessage;
  bool get lastPlanLoadNotFound => _lastPlanLoadNotFound;

  // Lista jest sortowana od najnowszego, więc nowszy draft nie może być
  // przesłonięty przez starszy plan ze statusem active.
  MealPlan? get activePlan {
    try {
      return _plans.firstWhere((plan) => plan.isInUseAt(DateTime.now()));
    } catch (_) {
      return null;
    }
  }

  /// Wszystkie aktywne plany. Konto standardowe może utworzyć jeden nowy
  /// plan tygodniowo, więc z różnych tygodni może mieć ich kilka.
  /// UI pokazuje przełącznik, gdy dostępny jest więcej niż jeden.
  ///
  /// UWAGA: nowo wygenerowany plan ma status "draft" (nie "active") —
  /// backend nigdy go automatycznie nie "aktywuje". Traktujemy więc
  /// "draft" i "active" jako "obecnie w użyciu".
  List<MealPlan> get activePlans =>
      _plans.where((p) => p.isInUseAt(DateTime.now())).toList();

  /// Ustawia, który plan jest aktualnie przeglądany — używane przez
  /// przełącznik planów, gdy użytkownik ma ich kilka aktywnych naraz.
  void selectPlan(MealPlan plan) {
    _detailGeneration++;
    _currentPlan = plan;
    notifyListeners();
  }

  Future<void> loadPlans() async {
    if (_isRefreshing) return;
    final session = _sessionGeneration;
    _isRefreshing = true;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final plans = await _mealPlanService.getPlans();
      if (session != _sessionGeneration) return;
      _plans =
          plans
              .where((p) => !p.isArchived && !p.isExpiredAt(DateTime.now()))
              .toList();
      // Posortuj od najnowszych
      _plans.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (_plans.isNotEmpty) {
        final selectedId = _currentPlan?.id;
        final stillAvailable = _plans.where((plan) => plan.id == selectedId);
        _currentPlan =
            stillAvailable.isNotEmpty ? stillAvailable.first : activePlan;
      } else {
        _currentPlan = null;
      }
    } catch (e) {
      if (session != _sessionGeneration) return;
      _errorMessage = friendlyError(e, strings: errorStrings?.call());
    } finally {
      if (session == _sessionGeneration) {
        _isRefreshing = false;
        _isLoading = false;
        _hasLoaded = true;
        notifyListeners();
      }
    }
  }

  Future<void> loadPlan(String planId) async {
    final session = _sessionGeneration;
    final detail = ++_detailGeneration;
    _isLoading = true;
    _errorMessage = null;
    _lastPlanLoadNotFound = false;
    _currentPlan = null;
    notifyListeners();
    try {
      final plan = await _mealPlanService.getPlan(planId);
      if (session != _sessionGeneration || detail != _detailGeneration) return;
      _currentPlan = plan;
    } catch (e) {
      if (session != _sessionGeneration || detail != _detailGeneration) return;
      _currentPlan = null;
      _lastPlanLoadNotFound = e is ApiException && e.statusCode == 404;
      _errorMessage = friendlyError(e, strings: errorStrings?.call());
    } finally {
      if (session == _sessionGeneration && detail == _detailGeneration) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<bool> generatePlan(MealPlanGenerateRequest request) async {
    if (_isGenerating) return false;
    final session = _sessionGeneration;
    _isGenerating = true;
    _errorMessage = null;
    _generationFailure = null;
    notifyListeners();
    try {
      final newPlan = await _mealPlanService.generatePlan(request);
      if (session != _sessionGeneration) return false;
      _currentPlan = newPlan;
      _plans.insert(0, newPlan);
      AppReviewSignal.recordSuccess();
      _isGenerating = false;
      notifyListeners();
      return true;
    } catch (e) {
      if (session != _sessionGeneration) return false;
      _generationFailure = e;
      _errorMessage = friendlyError(e, strings: errorStrings?.call());
      _isGenerating = false;
      notifyListeners();
      return false;
    }
  }

  Future<MealPlan?> resumePlan(
    String planId,
    DateTime startDate, {
    String Function(Object error)? errorMessageFor,
  }) async {
    if (_isLoading) return null;
    final session = _sessionGeneration;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final plan = await _mealPlanService.resumePlan(planId, startDate);
      if (session != _sessionGeneration) return null;
      _plans.insert(0, plan);
      _currentPlan = plan;
      return plan;
    } catch (e) {
      if (session != _sessionGeneration) return null;
      _errorMessage =
          errorMessageFor?.call(e) ??
          friendlyError(e, strings: errorStrings?.call());
      return null;
    } finally {
      if (session == _sessionGeneration) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<bool> activatePlan(String planId) async {
    if (_isLoading) return false;
    final session = _sessionGeneration;
    _isLoading = true;
    notifyListeners();
    try {
      await _mealPlanService.updatePlanStatus(planId, 'active');
      if (session != _sessionGeneration) return false;
      await loadPlans(); // przeładuj, aby statusy się zaktualizowały
      return true;
    } catch (e) {
      if (session != _sessionGeneration) return false;
      _errorMessage = friendlyError(e, strings: errorStrings?.call());
      return false;
    } finally {
      if (session == _sessionGeneration) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<bool> swapRecipe({
    required String planId,
    required String entryId,
    required String newRecipeId,
  }) async {
    if (_isLoading) return false;
    final session = _sessionGeneration;
    _isLoading = true;
    notifyListeners();
    try {
      final updatedPlan = await _mealPlanService.swapRecipe(
        planId,
        entryId,
        newRecipeId,
      );
      if (session != _sessionGeneration) return false;
      _currentPlan = updatedPlan;
      // Zaktualizuj na liście planów
      final index = _plans.indexWhere((p) => p.id == planId);
      if (index != -1) {
        _plans[index] = updatedPlan;
      }
      return true;
    } catch (e) {
      if (session != _sessionGeneration) return false;
      _errorMessage = friendlyError(e, strings: errorStrings?.call());
      return false;
    } finally {
      if (session == _sessionGeneration) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Zmienia sklep przypisany do planu — lista zakupów przelicza się
  /// automatycznie po stronie backendu pod nowe ceny/działy.
  Future<bool> updateStore(String planId, String storeId) async {
    if (_isLoading) return false;
    final session = _sessionGeneration;
    _isLoading = true;
    notifyListeners();
    try {
      final updatedPlan = await _mealPlanService.updateStore(planId, storeId);
      if (session != _sessionGeneration) return false;
      _currentPlan = updatedPlan;
      final index = _plans.indexWhere((p) => p.id == planId);
      if (index != -1) {
        _plans[index] = updatedPlan;
      }
      return true;
    } catch (e) {
      if (session != _sessionGeneration) return false;
      _errorMessage = friendlyError(e, strings: errorStrings?.call());
      return false;
    } finally {
      if (session == _sessionGeneration) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<bool> deletePlan(String planId) async {
    if (_isLoading) return false;
    final session = _sessionGeneration;
    _isLoading = true;
    notifyListeners();
    try {
      await _mealPlanService.deletePlan(planId);
      if (session != _sessionGeneration) return false;
      _plans.removeWhere((p) => p.id == planId);
      if (_currentPlan?.id == planId) {
        _currentPlan = _plans.isNotEmpty ? _plans.first : null;
      }
      return true;
    } catch (e) {
      if (session != _sessionGeneration) return false;
      _errorMessage = friendlyError(e, strings: errorStrings?.call());
      return false;
    } finally {
      if (session == _sessionGeneration) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Czyści cały stan — wywoływane przy wylogowaniu. Bez tego, po
  /// zalogowaniu się jako inny użytkownik, ekrany korzystające z tego
  /// providera (np. zakładka "Plan" w Śledzeniu kalorii, która ładuje
  /// dane TYLKO gdy lista jest pusta) pokazywałyby plany POPRZEDNIEGO
  /// użytkownika, dopóki coś jawnie nie wymusiłoby ponownego pobrania.
  void clear() {
    _sessionGeneration++;
    _detailGeneration++;
    _isRefreshing = false;
    _currentPlan = null;
    _plans = [];
    _isLoading = false;
    _hasLoaded = false;
    _isGenerating = false;
    _errorMessage = null;
    _generationFailure = null;
    _lastPlanLoadNotFound = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _sessionGeneration++;
    _detailGeneration++;
    super.dispose();
  }
}
