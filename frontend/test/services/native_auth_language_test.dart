import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:http/http.dart' as http;
import 'package:smart_meal_planner/config/api_config.dart';
import 'package:smart_meal_planner/services/api_client.dart';
import 'package:smart_meal_planner/services/auth_service.dart';

class _Client extends ApiClient {
  _Client() : super.forTesting(httpClient: http.Client());
  int posts = 0;
  int sessions = 0;
  String? path;
  Map<String, dynamic>? body;
  @override
  Future<dynamic> post(String path, {dynamic body, Duration? timeout}) async {
    posts++;
    this.path = path;
    this.body = Map<String, dynamic>.from(body as Map);
    return {'access_token': 'synthetic-app-token', 'token_type': 'bearer'};
  }

  @override
  Future<void> setSession(
    String accessToken,
    String? refreshToken, {
    int? expectedGeneration,
  }) async {
    if (expectedGeneration == sessionGeneration) sessions++;
  }
}

AuthorizationCredentialAppleID apple(String? token) =>
    AuthorizationCredentialAppleID(
      userIdentifier: 'synthetic-user',
      givenName: 'Original',
      familyName: 'Name',
      email: 'synthetic@example.invalid',
      identityToken: token,
      state: null,
      authorizationCode: 'synthetic-code',
    );

void main() {
  for (final country in ['PL', 'GB']) {
    for (final provider in ['Google', 'Apple']) {
      test(
        '$country $provider native rejection is localized and never posts',
        () async {
          final client = _Client();
          final service = AuthService(
            client: client,
            deviceRegion: () => country,
            googleIdentityToken:
                () async =>
                    throw const GoogleSignInException(
                      code: GoogleSignInExceptionCode.unknownError,
                    ),
            appleCredential:
                () async =>
                    throw const SignInWithAppleAuthorizationException(
                      code: AuthorizationErrorCode.failed,
                      message: 'synthetic',
                    ),
          );
          final expected =
              country == 'GB'
                  ? 'Could not sign in with $provider${provider == 'Google' ? ' (unknownError)' : ''}. Please try again.'
                  : 'Nie udało się zalogować przez $provider${provider == 'Google' ? ' (unknownError)' : ''}. Spróbuj ponownie.';
          await expectLater(
            provider == 'Google'
                ? service.loginWithGoogle()
                : service.loginWithApple(),
            throwsA(
              isA<ApiException>().having((e) => e.message, 'message', expected),
            ),
          );
          expect(client.posts, 0);
          expect(client.sessions, 0);
        },
      );
      for (final token in <String?>[null, '']) {
        test(
          '$country $provider missing token ($token) never establishes session',
          () async {
            final client = _Client();
            final service = AuthService(
              client: client,
              deviceRegion: () => country,
              googleIdentityToken: () async => token,
              appleCredential: () async => apple(token),
            );
            final expected =
                country == 'GB'
                    ? 'Could not obtain the $provider identity token.'
                    : 'Nie udało się uzyskać tokenu tożsamości $provider.';
            await expectLater(
              provider == 'Google'
                  ? service.loginWithGoogle()
                  : service.loginWithApple(),
              throwsA(
                isA<ApiException>().having(
                  (e) => e.message,
                  'message',
                  expected,
                ),
              ),
            );
            expect(client.posts, 0);
            expect(client.sessions, 0);
          },
        );
      }
      test(
        '$country $provider cancellation is not an error or network request',
        () async {
          final client = _Client();
          final service = AuthService(
            client: client,
            deviceRegion: () => country,
            googleIdentityToken:
                () async =>
                    throw const GoogleSignInException(
                      code: GoogleSignInExceptionCode.canceled,
                    ),
            appleCredential:
                () async =>
                    throw const SignInWithAppleAuthorizationException(
                      code: AuthorizationErrorCode.canceled,
                      message: 'synthetic',
                    ),
          );
          expect(
            await (provider == 'Google'
                ? service.loginWithGoogle()
                : service.loginWithApple()),
            isFalse,
          );
          expect(client.posts, 0);
          expect(client.sessions, 0);
        },
      );
      test(
        '$country $provider success still requires the existing backend endpoint',
        () async {
          final client = _Client();
          final service = AuthService(
            client: client,
            deviceRegion: () => country,
            googleIdentityToken: () async => 'synthetic-identity',
            appleCredential: () async => apple('synthetic-identity'),
          );
          expect(
            await (provider == 'Google'
                ? service.loginWithGoogle(captchaToken: 'synthetic-challenge')
                : service.loginWithApple(captchaToken: 'synthetic-challenge')),
            isTrue,
          );
          expect(
            client.path,
            provider == 'Google' ? ApiConfig.authGoogle : ApiConfig.authApple,
          );
          expect(client.body!['device_region'], country);
          expect(client.body!['turnstile_token'], 'synthetic-challenge');
          expect(
            client.body![provider == 'Google' ? 'id_token' : 'identity_token'],
            'synthetic-identity',
          );
          if (provider == 'Apple')
            expect(client.body!['full_name'], 'Original Name');
          expect(client.sessions, 1);
        },
      );
    }
  }
}
