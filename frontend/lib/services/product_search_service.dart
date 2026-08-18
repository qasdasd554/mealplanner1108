import '../models/product.dart';
import 'api_client.dart';
import '../config/api_config.dart';

/// Wyszukiwanie w GLOBALNYM katalogu produktów (nie przypisanym do
/// konkretnego sklepu) — używane przy ręcznym dodawaniu przepisu, gdzie
/// wybieramy produkt jako składnik, niezależnie od tego, w którym sklepie
/// jest dostępny.
class ProductSearchService {
  final ApiClient _client = ApiClient();

  Future<List<Product>> search(String query, {int limit = 20}) async {
    if (query.trim().isEmpty) return [];
    final response = await _client.get(
      '${ApiConfig.products}?search=${Uri.encodeComponent(query.trim())}&limit=$limit',
    );
    if (response is List) {
      return response.map((e) => Product.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }
}
