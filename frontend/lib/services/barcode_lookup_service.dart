import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/barcode_lookup_result.dart';
import 'api_client.dart';

/// Wyszukuje produkt najpierw w Neon, a potem w bazach zewnętrznych backendu.
/// Bezpośrednia próba Open Food Facts jest
/// niezależna od wdrożenia backendu i pozwala uzupełnić formularz także
/// wtedy, gdy serwer aplikacji chwilowo nie odpowiada.
class BarcodeLookupService {
  static const _backendTimeout = Duration(seconds: 8);
  static const _externalTimeout = Duration(seconds: 12);
  static const _userAgent =
      'MealPlannerPolska/1.0 (https://github.com/qasdasd554/mealplanner1108)';

  final ApiClient _apiClient;
  final http.Client _httpClient;

  BarcodeLookupService({ApiClient? apiClient, http.Client? httpClient})
    : _apiClient = apiClient ?? ApiClient(),
      _httpClient = httpClient ?? http.Client();

  void close() => _httpClient.close();

  Future<BarcodeLookupResult> lookup(String barcode) async {
    Object? backendError;
    BarcodeLookupResult? backendResult;
    // Uruchamiamy niezależne źródło od razu. Dzięki temu uśpiony backend
    // nie opóźnia o kilkanaście sekund danych, które OFF ma już gotowe.
    final externalFuture = _lookupOpenFoodFacts(barcode);

    try {
      final response = await _apiClient.get(
        '/products/barcode/$barcode',
        timeout: _backendTimeout,
      );
      backendResult = BarcodeLookupResult.fromJson(
        response as Map<String, dynamic>,
      );
      if (backendResult.found &&
          _hasName(backendResult) &&
          _hasCompleteProductData(backendResult)) {
        return backendResult;
      }
    } catch (error) {
      backendError = error;
    }

    final externalResult = await externalFuture;
    if (externalResult != null) {
      if (backendResult != null &&
          backendResult.found &&
          _hasName(backendResult)) {
        return mergeBarcodeLookupResults(backendResult, externalResult);
      }
      return externalResult;
    }

    // Gdy backend odpowiedział poprawnie "nie znaleziono", zachowujemy ten
    // wynik. Błąd połączenia pokazujemy dopiero wtedy, gdy zawiodła również
    // niezależna próba w Open Food Facts.
    if (backendResult != null) return backendResult;
    if (backendError != null) throw backendError;
    return const BarcodeLookupResult(found: false);
  }

  bool _hasName(BarcodeLookupResult result) =>
      result.name?.trim().isNotEmpty == true;

  bool _hasCompleteProductData(BarcodeLookupResult result) =>
      _nonEmpty(result.brand) != null &&
      result.kcalPer100 != null &&
      result.proteinPer100 != null &&
      result.fatPer100 != null &&
      result.carbsPer100 != null &&
      result.priceMin != null &&
      result.priceMax != null;

  Future<BarcodeLookupResult?> _lookupOpenFoodFacts(String barcode) async {
    final urls = [
      Uri.https('world.openfoodfacts.org', '/api/v3/product/$barcode', {
        'cc': 'pl',
        'lc': 'pl',
        'fields': _fields,
      }),
      Uri.https('world.openfoodfacts.org', '/api/v2/product/$barcode.json', {
        'cc': 'pl',
        'lc': 'pl',
        'fields': _fields,
      }),
    ];

    for (var index = 0; index < urls.length; index++) {
      try {
        final response = await _httpClient
            .get(
              urls[index],
              headers: const {
                'Accept': 'application/json',
                'User-Agent': _userAgent,
              },
            )
            .timeout(_externalTimeout);
        if (response.statusCode != 200) continue;

        final decoded = jsonDecode(response.body);
        if (decoded is! Map<String, dynamic>) continue;
        final product = extractOpenFoodFactsProduct(decoded, isV3: index == 0);
        if (product == null) continue;

        final result = barcodeResultFromOpenFoodFacts(product);
        if (result != null) return result;
      } on TimeoutException {
        continue;
      } on http.ClientException {
        continue;
      } on FormatException {
        continue;
      }
    }
    return null;
  }

  static const _fields =
      'product_name_pl,product_name,generic_name_pl,generic_name,'
      'abbreviated_product_name,brands,nutriments,categories_tags,'
      'product_quantity,product_quantity_unit,serving_quantity';
}

/// Zachowuje zweryfikowaną nazwę, markę i cenę z katalogu aplikacji, a braki
/// żywieniowe uzupełnia danymi z Open Food Facts.
BarcodeLookupResult mergeBarcodeLookupResults(
  BarcodeLookupResult catalog,
  BarcodeLookupResult external,
) {
  return BarcodeLookupResult(
    found: true,
    source: catalog.source,
    name: _nonEmpty(catalog.name) ?? external.name,
    brand: _nonEmpty(catalog.brand) ?? external.brand,
    unit: catalog.unit,
    kcalPer100: catalog.kcalPer100 ?? external.kcalPer100,
    proteinPer100: catalog.proteinPer100 ?? external.proteinPer100,
    fatPer100: catalog.fatPer100 ?? external.fatPer100,
    carbsPer100: catalog.carbsPer100 ?? external.carbsPer100,
    existingProductId: catalog.existingProductId,
    priceMin: catalog.priceMin ?? external.priceMin,
    priceMax: catalog.priceMax ?? external.priceMax,
  );
}

String? _nonEmpty(String? value) {
  final normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}

Map<String, dynamic>? extractOpenFoodFactsProduct(
  Map<String, dynamic> response, {
  required bool isV3,
}) {
  final product = response['product'];
  if (product is! Map<String, dynamic>) return null;

  if (isV3) {
    final result = response['result'];
    if (response['status'] != 'success' ||
        result is! Map<String, dynamic> ||
        result['id'] != 'product_found') {
      return null;
    }
  } else if (response['status'].toString() != '1') {
    return null;
  }
  return product;
}

BarcodeLookupResult? barcodeResultFromOpenFoodFacts(
  Map<String, dynamic> product,
) {
  final name = _firstText(product, const [
    'product_name_pl',
    'product_name',
    'abbreviated_product_name',
    'generic_name_pl',
    'generic_name',
  ]);
  if (name == null) return null;

  final nutriments =
      product['nutriments'] is Map<String, dynamic>
          ? product['nutriments'] as Map<String, dynamic>
          : <String, dynamic>{};
  var kcal = _firstNumber(nutriments, const [
    'energy-kcal_100g',
    'energy-kcal',
  ]);
  if (kcal == null) {
    final energyKj = _firstNumber(nutriments, const ['energy_100g', 'energy']);
    if (energyKj != null) kcal = energyKj / 4.184;
  }

  final rawBrand = product['brands'];
  final brand =
      rawBrand is List
          ? (rawBrand.isEmpty ? null : rawBrand.first.toString().trim())
          : rawBrand?.toString().split(',').first.trim();

  return BarcodeLookupResult(
    found: true,
    source: 'open_food_facts_direct',
    name: name,
    brand: brand?.isEmpty == true ? null : brand,
    unit: _unitFromProduct(product),
    kcalPer100: kcal,
    proteinPer100: _firstNumber(nutriments, const [
      'proteins_100g',
      'proteins',
    ]),
    fatPer100: _firstNumber(nutriments, const ['fat_100g', 'fat']),
    carbsPer100: _firstNumber(nutriments, const [
      'carbohydrates_100g',
      'carbohydrates',
    ]),
    priceMin: _fixedPriceRange(product).$1,
    priceMax: _fixedPriceRange(product).$2,
  );
}

String? _firstText(Map<String, dynamic> values, List<String> keys) {
  for (final key in keys) {
    final text = values[key]?.toString().trim();
    if (text != null && text.isNotEmpty) return text;
  }
  return null;
}

double? _firstNumber(Map<String, dynamic> values, List<String> keys) {
  for (final key in keys) {
    final value = values[key];
    if (value is num) return value.toDouble();
    if (value is String) {
      final parsed = double.tryParse(value.replaceAll(',', '.'));
      if (parsed != null) return parsed;
    }
  }
  return null;
}

String _unitFromProduct(Map<String, dynamic> product) {
  final unit = product['product_quantity_unit']?.toString().toLowerCase();
  if (const {'ml', 'cl', 'dl', 'l'}.contains(unit)) return 'ml';
  if (const {'piece', 'pieces', 'szt', 'szt.'}.contains(unit)) return 'szt';
  return 'g';
}

/// Stałe, szerokie widełki detaliczne. Nie są wyliczane z przypadkowej
/// gramatury ani pojedynczej obserwacji cenowej.
(double, double) _fixedPriceRange(Map<String, dynamic> product) {
  final name =
      _firstText(product, const [
        'product_name_pl',
        'product_name',
        'abbreviated_product_name',
        'generic_name_pl',
        'generic_name',
      ]) ??
      '';
  final tags =
      product['categories_tags'] is List
          ? (product['categories_tags'] as List)
              .map((tag) => tag.toString().toLowerCase())
              .join(' ')
          : '';
  final text = '$name $tags'.toLowerCase();
  const ranges = <({List<String> keywords, (double, double) range})>[
    (keywords: ['masło', 'butter'], range: (6, 10)),
    (keywords: ['jaj', 'egg'], range: (8, 18)),
    (keywords: ['mleko', 'milk'], range: (3, 6)),
    (keywords: ['jogurt', 'yogurt'], range: (2, 7)),
    (keywords: ['ser ', 'sery', 'sera', 'twaróg', 'cheese'], range: (5, 18)),
    (keywords: ['pieczywo', 'chleb', 'bread', 'bakery'], range: (3, 9)),
    (keywords: ['ryba', 'fish', 'seafood', 'salmon', 'tuna'], range: (10, 40)),
    (keywords: ['mięso', 'meat', 'poultry', 'beef', 'pork'], range: (10, 35)),
    (
      keywords: [
        'makaron',
        'ryż',
        'mąka',
        'pasta',
        'rice',
        'flour',
        'cereal',
        'legume',
      ],
      range: (3, 12),
    ),
    (keywords: ['oliwa', 'olej', 'oil', 'vinegar'], range: (7, 30)),
    (
      keywords: ['przypraw', 'zioł', 'spice', 'seasoning', 'herb'],
      range: (2, 10),
    ),
    (keywords: ['warzyw', 'owoc', 'vegetable', 'fruit'], range: (2, 15)),
    (
      keywords: ['sos', 'ketchup', 'mustard', 'pesto', 'condiment'],
      range: (3, 15),
    ),
    (keywords: ['napój', 'sok', 'drink', 'soda', 'juice'], range: (3, 12)),
  ];
  for (final item in ranges) {
    if (item.keywords.any(text.contains)) return item.range;
  }
  return (3, 25);
}
