import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meal_planner/l10n/app_localizations.dart';
import 'package:smart_meal_planner/services/price_compare_service.dart';
import 'package:smart_meal_planner/theme/app_theme.dart';
import 'package:smart_meal_planner/widgets/store_price_comparison_card.dart';

void main() {
  var proofFont = 'Roboto';
  setUpAll(() async {
    await (FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    final font = File('C:/Windows/Fonts/arial.ttf');
    if (await font.exists()) {
      await (FontLoader('UKPriceProof')
        ..addFont(font.readAsBytes().then(ByteData.sublistView))).load();
      proofFont = 'UKPriceProof';
    }
  });
  tearDown(() => AppTheme.setDark(false));

  for (final dark in [false, true]) {
    for (final scale in [1.5, 2.0]) {
      testWidgets('GB package comparison fits 320 px, scale=$scale, dark=$dark', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final boundaryKey = GlobalKey();
        AppTheme.setDark(dark);
        final baseTheme = dark ? AppTheme.darkTheme : AppTheme.lightTheme;
        final result = PriceComparisonResult.fromJson({
          'store_id': 'GB-store',
          'store_name': "Sainsbury’s",
          'total_price': 2.1,
          'currency_code': 'GBP',
          'is_complete': true,
          'is_cheapest': true,
          'has_estimated_prices': true,
          'items': [
            {
              'product_name': 'Wholegrain pasta — local pack',
              'quantity_needed': 600,
              'unit': 'g',
              'price_in_store': 2.1,
              'price_is_estimated': true,
              'package_quantity': 250,
              'package_unit': 'g',
              'package_count': 3,
              'purchased_quantity': 750,
              'price_per_package': 0.7,
            },
          ],
        });
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('en', 'GB'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            theme: baseTheme.copyWith(
              textTheme: baseTheme.textTheme.apply(fontFamily: proofFont),
              outlinedButtonTheme: OutlinedButtonThemeData(
                style: baseTheme.outlinedButtonTheme.style?.copyWith(
                  textStyle: WidgetStatePropertyAll(
                    TextStyle(
                      fontFamily: proofFont,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            builder:
                (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
            home: RepaintBoundary(
              key: boundaryKey,
              child: Scaffold(
                body: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: StorePriceComparisonCard(
                    result: result,
                    onSwitchStore: () {},
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text("Sainsbury’s"));
        await tester.pumpAndSettle();
        expect(find.textContaining('To buy: 3 × 250 g'), findsOneWidget);
        expect(find.textContaining('600 g'), findsOneWidget);
        expect(find.textContaining('£2.10'), findsNWidgets(2));
        expect(find.textContaining('zł'), findsNothing);
        expect(tester.takeException(), isNull);
        final button = tester.widget<OutlinedButton>(
          find.byType(OutlinedButton),
        );
        final foreground =
            button.style?.foregroundColor?.resolve({}) ??
            baseTheme.outlinedButtonTheme.style!.foregroundColor!.resolve({})!;
        final inheritedBackground =
            baseTheme.outlinedButtonTheme.style?.backgroundColor?.resolve({}) ??
            Colors.transparent;
        final buttonBackground = Color.alphaBlend(
          inheritedBackground,
          baseTheme.colorScheme.primaryContainer,
        );
        final foregroundLuminance = foreground.computeLuminance();
        final backgroundLuminance = buttonBackground.computeLuminance();
        final contrast =
            (foregroundLuminance > backgroundLuminance)
                ? (foregroundLuminance + .05) / (backgroundLuminance + .05)
                : (backgroundLuminance + .05) / (foregroundLuminance + .05);
        expect(
          contrast,
          greaterThanOrEqualTo(4.5),
          reason:
              'The switch action must remain legible on the green cheapest card',
        );
        expect(button.style!.side!.resolve({})!.color, foreground);
        expect(
          button.style!.side!.resolve({})!.width,
          baseTheme.outlinedButtonTheme.style!.side!.resolve({})!.width,
        );
        if (const bool.fromEnvironment('CAPTURE_UK_LAYOUT') && scale == 1.5) {
          final boundary =
              boundaryKey.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          await tester.runAsync(() async {
            final bitmap = await boundary.toImage(pixelRatio: 1);
            final png = await bitmap.toByteData(format: ui.ImageByteFormat.png);
            final file = File(
              '../docs/uk-stage4/evidence/packages-320-text150-${dark ? 'dark' : 'light'}.png',
            );
            await file.parent.create(recursive: true);
            await file.writeAsBytes(png!.buffer.asUint8List());
            bitmap.dispose();
          });
        }
      });
    }
  }

  test('a fully covered pantry requirement may truthfully cost zero', () {
    final item = PriceCompareItem.fromJson({
      'product_name': 'In pantry',
      'quantity_needed': 100,
      'unit': 'g',
      'price_in_store': 0,
      'is_from_pantry': true,
    }, requirePrice: true);
    expect(item.isFromPantry, isTrue);
    expect(item.priceIsEstimated, isFalse);
    expect(item.priceInStore, 0);
  });
}
