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
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

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

  Future<void> clearToken() async {
    _token = null;
    await _secureStorage.delete(key: _tokenKey);
    // Sprzątamy też ewentualną starą, niezaszyfrowaną kopię.
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_legacyPrefsKey);
  }

  Map<String, String> _headers(String? token) {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<dynamic> get(String path) async {
    final token = await getToken();
    final url = Uri.parse('${ApiConfig.apiUrl}$path');
    
    try {
      final response = await http.get(url, headers: _headers(token));
      return _handleResponse(response);
    } catch (e) {
      _handleError(e);
    }
  }

  Future<dynamic> post(String path, {dynamic body}) async {
    final token = await getToken();
    final url = Uri.parse('${ApiConfig.apiUrl}$path');

    try {
      final response = await http.post(
        url,
        headers: _headers(token),
        body: body != null ? jsonEncode(body) : null,
      );
      return _handleResponse(response);
    } catch (e) {
      _handleError(e);
    }
  }

  Future<dynamic> put(String path, {dynamic body}) async {
    final token = await getToken();
    final url = Uri.parse('${ApiConfig.apiUrl}$path');
    
    try {
      final response = await http.put(
        url,
        headers: _headers(token),
        body: body != null ? jsonEncode(body) : null,
      );
      return _handleResponse(response);
    } catch (e) {
      _handleError(e);
    }
  }

  Future<dynamic> delete(String path) async {
    final token = await getToken();
    final url = Uri.parse('${ApiConfig.apiUrl}$path');
    
    try {
      final response = await http.delete(url, headers: _headers(token));
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
    } else if (error is SocketException) {
      throw ApiException(503, 'Brak połączenia z serwerem. Sprawdź swoje połączenie internetowe.');
    } else {
      throw ApiException(500, 'Błąd połączenia sieciowego: $error');
    }
  }
}
