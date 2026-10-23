import 'dart:async';

import 'package:flutter/material.dart';
import '../utils/lookup_market_context.dart';
import '../l10n/market_locale.dart';
import '../l10n/recipe_content.dart';
import '../l10n/app_localizations.dart';
import '../l10n/measure_labels.dart';

import '../models/barcode_lookup_result.dart';
import '../models/product.dart';
import '../config/api_config.dart';
import '../screens/barcode_scanner_screen.dart';
import 'product_label_recognition_sheet.dart';
import '../services/api_client.dart';
import '../services/barcode_lookup_service.dart';
import '../theme/app_theme.dart';
import '../utils/error_utils.dart';
import 'product_amount_picker.dart';
import '../utils/barcode_utils.dart';

List<Product> mergeCatalogProducts(Iterable<List<Product>> responses) {
  final merged = <String, Product>{};
  for (final response in responses) {
    for (final product in response) {
      final barcode = normalizeScannedBarcode(product.barcode);
      // Taka sama etykieta nie identyfikuje wariantu ani opakowania.
      final key =
          barcode != null
              ? 'gtin:${barcode.padLeft(14, '0')}'
              : 'id:${product.id}';
      merged.putIfAbsent(key, () => product);
    }
  }
  return merged.values.toList()..sort((a, b) => a.name.compareTo(b.name));
}

/// Wynik wyboru produktu z katalogu — nazwa, ilość i wyliczone wartości
/// odżywcze gotowe do wstawienia w formularz dziennika.
class PickedCatalogProduct {
  final String name;
  final double quantity;
  final String unit;
  final double kcal;
  final double protein;
  final double fat;
  final double carbs;
  final double? portionSize;
  final String? portionUnit;

  const PickedCatalogProduct({
    required this.name,
    required this.quantity,
    required this.unit,
    required this.kcal,
    required this.protein,
    required this.fat,
    required this.carbs,
    this.portionSize,
    this.portionUnit,
  });

  String get amountLabel {
    if (unit == 'opak') {
      final package =
          quantity == 1
              ? '1 opakowanie'
              : '${quantity.toStringAsFixed(1)} opak.';
      if (portionSize != null && portionUnit != null) {
        final digits = portionSize == portionSize!.roundToDouble() ? 0 : 1;
        return '$package (${portionSize!.toStringAsFixed(digits)} $portionUnit)';
      }
      return package;
    }
    const labels = {
      'porcja': 'porcja',
      'szt': 'sztuka',
      'lyzeczka': 'łyżeczka',
      'szklanka': 'szklanka',
    };
    final digits = quantity == quantity.roundToDouble() ? 0 : 1;
    final label = labels[unit] ?? unit;
    return '${quantity.toStringAsFixed(digits)} × $label';
  }

  String amountLabelFor(AppLocalizations strings) {
    if (!strings.localeName.startsWith('en')) return amountLabel;
    final digits = quantity == quantity.roundToDouble() ? 0 : 1;
    final label = strings.measureQuantityLabel(
      unit,
      fallback: unit,
      amount: quantity,
    );
    final amount = '${quantity.toStringAsFixed(digits)} $label';
    if (portionSize == null ||
        portionUnit == null ||
        const {'g', 'ml'}.contains(unit)) {
      return amount;
    }
    final sizeDigits = portionSize == portionSize!.roundToDouble() ? 0 : 1;
    return '$amount (${portionSize!.toStringAsFixed(sizeDigits)} $portionUnit)';
  }
}

/// Okno wyszukiwania produktu w katalogu — domyka obietnicę złożoną przy
/// przycisku "Dodaj produkt": zgłoszony (i zatwierdzony) produkt miał być
/// możliwy do wybrania w Śledzeniu, ale nigdzie w aplikacji nie było
/// faktycznej wyszukiwarki, która by to umożliwiała. Ten widget to
/// naprawia — szuka po tym samym katalogu (`GET /products`), z którego
/// korzysta ekran "Baza produktów", więc własne zatwierdzone zgłoszenia
/// pojawiają się tu na równi z produktami oficjalnymi.
class PickProductFromCatalogSheet extends StatefulWidget {
  final bool scanOnOpen;
  final String? initialBarcode;
  final bool embedded;
  final ValueChanged<PickedCatalogProduct>? onPicked;
  final ApiClient? client;
  final BarcodeLookupService? lookupService;

  const PickProductFromCatalogSheet({
    super.key,
    this.scanOnOpen = false,
    this.initialBarcode,
    this.embedded = false,
    this.onPicked,
    this.client,
    this.lookupService,
  });

  @override
  State<PickProductFromCatalogSheet> createState() =>
      _PickProductFromCatalogSheetState();
}

class _PickProductFromCatalogSheetState
    extends State<PickProductFromCatalogSheet> {
  late final ApiClient _client;
  late final BarcodeLookupService _barcodeLookupService;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  int _requestGeneration = 0;

  List<Product> _results = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _client = widget.client ?? ApiClient();
    _barcodeLookupService =
        widget.lookupService ??
        BarcodeLookupService(
          accountCountry: () => context.registeredLookupCountry,
        );
    _search('');
    if (widget.initialBarcode != null || widget.scanOnOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (widget.initialBarcode != null) {
          _lookupBarcode(widget.initialBarcode!);
        } else {
          _scanBarcode();
        }
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _barcodeLookupService.close();
    _searchController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    // Odczekujemy chwilę po ostatnim znaku, zamiast odpytywać serwer
    // przy KAŻDYM naciśnięciu klawisza — przy szybkim pisaniu to
    // dziesiątki zbędnych żądań zamiast jednego.
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(query));
  }

  Future<List<Product>> _fetchAllProducts(
    String endpoint,
    String queryPart,
  ) async {
    const pageSize = 200;
    final products = <Product>[];
    for (var skip = 0; skip < 1000; skip += pageSize) {
      final response = await _client.get(
        '$endpoint?skip=$skip&limit=$pageSize$queryPart',
      );
      final page =
          (response as List)
              .map((item) => Product.fromJson(item as Map<String, dynamic>))
              .toList();
      products.addAll(page);
      if (page.length < pageSize) break;
    }
    return products;
  }

  Future<void> _search(String query) async {
    final generation = ++_requestGeneration;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final encodedQuery = Uri.encodeQueryComponent(query.trim());
      final queryPart = query.trim().isEmpty ? '' : '&search=$encodedQuery';
      // Końcowy ukośnik jest istotny: wcześniej "/products?" było
      // przekierowywane na "/products/?". Przy takim przekierowaniu klient
      // potrafił zgubić nagłówek Authorization, dlatego zalogowany
      // użytkownik dostawał błędny komunikat o konieczności logowania.
      final responses = await Future.wait<List<Product>>([
        _fetchAllProducts(ApiConfig.products, queryPart),
        _fetchAllProducts('${ApiConfig.products}scanned', queryPart),
      ]);
      if (!mounted || generation != _requestGeneration) return;

      setState(() {
        _results = mergeCatalogProducts(responses);
      });
    } catch (e) {
      if (!mounted || generation != _requestGeneration) return;
      setState(() => _error = friendlyError(e, strings: context.strings));
    } finally {
      if (mounted && generation == _requestGeneration) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _complete(PickedCatalogProduct product) {
    final callback = widget.onPicked;
    if (callback != null) {
      callback(product);
    } else {
      Navigator.of(context).pop(product);
    }
  }

  Future<void> _scanBarcode() async {
    final code = await scanBarcode(context);
    if (code == null || !mounted) return;

    await _lookupBarcode(code);
  }

  Future<void> _lookupBarcode(String code) async {
    if (!mounted) return;

    setState(() => _isLoading = true);
    try {
      var result = await _barcodeLookupService.lookup(code);
      if (!mounted) return;

      if (!result.found ||
          result.name == null ||
          !result.hasCompleteNutrition) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              duration: const Duration(seconds: 4),
              content: Text(context.strings.catalogueNutritionMissing),
            ),
          );
        final recognized = await showProductLabelRecognitionSheet(
          context,
          barcode: code,
        );
        if (!mounted || recognized == null) return;
        result = recognized;
      }

      setState(() => _isLoading = false);

      await _pickLookupResult(result);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 3),
            content: Text(friendlyError(e, strings: context.strings)),
          ),
        );
    }
  }

  Future<void> _pickLookupResult(BarcodeLookupResult result) async {
    if (!result.found ||
        (result.name?.trim().isEmpty ?? true) ||
        !result.hasCompleteNutrition) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.strings.catalogueIncomplete)),
      );
      return;
    }
    final product = Product(
      id: result.existingProductId ?? '',
      name: result.name!,
      brand: result.brand,
      unit: result.unit,
      defaultQuantity: 1,
      servingQuantity: result.servingQuantity,
      barcode: result.barcode,
      source: result.source,
      nutritionPer100: NutritionInfo(
        kcal: result.kcalPer100 ?? 0,
        protein: result.proteinPer100 ?? 0,
        fat: result.fatPer100 ?? 0,
        carbs: result.carbsPer100 ?? 0,
        fiber: 0,
        confirmedZeroValues: result.hasCompleteNutrition,
      ),
    );
    final selection = await showProductAmountPicker(
      context,
      product: product,
      initialUnit: result.servingQuantity != null ? 'opak' : result.unit,
    );
    if (selection == null || !mounted) return;

    final factor = selection.nutritionFactorPer100();
    _complete(
      PickedCatalogProduct(
        name: result.displayName(context) ?? result.name!,
        quantity: selection.quantity,
        unit: selection.measure.code,
        kcal: (result.kcalPer100 ?? 0) * factor,
        protein: (result.proteinPer100 ?? 0) * factor,
        fat: (result.fatPer100 ?? 0) * factor,
        carbs: (result.carbsPer100 ?? 0) * factor,
        portionSize: selection.measure.baseQuantity,
        portionUnit: selection.measure.baseUnit,
      ),
    );
  }

  Future<void> _pickProduct(Product product) async {
    final nutrition = product.nutritionPer100;
    final nutritionMissing = !nutrition.hasCompleteNutrition;
    if (nutritionMissing && product.barcode?.trim().isNotEmpty == true) {
      final recognized = await showProductLabelRecognitionSheet(
        context,
        barcode: product.barcode!,
      );
      if (!mounted || recognized == null) return;
      await _pickLookupResult(recognized);
      return;
    }

    if (nutritionMissing) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 4),
            content: Text(context.strings.catalogueIncomplete),
          ),
        );
      return;
    }

    if (product.barcode?.trim().isNotEmpty == true ||
        product.unit == 'opak' ||
        product.source == 'scan') {
      await _pickLookupResult(
        BarcodeLookupResult(
          found: true,
          source: product.source,
          name: product.name,
          existingProductId: product.id,
          brand: product.brand,
          unit: product.unit,
          barcode: product.barcode,
          servingQuantity: product.servingQuantity,
          kcalPer100: nutrition.kcal,
          proteinPer100: nutrition.protein,
          fatPer100: nutrition.fat,
          carbsPer100: nutrition.carbs,
        ),
      );
      return;
    }

    final selection = await showProductAmountPicker(
      context,
      product: product,
      initialQuantity: 1,
      initialUnit: product.servingQuantity != null ? 'opak' : product.unit,
    );
    if (selection == null || !mounted) return;

    // Jednostka bazowa produktu bywa "l"/"kg" (duże opakowanie) — okno
    // pyta zawsze o ml/g dla precyzji, więc gdy trzeba, przeliczamy na
    // jednostkę, w której faktycznie podane jest nutritionPer100 (zawsze
    // "na 100 g/ml", niezależnie od jednostki opakowania).
    final n = product.nutritionPer100;
    final factor = selection.nutritionFactorPer100();

    _complete(
      PickedCatalogProduct(
        name: product.displayName(context),
        quantity: selection.quantity,
        unit: selection.measure.code,
        kcal: n.kcal * factor,
        protein: n.protein * factor,
        fat: n.fat * factor,
        carbs: n.carbs * factor,
        portionSize: selection.measure.baseQuantity,
        portionUnit: selection.measure.baseUnit,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) {
      return _buildContents(null, showHandle: false);
    }
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return _buildContents(scrollController, showHandle: true);
      },
    );
  }

  Widget _buildContents(
    ScrollController? scrollController, {
    required bool showHandle,
  }) {
    return Column(
      children: [
        if (showHandle) ...[
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.textSecondary.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: TextField(
            controller: _searchController,
            autofocus: widget.initialBarcode == null && !widget.scanOnOpen,
            onChanged: _onQueryChanged,
            decoration: InputDecoration(
              hintText: context.strings.catalogueProductSearch,
              prefixIcon: const Icon(Icons.search),
              // Skanowanie tuż obok pola wyszukiwania — szybsza
              // alternatywa dla wpisywania nazwy, gdy opakowanie
              // jest pod ręką.
              suffixIcon: IconButton(
                icon: const Icon(Icons.barcode_reader),
                tooltip: context.strings.productsScan,
                onPressed: _scanBarcode,
              ),
            ),
          ),
        ),
        Expanded(
          child:
              _isLoading && _results.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Center(
                    child: Text(
                      _error!,
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  )
                  : _results.isEmpty
                  ? Center(
                    child: Text(
                      context.strings.catalogueNoMatch,
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  )
                  : ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _results.length,
                    itemBuilder: (context, index) {
                      final p = _results[index];
                      return ListTile(
                        title: Text(p.displayName(context)),
                        subtitle: Text(
                          '${p.nutritionPer100.knownValue('kcal')?.round() ?? '—'} kcal / 100${p.unit == 'ml' || p.unit == 'l' ? 'ml' : 'g'}'
                          '${p.brand != null && p.brand!.isNotEmpty ? ' · ${p.brand}' : ''}'
                          '${p.source == 'scan' ? ' · ${context.strings.autocompleteScanned}' : ''}',
                        ),
                        onTap: () => _pickProduct(p),
                      );
                    },
                  ),
        ),
      ],
    );
  }
}
