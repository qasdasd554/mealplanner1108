import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'theme/app_theme.dart';
import 'providers/theme_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/food_log_provider.dart';
import 'providers/wellness_provider.dart';
import 'providers/meal_plan_provider.dart';
import 'providers/shopping_list_provider.dart';
import 'providers/promotion_provider.dart';
import 'providers/store_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth/email_verification_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/meal_plan/plan_config_screen.dart';
import 'screens/meal_plan/plan_view_screen.dart';
import 'screens/meal_plan/plan_archive_screen.dart';
import 'screens/profile/ingredient_preferences_screen.dart';
import 'screens/shopping/shopping_list_screen.dart';
import 'screens/recipes/recipes_screen.dart';
import 'screens/recipes/recipe_detail_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/profile/premium_screen.dart';
import 'screens/products/products_screen.dart';
import 'screens/tracker/calorie_tracker_screen.dart';
import 'screens/tracker/add_food_entry_screen.dart';
import 'screens/promotions/promotions_screen.dart';
import 'screens/notifications/notifications_screen.dart';
import 'utils/calendar_day.dart';
import 'services/update_service.dart';
import 'models/meal_plan.dart';
import 'l10n/app_localizations.dart';
import 'l10n/market_locale.dart';

class SmartMealPlannerApp extends StatefulWidget {
  @visibleForTesting
  final Map<String, WidgetBuilder> testRoutes;

  const SmartMealPlannerApp({super.key, this.testRoutes = const {}});

  // Globalny klucz nawigatora — potrzebny, żeby ShareIntentHandler mógł
  // otworzyć ekran rozpoznawania przepisu z linku POZA drzewem widgetów
  // (udostępnienie z innej aplikacji może przyjść w dowolnym momencie,
  // nie tylko wtedy, gdy mamy pod ręką zwykły BuildContext).
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  @override
  State<SmartMealPlannerApp> createState() => _SmartMealPlannerAppState();
}

class _SmartMealPlannerAppState extends State<SmartMealPlannerApp>
    with WidgetsBindingObserver {
  DateTime _lastForegroundDay = DateTime.now();
  bool _updateCheckInProgress = false;
  bool _updatePromptVisible = false;
  bool _hasLeftForeground = false;
  Timer? _updateTimer;
  AuthProvider? _observedAuth;
  bool _wasAuthenticated = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.read<AuthProvider>();
    if (identical(auth, _observedAuth)) return;
    _observedAuth?.removeListener(_onAuthChanged);
    _observedAuth = auth;
    _wasAuthenticated = auth.isAuthenticated;
    auth.addListener(_onAuthChanged);
  }

  void _onAuthChanged() {
    if (!mounted) return;
    final authenticated = _observedAuth!.isAuthenticated;
    final endedSession = _wasAuthenticated && !authenticated;
    _wasAuthenticated = authenticated;
    if (!endedSession) return;
    context.read<MealPlanProvider>().clear();
    context.read<FoodLogProvider>().clear();
    context.read<WellnessProvider>().clear();
    context.read<ShoppingListProvider>().clear();
    context.read<PromotionProvider>().clear();
    context.read<StoreProvider>().clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _observedAuth!.isAuthenticated) return;
      SmartMealPlannerApp.navigatorKey.currentState?.pushNamedAndRemoveUntil(
        '/login',
        (route) => false,
      );
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Dłuższa sesja na pierwszym planie też nie wymaga ponownego uruchomienia
    // aplikacji. Kontrola co 15 minut jest lekka (jeden publiczny endpoint),
    // a pojedynczy aktywny request chroni flaga poniżej.
    _updateTimer = Timer.periodic(const Duration(minutes: 15), (_) {
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed &&
          context.read<AuthProvider>().isAuthenticated &&
          !isSameCalendarDay(_lastForegroundDay, DateTime.now())) {
        _lastForegroundDay = DateTime.now();
        unawaited(context.read<MealPlanProvider>().loadPlans());
      }
      unawaited(_checkForUpdateAfterResume());
    });
  }

  @override
  void dispose() {
    _observedAuth?.removeListener(_onAuthChanged);
    _updateTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final now = DateTime.now();
      final dayChanged = !isSameCalendarDay(_lastForegroundDay, now);
      _lastForegroundDay = now;
      final auth = Provider.of<AuthProvider>(context, listen: false);
      // A notification shade, permission sheet or loss of window focus can
      // emit inactive → resumed without leaving the app. Do not replace the
      // user's current content with loading states for these transitions.
      if (auth.isAuthenticated && (_hasLeftForeground || dayChanged)) {
        unawaited(auth.loadProfileInBackground());
        unawaited(context.read<MealPlanProvider>().loadPlans());
        if (dayChanged) {
          Provider.of<FoodLogProvider>(context, listen: false).setDate(now);
          unawaited(
            Provider.of<WellnessProvider>(
              context,
              listen: false,
            ).loadForDate(now),
          );
        }
      }
      // Sprawdzamy wersję również po każdym powrocie aplikacji na pierwszy
      // plan. Wcześniej kontrola była tylko na splash screenie, więc osoba,
      // która pozostawiała aplikację otwartą w tle, nie widziała komunikatu
      // aż do pełnego zamknięcia i ponownego uruchomienia.
      if (_hasLeftForeground) {
        unawaited(_checkForUpdateAfterResume());
      }
      _hasLeftForeground = false;
    } else if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      _hasLeftForeground = true;
    }
  }

  Future<void> _checkForUpdateAfterResume() async {
    if (_updateCheckInProgress ||
        _updatePromptVisible ||
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      return;
    }
    _updateCheckInProgress = true;
    try {
      final update = await UpdateService().checkForUpdate();
      final navigator = SmartMealPlannerApp.navigatorKey.currentState;
      if (!mounted || navigator == null || !update.updateAvailable) return;

      _updatePromptVisible = true;
      await navigator.push(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder:
              (_) => UpdateAvailableScreen(
                storeUrl: update.storeUrl,
                forceUpdate: update.forceUpdate,
              ),
        ),
      );
    } finally {
      _updatePromptVisible = false;
      _updateCheckInProgress = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        final auth = context.watch<AuthProvider>();
        return MaterialApp(
          // NAPRAWA MIGANIA BIAŁEGO TŁA PRZY ZMIANIE MOTYWU:
          // AppTheme trzyma kolory w polu STATYCZNYM (`AppTheme._isDark`),
          // a nie w drzewie widgetów — świadoma decyzja, żeby dało się
          // pisać `AppTheme.surfaceColor` bez `Theme.of(context)`. Skutek
          // uboczny: widgety zbudowane jako `const` NIE są przebudowywane
          // przy zmianie motywu (Flutter uznaje je za identyczne), więc
          // zostają z kolorami zapamiętanymi w poprzednim trybie —
          // np. tabela porównania planów zostawała biała w trybie ciemnym,
          // dopóki cokolwiek innego nie wymusiło jej odbudowy.
          //
          // Klucz zależny od motywu wymusza odtworzenie CAŁEGO drzewa przy
          // przełączeniu, więc żaden `const` widget nie zostaje ze starymi
          // kolorami. Dzieje się to tylko przy ręcznej zmianie motywu,
          // więc koszt jest bez znaczenia.
          key: ValueKey(themeProvider.isDark),
          navigatorKey: SmartMealPlannerApp.navigatorKey,
          title: 'Meal Planner Polska',
          locale: localeForMarket(
            accountCountry:
                auth.currentUser?.countryCode ??
                (auth.isAuthenticated ? 'PL' : null),
            deviceRegion:
                WidgetsBinding.instance.platformDispatcher.locale.countryCode,
          ),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.themeMode,
          debugShowCheckedModeBanner: false,
          initialRoute: '/',
          routes: {
            '/': (context) => const SplashScreen(),
            '/login': (context) => const LoginScreen(),
            '/register': (context) => const RegisterScreen(),
            '/verify-email': (context) => const EmailVerificationScreen(),
            '/onboarding': (context) => const OnboardingScreen(),
            '/home':
                (context) => HomeScreen(
                  initialIndex:
                      (ModalRoute.of(context)?.settings.arguments as int?) ?? 0,
                ),
            '/plan/config': (context) => const PlanConfigScreen(),
            '/plan/view':
                (context) => PlanViewScreen(
                  archivedPlan:
                      ModalRoute.of(context)?.settings.arguments is MealPlan
                          ? ModalRoute.of(context)!.settings.arguments
                              as MealPlan
                          : null,
                ),
            '/plan/archive': (context) => const PlanArchiveScreen(),
            '/profile/ingredients':
                (context) => const IngredientPreferencesScreen(),
            '/shopping': (context) => const ShoppingListScreen(),
            '/recipes': (context) => const RecipesScreen(),
            '/recipe/detail': (context) => const RecipeDetailScreen(),
            '/profile': (context) => const ProfileScreen(),
            '/premium': (context) => const PremiumScreen(),
            '/products': (context) => const ProductsScreen(),
            '/tracker': (context) => const CalorieTrackerScreen(),
            '/tracker/add': (context) => const AddFoodEntryScreen(),
            '/promotions': (context) => const PromotionsScreen(),
            '/notifications': (context) => const NotificationsScreen(),
            ...widget.testRoutes,
          },
        );
      },
    );
  }
}
