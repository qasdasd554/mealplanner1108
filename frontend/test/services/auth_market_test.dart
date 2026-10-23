import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:smart_meal_planner/config/api_config.dart';
import 'package:smart_meal_planner/services/api_client.dart';
import 'package:smart_meal_planner/services/auth_service.dart';

class _RecordingClient extends ApiClient {
  _RecordingClient() : super.forTesting(httpClient: http.Client());

  String? path;
  Map<String, dynamic>? body;

  @override
  Future<dynamic> post(String path, {dynamic body, Duration? timeout}) async {
    this.path = path;
    this.body = Map<String, dynamic>.from(body as Map);
    // A compatibility response without a session avoids platform storage in
    // these request-construction tests. It does not establish a real account.
    return <String, dynamic>{};
  }
}

void main() {
  for (final region in <String?>['GB', 'UK', 'PL', null]) {
    test(
      'password recovery sends only the normalized UI region $region',
      () async {
        final client = _RecordingClient();
        final service = AuthService(client: client, deviceRegion: () => region);
        final expectedRegion = region == 'GB' || region == 'UK' ? 'GB' : 'PL';
        await service.forgotPassword('account@example.invalid');
        expect(client.body, {
          'email': 'account@example.invalid',
          'device_region': expectedRegion,
        });
        await service.resetPassword(
          email: 'account@example.invalid',
          code: '123456',
          newPassword: 'synthetic',
        );
        expect(client.body, {
          'email': 'account@example.invalid',
          'code': '123456',
          'new_password': 'synthetic',
          'device_region': expectedRegion,
        });
      },
    );
  }
  group('registration device region', () {
    for (final region in <String?>['GB', 'UK', 'PL', 'US', null]) {
      test('email registration sends normalized region $region', () async {
        final client = _RecordingClient();
        final service = AuthService(client: client, deviceRegion: () => region);
        await service.register('account@example.invalid', 'password', 'Name');
        expect(client.path, ApiConfig.authRegister);
        expect(
          client.body!['device_region'],
          region == 'GB' || region == 'UK' ? 'GB' : 'PL',
        );
        expect(client.body!['email'], 'account@example.invalid');
        expect(client.body!['display_name'], 'Name');
      });
    }

    test('profile editing never sends a new country', () async {
      final client = _ProfileClient();
      final service = AuthService(client: client, deviceRegion: () => 'PL');
      final user = await service.updateProfile(displayName: 'Changed');
      expect(client.body, {'display_name': 'Changed'});
      expect(user.countryCode, 'GB');
    });

    test('does not cache the preceding registration region', () async {
      final client = _RecordingClient();
      var region = 'GB';
      final service = AuthService(client: client, deviceRegion: () => region);
      await service.register('first@example.invalid', 'password', 'First');
      expect(client.body!['device_region'], 'GB');
      region = 'PL';
      await service.register('second@example.invalid', 'password', 'Second');
      expect(client.body!['device_region'], 'PL');
    });

    testWidgets('uses the device region rather than its language', (
      tester,
    ) async {
      tester.platformDispatcher.localeTestValue = const Locale('pl', 'GB');
      addTearDown(tester.platformDispatcher.clearLocaleTestValue);
      final client = _RecordingClient();
      // TestPlatformDispatcher wraps rather than replaces the real singleton.
      // Read its region through the same injectable boundary as real devices.
      await AuthService(
        client: client,
        deviceRegion: () => tester.platformDispatcher.locale.countryCode,
      ).register('account@example.invalid', 'password', 'Name');
      expect(client.body!['device_region'], 'GB');
    });
  });
}

class _ProfileClient extends _RecordingClient {
  @override
  Future<dynamic> put(String path, {dynamic body, Duration? timeout}) async {
    this.path = path;
    this.body = Map<String, dynamic>.from(body as Map);
    return {
      'id': 'account-1',
      'email': 'account@example.invalid',
      'country_code': 'GB',
      'created_at': '2026-10-15T00:00:00Z',
    };
  }
}
