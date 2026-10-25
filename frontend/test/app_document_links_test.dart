import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meal_planner/config/app_links.dart';
import 'package:smart_meal_planner/widgets/app_document_links.dart';
import 'package:smart_meal_planner/l10n/app_localizations.dart';
import 'package:smart_meal_planner/l10n/market_locale.dart';

void main() {
  for (final country in ['PL', 'GB']) {
    testWidgets(
      'document destinations follow account $country, not phone region',
      (tester) async {
        final opened = <Uri>[];
        final english = country == 'GB';
        await tester.pumpWidget(
          MaterialApp(
            locale: localeForMarket(
              accountCountry: country,
              deviceRegion: english ? 'PL' : 'GB',
            ),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: Scaffold(
              body: AppDocumentLinks(
                showAccountHelp: true,
                openLink: (uri) async {
                  opened.add(uri);
                  return true;
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        for (final label
            in english
                ? [
                  'Terms of Use (EULA)',
                  'Privacy policy',
                  'Account deletion information',
                  'Help',
                  'Contact',
                ]
                : [
                  'Regulamin (EULA)',
                  'Polityka prywatności',
                  'Usuwanie konta — informacje',
                  'Pomoc',
                  'Kontakt',
                ]) {
          await tester.tap(find.text(label));
          await tester.pump();
        }
        final host =
            english
                ? 'https://mealplannerworld.com'
                : 'https://mealplannerpolska.pl';
        final email =
            english
                ? 'support@mealplannerworld.com'
                : 'kontakt@mealplannerpolska.pl';
        expect(opened.map((uri) => uri.toString()), [
          '$host/terms-of-use.html',
          '$host/privacy-policy.html',
          '$host/delete-account.html',
          '$host/support.html',
          'mailto:$email',
        ]);
        expect(find.text(email), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('UK mail fallback copies the displayed UK support address', (
    tester,
  ) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en', 'GB'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(body: AppDocumentLinks(openLink: (_) async => false)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Contact'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<SelectableText>(find.byType(SelectableText)).data,
      'support@mealplannerworld.com',
    );
    await tester.tap(find.text('Copy address'));
    await tester.pumpAndSettle();
    expect(copied, 'support@mealplannerworld.com');
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('legal, support and mail links use the verified public domain', (
    tester,
  ) async {
    final opened = <Uri>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppDocumentLinks(
            showAccountHelp: true,
            openLink: (uri) async {
              opened.add(uri);
              return true;
            },
          ),
        ),
      ),
    );
    for (final label in [
      'Regulamin (EULA)',
      'Polityka prywatności',
      'Usuwanie konta — informacje',
      'Pomoc',
      'Kontakt',
    ]) {
      await tester.tap(find.text(label));
      await tester.pump();
    }
    expect(opened.map((uri) => uri.toString()), [
      AppLinks.terms,
      AppLinks.privacy,
      AppLinks.accountDeletion,
      AppLinks.support,
      'mailto:${AppLinks.contactEmail}',
    ]);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'missing mail application offers a readable address and copy action',
    (tester) async {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (_) async => null,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: AppDocumentLinks(openLink: (_) async => false)),
        ),
      );
      await tester.tap(find.text('Kontakt'));
      await tester.pumpAndSettle();
      expect(find.byType(SelectableText), findsOneWidget);
      expect(find.text('Kopiuj adres'), findsOneWidget);
      await tester.tap(find.text('Kopiuj adres'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('failed browser opening is reported, not silently ignored', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppDocumentLinks(
            openLink: (_) async => throw StateError('No browser'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Regulamin (EULA)'));
    await tester.pump();
    expect(
      find.text('Nie udało się otworzyć dokumentu. Spróbuj ponownie.'),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 5));
    expect(tester.takeException(), isNull);
  });

  for (final country in ['PL', 'GB']) {
    testWidgets('account $country links wrap at 320px and enlarged text', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 568);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        MaterialApp(
          locale: localeForMarket(accountCountry: country),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          builder:
              (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(1.5)),
                child: child!,
              ),
          home: const Scaffold(
            body: SingleChildScrollView(
              padding: EdgeInsets.all(24),
              child: AppDocumentLinks(showAccountHelp: true),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(country == 'GB' ? 'Contact' : 'Kontakt'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
