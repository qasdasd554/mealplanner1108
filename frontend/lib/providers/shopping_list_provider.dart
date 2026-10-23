import 'package:flutter/material.dart';
import '../models/shopping_list.dart';
import '../services/shopping_list_service.dart';
import '../utils/error_utils.dart';

class ShoppingListProvider with ChangeNotifier {
  final ShoppingListService _shoppingListService;
  final ErrorStringsResolver? errorStrings;

  ShoppingListProvider({
    ShoppingListService? shoppingListService,
    this.errorStrings,
  }) : _shoppingListService = shoppingListService ?? ShoppingListService();

  ShoppingList? _currentList;
  bool _isLoading = false;
  String? _errorMessage;
  Object? _creationFailure;
  Object? get creationFailure => _creationFailure;

  // Użytkownik Premium może mieć wiele list, ale ekran zakupów
  // ładował WYŁĄCZNIE listę powiązaną z aktywnym planem posiłków
  // (mealPlanProvider.activePlan), więc pozostałych nie dało się w ogóle
  // otworzyć — istniały w bazie i zwracał je GET /shopping-lists/mine,
  // tylko nic ich nie pokazywało. Trzymamy tu wszystkie i pozwalamy
  // przełączać.
  List<ShoppingList> _allLists = [];
  String? _selectedListId;
  final Set<String> _pendingToggleIds = <String>{};
  int _requestGeneration = 0;
  int _sessionGeneration = 0;

  ShoppingList? get currentList => _currentList;
  List<ShoppingList> get allLists => _allLists;
  String? get selectedListId => _selectedListId;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool isTogglePending(String itemId) => _pendingToggleIds.contains(itemId);

  ShoppingListItem? _findItem(ShoppingList list, String itemId) {
    for (final items in list.itemsByDepartment.values) {
      for (final item in items) {
        if (item.id == itemId) return item;
      }
    }
    return null;
  }

  /// Pobiera wszystkie listy użytkownika i ustawia aktywną.
  ///
  /// `preferredListId` (zwykle ID aktywnego planu posiłków) jest
  /// wybierane, jeśli faktycznie istnieje wśród list — inaczej bierzemy
  /// pierwszą dostępną, żeby ekran nigdy nie był pusty tylko dlatego, że
  /// aktywny plan akurat nie ma listy.
  Future<void> loadAllLists({String? preferredListId}) async {
    final generation = ++_requestGeneration;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final lists = await _shoppingListService.getMyLists();
      if (generation != _requestGeneration) return;
      _allLists = lists;

      String? target = preferredListId;
      // Porównujemy po mealPlanId, bo tym identyfikatorem backend
      // indeksuje listy zakupów (patrz _get_shopping_list_or_404).
      final hasPreferred = _allLists.any(
        (l) => l.mealPlanId == preferredListId,
      );
      if (!hasPreferred) {
        target = _allLists.isNotEmpty ? _allLists.first.mealPlanId : null;
      }

      if (target != null) {
        _selectedListId = target;
        final list = await _shoppingListService.getShoppingList(target);
        if (generation != _requestGeneration) return;
        _currentList = list;
      } else {
        _selectedListId = null;
        _currentList = null;
      }
    } catch (e) {
      if (generation != _requestGeneration) return;
      _errorMessage = friendlyError(e, strings: errorStrings?.call());
    } finally {
      if (generation == _requestGeneration) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Przełącza widoczną listę na inną z już pobranych.
  Future<void> selectList(String listId) async {
    if (listId == _selectedListId) return;
    _selectedListId = listId;
    await loadShoppingList(listId);
  }

  /// Dopisuje pojedynczy produkt (spoza przepisu) do bieżącej listy.
  Future<bool> addProduct(
    String productId, {
    double quantity = 1.0,
    String unit = 'szt',
  }) async {
    if (_selectedListId == null) return false;
    final session = _sessionGeneration;
    final listId = _selectedListId!;
    _errorMessage = null;
    try {
      await _shoppingListService.addProduct(
        listId,
        productId,
        quantity: quantity,
        unit: unit,
      );
      if (session != _sessionGeneration) return false;
      if (_selectedListId == listId) await loadShoppingList(listId);
      return true;
    } catch (e) {
      if (session != _sessionGeneration) return false;
      _errorMessage = friendlyError(e, strings: errorStrings?.call());
      notifyListeners();
      return false;
    }
  }

  Future<bool> addCustomItem(
    String name, {
    double quantity = 1.0,
    String unit = 'szt',
  }) async {
    if (_selectedListId == null || name.trim().isEmpty) return false;
    final session = _sessionGeneration;
    final listId = _selectedListId!;
    _errorMessage = null;
    try {
      await _shoppingListService.addCustomItem(
        listId,
        name.trim(),
        quantity: quantity,
        unit: unit,
      );
      if (session != _sessionGeneration) return false;
      if (_selectedListId == listId) await loadShoppingList(listId);
      return true;
    } catch (e) {
      if (session != _sessionGeneration) return false;
      _errorMessage = friendlyError(e, strings: errorStrings?.call());
      notifyListeners();
      return false;
    }
  }

  Future<bool> createEmptyList(String storeId) async {
    if (_isLoading) return false;
    final session = _sessionGeneration;
    _isLoading = true;
    _errorMessage = null;
    _creationFailure = null;
    notifyListeners();
    try {
      final created = await _shoppingListService.createEmptyList(storeId);
      if (session != _sessionGeneration) return false;
      _currentList = created;
      _selectedListId = created.mealPlanId;
      _allLists = [
        created,
        ..._allLists.where((list) => list.mealPlanId != created.mealPlanId),
      ];
      return true;
    } catch (e) {
      if (session != _sessionGeneration) return false;
      _creationFailure = e;
      _errorMessage = friendlyError(e, strings: errorStrings?.call());
      return false;
    } finally {
      if (session == _sessionGeneration) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<bool> mergeLists(List<String> listIds) async {
    if (_isLoading) return false;
    final session = _sessionGeneration;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final merged = await _shoppingListService.mergeLists(listIds);
      if (session != _sessionGeneration) return false;
      final sourceIds = listIds.toSet();
      _allLists = [
        merged,
        ..._allLists.where((list) => !sourceIds.contains(list.mealPlanId)),
      ];
      _currentList = merged;
      _selectedListId = merged.mealPlanId;
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

  /// Usuwa całą listę zakupów i odświeża pozostałe. Jeśli usunięta była
  /// aktualnie oglądaną, `loadAllLists` sam przełączy się na pierwszą
  /// dostępną (albo wyczyści widok, gdy nie ma już żadnej).
  Future<bool> deleteList(String listId) async {
    final session = _sessionGeneration;
    _errorMessage = null;
    try {
      await _shoppingListService.deleteList(listId);
      if (session != _sessionGeneration) return false;
      final wasSelected = listId == _selectedListId;
      await loadAllLists(preferredListId: wasSelected ? null : _selectedListId);
      return true;
    } catch (e) {
      if (session != _sessionGeneration) return false;
      _errorMessage = friendlyError(e, strings: errorStrings?.call());
      notifyListeners();
      return false;
    }
  }

  /// Kończy bieżącą listę. Zwraca liczbę produktów przeniesionych do
  /// spiżarni, albo `null` przy błędzie.
  Future<int?> completeList({bool moveToPantry = true}) async {
    if (_selectedListId == null) return null;
    final session = _sessionGeneration;
    final listId = _selectedListId!;
    _errorMessage = null;
    try {
      final moved = await _shoppingListService.completeList(
        listId,
        moveToPantry: moveToPantry,
      );
      if (session != _sessionGeneration) return null;
      await loadAllLists(preferredListId: _selectedListId);
      return moved;
    } catch (e) {
      if (session != _sessionGeneration) return null;
      _errorMessage = friendlyError(e, strings: errorStrings?.call());
      notifyListeners();
      return null;
    }
  }

  Future<bool> removeItem(String itemId) async {
    if (_selectedListId == null) return false;
    final session = _sessionGeneration;
    final listId = _selectedListId!;
    _errorMessage = null;
    try {
      await _shoppingListService.deleteItem(listId, itemId);
      if (session != _sessionGeneration) return false;
      if (_selectedListId == listId) await loadShoppingList(listId);
      return true;
    } catch (e) {
      if (session != _sessionGeneration) return false;
      _errorMessage = friendlyError(e, strings: errorStrings?.call());
      notifyListeners();
      return false;
    }
  }

  Future<void> loadShoppingList(String listId) async {
    final generation = ++_requestGeneration;
    _currentList = null;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final list = await _shoppingListService.getShoppingList(listId);
      if (generation != _requestGeneration) return;
      _currentList = list;
    } catch (e) {
      if (generation != _requestGeneration) return;
      _errorMessage = friendlyError(e, strings: errorStrings?.call());
    } finally {
      if (generation == _requestGeneration) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<bool> toggleItem(String itemId) async {
    final session = _sessionGeneration;
    final listAtRequest = _currentList;
    if (listAtRequest == null || _pendingToggleIds.contains(itemId)) {
      return false;
    }

    final targetItem = _findItem(listAtRequest, itemId);
    if (targetItem == null) return false;

    // Zmień stan lokalnie (Optymistyczna aktualizacja)
    final previousValue = targetItem.isChecked;
    _errorMessage = null;
    _pendingToggleIds.add(itemId);
    targetItem.isChecked = !previousValue;
    notifyListeners();

    try {
      final confirmedValue = await _shoppingListService.toggleItemCheck(
        listAtRequest.id,
        itemId,
      );
      if (session != _sessionGeneration) return false;
      // Lista mogła zostać odświeżona w trakcie żądania. Aktualizujemy
      // obiekt, który jest faktycznie widoczny, a nie stary odłączony model.
      if (_currentList?.id == listAtRequest.id) {
        _findItem(_currentList!, itemId)?.isChecked = confirmedValue;
      }
      return true;
    } catch (e) {
      if (session != _sessionGeneration) return false;
      if (_currentList?.id == listAtRequest.id) {
        _findItem(_currentList!, itemId)?.isChecked = previousValue;
      }
      _errorMessage = friendlyError(e, strings: errorStrings?.call());
      return false;
    } finally {
      if (session == _sessionGeneration) {
        _pendingToggleIds.remove(itemId);
        notifyListeners();
      }
    }
  }

  Future<bool> substituteItem(String itemId, String substituteProductId) async {
    if (_currentList == null) return false;
    final session = _sessionGeneration;
    final listAtRequest = _currentList!;
    _isLoading = true;
    notifyListeners();
    try {
      await _shoppingListService.substituteItem(
        listAtRequest.id,
        itemId,
        substituteProductId,
      );
      // Przeładuj listę, aby odzwierciedlić zamianę
      if (session != _sessionGeneration) return false;
      if (_currentList?.id == listAtRequest.id)
        await loadShoppingList(listAtRequest.mealPlanId);
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

  /// Czyści cały stan — wywoływane przy wylogowaniu.
  void clear() {
    _sessionGeneration++;
    _requestGeneration++;
    _currentList = null;
    _allLists = [];
    _selectedListId = null;
    _isLoading = false;
    _errorMessage = null;
    _pendingToggleIds.clear();
    _creationFailure = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _sessionGeneration++;
    _requestGeneration++;
    super.dispose();
  }
}
