import 'package:flutter/material.dart';

import '../screens/barcode_scanner_screen.dart';
import '../screens/tracker/add_food_entry_screen.dart';
import '../theme/app_theme.dart';
import 'submit_product_sheet.dart';

enum _BarcodeDestination { tracking, productDatabase }

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
