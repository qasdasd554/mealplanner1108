import '../models/product.dart';
import 'api_client.dart';
import '../config/api_config.dart';

/// Wyszukiwanie w GLOBALNYM katalogu produktów (nie przypisanym do
/// konkretnego sklepu) — używane przy ręcznym dodawaniu przepisu, gdzie
/// wybieramy produkt jako składnik, niezależnie od tego, w którym sklepie
/// jest dostępny.
class ProductSearchService {
  final ApiClient _client = ApiClient();

  Future<List<Product>> list({
    String query = '',
    int skip = 0,
    int limit = 50,
  }) async {
    final parameters = <String, String>{'skip': '$skip', 'limit': '$limit'};
    if (query.trim().isNotEmpty) {
      parameters['search'] = query.trim();
    }
    final uri = Uri(path: ApiConfig.products, queryParameters: parameters);
    final response = await _client.get(uri.toString());
    if (response is List) {
      return response
          .map((e) => Product.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<List<Product>> search(String query, {int limit = 20}) async {
    if (query.trim().isEmpty) return [];
    return list(query: query, limit: limit);
  }
}
