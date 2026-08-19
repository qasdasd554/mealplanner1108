import 'package:flutter/material.dart';
import '../models/store.dart';
import '../services/store_service.dart';
import '../utils/error_utils.dart';

class StoreProvider with ChangeNotifier {
  final StoreService _storeService = StoreService();

  List<Store> _stores = [];
  Store? _selectedStore;
  bool _isLoading = false;
  String? _errorMessage;

  List<Store> get stores => _stores;
  Store? get selectedStore => _selectedStore;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> loadStores() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _stores = await _storeService.getStores();
    } catch (e) {
      _errorMessage = friendlyError(e);
    } finally {
      _isLoading = false;
      notifyListeners();
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
  /// jest `_selectedStore` (preferencja KONKRETNEGO użytkownika) — lista
  /// samych sklepów jest wspólna dla wszystkich, ale czyścimy ją też dla
  /// spójności (i tak odświeży się bezboleśnie przy następnym ładowaniu).
  void clear() {
    _stores = [];
    _selectedStore = null;
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }
}
