import 'dart:async';

import 'package:flutter/material.dart';

import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/api_client.dart';
import '../utils/error_utils.dart';
import '../l10n/app_localizations.dart';
import '../l10n/market_locale.dart';
import '../services/push_service.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService;
  final Future<String?> Function() _readToken;
  final Future<void> Function() _unregisterPush;
  final Future<void> Function(String countryCode) _registerPush;
  final ErrorStringsResolver? errorStrings;

  User? _currentUser;
  bool _isAuthenticated = false;
  bool _isInitialized = false;
  bool _isLoading = false;
  String? _errorMessage;
  Timer? _premiumExpiryTimer;
  late final Future<void> initialization;
  int _sessionGeneration = 0;
  bool _disposed = false;
  bool _explicitLogout = false;
  bool _logoutInProgress = false;
  ({int session, Future<void> future})? _profileLoad;
  int _profileRequestGeneration = 0;

  User? get currentUser => _currentUser;
  int get sessionGeneration => _sessionGeneration;
  bool get isAuthenticated => _isAuthenticated;
  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Apply only a verified backend response for the exact session that bought
  /// the product. A subsequent, optional profile GET may be offline or stale.
  bool applyVerifiedPoints({
    required String userId,
    required int session,
    required int balance,
  }) {
    if (_disposed ||
        _logoutInProgress ||
        session != _sessionGeneration ||
        _currentUser?.id != userId ||
        balance < 0)
      return false;
    _profileRequestGeneration++;
    _currentUser = _currentUser!.copyWith(premiumPoints: balance);
    notifyListeners();
    return true;
  }

  bool applyVerifiedSubscription({
    required String userId,
    required int session,
    required Map<String, dynamic> result,
  }) {
    if (_disposed ||
        _logoutInProgress ||
        session != _sessionGeneration ||
        _currentUser?.id != userId ||
        result['is_premium'] != true)
      return false;
    final rawExpiry = result['premium_expires_at'];
    final expiry = rawExpiry is String ? DateTime.tryParse(rawExpiry) : null;
    final product = result['premium_product_id'];
    if (expiry == null ||
        !expiry.isAfter(DateTime.now()) ||
        product is! String ||
        product.isEmpty)
      return false;
    _profileRequestGeneration++;
    _currentUser = _currentUser!.copyWith(
      isPremium: true,
      hasPremiumAccessFromServer: true,
      premiumExpiresAt: expiry,
      premiumProductId: product,
    );
    _schedulePremiumExpiryRefresh();
    notifyListeners();
    return true;
  }

  AppLocalizations? get _currentErrorStrings =>
      _currentUser != null
          ? stringsForAccountCountry(_currentUser!.countryCode)
          : errorStrings?.call();

  AuthProvider({
    AuthService? service,
    Future<String?> Function()? readToken,
    Future<void> Function()? unregisterPush,
    Future<void> Function(String countryCode)? registerPush,
    this.errorStrings,
  }) : _authService = service ?? AuthService(),
       _readToken = readToken ?? ApiClient().getToken,
       _unregisterPush = unregisterPush ?? PushService().unregister,
       _registerPush =
           registerPush ??
           ((country) => PushService().registerForUser(countryCode: country)) {
    initialization = _checkTokenOnInit();
  }

  Future<void> _checkTokenOnInit() async {
    final session = _sessionGeneration;
    try {
      final token = await _readToken();
      if (session != _sessionGeneration) return;
      if (token != null) {
        _isAuthenticated = true;
        notifyListeners();
        await loadProfile();

        // UWAGA (naprawa): jeśli loadProfile() zawiodło z powodu INNEGO
        // błędu niż wprost 401 (np. chwilowy problem sieciowy przy
        // "cold starcie" darmowego backendu Render po dłuższej
        // bezczynności) — _currentUser zostawał wtedy pusty NA ZAWSZE,
        // mimo że użytkownik i tak trafiał do aplikacji (bo
        // _isAuthenticated jest ustawiane na podstawie samego istnienia
        // tokenu, nie udanego wczytania profilu). Efekt: aplikacja
        // wyglądała, jakby zalogowała na konto "Użytkownik" (domyślna
        // wartość zastępcza dla pustego displayName). Jedna dodatkowa
        // próba po krótkim opóźnieniu w większości przypadków wystarcza,
        // żeby backend zdążył się obudzić.
        if (_currentUser == null && _isAuthenticated) {
          await Future.delayed(const Duration(seconds: 3));
          await loadProfile();
        }
      }

      // Jeśli nie mamy sesji (brak tokenu albo zapisany token wygasł i
      // loadProfile go wyczyścił), spróbuj po cichu wznowić sesję Google,
      // o ile użytkownik logował się nią wcześniej na tym urządzeniu.
      // Dodatkowe zabezpieczenie przed niechcianym wylogowaniem.
      if (!_isAuthenticated && !_explicitLogout) {
        final restored = await _authService.attemptGoogleSilentLogin();
        if (session != _sessionGeneration) return;
        if (restored) {
          _isAuthenticated = true;
          notifyListeners();
          await loadProfile();
        }
      }
    } catch (error) {
      if (session != _sessionGeneration) return;
      // A restored/temporarily unavailable Android Keystore must not leave
      // SplashScreen awaiting a failed initialization forever. Keep the
      // stored credentials intact; a storage read error is not a logout.
      _errorMessage =
          _currentErrorStrings?.authStoredSessionFailed ??
          'Nie udało się odtworzyć zapisanej sesji. Spróbuj zalogować się ponownie.';
      debugPrint('Session initialization failed (${error.runtimeType}).');
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<bool> login(
    String email,
    String password, {
    String? captchaToken,
  }) async {
    if (_isLoading || _logoutInProgress) return false;
    final session = ++_sessionGeneration;
    _setLoading(true);
    _clearError();
    try {
      await _authService.login(email, password, captchaToken: captchaToken);
      if (session != _sessionGeneration) return false;
      _explicitLogout = false;
      _isAuthenticated = true;
      notifyListeners();
      await loadProfile();
      if (session != _sessionGeneration) return false;
      _setLoading(false);
      return true;
    } catch (e) {
      if (session != _sessionGeneration) return false;
      // UWAGA (naprawa): friendlyError() dla kodu 401 domyślnie pokazuje
      // "Musisz być zalogowany, żeby to zrobić" — sensowne dla WYGASŁEJ
      // SESJI gdzieś indziej w aplikacji, ale kompletnie mylące akurat
      // na ekranie logowania, gdzie 401 oznacza konkretnie złe dane
      // logowania. Tutaj, w KONTEKŚCIE logowania, pokazujemy prawdziwą
      // wiadomość z backendu wprost ("Nieprawidłowy e-mail lub hasło"),
      // zamiast generycznego komunikatu — bez zmiany zachowania
      // friendlyError() dla pozostałych, poprawnych zastosowań w reszcie
      // aplikacji.
      if (e is ApiException && e.statusCode == 401) {
        _setErrorMessage(e.message);
      } else {
        _setErrorMessage(friendlyError(e, strings: _currentErrorStrings));
      }
      _setLoading(false);
      return false;
    }
  }

  /// Logowanie/rejestracja przez Google. Zwraca `true` po sukcesie, `false`
  /// jeśli użytkownik anulował okno logowania (bez pokazywania błędu).
  Future<bool> loginWithGoogle({String? captchaToken}) async {
    if (_isLoading || _logoutInProgress) return false;
    final session = ++_sessionGeneration;
    _setLoading(true);
    _clearError();
    try {
      final success = await _authService.loginWithGoogle(
        captchaToken: captchaToken,
      );
      if (session != _sessionGeneration) return false;
      if (!success) {
        _setLoading(false);
        return false;
      }
      _explicitLogout = false;
      _isAuthenticated = true;
      notifyListeners();
      await loadProfile();
      if (session != _sessionGeneration) return false;
      _setLoading(false);
      return true;
    } catch (e) {
      if (session != _sessionGeneration) return false;
      _setErrorMessage(
        e is ApiException && e.statusCode == 401
            ? e.message
            : friendlyError(e, strings: _currentErrorStrings),
      );
      _setLoading(false);
      return false;
    }
  }

  /// Logowanie/rejestracja przez "Sign in with Apple" (iOS). Zwraca
  /// `true` po sukcesie, `false` jeśli użytkownik anulował okno logowania.
  Future<bool> loginWithApple({String? captchaToken}) async {
    if (_isLoading || _logoutInProgress) return false;
    final session = ++_sessionGeneration;
    _setLoading(true);
    _clearError();
    try {
      final success = await _authService.loginWithApple(
        captchaToken: captchaToken,
      );
      if (session != _sessionGeneration) return false;
      if (!success) {
        _setLoading(false);
        return false;
      }
      _explicitLogout = false;
      _isAuthenticated = true;
      notifyListeners();
      await loadProfile();
      if (session != _sessionGeneration) return false;
      _setLoading(false);
      return true;
    } catch (e) {
      if (session != _sessionGeneration) return false;
      _setErrorMessage(
        e is ApiException && e.statusCode == 401
            ? e.message
            : friendlyError(e, strings: _currentErrorStrings),
      );
      _setLoading(false);
      return false;
    }
  }

  Future<bool> register(
    String email,
    String password,
    String displayName, {
    String? captchaToken,
  }) async {
    if (_isLoading || _logoutInProgress) return false;
    final session = ++_sessionGeneration;
    _setLoading(true);
    _clearError();
    try {
      await _authService.register(
        email,
        password,
        displayName,
        captchaToken: captchaToken,
      );
      if (session != _sessionGeneration) return false;
      _explicitLogout = false;
      _isAuthenticated = true;

      // Sesja jest już zapisana przez register() na podstawie tokenu
      // zwróconego przez serwer — NIE logujemy się drugi raz.
      // Poprzednie automatyczne logowanie wysyłało żądanie bez tokenu
      // CAPTCHA (jednorazowy, zużyty już przy rejestracji), więc przy
      // włączonej bramce zawsze kończyło się błędem.
      await loadProfile();
      if (session != _sessionGeneration) return false;
      _setLoading(false);
      return currentUser != null;
    } catch (e) {
      if (session != _sessionGeneration) return false;
      _setErrorMessage(friendlyError(e, strings: _currentErrorStrings));
      _setLoading(false);
      return false;
    }
  }

  /// Only lifecycle/background reads may share a pending snapshot. Mutations
  /// (purchases, verification, earned points) must request a fresh profile.
  Future<void> loadProfileInBackground() {
    if (_disposed || _logoutInProgress) return Future<void>.value();
    final session = _sessionGeneration;
    final running = _profileLoad;
    if (running != null && running.session == session) return running.future;
    return loadProfile();
  }

  Future<void> loadProfile() {
    if (_disposed || _logoutInProgress) return Future<void>.value();
    final session = _sessionGeneration;
    final request = ++_profileRequestGeneration;
    late final Future<void> pending;
    pending = _loadProfileForSession(session, request).whenComplete(() {
      if (identical(_profileLoad?.future, pending)) _profileLoad = null;
    });
    _profileLoad = (session: session, future: pending);
    return pending;
  }

  Future<void> _loadProfileForSession(int session, int request) async {
    bool isCurrent() =>
        session == _sessionGeneration && request == _profileRequestGeneration;
    try {
      final user = await _authService.getProfile();
      if (!isCurrent()) return;
      _currentUser = user;
      _schedulePremiumExpiryRefresh();
      notifyListeners();

      // Rejestracja urządzenia do powiadomień push. Robimy to TUTAJ, bo
      // loadProfile() jest wspólnym punktem dla wszystkich ścieżek
      // wejścia: logowania e-mailem, Google, Apple oraz wznowienia sesji
      // przy starcie aplikacji. Dopisywanie tego osobno w każdej z nich
      // byłoby czterokrotnym powtórzeniem i łatwo byłoby o którejś
      // zapomnieć. Nie czekamy na wynik — prośba o zgodę i zapis tokenu
      // nie mogą opóźniać wejścia do aplikacji.
      if (_currentUser != null && _currentUser!.isEmailVerified) {
        unawaited(_registerPush(user.countryCode));
      }
    } catch (e) {
      if (!isCurrent()) return;
      if (e is ApiException && e.statusCode == 401) {
        // UWAGA (naprawa — zgłoszone jednorazowe, niewyjaśnione
        // wylogowanie): wcześniej POJEDYNCZY błąd 401 z JAKIEGOKOLWIEK
        // powodu (nawet przejściowego — np. chwilowa niespójność przy
        // "cold starcie" darmowego backendu Render, krótki błąd sieci
        // zinterpretowany jako 401 zamiast prawdziwego kodu błędu)
        // natychmiast i bezwarunkowo wylogowywał użytkownika, bez
        // żadnej próby ponowienia — inaczej niż pozostałe błędy
        // (sieciowe/cold-start), które już MAJĄ ponowną próbę kilka
        // linii wyżej w _checkTokenOnInit. Token ma 30 dni ważności,
        // więc "zwykłe wygaśnięcie w trakcie sesji" jest mało
        // prawdopodobne — jeśli 401 pojawia się mimo to, rozsądniej
        // dać jedną, krótką szansę na ponowienie, zanim bezpowrotnie
        // skasujemy sesję użytkownika. Prawdziwie wygasły/nieprawidłowy
        // token i tak zawiedzie przy drugiej próbie — to nic nie
        // kosztuje w tym przypadku, a chroni przed niepotrzebnym
        // wylogowaniem przy czysto przejściowym problemie.
        await Future.delayed(const Duration(seconds: 2));
        if (!isCurrent()) return;
        try {
          final user = await _authService.getProfile();
          if (!isCurrent()) return;
          _currentUser = user;
          _schedulePremiumExpiryRefresh();
          notifyListeners();
          if (_currentUser != null && _currentUser!.isEmailVerified) {
            unawaited(_registerPush(user.countryCode));
          }
          return;
        } catch (retryError) {
          if (!isCurrent()) return;
          if (retryError is ApiException && retryError.statusCode == 401) {
            await logout();
          }
          // Inny błąd przy ponowieniu (np. dalej sieciowy) — zostawiamy
          // sesję nietkniętą, tak samo jak dla błędów niebędących 401.
        }
      }
    }
  }

  void _schedulePremiumExpiryRefresh() {
    _premiumExpiryTimer?.cancel();
    final expiresAt = _currentUser?.premiumExpiresAt;
    if (expiresAt == null) return;

    final remaining = expiresAt.difference(DateTime.now());
    if (remaining <= Duration.zero) {
      // Getter hasPremiumAccess już zwróci false; wymuszamy przebudowę,
      // a profil odświeży się przy najbliższym starcie/wznowieniu.
      notifyListeners();
      return;
    }

    _premiumExpiryTimer = Timer(remaining + const Duration(seconds: 1), () {
      notifyListeners();
      if (_isAuthenticated) {
        unawaited(loadProfile());
      }
    });
  }

  /// Potwierdza kod weryfikacyjny e-mail. Zwraca true przy sukcesie —
  /// odświeża przy okazji profil, żeby currentUser.isEmailVerified było
  /// aktualne od razu, bez osobnego wywołania loadProfile().
  Future<bool> verifyEmail(String code) async {
    final session = _sessionGeneration;
    _clearError();
    try {
      await _authService.verifyEmail(code);
      if (session != _sessionGeneration) return false;
      await loadProfile();
      return session == _sessionGeneration;
    } catch (e) {
      if (session != _sessionGeneration) return false;
      _setErrorMessage(friendlyError(e, strings: _currentErrorStrings));
      return false;
    }
  }

  Future<bool> resendVerificationCode() async {
    final session = _sessionGeneration;
    _clearError();
    try {
      await _authService.resendVerificationCode();
      return session == _sessionGeneration;
    } catch (e) {
      if (session != _sessionGeneration) return false;
      _setErrorMessage(friendlyError(e, strings: _currentErrorStrings));
      return false;
    }
  }

  Future<bool> forgotPassword(String email) async {
    final session = _sessionGeneration;
    _clearError();
    try {
      await _authService.forgotPassword(email);
      return session == _sessionGeneration;
    } catch (e) {
      if (session != _sessionGeneration) return false;
      _setErrorMessage(friendlyError(e, strings: _currentErrorStrings));
      return false;
    }
  }

  Future<bool> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    final session = _sessionGeneration;
    _clearError();
    try {
      await _authService.resetPassword(
        email: email,
        code: code,
        newPassword: newPassword,
      );
      return session == _sessionGeneration;
    } catch (e) {
      if (session != _sessionGeneration) return false;
      _setErrorMessage(friendlyError(e, strings: _currentErrorStrings));
      return false;
    }
  }

  Future<bool> updateProfile({
    String? displayName,
    String? tiktokUsername,
    String? preferredStoreId,
    Map<String, dynamic>? dietaryPreferences,
    int? householdSize,
    double? weightKg,
    double? heightCm,
    int? age,
    String? gender,
    String? activityLevel,
    int? dailyKcalGoal,
    String? avatar,
    String? avatarPhotoBase64,
  }) async {
    final session = _sessionGeneration;
    _clearError();
    try {
      final updatedUser = await _authService.updateProfile(
        displayName: displayName,
        tiktokUsername: tiktokUsername,
        preferredStoreId: preferredStoreId,
        dietaryPreferences: dietaryPreferences,
        householdSize: householdSize,
        weightKg: weightKg,
        heightCm: heightCm,
        age: age,
        gender: gender,
        activityLevel: activityLevel,
        dailyKcalGoal: dailyKcalGoal,
        avatar: avatar,
        avatarPhotoBase64: avatarPhotoBase64,
      );
      if (session != _sessionGeneration) return false;
      _currentUser = updatedUser;
      notifyListeners();
      return true;
    } catch (e) {
      if (session != _sessionGeneration) return false;
      _setErrorMessage(friendlyError(e, strings: _currentErrorStrings));
      return false;
    }
  }

  /// Liczba punktów przyznanych przy ostatnim ukończeniu onboardingu.
  /// 0 oznacza, że konto już wcześniej odebrało bonus.
  int _lastBonusPoints = 0;
  int get lastBonusPoints => _lastBonusPoints;

  Future<bool> saveOnboardingPreferences({
    required String storeId,
    required List<String> allergenIds,
    required String diet,
    required int householdSize,
    double? weightKg,
    double? heightCm,
    int? dailyKcalGoal,
  }) async {
    if (_isLoading || _logoutInProgress || _disposed) return false;
    final session = _sessionGeneration;
    final submittedAllergens = List<String>.of(allergenIds);
    _lastBonusPoints = 0;
    _clearError();
    _setLoading(true);
    try {
      // preferredStoreId is also the existing onboarding-complete marker.
      // Save allergens first so a failed required step cannot prematurely
      // send a returning user past onboarding on the next app launch.
      await _authService.updateAllergens(submittedAllergens);
      if (session != _sessionGeneration) return false;
      final profileSaved = await updateProfile(
        preferredStoreId: storeId,
        dietaryPreferences: {'diet': diet},
        householdSize: householdSize,
        weightKg: weightKg,
        heightCm: heightCm,
        dailyKcalGoal: dailyKcalGoal,
      );
      if (!profileSaved || session != _sessionGeneration) return false;

      // Punkty powitalne. Wywołujemy bezwarunkowo — serwer sam pilnuje,
      // żeby przyznać je tylko raz, więc powtórne przejście onboardingu
      // niczego nie dosypie (patrz claim_onboarding_bonus w backendzie).
      try {
        final awarded = await _authService.claimOnboardingBonus(
          onTotalPoints: (balance) {
            if (session != _sessionGeneration || _currentUser == null) return;
            // The POST already committed this authoritative balance. Do not
            // hide awarded points if the optional follow-up GET is offline.
            _profileRequestGeneration++;
            _currentUser = _currentUser!.copyWith(premiumPoints: balance);
            notifyListeners();
          },
        );
        if (session != _sessionGeneration) return false;
        _lastBonusPoints = awarded;
      } catch (_) {
        if (session != _sessionGeneration) return false;
        // Bonus to dodatek — jego niepowodzenie NIE może przerwać
        // onboardingu ani zablokować wejścia do aplikacji.
        _lastBonusPoints = 0;
      }

      await loadProfile();
      return session == _sessionGeneration;
    } catch (e) {
      if (session == _sessionGeneration)
        _setErrorMessage(friendlyError(e, strings: _currentErrorStrings));
      return false;
    } finally {
      if (session == _sessionGeneration) _setLoading(false);
    }
  }

  /// Dokąd skierować użytkownika po udanym zalogowaniu.
  ///
  /// NAPRAWA: ekran onboardingu był osiągalny WYŁĄCZNIE z ekranu
  /// weryfikacji e-maila. Logowanie przez Google i Apple ustawia adres
  /// jako zweryfikowany i szło prosto na /home, więc te konta NIGDY nie
  /// przechodziły przez wybór sklepu, diety i alergenów — aplikacja
  /// startowała bez podstawowych ustawień.
  ///
  /// Za wyznacznik ukończenia onboardingu bierzemy wybrany sklep: to
  /// pierwsze i obowiązkowe pytanie w tym procesie, więc jego brak
  /// jednoznacznie oznacza, że użytkownik go nie przeszedł.
  String get postLoginRoute {
    if (_currentUser == null) return '/login';
    if (!_currentUser!.isEmailVerified) return '/verify-email';
    if (_currentUser!.preferredStoreId == null) return '/onboarding';
    return '/home';
  }

  Future<void> logout() async {
    if (_logoutInProgress) return;
    _logoutInProgress = true;
    _authService.invalidateSession();
    _sessionGeneration++;
    _explicitLogout = true;
    _currentUser = null;
    _lastBonusPoints = 0;
    _premiumExpiryTimer?.cancel();
    _isAuthenticated = false;
    _isLoading = false;
    notifyListeners();
    // Wyrejestruj urządzenie ZANIM stracimy token sesji — po wylogowaniu
    // żądanie do backendu nie przeszłoby autoryzacji.
    try {
      await _unregisterPush();
    } catch (_) {
      // Optional push cleanup must never prevent local token removal.
    }
    try {
      await _authService.logout();
    } finally {
      _currentUser = null;
      _premiumExpiryTimer?.cancel();
      _isAuthenticated = false;
      _logoutInProgress = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _sessionGeneration++;
    _disposed = true;
    _premiumExpiryTimer?.cancel();
    super.dispose();
  }

  /// Trwale usuwa konto. Po sukcesie czyści lokalną sesję dokładnie tak
  /// jak logout(), więc ekran logowania pojawia się natychmiast — nie ma
  /// już żadnego tokenu ani profilu, do których dałoby się wrócić.
  Future<bool> deleteAccount() async {
    if (_isLoading || _logoutInProgress) return false;
    var operationSession = _sessionGeneration;
    _setLoading(true);
    _clearError();
    try {
      await _unregisterPush();
      if (operationSession != _sessionGeneration) return false;
      await _authService.deleteAccount();
      if (operationSession != _sessionGeneration) return false;
      _authService.invalidateSession();
      operationSession = ++_sessionGeneration;
      _explicitLogout = true;
      await _authService.logout();
      if (operationSession != _sessionGeneration) return false;
      _currentUser = null;
      _premiumExpiryTimer?.cancel();
      _isAuthenticated = false;
      notifyListeners();
      return true;
    } catch (e) {
      if (operationSession != _sessionGeneration) return false;
      _setErrorMessage(friendlyError(e, strings: _currentErrorStrings));
      return false;
    } finally {
      if (operationSession == _sessionGeneration) _setLoading(false);
    }
  }

  Future<bool> blockUser(String userId) async {
    final session = _sessionGeneration;
    _clearError();
    try {
      await _authService.blockUser(userId);
      return session == _sessionGeneration;
    } catch (e) {
      if (session != _sessionGeneration) return false;
      _setErrorMessage(friendlyError(e, strings: _currentErrorStrings));
      return false;
    }
  }

  Future<bool> unblockUser(String userId) async {
    final session = _sessionGeneration;
    _clearError();
    try {
      await _authService.unblockUser(userId);
      return session == _sessionGeneration;
    } catch (e) {
      if (session != _sessionGeneration) return false;
      _setErrorMessage(friendlyError(e, strings: _currentErrorStrings));
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getBlockedUsers() {
    return _authService.getBlockedUsers();
  }

  Future<bool> reportRecipe(
    String recipeId, {
    required String reason,
    String? details,
  }) async {
    final session = _sessionGeneration;
    _clearError();
    try {
      await _authService.reportRecipe(
        recipeId,
        reason: reason,
        details: details,
      );
      return session == _sessionGeneration;
    } catch (e) {
      if (session != _sessionGeneration) return false;
      _setErrorMessage(friendlyError(e, strings: _currentErrorStrings));
      return false;
    }
  }

  Future<bool> reportComment(
    String recipeId,
    String commentId, {
    required String reason,
    String? details,
  }) async {
    final session = _sessionGeneration;
    _clearError();
    try {
      await _authService.reportComment(
        recipeId,
        commentId,
        reason: reason,
        details: details,
      );
      return session == _sessionGeneration;
    } catch (e) {
      if (session != _sessionGeneration) return false;
      _setErrorMessage(friendlyError(e, strings: _currentErrorStrings));
      return false;
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  void _setErrorMessage(String msg) {
    _errorMessage = msg;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
