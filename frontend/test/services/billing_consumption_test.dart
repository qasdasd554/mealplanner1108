import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
// The store plugin's existing platform contract is used only as a test fake.
// ignore: depend_on_referenced_packages
import 'package:in_app_purchase_platform_interface/in_app_purchase_platform_interface.dart';
import 'package:smart_meal_planner/services/billing_service.dart';

class _Store extends InAppPurchasePlatform {
  bool? autoConsumed;
  bool acceptsPurchase = true;
  int acknowledgements = 0;
  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {
    acknowledgements++;
  }

  @override
  Future<bool> buyConsumable({
    required PurchaseParam purchaseParam,
    bool autoConsume = true,
  }) async {
    autoConsumed = autoConsume;
    return acceptsPurchase;
  }

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async =>
      acceptsPurchase;
}

class _Addition extends InAppPurchasePlatformAddition
    implements InAppPurchaseAndroidPlatformAddition {
  BillingResponse response = BillingResponse.ok;
  int consumed = 0;
  @override
  Future<BillingResultWrapper> consumePurchase(PurchaseDetails purchase) async {
    consumed++;
    return BillingResultWrapper(
      responseCode: response,
      debugMessage: 'synthetic',
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    InAppPurchasePlatform.instance = _Store();
    BillingService();
    debugDefaultTargetPlatformOverride = null;
  });
  for (final response in [
    BillingResponse.ok,
    BillingResponse.itemNotOwned,
    BillingResponse.serviceUnavailable,
  ]) {
    test('verified Android points finish consumption: $response', () async {
      final original = InAppPurchasePlatform.instance;
      final additionOriginal = InAppPurchasePlatformAddition.instance;
      final store = _Store(), addition = _Addition()..response = response;
      InAppPurchasePlatform.instance = store;
      InAppPurchasePlatformAddition.instance = addition;
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() {
        InAppPurchasePlatform.instance = original;
        InAppPurchasePlatformAddition.instance = additionOriginal;
        debugDefaultTargetPlatformOverride = null;
      });
      final details = PurchaseDetails(
        productID: kPoints10ProductId,
        verificationData: PurchaseVerificationData(
          localVerificationData: '',
          serverVerificationData: 'test-only',
          source: 'google_play',
        ),
        transactionDate: '1',
        status: PurchaseStatus.purchased,
      );
      final result = BillingService().completePurchase(details);
      if (response == BillingResponse.serviceUnavailable) {
        await expectLater(result, throwsStateError);
      } else {
        await result;
      }
      expect(addition.consumed, 1);
      expect(store.acknowledgements, 0);
    });
  }
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    test(
      '$platform consumption cannot precede durable Android points credit',
      () async {
        final billing = BillingService();
        final original = InAppPurchasePlatform.instance;
        final store = _Store();
        InAppPurchasePlatform.instance = store;
        debugDefaultTargetPlatformOverride = platform;
        addTearDown(() {
          InAppPurchasePlatform.instance = original;
          debugDefaultTargetPlatformOverride = null;
        });
        await billing.buyPoints(
          ProductDetails(
            id: kPoints10ProductId,
            title: '',
            description: '',
            price: '£1',
            rawPrice: 1,
            currencyCode: 'GBP',
          ),
        );
        expect(store.autoConsumed, platform != TargetPlatform.android);
      },
    );
    for (final points in [false, true]) {
      test(
        '$platform declined purchase start is surfaced points=$points',
        () async {
          final original = InAppPurchasePlatform.instance;
          final store = _Store()..acceptsPurchase = false;
          InAppPurchasePlatform.instance = store;
          debugDefaultTargetPlatformOverride = platform;
          addTearDown(() {
            InAppPurchasePlatform.instance = original;
            debugDefaultTargetPlatformOverride = null;
          });
          final product = ProductDetails(
            id: points ? kPoints10ProductId : kMonthlyProductId,
            title: '',
            description: '',
            price: '£1',
            rawPrice: 1,
            currencyCode: 'GBP',
          );
          final billing = BillingService();
          await expectLater(
            points ? billing.buyPoints(product) : billing.buy(product),
            throwsStateError,
          );
        },
      );
    }
  }
}
