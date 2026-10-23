import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_storekit/store_kit_2_wrappers.dart';
import 'package:in_app_purchase_storekit/store_kit_wrappers.dart';

SubscriptionOfferDetailsWrapper? _googleOffer(
  GooglePlayProductDetails product,
) {
  final index = product.subscriptionIndex;
  final offers = product.productDetails.subscriptionOfferDetails;
  if (index == null || offers == null || index < 0 || index >= offers.length)
    return null;
  return offers[index];
}

/// A display claim, never an entitlement. Unknown/error means no free-trial
/// promise; the customer can still see the actual offer in the store sheet.
Future<bool> confirmedSevenDayTrial(
  ProductDetails product, {
  Future<bool> Function(String)? appleEligibility,
}) async {
  if (product.id != 'premium_monthly') return false;
  if (product is GooglePlayProductDetails) {
    final phases = _googleOffer(product)?.pricingPhases;
    if (phases == null || phases.length != 2) return false;
    final trial = phases.first, regular = phases.last;
    return trial.priceAmountMicros == 0 &&
        trial.billingCycleCount == 1 &&
        trial.recurrenceMode == RecurrenceMode.finiteRecurring &&
        const {'P7D', 'P1W'}.contains(trial.billingPeriod) &&
        regular.billingPeriod == 'P1M' &&
        regular.recurrenceMode == RecurrenceMode.infiniteRecurring &&
        regular.priceAmountMicros > 0 &&
        trial.priceCurrencyCode == regular.priceCurrencyCode;
  }
  bool configured = false;
  if (product is AppStoreProduct2Details) {
    final subscription = product.sk2Product.subscription;
    configured =
        subscription?.subscriptionPeriod.unit ==
            SK2SubscriptionPeriodUnit.month &&
        subscription?.subscriptionPeriod.value == 1 &&
        subscription!.promotionalOffers.any(
          (offer) =>
              offer.type == SK2SubscriptionOfferType.introductory &&
              offer.paymentMode == SK2SubscriptionOfferPaymentMode.freeTrial &&
              offer.price == 0 &&
              offer.periodCount == 1 &&
              ((offer.period.unit == SK2SubscriptionPeriodUnit.day &&
                      offer.period.value == 7) ||
                  (offer.period.unit == SK2SubscriptionPeriodUnit.week &&
                      offer.period.value == 1)),
        );
  } else if (product is AppStoreProductDetails) {
    final subscription = product.skProduct.subscriptionPeriod;
    final offer = product.skProduct.introductoryPrice;
    configured =
        subscription?.unit == SKSubscriptionPeriodUnit.month &&
        subscription?.numberOfUnits == 1 &&
        offer != null &&
        offer.type == SKProductDiscountType.introductory &&
        offer.paymentMode == SKProductDiscountPaymentMode.freeTrail &&
        double.tryParse(offer.price) == 0 &&
        offer.numberOfPeriods == 1 &&
        ((offer.subscriptionPeriod.unit == SKSubscriptionPeriodUnit.day &&
                offer.subscriptionPeriod.numberOfUnits == 7) ||
            (offer.subscriptionPeriod.unit == SKSubscriptionPeriodUnit.week &&
                offer.subscriptionPeriod.numberOfUnits == 1));
  }
  if (!configured || appleEligibility == null) return false;
  try {
    // Handle bridge errors on the source future before applying a timeout.
    // This also consumes a late native error after the deadline has elapsed.
    final eligibility = appleEligibility(product.id).then<bool>(
      (eligible) => eligible,
      onError: (Object _, StackTrace __) => false,
    );
    return await eligibility.timeout(
      const Duration(seconds: 3),
      onTimeout: () => false,
    );
  } catch (_) {
    return false;
  }
}

({double amount, String currency, String period})? _recurring(
  ProductDetails? product,
) {
  if (product == null) return null;
  if (product is GooglePlayProductDetails) {
    final recurring =
        _googleOffer(product)?.pricingPhases
            .where(
              (phase) =>
                  phase.recurrenceMode == RecurrenceMode.infiniteRecurring,
            )
            .toList();
    if (recurring == null ||
        recurring.length != 1 ||
        recurring.single.priceAmountMicros <= 0)
      return null;
    final phase = recurring.single;
    return (
      amount: phase.priceAmountMicros / 1000000,
      currency: phase.priceCurrencyCode,
      period: phase.billingPeriod,
    );
  }
  if (!product.rawPrice.isFinite || product.rawPrice <= 0) return null;
  String? period;
  if (product is AppStoreProduct2Details) {
    final value = product.sk2Product.subscription?.subscriptionPeriod;
    if (value?.value == 1) {
      period = switch (value!.unit) {
        SK2SubscriptionPeriodUnit.month => 'P1M',
        SK2SubscriptionPeriodUnit.year => 'P1Y',
        _ => null,
      };
    }
  } else if (product is AppStoreProductDetails) {
    final value = product.skProduct.subscriptionPeriod;
    if (value?.numberOfUnits == 1) {
      period = switch (value!.unit) {
        SKSubscriptionPeriodUnit.month => 'P1M',
        SKSubscriptionPeriodUnit.year => 'P1Y',
        _ => null,
      };
    }
  }
  return period == null
      ? null
      : (
        amount: product.rawPrice,
        currency: product.currencyCode,
        period: period,
      );
}

/// Conservative whole-percent saving on twelve regular months, same currency.
int? annualSavingsPercent(ProductDetails? monthly, ProductDetails? yearly) {
  final month = _recurring(monthly), year = _recurring(yearly);
  if (month == null ||
      year == null ||
      month.period != 'P1M' ||
      year.period != 'P1Y' ||
      month.currency != year.currency)
    return null;
  final monthlyMicros = (month.amount * 1000000).round();
  final yearlyMicros = (year.amount * 1000000).round();
  if (monthlyMicros <= 0 || yearlyMicros <= 0) return null;
  final totalMonthly = monthlyMicros * 12;
  final percent = ((totalMonthly - yearlyMicros) * 100) ~/ totalMonthly;
  return percent > 0 && percent < 100 ? percent : null;
}
