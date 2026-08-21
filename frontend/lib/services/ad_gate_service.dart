import 'package:shared_preferences/shared_preferences.dart';

/// Bramka reklamowa dla ekranu Śledzenia — konta BEZ Premium muszą
/// obejrzeć krótką reklamę wideo, żeby przejść dalej, maksymalnie 2 razy
/// na 8 godzin.
///
/// UWAGA (NAPRAWA AWARYJNA — TYMCZASOWE WYŁĄCZENIE, sierpień 2026):
/// aplikacja zaczęła crashować NATYCHMIAST po otwarciu po skoku wersji
/// google_mobile_ads (5→9). Nawet po usunięciu wywołań MobileAds.
/// initialize() z main.dart w kodzie Dart, SAM pakiet google_mobile_ads
/// jako zależność (nawet nieużywany) dołącza natywny kod Androida do
/// buildu, który może mieć własną, automatyczną inicjalizację URUCHAMIANĄ
/// JESZCZE PRZED main() we Flutterze — więc samo niewywoływanie go z
/// Dart mogło nie wystarczyć. Dla pewności CAŁY import google_mobile_ads
/// został tu usunięty, a zależność wykomentowana w pubspec.yaml, żeby
/// natywny kod SDK reklam w ogóle nie trafiał do zbudowanej aplikacji.
///
/// Interfejs (needsAd/showAd) jest CELOWO zachowany bez zmian, żeby
/// reszta aplikacji (home_screen.dart, ad_gate_screen.dart) kompilowała
/// się bez żadnych dodatkowych zmian — showAd() po prostu zawsze zwraca
/// false, dopóki nie zdiagnozujemy prawdziwej przyczyny awarii na
/// podstawie logów i bezpiecznie przywrócimy prawdziwą implementację.
class AdGateService {
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
    if (recent.length != raw.length) {
      await prefs.setStringList(_prefsKey, recent.map((t) => t.toIso8601String()).toList());
    }
    return recent;
  }

  /// TYMCZASOWO wyłączone — patrz komentarz na górze pliku. Zawsze
  /// zwraca false (reklama "nie załadowała się"), co jest bezpiecznie
  /// obsługiwane przez wywołujący kod — ale bramka jest i tak wyłączona
  /// w home_screen.dart, więc ten kod obecnie się nie uruchamia.
  Future<bool> showAd() async {
    return false;
  }
}
