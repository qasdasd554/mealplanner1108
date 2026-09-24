import 'dart:async';
import 'package:flutter/material.dart';

import '../models/product.dart';
import '../config/api_config.dart';
import '../screens/barcode_scanner_screen.dart';
import 'product_label_recognition_sheet.dart';
import '../services/api_client.dart';
import '../services/barcode_lookup_service.dart';
import '../theme/app_theme.dart';
import '../utils/error_utils.dart';

/// Wynik wyboru produktu z katalogu — nazwa, ilość i wyliczone wartości
/// odżywcze gotowe do wstawienia w formularz dziennika.
class PickedCatalogProduct {
  final String name;
  final double grams;
  final double kcal;
  final double protein;
  final double fat;
  final double carbs;

  const PickedCatalogProduct({
    required this.name,
    required this.grams,
    required this.kcal,
    required this.protein,
    required this.fat,
    required this.carbs,
  });
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

  const PickProductFromCatalogSheet({
    super.key,
    this.scanOnOpen = false,
    this.initialBarcode,
    this.embedded = false,
    this.onPicked,
  });

  @override
  State<PickProductFromCatalogSheet> createState() =>
      _PickProductFromCatalogSheetState();
}

class _PickProductFromCatalogSheetState
    extends State<PickProductFromCatalogSheet> {
  final ApiClient _client = ApiClient();
  final BarcodeLookupService _barcodeLookupService = BarcodeLookupService();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  int _requestGeneration = 0;

  List<Product> _results = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
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

      final merged = <String, Product>{};
      for (final response in responses) {
        for (final product in response) {
          final key =
              '${product.name.trim().toLowerCase()}|'
              '${(product.brand ?? '').trim().toLowerCase()}';
          // Katalog oficjalny jest pobierany pierwszy i ma pierwszeństwo
          // przed takim samym rekordem z cache skanera.
          merged.putIfAbsent(key, () => product);
        }
      }
      setState(() {
        _results =
            merged.values.toList()..sort((a, b) => a.name.compareTo(b.name));
      });
    } catch (e) {
      if (!mounted || generation != _requestGeneration) return;
      setState(() => _error = friendlyError(e));
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

      if (!result.found || result.name == null) {
        setState(() => _isLoading = false);
        final recognized = await showProductLabelRecognitionSheet(
          context,
          barcode: code,
        );
        if (!mounted || recognized == null) return;
        result = recognized;
      }

      setState(() => _isLoading = false);

      // Ilość — TA SAMA ścieżka co przy wyborze produktu z listy, żeby
      // zachowanie było spójne niezależnie od tego, czy trafiono
      // wyszukiwaniem tekstowym, czy skanowaniem.
      final suggested = result.servingQuantity ?? 100;
      final controller = TextEditingController(
        text:
            suggested == suggested.roundToDouble()
                ? suggested.toStringAsFixed(0)
                : suggested.toStringAsFixed(1),
      );
      final grams = await showDialog<double>(
        context: context,
        builder:
            (ctx) => AlertDialog(
              title: Text(result.name!),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (result.brand?.trim().isNotEmpty == true)
                    Text('Marka: ${result.brand}'),
                  if (result.priceMin != null && result.priceMax != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 12),
                      child: Text(
                        'Typowy zakres cen: ${result.priceMin!.toStringAsFixed(0)}–${result.priceMax!.toStringAsFixed(0)} zł',
                      ),
                    ),
                  TextField(
                    controller: controller,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'Ilość (${result.unit})',
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Anuluj'),
                ),
                FilledButton(
                  onPressed: () {
                    final val = double.tryParse(
                      controller.text.replaceAll(',', '.'),
                    );
                    Navigator.pop(ctx, val);
                  },
                  child: const Text('Dalej'),
                ),
              ],
            ),
      );
      controller.dispose();
      if (grams == null || grams <= 0 || !mounted) return;

      final factor = grams / 100.0;
      _complete(
        PickedCatalogProduct(
          name: result.name!,
          grams: grams,
          kcal: (result.kcalPer100 ?? 0) * factor,
          protein: (result.proteinPer100 ?? 0) * factor,
          fat: (result.fatPer100 ?? 0) * factor,
          carbs: (result.carbsPer100 ?? 0) * factor,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 3),
            content: Text(friendlyError(e)),
          ),
        );
    }
  }

  Future<void> _pickProduct(Product product) async {
    final controller = TextEditingController(
      text:
          product.defaultQuantity > 0
              ? product.defaultQuantity.toStringAsFixed(0)
              : '100',
    );
    final grams = await showDialog<double>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(product.name),
            content: TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              autofocus: true,
              decoration: InputDecoration(
                labelText:
                    'Ilość (${product.unit == 'ml' || product.unit == 'l' ? 'ml' : 'g'})',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Anuluj'),
              ),
              FilledButton(
                onPressed: () {
                  final val = double.tryParse(
                    controller.text.replaceAll(',', '.'),
                  );
                  Navigator.pop(ctx, val);
                },
                child: const Text('Dalej'),
              ),
            ],
          ),
    );
    controller.dispose();
    if (grams == null || grams <= 0 || !mounted) return;

    // Jednostka bazowa produktu bywa "l"/"kg" (duże opakowanie) — okno
    // pyta zawsze o ml/g dla precyzji, więc gdy trzeba, przeliczamy na
    // jednostkę, w której faktycznie podane jest nutritionPer100 (zawsze
    // "na 100 g/ml", niezależnie od jednostki opakowania).
    final n = product.nutritionPer100;
    final factor = grams / 100.0;

    _complete(
      PickedCatalogProduct(
        name: product.name,
        grams: grams,
        kcal: n.kcal * factor,
        protein: n.protein * factor,
        fat: n.fat * factor,
        carbs: n.carbs * factor,
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
              hintText: 'Szukaj produktu...',
              prefixIcon: const Icon(Icons.search),
              // Skanowanie tuż obok pola wyszukiwania — szybsza
              // alternatywa dla wpisywania nazwy, gdy opakowanie
              // jest pod ręką.
              suffixIcon: IconButton(
                icon: const Icon(Icons.barcode_reader),
                tooltip: 'Skanuj kod kreskowy',
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
                      'Brak produktów pasujących do wyszukiwania.',
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
                        title: Text(p.name),
                        subtitle: Text(
                          '${p.nutritionPer100.kcal.round()} kcal / 100${p.unit == 'ml' || p.unit == 'l' ? 'ml' : 'g'}'
                          '${p.brand != null && p.brand!.isNotEmpty ? ' · ${p.brand}' : ''}'
                          '${p.source == 'scan' ? ' · zeskanowany' : ''}',
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
