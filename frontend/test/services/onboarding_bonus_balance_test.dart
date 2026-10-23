import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_meal_planner/services/api_client.dart';
import 'package:smart_meal_planner/services/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });
  for (final total in [6, 10, null, -1, '6']) {
    test(
      'bonus uses authoritative valid server balance $total without guessing',
      () async {
        var requests = 0;
        final client = ApiClient.forTesting(
          httpClient: MockClient((request) async {
            requests++;
            expect(request.url.path, endsWith('/users/me/onboarding-bonus'));
            return http.Response(
              jsonEncode({
                'points': 4,
                if (total != null) 'total_points': total,
              }),
              200,
            );
          }),
        );
        final service = AuthService(client: client);
        final received = <int>[];
        expect(
          await service.claimOnboardingBonus(onTotalPoints: received.add),
          4,
        );
        expect(received, total is int && total >= 0 ? [total] : isEmpty);
        expect(requests, 1);
      },
    );
  }
}
