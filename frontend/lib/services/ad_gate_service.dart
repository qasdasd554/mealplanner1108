import 'dart:async';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Bramka reklamowa dla ekranu Śledzenia — konta BEZ Premium muszą
/// obejrzeć krótką reklamę wideo, żeby przejść dalej, maksymalnie 2 razy
/// na 8 godzin. Po wykorzystaniu limitu w danym oknie czasowym dostęp
/// jest wolny od reklam AŻ DO jego wygaśnięcia (nie blokujemy dostępu
/// całkowicie — to byłoby zbyt frustrujące) — dopiero po 8 godzinach od
/// NAJSTARSZEGO z dwóch ostatnich obejrzeń licznik "resetuje się" i
/// trzeba obejrzeć znowu.
///
/// UWAGA: identyfikator jednostki reklamowej poniżej to OFICJALNY,
/// TESTOWY identyfikator Google (bezpieczny do developmentu — zawsze
/// zwraca reklamy testowe, nigdy prawdziwe). Podmień na własny z panelu
/// AdMob (Jednostki reklamowe → typ "Nagroda za obejrzenie w
/// międzyczasie" / Rewarded interstitial), gdy konto będzie gotowe do
/// serwowania prawdziwych reklam — inaczej nigdy nie zarobisz na
/// reklamach, mimo że funkcja będzie działać poprawnie.
class AdGateService {
  static const String _testAdUnitId = 'ca-app-pub-3940256099942544/5354046379';
  static const String adUnitId = _testAdUnitId;

  static const String _prefsKey = 'ad_gate_watch_timestamps';
  static const Duration _window = Duration(hours: 8);
  static const int _maxAdsPerWindow = 2;

  /// Zwraca true, jeśli trzeba pokazać reklamę przed wpuszczeniem do
  /// Śledzenia (limit z ostatnich 8h jeszcze nie wykorzystany).
  Future<bool> needsAd() async {
    final timestamps = await _getRecentTimestamps();
    return timestamps.length < _maxAdsPerWindow;
  }

  Future<List<DateTime>> _getRecentTimestamps() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_prefsKey) ?? [];
    final cutoff = DateTime.now().subtract(_window);
    final recent = raw
        .map((s) => DateTime.tryParse(s))
        .whereType<DateTime>()
        .where((t) => t.isAfter(cutoff))
        .toList();
    // Przy okazji sprzątamy stare wpisy — bez tego lista rosłaby w
    // nieskończoność przy długim korzystaniu z aplikacji.
    if (recent.length != raw.length) {
      await prefs.setStringList(_prefsKey, recent.map((t) => t.toIso8601String()).toList());
    }
    return recent;
  }

  Future<void> _recordWatch() async {
    final timestamps = await _getRecentTimestamps();
    timestamps.add(DateTime.now());
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey, timestamps.map((t) => t.toIso8601String()).toList());
  }

  /// Ładuje i pokazuje reklamę nagradzaną. Zwraca true TYLKO jeśli
  /// użytkownik obejrzał ją do końca (callback onUserEarnedReward) — w
  /// każdym innym przypadku (błąd ładowania, zamknięcie w trakcie) false,
  /// żeby wywołujący kod NIE wpuścił do Śledzenia bez pełnego obejrzenia.
  Future<bool> showAd() async {
    // Używamy standardowego Completer z dart:async — z ochroną przed
    // podwójnym complete() (callback "obejrzano nagrodę" i callback
    // "reklama zamknięta" zawsze przychodzą OBA, w tej kolejności; drugie
    // wywołanie complete() na tym samym Completerze rzuciłoby wyjątek).
    final completer = Completer<bool>();
    void completeOnce(bool earned) {
      if (!completer.isCompleted) completer.complete(earned);
    }

    RewardedInterstitialAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      rewardedInterstitialAdLoadCallback: RewardedInterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              completeOnce(false);
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              completeOnce(false);
            },
          );
          ad.show(
            onUserEarnedReward: (ad, reward) async {
              await _recordWatch();
              completeOnce(true);
            },
          );
        },
        onAdFailedToLoad: (error) {
          completeOnce(false);
        },
      ),
    );

    return completer.future;
  }
}
