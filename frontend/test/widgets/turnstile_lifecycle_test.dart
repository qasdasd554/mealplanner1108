import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// Fakes implement the WebView plugin's platform contract, not a real WebView.
// ignore: depend_on_referenced_packages
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';
import 'package:smart_meal_planner/widgets/turnstile_widget.dart';
import 'package:smart_meal_planner/l10n/app_localizations.dart';

class _Platform extends WebViewPlatform {
  final controllers = <_Controller>[];
  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) {
    final result = _Controller(params);
    controllers.add(result);
    return result;
  }

  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) => _Navigation(params);
  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
    PlatformWebViewWidgetCreationParams params,
  ) => _View(params);
}

class _Navigation extends PlatformNavigationDelegate {
  _Navigation(super.params) : super.implementation();
  PageEventCallback? finished;
  WebResourceErrorCallback? error;
  @override
  Future<void> setOnPageFinished(PageEventCallback callback) async {
    finished = callback;
  }

  @override
  Future<void> setOnWebResourceError(WebResourceErrorCallback callback) async {
    error = callback;
  }
}

class _Controller extends PlatformWebViewController {
  _Controller(super.params) : super.implementation();
  JavaScriptChannelParams? channel;
  _Navigation? navigation;
  int reloads = 0;
  void send(String type, {String? token}) => channel!.onMessageReceived(
    JavaScriptMessage(message: jsonEncode({'type': type, 'token': token})),
  );
  void fail({bool mainFrame = true}) => navigation!.error!(
    WebResourceError(
      errorCode: -1,
      description: 'synthetic offline',
      isForMainFrame: mainFrame,
    ),
  );
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

  @override
  Future<void> reload() async {
    reloads++;
  }
}

class _View extends PlatformWebViewWidget {
  _View(super.params) : super.implementation();
  @override
  Widget build(BuildContext context) => const SizedBox();
}

Future<(_Platform, List<String?>)> _mount(
  WidgetTester tester, {
  Locale locale = const Locale('pl', 'PL'),
}) async {
  final previous = WebViewPlatform.instance;
  final platform = _Platform();
  WebViewPlatform.instance = platform;
  addTearDown(() => WebViewPlatform.instance = previous ?? _Platform());
  final tokens = <String?>[];
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: TurnstileWidget(onToken: tokens.add)),
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
  await tester.pumpAndSettle();
  return (platform, tokens);
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 13));
}

void main() {
  for (final english in [false, true]) {
    testWidgets('verification error/retry is readable in PL/GB: $english', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final (platform, _) = await _mount(
        tester,
        locale: english ? const Locale('en', 'GB') : const Locale('pl', 'PL'),
      );
      platform.controllers.single.fail();
      await tester.pump();
      expect(
        find.text(
          english
              ? 'Could not load verification. Check your connection.'
              : 'Nie udało się wczytać weryfikacji. Sprawdź połączenie.',
        ),
        findsOneWidget,
      );
      final retry = find.text(english ? 'Retry' : 'Ponów');
      expect(retry.hitTestable(), findsOneWidget);
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(platform.controllers, hasLength(2));
      expect(tester.takeException(), isNull);
      await _unmount(tester);
    });
  }
  testWidgets('initial resume does not reload the challenge', (tester) async {
    final (platform, tokens) = await _mount(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(platform.controllers.single.reloads, 0);
    expect(tokens, isEmpty);
    await _unmount(tester);
  });

  testWidgets('focus changes retain verification without reload loop', (
    tester,
  ) async {
    final (platform, tokens) = await _mount(tester);
    final controller = platform.controllers.single;
    controller.send('token', token: 'verified');
    for (var i = 0; i < 5; i++) {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
    }
    expect(controller.reloads, 0);
    expect(tokens, ['verified']);
    await _unmount(tester);
  });

  testWidgets('real background return invalidates token and reloads once', (
    tester,
  ) async {
    final (platform, tokens) = await _mount(tester);
    final controller = platform.controllers.single;
    controller.send('token', token: 'old-token');
    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pump();
    expect(controller.reloads, 1);
    expect(tokens, ['old-token', null]);
    await _unmount(tester);
  });

  testWidgets('disposed challenge cannot call its parent from late JS events', (
    tester,
  ) async {
    final (platform, tokens) = await _mount(tester);
    final controller = platform.controllers.single;
    await _unmount(tester);
    controller.send('token', token: 'late');
    controller.send('expired');
    controller.send('error');
    expect(tokens, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'main document failure revokes token; resource failure does not',
    (tester) async {
      final (platform, tokens) = await _mount(tester);
      final controller = platform.controllers.single;
      controller.send('token', token: 'verified');
      controller.fail(mainFrame: false);
      await tester.pump();
      expect(tokens, ['verified']);
      expect(find.text('Ponów'), findsNothing);
      controller.fail();
      await tester.pump();
      expect(tokens, ['verified', null]);
      expect(find.text('Ponów'), findsOneWidget);
      await _unmount(tester);
    },
  );

  testWidgets(
    'retry ignores messages and page events from replaced controller',
    (tester) async {
      final (platform, tokens) = await _mount(tester);
      final old = platform.controllers.single;
      old.fail();
      await tester.pump();
      await tester.tap(find.text('Ponów'));
      await tester.pumpAndSettle();
      expect(platform.controllers, hasLength(2));
      tokens.clear();
      old.send('token', token: 'stale');
      old.fail();
      old.navigation!.finished?.call('https://example.invalid/old');
      platform.controllers.last.send('token', token: 'fresh');
      await tester.pump();
      expect(tokens, ['fresh']);
      expect(find.text('Ponów'), findsNothing);
      await _unmount(tester);
    },
  );
}
