import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
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
