import '../models/promotion.dart';
import 'api_client.dart';

class PromotionService {
  PromotionService({ApiClient? client, Future<void> Function(Duration)? wait})
    : _client = client ?? ApiClient(),
      _wait = wait ?? Future<void>.delayed;
  final ApiClient _client;
  final Future<void> Function(Duration) _wait;

  /// Zwraca aktywne, dziś ważne promocje — opcjonalnie tylko dla danego
  /// sklepu i/lub pasujące do wpisanej nazwy produktu.
  Future<List<Promotion>> getPromotions({
    String? storeName,
    String? search,
  }) async {
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
      return response
          .map((e) => Promotion.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  /// Sprawdza, czy konkretny produkt ma dziś aktywną promocję. Używane np.
  /// przy pozycjach listy zakupów, żeby pokazać odznakę "promocja".
  Future<List<Promotion>> checkPromotion(
    String productName, {
    String? storeName,
  }) async {
    final params = <String>['product_name=${Uri.encodeComponent(productName)}'];
    if (storeName != null && storeName.isNotEmpty) {
      params.add('store_name=${Uri.encodeComponent(storeName)}');
    }
    final response = await _client.get('/promotions/check?${params.join('&')}');
    if (response is List) {
      return response
          .map((e) => Promotion.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  /// Uruchamia skanowanie gazetki danego sklepu przez AI (tylko admin).
  /// Zwraca podsumowanie — ile promocji znaleziono i zakolejkowano do
  /// akceptacji. To NIE tworzy żadnych aktywnych promocji od razu.
  Future<Map<String, dynamic>> triggerAiScan(
    String storeName, {
    bool Function()? isActive,
  }) async {
    final response = await _client.post(
      '/promotions/ai-scan/jobs?store_name=${Uri.encodeComponent(storeName)}',
    );
    return waitForScan(response as Map<String, dynamic>, isActive: isActive);
  }

  Future<List<Map<String, dynamic>>> activeScans() async {
    final response = await _client.get('/promotions/ai-scan/jobs/active');
    return (response as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> waitForScan(
    Map<String, dynamic> job, {
    bool Function()? isActive,
  }) async {
    var current = job;
    final id = current['id'];
    if (id is! String || id.isEmpty)
      throw ApiException(422, 'Nieprawidłowy status skanowania.');
    final deadline = DateTime.now().add(const Duration(minutes: 8));
    var connectionErrors = 0;
    while (DateTime.now().isBefore(deadline) && (isActive?.call() ?? true)) {
      if (current['status'] == 'completed') {
        return {
          ...?current['result'] as Map<String, dynamic>?,
          'status': 'completed',
        };
      }
      if (current['status'] == 'failed') {
        throw ApiException(
          422,
          current['error'] as String? ?? 'Nie udało się przeskanować gazetki.',
        );
      }
      await _wait(const Duration(seconds: 3));
      if (!(isActive?.call() ?? true)) break;
      try {
        current =
            await _client.get(
                  '/promotions/ai-scan/jobs/$id',
                  timeout: const Duration(seconds: 20),
                )
                as Map<String, dynamic>;
        connectionErrors = 0;
      } on ApiException catch (error) {
        if ({401, 403, 404}.contains(error.statusCode)) rethrow;
        if (++connectionErrors >= 3) break;
      } catch (_) {
        if (++connectionErrors >= 3) break;
      }
    }
    // Praca na serwerze nadal trwa. Zamknięcie widoku/utrata sieci jej nie
    // anuluje i nie uruchamia drugiego skanu. Wyniki zostaną w kolejce.
    if (current['status'] == 'completed') {
      return {
        ...?current['result'] as Map<String, dynamic>?,
        'status': 'completed',
      };
    }
    return current;
  }

  /// Lista promocji znalezionych przez AI, czekających na akceptację
  /// administratora.
  Future<List<Promotion>> getPendingPromotions({String? market}) async {
    final query =
        market == null ? '' : '?market=${Uri.encodeQueryComponent(market)}';
    final response = await _client.get('/promotions/pending$query');
    if (response is List) {
      return response
          .map((e) => Promotion.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<Promotion> approvePromotion(String promotionId) async {
    final response = await _client.put('/promotions/$promotionId/approve');
    return Promotion.fromJson(response as Map<String, dynamic>);
  }

  Future<Promotion> rejectPromotion(String promotionId) async {
    final response = await _client.put('/promotions/$promotionId/reject');
    return Promotion.fromJson(response as Map<String, dynamic>);
  }
}
