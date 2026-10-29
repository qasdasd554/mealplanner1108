import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_meal_planner/l10n/app_localizations.dart';
import 'package:smart_meal_planner/models/user.dart';
import 'package:smart_meal_planner/providers/auth_provider.dart';
import 'package:smart_meal_planner/screens/profile/premium_screen.dart';
import 'package:smart_meal_planner/services/api_client.dart';
import 'package:smart_meal_planner/services/auth_service.dart';
import 'package:smart_meal_planner/services/billing_service.dart';

class _Auth extends AuthService {
  bool offline = false;
  @override
  Future<User> getProfile() async {
    if (offline) throw ApiException(503, 'offline');
    return User(
      id: 'qa',
      email: 'qa@example.invalid',
      householdSize: 1,
      createdAt: DateTime(2026),
      premiumPoints: 4,
    );
  }

  @override
  Future<bool> attemptGoogleSilentLogin() async => false;
}

class _Api implements ApiClient {
  @override
  Future<dynamic> get(String path, {Duration? timeout}) async => [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Billing extends BillingService {
  final events = StreamController<List<PurchaseDetails>>.broadcast();
  final pending = Completer<Map<String, dynamic>>();
  int verifications = 0, completed = 0;
  bool completionFails = false;
  final pointResults = <Future<int>>[];
  @override
  Stream<List<PurchaseDetails>> get purchaseStream => events.stream;
  @override
  Future<bool> isAvailable() async => true;
  @override
  Future<ProductDetailsResponse> queryProducts() async =>
      ProductDetailsResponse(
        productDetails: [
          ProductDetails(
            id: kMonthlyProductId,
            title: 'Monthly',
            description: '',
            price: '£4.99',
            rawPrice: 4.99,
            currencyCode: 'GBP',
          ),
        ],
        notFoundIDs: [],
      );
  @override
  Future<ProductDetailsResponse> queryPointsProducts() async =>
      ProductDetailsResponse(productDetails: [], notFoundIDs: []);
  @override
  Future<Map<String, dynamic>> verifyPurchase({
    required String purchaseToken,
    required String productId,
  }) {
    verifications++;
    return pending.future;
  }

  @override
  Future<Map<String, dynamic>> restoreOnBackend({
    required String purchaseToken,
    required String productId,
  }) => verifyPurchase(purchaseToken: purchaseToken, productId: productId);
  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {
    completed++;
    if (completionFails) throw StateError('native completion unavailable');
  }

  @override
  Future<void> restorePurchases() async {}
  @override
  Future<int> verifyPointsPurchase({
    required String purchaseToken,
    required String productId,
  }) {
    verifications++;
    return pointResults.removeAt(0);
  }
}

PurchaseDetails purchase({PurchaseStatus status = PurchaseStatus.purchased}) =>
    PurchaseDetails(
      purchaseID: 'qa-purchase',
      productID: kMonthlyProductId,
      verificationData: PurchaseVerificationData(
        localVerificationData: '',
        serverVerificationData: 'synthetic-test-token',
        source: 'google_play',
      ),
      transactionDate: '1',
      status: status,
    )..pendingCompletePurchase = true;

Future<AuthProvider> open(
  WidgetTester tester,
  _Billing billing,
  bool english, {
  _Auth? service,
}) async {
  SharedPreferences.setMockInitialValues({});
  final auth = AuthProvider(
    service: service ?? _Auth(),
    readToken: () async => null,
  );
  await auth.initialization;
  if (service != null) await auth.loadProfile();
  addTearDown(auth.dispose);
  addTearDown(billing.events.close);
  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: auth,
      child: MaterialApp(
        locale: english ? const Locale('en', 'GB') : const Locale('pl', 'PL'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: PremiumScreen(
          billing: billing,
          client: _Api(),
          popAfterSuccess: false,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return auth;
}

void main() {
  for (final english in [false, true]) {
    final market = english ? 'GB' : 'PL';
    testWidgets(
      '$market late purchase responses cannot update another session',
      (tester) async {
        final auth = await open(tester, _Billing(), english, service: _Auth());
        expect(
          auth.applyVerifiedPoints(
            userId: 'qa',
            session: auth.sessionGeneration + 1,
            balance: 500,
          ),
          isFalse,
        );
        expect(
          auth.applyVerifiedPoints(
            userId: 'other-user',
            session: auth.sessionGeneration,
            balance: 500,
          ),
          isFalse,
        );
        expect(
          auth.applyVerifiedSubscription(
            userId: 'qa',
            session: auth.sessionGeneration + 1,
            result: {
              'is_premium': true,
              'premium_product_id': kMonthlyProductId,
              'premium_expires_at':
                  DateTime.now().add(const Duration(days: 7)).toIso8601String(),
            },
          ),
          isFalse,
        );
        expect(auth.currentUser!.premiumPoints, 4);
        expect(auth.currentUser!.hasPremiumAccess, isFalse);
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets(
      '$market committed points remain visible if profile refresh is offline',
      (tester) async {
        final billing = _Billing();
        final service = _Auth();
        final auth = await open(tester, billing, english, service: service);
        service.offline = true;
        billing.pointResults.add(Future.value(14));
        final details = PurchaseDetails(
          purchaseID: 'points-offline',
          productID: kPoints10ProductId,
          verificationData: PurchaseVerificationData(
            localVerificationData: '',
            serverVerificationData: 'synthetic-offline-token',
            source: 'google_play',
          ),
          transactionDate: '1',
          status: PurchaseStatus.purchased,
        )..pendingCompletePurchase = true;
        billing.events.add([details]);
        await tester.pumpAndSettle();
        expect(auth.currentUser!.premiumPoints, 14);
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets(
      '$market verified subscription activates when optional profile GET is offline',
      (tester) async {
        final billing = _Billing();
        final service = _Auth();
        final auth = await open(tester, billing, english, service: service);
        service.offline = true;
        billing.events.add([purchase()]);
        await tester.pump();
        billing.pending.complete({
          'is_premium': true,
          'premium_product_id': kMonthlyProductId,
          'premium_expires_at':
              DateTime.now()
                  .toUtc()
                  .add(const Duration(days: 7))
                  .toIso8601String(),
        });
        await tester.pumpAndSettle();
        expect(auth.currentUser!.hasPremiumAccess, isTrue);
        expect(tester.takeException(), isNull);
        // Dispose the synthetic subscription's long timer before the widget
        // binding checks its fake clock; production still keeps that timer.
        service.offline = false;
        await auth.loadProfile();
      },
    );
    testWidgets('$market duplicate store events share one verification', (
      tester,
    ) async {
      final billing = _Billing();
      await open(tester, billing, english);
      billing.events.add([purchase()]);
      await tester.pump();
      billing.events.add([purchase()]);
      await tester.pump();
      expect(billing.verifications, 1);
      billing.pending.complete({'is_premium': true});
      await tester.pumpAndSettle();
      expect(billing.completed, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('$market failed native error completion is handled', (
      tester,
    ) async {
      final billing = _Billing()..completionFails = true;
      await open(tester, billing, english);
      billing.events.add([purchase(status: PurchaseStatus.error)]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
    });

    testWidgets('$market restore does not report empty during verification', (
      tester,
    ) async {
      final billing = _Billing();
      await open(tester, billing, english);
      final restore = find.text(
        english ? 'Restore purchases' : 'Przywróć zakupy',
      );
      await tester.scrollUntilVisible(restore, 500, maxScrolls: 35);
      await tester.tap(restore);
      await tester.pump();
      billing.events.add([purchase(status: PurchaseStatus.restored)]);
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      expect(
        find.text(
          english
              ? 'There are no previous purchases to restore.'
              : 'Nie znaleziono żadnych wcześniejszych zakupów do przywrócenia.',
        ),
        findsNothing,
      );
      billing.pending.complete({'is_premium': true});
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('$market disposal stops remaining stream batch UI callbacks', (
      tester,
    ) async {
      final billing = _Billing();
      await open(tester, billing, english);
      billing.events.add([purchase(), purchase()]);
      await tester.pump();
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      billing.pending.complete({'is_premium': true});
      await tester.pumpAndSettle();
      expect(billing.verifications, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      '$market points are not completed before server accepts; retry is possible',
      (tester) async {
        final billing = _Billing();
        final first = Completer<int>(), second = Completer<int>();
        billing.pointResults.addAll([first.future, second.future]);
        await open(tester, billing, english);
        final details = PurchaseDetails(
          purchaseID: 'points-recovery',
          productID: kPoints10ProductId,
          verificationData: PurchaseVerificationData(
            localVerificationData: '',
            serverVerificationData: 'synthetic-points-token',
            source: 'google_play',
          ),
          transactionDate: '1',
          status: PurchaseStatus.purchased,
        )..pendingCompletePurchase = true;
        billing.events.add([details]);
        await tester.pump();
        first.completeError(ApiException(503, 'offline'));
        await tester.pumpAndSettle();
        expect(billing.completed, 0);
        billing.events.add([details]);
        await tester.pump();
        second.complete(10);
        await tester.pumpAndSettle();
        expect(billing.verifications, 2);
        expect(billing.completed, 1);
        billing.events.add([details]);
        await tester.pumpAndSettle();
        expect(billing.verifications, 2);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
