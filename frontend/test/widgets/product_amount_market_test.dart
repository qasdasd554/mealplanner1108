import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meal_planner/l10n/app_localizations.dart';
import 'package:smart_meal_planner/models/product.dart';
import 'package:smart_meal_planner/widgets/product_amount_picker.dart';

Product fixture({bool unknown = false}) => Product(
  id: 'rice',
  name: 'Rice',
  unit: 'g',
  defaultQuantity: 100,
  servingQuantity: 500,
  nutritionPer100:
      unknown
          ? NutritionInfo.fromJson({})
          : NutritionInfo(kcal: 300, protein: 10, fat: 2, carbs: 65, fiber: 2),
);
Future<void> openAmount(WidgetTester tester, {bool unknown = false}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en', 'GB'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Builder(
        builder:
            (context) => Scaffold(
              body: TextButton(
                onPressed:
                    () => showProductAmountPicker(
                      context,
                      product: fixture(unknown: unknown),
                    ),
                child: const Text('Open'),
              ),
            ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('English quick measures keep physical gram quantities', (
    tester,
  ) async {
    await openAmount(tester);
    expect(find.text('Quick selection'), findsOneWidget);
    expect(find.text('1 × pack'), findsOneWidget);
    expect(find.text('500 g'), findsWidgets);
    expect(find.text('1 × serving'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  for (final invalid in ['NaN', 'Infinity', '1e999']) {
    testWidgets('invalid amount $invalid never crashes or enables save', (
      tester,
    ) async {
      await openAmount(tester);
      await tester.scrollUntilVisible(
        find.byType(TextField),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(find.byType(TextField), invalid);
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('unknown nutrition is not presented as zero calories', (
    tester,
  ) async {
    await openAmount(tester, unknown: true);
    expect(find.text('0 kcal'), findsNothing);
    expect(find.text('— kcal'), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
