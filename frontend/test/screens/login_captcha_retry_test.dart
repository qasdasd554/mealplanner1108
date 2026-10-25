import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
// The app-facing plugin intentionally hides the platform implementation APIs.
// ignore: depend_on_referenced_packages
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';
import 'package:smart_meal_planner/providers/auth_provider.dart';
import 'package:smart_meal_planner/screens/auth/login_screen.dart';
import 'package:smart_meal_planner/screens/auth/register_screen.dart';
import 'package:smart_meal_planner/l10n/app_localizations.dart';
import 'package:smart_meal_planner/l10n/market_locale.dart';

class _Auth extends ChangeNotifier implements AuthProvider {
  final attempts = <({String email, String password, String? token})>[];
  @override
  bool get isLoading => false;
  @override
  String? get errorMessage => 'Wrong password';
  @override
  String get postLoginRoute => '/home';
  @override
  Future<bool> login(
    String email,
    String password, {
    String? captchaToken,
  }) async {
    attempts.add((email: email, password: password, token: captchaToken));
    return attempts.length > 1;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _WebPlatform extends WebViewPlatform {
  final controllers = <_Controller>[];
  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) {
    final controller = _Controller(params);
    controllers.add(controller);
    return controller;
  }

  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) => _Navigation(params);
  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
    PlatformWebViewWidgetCreationParams params,
  ) => _WebWidget(params);
}

class _Navigation extends PlatformNavigationDelegate {
  _Navigation(super.params) : super.implementation();
  PageEventCallback? finished;
  @override
  Future<void> setOnPageFinished(PageEventCallback callback) async {
    finished = callback;
  }

  @override
  Future<void> setOnWebResourceError(WebResourceErrorCallback callback) async {}
}

class _Controller extends PlatformWebViewController {
  _Controller(super.params) : super.implementation();
  JavaScriptChannelParams? channel;
  _Navigation? navigation;
  void solve(String token) {
    channel!.onMessageReceived(
      JavaScriptMessage(message: jsonEncode({'type': 'token', 'token': token})),
    );
  }

  @override
  Future<void> setJavaScriptMode(JavaScriptMode mode) async {}
  @override
  Future<void> setBackgroundColor(Color color) async {}
  @override
  Future<void> addJavaScriptChannel(JavaScriptChannelParams params) async {
    channel = params;
  }

  @override
  Future<void> setPlatformNavigationDelegate(
    PlatformNavigationDelegate value,
  ) async {
    navigation = value as _Navigation;
  }

  @override
  Future<void> loadRequest(LoadRequestParams params) async {
    scheduleMicrotask(() => navigation?.finished?.call(params.uri.toString()));
  }
}

class _WebWidget extends PlatformWebViewWidget {
  _WebWidget(super.params) : super.implementation();
  @override
  Widget build(BuildContext context) => const SizedBox();
}

void main() {
  for (final region in ['PL', 'GB']) {
    testWidgets(
      'registration legal links use $region documents before account creation',
      (tester) async {
        final previous = WebViewPlatform.instance;
        WebViewPlatform.instance = _WebPlatform();
        addTearDown(
          () => WebViewPlatform.instance = previous ?? _WebPlatform(),
        );
        final auth = _Auth();
        addTearDown(auth.dispose);
        final launched = <String>[];
        const channel = MethodChannel('plugins.flutter.io/url_launcher');
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          (call) async {
            if (call.method == 'launch') {
              launched.add((call.arguments as Map)['url'] as String);
            }
            return true;
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            channel,
            null,
          ),
        );
        await tester.pumpWidget(
          ChangeNotifierProvider<AuthProvider>.value(
            value: auth,
            child: MaterialApp(
              locale: localeForMarket(deviceRegion: region),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              home: const RegisterScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        for (final label
            in region == 'GB'
                ? ['terms of use', 'privacy policy']
                : ['regulamin', 'politykę prywatności']) {
          final link = find.text(label);
          await tester.ensureVisible(link);
          await tester.pumpAndSettle();
          await tester.tap(link);
          await tester.pumpAndSettle();
        }
        final host =
            region == 'GB'
                ? 'https://mealplannerworld.com'
                : 'https://mealplannerpolska.pl';
        expect(launched, [
          '$host/terms-of-use.html',
          '$host/privacy-policy.html',
        ]);
        expect(auth.attempts, isEmpty);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 13));
      },
    );
  }

  testWidgets('wrong password refreshes CAPTCHA while preserving credentials', (
    tester,
  ) async {
    final platform = _WebPlatform();
    final previous = WebViewPlatform.instance;
    WebViewPlatform.instance = platform;
    addTearDown(() => WebViewPlatform.instance = previous ?? _WebPlatform());
    final auth = _Auth();
    addTearDown(auth.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: MaterialApp(
          home: const LoginScreen(),
          routes: {'/home': (_) => const Scaffold(body: Text('Signed in'))},
        ),
      ),
    );
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'person@example.com');
    await tester.enterText(fields.at(1), 'wrong-password');
    platform.controllers.single.solve('first-captcha-token');
    await tester.pump();
    final submit = find.byType(ElevatedButton);
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(auth.attempts.single.token, 'first-captcha-token');
    expect(platform.controllers, hasLength(2));
    expect(
      tester.widget<TextFormField>(fields.at(0)).controller!.text,
      'person@example.com',
    );
    expect(
      tester.widget<TextFormField>(fields.at(1)).controller!.text,
      'wrong-password',
    );
    // A retry before the replacement challenge is solved cannot reuse its token.
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(auth.attempts, hasLength(1));
    await tester.enterText(fields.at(1), 'correct-password');
    platform.controllers.last.solve('fresh-captcha-token');
    await tester.pump();
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(auth.attempts.map((attempt) => attempt.token), [
      'first-captcha-token',
      'fresh-captcha-token',
    ]);
    expect(auth.attempts.last.email, 'person@example.com');
    expect(auth.attempts.last.password, 'correct-password');
    expect(find.text('Signed in'), findsOneWidget);
    // The replaced login page must not receive late native JS callbacks.
    platform.controllers.first.solve('late-original-token');
    platform.controllers.last.solve('late-retry-token');
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 13));
  });
}
