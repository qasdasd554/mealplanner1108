import 'package:flutter/foundation.dart';

class ApiConfig {
  // Prawdziwy backend produkcyjny (Render). Używany zawsze poza trybem
  // debug na emulatorze — wcześniej aplikacja ZAWSZE (także w wydanym
  // APK na prawdziwym telefonie) próbowała łączyć się z 10.0.2.2, czyli
  // adresem działającym WYŁĄCZNIE wewnątrz emulatora Android Studio.
  // Efekt: każde żądanie sieciowe w zainstalowanej aplikacji kończyło się
  // błędem połączenia.
  static const String _productionBaseUrl = 'https://mealplanner1108.onrender.com';

  // Dynamiczne dopasowanie adresu URL w zależności od platformy
  static String get baseUrl {
    if (kIsWeb) {
      final uri = Uri.base;
      // Jeśli działamy w GitHub Codespaces (web)
      if (uri.host.contains('app.github.dev')) {
        // Zamieniamy końcowy numer portu w subdomenie Codespaces na -8000 (backend)
        final newHost = uri.host.replaceFirst(RegExp(r'-\d+(?=\.app\.github\.dev$)'), '-8000');
        return '${uri.scheme}://$newHost';
      }
      // Jeśli to lokalny serwer webowy na komputerze
      if (uri.host == 'localhost' || uri.host == '127.0.0.1') {
        return 'http://localhost:8000';
      }
      return _productionBaseUrl;
    }
    // Emulator Androida w trybie debug — wygodny lokalny backend na hoście.
    // UWAGA (naprawa — "usługa chwilowo niedostępna" na iOS): warunek
    // sprawdzał WYŁĄCZNIE kDebugMode, bez sprawdzenia platformy — więc
    // uruchomienie aplikacji na iOS w trybie debug (np. z Xcode) TEŻ
    // trafiało w ten warunek i próbowało łączyć się z 10.0.2.2, adresem
    // istniejącym WYŁĄCZNIE wewnątrz emulatora Androida, kompletnie
    // nieosiągalnym na iOS (nawet na symulatorze). Efekt: każde
    // zapytanie sieciowe na iOS w trybie debug kończyło się błędem
    // połączenia. Dodane sprawdzenie platformy (przez
    // defaultTargetPlatform, bezpieczne też na web — w przeciwieństwie
    // do Platform.isAndroid z dart:io, które nie kompiluje się na web).
    if (kDebugMode && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }
    // Urządzenie fizyczne / build release (to trafia do prawdziwych użytkowników) —
    // prawdziwy backend na Render.
    return _productionBaseUrl;
  }

  static const String apiPrefix = '/api/v1';

  static String get apiUrl => '$baseUrl$apiPrefix';

  // ── Google Sign-In ──────────────────────────────────────────────
  // Client ID typu "Web application" z Google Cloud Console. To NIE jest
  // Android OAuth Client (ten nie jest w ogóle wpisywany w kodzie — Google
  // Play Services znajduje go automatycznie na podstawie package name
  // aplikacji + odcisku SHA-1 certyfikatu podpisującego build). Musi być
  // identyczny z GOOGLE_WEB_CLIENT_ID w backendzie (app/core/config.py).
  static const String googleWebClientId =
      '780793039743-6ap1jq18i31hqt04pf7gj8i4jip67uts.apps.googleusercontent.com';

  /// Client ID klienta OAuth typu **iOS** z Google Cloud Console.
  ///
  /// PUSTY = logowanie Google jest na iOS WYŁĄCZONE (przycisk się nie
  /// pokazuje — patrz login_screen.dart). Tak jest teraz, bo bez tej
  /// konfiguracji logowanie kończyło się błędem.
  ///
  /// Żeby włączyć Google także na iOS, trzeba zrobić WSZYSTKIE trzy rzeczy
  /// — sama zmiana tej stałej nie wystarczy:
  ///
  /// 1. Google Cloud Console → Credentials → Create OAuth client ID →
  ///    typ "iOS", Bundle ID: com.meal-planner-polska-v1. Skopiowany
  ///    identyfikator wklej poniżej.
  /// 2. ios/Runner/Info.plist: dodaj klucz `GIDClientID` z tą samą wartością.
  /// 3. ios/Runner/Info.plist: dodaj schemat URL z ODWRÓCONYM client ID
  ///    (czyli "com.googleusercontent.apps.780793039743-xxxx"), bo bez
  ///    niego system nie ma jak wrócić do aplikacji po zalogowaniu:
  ///
  ///    <key>CFBundleURLTypes</key>
  ///    <array>
  ///      <dict>
  ///        <key>CFBundleURLSchemes</key>
  ///        <array>
  ///          <string>com.googleusercontent.apps.780793039743-xxxx</string>
  ///        </array>
  ///      </dict>
  ///    </array>
  ///
  /// Po uzupełnieniu przycisk pojawi się na iOS automatycznie.
  static const String googleIosClientId = '';

  /// Klucz PUBLICZNY (site key) Cloudflare Turnstile — bramki CAPTCHA
  /// przed logowaniem i rejestracją.
  ///
  /// PUSTY = bramka WYŁĄCZONA (widget się nie pokazuje, aplikacja działa
  /// jak dotąd). To celowe: pozwala wydać aplikację i backend zanim
  /// klucze zostaną skonfigurowane.
  ///
  /// Jak włączyć:
  /// 1. dash.cloudflare.com → Turnstile → Add widget
  ///    - Domain: qasdasd554.github.io
  ///    - Widget mode: Managed (zalecane — najczęściej niewidoczne)
  /// 2. Skopiuj SITE KEY tutaj (nie jest tajny — widać go w każdej
  ///    stronie używającej Turnstile).
  /// 3. SECRET KEY wklej w Render → Environment → TURNSTILE_SECRET_KEY.
  ///    Ten jest tajny i nigdy nie może trafić do kodu aplikacji.
  ///
  /// WAŻNA KOLEJNOŚĆ: klucz tajny na Render ustaw DOPIERO wtedy, gdy nowa
  /// wersja aplikacji jest już w sklepach — starsze wersje nie wysyłają
  /// tokenu i zostałyby odcięte od logowania.
  static const String turnstileSiteKey = '';

  /// Strona hostująca widget (patrz docs/captcha.html). Musi leżeć na
  /// domenie dodanej w konfiguracji widgetu w Cloudflare.
  static const String turnstilePageUrl =
      'https://qasdasd554.github.io/mealplanner1108/captcha.html';

  // Endpointy
  static const String authLogin = '/auth/login';
  static const String authRegister = '/auth/register';
  static const String authGoogle = '/auth/google';
  static const String authApple = '/auth/apple';
  static const String authVerifyEmail = '/auth/verify-email';
  static const String authResendCode = '/auth/resend-code';
  static const String authForgotPassword = '/auth/forgot-password';
  static const String authResetPassword = '/auth/reset-password';
  static const String usersMe = '/users/me';
  static const String usersAllergens = '/users/me/allergens';
  static const String usersCalorieCalculator = '/users/me/calorie-calculator';
  static const String usersRecipeLeaderboard = '/users/leaderboard/recipes';
  static const String usersRecipeLeaderboardWeekly = '/users/leaderboard/recipes/weekly';
  static const String billingVerify = '/billing/verify-purchase';
  static const String billingRestore = '/billing/restore';
  static const String billingVerifyPoints = '/billing/verify-points-purchase';
  static const String stores = '/stores/';
  static const String products = '/products/';
  static const String recipes = '/recipes/';
  static const String pantry = '/pantry/';
  static const String recipesAvailable = '/recipes/available';
  static const String mealPlans = '/meal-plans/';
  static const String shoppingLists = '/shopping-lists/';
  static const String usersBlocked = '/users/me/blocked';
  static String userBlock(String userId) => '/users/$userId/block';
  static String recipeReport(String recipeId) => '/recipes/$recipeId/report';
  static String commentReport(String recipeId, String commentId) =>
      '/recipes/$recipeId/comments/$commentId/report';
}
