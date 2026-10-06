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
    showDragHandle: true,
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

  IconData _iconFor(ProductMeasureOption option) => switch (option.code) {
    'opak' => Icons.inventory_2_outlined,
    'szt' => Icons.circle_outlined,
    'lyzeczka' => Icons.restaurant_outlined,
    'szklanka' => Icons.local_drink_outlined,
    'ml' => Icons.water_drop_outlined,
    _ => Icons.scale_outlined,
  };

  void _submit() {
    final quantity = _quantity;
    if (quantity == null || quantity <= 0) return;
    Navigator.pop(
      context,
      ProductAmountSelection(quantity: quantity, measure: _selected),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final availableHeight =
        media.size.height -
        media.viewInsets.bottom -
        media.padding.top -
        media.padding.bottom -
        24;
    final sheetHeight =
        availableHeight.clamp(240.0, media.size.height * 0.88).toDouble();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      height: sheetHeight,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 2, 20, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      if (widget.product.brand?.trim().isNotEmpty == true)
                        Text(
                          widget.product.brand!,
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Zamknij',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              children: [
                Text(
                  'Szybki wybór',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 3),
                Text(
                  'Dotknij wariantu, aby od razu go wybrać.',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 10),
                ..._options.take(4).map(_buildQuickOption),
                const SizedBox(height: 10),
                const Divider(),
                const SizedBox(height: 8),
                Text(
                  'Własna ilość',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<ProductMeasureOption>(
                  initialValue: _selected,
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
                const SizedBox(height: 14),
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
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _baseAmountLabel(_selected, _quantity ?? 0),
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _macroPreview(),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              border: Border(
                top: BorderSide(
                  color: AppTheme.textSecondary.withValues(alpha: 0.15),
                ),
              ),
            ),
            child: SafeArea(
              top: false,
              minimum: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: (_quantity ?? 0) <= 0 ? null : _submit,
                  icon: const Icon(Icons.check),
                  label: const Text('Wybierz ilość'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickOption(ProductMeasureOption option) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppTheme.primaryColor.withValues(alpha: 0.055),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: AppTheme.primaryColor.withValues(alpha: 0.22),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _chooseQuickOption(option),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 58),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _iconFor(option),
                      size: 21,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '1 × ${option.label}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          _baseAmountLabel(option),
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _calorieLabel(option),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 2),
                  const Icon(Icons.chevron_right, size: 22),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
