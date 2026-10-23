import 'package:flutter/foundation.dart';
import '../models/premium_offer.dart';

/// Non-blocking local signal, emitted only after a successful write.
/// It never opens a screen from a service, camera or an amount-entry sheet.
class PremiumOfferSuccessSignal {
  static final events =
      ValueNotifier<({int serial, PremiumOfferContext context})>((
        serial: 0,
        context: PremiumOfferContext.journal,
      ));

  static void record(PremiumOfferContext context) {
    events.value = (serial: events.value.serial + 1, context: context);
  }
}
