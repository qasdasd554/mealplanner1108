import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meal_planner/utils/market_money.dart';

void main() {
  group('market money formatting', () {
    test('preserves existing Polish display including decimal point', () {
      expect(formatMarketMoney(12.3, currencyCode: 'PLN'), '12.30 zł');
      expect(formatMarketMoney(1234.56, currencyCode: 'PLN'), '1234.56 zł');
      expect(formatMarketMoney(0, currencyCode: 'PLN'), '0.00 zł');
    });

    test('displays GBP without converting the numeric amount', () {
      expect(formatMarketMoney(12.3, currencyCode: 'GBP'), '£12.30');
      expect(formatMarketMoney(1234.56, currencyCode: 'GBP'), '£1,234.56');
      expect(formatMarketMoney(0, currencyCode: 'GBP'), '£0.00');
    });

    test('country uses persisted market identifiers, not phone language', () {
      expect(currencyForAccountCountry('PL'), 'PLN');
      expect(currencyForAccountCountry('GB'), 'GBP');
      expect(currencyForAccountCountry('UK'), 'GBP');
    });

    test('does not silently label an unknown currency as PLN or GBP', () {
      expect(
        () => formatMarketMoney(12, currencyCode: 'USD'),
        throwsFormatException,
      );
      expect(() => supportedCurrencyCode(''), throwsFormatException);
    });

    test('normalizes supported currency codes only', () {
      expect(supportedCurrencyCode(' gbp '), 'GBP');
      expect(supportedCurrencyCode('pln'), 'PLN');
    });

    test('never displays invalid amounts', () {
      for (final amount in [double.nan, double.infinity, -double.infinity]) {
        expect(
          () => formatMarketMoney(amount, currencyCode: 'GBP'),
          throwsFormatException,
        );
      }
    });
  });
}
