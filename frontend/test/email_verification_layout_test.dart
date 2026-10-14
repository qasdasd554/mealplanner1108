import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:smart_meal_planner/models/user.dart';
import 'package:smart_meal_planner/providers/auth_provider.dart';
import 'package:smart_meal_planner/screens/auth/email_verification_screen.dart';
import 'package:smart_meal_planner/theme/app_theme.dart';

class _Auth extends ChangeNotifier implements AuthProvider {
  @override
  User? get currentUser => User(
    id: 'test',
    householdSize: 1,
    email: 'very.long.address.for.layout@example.invalid',
    createdAt: DateTime(2026),
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  var proofTheme = AppTheme.lightTheme;
  setUpAll(() async {
    final font = File('C:/Windows/Fonts/arial.ttf');
    if (await font.exists()) {
      final loader = FontLoader('AuditSans')
        ..addFont(font.readAsBytes().then(ByteData.sublistView));
      await loader.load();
      proofTheme = proofTheme.copyWith(
        textTheme: proofTheme.textTheme.apply(fontFamily: 'AuditSans'),
        filledButtonTheme: FilledButtonThemeData(
          style: proofTheme.filledButtonTheme.style?.copyWith(
            textStyle: const WidgetStatePropertyAll(
              TextStyle(
                fontFamily: 'AuditSans',
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            textStyle: const TextStyle(fontFamily: 'AuditSans'),
          ),
        ),
      );
    }
  });
  for (final keyboard in [0.0, 240.0]) {
    testWidgets('verification fits 320px at 150% text with keyboard=$keyboard', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 568);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final key = GlobalKey();
      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => _Auth(),
          child: MaterialApp(
            theme: proofTheme,
            builder:
                (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(1.5),
                    viewInsets: EdgeInsets.only(bottom: keyboard),
                  ),
                  child: child!,
                ),
            home: RepaintBoundary(
              key: key,
              child: const EmailVerificationScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Potwierdź'));
      await tester.pumpAndSettle();
      expect(
        tester.getBottomRight(find.text('Potwierdź')).dy,
        lessThanOrEqualTo(568 - keyboard),
      );
      expect(tester.takeException(), isNull);
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final bitmap = await boundary.toImage(pixelRatio: 1);
        final png = await bitmap.toByteData(format: ui.ImageByteFormat.png);
        final file = File(
          '../docs/audit/evidence/verification-320x568-text150-keyboard${keyboard.toInt()}.png',
        );
        await file.parent.create(recursive: true);
        await file.writeAsBytes(png!.buffer.asUint8List());
        bitmap.dispose();
      });
    });
  }
}
