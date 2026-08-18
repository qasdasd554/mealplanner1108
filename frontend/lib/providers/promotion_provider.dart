import 'package:flutter/foundation.dart';
import '../models/promotion.dart';
import '../services/promotion_service.dart';

class PromotionProvider with ChangeNotifier {
  final PromotionService _service = PromotionService();

  List<Promotion> _promotions = [];
  bool _isLoading = false;
  String? _error;
  String? _loadedForStore;

  List<Promotion> get promotions => _promotions;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadPromotions({String? storeName}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _promotions = await _service.getPromotions(storeName: storeName);
      _loadedForStore = storeName;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      _promotions = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Ładuje promocje dla sklepu tylko, jeśli jeszcze nie zostały wczytane
  /// dla tego samego sklepu — pozwala bezpiecznie wywoływać to z wielu
  /// ekranów bez zbędnych powtórnych zapytań.
  Future<void> ensureLoadedForStore(String? storeName) async {
    if (_loadedForStore == storeName && _promotions.isNotEmpty) return;
    await loadPromotions(storeName: storeName);
  }

  /// Zwraca promocję pasującą do nazwy produktu (dopasowanie częściowe,
  /// bez rozróżniania wielkości liter) z już wczytanej listy — używane do
  /// odznak "promocja" przy pozycjach listy zakupów.
  Promotion? findForProduct(String productName) {
    final needle = productName.toLowerCase().trim();
    if (needle.isEmpty) return null;
    for (final p in _promotions) {
      final promoName = p.productName.toLowerCase();
      if (promoName.contains(needle) || needle.contains(promoName)) {
        return p;
      }
    }
    return null;
  }

  /// Czyści cały stan — wywoływane przy wylogowaniu.
  void clear() {
    _promotions = [];
    _isLoading = false;
    _error = null;
    _loadedForStore = null;
    notifyListeners();
  }
}
