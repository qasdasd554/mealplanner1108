import '../models/product.dart';

class ProductAmountSelection {
  final double quantity;
  final ProductMeasureOption measure;

  const ProductAmountSelection({required this.quantity, required this.measure});

  double get baseAmount => quantity * measure.baseQuantity;
  String get baseUnit => measure.baseUnit;

  double nutritionFactorPer100() => baseAmount / 100;
}

const _liquidWords = <String>{
  'mleko',
  'napój',
  'sok',
  'woda',
  'cola',
  'pepsi',
  'lemoniada',
  'kawa',
  'herbata',
  'olej',
  'oliwa',
  'ocet',
  'bulion',
  'śmietana',
};

const _teaspoonGrams = <String, double>{
  'sól': 5,
  'cukier': 4,
  'miód': 7,
  'masło': 5,
  'mąka': 3,
  'kakao': 3,
  'przypraw': 2,
  'cynamon': 2.6,
  'sos': 5,
  'majonez': 5,
  'musztarda': 5,
  'ketchup': 5,
};

const _glassGrams = <String, double>{
  'mąka': 160,
  'cukier': 220,
  'ryż': 190,
  'płatki': 110,
  'kasza': 180,
  'orzech': 140,
};

String productBaseUnit(String name, String unit) {
  if (unit == 'ml' || unit == 'l') return 'ml';
  final lower = name.toLowerCase();
  return _liquidWords.any(lower.contains) ? 'ml' : 'g';
}

List<ProductMeasureOption> effectiveMeasureOptions(Product product) {
  if (product.measureOptions.isNotEmpty) return product.measureOptions;

  final baseUnit = productBaseUnit(product.name, product.unit);
  final result = <ProductMeasureOption>[];
  double? packageSize = product.servingQuantity;
  if ((packageSize == null || packageSize <= 0) &&
      product.defaultQuantity > 0 &&
      product.unit != 'szt') {
    packageSize =
        product.defaultQuantity *
        ((product.unit == 'kg' || product.unit == 'l') ? 1000 : 1);
  }
  if (packageSize != null && packageSize > 0) {
    result.add(
      ProductMeasureOption(
        code: 'opak',
        label: 'opakowanie',
        baseQuantity: packageSize,
        baseUnit: baseUnit,
      ),
    );
  }
  // Nie zakładamy już, że każda sztuka waży 100 g. Opcję „sztuka”
  // pokazujemy tylko, gdy API podało przelicznik w measure_options.
  // Bez niego bezpiecznym wyborem pozostają gramy.
  if (product.unit == 'szt' && product.servingQuantity != null) {
    result.add(
      ProductMeasureOption(
        code: 'szt',
        label: 'sztuka',
        baseQuantity: product.servingQuantity!,
        baseUnit: 'g',
        approximate: true,
      ),
    );
  }
  result.add(
    ProductMeasureOption(
      code: baseUnit,
      label: baseUnit == 'g' ? 'gramy' : 'mililitry',
      baseQuantity: 1,
      baseUnit: baseUnit,
    ),
  );

  final lower = product.name.toLowerCase();
  if (baseUnit == 'ml') {
    result.addAll(const [
      ProductMeasureOption(
        code: 'lyzeczka',
        label: 'łyżeczka',
        baseQuantity: 5,
        baseUnit: 'ml',
      ),
      ProductMeasureOption(
        code: 'szklanka',
        label: 'szklanka',
        baseQuantity: 250,
        baseUnit: 'ml',
      ),
    ]);
  } else {
    for (final entry in _teaspoonGrams.entries) {
      if (lower.contains(entry.key)) {
        result.add(
          ProductMeasureOption(
            code: 'lyzeczka',
            label: 'łyżeczka',
            baseQuantity: entry.value,
            baseUnit: 'g',
            approximate: true,
          ),
        );
        break;
      }
    }
    for (final entry in _glassGrams.entries) {
      if (lower.contains(entry.key)) {
        result.add(
          ProductMeasureOption(
            code: 'szklanka',
            label: 'szklanka',
            baseQuantity: entry.value,
            baseUnit: 'g',
            approximate: true,
          ),
        );
        break;
      }
    }
  }
  return result;
}

String formatMeasureAmount(double quantity, ProductMeasureOption option) {
  final digits = quantity == quantity.roundToDouble() ? 0 : 1;
  return '${quantity.toStringAsFixed(digits)} × ${option.label}';
}

String productMeasureLabel(String code) =>
    const {
      'opak': 'opakowanie',
      'porcja': 'porcja',
      'szt': 'sztuka',
      'lyzeczka': 'łyżeczka',
      'szklanka': 'szklanka',
    }[code] ??
    code;
