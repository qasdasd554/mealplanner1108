import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meal_planner/data/cooking_tips.dart';
import 'package:smart_meal_planner/screens/home/cooking_tips_screen.dart';
import 'package:smart_meal_planner/widgets/product_contribution_reward_banner.dart';

void main() {
  testWidgets('pokazuje nagrodę za dodanie unikalnego produktu', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ProductContributionRewardBanner()),
      ),
    );

    expect(find.text('Zyskaj 1 punkt Premium'), findsOneWidget);
    expect(find.text('+1 pkt'), findsOneWidget);
    expect(
      find.text(
        'Zeskanuj kod lub dodaj ręcznie nowy, unikalny produkt do bazy.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('otwiera wskazaną poradę w widocznym obszarze', (tester) async {
    const highlightedIndex = 20;
    await tester.pumpWidget(
      const MaterialApp(
        home: CookingTipsScreen(highlightIndex: highlightedIndex),
      ),
    );
    await tester.pumpAndSettle();

    final title = find.text(kCookingTips[highlightedIndex].title);
    expect(title, findsOneWidget);
    final rect = tester.getRect(title);
    expect(rect.top, greaterThanOrEqualTo(0));
    expect(rect.bottom, lessThanOrEqualTo(600));
    await tester.pump(const Duration(seconds: 3));
  });
}
