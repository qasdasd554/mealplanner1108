import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meal_planner/theme/app_theme.dart';

const _proof = bool.fromEnvironment('UK_WRITE_UI_PROOF');
const productFormProofKey = ValueKey('stage8-form-proof');

Future<void> loadProductFormFonts() async {
  if (!_proof) return;
  await (FontLoader('MaterialIcons')
    ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  await (FontLoader('UKStage8Proof')..addFont(
    File('C:/Windows/Fonts/arial.ttf').readAsBytes().then(ByteData.sublistView),
  )).load();
}

ThemeData productFormTheme(bool dark) {
  final base = dark ? AppTheme.darkTheme : AppTheme.lightTheme;
  if (!_proof) return base;
  ButtonStyle? fonts(ButtonStyle? style) => style?.copyWith(
    textStyle: WidgetStateProperty.resolveWith(
      (states) =>
          style.textStyle
              ?.resolve(states)
              ?.copyWith(fontFamily: 'UKStage8Proof') ??
          const TextStyle(fontFamily: 'UKStage8Proof'),
    ),
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(fontFamily: 'UKStage8Proof'),
    filledButtonTheme: FilledButtonThemeData(
      style: fonts(base.filledButtonTheme.style),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: fonts(base.outlinedButtonTheme.style),
    ),
    textButtonTheme: TextButtonThemeData(
      style: fonts(base.textButtonTheme.style),
    ),
    inputDecorationTheme: base.inputDecorationTheme.copyWith(
      labelStyle: base.inputDecorationTheme.labelStyle?.copyWith(
        fontFamily: 'UKStage8Proof',
      ),
      hintStyle: base.inputDecorationTheme.hintStyle?.copyWith(
        fontFamily: 'UKStage8Proof',
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      labelStyle: base.chipTheme.labelStyle?.copyWith(
        fontFamily: 'UKStage8Proof',
      ),
    ),
  );
}

Future<void> captureProductForm(WidgetTester tester, String name) async {
  if (!_proof) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(productFormProofKey),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('../docs/uk-stage8/evidence/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(png!.buffer.asUint8List());
    image.dispose();
  });
}
