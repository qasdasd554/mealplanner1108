import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meal_planner/l10n/app_localizations.dart';
import 'package:smart_meal_planner/l10n/system_content_data.dart';
import 'package:smart_meal_planner/services/api_client.dart';
import 'package:smart_meal_planner/widgets/pick_product_from_catalog_sheet.dart';

class _Client implements ApiClient {
  final String id;
  final String name;
  _Client(this.id, this.name);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  @override
  Future<dynamic> get(String path, {Duration? timeout}) async =>
      path.contains('scanned')
          ? []
          : [
            {
              'id': id,
              'name': name,
              'unit': 'g',
              'barcode': '5901234123457',
              'default_quantity': 1,
              'serving_quantity': 200,
              'nutrition_per_100': {
                'kcal': 740,
                'protein': 1,
                'fat': 82,
                'carbs': 1,
              },
            },
          ];
}

void main() {
  testWidgets(
    'catalogue pack selection keeps identity and translated label through the diary picker',
    (tester) async {
      final butter = systemIngredientText.entries.firstWhere(
        (row) => row.value['en_GB'] == 'Butter',
      );
      PickedCatalogProduct? picked;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en', 'GB'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: PickProductFromCatalogSheet(
              embedded: true,
              client: _Client(butter.key, butter.value['source']!),
              onPicked: (value) => picked = value,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Butter'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text('Butter'),
        ),
        findsOneWidget,
      );
      await tester.tap(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byWidgetPredicate((widget) => widget is FilledButton),
        ),
      );
      await tester.pumpAndSettle();
      expect(picked?.name, 'Butter');
      expect(picked?.unit, 'opak');
      expect(picked?.quantity, 1);
      expect(picked?.portionSize, 200);
      expect(picked?.kcal, 1480);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );
}
