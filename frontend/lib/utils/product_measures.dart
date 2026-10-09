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

bool _containsAny(String value, Iterable<String> words) =>
    words.any(value.contains);

/// Zwraca praktyczną wielkość jednej porcji w g/ml.
///
/// Najpierw respektujemy dokładną porcję zwróconą przez API. Dla starszych
/// produktów, które jej jeszcze nie mają, dobieramy wartość według rodzaju
/// żywności i ograniczamy ją do znanej wielkości opakowania. To nadal
/// przybliżenie (oznaczone w UI jako „ok.”), ale jest znacznie bardziej
/// użyteczne niż techniczny wybór 1 g / 1 ml.
double recommendedPortionQuantity(Product product) {
  for (final option in product.measureOptions) {
    if (option.code == 'porcja' && option.baseQuantity > 0) {
      return option.baseQuantity;
    }
  }

  final name = product.name.toLowerCase();
  final baseUnit = productBaseUnit(product.name, product.unit);
  double portion;

  if (baseUnit == 'ml') {
    if (_containsAny(name, const ['olej', 'oliwa'])) {
      portion = 10;
    } else if (_containsAny(name, const ['sos', 'ocet'])) {
      portion = 15;
    } else if (name.contains('śmietan')) {
      portion = 50;
    } else {
      portion = 250;
    }
  } else if (_containsAny(name, const [
    'pieprz',
    'papryka słodka',
    'papryka wędzona',
    'curry',
    'kurkuma',
    'cynamon',
    'oregano',
    'tymianek',
    'rozmaryn',
    'kolendra mielona',
    'gałka muszkatołowa',
    'ziele angielskie',
    'liść laurowy',
    'czosnek granulowany',
    'chili suszone',
  ])) {
    portion = 2;
  } else if (_containsAny(name, const ['sól', 'proszek do pieczenia'])) {
    portion = 5;
  } else if (_containsAny(name, const [
    'masło',
    'miód',
    'majonez',
    'ketchup',
    'musztarda',
    'pesto',
    'tahini',
    'chrzan',
  ])) {
    portion = 15;
  } else if (_containsAny(name, const [
    'orzech',
    'migdał',
    'pestki',
    'nasiona',
    'sezam',
    'rodzynki',
    'wiórki kokosowe',
  ])) {
    portion = 30;
  } else if (_containsAny(name, const [
    'ser ',
    'parmezan',
    'mozzarella',
    'feta',
    'cheddar',
  ])) {
    portion = 30;
  } else if (_containsAny(name, const ['chleb', 'bułka', 'tortilla'])) {
    portion = 50;
  } else if (_containsAny(name, const [
    'makaron',
    'ryż',
    'kasza',
    'quinoa',
    'kuskus',
    'płatki',
    'soczewica sucha',
    'ciecierzyca sucha',
  ])) {
    portion = 80;
  } else if (_containsAny(name, const [
    'kurczak',
    'indyk',
    'wołow',
    'wieprz',
    'schab',
    'mięso',
    'łosoś',
    'dorsz',
    'tuńczyk',
    'ryba',
    'krewet',
    'tofu',
  ])) {
    portion = 150;
  } else if (_containsAny(name, const [
    'jogurt',
    'kefir',
    'twaróg',
    'ricotta',
    'mascarpone',
    'serek',
  ])) {
    portion = 200;
  } else if (name.contains('hummus')) {
    portion = 50;
  } else if (_containsAny(name, const [
    'jabł',
    'banan',
    'malin',
    'truskawk',
    'borów',
    'mango',
    'kiwi',
    'pomarańcz',
    'mandarynk',
    'grejpfrut',
    'ananas',
    'melon',
    'granat',
    'kaki',
  ])) {
    portion = 150;
  } else if (_containsAny(name, const [
    'warzyw',
    'pomidor',
    'ogórek',
    'marchew',
    'ziemniak',
    'kapust',
    'brokuł',
    'kalafior',
    'cukini',
    'bakłażan',
    'szpinak',
    'burak',
    'papryka',
    'pieczark',
  ])) {
    portion = 200;
  } else if (product.unit == 'opak' &&
      product.servingQuantity != null &&
      product.servingQuantity! > 0) {
    portion =
        product.servingQuantity! <= 350
            ? product.servingQuantity!
            : product.servingQuantity! / 2;
  } else {
    portion = 100;
  }

  final packageSize = product.servingQuantity;
  if (packageSize != null && packageSize >= 5 && portion > packageSize) {
    portion = packageSize;
  }
  return portion;
}

List<ProductMeasureOption> effectiveMeasureOptions(Product product) {
  final baseUnit = productBaseUnit(product.name, product.unit);
  final result = <ProductMeasureOption>[];
  final packageSize = product.servingQuantity;
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
  // Zachowujemy tylko zweryfikowane dodatkowe miary z API. Stare wersje
  // zapisywały sztuczne „opakowanie = 100 g”; dlatego opakowanie zawsze
  // odbudowujemy wyłącznie z servingQuantity, zamiast ufać staremu JSON-owi.
  for (final option in product.measureOptions) {
    if (option.code == 'opak' ||
        option.code == 'g' ||
        option.code == 'ml' ||
        result.any((existing) => existing.code == option.code)) {
      continue;
    }
    result.add(option);
  }
  if (!result.any((option) => option.code == 'porcja')) {
    final insertionIndex =
        result.any((option) => option.code == 'opak') ? 1 : 0;
    result.insert(
      insertionIndex,
      ProductMeasureOption(
        code: 'porcja',
        label: 'porcja',
        baseQuantity: recommendedPortionQuantity(product),
        baseUnit: baseUnit,
        approximate: true,
      ),
    );
  }
  // Nie zakładamy, że masa całego opakowania jest masą jednej sztuki.
  // Opcję „sztuka” zachowujemy tylko wtedy, gdy API podało jej osobny,
  // zweryfikowany przelicznik w measure_options.
  if (!result.any((option) => option.code == baseUnit)) {
    result.add(
      ProductMeasureOption(
        code: baseUnit,
        label: baseUnit == 'g' ? 'gramy' : 'mililitry',
        baseQuantity: 1,
        baseUnit: baseUnit,
      ),
    );
  }

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
