import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meal_planner/models/user.dart';
import 'package:smart_meal_planner/providers/auth_provider.dart';
import 'package:smart_meal_planner/services/auth_service.dart';

class _AuthService extends AuthService {
  int logoutCalls = 0;
  Completer<User>? pendingProfile;
  @override
  Future<bool> attemptGoogleSilentLogin() async => false;
  @override
  Future<User> getProfile() async =>
      pendingProfile == null
          ? User.fromJson({
            'id': 'user-1',
            'email': 'test@example.invalid',
            'display_name': 'Test',
            'is_email_verified': false,
            'created_at': '2026-10-14T00:00:00',
          })
          : await pendingProfile!.future;
  @override
  Future<void> register(
    String email,
    String password,
    String displayName, {
    String? captchaToken,
  }) async {}
  @override
  Future<void> logout() async {
    logoutCalls++;
  }
}

void main() {
  test(
    'new authentication waits until old logout cleanup is finished',
    () async {
      final unregister = Completer<void>();
      final provider = AuthProvider(
        service: _AuthService(),
        readToken: () async => null,
        unregisterPush: () => unregister.future,
      );
      addTearDown(provider.dispose);
      await provider.initialization;
      final cleanup = provider.logout();
      final registered = await provider.register(
        'new@example.invalid',
        'password',
        'New',
      );
      unregister.complete();
      await cleanup;
      expect(registered, isFalse);
      expect(
        await provider.register('new@example.invalid', 'password', 'New'),
        isTrue,
      );
    },
  );

  test(
    'push unregistration failure cannot leave the auth token uncleared',
    () async {
      final service = _AuthService();
      final provider = AuthProvider(
        service: service,
        readToken: () async => null,
        unregisterPush: () async => throw StateError('offline'),
      );
      addTearDown(provider.dispose);
      await provider.initialization;
      await provider.logout();
      expect(service.logoutCalls, 1);
      expect(provider.isAuthenticated, isFalse);
    },
  );
  test(
    'registration session is authenticated while waiting for email verification',
    () async {
      final provider = AuthProvider(
        service: _AuthService(),
        readToken: () async => null,
        unregisterPush: () async {},
      );
      addTearDown(provider.dispose);
      await provider.initialization;
      expect(
        await provider.register('test@example.invalid', 'password', 'Test'),
        isTrue,
      );
      expect(provider.isAuthenticated, isTrue);
      expect(provider.postLoginRoute, '/verify-email');
    },
  );

  test(
    'profile response that arrives after explicit logout cannot restore user',
    () async {
      final service = _AuthService();
      final provider = AuthProvider(
        service: service,
        readToken: () async => null,
        unregisterPush: () async {},
      );
      addTearDown(provider.dispose);
      await provider.initialization;
      service.pendingProfile = Completer<User>();
      final request = provider.loadProfile();
      await provider.logout();
      service.pendingProfile!.complete(
        User.fromJson({
          'id': 'old-user',
          'email': 'old@example.invalid',
          'display_name': 'Old',
          'created_at': '2026-10-14T00:00:00',
        }),
      );
      await request;
      expect(provider.currentUser, isNull);
      expect(provider.isAuthenticated, isFalse);
    },
  );
}
