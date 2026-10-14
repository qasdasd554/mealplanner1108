import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smart_meal_planner/services/api_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({
      'auth_token': 'old',
      'auth_refresh_token': 'refresh',
    });
  });
  test(
    'refresh arriving after logout cannot restore token or retry request',
    () async {
      final refreshStarted = Completer<void>();
      final refreshResponse = Completer<http.Response>();
      var attempts = 0;
      final client = ApiClient.forTesting(
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/auth/refresh')) {
            refreshStarted.complete();
            return refreshResponse.future;
          }
          attempts++;
          return http.Response('{"detail":"expired"}', 401);
        }),
      );
      final request = client.get('/users/me');
      final assertion = expectLater(request, throwsA(isA<ApiException>()));
      await refreshStarted.future;
      await client.clearToken();
      refreshResponse.complete(
        http.Response(
          '{"access_token":"restored","refresh_token":"new-refresh"}',
          200,
        ),
      );
      await assertion;
      expect(await client.getToken(), isNull);
      expect(await client.hasRefreshToken(), isFalse);
      expect(attempts, 1);
    },
  );

  test('simultaneous expired requests share one token refresh', () async {
    var refreshes = 0;
    final ready = Completer<void>();
    final response = Completer<http.Response>();
    final client = ApiClient.forTesting(
      httpClient: MockClient((request) async {
        if (request.url.path.endsWith('/auth/refresh')) {
          refreshes++;
          if (!ready.isCompleted) ready.complete();
          return response.future;
        }
        return request.headers['Authorization'] == 'Bearer restored'
            ? http.Response('{"ok":true}', 200)
            : http.Response('{"detail":"expired"}', 401);
      }),
    );
    final first = client.get('/users/me');
    final second = client.get('/meal-plans/');
    await ready.future;
    await Future<void>.delayed(Duration.zero);
    response.complete(
      http.Response(
        '{"access_token":"restored","refresh_token":"new-refresh"}',
        200,
      ),
    );
    await Future.wait([first, second]);
    expect(refreshes, 1);
  });
}
