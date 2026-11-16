// FlutterFire exposes the test doubles through its platform packages.
// ignore_for_file: depend_on_referenced_packages

import 'package:firebase_analytics_platform_interface/firebase_analytics_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_meal_planner/models/premium_offer.dart';
import 'package:smart_meal_planner/services/product_analytics.dart';

class _RecordingAnalytics extends FirebaseAnalyticsPlatform {
  final collection = <bool>[];
  final events = <(String, Map<String, Object?>?)>[];

  @override
  FirebaseAnalyticsPlatform delegateFor({
    required FirebaseApp app,
    Map<String, dynamic>? webOptions,
  }) => this;

  @override
  Future<void> setAnalyticsCollectionEnabled(bool enabled) async {
    collection.add(enabled);
  }

  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object?>? parameters,
    AnalyticsCallOptions? callOptions,
  }) async {
    events.add((name, parameters));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'analytics records visible tabs and actions only while opted in',
    () async {
      setupFirebaseCoreMocks();
      await Firebase.initializeApp();
      SharedPreferences.setMockInitialValues({});
      final platform = _RecordingAnalytics();
      final originalPlatform = FirebaseAnalyticsPlatform.instance;
      FirebaseAnalyticsPlatform.instance = platform;
      addTearDown(() => FirebaseAnalyticsPlatform.instance = originalPlatform);

      final analytics = ProductAnalytics.instance;
      final home = MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/home'),
        builder: (_) => const SizedBox.shrink(),
      );
      final premium = MaterialPageRoute<void>(
        builder: (_) => const SizedBox.shrink(),
      );

      analytics.setMarket('GB');
      await analytics.initialize();
      analytics.didChangeTop(home, null);
      analytics.newPlanTapped();
      expect(platform.collection, [false]);
      expect(platform.events, isEmpty);

      expect(await analytics.setEnabled(true), isTrue);
      analytics.selectHomeTab(home, 4);
      analytics.selectHomeTab(home, 4);
      analytics.premiumCheckoutTapped('premium_tab');
      analytics.selectHomeTab(home, 0);
      analytics.newPlanTapped();
      analytics.mealPlanGenerated();

      analytics.setMarket('DE');
      analytics.didChangeTop(premium, home);
      analytics.describePremiumPage(
        premium,
        ProductAnalytics.premiumEntryPoint(
          offerContext: PremiumOfferContext.pantry,
          shoppingListLimit: false,
          fromTab: false,
        ),
      );
      expect(platform.events.map((event) => event.$1), [
        'screen_view',
        'screen_view',
        'premium_offer_view',
        'premium_checkout_tap',
        'screen_view',
        'new_plan_tap',
        'meal_plan_generated',
        'screen_view',
        'premium_offer_view',
      ]);
      expect(platform.events[2].$2, {
        'entry_point': 'premium_tab',
        'app_market': 'GB',
      });
      expect(platform.events.last.$2, {
        'entry_point': 'pantry',
        'app_market': 'DE',
      });

      expect(await analytics.setEnabled(false), isTrue);
      analytics.setMarket('PL');
      analytics.newPlanTapped();
      expect(platform.collection, [false, true, false]);
      expect(platform.events, hasLength(9));
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getBool('product_analytics_enabled'), isFalse);
    },
  );
}
