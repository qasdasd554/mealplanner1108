import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meal_planner/config/constants.dart';
import 'package:smart_meal_planner/l10n/app_localizations_en.dart';
import 'package:smart_meal_planner/l10n/app_localizations_pl.dart';
import 'package:smart_meal_planner/l10n/catalog_labels.dart';
import 'package:smart_meal_planner/utils/quantity_formatter.dart';

void main() {
  final pl = AppLocalizationsPl();
  final gb = AppLocalizationsEnGb();

  test(
    'legacy recipe spoon spellings are translated without changing storage',
    () {
      expect(gb.unitLabel('łyżeczka'), 'tsp');
      expect(gb.unitLabel('łyżka'), 'tbsp');
      expect(gb.unitLabel('lyzka'), 'tbsp');
      expect(gb.unitLabel('szt.'), 'pcs');
      expect(pl.unitLabel('łyżka'), 'łyżka');
    },
  );

  test('Polish diet identifiers and descriptions are unchanged', () {
    for (final diet in kDietOptions) {
      expect(pl.dietName(diet['name']!), diet['name']);
      expect(pl.dietDescription(diet['name']!), diet['desc']);
    }
    expect(kDietNameToTag['Wegańska'], 'wegańskie');
  });

  test('British display labels do not mutate canonical recipe values', () {
    const mealTypes = ['śniadanie', 'obiad', 'kolacja', 'przekąska', 'deser'];
    expect(mealTypes.map(gb.mealTypeLabel), [
      'breakfast',
      'lunch',
      'dinner',
      'snack',
      'dessert',
    ]);
    expect(mealTypes.map(pl.mealTypeLabel), mealTypes);
    expect(gb.dietName('Wegetariańska'), 'Vegetarian');
    expect(gb.difficultyLabel('łatwy'), 'easy');
    expect(gb.difficultyLabel('średni'), 'medium');
    expect(gb.difficultyLabel('trudny'), 'hard');
    expect(kDietOptions[1]['name'], 'Wegetariańska');
  });

  test('unknown or user-authored values are preserved, not guessed', () {
    expect(gb.mealTypeLabel('brunch'), 'brunch');
    expect(gb.difficultyLabel('custom'), 'custom');
    expect(gb.dietName('Moja dieta'), 'Moja dieta');
    expect(pl.planStatusLabel('active'), 'active');
  });

  test('card summary retains per-serving meaning in both languages', () {
    expect(pl.recipeCardSummary(20, 450), '20 min • 450 kcal/porcję');
    expect(gb.recipeCardSummary(20, 450), '20 min • 450 kcal/serving');
  });

  test('measure display labels preserve Polish values and canonical units', () {
    for (final unit in [
      'g',
      'kg',
      'ml',
      'l',
      'opak',
      'porcja',
      'szt',
      'lyzeczka',
      'szklanka',
    ]) {
      expect(pl.unitLabel(unit), formatUnitLabel(unit));
    }
    expect(gb.unitLabel('opak'), 'pack');
    expect(gb.unitLabel('porcja'), 'serving');
    expect(gb.unitLabel('lyzeczka'), 'tsp');
    expect(gb.unitLabel('ml'), 'ml');
    expect(gb.unitLabel('unrecognised'), 'unrecognised');
  });
}
