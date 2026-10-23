import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/api_config.dart';
import '../models/premium_offer.dart';
import '../providers/auth_provider.dart';
import '../screens/profile/premium_screen.dart';
import 'api_client.dart';

class ContextualPremiumOfferService {
  static bool _claimInProgress = false;
  static ({String userId, int generation})? _shownSession;
  static bool get isPresenting => _claimInProgress;

  static Future<bool> maybeShow(
    BuildContext context,
    PremiumOfferContext offerContext, {
    ApiClient? client,
    Future<void> Function(BuildContext, PremiumOfferContext)? present,
  }) async {
    final api = client ?? ApiClient();
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    if (user == null || user.hasPremiumAccess || _claimInProgress) return false;
    final session = (userId: user.id, generation: api.sessionGeneration);
    bool safeToPresent() {
      if (!context.mounted || _shownSession == session) return false;
      final current = context.read<AuthProvider>().currentUser;
      final lifecycle = WidgetsBinding.instance.lifecycleState;
      return current?.id == session.userId &&
          current?.hasPremiumAccess == false &&
          api.sessionGeneration == session.generation &&
          (lifecycle == null || lifecycle == AppLifecycleState.resumed) &&
          (ModalRoute.of(context)?.isCurrent ?? false) &&
          MediaQuery.viewInsetsOf(context).bottom == 0 &&
          FocusManager.instance.primaryFocus?.context
                  ?.findAncestorStateOfType<EditableTextState>() ==
              null;
    }

    if (!safeToPresent()) return false;

    _claimInProgress = true;
    try {
      final response = await api.post(
        ApiConfig.usersPremiumOfferClaim,
        body: {'context': offerContext.apiValue},
        timeout: const Duration(seconds: 8),
      );
      final allowed =
          response is Map<String, dynamic> && response['allowed'] == true;
      if (!allowed || !safeToPresent()) {
        return false;
      }

      _shownSession = session;
      if (present != null) {
        await present(context, offerContext);
      } else {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            fullscreenDialog: true,
            builder: (_) => PremiumScreen(offerContext: offerContext),
          ),
        );
      }
      return true;
    } catch (_) {
      // Oferta nie jest funkcją krytyczną. Awaria sieci nie może przerwać
      // czytania przepisu ani powodować serii lokalnych komunikatów.
      return false;
    } finally {
      _claimInProgress = false;
    }
  }
}
