import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_storekit/store_kit_2_wrappers.dart';
import 'package:smart_meal_planner/utils/subscription_presentation.dart';

GooglePlayProductDetails android({
  String id = 'premium_monthly',
  int trial = 7,
  int cycles = 1,
  int amount = 4990000,
  String currency = 'GBP',
  String period = 'P1M',
  bool extraPhase = false,
}) {
  final phases = <PricingPhaseWrapper>[
    if (trial > 0)
      PricingPhaseWrapper(
        billingCycleCount: cycles,
        billingPeriod: 'P${trial}D',
        formattedPrice: '0',
        priceAmountMicros: 0,
        priceCurrencyCode: currency,
        recurrenceMode: RecurrenceMode.finiteRecurring,
      ),
    if (extraPhase)
      PricingPhaseWrapper(
        billingCycleCount: 1,
        billingPeriod: 'P1M',
        formattedPrice: '1',
        priceAmountMicros: 1000000,
        priceCurrencyCode: currency,
        recurrenceMode: RecurrenceMode.finiteRecurring,
      ),
    PricingPhaseWrapper(
      billingCycleCount: 0,
      billingPeriod: period,
      formattedPrice:
          '${currency == 'GBP' ? '£' : currency}${(amount / 1000000).toStringAsFixed(2)}',
      priceAmountMicros: amount,
      priceCurrencyCode: currency,
      recurrenceMode: RecurrenceMode.infiniteRecurring,
    ),
  ];
  return GooglePlayProductDetails.fromProductDetails(
    ProductDetailsWrapper(
      description: '',
      name: id,
      productId: id,
      productType: ProductType.subs,
      title: id,
      subscriptionOfferDetails: [
        SubscriptionOfferDetailsWrapper(
          basePlanId: 'base',
          offerId: trial == 0 ? null : 'trial',
          offerTags: [],
          offerIdToken: 'token',
          pricingPhases: phases,
        ),
      ],
    ),
  ).single;
}

AppStoreProduct2Details apple({
  int days = 7,
  double trialPrice = 0,
  SK2SubscriptionOfferType type = SK2SubscriptionOfferType.introductory,
}) => AppStoreProduct2Details.fromSK2Product(
  SK2Product(
    id: 'premium_monthly',
    displayName: 'Monthly',
    displayPrice: '£4.99',
    description: '',
    price: 4.99,
    type: SK2ProductType.autoRenewable,
    priceLocale: SK2PriceLocale(currencyCode: 'GBP', currencySymbol: '£'),
    subscription: SK2SubscriptionInfo(
      subscriptionGroupID: 'group',
      subscriptionPeriod: const SK2SubscriptionPeriod(
        value: 1,
        unit: SK2SubscriptionPeriodUnit.month,
      ),
      promotionalOffers: [
        SK2SubscriptionOffer(
          price: trialPrice,
          type: type,
          period: SK2SubscriptionPeriod(
            value: days,
            unit: SK2SubscriptionPeriodUnit.day,
          ),
          periodCount: 1,
          paymentMode: SK2SubscriptionOfferPaymentMode.freeTrial,
        ),
      ],
    ),
  ),
);

void main() {
  test(
    'Android confirms only an actual 7-day free phase then the regular month',
    () async {
      expect(await confirmedSevenDayTrial(android()), isTrue);
      expect(await confirmedSevenDayTrial(android(trial: 0)), isFalse);
      expect(await confirmedSevenDayTrial(android(trial: 3)), isFalse);
      expect(await confirmedSevenDayTrial(android(trial: 14)), isFalse);
      expect(await confirmedSevenDayTrial(android(cycles: 2)), isFalse);
      expect(await confirmedSevenDayTrial(android(extraPhase: true)), isFalse);
      expect(await confirmedSevenDayTrial(android(period: 'P1Y')), isFalse);
    },
  );
  test(
    'Apple needs configured free introductory period AND confirmed account eligibility',
    () async {
      expect(
        await confirmedSevenDayTrial(
          apple(),
          appleEligibility: (_) async => true,
        ),
        isTrue,
      );
      expect(
        await confirmedSevenDayTrial(
          apple(),
          appleEligibility: (_) async => false,
        ),
        isFalse,
      );
      expect(await confirmedSevenDayTrial(apple()), isFalse);
      expect(
        await confirmedSevenDayTrial(
          apple(),
          appleEligibility: (_) async => throw Exception('offline'),
        ),
        isFalse,
      );
    },
  );
  test(
    'Apple does not query eligibility for paid, wrong duration or promotional offer',
    () async {
      var queries = 0;
      Future<bool> check(String id) async {
        queries++;
        return true;
      }

      expect(
        await confirmedSevenDayTrial(apple(days: 3), appleEligibility: check),
        isFalse,
      );
      expect(
        await confirmedSevenDayTrial(
          apple(trialPrice: 1),
          appleEligibility: check,
        ),
        isFalse,
      );
      expect(
        await confirmedSevenDayTrial(
          apple(type: SK2SubscriptionOfferType.promotional),
          appleEligibility: check,
        ),
        isFalse,
      );
      expect(queries, 0);
    },
  );
  test(
    'Apple bridge failures, including a late error, never promise a trial',
    () async {
      expect(
        await confirmedSevenDayTrial(
          apple(),
          appleEligibility: (_) => throw StateError('bridge unavailable'),
        ),
        isFalse,
      );
      expect(
        await confirmedSevenDayTrial(
          apple(),
          appleEligibility:
              (_) => Future<bool>.delayed(
                const Duration(milliseconds: 3100),
                () => throw StateError('late error'),
              ),
        ),
        isFalse,
      );
      await Future<void>.delayed(const Duration(milliseconds: 200));
    },
  );
  test(
    'yearly saving compares actual same-currency recurring prices, never a fixed percentage',
    () {
      final monthly = android(trial: 7, amount: 5000000);
      final yearly = android(
        id: 'premium_yearly',
        trial: 0,
        amount: 48000000,
        period: 'P1Y',
      );
      expect(annualSavingsPercent(monthly, yearly), 20);
      expect(
        annualSavingsPercent(
          monthly,
          android(trial: 0, amount: 72000000, period: 'P1Y'),
        ),
        isNull,
      );
      expect(
        annualSavingsPercent(
          monthly,
          android(trial: 0, amount: 48000000, period: 'P1Y', currency: 'PLN'),
        ),
        isNull,
      );
      expect(
        annualSavingsPercent(
          monthly,
          android(trial: 0, amount: 48000000, period: 'P6M'),
        ),
        isNull,
      );
      expect(annualSavingsPercent(null, yearly), isNull);
    },
  );
  test(
    'untyped store data cannot establish a trial or subscription billing period',
    () async {
      final unknown = ProductDetails(
        id: 'premium_monthly',
        title: '',
        description: '',
        price: '£4.99',
        rawPrice: 4.99,
        currencyCode: 'GBP',
      );
      expect(await confirmedSevenDayTrial(unknown), isFalse);
      expect(annualSavingsPercent(unknown, unknown), isNull);
    },
  );
}
