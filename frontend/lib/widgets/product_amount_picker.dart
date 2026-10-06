import 'package:flutter/material.dart';

import '../models/product.dart';
import '../theme/app_theme.dart';
import '../utils/product_measures.dart';

Future<ProductAmountSelection?> showProductAmountPicker(
  BuildContext context, {
  required Product product,
  double initialQuantity = 1,
  String? initialUnit,
}) {
  return showModalBottomSheet<ProductAmountSelection>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppTheme.surfaceColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder:
        (_) => _ProductAmountPicker(
          product: product,
          initialQuantity: initialQuantity,
          initialUnit: initialUnit,
        ),
  );
}

class _ProductAmountPicker extends StatefulWidget {
  final Product product;
  final double initialQuantity;
  final String? initialUnit;

  const _ProductAmountPicker({
    required this.product,
    required this.initialQuantity,
    this.initialUnit,
  });

  @override
  State<_ProductAmountPicker> createState() => _ProductAmountPickerState();
}

class _ProductAmountPickerState extends State<_ProductAmountPicker> {
  late final List<ProductMeasureOption> _options;
  late ProductMeasureOption _selected;
  late final TextEditingController _quantityController;

  @override
  void initState() {
    super.initState();
    _options = effectiveMeasureOptions(widget.product);
    _selected = _options.firstWhere(
      (option) => option.code == widget.initialUnit,
      orElse: () => _options.first,
    );
    _quantityController = TextEditingController(
      text:
          widget.initialQuantity == widget.initialQuantity.roundToDouble()
              ? widget.initialQuantity.toStringAsFixed(0)
              : widget.initialQuantity.toStringAsFixed(1),
    );
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  double? get _quantity =>
      double.tryParse(_quantityController.text.trim().replaceAll(',', '.'));

  String _macroPreview() {
    final quantity = _quantity;
    if (quantity == null || quantity <= 0) return 'Podaj ilość większą od zera';
    final factor = quantity * _selected.baseQuantity / 100;
    final n = widget.product.nutritionPer100;
    return '${(n.kcal * factor).round()} kcal  •  '
        'B ${(n.protein * factor).toStringAsFixed(1)} g  •  '
        'T ${(n.fat * factor).toStringAsFixed(1)} g  •  '
        'W ${(n.carbs * factor).toStringAsFixed(1)} g';
  }

  String _baseAmountLabel(ProductMeasureOption option, [double quantity = 1]) {
    final amount = quantity * option.baseQuantity;
    final digits = amount == amount.roundToDouble() ? 0 : 1;
    return '${option.approximate ? 'ok. ' : ''}'
        '${amount.toStringAsFixed(digits)} ${option.baseUnit}';
  }

  String _calorieLabel(ProductMeasureOption option, [double quantity = 1]) {
    final kcal =
        widget.product.nutritionPer100.kcal *
        quantity *
        option.baseQuantity /
        100;
    return '${kcal.round()} kcal';
  }

  void _chooseQuickOption(ProductMeasureOption option) {
    Navigator.pop(
      context,
      ProductAmountSelection(quantity: 1, measure: option),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.textSecondary.withOpacity(.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              widget.product.name,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (widget.product.brand?.trim().isNotEmpty == true)
              Text(
                widget.product.brand!,
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            const SizedBox(height: 18),
            Text('Szybki wybór', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            ..._options
                .take(4)
                .map(
                  (option) => InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => _chooseQuickOption(option),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 5,
                            child: Text(
                              '1 × ${option.label}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Text(
                              _baseAmountLabel(option),
                              textAlign: TextAlign.end,
                              style: TextStyle(color: AppTheme.textSecondary),
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 66,
                            child: Text(
                              _calorieLabel(option),
                              textAlign: TextAlign.end,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                    ),
                  ),
                ),
            const Divider(height: 20),
            Text('Inna ilość', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            DropdownButtonFormField<ProductMeasureOption>(
              value: _selected,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Jednostka',
                border: OutlineInputBorder(),
              ),
              items:
                  _options
                      .map(
                        (option) => DropdownMenuItem(
                          value: option,
                          child: Text(option.label),
                        ),
                      )
                      .toList(),
              onChanged: (option) {
                if (option == null) return;
                setState(() {
                  _selected = option;
                  _quantityController.text = '1';
                });
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _quantityController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Ilość',
                suffixText: _selected.label,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _baseAmountLabel(_selected, _quantity ?? 0),
              style: TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 4),
            Text(
              _macroPreview(),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed:
                    (_quantity ?? 0) <= 0
                        ? null
                        : () => Navigator.pop(
                          context,
                          ProductAmountSelection(
                            quantity: _quantity!,
                            measure: _selected,
                          ),
                        ),
                child: const Text('Wybierz'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
