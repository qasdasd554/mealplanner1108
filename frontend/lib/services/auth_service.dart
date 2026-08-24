import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../models/user.dart';
import 'api_client.dart';
import '../config/api_config.dart';

class AuthService {
  final ApiClient _client = ApiClient();
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  bool _googleInitialized = false;

  Future<void> _ensureGoogleInitialized() async {
    if (_googleInitialized) return;
    await _googleSignIn.initialize(serverClientId: ApiConfig.googleWebClientId);
    _googleInitialized = true;
  }

  Future<AuthToken> login(String email, String password) async {
    final response = await _client.post(
      ApiConfig.authLogin,
      // WAŻNE: backend (app/api/v1/auth.py) parsuje ciało żądania jako JSON
      // i szuka klucza "email" — wcześniej wysyłaliśmy "username" jako
      // x-www-form-urlencoded, co zawsze kończyło się błędem 400.
      body: {
        'email': email,
        'password': password,
      },
    );
    final token = AuthToken.fromJson(response as Map<String, dynamic>);
    await _client.setToken(token.accessToken);
    return token;
  }

  Future<void> register(String email, String password, String displayName) async {
    // Odpowiedź /auth/register zawiera tylko access_token — pełny profil
    // użytkownika (wymagany przez User.fromJson, m.in. created_at) pobiera
    // się osobno przez /users/me po zalogowaniu (patrz AuthProvider.register).
    await _client.post(
      ApiConfig.authRegister,
      body: {
        'email': email,
        'password': password,
        'display_name': displayName,
      },
    );
  }

  /// Loguje przez natywny Google Sign-In (Credential Manager na Androidzie).
  /// Nie korzysta z przeglądarki ani redirect_uri, więc nie powoduje błędu
  /// "invalid_request" — ten błąd był spowodowany próbą użycia przeglądarkowego
  /// flow OAuth z niestandardowym adresem powrotnym.
  ///
  /// Zwraca `true` po udanym zalogowaniu, `false` jeśli użytkownik po prostu
  /// anulował okno logowania (nie jest to błąd).
  Future<bool> loginWithGoogle() async {
    await _ensureGoogleInitialized();

    late final GoogleSignInAccount googleUser;
    try {
      googleUser = await _googleSignIn.authenticate();
    } on GoogleSignInException catch (e) {
      // UWAGA (diagnostyka): biblioteka google_sign_in na Androidzie ma
      // znaną usterkę — prawdziwy błąd konfiguracji (np. niezgodność
      // SHA-1/identyfikatora klienta, kod natywny "DEVELOPER_ERROR")
      // bywa czasem błędnie zgłaszany jako zwykłe "canceled", nawet gdy
      // użytkownik FAKTYCZNIE wybrał konto, a nie kliknął "anuluj". Bez
      // tego logu taki przypadek wyglądał identycznie jak świadome
      // anulowanie — nie dało się ich odróżnić. `debugPrint` trafia do
      // `flutter logs`/`adb logcat`, więc widać PRAWDZIWY kod błędu
      // nawet wtedy, gdy interfejs aplikacji celowo nic nie pokazuje.
      debugPrint(
        '[Google Sign-In] Wyjątek: code=${e.code.name}, description=${e.description}, details=${e.details}',
      );
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return false;
      }
      throw ApiException(
        401,
        'Nie udało się zalogować przez Google (${e.code.name}). Spróbuj ponownie.',
      );
    }

    final idToken = googleUser.authentication.idToken;
    if (idToken == null) {
      throw ApiException(401, 'Nie udało się uzyskać tokenu tożsamości Google.');
    }

    final response = await _client.post(
      ApiConfig.authGoogle,
      body: {'id_token': idToken},
    );
    final token = AuthToken.fromJson(response as Map<String, dynamic>);
    await _client.setToken(token.accessToken);
    return true;
  }

  /// Próbuje po cichu wznowić wcześniejszą sesję Google (bez pokazywania
  /// żadnego okna) — używane przy starcie aplikacji jako dodatkowe
  /// zabezpieczenie przed niechcianym wylogowaniem, na wypadek gdyby lokalny
  /// token aplikacji zniknął, ale urządzenie wciąż ma zapisaną sesję Google.
  Future<bool> attemptGoogleSilentLogin() async {
    try {
      await _ensureGoogleInitialized();
      final future = _googleSignIn.attemptLightweightAuthentication();
      final googleUser = future == null ? null : await future;
      if (googleUser == null) return false;

      final idToken = googleUser.authentication.idToken;
      if (idToken == null) return false;

      final response = await _client.post(
        ApiConfig.authGoogle,
        body: {'id_token': idToken},
      );
      final token = AuthToken.fromJson(response as Map<String, dynamic>);
      await _client.setToken(token.accessToken);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<User> getProfile() async {
    final response = await _client.get(ApiConfig.usersMe);
    return User.fromJson(response as Map<String, dynamic>);
  }

  /// Potwierdza adres e-mail kodem wysłanym przy rejestracji. Rzuca
  /// ApiException (400), jeśli kod jest nieprawidłowy albo wygasł.
  Future<void> verifyEmail(String code) async {
    await _client.post(ApiConfig.authVerifyEmail, body: {'code': code});
  }

  /// Prosi o wysłanie NOWEGO kodu weryfikacyjnego (limit 3x/10 minut po
  /// stronie backendu).
  Future<void> resendVerificationCode() async {
    await _client.post(ApiConfig.authResendCode);
  }

  /// Prosi o wysłanie kodu resetu hasła — działa BEZ logowania.
  Future<void> forgotPassword(String email) async {
    await _client.post(ApiConfig.authForgotPassword, body: {'email': email});
  }

  /// Ustawia nowe hasło na podstawie kodu z forgotPassword — też bez
  /// logowania.
  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    await _client.post(ApiConfig.authResetPassword, body: {
      'email': email,
      'code': code,
      'new_password': newPassword,
    });
  }

  Future<User> updateProfile({
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
    final body = <String, dynamic>{};
    if (displayName != null) body['display_name'] = displayName;
    if (preferredStoreId != null) body['preferred_store_id'] = preferredStoreId;
    if (dietaryPreferences != null) body['dietary_preferences'] = dietaryPreferences;
    if (householdSize != null) body['household_size'] = householdSize;
    if (weightKg != null) body['weight_kg'] = weightKg;
    if (heightCm != null) body['height_cm'] = heightCm;
    if (age != null) body['age'] = age;
    if (gender != null) body['gender'] = gender;
    if (activityLevel != null) body['activity_level'] = activityLevel;
    if (dailyKcalGoal != null) body['daily_kcal_goal'] = dailyKcalGoal;
    if (avatar != null) body['avatar'] = avatar;

    final response = await _client.put(ApiConfig.usersMe, body: body);
    return User.fromJson(response as Map<String, dynamic>);
  }

  /// Liczy zapotrzebowanie kaloryczne (wzór Mifflin-St Jeor) — zwraca
  /// {maintenance, weight_loss, weight_gain}. Czysta funkcja, nic nie
  /// zapisuje — do tego służy osobne wywołanie updateProfile.
  Future<Map<String, int>> calculateCalorieNeeds({
    required double weightKg,
    required double heightCm,
    required int age,
    required String gender,
    required String activityLevel,
  }) async {
    final response = await _client.post(ApiConfig.usersCalorieCalculator, body: {
      'weight_kg': weightKg,
      'height_cm': heightCm,
      'age': age,
      'gender': gender,
      'activity_level': activityLevel,
    });
    final data = response as Map<String, dynamic>;
    return data.map((k, v) => MapEntry(k, v as int));
  }

  /// Ranking użytkowników wg liczby dodanych, zaakceptowanych przepisów
  /// do wspólnego katalogu.
  Future<List<Map<String, dynamic>>> getRecipeLeaderboard() async {
    final response = await _client.get(ApiConfig.usersRecipeLeaderboard);
    return (response as List).cast<Map<String, dynamic>>();
  }

  Future<void> updateAllergens(List<String> allergenIds) async {
    await _client.put(ApiConfig.usersAllergens, body: {'allergen_ids': allergenIds});
  }

  Future<void> logout() async {
    await _client.clearToken();
    try {
      if (_googleInitialized) {
        await _googleSignIn.signOut();
      }
    } catch (_) {
      // Nieistotne — najważniejsze jest wyczyszczenie lokalnej sesji aplikacji.
    }
  }
}
