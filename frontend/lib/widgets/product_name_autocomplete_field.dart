import 'dart:async';

import 'package:flutter/material.dart';

import '../models/barcode_lookup_result.dart';
import '../services/product_name_lookup_service.dart';
import '../theme/app_theme.dart';

/// Pole nazwy, które nadal przyjmuje dowolny tekst, ale po wpisaniu co
/// najmniej dwóch znaków pokazuje produkty z katalogu, skanów i OFF.
class ProductNameAutocompleteField extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<BarcodeLookupResult> onSelected;
  final String labelText;
  final String? hintText;
  final String? Function(String?)? validator;
  final int? maxLength;

  const ProductNameAutocompleteField({
    super.key,
    required this.controller,
    required this.onSelected,
    required this.labelText,
    this.hintText,
    this.validator,
    this.maxLength,
  });

  @override
  State<ProductNameAutocompleteField> createState() =>
      _ProductNameAutocompleteFieldState();
}

class _ProductNameAutocompleteFieldState
    extends State<ProductNameAutocompleteField> {
  final ProductNameLookupService _service = ProductNameLookupService();
  Timer? _debounce;
  List<BarcodeLookupResult> _results = const [];
  bool _loading = false;
  int _generation = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    final generation = ++_generation;
    final normalized = value.trim();
    if (normalized.length < 2) {
      setState(() {
        _results = const [];
        _loading = false;
      });
      return;
    }
    setState(() {
      _results = const [];
      _loading = true;
    });
    _debounce = Timer(
      const Duration(milliseconds: 600),
      () => _search(normalized, generation),
    );
  }

  Future<void> _search(String query, int generation) async {
    try {
      final results = await _service.search(query);
      if (!mounted || generation != _generation) return;
      setState(() {
        _results = results;
        _loading = false;
      });
    } catch (_) {
      // Awaria podpowiedzi nie może blokować ręcznego wpisania produktu.
      if (!mounted || generation != _generation) return;
      setState(() {
        _results = const [];
        _loading = false;
      });
    }
  }

  void _select(BarcodeLookupResult result) {
    _debounce?.cancel();
    _generation++;
    widget.controller.text = result.name ?? widget.controller.text;
    widget.controller.selection = TextSelection.collapsed(
      offset: widget.controller.text.length,
    );
    setState(() => _results = const []);
    FocusScope.of(context).unfocus();
    widget.onSelected(result);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: widget.controller,
          maxLength: widget.maxLength,
          onChanged: _onChanged,
          decoration: InputDecoration(
            labelText: widget.labelText,
            hintText: widget.hintText,
            border: const OutlineInputBorder(),
            suffixIcon: _loading
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : const Icon(Icons.search),
          ),
          validator: widget.validator,
        ),
        if (_results.isNotEmpty)
          Container(
            constraints: const BoxConstraints(maxHeight: 240),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              border: Border.all(
                color: AppTheme.textSecondary.withOpacity(0.25),
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: _results.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final result = _results[index];
                final details = <String>[
                  if (result.brand?.trim().isNotEmpty == true) result.brand!,
                  if (result.kcalPer100 != null)
                    '${result.kcalPer100!.round()} kcal / 100${result.unit == 'ml' || result.unit == 'l' ? 'ml' : 'g'}',
                  result.source == 'catalog'
                      ? 'katalog aplikacji'
                      : result.source == 'neon_cache'
                          ? 'wcześniej zeskanowany'
                          : 'Open Food Facts',
                ];
                return ListTile(
                  dense: true,
                  leading: const Icon(
                    Icons.inventory_2_outlined,
                    color: AppTheme.primaryColor,
                  ),
                  title: Text(result.name!),
                  subtitle: Text(
                    details.join(' · '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => _select(result),
                );
              },
            ),
          ),
        if (!_loading &&
            _results.isEmpty &&
            widget.controller.text.trim().length >= 2)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Możesz wybrać podpowiedź albo pozostawić własną nazwę.',
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
      ],
    );
  }
}
