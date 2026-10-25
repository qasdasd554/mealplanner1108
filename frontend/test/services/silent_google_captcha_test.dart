import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:smart_meal_planner/config/api_config.dart';
import 'package:smart_meal_planner/services/api_client.dart';
import 'package:smart_meal_planner/services/auth_service.dart';

class _Client extends ApiClient {
  _Client() : super.forTesting(httpClient: http.Client());
  int sessionReads = 0;
  int posts = 0;

  @override
  int get sessionGeneration {
    sessionReads++;
    return super.sessionGeneration;
  }

  @override
  Future<dynamic> post(String path, {dynamic body, Duration? timeout}) async {
    posts++;
    throw StateError('A background attempt must not bypass CAPTCHA');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'configured CAPTCHA defers silent Google login to interactive sign-in',
    () async {
      expect(ApiConfig.turnstileSiteKey, isNotEmpty);
      final client = _Client();
      final service = AuthService(client: client);
      expect(await service.attemptGoogleSilentLogin(), isFalse);
      expect(client.sessionReads, 0);
      expect(client.posts, 0);
    },
  );
}
