import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meal_planner/widgets/campaign_icon.dart';

void main() {
  testWidgets('pokazuje szarfę tylko przy aktywnym rabacie', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: CampaignIcon(
          icon: Icons.toll,
          color: Colors.amber,
          discountPercent: 30,
        ),
      ),
    ));
    expect(find.text('RABAT -30%'), findsOneWidget);

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: CampaignIcon(icon: Icons.toll, color: Colors.amber)),
    ));
    expect(find.text('RABAT -30%'), findsNothing);
  });
}
