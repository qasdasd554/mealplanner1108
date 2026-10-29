import 'dart:math';

import 'package:flutter/material.dart';
import '../../utils/lookup_market_context.dart';
import '../l10n/market_locale.dart';
import '../l10n/catalog_labels.dart';
import '../widgets/manual_barcode_dialog.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../models/barcode_lookup_result.dart';
import '../providers/auth_provider.dart';
import '../providers/food_log_provider.dart';
import '../services/api_client.dart';
import '../services/barcode_lookup_service.dart';
import '../services/pantry_service.dart';
import '../theme/app_theme.dart';
import '../utils/barcode_utils.dart';
import '../utils/scanner_camera_lifecycle.dart';
import '../utils/batch_tracking_payload.dart';
import '../utils/error_utils.dart';
import '../widgets/product_label_recognition_sheet.dart';

/// Seryjne skanowanie Premium. Aparat pozostaje otwarty, a użytkownik
/// wybiera jedno lub kilka miejsc dla całej sesji i zatwierdza wszystkie
/// produkty jednym przyciskiem.
class BatchBarcodeScannerScreen extends StatefulWidget {
  final bool previewOnly;
  final MobileScannerController? controller;
  final BarcodeLookupService? lookupService;
  final ApiClient? client;
  final PantryService? pantryService;

  const BatchBarcodeScannerScreen({
    super.key,
    this.previewOnly = false,
    this.controller,
    this.lookupService,
    this.client,
    this.pantryService,
  });

  @override
  State<BatchBarcodeScannerScreen> createState() =>
      _BatchBarcodeScannerScreenState();
}

class _BatchBarcodeScannerScreenState extends State<BatchBarcodeScannerScreen> {
  late final MobileScannerController _scanner =
      widget.controller ??
      MobileScannerController(
        autoStart: false,
        facing: CameraFacing.back,
        lensType: CameraLensType.normal,
        detectionSpeed: DetectionSpeed.normal,
        autoZoom: true,
        formats: const [
          BarcodeFormat.ean8,
          BarcodeFormat.ean13,
          BarcodeFormat.upcA,
          BarcodeFormat.upcE,
        ],
      );
  late final PantryService _pantry = widget.pantryService ?? PantryService();
  late final BarcodeLookupService _lookup =
      widget.lookupService ??
      BarcodeLookupService(
        accountCountry: () => context.registeredLookupCountry,
      );
  late final ApiClient _api = widget.client ?? ApiClient();
  final Set<String> _seen = {};
  final List<_BatchScanItem> _items = [];
  final List<String> _queue = [];
  final BarcodeScanConfirmation _confirmation = BarcodeScanConfirmation();

  bool _processing = false;
  bool _itemActionBusy = false;
  bool _submitting = false;
  bool _manualEntryOpen = false;
  bool _closeRange = false;
  double _zoom = 1;
  final Set<_BatchDestination> _destinations = {};
  String _mealType = 'Przekąska';
  ScannerCameraLifecycle? _camera;
  bool _cameraVisible = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible =
        !widget.previewOnly &&
        (context.watch<AuthProvider>().currentUser?.hasPremiumAccess ?? false);
    if (_cameraVisible == visible) return;
    _cameraVisible = visible;
    if (visible) {
      _camera ??= ScannerCameraLifecycle(
        _scanner,
        onPause: _confirmation.reset,
        onStarted: _resetCameraControls,
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            _cameraVisible &&
            (widget.controller == null || _scanner.autoStart)) {
          _camera!.start();
        }
      });
    } else {
      _camera?.suspend();
    }
  }

  void _resetCameraControls() {
    if (!mounted || (!_closeRange && _zoom == 1)) return;
    setState(() {
      _closeRange = false;
      _zoom = 1;
    });
  }

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
    _camera?.dispose();
    _lookup.close();
    super.dispose();
  }

  Future<void> _onScan(BarcodeCapture capture) async {
    if (!mounted ||
        _submitting ||
        _itemActionBusy ||
        !(_camera?.canDetect ?? false)) {
      return;
    }
    final candidates = <String>{};
    for (final candidate in capture.barcodes) {
      final normalized = normalizeScannedBarcode(candidate.rawValue);
      if (normalized != null && !_seen.contains(normalized)) {
        candidates.add(normalized);
      }
    }
    if (candidates.length != 1) {
      _confirmation.reset();
      return;
    }

    final code = candidates.single;
    if (!_confirmation.confirm(code, DateTime.now())) return;

    _enqueueCode(code);
    await _processQueue();
  }

  void _enqueueCode(String scannedCode) {
    if (_seen.contains(scannedCode)) return;
    _seen.add(scannedCode);
    setState(() {
      _queue.add(scannedCode);
      _items.insert(
        0,
        _BatchScanItem(
          code: scannedCode,
          state: _BatchState.loading,
          trackingRequestId: _newTrackingRequestId(),
        ),
      );
    });
  }

  Future<void> _setZoom(double zoom) async {
    try {
      if (zoom == 1) {
        await _scanner.resetZoomScale();
      } else {
        await _scanner.setZoomScale(zoom);
      }
      if (mounted) setState(() => _zoom = zoom);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.strings.scanZoomUnavailable)),
        );
      }
    }
  }

  Future<void> _toggleCloseRange() async {
    try {
      if (_closeRange) {
        await _scanner.switchCamera(
          const SelectCamera(
            facingDirection: CameraFacing.back,
            lensType: CameraLensType.normal,
          ),
        );
        if (mounted) setState(() => _closeRange = false);
        return;
      }
      final best = await _scanner.getBestCloseRangeScanningLens(
        facing: CameraFacing.back,
      );
      final supported = await _scanner.getSupportedLenses(
        facing: CameraFacing.back,
      );
      if (best == null ||
          best == CameraLensType.normal ||
          !supported.contains(best)) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(context.strings.scanZoomHint)));
        }
        return;
      }
      await _scanner.switchCamera(
        SelectCamera(facingDirection: CameraFacing.back, lensType: best),
      );
      if (mounted) setState(() => _closeRange = true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.strings.scanLensFailed)));
      }
    }
  }

  Future<void> _enterManually() async {
    if (_busy || _manualEntryOpen) return;
    _manualEntryOpen = true;
    try {
      await _camera?.suspend();
      if (!mounted || !_cameraVisible) return;
      final barcode = await showManualBarcodeDialog(context, batch: true);
      if (!mounted || barcode == null) return;
      if (_seen.contains(barcode)) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.strings.scanDuplicate)));
        return;
      }
      _enqueueCode(barcode);
      await _processQueue();
    } finally {
      _manualEntryOpen = false;
      if (mounted && _cameraVisible) await _camera?.resume();
    }
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
          message: context.strings.scanMissing,
        );
        return;
      }
      if (!result.hasCompleteNutrition) {
        _replaceItem(
          scannedCode,
          state: _BatchState.missing,
          result: result,
          message: context.strings.scanMissingNutrition,
        );
        return;
      }
      if (!hasKnownBarcodePackageSize(result)) {
        _replaceItem(
          scannedCode,
          state: _BatchState.missing,
          result: result,
          message: context.strings.scanMissingPackage,
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
                ? context.strings.scanMissing
                : context.strings.scanRetryError(
                  friendlyError(error, strings: context.strings),
                ),
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
      await _camera?.suspend();
      if (!mounted) return;
      final recognized = await showProductLabelRecognitionSheet(
        context,
        barcode: item.code,
      );
      if (!mounted || recognized == null) return;
      if (!recognized.hasCompleteNutrition) {
        _replaceItem(
          item.code,
          state: _BatchState.missing,
          result: recognized,
          message: context.strings.scanCorrectNutrition,
        );
        return;
      }
      if (!hasKnownBarcodePackageSize(recognized)) {
        _replaceItem(
          item.code,
          state: _BatchState.missing,
          result: recognized,
          message: context.strings.scanCorrectPackage,
        );
        return;
      }
      _replaceItem(item.code, state: _BatchState.ready, result: recognized);
    } finally {
      if (mounted) {
        setState(() => _itemActionBusy = false);
        try {
          if (_cameraVisible) await _camera?.start();
        } catch (_) {
          // Ekran mógł zostać zamknięty podczas powrotu z formularza.
        }
      }
    }
  }

  Future<String> _saveItem(
    _BatchScanItem item,
    _BatchDestination destination,
  ) async {
    final result = item.result!;
    final strings = context.strings;
    switch (destination) {
      case _BatchDestination.pantry:
        await _pantry.addFromBarcode(
          item.code,
          quantity: 1,
          unit: barcodePackageUnit,
          batch: true,
          lookupResult: result,
        );
        return strings.scanAddedPantry;
      case _BatchDestination.tracking:
        final payload = buildBatchTrackingPayload(
          result: result,
          mealType: _mealType,
          date: DateTime.now(),
          packageLabel:
              strings.localeName.startsWith('en')
                  ? '1 ${strings.measurePack}'
                  : null,
        );
        payload['client_entry_id'] = item.trackingRequestId;
        final response = await _api.post('/food-log/', body: payload);
        if (response is! Map<String, dynamic> ||
            response['calories'] == null ||
            response['protein'] == null ||
            response['fat'] == null ||
            response['carbs'] == null) {
          throw ApiException(502, strings.scanNutritionUnconfirmed);
        }
        return strings.scanAddedDiary;
      case _BatchDestination.productDatabase:
        if (result.existingProductId != null) {
          return strings.scanAlreadyCatalogue;
        }
        try {
          final response = await _api.post(
            '/products/submit',
            body: {
              'name': result.name,
              'unit': barcodePackageUnit,
              if (result.servingQuantity != null)
                'serving_quantity': result.servingQuantity,
              'serving_unit':
                  const {'g', 'ml', 'szt'}.contains(result.unit)
                      ? result.unit
                      : 'g',
              if (result.brand?.trim().isNotEmpty == true)
                'brand': result.brand,
              if (result.kcalPer100 != null) 'kcal_per_100': result.kcalPer100,
              if (result.proteinPer100 != null)
                'protein_per_100': result.proteinPer100,
              if (result.fatPer100 != null) 'fat_per_100': result.fatPer100,
              if (result.carbsPer100 != null)
                'carbs_per_100': result.carbsPer100,
              'store_ids': <String>[],
              'barcode': item.code,
            },
          );
          final awarded =
              response is Map<String, dynamic>
                  ? (response['points_awarded'] as num?)?.toInt() ?? 0
                  : 0;
          return awarded > 0
              ? strings.scanAddedPoints(awarded)
              : strings.scanAddedCatalogue;
        } on ApiException catch (error) {
          if (error.statusCode == 409) return strings.scanAlreadySubmitted;
          rethrow;
        }
    }
  }

  Future<bool> _saveAndUpdate(_BatchScanItem item) async {
    final completed = Set<_BatchDestination>.of(item.completedDestinations);
    try {
      final labels = <String>[];
      // Stała kolejność zapobiega konfliktowi: dodanie do spiżarni tworzy
      // techniczny produkt, więc zgłoszenie do katalogu wykonane później
      // wyglądałoby jak duplikat i nie przyznałoby punktu użytkownikowi.
      const saveOrder = [
        _BatchDestination.productDatabase,
        _BatchDestination.pantry,
        _BatchDestination.tracking,
      ];
      for (final destination in saveOrder) {
        if (!_destinations.contains(destination)) continue;
        if (completed.contains(destination)) continue;
        labels.add(await _saveItem(item, destination));
        completed.add(destination);
      }
      if (!mounted) return false;
      _replaceItem(
        item.code,
        state: _BatchState.completed,
        result: item.result,
        destinationLabel: labels.join(' · '),
        completedDestinations: completed,
      );
      return true;
    } catch (error) {
      if (!mounted) return false;
      _replaceItem(
        item.code,
        state: _BatchState.error,
        result: item.result,
        message: context.strings.scanRetrySavedError(
          friendlyError(error, strings: context.strings),
        ),
        completedDestinations: completed,
      );
      return false;
    }
  }

  Future<void> _applyToAll() async {
    if (_destinations.isEmpty || _readyCount == 0 || _busy) return;
    final pending = _items
        .where((item) => item.state == _BatchState.ready)
        .toList(growable: false);
    final pendingCodes = pending.map((item) => item.code).toSet();
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
      await _camera?.suspend();
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
      if (mounted && _destinations.contains(_BatchDestination.tracking)) {
        final provider = context.read<FoodLogProvider>();
        final today = DateTime.now();
        if (provider.currentDate.year == today.year &&
            provider.currentDate.month == today.month &&
            provider.currentDate.day == today.day) {
          await provider.fetchLogsForDate(today);
        }
      }
      if (mounted &&
          _destinations.contains(_BatchDestination.productDatabase) &&
          _items.any(
            (item) =>
                pendingCodes.contains(item.code) &&
                item.completedDestinations.contains(
                  _BatchDestination.productDatabase,
                ),
          )) {
        await context.read<AuthProvider>().loadProfile();
      }
      if (mounted) {
        final failedCount = pending.length - savedCount;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                failedCount == 0
                    ? context.strings.scanAddedCount(pending.length)
                    : context.strings.scanAddedPartial(
                      savedCount,
                      pending.length,
                    ),
              ),
            ),
          );
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
        if (_cameraVisible && (_readyCount > 0 || _errorCount > 0)) {
          try {
            await _camera?.start();
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
    Set<_BatchDestination>? completedDestinations,
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
        completedDestinations: completedDestinations,
      );
    });
  }

  String get _disabledReason {
    if (_lookupBusy) return context.strings.scanWaitLookup;
    if (_items.isEmpty) return context.strings.scanFirstProduct;
    if (_readyCount == 0 && _completedCount == 0) {
      return context.strings.scanCompleteMissing;
    }
    if (_destinations.isEmpty) {
      return context.strings.scanChooseDestinations;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.previewOnly) return _buildPremiumPreview();
    final hasPremium =
        context.watch<AuthProvider>().currentUser?.hasPremiumAccess ?? false;
    if (!hasPremium) return _buildPremiumPreview();

    final screenHeight = MediaQuery.sizeOf(context).height;
    final cameraHeight = (screenHeight * .34).clamp(210.0, 310.0).toDouble();
    return Scaffold(
      appBar: AppBar(
        title: Text(context.strings.scanBatchTitle),
        actions: [
          TextButton(
            onPressed:
                _submitting
                    ? null
                    : () => Navigator.of(context).pop(_completedCount),
            child: Text(context.strings.scanFinish),
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
                  useAppLifecycleState: false,
                  onDetect: _onScan,
                  tapToFocus: true,
                  errorBuilder:
                      (context, error) => Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            context.strings.scanBatchCameraError(
                              error.toString(),
                            ),
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
                            ? context.strings.scanQueueCount(
                              _queue.length + (_processing ? 1 : 0),
                            )
                            : context.strings.scanBatchGuide,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 8,
                  child: Card(
                    color: Colors.black.withOpacity(.72),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          tooltip:
                              _zoom == 1
                                  ? context.strings.scanZoomTwo
                                  : context.strings.scanZoomOne,
                          onPressed: () => _setZoom(_zoom == 1 ? 2 : 1),
                          icon: Icon(
                            _zoom == 1 ? Icons.zoom_in : Icons.zoom_out,
                            color: Colors.white,
                          ),
                        ),
                        IconButton(
                          tooltip:
                              _closeRange
                                  ? context.strings.scanNormalLens
                                  : context.strings.scanCloseUpMode,
                          onPressed: _toggleCloseRange,
                          icon: const Icon(
                            Icons.center_focus_strong,
                            color: Colors.white,
                          ),
                        ),
                        IconButton(
                          tooltip: context.strings.scanTorch,
                          onPressed: _scanner.toggleTorch,
                          icon: const Icon(
                            Icons.flashlight_on,
                            color: Colors.white,
                          ),
                        ),
                        IconButton(
                          tooltip: context.strings.scanManual,
                          onPressed: _enterManually,
                          icon: const Icon(Icons.keyboard, color: Colors.white),
                        ),
                      ],
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
                                context.strings.scanBatchEmpty,
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
        ],
      ),
      // Scaffold positions SnackBars above this panel instead of covering
      // the retry/confirm button when a destination fails.
      bottomNavigationBar: _buildBatchActions(),
    );
  }

  Widget _buildPremiumPreview() {
    Widget sampleProduct(String name, String nutrition) => Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: const Icon(
          Icons.check_circle_outline,
          color: AppTheme.primaryColor,
        ),
        title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(nutrition),
        trailing: const Icon(Icons.lock_outline),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: Text(context.strings.scanBatchTitle)),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    height: 220,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1D2925),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: double.infinity,
                          height: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.black.withOpacity(0.22),
                                AppTheme.primaryColor.withOpacity(0.2),
                              ],
                            ),
                          ),
                        ),
                        Container(
                          width: 250,
                          height: 118,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white, width: 3),
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        Positioned(
                          top: 14,
                          left: 12,
                          right: 12,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.68),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.lock_outline,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      context.strings.scanPremiumPreview,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    context.strings.scanPreviewTitle,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    context.strings.scanPreviewBody,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  sampleProduct(
                    context.strings.scanSampleYogurt,
                    context.strings.scanSampleYogurtMacro,
                  ),
                  const SizedBox(height: 8),
                  sampleProduct(
                    context.strings.scanSamplePasta,
                    context.strings.scanSamplePastaMacro,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    context.strings.scanAllDestinations,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children:
                        _BatchDestination.values
                            .map(
                              (destination) => Chip(
                                avatar: Icon(destination.icon, size: 17),
                                label: Text(
                                  destination.localizedLabel(context),
                                ),
                              ),
                            )
                            .toList(),
                  ),
                ],
              ),
            ),
          ),
          Material(
            color: Theme.of(context).colorScheme.surface,
            elevation: 10,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed:
                            () => Navigator.of(context).pushNamed('/premium'),
                        icon: const Icon(Icons.workspace_premium_outlined),
                        label: Text(context.strings.scanTrial),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      context.strings.scanPreviewNoCamera,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBatchActions() {
    final canApply = !_busy && _readyCount > 0 && _destinations.isNotEmpty;
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
                context.strings.scanAllDestinations,
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
                          (destination) => FilterChip(
                            avatar: Icon(destination.icon, size: 18),
                            label: Text(destination.localizedLabel(context)),
                            selected: _destinations.contains(destination),
                            onSelected:
                                _submitting
                                    ? null
                                    : (selected) => setState(() {
                                      if (selected) {
                                        _destinations.add(destination);
                                      } else {
                                        _destinations.remove(destination);
                                      }
                                    }),
                          ),
                        )
                        .toList(),
              ),
              if (_destinations.contains(_BatchDestination.tracking)) ...[
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: _mealType,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: context.strings.scanMealTypeAll,
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
                              child: Text(
                                context.strings.diaryMealTypeLabel(type),
                              ),
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
                        ? context.strings.scanAdding
                        : canFinish
                        ? context.strings.scanDoneCount(_completedCount)
                        : context.strings.scanAddAllCount(_readyCount),
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
        context.strings.scanRecognising,
      ),
      _BatchState.ready => (
        Icons.check_circle_outline,
        AppTheme.secondaryColor,
        context.strings.scanReady,
      ),
      _BatchState.saving => (
        Icons.sync,
        AppTheme.secondaryColor,
        context.strings.scanSaving,
      ),
      _BatchState.completed => (
        Icons.check_circle,
        AppTheme.primaryColor,
        item.destinationLabel ?? context.strings.scanDone,
      ),
      _BatchState.missing => (
        Icons.add_a_photo_outlined,
        AppTheme.secondaryColor,
        item.message ?? context.strings.scanTapComplete,
      ),
      _BatchState.error => (
        Icons.error_outline,
        AppTheme.errorColor,
        item.message ?? context.strings.scanTapRetry,
      ),
    };
    final nutrition = _nutritionSummary(item.result);
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
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(status, maxLines: 3, overflow: TextOverflow.ellipsis),
            if (nutrition != null) ...[
              const SizedBox(height: 3),
              Text(
                nutrition,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
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

  String? _nutritionSummary(BarcodeLookupResult? result) {
    if (result == null) return null;
    final values = <String>[
      if (result.kcalPer100 != null)
        '${_formatNutrition(result.kcalPer100!, 0)} kcal',
      if (result.proteinPer100 != null)
        '${context.strings.localeName.startsWith('en') ? 'P' : 'B'} ${_formatMacro(result.proteinPer100!)} g',
      if (result.fatPer100 != null)
        '${context.strings.localeName.startsWith('en') ? 'F' : 'T'} ${_formatMacro(result.fatPer100!)} g',
      if (result.carbsPer100 != null)
        '${context.strings.localeName.startsWith('en') ? 'C' : 'W'} ${_formatMacro(result.carbsPer100!)} g',
    ];
    if (values.isEmpty) return null;
    final basis =
        result.unit == 'ml' || result.unit == 'l' ? '100 ml' : '100 g';
    return '$basis: ${values.join(' · ')}';
  }

  String _formatMacro(double value) =>
      _formatNutrition(value, value == value.roundToDouble() ? 0 : 1);
  String _formatNutrition(double value, int digits) =>
      value.isFinite && value >= 0 ? value.toStringAsFixed(digits) : '—';
}

enum _BatchState { loading, ready, saving, completed, missing, error }

enum _BatchDestination {
  pantry('Spiżarnia', Icons.kitchen_outlined),
  tracking('Dziennik', Icons.local_fire_department_outlined),
  productDatabase('Katalog', Icons.inventory_2_outlined);

  final String label;
  final IconData icon;

  const _BatchDestination(this.label, this.icon);
  String localizedLabel(BuildContext context) =>
      !context.strings.localeName.startsWith('en')
          ? label
          : switch (this) {
            pantry => context.strings.pantry,
            tracking => context.strings.diary,
            productDatabase => context.strings.productsCatalogueTab,
          };
}

String _newTrackingRequestId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex =
      bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

class _BatchScanItem {
  final String code;
  final String trackingRequestId;
  final _BatchState state;
  final BarcodeLookupResult? result;
  final String? message;
  final String? destinationLabel;
  final Set<_BatchDestination> completedDestinations;

  const _BatchScanItem({
    required this.code,
    required this.trackingRequestId,
    required this.state,
    this.result,
    this.message,
    this.destinationLabel,
    this.completedDestinations = const {},
  });

  _BatchScanItem copyWith({
    _BatchState? state,
    BarcodeLookupResult? result,
    String? message,
    String? destinationLabel,
    Set<_BatchDestination>? completedDestinations,
  }) {
    return _BatchScanItem(
      code: code,
      trackingRequestId: trackingRequestId,
      state: state ?? this.state,
      result: result ?? this.result,
      message: message,
      destinationLabel: destinationLabel,
      completedDestinations:
          completedDestinations ?? this.completedDestinations,
    );
  }
}
