import 'package:flutter/material.dart';

import '../screens/barcode_scanner_screen.dart';
import '../screens/tracker/add_food_entry_screen.dart';
import '../services/barcode_lookup_service.dart';
import '../services/pantry_service.dart';
import '../theme/app_theme.dart';
import '../utils/error_utils.dart';
import '../utils/quantity_formatter.dart';
import 'product_label_recognition_sheet.dart';
import 'submit_product_sheet.dart';

enum _BarcodeDestination { tracking, productDatabase, pantry }

/// Skanuje kod tylko raz, a potem pozwala zdecydować, do czego wykorzystać
/// wynik. Zwraca true wyłącznie wtedy, gdy produkt został zapisany w bazie.
Future<bool> scanProductWithDestination(BuildContext context) async {
  final barcode = await scanBarcode(context);
  if (barcode == null || !context.mounted) return false;

  final destination = await showModalBottomSheet<_BarcodeDestination>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Co zrobić z produktem?',
              style: Theme.of(sheetContext).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              'Kod: $barcode',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 10),
            ListTile(
              leading: const Icon(Icons.local_fire_department_outlined),
              title: const Text('Dodaj do śledzenia'),
              subtitle: const Text('Wybierz ilość i rodzaj posiłku'),
              onTap: () => Navigator.pop(
                sheetContext,
                _BarcodeDestination.tracking,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.inventory_2_outlined),
              title: const Text('Dodaj do bazy produktów'),
              subtitle: const Text('Sprawdź nazwę, markę i makroskładniki'),
              onTap: () => Navigator.pop(
                sheetContext,
                _BarcodeDestination.productDatabase,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.kitchen_outlined),
              title: const Text('Dodaj do spiżarni'),
              subtitle: const Text('Podaj ilość i jednostkę produktu'),
              onTap: () => Navigator.pop(
                sheetContext,
                _BarcodeDestination.pantry,
              ),
            ),
          ],
        ),
      ),
    ),
  );
  if (destination == null || !context.mounted) return false;

  if (destination == _BarcodeDestination.tracking) {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddFoodEntryScreen(initialBarcode: barcode),
      ),
    );
    return false;
  }

  if (destination == _BarcodeDestination.pantry) {
    await _addBarcodeToPantry(context, barcode);
    return false;
  }

  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.surfaceColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => SubmitProductSheet(initialBarcode: barcode),
  );
  return saved == true;
}

Future<void> _addBarcodeToPantry(BuildContext context, String barcode) async {
  final lookupService = BarcodeLookupService();
  try {
    var result = await lookupService.lookup(barcode);
    if (!context.mounted) return;
    if (!result.found || (result.name?.trim().isEmpty ?? true)) {
      final recognized = await showProductLabelRecognitionSheet(
        context,
        barcode: barcode,
      );
      if (!context.mounted || recognized == null) return;
      result = recognized;
    }

    const units = ['g', 'kg', 'ml', 'l', 'szt'];
    var unit = units.contains(result.unit) ? result.unit : 'szt';
    final suggested = result.servingQuantity != null &&
            result.servingQuantity! > 0
        ? result.servingQuantity!
        : (unit == 'g' || unit == 'ml' ? 100.0 : 1.0);
    final controller = TextEditingController(
      text: formatQuantity(suggested, unit),
    );
    final amount = await showDialog<({double quantity, String unit})>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(result.name ?? 'Dodaj do spiżarni'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Ilość'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: unit,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Jednostka'),
                items: units
                    .map((value) => DropdownMenuItem(
                          value: value,
                          child: Text(value),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) setDialogState(() => unit = value);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Anuluj'),
            ),
            FilledButton(
              onPressed: () {
                final quantity = double.tryParse(
                  controller.text.trim().replaceAll(',', '.'),
                );
                if (quantity == null || quantity <= 0) return;
                Navigator.pop(
                  dialogContext,
                  (quantity: quantity, unit: unit),
                );
              },
              child: const Text('Dodaj'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (!context.mounted || amount == null) return;

    final added = await PantryService().addFromBarcode(
      barcode,
      quantity: amount.quantity,
      unit: amount.unit,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('${added.product.name} dodano do spiżarni.'),
      ));
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(friendlyError(error))));
  } finally {
    lookupService.close();
  }
}
