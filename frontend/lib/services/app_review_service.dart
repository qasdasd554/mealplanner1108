import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';

import 'api_client.dart';

/// Sygnał wyłącznie po udanym zapisie; pobieranie danych nie prosi o ocenę.
class AppReviewSignal {
  static final successfulActions = ValueNotifier<int>(0);

  static void recordSuccess() {
    successfulActions.value++;
  }
}

/// Wygląd, dostępność, zamknięcie i limity okna należą do Apple/Google.
/// Backend atomowo pilnuje dodatkowego limitu 10 dni na konto.
class AppReviewService {
  AppReviewService({
    Future<bool> Function()? isAvailable,
    Future<bool> Function()? claim,
    Future<void> Function()? requestReview,
  }) : _isAvailable = isAvailable ?? InAppReview.instance.isAvailable,
       _claim = claim ?? _claimOnServer,
       _requestReview = requestReview ?? InAppReview.instance.requestReview;

  final Future<bool> Function() _isAvailable;
  final Future<bool> Function() _claim;
  final Future<void> Function() _requestReview;
  bool _busy = false;

  static Future<bool> _claimOnServer() async {
    final response = await ApiClient().post(
      '/users/me/review-prompt/claim',
      body: <String, dynamic>{},
      timeout: const Duration(seconds: 5),
    );
    return response is Map<String, dynamic> && response['allowed'] == true;
  }

  Future<bool> maybeRequest({bool Function()? stillSafe}) async {
    if (_busy) return false;
    _busy = true;
    try {
      if (!await _isAvailable() || !(stillSafe?.call() ?? true)) return false;
      if (!await _claim() || !(stillSafe?.call() ?? true)) return false;
      await _requestReview();
      // Sukces oznacza wywołanie API, nie dowód wystawienia oceny.
      return true;
    } catch (_) {
      // Opcjonalna prośba nigdy nie blokuje głównej funkcji ani sesji.
      return false;
    } finally {
      _busy = false;
    }
  }
}
