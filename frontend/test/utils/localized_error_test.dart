import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meal_planner/l10n/app_localizations_en.dart';
import 'package:smart_meal_planner/l10n/app_localizations_pl.dart';
import 'package:smart_meal_planner/services/api_client.dart';
import 'package:smart_meal_planner/utils/error_utils.dart';

void main() {
  final pl = AppLocalizationsPl(), gb = AppLocalizationsEnGb();
  final cases = <Object, (String, String)>{
    ApiException(401, 'raw'): (pl.errorSignIn, gb.errorSignIn),
    ApiException(429, 'raw'): (
      pl.errorTooManyRequests,
      gb.errorTooManyRequests,
    ),
    ApiException(503, 'raw'): (pl.errorUnavailable, gb.errorUnavailable),
    ApiException(504, 'raw'): (pl.errorServerTimeout, gb.errorServerTimeout),
    ApiException(500, 'raw'): (pl.errorServer, gb.errorServer),
    TimeoutException('slow'): (
      pl.errorOperationTimeout,
      gb.errorOperationTimeout,
    ),
    Exception('SocketException: disconnected'): (
      pl.errorConnection,
      gb.errorConnection,
    ),
    const FormatException('invalid'): (pl.errorFormat, gb.errorFormat),
  };
  for (final entry in cases.entries) {
    test(
      'errors preserve legacy Polish and localise English: ${entry.key.runtimeType} ${entry.value.$2}',
      () {
        expect(friendlyError(entry.key), entry.value.$1);
        expect(friendlyError(entry.key, strings: pl), entry.value.$1);
        expect(friendlyError(entry.key, strings: gb), entry.value.$2);
      },
    );
  }
  for (final status in [403, 404, 409, 422]) {
    test('server detail is retained for $status', () {
      final error = ApiException(
        status,
        'Choose a preferred shop in your profile.',
      );
      expect(friendlyError(error, strings: gb), error.message);
    });
  }
  test('unknown exceptions lose only the Exception prefix', () {
    expect(
      friendlyError(Exception('Readable detail'), strings: gb),
      'Readable detail',
    );
  });
}
