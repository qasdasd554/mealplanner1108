import 'package:intl/intl.dart';

import '../services/account_market.dart';

/// Currency follows the immutable account market, never the device language.
/// This selects a currency only. It does not perform exchange-rate conversion.
String currencyForAccountCountry(String? countryCode) =>
    normalizeAccountCountry(countryCode) == 'GB' ? 'GBP' : 'PLN';

/// Reject unsupported or malformed price payloads instead of inventing a
/// currency. A missing currency on a legacy Polish response is handled by the
/// response model, not by silently treating arbitrary values as PLN here.
String supportedCurrencyCode(String currencyCode) {
  final normalized = currencyCode.trim().toUpperCase();
  if (normalized != 'PLN' && normalized != 'GBP') {
    throw const FormatException('Unsupported price currency');
  }
  return normalized;
}

final _pounds = NumberFormat.currency(
  locale: 'en_GB',
  name: 'GBP',
  symbol: '£',
  decimalDigits: 2,
);

/// Existing Polish presentation is deliberately unchanged, including its
/// decimal point and lack of grouping. British amounts use the local notation.
String formatMarketMoney(num amount, {required String currencyCode}) {
  final currency = supportedCurrencyCode(currencyCode);
  if (!amount.isFinite) {
    throw const FormatException('Invalid price amount');
  }
  return currency == 'GBP'
      ? _pounds.format(amount)
      : '${amount.toStringAsFixed(2)} zł';
}
