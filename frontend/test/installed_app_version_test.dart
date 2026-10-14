import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:smart_meal_planner/widgets/installed_app_version.dart';

void main() {
  testWidgets('profile version is read from the installed artifact', (
    tester,
  ) async {
    PackageInfo.setMockInitialValues(
      appName: 'Meal Planner Polska',
      packageName: 'test',
      version: '9.8.7',
      buildNumber: '999',
      buildSignature: '',
    );
    await tester.pumpWidget(const MaterialApp(home: InstalledAppVersion()));
    await tester.pumpAndSettle();
    expect(find.text('v9.8.7+999 (Meal Planner)'), findsOneWidget);
    expect(find.textContaining('1.0.22'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
