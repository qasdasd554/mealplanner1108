import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meal_planner/models/user.dart';

Map<String, dynamic> _profile({String? country}) => {
  'id': 'account-1',
  'email': 'account@example.invalid',
  'created_at': '2026-10-15T00:00:00Z',
  if (country != null) 'country_code': country,
};

void main() {
  group('read-only account country', () {
    test('older backend profiles remain Polish', () {
      expect(User.fromJson(_profile()).countryCode, 'PL');
    });

    test('reads the server account country', () {
      expect(User.fromJson(_profile(country: 'GB')).countryCode, 'GB');
      expect(User.fromJson(_profile(country: 'PL')).countryCode, 'PL');
    });

    test('a profile copy cannot drop the assigned market', () {
      final user = User.fromJson(_profile(country: 'GB'));
      expect(user.copyWith(displayName: 'New name').countryCode, 'GB');
    });

    test('unsupported server country falls back safely', () {
      expect(User.fromJson(_profile(country: 'DE')).countryCode, 'PL');
    });
  });
}
