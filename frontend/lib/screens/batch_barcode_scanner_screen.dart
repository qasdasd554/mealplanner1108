import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../services/api_client.dart';
import '../services/pantry_service.dart';
import '../theme/app_theme.dart';
import '../utils/barcode_utils.dart';
import '../utils/error_utils.dart';
import '../widgets/product_label_recognition_sheet.dart';
import '../widgets/submit_product_sheet.dart';
import 'tracker/add_food_entry_screen.dart';

/// Seryjne skanowanie Premium. Aparat pozostaje otwarty, a każdy poprawnie
/// rozpoznany produkt jest od razu dodawany do spiżarni. Ten sam kod w jednej
/// sesji jest obsługiwany tylko raz, więc kamera nie tworzy duplikatów.
class BatchBarcodeScannerScreen extends StatefulWidget {
  const BatchBarcodeScannerScreen({super.key});

  @override
  State<BatchBarcodeScannerScreen> createState() =>
      _BatchBarcodeScannerScreenState();
}

class _BatchBarcodeScannerScreenState
    extends State<BatchBarcodeScannerScreen> {
  final MobileScannerController _scanner = MobileScannerController(
    facing: CameraFacing.back,
    detectionSpeed: DetectionSpeed.noDuplicates,
    autoZoom: true,
    formats: const [
      BarcodeFormat.ean8,
      BarcodeFormat.ean13,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
      BarcodeFormat.code128,
      BarcodeFormat.itf,
    ],
  );
  final PantryService _pantry = PantryService();
  final Set<String> _seen = {};
  final List<_BatchScanItem> _items = [];
  final List<String> _queue = [];
  bool _processing = false;
  bool _itemActionBusy = false;

  bool get _busy => _processing || _queue.isNotEmpty || _itemActionBusy;

  @override
  void dispose() {
    _scanner.dispose();
    super.dispose();
  }

  Future<void> _onScan(BarcodeCapture capture) async {
    if (!mounted) return;
    String? code;
    for (final candidate in capture.barcodes) {
      final normalized = normalizeScannedBarcode(candidate.rawValue);
      if (normalized != null && !_seen.contains(normalized)) {
        code = normalized;
        break;
      }
    }
    if (code == null) return;
    final scannedCode = code;

    _seen.add(scannedCode);
    setState(() {
      _queue.add(scannedCode);
      _items.insert(
        0,
        _BatchScanItem(code: scannedCode, state: _BatchState.loading),
      );
    });
    await _processQueue();
  }

  Future<void> _processQueue() async {
    if (_processing) return;
    _processing = true;
    while (_queue.isNotEmpty && mounted) {
      final scannedCode = _queue.removeAt(0);
      if (mounted) setState(() {});
      await _processCode(scannedCode);
    }
    _processing = false;
    if (mounted) setState(() {});
  }

  Future<void> _processCode(String scannedCode) async {
    try {
      final pantryItem = await _pantry.addFromBarcode(
        scannedCode,
        // W trybie batch backend dobiera właściwą ilość i jednostkę po
        // rozpoznaniu produktu. Te wartości są bezpiecznym fallbackiem.
        quantity: 1,
        unit: 'szt',
        batch: true,
      );
      if (!mounted) return;
      _replaceItem(
        scannedCode,
        state: _BatchState.added,
        name: pantryItem.product.name,
        quantity: pantryItem.quantity,
        unit: pantryItem.unit,
      );
    } catch (error) {
      if (!mounted) return;
      _replaceItem(
        scannedCode,
        state: error is ApiException && error.statusCode == 404
            ? _BatchState.missing
            : _BatchState.error,
        message: error is ApiException && error.statusCode == 404
            ? 'Nie znaleziono. Dotknij, aby dodać produkt ze zdjęć.'
            : friendlyError(error),
      );
    }
  }

  Future<void> _completeMissingProduct(_BatchScanItem item) async {
    if (item.state != _BatchState.missing || _busy) return;
    setState(() => _itemActionBusy = true);
    await _scanner.stop();
    try {
      if (!mounted) return;
      final recognized = await showProductLabelRecognitionSheet(
        context,
        barcode: item.code,
      );
      if (!mounted || recognized == null) return;
      _replaceItem(
        item.code,
        state: _BatchState.loading,
        name: recognized.name,
      );
      await _processCode(item.code);
    } finally {
      if (mounted) {
        setState(() => _itemActionBusy = false);
        try {
          await _scanner.start();
        } catch (_) {
          // Powrót z formularza może zbiec się z zamknięciem ekranu.
        }
      }
    }
  }

  Future<void> _openProductActions(_BatchScanItem item) async {
    if (item.state != _BatchState.added || _busy) return;
    setState(() => _itemActionBusy = true);
    await _scanner.stop();
    try {
      if (!mounted) return;
      final destination = await showModalBottomSheet<_BatchDestination>(
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
                  item.name ?? item.code,
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                const ListTile(
                  enabled: false,
                  leading: Icon(Icons.kitchen_outlined),
                  title: Text('Dodano do spiżarni'),
                ),
                ListTile(
                  leading: const Icon(Icons.local_fire_department_outlined),
                  title: const Text('Dodaj do śledzenia'),
                  subtitle: const Text('Wybierz ilość i rodzaj posiłku'),
                  onTap: () => Navigator.pop(
                    sheetContext,
                    _BatchDestination.tracking,
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.inventory_2_outlined),
                  title: const Text('Dodaj lub sprawdź w bazie produktów'),
                  subtitle: const Text('Nazwa, marka i makroskładniki'),
                  onTap: () => Navigator.pop(
                    sheetContext,
                    _BatchDestination.productDatabase,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      if (!mounted || destination == null) return;
      if (destination == _BatchDestination.tracking) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AddFoodEntryScreen(initialBarcode: item.code),
          ),
        );
      } else {
        await showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          backgroundColor: AppTheme.surfaceColor,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (_) => SubmitProductSheet(initialBarcode: item.code),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _itemActionBusy = false);
        try {
          await _scanner.start();
        } catch (_) {
          // Ekran mógł zostać zamknięty podczas powrotu z formularza.
        }
      }
    }
  }

  void _replaceItem(
    String code, {
    required _BatchState state,
    String? name,
    double? quantity,
    String? unit,
    String? message,
  }) {
    setState(() {
      final index = _items.indexWhere((item) => item.code == code);
      if (index == -1) return;
      _items[index] = _BatchScanItem(
        code: code,
        state: state,
        name: name,
        quantity: quantity,
        unit: unit,
        message: message,
      );
    });
  }

  int get _addedCount =>
      _items.where((item) => item.state == _BatchState.added).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Skanowanie seryjne'),
        actions: [
          TextButton(
            onPressed: _busy
                ? null
                : () => Navigator.of(context).pop(_addedCount),
            child: const Text('Zakończ'),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: Stack(
              fit: StackFit.expand,
              children: [
                MobileScanner(
                  controller: _scanner,
                  onDetect: _onScan,
                  tapToFocus: true,
                  errorBuilder: (context, error) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Nie można uruchomić aparatu. Sprawdź uprawnienie do kamery.\n$error',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
                IgnorePointer(
                  child: Center(
                    child: Container(
                      width: MediaQuery.sizeOf(context).width * .82,
                      height: 135,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white, width: 3),
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 12,
                  right: 12,
                  top: 12,
                  child: Card(
                    color: Colors.black.withOpacity(.72),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      child: Text(
                        _busy
                            ? 'Rozpoznaję produkty · oczekuje ${_queue.length + 1}'
                            : 'Skanuj kolejne produkty. Aparat pozostanie otwarty.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Container(
              color: AppTheme.backgroundColor,
              child: _items.isEmpty
                  ? Center(
                      child: Text(
                        'Zeskanowane produkty pojawią się tutaj.',
                        style: TextStyle(color: AppTheme.textSecondary),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (_, index) => _buildItem(_items[index]),
                    ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _busy
                      ? null
                      : () => Navigator.of(context).pop(_addedCount),
                  icon: const Icon(Icons.check),
                  label: Text('Zakończ · dodano $_addedCount'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItem(_BatchScanItem item) {
    final (icon, color, status) = switch (item.state) {
      _BatchState.loading =>
        (Icons.hourglass_top, AppTheme.textSecondary, 'Rozpoznawanie…'),
      _BatchState.added =>
        (Icons.check_circle, AppTheme.primaryColor, 'Dodano do spiżarni'),
      _BatchState.missing =>
        (Icons.add_a_photo_outlined, AppTheme.secondaryColor,
          item.message ?? 'Dotknij, aby uzupełnić produkt'),
      _BatchState.error =>
        (Icons.error_outline, AppTheme.errorColor, item.message ?? 'Błąd'),
    };
    return Card(
      child: ListTile(
        dense: true,
        leading: Icon(icon, color: color),
        title: Text(
          item.name ?? item.code,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          item.state == _BatchState.added
              ? '$status · ${item.quantity?.toStringAsFixed(0)} ${item.unit}\n'
                  'Dotknij, aby dodać też do śledzenia lub bazy produktów.'
              : status,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: switch (item.state) {
          _BatchState.missing => const Icon(Icons.chevron_right),
          _BatchState.added => const Icon(Icons.more_horiz),
          _ => null,
        },
        onTap: switch (item.state) {
          _BatchState.missing => () => _completeMissingProduct(item),
          _BatchState.added => () => _openProductActions(item),
          _ => null,
        },
      ),
    );
  }
}

enum _BatchState { loading, added, missing, error }

enum _BatchDestination { tracking, productDatabase }

class _BatchScanItem {
  final String code;
  final _BatchState state;
  final String? name;
  final double? quantity;
  final String? unit;
  final String? message;

  const _BatchScanItem({
    required this.code,
    required this.state,
    this.name,
    this.quantity,
    this.unit,
    this.message,
  });
}
