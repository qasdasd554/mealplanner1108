import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_meal_planner/l10n/app_localizations.dart';
import 'package:smart_meal_planner/models/barcode_lookup_result.dart';
import 'package:smart_meal_planner/services/barcode_lookup_service.dart';
import 'package:smart_meal_planner/widgets/barcode_destination_sheet.dart';

class _Lookup extends BarcodeLookupService {
  final double? size;
  _Lookup(this.size);
  @override
  Future<BarcodeLookupResult> lookup(String barcode) async =>
      BarcodeLookupResult(
        found: true,
        name: 'Milk',
        unit: 'ml',
        servingQuantity: size,
        kcalPer100: 50,
        proteinPer100: 3,
        fatPer100: 2,
        carbsPer100: 5,
      );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final withPackage in [true, false]) {
    testWidgets(
      'English scan destination is multi-select and package hint is honest ($withPackage)',
      (tester) async {
        bool? result;
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('en', 'GB'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: Builder(
              builder:
                  (context) => Scaffold(
                    body: TextButton(
                      child: const Text('Scan'),
                      onPressed: () async {
                        result = await scanProductWithDestination(
                          context,
                          scanner: (_) async => '5901234123457',
                          lookupService: _Lookup(withPackage ? 500 : null),
                        );
                      },
                    ),
                  ),
            ),
          ),
        );
        await tester.tap(find.text('Scan'));
        await tester.pumpAndSettle();
        expect(
          find.text('Where would you like to add this product?'),
          findsOneWidget,
        );
        expect(find.text('Milk'), findsOneWidget);
        expect(
          find.text(
            withPackage
                ? 'Save as 1 whole pack'
                : 'Choose an amount in grams or millilitres',
          ),
          findsOneWidget,
        );
        expect(
          tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNull,
        );
        await tester.tap(find.widgetWithText(CheckboxListTile, 'Add to diary'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.widgetWithText(CheckboxListTile, 'Add to product catalogue'),
        );
        await tester.pumpAndSettle();
        expect(find.text('Add to 2 destinations'), findsOneWidget);
        expect(
          tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNotNull,
        );
        // Cancelling must not run any destination save.
        Navigator.of(tester.element(find.text('Milk'))).pop();
        await tester.pumpAndSettle();
        expect(result, isFalse);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
