import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meal_planner/providers/auth_provider.dart';
import 'package:smart_meal_planner/services/auth_service.dart';
import 'package:smart_meal_planner/services/api_client.dart';
import 'package:smart_meal_planner/l10n/market_locale.dart';

class _Service extends AuthService {
  _Service(this.message, this.status);
  final String message;
  final int status;
  @override
  Future<bool> attemptGoogleSilentLogin() async => false;
  @override
  Future<bool> loginWithGoogle({String? captchaToken}) async =>
      throw ApiException(status, message);
  @override
  Future<bool> loginWithApple({String? captchaToken}) async =>
      throw ApiException(status, message);
}

void main() {
  for (final country in ['PL', 'GB']) {
    for (final provider in ['Google', 'Apple']) {
      test(
        '$country $provider sign-in failure is not a request to sign in',
        () async {
          final message =
              country == 'GB'
                  ? 'Invalid or expired $provider token'
                  : 'Nieprawidłowy lub wygasły token $provider';
          final auth = AuthProvider(
            service: _Service(message, 401),
            readToken: () async => null,
            unregisterPush: () async {},
            errorStrings: () => stringsForAccountCountry(country),
          );
          addTearDown(auth.dispose);
          await auth.initialization;
          final result =
              provider == 'Google'
                  ? await auth.loginWithGoogle()
                  : await auth.loginWithApple();
          expect(result, isFalse);
          expect(auth.errorMessage, message);
          expect(auth.isAuthenticated, isFalse);
          expect(auth.isLoading, isFalse);
        },
      );
    }
  }
}
