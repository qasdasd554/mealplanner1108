import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meal_planner/l10n/app_localizations.dart';
import 'package:smart_meal_planner/screens/batch_barcode_scanner_screen.dart';
import 'package:smart_meal_planner/theme/app_theme.dart';

const _proof = bool.fromEnvironment('UK_WRITE_UI_PROOF');
ThemeData _theme(bool dark) {
  final base = dark ? AppTheme.darkTheme : AppTheme.lightTheme;
  if (!_proof) return base;
  ButtonStyle? fonts(ButtonStyle? style) => style?.copyWith(
    textStyle: WidgetStateProperty.resolveWith(
      (states) =>
          style.textStyle
              ?.resolve(states)
              ?.copyWith(fontFamily: 'UKStage7Proof') ??
          const TextStyle(fontFamily: 'UKStage7Proof'),
    ),
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(fontFamily: 'UKStage7Proof'),
    appBarTheme: base.appBarTheme.copyWith(
      titleTextStyle: base.appBarTheme.titleTextStyle?.copyWith(
        fontFamily: 'UKStage7Proof',
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: fonts(base.filledButtonTheme.style),
    ),
    chipTheme: base.chipTheme.copyWith(
      labelStyle: base.chipTheme.labelStyle?.copyWith(
        fontFamily: 'UKStage7Proof',
      ),
    ),
  );
}

void main() {
  setUpAll(() async {
    if (!_proof) return;
    await (FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    await (FontLoader('UKStage7Proof')..addFont(
      File(
        'C:/Windows/Fonts/arial.ttf',
      ).readAsBytes().then(ByteData.sublistView),
    )).load();
  });
  for (final locale in [const Locale('pl', 'PL'), const Locale('en', 'GB')]) {
    for (final dark in [false, true]) {
      testWidgets('preview fits 320px text150 ${locale.countryCode} dark=$dark', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(320, 740);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        AppTheme.setDark(dark);
        addTearDown(() => AppTheme.setDark(false));
        await tester.pumpWidget(
          RepaintBoundary(
            key: const ValueKey('stage7-proof'),
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              locale: locale,
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              theme: _theme(dark),
              builder:
                  (context, child) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: const TextScaler.linear(1.5)),
                    child: child!,
                  ),
              home: const BatchBarcodeScannerScreen(previewOnly: true),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final english = locale.countryCode == 'GB';
        final badge = tester.getRect(
          find.text(
            english ? 'Premium feature preview' : 'Podgląd funkcji Premium',
          ),
        );
        expect(badge.left, greaterThanOrEqualTo(0));
        expect(badge.right, lessThanOrEqualTo(320));
        final trial = find.text(english ? 'Explore Premium' : 'Zobacz Premium');
        expect(trial, findsOneWidget);
        expect(tester.getRect(trial).bottom, lessThanOrEqualTo(740));
        expect(tester.takeException(), isNull);
        if (_proof) {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const ValueKey('stage7-proof')),
          );
          await tester.runAsync(() async {
            final image = await boundary.toImage(pixelRatio: 1);
            final png = await image.toByteData(format: ui.ImageByteFormat.png);
            final file = File(
              '../docs/uk-stage7/evidence/preview-${locale.countryCode}-${dark ? 'dark' : 'light'}-320-text150.png',
            );
            await file.parent.create(recursive: true);
            await file.writeAsBytes(png!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}
