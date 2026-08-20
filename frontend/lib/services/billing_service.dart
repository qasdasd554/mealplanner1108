import 'dart:async';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../config/api_config.dart';
import 'api_client.dart';

/// ID produktów subskrypcyjnych — MUSZĄ dokładnie odpowiadać temu, co
/// zostało utworzone w Google Play Console (patrz przewodnik konfiguracji
/// płatności). Zmiana tych stringów bez zmiany w Play Console spowoduje,
/// że aplikacja nie znajdzie żadnych produktów do kupienia.
const String kWeeklyProductId = 'premium_weekly';
const String kMonthlyProductId = 'premium_monthly';
const String kYearlyProductId = 'premium_yearly';

/// Obsługuje cały przepływ zakupu subskrypcji: odpytanie sklepu o
/// dostępne produkty (i ich prawdziwe, lokalne ceny), zainicjowanie
/// zakupu, nasłuchiwanie na wynik, i weryfikację po stronie backendu —
/// to backend, po zapytaniu Google, ostatecznie decyduje, czy nadać
/// dostęp premium (nigdy nie ufamy samej aplikacji, że "zakup się udał").
class BillingService {
  final InAppPurchase _iap = InAppPurchase.instance;
  final ApiClient _client = ApiClient();
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  /// Sprawdza, czy usługa płatności jest w ogóle dostępna na tym
  /// urządzeniu (np. brak konta Google Play, urządzenie bez usług
  /// Google itp. — rzadkie, ale możliwe).
  Future<bool> isAvailable() => _iap.isAvailable();

  /// Pobiera prawdziwe, lokalne ceny (uwzględniające walutę i podatki
  /// danego kraju) dla obu planów subskrypcji.
  Future<ProductDetailsResponse> queryProducts() {
    return _iap.queryProductDetails({kWeeklyProductId, kMonthlyProductId, kYearlyProductId});
  }

  /// Rozpoczyna zakup — wynik przyjdzie asynchronicznie przez
  /// [purchaseStream], nie przez zwróconą wartość tej metody.
  Future<void> buy(ProductDetails product) {
    final purchaseParam = PurchaseParam(productDetails: product);
    // Subskrypcje w ujednoliconym API in_app_purchase obsługuje się przez
    // buyNonConsumable (mimo nazwy — to standardowa ścieżka dla
    // subskrypcji na Androidzie, konsumpcja nie ma tu zastosowania).
    return _iap.buyNonConsumable(purchaseParam: purchaseParam);
  }

  /// Przywraca wcześniej kupione, wciąż aktywne subskrypcje — potrzebne
  /// np. po reinstalacji aplikacji albo zmianie urządzenia.
  Future<void> restorePurchases() => _iap.restorePurchases();

  /// Strumień aktualizacji zakupów — nasłuchuj na to, żeby wiedzieć, kiedy
  /// zakup się powiódł/nie powiódł/oczekuje.
  Stream<List<PurchaseDetails>> get purchaseStream => _iap.purchaseStream;

  /// WYMAGANE po każdym udanym (albo przywróconym) zakupie — potwierdza
  /// odbiór wobec sklepu. Bez tego Google automatycznie zwróci pieniądze
  /// użytkownikowi po 3 dniach, traktując zakup jako "nieobsłużony".
  Future<void> completePurchase(PurchaseDetails purchase) {
    return _iap.completePurchase(purchase);
  }

  void dispose() {
    _subscription?.cancel();
  }

  /// Wysyła token zakupu do backendu, który weryfikuje go bezpośrednio u
  /// Google i, jeśli prawdziwy i aktywny, nadaje dostęp premium. Zwraca
  /// zaktualizowane dane premium użytkownika.
  Future<Map<String, dynamic>> verifyPurchase({
    required String purchaseToken,
    required String productId,
  }) async {
    final response = await _client.post(
      ApiConfig.billingVerify,
      body: {'purchase_token': purchaseToken, 'product_id': productId},
    );
    return response as Map<String, dynamic>;
  }

  /// Jak [verifyPurchase], ale przez endpoint /restore — funkcjonalnie
  /// identyczne, osobna ścieżka głównie dla czytelności logów/metryk
  /// po stronie backendu.
  Future<Map<String, dynamic>> restoreOnBackend({
    required String purchaseToken,
    required String productId,
  }) async {
    final response = await _client.post(
      ApiConfig.billingRestore,
      body: {'purchase_token': purchaseToken, 'product_id': productId},
    );
    return response as Map<String, dynamic>;
  }
}
