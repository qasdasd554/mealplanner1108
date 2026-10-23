import 'package:flutter/widgets.dart';
import '../services/account_market.dart';
import 'app_localizations.dart';
import 'app_localizations_en.dart';
import 'app_localizations_pl.dart';

/// Registered account market always wins over later phone-region changes.
Locale localeForMarket({String? accountCountry, String? deviceRegion}) =>
    normalizeAccountCountry(accountCountry ?? deviceRegion) == 'GB'
        ? const Locale('en', 'GB')
        : const Locale('pl', 'PL');

final _polishFallback = AppLocalizationsPl();
final _britishFallback = AppLocalizationsEnGb();

/// Synchronous strings for state objects that do not own a widget context.
/// The caller passes the persisted account country, never IP or phone locale.
AppLocalizations stringsForAccountCountry(String? country) =>
    normalizeAccountCountry(country) == 'GB'
        ? _britishFallback
        : _polishFallback;

extension MarketStrings on BuildContext {
  // Standalone component tests and legacy embedding retain Polish wording.
  AppLocalizations get strings =>
      Localizations.of<AppLocalizations>(this, AppLocalizations) ??
      _polishFallback;
}
