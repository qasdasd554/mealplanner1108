import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/account_market.dart';

/// External lookup follows the registered account, never a travelling phone's
/// region, the current UI language, or the administrator's selected shop.
extension LookupMarketContext on BuildContext {
  String get registeredLookupCountry =>
      normalizeAccountCountry(read<AuthProvider?>()?.currentUser?.countryCode);
}
