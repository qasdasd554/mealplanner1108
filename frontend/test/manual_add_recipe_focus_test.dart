import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meal_planner/screens/recipes/manual_add_recipe_screen.dart';

void main() {
  Future<void> openForm(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: ManualAddRecipeScreen()));
    await tester.pump();
  }

  testWidgets('tytuł pozostaje wpisany, a Dalej przechodzi do opisu', (
    tester,
  ) async {
    await openForm(tester);
    final title = find.widgetWithText(TextFormField, 'Nazwa przepisu');
    final description = find.widgetWithText(
      TextFormField,
      'Krótki opis (opcjonalnie)',
    );

    await tester.tap(title);
    await tester.enterText(title, 'Wieprzowina po polsku');
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pump();

    expect(find.text('Wieprzowina po polsku'), findsOneWidget);
    final descriptionEditable = find.descendant(
      of: description,
      matching: find.byType(EditableText),
    );
    expect(
      tester.widget<EditableText>(descriptionEditable).focusNode.hasFocus,
      isTrue,
    );
    expect(find.text('Dodaj przepis ręcznie'), findsOneWidget);
  });

  testWidgets('odzyskuje fokus zgubiony przez klawiaturę tuż po wpisaniu', (
    tester,
  ) async {
    await openForm(tester);
    final title = find.widgetWithText(TextFormField, 'Nazwa przepisu');

    await tester.tap(title);
    await tester.enterText(title, 'Wieprzowina');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump(const Duration(milliseconds: 100));

    final titleEditable = find.descendant(
      of: title,
      matching: find.byType(EditableText),
    );
    expect(
      tester.widget<EditableText>(titleEditable).focusNode.hasFocus,
      isTrue,
    );
    expect(find.text('Wieprzowina'), findsOneWidget);
  });

  testWidgets('cofnięcie nie wyrzuca formularza z niezapisanym tytułem', (
    tester,
  ) async {
    await openForm(tester);
    final title = find.widgetWithText(TextFormField, 'Nazwa przepisu');
    await tester.enterText(title, 'Niezapisany przepis');

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Odrzucić zmiany?'), findsOneWidget);
    await tester.tap(find.text('Zostań'));
    await tester.pumpAndSettle();
    expect(find.text('Dodaj przepis ręcznie'), findsOneWidget);
    expect(find.text('Niezapisany przepis'), findsOneWidget);
  });
}
