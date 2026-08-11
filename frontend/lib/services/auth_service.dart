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

  Future<User> updateProfile({
    String? displayName,
    String? preferredStoreId,
    Map<String, dynamic>? dietaryPreferences,
    int? householdSize,
  }) async {
    final body = <String, dynamic>{};
    if (displayName != null) body['display_name'] = displayName;
    if (preferredStoreId != null) body['preferred_store_id'] = preferredStoreId;
    if (dietaryPreferences != null) body['dietary_preferences'] = dietaryPreferences;
    if (householdSize != null) body['household_size'] = householdSize;

    final response = await _client.put(ApiConfig.usersMe, body: body);
    return User.fromJson(response as Map<String, dynamic>);
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
