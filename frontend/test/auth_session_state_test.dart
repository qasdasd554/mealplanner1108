import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meal_planner/models/user.dart';
import 'package:smart_meal_planner/providers/auth_provider.dart';
import 'package:smart_meal_planner/services/auth_service.dart';

class _AuthService extends AuthService {
  int logoutCalls = 0;
  int profileCalls = 0;
  bool profileVerified = false;
  Completer<User>? pendingProfile;
  Completer<void>? pendingLogin;
  @override
  Future<AuthToken> login(
    String email,
    String password, {
    String? captchaToken,
  }) async {
    if (pendingLogin != null) await pendingLogin!.future;
    return AuthToken(accessToken: 'synthetic-token', tokenType: 'bearer');
  }

  @override
  Future<bool> loginWithGoogle({String? captchaToken}) async => true;
  @override
  Future<bool> loginWithApple({String? captchaToken}) async => true;
  @override
  Future<bool> attemptGoogleSilentLogin() async => false;
  @override
  Future<User> getProfile() async {
    profileCalls++;
    return pendingProfile == null
        ? User.fromJson({
          'id': 'user-1',
          'email': 'test@example.invalid',
          'display_name': 'Test',
          'is_email_verified': profileVerified,
          'created_at': '2026-10-14T00:00:00',
        })
        : await pendingProfile!.future;
  }

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

  @override
  Future<void> verifyEmail(String code) async {}
}

void main() {
  for (final kind in ['email', 'google', 'apple', 'register']) {
    test(
      '$kind completion after logout cannot affect a new pending login',
      () async {
        final service = _AuthService();
        final provider = AuthProvider(
          service: service,
          readToken: () async => null,
          unregisterPush: () async {},
        );
        addTearDown(provider.dispose);
        await provider.initialization;
        final old = Completer<User>();
        service.pendingProfile = old;
        final oldRequest = switch (kind) {
          'email' => provider.login('old@example.invalid', 'password'),
          'google' => provider.loginWithGoogle(),
          'apple' => provider.loginWithApple(),
          _ => provider.register('old@example.invalid', 'password', 'Old'),
        };
        await Future<void>.delayed(Duration.zero);
        expect(service.profileCalls, 1);
        await provider.logout();
        final fresh = Completer<User>();
        service.pendingProfile = fresh;
        final newRequest = provider.register(
          'new@example.invalid',
          'password',
          'New',
        );
        await Future<void>.delayed(Duration.zero);
        expect(provider.isLoading, isTrue);
        old.complete(
          User.fromJson({
            'id': 'old',
            'email': 'old@example.invalid',
            'created_at': '2026-10-22T00:00:00',
          }),
        );
        expect(await oldRequest, isFalse);
        expect(
          provider.isLoading,
          isTrue,
          reason: 'old completion cannot hide the new operation',
        );
        fresh.complete(
          User.fromJson({
            'id': 'new',
            'email': 'new@example.invalid',
            'created_at': '2026-10-22T00:00:00',
          }),
        );
        expect(await newRequest, isTrue);
        expect(provider.currentUser?.id, 'new');
        expect(provider.isLoading, isFalse);
      },
    );
  }
  test('late login error cannot appear in the replacement session', () async {
    final service = _AuthService();
    final provider = AuthProvider(
      service: service,
      readToken: () async => null,
      unregisterPush: () async {},
    );
    addTearDown(provider.dispose);
    await provider.initialization;
    service.pendingLogin = Completer<void>();
    final oldRequest = provider.login('old@example.invalid', 'password');
    await Future<void>.delayed(Duration.zero);
    await provider.logout();
    expect(
      await provider.register('new@example.invalid', 'password', 'New'),
      isTrue,
    );
    service.pendingLogin!.completeError(
      StateError('synthetic old session failure'),
    );
    expect(await oldRequest, isFalse);
    expect(provider.errorMessage, isNull);
    expect(provider.isAuthenticated, isTrue);
  });
  test(
    'verification refresh cannot reuse a pre-verification profile',
    () async {
      final service = _AuthService();
      final provider = AuthProvider(
        service: service,
        readToken: () async => null,
        unregisterPush: () async {},
      );
      addTearDown(provider.dispose);
      await provider.initialization;
      final old = Completer<User>();
      service.pendingProfile = old;
      final staleRequest = provider.loadProfile();
      service.pendingProfile = null;
      service.profileVerified = true;
      final verified = provider.verifyEmail('123456');
      await Future<void>.delayed(Duration.zero);
      old.complete(
        User.fromJson({
          'id': 'user-1',
          'email': 'test@example.invalid',
          'is_email_verified': false,
          'created_at': '2026-10-14T00:00:00',
        }),
      );
      await staleRequest;
      expect(await verified, isTrue);
      expect(provider.currentUser?.isEmailVerified, isTrue);
      expect(service.profileCalls, 2);
    },
  );
  test(
    'token storage error cannot leave initialization as a failed future',
    () async {
      final service = _AuthService();
      final provider = AuthProvider(
        service: service,
        readToken:
            () async => throw PlatformException(code: 'storage-unavailable'),
        unregisterPush: () async {},
      );
      addTearDown(provider.dispose);
      await provider.initialization;
      expect(provider.isInitialized, isTrue);
      expect(provider.isAuthenticated, isFalse);
      expect(provider.errorMessage, isNotEmpty);
      expect(
        service.logoutCalls,
        0,
        reason: 'do not erase credentials after a read error',
      );
    },
  );
  test(
    'an old pending profile cannot block the next authenticated session',
    () async {
      final service = _AuthService();
      final provider = AuthProvider(
        service: service,
        readToken: () async => null,
        unregisterPush: () async {},
      );
      addTearDown(provider.dispose);
      await provider.initialization;
      final old = Completer<User>();
      service.pendingProfile = old;
      final oldRequest = provider.loadProfile();
      await provider.logout();
      service.pendingProfile = null;
      expect(
        await provider.register('new@example.invalid', 'password', 'New'),
        isTrue,
      );
      expect(service.profileCalls, 2);
      old.complete(
        User.fromJson({
          'id': 'old',
          'email': 'old@example.invalid',
          'created_at': '2026-10-14T00:00:00',
        }),
      );
      await oldRequest;
      expect(provider.currentUser?.id, 'user-1');
      expect(provider.isAuthenticated, isTrue);
    },
  );
  test(
    'overlapping profile refreshes share a single request and notification',
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
      var notifications = 0;
      provider.addListener(() => notifications++);
      final requests = List.generate(
        8,
        (_) => provider.loadProfileInBackground(),
      );
      expect(service.profileCalls, 1);
      service.pendingProfile!.complete(
        User.fromJson({
          'id': 'user-1',
          'email': 'test@example.invalid',
          'is_email_verified': false,
          'created_at': '2026-10-14T00:00:00',
        }),
      );
      await Future.wait(requests);
      expect(notifications, 1);
      service.pendingProfile = null;
      await provider.loadProfile();
      expect(
        service.profileCalls,
        2,
        reason: 'subsequent explicit refresh still works',
      );
    },
  );
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
