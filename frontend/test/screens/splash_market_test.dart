import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:smart_meal_planner/l10n/app_localizations.dart';
import 'package:smart_meal_planner/providers/auth_provider.dart';
import 'package:smart_meal_planner/screens/splash_screen.dart';

void main() {
  for (final english in [false, true]) {
    testWidgets(
      'splash has no guessed-language subtitle while session loads EN=$english',
      (tester) async {
        final pending = Completer<String?>();
        final auth = AuthProvider(readToken: () => pending.future);
        addTearDown(auth.dispose);
        const channel = MethodChannel(
          'com.meal_planner_polska_v1/share_intent',
        );
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          (_) async => null,
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
              locale: english ? const Locale('en', 'GB') : const Locale('pl'),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              home: const SplashScreen(),
              routes: {
                '/login':
                    (_) => const Scaffold(body: Text('Login destination')),
              },
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text('Meal Planner'), findsOneWidget);
        expect(
          find.text('Planuj posiłki mądrze i oszczędzaj').hitTestable(),
          findsNothing,
        );
        expect(
          find.text('Plan meals wisely and save').hitTestable(),
          findsNothing,
        );
        pending.complete(null);
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();
        expect(find.text('Login destination'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final english in [false, true]) {
    testWidgets('storage failure still reaches login EN=$english', (
      tester,
    ) async {
      const channel = MethodChannel('com.meal_planner_polska_v1/share_intent');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (_) async => null,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      final auth = AuthProvider(
        readToken:
            () async => throw PlatformException(code: 'storage-unavailable'),
      );
      addTearDown(auth.dispose);
      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>.value(
          value: auth,
          child: MaterialApp(
            locale: english ? const Locale('en', 'GB') : const Locale('pl'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: const SplashScreen(),
            routes: {
              '/login': (_) => const Scaffold(body: Text('Login destination')),
            },
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.text('Login destination'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
    testWidgets(
      'splash localizes subtitle and preserves signed-out routing EN=$english',
      (tester) async {
        final methods = <String>[];
        const channel = MethodChannel(
          'com.meal_planner_polska_v1/share_intent',
        );
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          (call) async {
            methods.add(call.method);
            return null;
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            channel,
            null,
          ),
        );
        final auth = AuthProvider(readToken: () async => null);
        await auth.initialization;
        addTearDown(auth.dispose);
        await tester.pumpWidget(
          ChangeNotifierProvider<AuthProvider>.value(
            value: auth,
            child: MaterialApp(
              locale: english ? const Locale('en', 'GB') : const Locale('pl'),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              home: const SplashScreen(),
              routes: {
                '/login':
                    (_) => const Scaffold(body: Text('Login destination')),
              },
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text('Meal Planner'), findsOneWidget);
        expect(
          find.text(
            english
                ? 'Plan meals wisely and save'
                : 'Planuj posiłki mądrze i oszczędzaj',
          ),
          findsOneWidget,
        );
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();
        expect(find.text('Login destination'), findsOneWidget);
        expect(methods, ['getInitialSharedText', 'getInitialDeepLink']);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
