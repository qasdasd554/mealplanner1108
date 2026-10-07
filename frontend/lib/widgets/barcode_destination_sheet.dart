import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../screens/barcode_scanner_screen.dart';
import '../screens/tracker/add_food_entry_screen.dart';
import '../services/barcode_lookup_service.dart';
import '../services/pantry_service.dart';
import '../models/barcode_lookup_result.dart';
import '../models/product.dart';
import '../theme/app_theme.dart';
import '../utils/error_utils.dart';
import 'product_label_recognition_sheet.dart';
import 'product_amount_picker.dart';
import 'submit_product_sheet.dart';

enum _BarcodeDestination { tracking, productDatabase, pantry }

/// Skanuje kod tylko raz, a potem pozwala zdecydować, do czego wykorzystać
/// wynik. Zwraca true wyłącznie wtedy, gdy produkt został zapisany w bazie.
Future<bool> scanProductWithDestination(
  BuildContext context, {
  VoidCallback? onPantryAdded,
}) async {
  final barcode = await scanBarcode(context);
  if (barcode == null || !context.mounted) return false;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt(
    'successful_barcode_scans',
    (prefs.getInt('successful_barcode_scans') ?? 0) + 1,
  );
  if (!context.mounted) return false;

  final lookupService = BarcodeLookupService();
  BarcodeLookupResult? lookup;
  try {
    lookup = await lookupService.lookup(barcode);
  } catch (_) {
    // Poszczególne miejsca docelowe pokażą własny komunikat i pozwolą
    // uzupełnić produkt ze zdjęcia, jeśli zewnętrzna baza jest chwilowo
    // niedostępna.
  } finally {
    lookupService.close();
  }
  if (!context.mounted) return false;

  final selectedDestinations = <_BarcodeDestination>{};
  final destinations = await showModalBottomSheet<Set<_BarcodeDestination>>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder:
        (sheetContext) => StatefulBuilder(
          builder:
              (sheetContext, setSheetState) => SafeArea(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Gdzie dodać produkt?',
                          style: Theme.of(sheetContext).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Możesz zaznaczyć kilka miejsc jednocześnie.',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          lookup?.name == null
                              ? 'Kod: $barcode'
                              : lookup!.name!,
                          style: Theme.of(sheetContext).textTheme.titleMedium,
                        ),
                        if (lookup?.brand?.trim().isNotEmpty == true)
                          Text(
                            lookup!.brand!,
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        const SizedBox(height: 4),
                        Text(
                          _nutritionSummary(lookup) ??
                              'Nie odnaleziono kompletnych makroskładników. '
                                  'Po wybraniu miejsca uzupełnisz dane ze zdjęć opakowania.',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 10),
                        CheckboxListTile(
                          value: selectedDestinations.contains(
                            _BarcodeDestination.tracking,
                          ),
                          secondary: const Icon(
                            Icons.local_fire_department_outlined,
                          ),
                          title: const Text('Dodaj do Dziennika'),
                          subtitle: const Text(
                            'Wybierz ilość i rodzaj posiłku',
                          ),
                          controlAffinity: ListTileControlAffinity.trailing,
                          onChanged:
                              (selected) => setSheetState(() {
                                if (selected == true) {
                                  selectedDestinations.add(
                                    _BarcodeDestination.tracking,
                                  );
                                } else {
                                  selectedDestinations.remove(
                                    _BarcodeDestination.tracking,
                                  );
                                }
                              }),
                        ),
                        CheckboxListTile(
                          value: selectedDestinations.contains(
                            _BarcodeDestination.productDatabase,
                          ),
                          secondary: const Icon(Icons.inventory_2_outlined),
                          title: const Text('Dodaj do bazy produktów'),
                          subtitle: const Text(
                            'Sprawdź nazwę, markę i makroskładniki',
                          ),
                          controlAffinity: ListTileControlAffinity.trailing,
                          onChanged:
                              (selected) => setSheetState(() {
                                if (selected == true) {
                                  selectedDestinations.add(
                                    _BarcodeDestination.productDatabase,
                                  );
                                } else {
                                  selectedDestinations.remove(
                                    _BarcodeDestination.productDatabase,
                                  );
                                }
                              }),
                        ),
                        CheckboxListTile(
                          value: selectedDestinations.contains(
                            _BarcodeDestination.pantry,
                          ),
                          secondary: const Icon(Icons.kitchen_outlined),
                          title: const Text('Dodaj do spiżarni'),
                          subtitle: const Text('Zapisz jako 1 całe opakowanie'),
                          controlAffinity: ListTileControlAffinity.trailing,
                          onChanged:
                              (selected) => setSheetState(() {
                                if (selected == true) {
                                  selectedDestinations.add(
                                    _BarcodeDestination.pantry,
                                  );
                                } else {
                                  selectedDestinations.remove(
                                    _BarcodeDestination.pantry,
                                  );
                                }
                              }),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed:
                                selectedDestinations.isEmpty
                                    ? null
                                    : () => Navigator.pop(
                                      sheetContext,
                                      Set<_BarcodeDestination>.of(
                                        selectedDestinations,
                                      ),
                                    ),
                            icon: const Icon(Icons.check),
                            label: Text(
                              selectedDestinations.length > 1
                                  ? 'Dodaj do ${selectedDestinations.length} miejsc'
                                  : 'Dalej',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
        ),
  );
  if (destinations == null || destinations.isEmpty || !context.mounted) {
    return false;
  }

  var savedToDatabase = false;
  // Katalog zapisujemy przed spiżarnią. Spiżarnia materializuje trafienie
  // skanera jako produkt techniczny; gdy robiliśmy to w odwrotnej kolejności,
  // użytkownik wybierający oba miejsca dostawał potem fałszywy błąd duplikatu
  // i tracił należny punkt za własne zgłoszenie produktu.
  if (destinations.contains(_BarcodeDestination.productDatabase)) {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SubmitProductSheet(initialBarcode: barcode),
    );
    savedToDatabase = saved == true;
    if (!context.mounted) return savedToDatabase;
  }

  if (destinations.contains(_BarcodeDestination.pantry)) {
    final pantryAdded = await _addBarcodeToPantry(
      context,
      barcode,
      initialResult: lookup,
    );
    if (pantryAdded) onPantryAdded?.call();
    if (!context.mounted) return savedToDatabase;
  }

  if (destinations.contains(_BarcodeDestination.tracking)) {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddFoodEntryScreen(initialBarcode: barcode),
      ),
    );
  }

  return savedToDatabase;
}

String? _nutritionSummary(BarcodeLookupResult? result) {
  if (result == null || !result.hasCompleteNutrition) return null;
  final basis = result.unit == 'ml' ? '100 ml' : '100 g';
  final values = <String>[
    if (result.kcalPer100 != null) '${result.kcalPer100!.round()} kcal/$basis',
    if (result.proteinPer100 != null)
      'B ${result.proteinPer100!.toStringAsFixed(1)} g',
    if (result.fatPer100 != null) 'T ${result.fatPer100!.toStringAsFixed(1)} g',
    if (result.carbsPer100 != null)
      'W ${result.carbsPer100!.toStringAsFixed(1)} g',
  ];
  return values.isEmpty ? null : values.join(' · ');
}

Future<bool> _addBarcodeToPantry(
  BuildContext context,
  String barcode, {
  BarcodeLookupResult? initialResult,
}) async {
  final lookupService = BarcodeLookupService();
  try {
    var result = initialResult ?? await lookupService.lookup(barcode);
    if (!context.mounted) return false;
    if (!result.found ||
        (result.name?.trim().isEmpty ?? true) ||
        !result.hasCompleteNutrition) {
      final recognized = await showProductLabelRecognitionSheet(
        context,
        barcode: barcode,
      );
      if (!context.mounted || recognized == null) return false;
      result = recognized;
    }

    final amount = await showProductAmountPicker(
      context,
      product: Product(
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
        ),
      ),
      initialUnit: result.servingQuantity != null ? 'opak' : result.unit,
    );
    if (!context.mounted || amount == null) return false;

    final added = await PantryService().addFromBarcode(
      barcode,
      quantity: amount.quantity,
      unit: amount.measure.code,
      lookupResult: result,
    );
    if (!context.mounted) return true;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('${added.product.name} dodano do spiżarni.')),
      );
    return true;
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(friendlyError(error))));
    }
    return false;
  } finally {
    lookupService.close();
  }
}
