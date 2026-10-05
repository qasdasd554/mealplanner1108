import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/api_config.dart';
import '../models/premium_offer.dart';
import '../providers/auth_provider.dart';
import '../screens/profile/premium_screen.dart';
import 'api_client.dart';

class ContextualPremiumOfferService {
  static bool _claimInProgress = false;

  static Future<bool> maybeShow(
    BuildContext context,
    PremiumOfferContext offerContext,
  ) async {
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    if (user == null || user.hasPremiumAccess || _claimInProgress) return false;

    _claimInProgress = true;
    try {
      final response = await ApiClient().post(
        ApiConfig.usersPremiumOfferClaim,
        body: {'context': offerContext.apiValue},
        timeout: const Duration(seconds: 8),
      );
      final allowed =
          response is Map<String, dynamic> && response['allowed'] == true;
      if (!allowed ||
          !context.mounted ||
          !(ModalRoute.of(context)?.isCurrent ?? false)) {
        return false;
      }

      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (_) => PremiumScreen(offerContext: offerContext),
        ),
      );
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
