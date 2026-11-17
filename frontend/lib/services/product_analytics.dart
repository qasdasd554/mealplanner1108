import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/premium_offer.dart';

enum AnalyticsShortcut {
  promotions('promotions'),
  products('products'),
  pantry('pantry'),
  scanProduct('scan_product'),
  batchScan('batch_scan'),
  scanReceipt('scan_receipt'),
  aiRecipe('ai_recipe'),
  addMeal('add_meal'),
  addToPantry('add_to_pantry');

  const AnalyticsShortcut(this.eventKey);
  final String eventKey;
}

enum AnalyticsShortcutSurface {
  homeShortcuts('home_shortcuts'),
  quickAdd('quick_add');

  const AnalyticsShortcutSurface(this.eventKey);
  final String eventKey;
}

class ProductAnalytics extends NavigatorObserver {
  ProductAnalytics._();

  static final instance = ProductAnalytics._();
  static const _preferenceKey = 'product_analytics_enabled';
  static const _homeTabs = [
    'home',
    'recipes',
    'shopping_list',
    'tracker',
    'premium',
    'profile',
  ];
  static const _screenNames = {
    '/login': 'login',
    '/register': 'register',
    '/onboarding': 'onboarding',
    '/plan/config': 'plan_config',
    '/plan/view': 'meal_plan',
    '/plan/archive': 'plan_archive',
    '/profile/ingredients': 'ingredient_preferences',
    '/shopping': 'shopping_list',
    '/recipes': 'recipes',
    '/recipe/detail': 'recipe_detail',
    '/pantry': 'pantry',
    '/profile': 'profile',
    '/products': 'products',
    '/tracker': 'tracker',
    '/tracker/add': 'tracker_add',
    '/promotions': 'promotions',
    '/notifications': 'notifications',
  };

  final _choice = ValueNotifier<bool?>(null);
  final _selectedTabs = Expando<int>();
  final _premiumPages = Expando<String>();
  SharedPreferences? _preferences;
  bool _hasDecided = false;
  Route<dynamic>? _currentPage;
  String? _market;

  ValueListenable<bool?> get choice => _choice;
  bool get needsChoice => _preferences != null && !_hasDecided;

  Future<void> initialize() async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return;
    }
    try {
      final preferences = await SharedPreferences.getInstance();
      final savedChoice = preferences.getBool(_preferenceKey);
      final enabled = savedChoice ?? false;
      await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(enabled);
      _preferences = preferences;
      _hasDecided = savedChoice != null;
      _choice.value = enabled;
      if (enabled) _logCurrentScreen();
    } catch (_) {
      debugPrint('[Analytics] Initialization unavailable');
    }
  }

  Future<bool> setEnabled(bool enabled) async {
    final preferences = _preferences;
    final previous = _choice.value;
    if (preferences == null || previous == null) return false;
    final savedChoice = preferences.getBool(_preferenceKey);
    if (savedChoice == enabled) return true;
    if (!enabled) _choice.value = false;
    try {
      if (!await preferences.setBool(_preferenceKey, enabled)) {
        throw StateError('Could not save analytics preference');
      }
      if (previous != enabled) {
        await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(enabled);
      }
      _hasDecided = true;
      _choice.value = enabled;
      if (enabled) _logCurrentScreen();
      return true;
    } catch (_) {
      try {
        if (savedChoice == null) {
          await preferences.remove(_preferenceKey);
        } else {
          await preferences.setBool(_preferenceKey, savedChoice);
        }
      } catch (_) {
        debugPrint('[Analytics] Could not restore preference');
      }
      // An explicit refusal can finish setup even if local storage failed.
      if (!enabled && !previous) _hasDecided = true;
      _choice.value = previous;
      return false;
    }
  }

  void setMarket(String? countryCode) {
    _market = switch (countryCode) {
      'PL' || 'GB' || 'DE' => countryCode,
      _ => null,
    };
  }

  @override
  void didChangeTop(Route<dynamic> topRoute, Route<dynamic>? previousTopRoute) {
    // Dialogs belong to the page that opened them.
    if (topRoute is! PageRoute || identical(topRoute, _currentPage)) return;
    _currentPage = topRoute;
    final name = topRoute.settings.name;
    if (name == '/home' ||
        _screenNames.containsKey(name) ||
        _premiumPages[topRoute] != null) {
      _logCurrentScreen();
    } else if (name != '/' && _choice.value == true) {
      // Some paywalls use unnamed routes and are identified when built.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (identical(topRoute, _currentPage) &&
            _premiumPages[topRoute] == null) {
          _logCurrentScreen();
        }
      });
    }
  }

  void selectHomeTab(Route<dynamic>? homeRoute, int index) {
    if (homeRoute == null || _homeTabIndex(homeRoute) == index) return;
    _selectedTabs[homeRoute] = index;
    if (!identical(homeRoute, _currentPage)) return;
    _logCurrentScreen();
  }

  void newPlanTapped() => _event('new_plan_tap');

  void mealPlanGenerated() => _event('meal_plan_generated');

  void shortcutTapped(
    AnalyticsShortcut shortcut,
    AnalyticsShortcutSurface surface,
  ) => _event(
    'feature_${shortcut.eventKey}_tap',
    parameters: {'entry_point': surface.eventKey},
  );

  static String premiumEntryPoint({
    required PremiumOfferContext? offerContext,
    required bool shoppingListLimit,
    required bool fromTab,
  }) =>
      offerContext?.apiValue ??
      (shoppingListLimit ? 'shopping_list_limit' : null) ??
      (fromTab ? 'premium_tab' : 'direct');

  void describePremiumPage(Route<dynamic>? route, String entryPoint) {
    if (route == null || _premiumPages[route] != null) return;
    _premiumPages[route] = entryPoint;
    if (identical(route, _currentPage)) _logCurrentScreen();
  }

  void premiumCheckoutTapped(String entryPoint) =>
      _event('premium_checkout_tap', parameters: {'entry_point': entryPoint});

  int _homeTabIndex(Route<dynamic> route) {
    final initialIndex = route.settings.arguments;
    return _selectedTabs[route] ??
        (initialIndex is int ? initialIndex.clamp(0, _homeTabs.length - 1) : 0);
  }

  void _logCurrentScreen() {
    final route = _currentPage;
    if (route == null || route.settings.name == '/') return;
    final premiumEntry = _premiumPages[route];
    final screen =
        route.settings.name == '/home'
            ? _homeTabs[_homeTabIndex(route)]
            : premiumEntry != null
            ? 'premium'
            : _screenNames[route.settings.name] ?? 'other';
    _send(
      (analytics) => analytics.logScreenView(
        screenName: screen,
        screenClass: screen,
        parameters: {if (_market case final market?) 'app_market': market},
      ),
    );
    if (premiumEntry != null ||
        (route.settings.name == '/home' && screen == 'premium')) {
      _event(
        'premium_offer_view',
        parameters: {'entry_point': premiumEntry ?? 'premium_tab'},
      );
    }
  }

  void _event(String name, {Map<String, Object> parameters = const {}}) {
    _send(
      (analytics) => analytics.logEvent(
        name: name,
        parameters: {
          ...parameters,
          if (_market case final market?) 'app_market': market,
        },
      ),
    );
  }

  void _send(Future<void> Function(FirebaseAnalytics) send) {
    if (_choice.value != true) return;
    unawaited(_sendSafely(send));
  }

  Future<void> _sendSafely(
    Future<void> Function(FirebaseAnalytics) send,
  ) async {
    try {
      await send(FirebaseAnalytics.instance);
    } catch (_) {
      debugPrint('[Analytics] Event unavailable');
    }
  }
}
