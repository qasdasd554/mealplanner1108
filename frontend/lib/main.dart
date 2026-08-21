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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // WAŻNE: ekran "Śledzenie" używa DateFormat('dd MMMM yyyy', 'pl_PL')
  // (polskie nazwy miesięcy). Pakiet intl wymaga jawnej inicjalizacji
  // danych dla danego locale, zanim jakikolwiek DateFormat go użyje —
  // bez tego rzuca wyjątek wewnątrz build(), co wywalało cały ekran na
  // biało. Musi się zakończyć PRZED runApp(), inaczej pierwsza klatka
  // mogłaby wyrenderować się zanim dane będą gotowe.
  await initializeDateFormatting('pl_PL', null);

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
        ChangeNotifierProvider(create: (_) => PromotionProvider()),
      ],
      child: const SmartMealPlannerApp(),
    ),
  );

  // Nasłuchiwanie na udostępnienia z innych aplikacji (np. TikTok) — po
  // uruchomieniu aplikacji, żeby GlobalKey nawigatora był już podłączony
  // do zbudowanego drzewa widgetów.
  ShareIntentHandler.initialize(SmartMealPlannerApp.navigatorKey);
}
