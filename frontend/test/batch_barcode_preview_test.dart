import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:smart_meal_planner/screens/batch_barcode_scanner_screen.dart';

void main() {
  testWidgets(
    'podgląd Premium nie uruchamia aparatu i mieści się na małym ekranie',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 568);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          routes: {
            '/premium': (_) => const Scaffold(body: Text('Ekran Premium')),
          },
          home: const BatchBarcodeScannerScreen(previewOnly: true),
        ),
      );

      expect(find.byType(MobileScanner), findsNothing);
      expect(find.text('Podgląd funkcji Premium'), findsOneWidget);
      expect(find.text('Wypróbuj Premium przez 7 dni'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Wypróbuj Premium przez 7 dni'));
      await tester.pumpAndSettle();
      expect(find.text('Ekran Premium'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
