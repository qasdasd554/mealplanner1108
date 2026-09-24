import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../models/barcode_lookup_result.dart';
import '../services/api_client.dart';
import '../services/barcode_lookup_service.dart';
import '../services/pantry_service.dart';
import '../theme/app_theme.dart';
import '../utils/barcode_utils.dart';
import '../utils/error_utils.dart';
import '../widgets/product_label_recognition_sheet.dart';

/// Seryjne skanowanie Premium. Aparat pozostaje otwarty, a użytkownik
/// wybiera jeden cel dla całej sesji i zatwierdza wszystkie rozpoznane
/// produkty jednym przyciskiem.
class BatchBarcodeScannerScreen extends StatefulWidget {
  const BatchBarcodeScannerScreen({super.key});

  @override
  State<BatchBarcodeScannerScreen> createState() =>
      _BatchBarcodeScannerScreenState();
}

class _BatchBarcodeScannerScreenState extends State<BatchBarcodeScannerScreen> {
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
  final BarcodeLookupService _lookup = BarcodeLookupService();
  final ApiClient _api = ApiClient();
  final Set<String> _seen = {};
  final List<_BatchScanItem> _items = [];
  final List<String> _queue = [];

  bool _processing = false;
  bool _itemActionBusy = false;
  bool _submitting = false;
  _BatchDestination? _destination;
  String _mealType = 'Przekąska';

  bool get _lookupBusy => _processing || _queue.isNotEmpty;
  bool get _busy => _lookupBusy || _itemActionBusy || _submitting;
  int get _readyCount =>
      _items.where((item) => item.state == _BatchState.ready).length;
  int get _completedCount =>
      _items.where((item) => item.state == _BatchState.completed).length;
  int get _errorCount =>
      _items.where((item) => item.state == _BatchState.error).length;

  @override
  void dispose() {
    _scanner.dispose();
    _lookup.close();
    super.dispose();
  }

  Future<void> _onScan(BarcodeCapture capture) async {
    if (!mounted || _submitting || _itemActionBusy) return;
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
      final result = await _lookup.lookup(scannedCode);
      if (!mounted) return;
      if (!result.found || (result.name?.trim().isEmpty ?? true)) {
        _replaceItem(
          scannedCode,
          state: _BatchState.missing,
          message: 'Nie znaleziono. Dotknij, aby dodać produkt ze zdjęć.',
        );
        return;
      }
      _replaceItem(scannedCode, state: _BatchState.ready, result: result);
    } catch (error) {
      if (!mounted) return;
      final missing = error is ApiException && error.statusCode == 404;
      _replaceItem(
        scannedCode,
        state: missing ? _BatchState.missing : _BatchState.error,
        message:
            missing
                ? 'Nie znaleziono. Dotknij, aby dodać produkt ze zdjęć.'
                : '${friendlyError(error)} Dotknij, aby spróbować ponownie.',
      );
    }
  }

  Future<void> _retryItem(_BatchScanItem item) async {
    if (_busy || item.state != _BatchState.error) return;
    if (item.result != null) {
      _replaceItem(item.code, state: _BatchState.ready, result: item.result);
      return;
    }
    _replaceItem(item.code, state: _BatchState.loading);
    await _processCode(item.code);
  }

  Future<void> _completeMissingProduct(_BatchScanItem item) async {
    if (item.state != _BatchState.missing || _busy) return;
    setState(() => _itemActionBusy = true);
    try {
      await _scanner.stop();
      if (!mounted) return;
      final recognized = await showProductLabelRecognitionSheet(
        context,
        barcode: item.code,
      );
      if (!mounted || recognized == null) return;
      _replaceItem(item.code, state: _BatchState.ready, result: recognized);
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

  double _defaultQuantity(BarcodeLookupResult result) {
    final known = result.servingQuantity;
    if (known != null && known > 0) return known;
    return _supportedUnit(result) == 'szt' ? 1 : 100;
  }

  String _supportedUnit(BarcodeLookupResult result) {
    const supported = {'g', 'kg', 'ml', 'l', 'szt'};
    return supported.contains(result.unit) ? result.unit : 'szt';
  }

  String _formatDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  Future<String> _saveItem(_BatchScanItem item) async {
    final result = item.result!;
    switch (_destination!) {
      case _BatchDestination.pantry:
        await _pantry.addFromBarcode(
          item.code,
          quantity: _defaultQuantity(result),
          unit: _supportedUnit(result),
          batch: true,
        );
        return 'Dodano do spiżarni';
      case _BatchDestination.tracking:
        final amount = _defaultQuantity(result);
        final unit = _supportedUnit(result);
        final nutritionFactor =
            unit == 'szt' && result.servingQuantity == null
                ? 1.0
                : amount / 100;
        await _api.post(
          '/food-log/',
          body: {
            'date': _formatDate(DateTime.now()),
            'meal_type': _mealType,
            'custom_name': result.name,
            'servings': 1,
            'calories': (result.kcalPer100 ?? 0) * nutritionFactor,
            'protein': (result.proteinPer100 ?? 0) * nutritionFactor,
            'fat': (result.fatPer100 ?? 0) * nutritionFactor,
            'carbs': (result.carbsPer100 ?? 0) * nutritionFactor,
          },
        );
        return 'Dodano do śledzenia';
      case _BatchDestination.productDatabase:
        if (result.existingProductId != null) return 'Już jest w katalogu';
        await _api.post(
          '/products/submit',
          body: {
            'name': result.name,
            'unit': _supportedUnit(result),
            if (result.brand?.trim().isNotEmpty == true) 'brand': result.brand,
            if (result.kcalPer100 != null) 'kcal_per_100': result.kcalPer100,
            if (result.proteinPer100 != null)
              'protein_per_100': result.proteinPer100,
            if (result.fatPer100 != null) 'fat_per_100': result.fatPer100,
            if (result.carbsPer100 != null) 'carbs_per_100': result.carbsPer100,
            'store_ids': <String>[],
            'barcode': item.code,
          },
        );
        return 'Dodano do katalogu';
    }
  }

  Future<bool> _saveAndUpdate(_BatchScanItem item) async {
    try {
      final label = await _saveItem(item);
      if (!mounted) return false;
      _replaceItem(
        item.code,
        state: _BatchState.completed,
        result: item.result,
        destinationLabel: label,
      );
      return true;
    } catch (error) {
      if (!mounted) return false;
      if (_destination == _BatchDestination.productDatabase &&
          error is ApiException &&
          error.statusCode == 409) {
        _replaceItem(
          item.code,
          state: _BatchState.completed,
          result: item.result,
          destinationLabel: 'Produkt jest już zgłoszony',
        );
        return true;
      }
      _replaceItem(
        item.code,
        state: _BatchState.error,
        result: item.result,
        message: '${friendlyError(error)} Dotknij, aby ponowić.',
      );
      return false;
    }
  }

  Future<void> _applyToAll() async {
    if (_destination == null || _readyCount == 0 || _busy) return;
    final pending = _items
        .where((item) => item.state == _BatchState.ready)
        .toList(growable: false);
    setState(() {
      _submitting = true;
      for (final item in pending) {
        final index = _items.indexWhere(
          (candidate) => candidate.code == item.code,
        );
        if (index != -1) {
          _items[index] = item.copyWith(state: _BatchState.saving);
        }
      }
    });
    try {
      await _scanner.stop();
      // Niewielkie grupy skracają czas operacji, ale nie zalewają backendu
      // dziesiątkami równoczesnych żądań na słabszym połączeniu.
      var savedCount = 0;
      for (var start = 0; start < pending.length; start += 4) {
        final end = start + 4 < pending.length ? start + 4 : pending.length;
        final results = await Future.wait(
          pending.sublist(start, end).map(_saveAndUpdate),
        );
        savedCount += results.where((saved) => saved).length;
      }
      if (mounted) {
        final failedCount = pending.length - savedCount;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                failedCount == 0
                    ? 'Dodano ${pending.length} produktów.'
                    : 'Dodano $savedCount z ${pending.length}. '
                        'Dotknij błędnych pozycji i spróbuj ponownie.',
              ),
            ),
          );
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
        if (_readyCount > 0 || _errorCount > 0) {
          try {
            await _scanner.start();
          } catch (_) {
            // Ekran mógł zostać zamknięty w trakcie zapisu.
          }
        }
      }
    }
  }

  void _replaceItem(
    String code, {
    required _BatchState state,
    BarcodeLookupResult? result,
    String? message,
    String? destinationLabel,
  }) {
    setState(() {
      final index = _items.indexWhere((item) => item.code == code);
      if (index == -1) return;
      final previous = _items[index];
      _items[index] = previous.copyWith(
        state: state,
        result: result,
        message: message,
        destinationLabel: destinationLabel,
      );
    });
  }

  String get _disabledReason {
    if (_lookupBusy) return 'Poczekaj, aż rozpoznam wszystkie kody.';
    if (_items.isEmpty) return 'Najpierw zeskanuj przynajmniej jeden produkt.';
    if (_readyCount == 0 && _completedCount == 0) {
      return 'Uzupełnij lub ponów nierozpoznane produkty.';
    }
    if (_destination == null) return 'Wybierz jedno miejsce dla całej serii.';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final cameraHeight = (screenHeight * .34).clamp(210.0, 310.0).toDouble();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Skanowanie seryjne'),
        actions: [
          TextButton(
            onPressed:
                _submitting
                    ? null
                    : () => Navigator.of(context).pop(_completedCount),
            child: const Text('Zakończ'),
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: cameraHeight,
            child: Stack(
              fit: StackFit.expand,
              children: [
                MobileScanner(
                  controller: _scanner,
                  onDetect: _onScan,
                  tapToFocus: true,
                  errorBuilder:
                      (context, error) => Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'Nie można uruchomić aparatu. Sprawdź uprawnienie '
                            'do kamery.\n$error',
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
                        _lookupBusy
                            ? 'Rozpoznaję produkty · oczekuje '
                                '${_queue.length + (_processing ? 1 : 0)}'
                            : 'Skanuj kolejne produkty. Miejsce wybierzesz '
                                'raz dla całej serii.',
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
            child: Container(
              color: AppTheme.backgroundColor,
              child:
                  _items.isEmpty
                      ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.qr_code_scanner,
                                size: 44,
                                color: AppTheme.textSecondary,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Zeskanowane produkty pojawią się tutaj.',
                                style: TextStyle(color: AppTheme.textSecondary),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
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
          _buildBatchActions(),
        ],
      ),
    );
  }

  Widget _buildBatchActions() {
    final canApply = !_busy && _readyCount > 0 && _destination != null;
    final canFinish = !_busy && _readyCount == 0 && _completedCount > 0;
    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 10,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dodaj wszystkie do',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    _BatchDestination.values
                        .map(
                          (destination) => ChoiceChip(
                            avatar: Icon(destination.icon, size: 18),
                            label: Text(destination.label),
                            selected: _destination == destination,
                            onSelected:
                                _submitting
                                    ? null
                                    : (_) => setState(() {
                                      _destination = destination;
                                    }),
                          ),
                        )
                        .toList(),
              ),
              if (_destination == _BatchDestination.tracking) ...[
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: _mealType,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Rodzaj posiłku dla wszystkich',
                    isDense: true,
                  ),
                  items:
                      const [
                            'Śniadanie',
                            'Obiad',
                            'Kolacja',
                            'Przekąska',
                            'Deser',
                          ]
                          .map(
                            (type) => DropdownMenuItem(
                              value: type,
                              child: Text(type),
                            ),
                          )
                          .toList(),
                  onChanged:
                      _submitting
                          ? null
                          : (value) => setState(() {
                            if (value != null) _mealType = value;
                          }),
                ),
              ],
              const SizedBox(height: 8),
              if (!canApply && !canFinish && !_submitting)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _disabledReason,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed:
                      canApply
                          ? _applyToAll
                          : canFinish
                          ? () => Navigator.of(context).pop(_completedCount)
                          : null,
                  icon:
                      _submitting
                          ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : Icon(
                            canFinish ? Icons.check : Icons.playlist_add_check,
                          ),
                  label: Text(
                    _submitting
                        ? 'Dodaję produkty…'
                        : canFinish
                        ? 'Gotowe · $_completedCount produktów'
                        : 'Dodaj wszystkie ($_readyCount)',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItem(_BatchScanItem item) {
    final (icon, color, status) = switch (item.state) {
      _BatchState.loading => (
        Icons.hourglass_top,
        AppTheme.textSecondary,
        'Rozpoznawanie…',
      ),
      _BatchState.ready => (
        Icons.check_circle_outline,
        AppTheme.secondaryColor,
        'Gotowy do wspólnego dodania',
      ),
      _BatchState.saving => (Icons.sync, AppTheme.secondaryColor, 'Dodawanie…'),
      _BatchState.completed => (
        Icons.check_circle,
        AppTheme.primaryColor,
        item.destinationLabel ?? 'Gotowe',
      ),
      _BatchState.missing => (
        Icons.add_a_photo_outlined,
        AppTheme.secondaryColor,
        item.message ?? 'Dotknij, aby uzupełnić produkt',
      ),
      _BatchState.error => (
        Icons.error_outline,
        AppTheme.errorColor,
        item.message ?? 'Błąd. Dotknij, aby ponowić.',
      ),
    };
    return Card(
      child: ListTile(
        minVerticalPadding: 10,
        leading:
            item.state == _BatchState.saving
                ? SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: color,
                  ),
                )
                : Icon(icon, color: color),
        title: Text(
          item.result?.name ?? item.code,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(status, maxLines: 3, overflow: TextOverflow.ellipsis),
        trailing: switch (item.state) {
          _BatchState.missing => const Icon(Icons.chevron_right),
          _BatchState.error => const Icon(Icons.refresh),
          _ => null,
        },
        onTap: switch (item.state) {
          _BatchState.missing => () => _completeMissingProduct(item),
          _BatchState.error => () => _retryItem(item),
          _ => null,
        },
      ),
    );
  }
}

enum _BatchState { loading, ready, saving, completed, missing, error }

enum _BatchDestination {
  pantry('Spiżarnia', Icons.kitchen_outlined),
  tracking('Śledzenie', Icons.local_fire_department_outlined),
  productDatabase('Katalog', Icons.inventory_2_outlined);

  final String label;
  final IconData icon;

  const _BatchDestination(this.label, this.icon);
}

class _BatchScanItem {
  final String code;
  final _BatchState state;
  final BarcodeLookupResult? result;
  final String? message;
  final String? destinationLabel;

  const _BatchScanItem({
    required this.code,
    required this.state,
    this.result,
    this.message,
    this.destinationLabel,
  });

  _BatchScanItem copyWith({
    _BatchState? state,
    BarcodeLookupResult? result,
    String? message,
    String? destinationLabel,
  }) {
    return _BatchScanItem(
      code: code,
      state: state ?? this.state,
      result: result ?? this.result,
      message: message,
      destinationLabel: destinationLabel,
    );
  }
}
