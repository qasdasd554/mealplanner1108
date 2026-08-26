import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/api_client.dart';
import '../utils/error_utils.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  final ApiClient _apiClient = ApiClient();

  User? _currentUser;
  bool _isAuthenticated = false;
  bool _isInitialized = false;
  bool _isLoading = false;
  String? _errorMessage;

  User? get currentUser => _currentUser;
  bool get isAuthenticated => _isAuthenticated;
  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  AuthProvider() {
    _checkTokenOnInit();
  }

  Future<void> _checkTokenOnInit() async {
    try {
      final token = await _apiClient.getToken();
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
      if (!_isAuthenticated) {
        final restored = await _authService.attemptGoogleSilentLogin();
        if (restored) {
          _isAuthenticated = true;
          notifyListeners();
          await loadProfile();
        }
      }
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<bool> login(String email, String password) async {
    _setLoading(true);
    _clearError();
    try {
      await _authService.login(email, password);
      _isAuthenticated = true;
      notifyListeners();
      await loadProfile();
      _setLoading(false);
      return true;
    } catch (e) {
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
        _setErrorMessage(friendlyError(e));
      }
      _setLoading(false);
      return false;
    }
  }

  /// Logowanie/rejestracja przez Google. Zwraca `true` po sukcesie, `false`
  /// jeśli użytkownik anulował okno logowania (bez pokazywania błędu).
  Future<bool> loginWithGoogle() async {
    _setLoading(true);
    _clearError();
    try {
      final success = await _authService.loginWithGoogle();
      if (!success) {
        _setLoading(false);
        return false;
      }
      _isAuthenticated = true;
      notifyListeners();
      await loadProfile();
      _setLoading(false);
      return true;
    } catch (e) {
      _setErrorMessage(friendlyError(e));
      _setLoading(false);
      return false;
    }
  }

  Future<bool> register(String email, String password, String displayName) async {
    _setLoading(true);
    _clearError();
    try {
      await _authService.register(email, password, displayName);
      // Auto login po rejestracji
      final success = await login(email, password);
      _setLoading(false);
      return success;
    } catch (e) {
      _setErrorMessage(friendlyError(e));
      _setLoading(false);
      return false;
    }
  }

  Future<void> loadProfile() async {
    try {
      _currentUser = await _authService.getProfile();
      notifyListeners();
    } catch (e) {
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
        try {
          _currentUser = await _authService.getProfile();
          notifyListeners();
          return;
        } catch (retryError) {
          if (retryError is ApiException && retryError.statusCode == 401) {
            await logout();
          }
          // Inny błąd przy ponowieniu (np. dalej sieciowy) — zostawiamy
          // sesję nietkniętą, tak samo jak dla błędów niebędących 401.
        }
      }
    }
  }

  /// Potwierdza kod weryfikacyjny e-mail. Zwraca true przy sukcesie —
  /// odświeża przy okazji profil, żeby currentUser.isEmailVerified było
  /// aktualne od razu, bez osobnego wywołania loadProfile().
  Future<bool> verifyEmail(String code) async {
    _clearError();
    try {
      await _authService.verifyEmail(code);
      await loadProfile();
      return true;
    } catch (e) {
      _setErrorMessage(friendlyError(e));
      return false;
    }
  }

  Future<bool> resendVerificationCode() async {
    _clearError();
    try {
      await _authService.resendVerificationCode();
      return true;
    } catch (e) {
      _setErrorMessage(friendlyError(e));
      return false;
    }
  }

  Future<bool> forgotPassword(String email) async {
    _clearError();
    try {
      await _authService.forgotPassword(email);
      return true;
    } catch (e) {
      _setErrorMessage(friendlyError(e));
      return false;
    }
  }

  Future<bool> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    _clearError();
    try {
      await _authService.resetPassword(email: email, code: code, newPassword: newPassword);
      return true;
    } catch (e) {
      _setErrorMessage(friendlyError(e));
      return false;
    }
  }

  Future<bool> updateProfile({
    String? displayName,
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
  }) async {
    _clearError();
    try {
      final updatedUser = await _authService.updateProfile(
        displayName: displayName,
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
      );
      _currentUser = updatedUser;
      notifyListeners();
      return true;
    } catch (e) {
      _setErrorMessage(friendlyError(e));
      return false;
    }
  }

  Future<bool> saveOnboardingPreferences({
    required String storeId,
    required List<String> allergenIds,
    required String diet,
    required int householdSize,
  }) async {
    _setLoading(true);
    try {
      // 1. Zapisz profil (sklep, dieta, household)
      await updateProfile(
        preferredStoreId: storeId,
        dietaryPreferences: {'diet': diet},
        householdSize: householdSize,
      );
      // 2. Zapisz alergeny
      await _authService.updateAllergens(allergenIds);
      await loadProfile();
      _setLoading(false);
      return true;
    } catch (e) {
      _setErrorMessage(friendlyError(e));
      _setLoading(false);
      return false;
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    _currentUser = null;
    _isAuthenticated = false;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
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
