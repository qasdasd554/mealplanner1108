import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meal_planner/utils/product_form_validation.dart';

void main() {
  test('optional empty is absent while required empty is invalid', () {
    expect(parseProductFormNumber('  '), isNull);
    expect(validProductFormNumber('', maximum: 200), isTrue);
    expect(validProductFormNumber('', maximum: 200, required: true), isFalse);
  });
  test('decimal comma is accepted, zero is not an unknown value', () {
    expect(parseProductFormNumber(' 12,5 '), 12.5);
    expect(validProductFormNumber('0', maximum: 200), isTrue);
    expect(
      validProductFormNumber('0', maximum: 100000, allowZero: false),
      isFalse,
    );
  });
  for (final value in ['NaN', 'Infinity', '-Infinity', '-0.1', '1e309', 'x']) {
    test('rejects $value', () {
      expect(validProductFormNumber(value, maximum: 100000), isFalse);
    });
  }
  test(
    'package and nutrient API limits are inclusive, not silently clamped',
    () {
      expect(
        validProductFormNumber('100000', maximum: 100000, allowZero: false),
        isTrue,
      );
      expect(
        validProductFormNumber('100000.1', maximum: 100000, allowZero: false),
        isFalse,
      );
      expect(validProductFormNumber('2000', maximum: 2000), isTrue);
      expect(validProductFormNumber('200.1', maximum: 200), isFalse);
    },
  );
}
