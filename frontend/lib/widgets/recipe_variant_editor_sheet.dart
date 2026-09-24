import 'dart:async';

import 'package:flutter/material.dart';

import '../models/product.dart';
import '../models/recipe.dart';
import '../services/product_search_service.dart';
import '../theme/app_theme.dart';
import '../utils/error_utils.dart';
import '../utils/quantity_formatter.dart';

/// Edytor roboczej listy składników. Niczego nie zapisuje na serwerze;
/// zwraca jedynie nową listę do ekranu szczegółów przepisu.
class RecipeVariantEditorSheet extends StatefulWidget {
  final List<RecipeIngredient> ingredients;

  const RecipeVariantEditorSheet({
    super.key,
    required this.ingredients,
  });

  @override
  State<RecipeVariantEditorSheet> createState() => _RecipeVariantEditorSheetState();
}

class _RecipeVariantEditorSheetState extends State<RecipeVariantEditorSheet> {
  late final List<RecipeIngredient> _ingredients;

  @override
  void initState() {
    super.initState();
    _ingredients = List<RecipeIngredient>.from(widget.ingredients);
  }

  Future<void> _addIngredient() async {
    final product = await showModalBottomSheet<Product>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _VariantProductPicker(),
    );
    if (product == null || !mounted) return;

    if (_ingredients.any((item) => item.productId == product.id)) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Ten produkt jest już na liście.')));
      return;
    }

    final quantity = await _askQuantity(
      name: product.name,
      initialQuantity: product.defaultQuantity,
      unit: product.unit,
    );
    if (quantity == null || !mounted) return;

    setState(() {
      _ingredients.add(
        RecipeIngredient(
          id: 'temporary:${product.id}',
          productId: product.id,
          productName: product.name,
          quantity: quantity,
          unit: product.unit,
          isOptional: false,
          product: product,
        ),
      );
    });
  }

  Future<void> _editQuantity(int index) async {
    final ingredient = _ingredients[index];
    final quantity = await _askQuantity(
      name: ingredient.productName ?? 'Składnik',
      initialQuantity: ingredient.quantity,
      unit: ingredient.unit,
    );
    if (quantity == null || !mounted) return;

    final factor = ingredient.quantity > 0 ? quantity / ingredient.quantity : 1.0;
    setState(() {
      _ingredients[index] = RecipeIngredient(
        id: ingredient.id,
        productId: ingredient.productId,
        productName: ingredient.productName,
        quantity: quantity,
        unit: ingredient.unit,
        isOptional: ingredient.isOptional,
        kcal: ingredient.kcal == null ? null : (ingredient.kcal! * factor).round(),
        protein: ingredient.protein == null ? null : ingredient.protein! * factor,
        fat: ingredient.fat == null ? null : ingredient.fat! * factor,
        carbs: ingredient.carbs == null ? null : ingredient.carbs! * factor,
        product: ingredient.product,
      );
    });
  }

  Future<double?> _askQuantity({
    required String name,
    required double initialQuantity,
    required String unit,
  }) async {
    final controller = TextEditingController(text: formatQuantity(initialQuantity, unit));
    final result = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(name),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: 'Ilość ($unit)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Anuluj'),
          ),
          FilledButton(
            onPressed: () {
              final value = double.tryParse(controller.text.replaceAll(',', '.'));
              Navigator.pop(dialogContext, value != null && value > 0 ? value : null);
            },
            child: const Text('Zmień'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.84,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.textSecondary.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Zmień składniki', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text(
                'Zmiany są tymczasowe. Oryginalny przepis pozostanie bez zmian.',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _addIngredient,
                icon: const Icon(Icons.add),
                label: const Text('Dodaj produkt'),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.separated(
                  itemCount: _ingredients.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final ingredient = _ingredients[index];
                    return Card(
                      elevation: 0,
                      color: AppTheme.surfaceColor,
                      child: ListTile(
                        title: Text(ingredient.productName ?? 'Składnik'),
                        subtitle: Text(
                          '${formatQuantity(ingredient.quantity, ingredient.unit)} ${ingredient.unit}',
                        ),
                        onTap: () => _editQuantity(index),
                        trailing: IconButton(
                          tooltip: 'Usuń składnik',
                          icon: const Icon(Icons.delete_outline, color: AppTheme.errorColor),
                          onPressed: () => setState(() => _ingredients.removeAt(index)),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _ingredients.isEmpty
                      ? null
                      : () => Navigator.pop(
                            context,
                            List<RecipeIngredient>.from(_ingredients),
                          ),
                  child: const Text('Zastosuj tymczasowo'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VariantProductPicker extends StatefulWidget {
  const _VariantProductPicker();

  @override
  State<_VariantProductPicker> createState() => _VariantProductPickerState();
}

class _VariantProductPickerState extends State<_VariantProductPicker> {
  final ProductSearchService _service = ProductSearchService();
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  List<Product> _results = [];
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => _search(value));
  }

  Future<void> _search(String value) async {
    if (value.trim().isEmpty) {
      setState(() {
        _results = [];
        _error = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await _service.search(value, limit: 30);
      if (!mounted) return;
      setState(() => _results = results);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.86,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Dodaj produkt', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              autofocus: true,
              onChanged: _onChanged,
              decoration: const InputDecoration(
                hintText: 'Wpisz nazwę produktu',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 8),
            if (_loading) const LinearProgressIndicator(),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_error!, style: const TextStyle(color: AppTheme.errorColor)),
              ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: _results.length,
                itemBuilder: (context, index) {
                  final product = _results[index];
                  return ListTile(
                    title: Text(product.name),
                    subtitle: product.brand == null ? null : Text('Marka: ${product.brand}'),
                    onTap: () => Navigator.pop(context, product),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
