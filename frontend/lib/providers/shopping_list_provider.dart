import 'package:flutter/material.dart';
import '../models/shopping_list.dart';
import '../services/shopping_list_service.dart';

class ShoppingListProvider with ChangeNotifier {
  final ShoppingListService _shoppingListService = ShoppingListService();

  ShoppingList? _currentList;
  bool _isLoading = false;
  String? _errorMessage;

  ShoppingList? get currentList => _currentList;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> loadShoppingList(String listId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _currentList = await _shoppingListService.getShoppingList(listId);
    } catch (e) {
      _errorMessage = e.toString().replaceAll('ApiException: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> toggleItem(String itemId) async {
    if (_currentList == null) return;

    // Znajdź przedmiot w strukturze słownika
    ShoppingListItem? targetItem;
    String? targetDept;

    for (final entry in _currentList!.itemsByDepartment.entries) {
      final index = entry.value.indexWhere((item) => item.id == itemId);
      if (index != -1) {
        targetItem = entry.value[index];
        targetDept = entry.key;
        break;
      }
    }

    if (targetItem == null || targetDept == null) return;

    // Zmień stan lokalnie (Optymistyczna aktualizacja)
    targetItem.isChecked = !targetItem.isChecked;
    notifyListeners();

    try {
      // Wyślij na serwer
      await _shoppingListService.toggleItemCheck(_currentList!.id, itemId);
    } catch (e) {
      // Cofnij zmianę w razie błędu
      targetItem.isChecked = !targetItem.isChecked;
      _errorMessage = e.toString().replaceAll('ApiException: ', '');
      notifyListeners();
    }
  }

  Future<bool> substituteItem(String itemId, String substituteProductId) async {
    if (_currentList == null) return false;
    _isLoading = true;
    notifyListeners();
    try {
      await _shoppingListService.substituteItem(
        _currentList!.id,
        itemId,
        substituteProductId,
      );
      // Przeładuj listę, aby odzwierciedlić zamianę
      await loadShoppingList(_currentList!.id);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('ApiException: ', '');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
