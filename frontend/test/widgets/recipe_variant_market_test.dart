import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meal_planner/l10n/app_localizations.dart';
import 'package:smart_meal_planner/models/product.dart';
import 'package:smart_meal_planner/models/recipe.dart';
import 'package:smart_meal_planner/services/product_search_service.dart';
import 'package:smart_meal_planner/widgets/recipe_variant_editor_sheet.dart';

Product product(String name, {String unit = 'g', double quantity = 100}) =>
    Product(
      id: name,
      name: name,
      unit: unit,
      defaultQuantity: quantity,
      nutritionPer100: NutritionInfo(
        kcal: 100,
        protein: 8,
        fat: 2,
        carbs: 10,
        fiber: 0,
      ),
    );

class _Search extends ProductSearchService {
  final pending = <String, Completer<List<Product>>>{};
  List<Product>? immediate;
  @override
  Future<List<Product>> search(String query, {int limit = 20}) async {
    return immediate ??
        pending.putIfAbsent(query, () => Completer<List<Product>>()).future;
  }
}

RecipeIngredient ingredient() => RecipeIngredient(
  id: 'ingredient',
  productId: 'salt',
  productName: 'Salt',
  quantity: 100,
  unit: 'g',
  isOptional: false,
  kcal: 100,
  protein: 8,
  fat: 2,
  carbs: 10,
);

Future<void> _open(
  WidgetTester tester, {
  bool english = false,
  _Search? search,
  ValueChanged<List<RecipeIngredient>?>? onResult,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: english ? const Locale('en', 'GB') : const Locale('pl', 'PL'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(
        body: Builder(
          builder:
              (context) => TextButton(
                onPressed: () async {
                  final result =
                      await showModalBottomSheet<List<RecipeIngredient>>(
                        context: context,
                        isScrollControlled: true,
                        useSafeArea: true,
                        builder:
                            (_) => RecipeVariantEditorSheet(
                              ingredients: [ingredient()],
                              searchService: search,
                            ),
                      );
                  onResult?.call(result);
                },
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
  testWidgets('Escape cancels quantity editing without discarding the draft', (
    tester,
  ) async {
    await _open(tester);
    await tester.tap(find.text('Salt'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '25');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('100 g'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('quantity dialog supports Tab and Enter after text entry', (
    tester,
  ) async {
    await _open(tester);
    await tester.tap(find.text('Salt'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '25');
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('25 g'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('GB editor translates controls without changing author data', (
    tester,
  ) async {
    await _open(tester, english: true);
    expect(find.text('Edit ingredients'), findsOneWidget);
    expect(find.text('Salt'), findsOneWidget);
    expect(find.text('Apply temporarily'), findsOneWidget);
  });

  for (final value in ['NaN', 'Infinity', '-1', '0', 'abc', '1e308']) {
    testWidgets(
      'invalid quantity $value preserves dialog and original amount',
      (tester) async {
        await _open(tester);
        await tester.tap(find.text('Salt'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), value);
        await tester.tap(find.widgetWithText(FilledButton, 'Zmień'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          value,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'valid edit survives reverse animation and scales draft macros once',
    (tester) async {
      List<RecipeIngredient>? result;
      await _open(tester, onResult: (items) => result = items);
      await tester.tap(find.text('Salt'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '50,5');
      await tester.tap(find.widgetWithText(FilledButton, 'Zmień'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(
        find.widgetWithText(FilledButton, 'Zastosuj tymczasowo'),
      );
      await tester.pumpAndSettle();
      expect(result!.single.quantity, 50.5);
      expect(result!.single.productId, 'salt');
      expect(result!.single.protein, closeTo(4.04, 0.0001));
    },
  );

  testWidgets('legacy pack product defaults to one pack, not 100 packs', (
    tester,
  ) async {
    final search =
        _Search()..immediate = [product('Pack', unit: 'opak', quantity: 100)];
    await _open(tester, search: search);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Dodaj produkt'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Pack');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Pack'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '1',
    );
  });

  testWidgets('late product search cannot overwrite newer or cleared query', (
    tester,
  ) async {
    final search = _Search();
    await _open(tester, search: search);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Dodaj produkt'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Old');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.enterText(find.byType(TextField), 'New');
    await tester.pump(const Duration(milliseconds: 350));
    search.pending['New']!.complete([product('New product')]);
    await tester.pump();
    search.pending['Old']!.complete([product('Old product')]);
    await tester.pump();
    expect(find.text('New product'), findsOneWidget);
    expect(find.text('Old product'), findsNothing);
    await tester.enterText(find.byType(TextField), '');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
    expect(find.text('New product'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });
}
