import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meal_planner/widgets/tiktok_icon.dart';

void main() {
  testWidgets('ikona TikToka ma stały, kompaktowy rozmiar', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: TikTokIcon(size: 16))),
    );

    expect(find.byType(TikTokIcon), findsOneWidget);
    expect(tester.getSize(find.byType(TikTokIcon)), const Size.square(16));
  });
}
