import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:smart_meal_planner/l10n/app_localizations_en.dart';
import 'package:smart_meal_planner/services/api_client.dart';
import 'package:smart_meal_planner/models/user.dart';
import 'package:smart_meal_planner/providers/auth_provider.dart';
import 'package:smart_meal_planner/services/auth_service.dart';

class _Service extends AuthService {
  int deleteCalls = 0;
  int logoutCalls = 0;
  Completer<void>? deleteResponse;
  Completer<User>? profileResponse;
  Completer<void>? actionResponse;
  int profileCalls = 0;
  @override
  Future<bool> attemptGoogleSilentLogin() async => false;
  @override
  Future<void> logout() async {
    logoutCalls++;
  }

  @override
  void invalidateSession() {}
  @override
  Future<void> deleteAccount() async {
    deleteCalls++;
    await deleteResponse?.future;
  }

  @override
  Future<AuthToken> login(
    String email,
    String password, {
    String? captchaToken,
  }) async => AuthToken(accessToken: 'synthetic-token', tokenType: 'bearer');
  @override
  Future<User> getProfile() async {
    profileCalls++;
    return profileResponse?.future ??
        User(
          id: 'new-account',
          email: 'new@example.invalid',
          countryCode: 'GB',
          householdSize: 1,
          createdAt: DateTime(2026),
        );
  }

  Future<void> _action() async => await actionResponse?.future;
  @override
  Future<void> verifyEmail(String code) => _action();
  @override
  Future<void> resendVerificationCode() => _action();
  @override
  Future<void> forgotPassword(String email) => _action();
  @override
  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) => _action();
  @override
  Future<void> blockUser(String userId) => _action();
  @override
  Future<void> unblockUser(String userId) => _action();
  @override
  Future<void> reportRecipe(
    String recipeId, {
    required String reason,
    String? details,
  }) => _action();
  @override
  Future<void> reportComment(
    String recipeId,
    String commentId, {
    required String reason,
    String? details,
  }) => _action();
}

Future<bool> _startAction(AuthProvider auth, String kind) => switch (kind) {
  'verify' => auth.verifyEmail('123456'),
  'resend' => auth.resendVerificationCode(),
  'forgot' => auth.forgotPassword('old@example.invalid'),
  'reset' => auth.resetPassword(
    email: 'old@example.invalid',
    code: '123456',
    newPassword: 'synthetic',
  ),
  'block' => auth.blockUser('synthetic-user'),
  'unblock' => auth.unblockUser('synthetic-user'),
  'recipe' => auth.reportRecipe('synthetic-recipe', reason: 'spam'),
  'comment' => auth.reportComment(
    'synthetic-recipe',
    'synthetic-comment',
    reason: 'spam',
  ),
  _ => throw StateError('Unknown test action'),
};

void main() {
  test(
    'pre-login storage failure uses the configured English UI language',
    () async {
      final auth = AuthProvider(
        service: _Service(),
        readToken:
            () async =>
                throw PlatformException(code: 'synthetic-storage-error'),
        unregisterPush: () async {},
        errorStrings: () => AppLocalizationsEnGb(),
      );
      addTearDown(auth.dispose);
      await auth.initialization;
      expect(auth.errorMessage, AppLocalizationsEnGb().authStoredSessionFailed);
      expect(auth.isInitialized, isTrue);
      expect(auth.isAuthenticated, isFalse);
    },
  );
  test(
    'a persisted GB account selects English for provider failures',
    () async {
      final service = _Service();
      final auth = AuthProvider(
        service: service,
        readToken: () async => null,
        unregisterPush: () async {},
      );
      addTearDown(auth.dispose);
      await auth.initialization;
      expect(await auth.login('new@example.invalid', 'synthetic'), isTrue);
      service.actionResponse = Completer<void>();
      final pending = auth.blockUser('synthetic-user');
      service.actionResponse!.completeError(
        ApiException(503, 'raw server error'),
      );
      expect(await pending, isFalse);
      expect(auth.errorMessage, AppLocalizationsEnGb().errorUnavailable);
    },
  );
  for (final kind in [
    'verify',
    'resend',
    'forgot',
    'reset',
    'block',
    'unblock',
    'recipe',
    'comment',
  ]) {
    for (final fail in [false, true]) {
      test(
        'late $kind action cannot succeed or show an error in another account: error=$fail',
        () async {
          final service = _Service()..actionResponse = Completer<void>();
          final auth = AuthProvider(
            service: service,
            readToken: () async => null,
            unregisterPush: () async {},
          );
          addTearDown(auth.dispose);
          await auth.initialization;
          final old = _startAction(auth, kind);
          await auth.logout();
          expect(await auth.login('new@example.invalid', 'synthetic'), isTrue);
          final profileCalls = service.profileCalls;
          if (fail) {
            service.actionResponse!.completeError(
              Exception('Old action failure'),
            );
          } else {
            service.actionResponse!.complete();
          }
          expect(await old, isFalse);
          expect(auth.errorMessage, isNull);
          expect(auth.currentUser?.id, 'new-account');
          expect(service.profileCalls, profileCalls);
        },
      );
    }
  }
  test(
    'a pre-login action cannot report a stale failure after a successful login',
    () async {
      final service = _Service()..actionResponse = Completer<void>();
      final auth = AuthProvider(
        service: service,
        readToken: () async => null,
        unregisterPush: () async {},
      );
      addTearDown(auth.dispose);
      await auth.initialization;
      final reset = auth.forgotPassword('old@example.invalid');
      expect(await auth.login('new@example.invalid', 'synthetic'), isTrue);
      service.actionResponse!.completeError(Exception('Old reset failure'));
      expect(await reset, isFalse);
      expect(auth.errorMessage, isNull);
    },
  );
  test(
    'pending push cleanup cannot dispatch account deletion after logout and new login',
    () async {
      final service = _Service();
      final pushCleanup = Completer<void>();
      var pushCalls = 0;
      final auth = AuthProvider(
        service: service,
        readToken: () async => null,
        unregisterPush: () async {
          if (++pushCalls == 1) await pushCleanup.future;
        },
      );
      addTearDown(auth.dispose);
      await auth.initialization;
      final deleting = auth.deleteAccount();
      await auth.logout();
      expect(await auth.login('new@example.invalid', 'synthetic'), isTrue);
      pushCleanup.complete();
      expect(await deleting, isFalse);
      expect(service.deleteCalls, 0);
      expect(auth.currentUser?.id, 'new-account');
      expect(auth.isAuthenticated, isTrue);
    },
  );
  for (final fail in [false, true]) {
    test(
      'late delete response cannot clear a new session or its loading state: error=$fail',
      () async {
        final service = _Service()..deleteResponse = Completer<void>();
        final auth = AuthProvider(
          service: service,
          readToken: () async => null,
          unregisterPush: () async {},
        );
        addTearDown(auth.dispose);
        await auth.initialization;
        final deleting = auth.deleteAccount();
        await Future<void>.delayed(Duration.zero);
        expect(service.deleteCalls, 1);
        await auth.logout();
        service.profileResponse = Completer<User>();
        final login = auth.login('new@example.invalid', 'synthetic');
        await Future<void>.delayed(Duration.zero);
        expect(auth.isLoading, isTrue);
        if (fail) {
          service.deleteResponse!.completeError(
            Exception('Old account failure'),
          );
        } else {
          service.deleteResponse!.complete();
        }
        expect(await deleting, isFalse);
        expect(auth.isLoading, isTrue);
        expect(auth.errorMessage, isNull);
        service.profileResponse!.complete(
          User(
            id: 'new-account',
            email: 'new@example.invalid',
            householdSize: 1,
            createdAt: DateTime(2026),
          ),
        );
        expect(await login, isTrue);
        expect(auth.currentUser?.id, 'new-account');
        expect(service.logoutCalls, 1);
      },
    );
  }
}
