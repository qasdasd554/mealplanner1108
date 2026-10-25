import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meal_planner/config/api_config.dart';

void main() {
  test('normal builds need no test endpoint', () {
    expect(developmentApiBaseUrl('', isRelease: false), isNull);
    expect(developmentApiBaseUrl('  ', isRelease: false), isNull);
  });
  test('a debug APK can explicitly use a separate HTTPS backend', () {
    expect(
      developmentApiBaseUrl(
        'https://uk-test.example.invalid/',
        isRelease: false,
      ),
      'https://uk-test.example.invalid',
    );
  });
  for (final value in [
    'http://example.invalid',
    'javascript:alert(1)',
    '/relative',
    'https://user:pass@example.invalid',
    'https://example.invalid/api/v1',
    'https://example.invalid?secret=value',
    'https://example.invalid/#fragment',
  ]) {
    test(
      'invalid debug endpoint is rejected rather than silently using production: $value',
      () {
        expect(
          () => developmentApiBaseUrl(value, isRelease: false),
          throwsFormatException,
        );
      },
    );
  }
  test('release AAB always ignores a developer endpoint, even if invalid', () {
    expect(
      developmentApiBaseUrl('https://test.example.invalid', isRelease: true),
      isNull,
    );
    expect(developmentApiBaseUrl('not a URL', isRelease: true), isNull);
  });
}
