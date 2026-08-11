import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
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

  Future<String?> getToken() async {
    if (_token != null) return _token;
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
    return _token;
  }

  Future<void> setToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  Future<void> clearToken() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
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
          errMsg = detail.map((e) => e['msg'] ?? '').join(', ');
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
