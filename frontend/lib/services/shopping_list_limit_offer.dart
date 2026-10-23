import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/market_locale.dart';
import '../models/premium_offer.dart';
import '../providers/auth_provider.dart';
import '../screens/profile/premium_screen.dart';
import 'api_client.dart';
import 'contextual_premium_offer_service.dart';

/// Recognise only the server's weekly-list limit, never an arbitrary 403,
/// access error, a Premium point shortage or a failed network request.
bool isWeeklyShoppingListLimit(Object? error) {
  if (error is! ApiException || error.statusCode != 403) return false;
  final message = error.message.replaceAll(RegExp(r'\s+'), ' ').trim();
  return message.startsWith(
        'Konto standardowe może utworzyć jedną listę zakupów w tygodniu',
      ) ||
      message.startsWith(
        'A Standard account can create one shopping list per week',
      );
}

class ShoppingListLimitOffer {
  static ({String userId, int generation})? _shownSession;
  static bool _presenting = false;

  /// A user-initiated limit screen is distinct from the daily automatic offer.
  /// The server remains the authority; no local list count approximates quota.
  static Future<bool> handle(
    BuildContext context,
    Object? error, {
    ApiClient? client,
    Future<dynamic> Function(BuildContext)? present,
  }) async {
    if (!isWeeklyShoppingListLimit(error) || !context.mounted) return false;
    final account = context.read<AuthProvider>().currentUser;
    if (account == null || account.hasPremiumAccess) return false;
    final api = client ?? ApiClient();
    final stamp = (userId: account.id, generation: api.sessionGeneration);
    if (_presenting || ContextualPremiumOfferService.isPresenting) return true;
    if (!(ModalRoute.of(context)?.isCurrent ?? false)) return true;
    if (_shownSession == stamp) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(context.strings.shoppingLimitShort),
            action: SnackBarAction(
              label: 'Premium',
              onPressed: () {
                if (context.mounted &&
                    context.read<AuthProvider>().currentUser?.id ==
                        stamp.userId &&
                    api.sessionGeneration == stamp.generation) {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder:
                          (_) => const PremiumScreen(
                            offerContext: PremiumOfferContext.shoppingList,
                          ),
                    ),
                  );
                }
              },
            ),
          ),
        );
      return true;
    }
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle != null && lifecycle != AppLifecycleState.resumed)
      return true;
    _shownSession = stamp;
    _presenting = true;
    try {
      FocusManager.instance.primaryFocus?.unfocus();
      final result =
          present != null
              ? await present(context)
              : await Navigator.of(context).push(
                MaterialPageRoute<dynamic>(
                  fullscreenDialog: true,
                  builder:
                      (_) => const PremiumScreen(
                        offerContext: PremiumOfferContext.shoppingList,
                        shoppingListLimit: true,
                      ),
                ),
              );
      if (result == 'shopping-list' &&
          context.mounted &&
          context.read<AuthProvider>().currentUser?.id == stamp.userId &&
          api.sessionGeneration == stamp.generation) {
        // Keep the recipe/form route underneath, including unsaved selections.
        Navigator.of(context).pushNamed('/home', arguments: 2);
      }
    } catch (_) {
      // A failed optional offer must not hide the original quota error or
      // consume the session's only opportunity to open the screen.
      if (_shownSession == stamp) _shownSession = null;
      return false;
    } finally {
      _presenting = false;
    }
    return true;
  }
}
