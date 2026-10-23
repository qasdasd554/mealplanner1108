import 'dart:async';

import 'package:flutter/material.dart';
import '../utils/lookup_market_context.dart';
import 'package:provider/provider.dart';

import '../l10n/market_locale.dart';
import '../models/barcode_lookup_result.dart';
import '../providers/shopping_list_provider.dart';
import '../services/product_name_lookup_service.dart';
import '../theme/app_theme.dart';
import '../utils/error_utils.dart';

/// Okno dodawania pojedynczego produktu do listy zakupów — czegoś spoza
/// przepisów ("papier toaletowy", "mleko").
///
/// Wpisaną nazwę można dodać bezpośrednio jako dowolną pozycję albo
/// wybrać pasujący produkt katalogowy z ceną i działem sklepu.
class AddProductSheet extends StatefulWidget {
  const AddProductSheet({super.key, this.lookupService});

  final ProductNameLookupService? lookupService;

  @override
  State<AddProductSheet> createState() => _AddProductSheetState();
}

class _AddProductSheetState extends State<AddProductSheet> {
  late final ProductNameLookupService _search =
      widget.lookupService ??
      ProductNameLookupService(
        accountCountry: () => context.registeredLookupCountry,
      );
  final TextEditingController _queryController = TextEditingController();

  Timer? _debounce;
  List<BarcodeLookupResult> _results = [];
  bool _isSearching = false;
  bool _isAddingCustom = false;
  String? _busyProductId;
  String? _error;
  int _requestGeneration = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _queryController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    // Odpytujemy dopiero po 350 ms bez pisania — bez tego każde
    // naciśnięcie klawisza wysyłałoby osobne zapytanie do serwera.
    _debounce?.cancel();
    // Invalidate immediately: the previous response may arrive during debounce.
    _requestGeneration++;
    setState(() {
      _results = [];
      _error = null;
      _isSearching = false;
    });
    _debounce = Timer(
      const Duration(milliseconds: 350),
      () => _runSearch(value),
    );
  }

  Future<void> _runSearch(String value) async {
    final generation = ++_requestGeneration;
    if (value.trim().length < 2) {
      setState(() {
        _results = [];
        _error = null;
        _isSearching = false;
      });
      return;
    }
    setState(() {
      _isSearching = true;
      _error = null;
    });
    try {
      final found = await _search.search(value);
      if (!mounted || generation != _requestGeneration) return;
      setState(() {
        _results = found;
        _isSearching = false;
      });
    } catch (error) {
      if (!mounted || generation != _requestGeneration) return;
      setState(() {
        _results = [];
        _isSearching = false;
        _error = friendlyError(error, strings: context.strings);
      });
    }
  }

  Future<void> _addCustom() async {
    final name = _queryController.text.trim();
    if (name.isEmpty || _isAddingCustom || _busyProductId != null) return;
    setState(() => _isAddingCustom = true);
    final provider = Provider.of<ShoppingListProvider>(context, listen: false);
    final ok = await provider.addCustomItem(name);
    if (!mounted) return;
    setState(() => _isAddingCustom = false);
    if (ok) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(context.strings.shoppingAddSuccess(name))),
        );
    } else {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              provider.errorMessage ?? context.strings.shoppingAddCustomFailed,
            ),
            backgroundColor: AppTheme.errorColor,
          ),
        );
    }
  }

  Future<void> _add(BarcodeLookupResult product) async {
    if (_isAddingCustom || _busyProductId != null) return;
    final provider = Provider.of<ShoppingListProvider>(context, listen: false);
    final resultKey =
        product.existingProductId ??
        '${product.source}:${product.barcode}:${product.name}';
    setState(() => _busyProductId = resultKey);

    // Produkty z katalogu mają własne ID i zachowują dzięki temu dział
    // sklepu oraz cenę. Wyniki z pamięci skanów i Open Food Facts nie są
    // jeszcze pełnymi produktami katalogowymi, więc trafiają na listę jako
    // zwykła pozycja tekstowa. Użytkownik nadal może ją odhaczyć i usunąć.
    final existingProductId = product.existingProductId;
    final ok =
        existingProductId != null
            ? await provider.addProduct(existingProductId)
            : await provider.addCustomItem(product.name!.trim());

    if (!mounted) return;
    setState(() => _busyProductId = null);

    if (ok) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 3),
            content: Text(
              context.strings.shoppingAddSuccess(
                product.name ?? context.strings.shoppingAddProductFallback,
              ),
            ),
          ),
        );
    } else {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 3),
            content: Text(
              provider.errorMessage ?? context.strings.shoppingAddProductFailed,
            ),
            backgroundColor: AppTheme.errorColor,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Odsuwamy zawartość znad klawiatury, żeby pole wyszukiwania nie
      // chowało się pod nią po otwarciu.
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return CustomScrollView(
            controller: scrollController,
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppTheme.textSecondary.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.strings.shoppingAddProduct,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _queryController,
                            autofocus: true,
                            onChanged: _onQueryChanged,
                            decoration: InputDecoration(
                              hintText: context.strings.shoppingAddQueryHint,
                              prefixIcon: const Icon(Icons.search),
                              border: const OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed:
                                  _queryController.text.trim().isEmpty ||
                                          _isAddingCustom ||
                                          _busyProductId != null
                                      ? null
                                      : _addCustom,
                              icon:
                                  _isAddingCustom
                                      ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                      : const Icon(Icons.playlist_add),
                              label: Text(context.strings.shoppingAddCustom),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            context.strings.shoppingAddMatches,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (_isSearching || _error != null || _results.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child:
                      _isSearching
                          ? const Center(child: CircularProgressIndicator())
                          : _error != null
                          ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                _error!,
                                textAlign: TextAlign.center,
                                style: TextStyle(color: AppTheme.textSecondary),
                              ),
                            ),
                          )
                          : Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                _queryController.text.trim().length < 2
                                    ? context.strings.shoppingAddMinimumQuery
                                    : context.strings.shoppingAddNoResults,
                                textAlign: TextAlign.center,
                                style: TextStyle(color: AppTheme.textSecondary),
                              ),
                            ),
                          ),
                )
              else
                SliverList.builder(
                  itemCount: _results.length,
                  itemBuilder: (context, index) {
                    final p = _results[index];
                    final resultKey =
                        p.existingProductId ??
                        '${p.source}:${p.barcode}:${p.name}';
                    final isBusy = _busyProductId == resultKey;
                    return ListTile(
                      title: Text(
                        p.name ?? context.strings.shoppingAddProductFallback,
                      ),
                      subtitle: Text(
                        [
                          if (p.brand?.trim().isNotEmpty == true)
                            p.brand!.trim(),
                          if (p.kcalPer100 != null)
                            '${p.kcalPer100!.round()} kcal / 100 g',
                          switch (p.source) {
                            'catalog' =>
                              context.strings.shoppingAddCatalogSource,
                            'neon_cache' =>
                              context.strings.shoppingAddCacheSource,
                            _ => 'Open Food Facts',
                          },
                        ].join(' · '),
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing:
                          isBusy
                              ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : Icon(
                                Icons.add_circle_outline,
                                color: AppTheme.primaryColor,
                              ),
                      onTap:
                          _isAddingCustom || _busyProductId != null
                              ? null
                              : () => _add(p),
                    );
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}
