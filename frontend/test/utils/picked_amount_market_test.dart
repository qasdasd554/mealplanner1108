import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meal_planner/l10n/app_localizations_en.dart';
import 'package:smart_meal_planner/l10n/app_localizations_pl.dart';
import 'package:smart_meal_planner/widgets/pick_product_from_catalog_sheet.dart';

void main() {
  test(
    'picked pack display retains 500 ml without changing the canonical code',
    () {
      const picked = PickedCatalogProduct(
        name: 'Milk',
        quantity: 2,
        unit: 'opak',
        kcal: 500,
        protein: 20,
        fat: 10,
        carbs: 30,
        portionSize: 500,
        portionUnit: 'ml',
      );
      expect(picked.amountLabelFor(AppLocalizationsEnGb()), '2 packs (500 ml)');
      expect(picked.amountLabelFor(AppLocalizationsPl()), picked.amountLabel);
      expect(picked.unit, 'opak');
      expect(picked.portionSize, 500);
    },
  );
  test(
    'picked grams and ml remain actual amounts not a new portion conversion',
    () {
      for (final unit in ['g', 'ml']) {
        final picked = PickedCatalogProduct(
          name: 'Food',
          quantity: 125.5,
          unit: unit,
          kcal: 100,
          protein: 5,
          fat: 2,
          carbs: 10,
          portionSize: 1,
          portionUnit: unit,
        );
        expect(picked.amountLabelFor(AppLocalizationsEnGb()), '125.5 $unit');
      }
    },
  );
}
