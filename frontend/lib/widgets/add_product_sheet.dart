import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../providers/shopping_list_provider.dart';
import '../services/product_search_service.dart';
import '../theme/app_theme.dart';
import '../utils/error_utils.dart';

/// Okno dodawania pojedynczego produktu do listy zakupów — czegoś spoza
/// przepisów ("papier toaletowy", "mleko").
///
/// Wpisaną nazwę można dodać bezpośrednio jako dowolną pozycję albo
/// wybrać pasujący produkt katalogowy z ceną i działem sklepu.
class AddProductSheet extends StatefulWidget {
  const AddProductSheet({super.key});

  @override
  State<AddProductSheet> createState() => _AddProductSheetState();
}

class _AddProductSheetState extends State<AddProductSheet> {
  final ProductSearchService _search = ProductSearchService();
  final TextEditingController _queryController = TextEditingController();

  Timer? _debounce;
  List<Product> _results = [];
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
    setState(() {});
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
        _error = friendlyError(error);
      });
    }
  }

  Future<void> _addCustom() async {
    final name = _queryController.text.trim();
    if (name.isEmpty || _isAddingCustom) return;
    setState(() => _isAddingCustom = true);
    final provider = Provider.of<ShoppingListProvider>(context, listen: false);
    final ok = await provider.addCustomItem(name);
    if (!mounted) return;
    setState(() => _isAddingCustom = false);
    if (ok) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Dodano: $name')));
    } else {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              provider.errorMessage ?? 'Nie udało się dodać pozycji',
            ),
            backgroundColor: AppTheme.errorColor,
          ),
        );
    }
  }

  Future<void> _add(Product product) async {
    final provider = Provider.of<ShoppingListProvider>(context, listen: false);
    setState(() => _busyProductId = product.id);

    final ok = await provider.addProduct(
      product.id,
      quantity: product.defaultQuantity > 0 ? product.defaultQuantity : 1,
      unit: product.unit,
    );

    if (!mounted) return;
    setState(() => _busyProductId = null);

    if (ok) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 3),
            content: Text('Dodano: ${product.name}'),
          ),
        );
    } else {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 3),
            content: Text(
              provider.errorMessage ?? 'Nie udało się dodać produktu',
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
          return Column(
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
                      'Dodaj produkt do listy',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _queryController,
                      autofocus: true,
                      onChanged: _onQueryChanged,
                      decoration: const InputDecoration(
                        hintText: 'Wpisz dowolną pozycję…',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed:
                            _queryController.text.trim().isEmpty ||
                                    _isAddingCustom
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
                        label: const Text('Dodaj wpisaną pozycję'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Pasujące produkty z katalogu',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
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
                        : _results.isEmpty
                        ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              _queryController.text.trim().length < 2
                                  ? 'Wpisz co najmniej 2 znaki, żeby wyszukać produkt.'
                                  : 'Nie znaleziono produktu o takiej nazwie.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppTheme.textSecondary),
                            ),
                          ),
                        )
                        : ListView.builder(
                          controller: scrollController,
                          itemCount: _results.length,
                          itemBuilder: (context, index) {
                            final p = _results[index];
                            final isBusy = _busyProductId == p.id;
                            return ListTile(
                              title: Text(p.name),
                              subtitle: Text(
                                [
                                  if (p.brand != null && p.brand!.isNotEmpty)
                                    p.brand!,
                                  '${p.defaultQuantity.toStringAsFixed(0)} ${p.unit}',
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
                              onTap: isBusy ? null : () => _add(p),
                            );
                          },
                        ),
              ),
            ],
          );
        },
      ),
    );
  }
}
