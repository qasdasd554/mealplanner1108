import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meal_planner/theme/app_theme.dart';
import 'package:smart_meal_planner/widgets/adaptive_action_tile.dart';
import 'package:smart_meal_planner/widgets/premium_feature_tag.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  var proofFont = 'Roboto';
  setUpAll(() async {
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    final font = File('C:/Windows/Fonts/arial.ttf');
    if (await font.exists()) {
      final loader = FontLoader('UKLayoutProof')
        ..addFont(font.readAsBytes().then(ByteData.sublistView));
      await loader.load();
      proofFont = 'UKLayoutProof';
    }
  });
  tearDown(() => AppTheme.setDark(false));

  for (final dark in [false, true]) {
    for (final width in [320.0, 390.0]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('action tile width=$width scale=$scale dark=$dark', (
          tester,
        ) async {
          tester.view.physicalSize = Size(width, 568);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          AppTheme.setDark(dark);
          final baseTheme = dark ? AppTheme.darkTheme : AppTheme.lightTheme;
          final key = GlobalKey();
          var taps = 0;
          await tester.pumpWidget(
            MaterialApp(
              theme: baseTheme.copyWith(
                textTheme: baseTheme.textTheme.apply(fontFamily: proofFont),
              ),
              builder:
                  (context, child) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: TextScaler.linear(scale)),
                    child: child!,
                  ),
              home: RepaintBoundary(
                key: key,
                child: Scaffold(
                  body: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Material(
                      color: baseTheme.colorScheme.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: baseTheme.colorScheme.outlineVariant,
                        ),
                      ),
                      child: AdaptiveActionTile(
                        icon: Icons.photo_camera_outlined,
                        title: 'Take a photo',
                        subtitle: 'Of a recipe or a finished dish',
                        trailing: const PremiumFeatureTag(
                          label: 'PREMIUM · 2 PTS',
                          fontSize: 8,
                        ),
                        onTap: () => taps++,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final tile = tester.widget<ListTile>(find.byType(ListTile));
          expect(tile.trailing == null, width == 320 || scale == 2);
          final title = find.text('Take a photo');
          expect(tester.getSize(title).width, greaterThan(100));
          expect(title.hitTestable(), findsOneWidget);
          await tester.tap(title);
          expect(taps, 1);
          expect(find.text('PREMIUM · 2 PTS'), findsOneWidget);
          if (const bool.fromEnvironment('CAPTURE_UK_LAYOUT') &&
              width == 320 &&
              scale == 2) {
            final boundary =
                key.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            await tester.runAsync(() async {
              final bitmap = await boundary.toImage(pixelRatio: 1);
              final png = await bitmap.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final file = File(
                '../docs/uk-stage2/evidence/action-320-text200-${dark ? 'dark' : 'light'}.png',
              );
              await file.parent.create(recursive: true);
              await file.writeAsBytes(png!.buffer.asUint8List());
              bitmap.dispose();
            });
          }
        });
      }
    }
  }
}
