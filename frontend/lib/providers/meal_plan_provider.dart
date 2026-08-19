import 'package:flutter/material.dart';
import '../models/meal_plan.dart';
import '../services/meal_plan_service.dart';
import '../utils/error_utils.dart';

class MealPlanProvider with ChangeNotifier {
  final MealPlanService _mealPlanService = MealPlanService();

  MealPlan? _currentPlan;
  List<MealPlan> _plans = [];
  bool _isLoading = false;
  bool _isGenerating = false;
  String? _errorMessage;

  MealPlan? get currentPlan => _currentPlan;
  List<MealPlan> get plans => _plans;
  bool get isLoading => _isLoading;
  bool get isGenerating => _isGenerating;
  String? get errorMessage => _errorMessage;

  // Pobierz plan oznaczony jako aktywny (lub najnowszy draft jeśli brak aktywnego)
  MealPlan? get activePlan {
    try {
      return _plans.firstWhere((plan) => plan.status == 'active');
    } catch (_) {
      try {
        return _plans.firstWhere((plan) => plan.status == 'draft');
      } catch (_) {
        return _plans.isNotEmpty ? _plans.first : null;
      }
    }
  }

  /// WSZYSTKIE aktywne plany — dla darmowych kont to zawsze co najwyżej
  /// jeden (backend automatycznie archiwizuje poprzedni przy generowaniu
  /// nowego), ale konta premium mogą mieć ich kilka naraz (np. osobny na
  /// dni robocze i osobny na weekend). UI powinno pokazać przełącznik
  /// tylko wtedy, gdy ta lista ma więcej niż jeden element.
  ///
  /// UWAGA: nowo wygenerowany plan ma status "draft" (nie "active") —
  /// backend nigdy go automatycznie nie "aktywuje". Traktujemy więc
  /// "draft" i "active" jako "obecnie w użyciu", spójnie z logiką
  /// archiwizacji po stronie backendu (patrz meal_plans.py:generate_meal_plan)
  /// i z istniejącym zachowaniem [activePlan] powyżej.
  List<MealPlan> get activePlans =>
      _plans.where((p) => p.status == 'active' || p.status == 'draft').toList();

  /// Ustawia, który plan jest aktualnie przeglądany — używane przez
  /// przełącznik planów, gdy użytkownik (premium) ma ich kilka aktywnych
  /// naraz.
  void selectPlan(MealPlan plan) {
    _currentPlan = plan;
    notifyListeners();
  }

  Future<void> loadPlans() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _plans = await _mealPlanService.getPlans();
      // Posortuj od najnowszych
      _plans.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (_plans.isNotEmpty) {
        _currentPlan = activePlan;
      }
    } catch (e) {
      _errorMessage = friendlyError(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadPlan(String planId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _currentPlan = await _mealPlanService.getPlan(planId);
    } catch (e) {
      _errorMessage = friendlyError(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> generatePlan(MealPlanGenerateRequest request) async {
    _isGenerating = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final newPlan = await _mealPlanService.generatePlan(request);
      _currentPlan = newPlan;
      _plans.insert(0, newPlan);
      _isGenerating = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = friendlyError(e);
      _isGenerating = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> activatePlan(String planId) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _mealPlanService.updatePlanStatus(planId, 'active');
      await loadPlans(); // przeładuj, aby statusy się zaktualizowały
      return true;
    } catch (e) {
      _errorMessage = friendlyError(e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> swapRecipe({
    required String planId,
    required String entryId,
    required String newRecipeId,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      final updatedPlan = await _mealPlanService.swapRecipe(planId, entryId, newRecipeId);
      _currentPlan = updatedPlan;
      // Zaktualizuj na liście planów
      final index = _plans.indexWhere((p) => p.id == planId);
      if (index != -1) {
        _plans[index] = updatedPlan;
      }
      return true;
    } catch (e) {
      _errorMessage = friendlyError(e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Zmienia sklep przypisany do planu — lista zakupów przelicza się
  /// automatycznie po stronie backendu pod nowe ceny/działy.
  Future<bool> updateStore(String planId, String storeId) async {
    _isLoading = true;
    notifyListeners();
    try {
      final updatedPlan = await _mealPlanService.updateStore(planId, storeId);
      _currentPlan = updatedPlan;
      final index = _plans.indexWhere((p) => p.id == planId);
      if (index != -1) {
        _plans[index] = updatedPlan;
      }
      return true;
    } catch (e) {
      _errorMessage = friendlyError(e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deletePlan(String planId) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _mealPlanService.deletePlan(planId);
      _plans.removeWhere((p) => p.id == planId);
      if (_currentPlan?.id == planId) {
        _currentPlan = _plans.isNotEmpty ? _plans.first : null;
      }
      return true;
    } catch (e) {
      _errorMessage = friendlyError(e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Czyści cały stan — wywoływane przy wylogowaniu. Bez tego, po
  /// zalogowaniu się jako inny użytkownik, ekrany korzystające z tego
  /// providera (np. zakładka "Plan" w Śledzeniu kalorii, która ładuje
  /// dane TYLKO gdy lista jest pusta) pokazywałyby plany POPRZEDNIEGO
  /// użytkownika, dopóki coś jawnie nie wymusiłoby ponownego pobrania.
  void clear() {
    _currentPlan = null;
    _plans = [];
    _isLoading = false;
    _isGenerating = false;
    _errorMessage = null;
    notifyListeners();
  }
}
