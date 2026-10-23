import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:smart_meal_planner/l10n/app_localizations.dart';
import 'package:smart_meal_planner/screens/barcode_scanner_screen.dart';
import 'package:smart_meal_planner/models/barcode_lookup_result.dart';
import 'package:smart_meal_planner/utils/batch_tracking_payload.dart';

void main() {
  testWidgets('Escape cancels manual entry and leaves the scanner available', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BarcodeScannerScreen(
          controller: MobileScannerController(autoStart: false),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Wpisz kod ręcznie'));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(BarcodeScannerScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'invalid typed code stays editable and valid correction returns the exact GTIN',
    (tester) async {
      String? result;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en', 'GB'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Builder(
            builder:
                (context) => Scaffold(
                  body: TextButton(
                    child: const Text('Open scanner'),
                    onPressed: () async {
                      result = await Navigator.of(context).push<String>(
                        MaterialPageRoute(
                          builder:
                              (_) => BarcodeScannerScreen(
                                controller: MobileScannerController(
                                  autoStart: false,
                                ),
                              ),
                        ),
                      );
                    },
                  ),
                ),
          ),
        ),
      );
      await tester.tap(find.text('Open scanner'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enter code manually'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '1234567890123');
      await tester.tap(find.widgetWithText(FilledButton, 'Search'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('1234567890123'), findsOneWidget);
      expect(result, isNull);
      await tester.enterText(find.byType(TextField), '5901234123457');
      await tester.tap(find.widgetWithText(FilledButton, 'Search'));
      await tester.pumpAndSettle();
      expect(result, '5901234123457');
      expect(find.text('Open scanner'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'manual code dialog can be cancelled without disposing a live controller',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BarcodeScannerScreen(
            controller: MobileScannerController(autoStart: false),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('Wpisz kod ręcznie'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '5901234123457');
      await tester.tap(find.text('Anuluj'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('GB scanner exposes English camera and manual-entry labels', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en', 'GB'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: BarcodeScannerScreen(
          controller: MobileScannerController(autoStart: false),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Scan barcode'), findsOneWidget);
    expect(find.text('Enter code manually'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  for (final size in [double.infinity, double.nan, 100001.0]) {
    test(
      'non-physical/unacceptable package size $size is never a confirmed batch pack',
      () {
        final item = BarcodeLookupResult(
          found: true,
          unit: 'g',
          servingQuantity: size,
          kcalPer100: 200,
          proteinPer100: 10,
          fatPer100: 2,
          carbsPer100: 30,
        );
        expect(hasKnownBarcodePackageSize(item), isFalse);
      },
    );
  }
}
