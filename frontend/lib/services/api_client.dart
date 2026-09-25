import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/api_config.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException(this.statusCode, this.message);

  @override
  String toString() => 'ApiException: [$statusCode] $message';
}

class ApiClient {
  /// Maksymalny czas oczekiwania na odpowiedź serwera.
  ///
  /// NAPRAWA REALNEGO BŁĘDU: żądania nie miały ŻADNEGO limitu czasu.
  /// Gdy backend na darmowym planie Render budzi się z uśpienia albo
  /// połączenie zawiesi się bez zerwania, żądanie wisiało w
  /// nieskończoność — razem z nim kręcił się przycisk, którego nie dało
  /// się już nacisnąć ponownie. Użytkownik musiał ubić aplikację.
  ///
  /// 45 sekund, a nie mniej, bo zimny start Rendera potrafi zająć ~30 s
  /// i krótszy limit przerywałby poprawne żądania.
  static const Duration _timeout = Duration(seconds: 45);

  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  // Jeden klient utrzymuje pulę połączeń przez całą sesję aplikacji.
  // Wywołania statyczne http.get/post tworzyły nowy Client dla każdego
  // żądania i wymuszały ponowne zestawianie połączenia.
  final http.Client _httpClient = http.Client();

  String? _token;

  // Token JWT trzymany w zaszyfrowanym magazynie systemowym (Android
  // Keystore / iOS Keychain), NIE w SharedPreferences — to zwykły,
  // niezaszyfrowany plik na dysku, czytelny dla każdego z dostępem do
  // pamięci urządzenia (np. na zrootowanym telefonie albo z kopii
  // zapasowej aplikacji).
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _tokenKey = 'auth_token';
  static const _refreshTokenKey = 'auth_refresh_token';
  // Stary klucz w SharedPreferences — używany tylko do jednorazowego
  // przeniesienia tokenu istniejących, już zalogowanych użytkowników do
  // nowego, bezpiecznego magazynu, żeby nikogo nie wylogować przy
  // aktualizacji aplikacji.
  static const _legacyPrefsKey = 'auth_token';

  Future<String?> getToken() async {
    if (_token != null) return _token;

    _token = await _secureStorage.read(key: _tokenKey);
    if (_token != null) return _token;

    // Migracja jednorazowa: jeśli token istnieje w starym,
    // niezaszyfrowanym miejscu (z wersji aplikacji sprzed tej poprawki),
    // przenieś go do bezpiecznego magazynu i usuń stamtąd.
    final prefs = await SharedPreferences.getInstance();
    final legacyToken = prefs.getString(_legacyPrefsKey);
    if (legacyToken != null) {
      _token = legacyToken;
      await _secureStorage.write(key: _tokenKey, value: legacyToken);
      await prefs.remove(_legacyPrefsKey);
    }
    return _token;
  }

  Future<void> setToken(String token) async {
    _token = token;
    await _secureStorage.write(key: _tokenKey, value: token);
  }

  Future<void> setSession(String accessToken, String? refreshToken) async {
    await setToken(accessToken);
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await _secureStorage.write(key: _refreshTokenKey, value: refreshToken);
    }
  }

  Future<bool> hasRefreshToken() async {
    final token = await _secureStorage.read(key: _refreshTokenKey);
    return token != null && token.isNotEmpty;
  }

  Future<void> clearToken() async {
    _token = null;
    await _secureStorage.delete(key: _tokenKey);
    await _secureStorage.delete(key: _refreshTokenKey);
    // Sprzątamy też ewentualną starą, niezaszyfrowaną kopię.
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_legacyPrefsKey);
  }

  bool _canRefresh(String path) =>
      !{
        ApiConfig.authLogin,
        ApiConfig.authRegister,
        ApiConfig.authGoogle,
        ApiConfig.authApple,
        ApiConfig.authRefresh,
        ApiConfig.authSession,
      }.contains(path);

  Future<bool> _refreshSession() async {
    final refreshToken = await _secureStorage.read(key: _refreshTokenKey);
    if (refreshToken == null || refreshToken.isEmpty) return false;
    try {
      final response = await _httpClient
          .post(
            Uri.parse('${ApiConfig.apiUrl}${ApiConfig.authRefresh}'),
            headers: _headers(null),
            body: jsonEncode({'refresh_token': refreshToken}),
          )
          .timeout(_timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) return false;
      final decoded = jsonDecode(response.body);
      if (decoded is! Map || decoded['access_token'] is! String) return false;
      await setSession(
        decoded['access_token'] as String,
        decoded['refresh_token'] as String?,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<http.Response> _sendWithRefresh(
    String path,
    Future<http.Response> Function(Map<String, String> headers) send,
  ) async {
    var response = await send(_headers(await getToken()));
    if (response.statusCode == 401 &&
        _canRefresh(path) &&
        await _refreshSession()) {
      response = await send(_headers(await getToken()));
    }
    return response;
  }

  Map<String, String> _headers(String? token) {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      // Wysyłane przy KAŻDYM żądaniu — backend (app/api/deps.py) zapisuje
      // to przepustowanie z last_active_at, bez dodatkowego zapisu do
      // bazy poza istniejącym mechanizmem throttlingu. Wyłącznie nazwa
      // systemu operacyjnego, NIE identyfikator urządzenia.
      'X-Platform': Platform.isIOS ? 'ios' : 'android',
    };
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<dynamic> get(String path, {Duration? timeout}) async {
    final url = Uri.parse('${ApiConfig.apiUrl}$path');

    try {
      final response = await _sendWithRefresh(
        path,
        (headers) =>
            _httpClient.get(url, headers: headers).timeout(timeout ?? _timeout),
      );
      return _handleResponse(response);
    } catch (e) {
      _handleError(e);
    }
  }

  Future<dynamic> post(String path, {dynamic body, Duration? timeout}) async {
    final url = Uri.parse('${ApiConfig.apiUrl}$path');

    try {
      final response = await _sendWithRefresh(
        path,
        (headers) => _httpClient
            .post(
              url,
              headers: headers,
              body: body != null ? jsonEncode(body) : null,
            )
            .timeout(timeout ?? _timeout),
      );
      return _handleResponse(response);
    } catch (e) {
      _handleError(e);
    }
  }

  Future<dynamic> put(String path, {dynamic body}) async {
    final url = Uri.parse('${ApiConfig.apiUrl}$path');

    try {
      final response = await _sendWithRefresh(
        path,
        (headers) => _httpClient
            .put(
              url,
              headers: headers,
              body: body != null ? jsonEncode(body) : null,
            )
            .timeout(_timeout),
      );
      return _handleResponse(response);
    } catch (e) {
      _handleError(e);
    }
  }

  Future<dynamic> patch(String path, {dynamic body}) async {
    final url = Uri.parse('${ApiConfig.apiUrl}$path');

    try {
      final response = await _sendWithRefresh(
        path,
        (headers) => _httpClient
            .patch(
              url,
              headers: headers,
              body: body != null ? jsonEncode(body) : null,
            )
            .timeout(_timeout),
      );
      return _handleResponse(response);
    } catch (e) {
      _handleError(e);
    }
  }

  Future<dynamic> delete(String path) async {
    final url = Uri.parse('${ApiConfig.apiUrl}$path');

    try {
      final response = await _sendWithRefresh(
        path,
        (headers) =>
            _httpClient.delete(url, headers: headers).timeout(_timeout),
      );
      return _handleResponse(response);
    } catch (e) {
      _handleError(e);
    }
  }

  dynamic _handleResponse(http.Response response) {
    final body = response.body;
    dynamic decoded;
    try {
      decoded = jsonDecode(body);
    } catch (_) {
      decoded = body;
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    } else {
      String errMsg = 'Wystąpił nieoczekiwany błąd';
      if (decoded is Map && decoded.containsKey('detail')) {
        final detail = decoded['detail'];
        if (detail is String) {
          errMsg = detail;
        } else if (detail is List) {
          // Błędy walidacji Pydantic
          errMsg = detail.map((e) => e['msg'] ?? '').join(',');
        }
      }
      throw ApiException(response.statusCode, errMsg);
    }
  }

  void _handleError(dynamic error) {
    if (error is ApiException) {
      throw error;
    } else if (error is TimeoutException) {
      // Osobny komunikat dla przekroczenia czasu — "brak połączenia"
      // byłoby mylące, gdy sieć działa, a to serwer się nie wyrabia
      // (typowo: budzenie uśpionej instancji na darmowym planie Render).
      throw ApiException(
        504,
        'Serwer nie odpowiedział na czas. Spróbuj ponownie za chwilę.',
      );
    } else if (error is SocketException) {
      throw ApiException(
        503,
        'Brak połączenia z serwerem. Sprawdź swoje połączenie internetowe.',
      );
    } else {
      throw ApiException(500, 'Błąd połączenia sieciowego: $error');
    }
  }
}
