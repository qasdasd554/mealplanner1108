import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meal_planner/config/app_links.dart';
import 'package:smart_meal_planner/widgets/app_document_links.dart';

void main() {
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

  testWidgets('account links wrap at 320px and enlarged text', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MaterialApp(
        builder:
            (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(1.5)),
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
    expect(find.text('Kontakt'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
