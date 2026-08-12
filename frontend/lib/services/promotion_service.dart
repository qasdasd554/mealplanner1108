import '../models/promotion.dart';
import 'api_client.dart';

class PromotionService {
  final ApiClient _client = ApiClient();

  /// Zwraca aktywne, dziś ważne promocje — opcjonalnie tylko dla danego
  /// sklepu i/lub pasujące do wpisanej nazwy produktu.
  Future<List<Promotion>> getPromotions({String? storeName, String? search}) async {
    final params = <String>[];
    if (storeName != null && storeName.isNotEmpty) {
      params.add('store_name=${Uri.encodeComponent(storeName)}');
    }
    if (search != null && search.isNotEmpty) {
      params.add('search=${Uri.encodeComponent(search)}');
    }
    final query = params.isEmpty ? '' : '?${params.join('&')}';

    final response = await _client.get('/promotions/$query');
    if (response is List) {
      return response.map((e) => Promotion.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  /// Sprawdza, czy konkretny produkt ma dziś aktywną promocję. Używane np.
  /// przy pozycjach listy zakupów, żeby pokazać odznakę "promocja".
  Future<List<Promotion>> checkPromotion(String productName, {String? storeName}) async {
    final params = <String>['product_name=${Uri.encodeComponent(productName)}'];
    if (storeName != null && storeName.isNotEmpty) {
      params.add('store_name=${Uri.encodeComponent(storeName)}');
    }
    final response = await _client.get('/promotions/check?${params.join('&')}');
    if (response is List) {
      return response.map((e) => Promotion.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }
}
