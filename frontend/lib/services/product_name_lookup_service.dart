import '../models/barcode_lookup_result.dart';
import 'api_client.dart';

/// Wspólne wyszukiwanie po nazwie: katalog aplikacji, zapamiętane skany
/// w Neon i Open Food Facts — ta sama zewnętrzna baza co skaner kodów.
class ProductNameLookupService {
  final ApiClient _client;

  ProductNameLookupService({ApiClient? client})
      : _client = client ?? ApiClient();

  Future<List<BarcodeLookupResult>> search(
    String query, {
    int limit = 10,
  }) async {
    final normalized = query.trim();
    if (normalized.length < 2) return const [];

    final response = await _client.get(
      '/products/search-by-name?query=${Uri.encodeQueryComponent(normalized)}&limit=$limit',
      timeout: const Duration(seconds: 12),
    );
    if (response is! List) return const [];
    return response
        .whereType<Map<String, dynamic>>()
        .map(BarcodeLookupResult.fromJson)
        .where((result) => result.name?.trim().isNotEmpty == true)
        .toList();
  }
}
