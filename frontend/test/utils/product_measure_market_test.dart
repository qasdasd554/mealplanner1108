import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meal_planner/l10n/app_localizations_en.dart';
import 'package:smart_meal_planner/l10n/app_localizations_pl.dart';
import 'package:smart_meal_planner/l10n/measure_labels.dart';
import 'package:smart_meal_planner/models/product.dart';
import 'package:smart_meal_planner/utils/product_measures.dart';

Product _item({
  double? package,
  List<ProductMeasureOption> measures = const [],
}) => Product(
  id: 'milk',
  name: 'Milk',
  unit: 'ml',
  defaultQuantity: 100,
  servingQuantity: package,
  measureOptions: measures,
  nutritionPer100: NutritionInfo.fromJson({}),
);
void main() {
  test('display translation does not change canonical unit codes', () {
    final en = AppLocalizationsEn(), pl = AppLocalizationsPl();
    expect(en.measureName('opak'), 'pack');
    expect(pl.measureName('opak', fallback: 'opakowanie'), 'opakowanie');
    expect(
      en.measureQuantityLabel('szklanka', fallback: '', amount: 2),
      'glasses',
    );
    expect(en.measureQuantityLabel('g', fallback: '', amount: 100), 'g');
    expect(
      en.measureName('custom', fallback: 'Original measure'),
      'Original measure',
    );
  });
  for (final invalid in [double.nan, double.infinity, -2.0, 0.0, 1000001.0]) {
    test('invalid package/measure $invalid cannot enter amount choices', () {
      final options = effectiveMeasureOptions(
        _item(
          package: invalid,
          measures: [
            ProductMeasureOption(
              code: 'porcja',
              label: 'porcja',
              baseQuantity: invalid,
              baseUnit: 'ml',
            ),
          ],
        ),
      );
      expect(options.any((o) => o.code == 'opak'), isFalse);
      expect(
        options.every(
          (o) =>
              o.baseQuantity.isFinite &&
              o.baseQuantity > 0 &&
              o.baseQuantity <= 1000000,
        ),
        isTrue,
      );
    });
  }
  test(
    'incompatible serving is not reinterpreted as a different physical unit',
    () {
      final options = effectiveMeasureOptions(
        _item(
          measures: [
            const ProductMeasureOption(
              code: 'porcja',
              label: 'portion in grams',
              baseQuantity: 77,
              baseUnit: 'g',
            ),
          ],
        ),
      );
      expect(options.singleWhere((o) => o.code == 'porcja').baseQuantity, 250);
    },
  );
  test(
    'API spoon/glass are retained once without overwriting their known quantities',
    () {
      final options = effectiveMeasureOptions(
        _item(
          measures: [
            const ProductMeasureOption(
              code: 'szklanka',
              label: 'small glass',
              baseQuantity: 200,
              baseUnit: 'ml',
            ),
          ],
        ),
      );
      expect(options.where((o) => o.code == 'szklanka'), hasLength(1));
      expect(
        options.singleWhere((o) => o.code == 'szklanka').baseQuantity,
        200,
      );
    },
  );
  test('English glass label never converts 250 ml into an imperial cup', () {
    final glass = effectiveMeasureOptions(
      _item(),
    ).singleWhere((o) => o.code == 'szklanka');
    expect(glass.baseQuantity, 250);
    expect(glass.baseUnit, 'ml');
  });
}
