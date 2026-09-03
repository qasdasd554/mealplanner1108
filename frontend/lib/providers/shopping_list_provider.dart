import 'package:flutter/material.dart';
import '../models/shopping_list.dart';
import '../services/shopping_list_service.dart';
import '../utils/error_utils.dart';

class ShoppingListProvider with ChangeNotifier {
  final ShoppingListService _shoppingListService = ShoppingListService();

  ShoppingList? _currentList;
  bool _isLoading = false;
  String? _errorMessage;

  // NAPRAWA: użytkownik Premium może mieć do 5 list, ale ekran zakupów
  // ładował WYŁĄCZNIE listę powiązaną z aktywnym planem posiłków
  // (mealPlanProvider.activePlan), więc pozostałych nie dało się w ogóle
  // otworzyć — istniały w bazie i zwracał je GET /shopping-lists/mine,
  // tylko nic ich nie pokazywało. Trzymamy tu wszystkie i pozwalamy
  // przełączać.
  List<ShoppingList> _allLists = [];
  String? _selectedListId;

  ShoppingList? get currentList => _currentList;
  List<ShoppingList> get allLists => _allLists;
  String? get selectedListId => _selectedListId;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Pobiera wszystkie listy użytkownika i ustawia aktywną.
  ///
  /// `preferredListId` (zwykle ID aktywnego planu posiłków) jest
  /// wybierane, jeśli faktycznie istnieje wśród list — inaczej bierzemy
  /// pierwszą dostępną, żeby ekran nigdy nie był pusty tylko dlatego, że
  /// aktywny plan akurat nie ma listy.
  Future<void> loadAllLists({String? preferredListId}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _allLists = await _shoppingListService.getMyLists();

      String? target = preferredListId;
      // Porównujemy po mealPlanId, bo tym identyfikatorem backend
      // indeksuje listy zakupów (patrz _get_shopping_list_or_404).
      final hasPreferred = _allLists.any((l) => l.mealPlanId == preferredListId);
      if (!hasPreferred) {
        target = _allLists.isNotEmpty ? _allLists.first.mealPlanId : null;
      }

      if (target != null) {
        _selectedListId = target;
        _currentList = await _shoppingListService.getShoppingList(target);
      } else {
        _selectedListId = null;
        _currentList = null;
      }
    } catch (e) {
      _errorMessage = friendlyError(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Przełącza widoczną listę na inną z już pobranych.
  Future<void> selectList(String listId) async {
    if (listId == _selectedListId) return;
    _selectedListId = listId;
    await loadShoppingList(listId);
  }

  /// Dopisuje pojedynczy produkt (spoza przepisu) do bieżącej listy.
  Future<bool> addProduct(String productId, {double quantity = 1.0, String unit = 'szt'}) async {
    if (_selectedListId == null) return false;
    _errorMessage = null;
    try {
      await _shoppingListService.addProduct(
        _selectedListId!,
        productId,
        quantity: quantity,
        unit: unit,
      );
      await loadShoppingList(_selectedListId!);
      return true;
    } catch (e) {
      _errorMessage = friendlyError(e);
      notifyListeners();
      return false;
    }
  }

  /// Usuwa całą listę zakupów i odświeża pozostałe. Jeśli usunięta była
  /// aktualnie oglądaną, `loadAllLists` sam przełączy się na pierwszą
  /// dostępną (albo wyczyści widok, gdy nie ma już żadnej).
  Future<bool> deleteList(String listId) async {
    _errorMessage = null;
    try {
      await _shoppingListService.deleteList(listId);
      final wasSelected = listId == _selectedListId;
      await loadAllLists(preferredListId: wasSelected ? null : _selectedListId);
      return true;
    } catch (e) {
      _errorMessage = friendlyError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> removeItem(String itemId) async {    if (_selectedListId == null) return false;
    _errorMessage = null;
    try {
      await _shoppingListService.deleteItem(_selectedListId!, itemId);
      await loadShoppingList(_selectedListId!);
      return true;
    } catch (e) {
      _errorMessage = friendlyError(e);
      notifyListeners();
      return false;
    }
  }

  Future<void> loadShoppingList(String listId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _currentList = await _shoppingListService.getShoppingList(listId);
    } catch (e) {
      _errorMessage = friendlyError(e);
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
      _errorMessage = friendlyError(e);
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
      _errorMessage = friendlyError(e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Czyści cały stan — wywoływane przy wylogowaniu.
  void clear() {
    _currentList = null;
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }
}
