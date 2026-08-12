import 'package:flutter/material.dart';
import '../models/meal_plan.dart';
import '../services/meal_plan_service.dart';

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
      _errorMessage = e.toString().replaceAll('ApiException:', '');
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
      _errorMessage = e.toString().replaceAll('ApiException:', '');
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
      _errorMessage = e.toString().replaceAll('ApiException:', '');
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
      _errorMessage = e.toString().replaceAll('ApiException:', '');
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
      _errorMessage = e.toString().replaceAll('ApiException:', '');
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
      _errorMessage = e.toString().replaceAll('ApiException:', '');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
