import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
// UWAGA (NAPRAWA AWARYJNA): import usuniety razem z zaleznoscia w
// pubspec.yaml - patrz komentarz nizej przy (wylaczonej) inicjalizacji.
// import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'app.dart';
import 'providers/auth_provider.dart';
import 'providers/store_provider.dart';
import 'providers/meal_plan_provider.dart';
import 'providers/shopping_list_provider.dart';
import 'providers/food_log_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/promotion_provider.dart';
import 'services/share_intent_handler.dart';
import 'services/push_service.dart';
import 'providers/wellness_provider.dart';

void main() async {
  // NAPRAWA BRAKU ZABEZPIECZENIA: w aplikacji nie było ŻADNEGO globalnego
  // przechwytywania błędów. Nieobsłużony wyjątek w dowolnym miejscu —
  // budowaniu widgetu, callbacku, funkcji async poza try/catch — kończył
  // się domyślnym czerwonym ekranem błędu Fluttera (w trybie debug) albo,
  // gorzej, awarią całego izolatu Darta w wersji produkcyjnej. Użytkownik
  // trafiał w ścianę bez żadnej drogi wyjścia poza ubiciem aplikacji.
  //
  // Dwie niezależne warstwy:
  // 1. ErrorWidget.builder — błąd przy BUDOWANIU pojedynczego widgetu
  //    (np. null tam, gdzie dane z serwera nie doszły) pokazuje teraz
  //    przyjazny komunikat z ikoną zamiast czerwonego ekranu ze stosem
  //    wywołań, który wygląda jak zepsuta aplikacja.
  // 2. runZonedGuarded + FlutterError.onError — błędy spoza drzewa
  //    widgetów (np. w funkcji async wywołanej z timera) są przechwytywane
  //    i logowane zamiast cicho ubijać aplikację.
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: const Color(0xFFF5F5F5),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              const Text(
                'Coś poszło nie tak przy wyświetlaniu tego ekranu.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  };

  runZonedGuarded(() async {
    await _bootstrap();
  }, (error, stack) {
    // Logujemy zamiast pozwolić błędowi cicho ubić izolat. Bez zdalnego
    // narzędzia (Crashlytics/Sentry) nie zobaczymy tego na produkcji,
    // ale samo przechwycenie już zapobiega awarii aplikacji z powodu
    // pojedynczego nieobsłużonego wyjątku w kodzie asynchronicznym.
    debugPrint('Nieobsłużony błąd: $error\n$stack');
  });
}

Future<void> _bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('FlutterError: ${details.exceptionAsString()}');
  };

  // Dane dat są lokalnym zasobem, ale nawet ich nieoczekiwany błąd nie
  // może zatrzymać pierwszej klatki aplikacji. Ekrany korzystające z
  // polskich nazw dat mają własne wartości zapasowe.
  try {
    await initializeDateFormatting('pl_PL', null).timeout(
      const Duration(seconds: 3),
    );
  } catch (error) {
    debugPrint('Nie udało się zainicjalizować polskich dat: $error');
  }

  // UWAGA (NAPRAWA AWARYJNA — TYMCZASOWE WYŁĄCZENIE): po skoku wersji
  // google_mobile_ads (5→9) aplikacja zaczęła crashować NATYCHMIAST po
  // otwarciu, zanim jakikolwiek kod Dart zdążył się wykonać — to
  // wskazuje na awarię na poziomie NATYWNYM (Android/Kotlin), której
  // try-catch po stronie Dart NIE jest w stanie złapać ani naprawić.
  // Dokumentacja Google wprost mówi, że brak/błąd konfiguracji SDK
  // reklam w AndroidManifest.xml "results in a crash on app launch" —
  // ale samo AndroidManifest.xml wygląda poprawnie, więc to może być
  // konflikt scalania manifestu z zależnościami nowszej wersji SDK,
  // którego nie da się zdiagnozować bez prawdziwych logów awarii
  // (adb logcat). Żeby NATYCHMIAST przywrócić działającą aplikację,
  // inicjalizacja jest tymczasowo wyłączona — Śledzenie po prostu
  // wpuszcza teraz wszystkich bez bramki reklamowej (patrz
  // home_screen.dart), dopóki nie zdiagnozujemy prawdziwej przyczyny
  // na podstawie logów i bezpiecznie przywrócimy tę funkcję.
  //
  // unawaited(
  //   MobileAds.instance.initialize().catchError((Object e) {
  //     debugPrint('[MobileAds] Błąd inicjalizacji (nie krytyczny): $e');
  //   }),
  // );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => StoreProvider()),
        ChangeNotifierProvider(create: (_) => MealPlanProvider()),
        ChangeNotifierProvider(create: (_) => ShoppingListProvider()),
        ChangeNotifierProvider(create: (_) => FoodLogProvider()),
        ChangeNotifierProvider(create: (_) => WellnessProvider()),
        ChangeNotifierProvider(create: (_) => PromotionProvider()),
      ],
      child: const SmartMealPlannerApp(),
    ),
  );

  // Firebase, APNs i lokalne powiadomienia są funkcjami dodatkowymi.
  // Uruchamiamy je dopiero PO runApp(), dzięki czemu błąd lub zawieszenie
  // dowolnego natywnego pluginu nigdy nie pozostawi użytkownika na białym
  // ekranie przed pierwszą klatką Fluttera.
  unawaited(PushService().init());

  // Nasłuchiwanie na udostępnienia z innych aplikacji (np. TikTok) — po
  // uruchomieniu aplikacji, żeby GlobalKey nawigatora był już podłączony
  // do zbudowanego drzewa widgetów.
  ShareIntentHandler.initialize(SmartMealPlannerApp.navigatorKey);

  // Kliknięcie dymka push przy aplikacji działającej w tle prowadzi do
  // listy powiadomień. Zimny start obsługuje SplashScreen, ponieważ tutaj
  // nawigator może nie być jeszcze podłączony do drzewa widgetów.
  PushService().notificationTaps.listen((_) {
    final navigator = SmartMealPlannerApp.navigatorKey.currentState;
    if (navigator != null) {
      navigator.pushNamed('/notifications');
    }
  });
}
