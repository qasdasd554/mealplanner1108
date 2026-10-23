import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meal_planner/services/account_market.dart';

void main() {
  group('registration account market', () {
    test('accepts Great Britain and its UK compatibility alias', () {
      for (final region in ['GB', 'gb', ' GB ', 'UK', 'uk']) {
        expect(normalizeAccountCountry(region), 'GB');
        expect(registrationMarketFields(region), {'device_region': 'GB'});
      }
    });

    test('keeps Poland for Polish, unsupported and missing regions', () {
      for (final region in <String?>['PL', 'pl', null, '', 'US', 'DE', 'en']) {
        expect(normalizeAccountCountry(region), 'PL');
        expect(registrationMarketFields(region), {'device_region': 'PL'});
      }
    });

    test('never derives country from a language or an unparsed locale', () {
      expect(normalizeAccountCountry('en'), 'PL');
      expect(normalizeAccountCountry('en_GB'), 'PL');
      expect(normalizeAccountCountry('pl-GB'), 'PL');
    });
  });
}
