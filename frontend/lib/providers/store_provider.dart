import 'package:flutter/material.dart';
import '../models/store.dart';
import '../services/store_service.dart';
import '../utils/error_utils.dart';

class StoreProvider with ChangeNotifier {
  final StoreService _storeService;
  final ErrorStringsResolver? errorStrings;

  StoreProvider({StoreService? service, this.errorStrings})
    : _storeService = service ?? StoreService();

  List<Store> _stores = [];
  Store? _selectedStore;
  bool _isLoading = false;
  String? _errorMessage;
  int _loadGeneration = 0;

  List<Store> get stores => _stores;
  Store? get selectedStore => _selectedStore;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> loadStores() async {
    final generation = ++_loadGeneration;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final stores = await _storeService.getStores();
      if (generation != _loadGeneration) return;
      _stores = stores;
      final selectedIndex = stores.indexWhere(
        (store) => store.id == _selectedStore?.id,
      );
      _selectedStore = selectedIndex < 0 ? null : stores[selectedIndex];
    } catch (e) {
      if (generation != _loadGeneration) return;
      _errorMessage = friendlyError(e, strings: errorStrings?.call());
    } finally {
      if (generation == _loadGeneration) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  void selectStore(Store store) {
    _selectedStore = store;
    notifyListeners();
  }

  void selectStoreById(String id) {
    if (_stores.isEmpty) return;
    try {
      _selectedStore = _stores.firstWhere((store) => store.id == id);
      notifyListeners();
    } catch (_) {
      // Sklepu nie ma na liście
    }
  }

  /// Czyści cały stan — wywoływane przy wylogowaniu. Najważniejsze tu
  /// jest `_selectedStore` oraz katalog kraju KONKRETNEGO użytkownika.
  /// Spóźniona odpowiedź poprzedniej sesji nie może przywrócić jej katalogu.
  void clear() {
    _loadGeneration++;
    _stores = [];
    _selectedStore = null;
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _loadGeneration++;
    super.dispose();
  }
}
