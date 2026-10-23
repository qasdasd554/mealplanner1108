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

/// A short-lived opportunity, never a popup waiting indefinitely for a form
/// or camera to close. Times are passed in explicitly for deterministic tests.
class ReviewPromptSchedule {
  static const quietPeriod = Duration(seconds: 8);
  static const opportunityLifetime = Duration(minutes: 2);
  String? _userId;
  int? _generation;
  int _successes = 0;
  DateTime? _lastSuccess;

  bool recordSuccess(String userId, int generation, DateTime now) {
    if (_userId != userId || _generation != generation) {
      _userId = userId;
      _generation = generation;
      _successes = 0;
    }
    _lastSuccess = now;
    return ++_successes >= 2;
  }

  bool isReady(String userId, int generation, DateTime now) {
    if (_userId != userId ||
        _generation != generation ||
        _lastSuccess == null ||
        _successes < 2)
      return false;
    final elapsed = now.difference(_lastSuccess!);
    return elapsed >= quietPeriod && elapsed <= opportunityLifetime;
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
  bool _requestedThisSession = false;

  static Future<bool> _claimOnServer() async {
    final response = await ApiClient().post(
      '/users/me/review-prompt/claim',
      body: <String, dynamic>{},
      timeout: const Duration(seconds: 5),
    );
    return response is Map<String, dynamic> && response['allowed'] == true;
  }

  Future<bool> maybeRequest({bool Function()? stillSafe}) async {
    if (_busy || _requestedThisSession) return false;
    _busy = true;
    try {
      if (!await _isAvailable() || !(stillSafe?.call() ?? true)) return false;
      if (!await _claim() || !(stillSafe?.call() ?? true)) return false;
      await _requestReview();
      _requestedThisSession = true;
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
