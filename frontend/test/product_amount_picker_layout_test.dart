import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meal_planner/models/product.dart';
import 'package:smart_meal_planner/widgets/product_amount_picker.dart';

void main() {
  final product = Product(
    id: 'product-1',
    name: 'Produkt testowy o dłuższej nazwie',
    brand: 'Marka',
    unit: 'opak',
    defaultQuantity: 1,
    servingQuantity: 150,
    measureOptions: const [
      ProductMeasureOption(
        code: 'opak',
        label: 'opakowanie',
        baseQuantity: 150,
        baseUnit: 'g',
      ),
      ProductMeasureOption(
        code: 'g',
        label: 'gramy',
        baseQuantity: 1,
        baseUnit: 'g',
      ),
      ProductMeasureOption(
        code: 'lyzeczka',
        label: 'łyżeczka',
        baseQuantity: 5,
        baseUnit: 'g',
      ),
      ProductMeasureOption(
        code: 'szklanka',
        label: 'szklanka',
        baseQuantity: 200,
        baseUnit: 'g',
      ),
    ],
    nutritionPer100: NutritionInfo(
      kcal: 120,
      protein: 5,
      fat: 4,
      carbs: 16,
      fiber: 2,
    ),
  );

  testWidgets('arkusz mieści akcję i pokazuje szybkie wybory jako przyciski', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder:
              (context) => Scaffold(
                body: ElevatedButton(
                  onPressed:
                      () => showProductAmountPicker(context, product: product),
                  child: const Text('Otwórz'),
                ),
              ),
        ),
      ),
    );

    await tester.tap(find.text('Otwórz'));
    await tester.pumpAndSettle();

    final action = find.text('Wybierz ilość');
    expect(action, findsOneWidget);
    expect(tester.getBottomRight(action).dy, lessThanOrEqualTo(568));

    final quickChoice = find.text('1 × opakowanie');
    expect(quickChoice, findsOneWidget);
    expect(
      find.ancestor(of: quickChoice, matching: find.byType(InkWell)),
      findsOneWidget,
    );
  });

  testWidgets(
    'wpisanie gramów z klawiaturą nie zasłania ani nie blokuje arkusza',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder:
                (context) => Scaffold(
                  body: ElevatedButton(
                    onPressed:
                        () =>
                            showProductAmountPicker(context, product: product),
                    child: const Text('Otwórz'),
                  ),
                ),
          ),
        ),
      );

      await tester.tap(find.text('Otwórz'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Własna ilość'),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      final unitPicker = find.byWidgetPredicate(
        (widget) => widget is DropdownButtonFormField<ProductMeasureOption>,
      );
      expect(unitPicker, findsOneWidget);
      await tester.tap(unitPicker);
      await tester.pumpAndSettle();
      await tester.tap(find.text('gramy').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TextField));
      await tester.showKeyboard(find.byType(TextField));
      await tester.enterText(find.byType(TextField), '250');
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Wybierz ilość'), findsOneWidget);
      await tester.tap(find.text('Wybierz ilość'));
      await tester.pumpAndSettle();
      expect(find.text('Otwórz'), findsOneWidget);
    },
  );
}
