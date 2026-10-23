import 'package:flutter/material.dart';
import '../l10n/market_locale.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../utils/barcode_utils.dart';
import '../utils/scanner_camera_lifecycle.dart';
import '../widgets/manual_barcode_dialog.dart';

/// Rozpoznawanie odbywa się na urządzeniu, bez wysyłania klatek do serwera.
Future<String?> scanBarcode(BuildContext context) {
  return Navigator.of(context).push<String>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => const BarcodeScannerScreen(),
    ),
  );
}

class BarcodeScannerScreen extends StatefulWidget {
  final MobileScannerController? controller;
  const BarcodeScannerScreen({super.key, this.controller});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  late final MobileScannerController _scanner =
      widget.controller ??
      MobileScannerController(
        autoStart: false,
        facing: CameraFacing.back,
        lensType: CameraLensType.normal,
        detectionSpeed: DetectionSpeed.normal,
        autoZoom:
            true, // Obsługiwane na Androidzie; iOS ma tryb zbliżeń poniżej.
        formats: [
          BarcodeFormat.ean8,
          BarcodeFormat.ean13,
          BarcodeFormat.upcA,
          BarcodeFormat.upcE,
        ],
      );
  final BarcodeScanConfirmation _confirmation = BarcodeScanConfirmation();
  bool _resultHandled = false;
  bool _manualEntryOpen = false;
  bool _closeRange = false;
  double _zoom = 1;
  late final ScannerCameraLifecycle _camera;

  @override
  void initState() {
    super.initState();
    _camera = ScannerCameraLifecycle(
      _scanner,
      onPause: _confirmation.reset,
      onStarted: _resetCameraControls,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && (widget.controller == null || _scanner.autoStart)) {
        _camera.start();
      }
    });
  }

  void _resetCameraControls() {
    if (!mounted || (!_closeRange && _zoom == 1)) return;
    setState(() {
      _closeRange = false;
      _zoom = 1;
    });
  }

  @override
  void dispose() {
    _camera.dispose();
    super.dispose();
  }

  void _onScan(BarcodeCapture capture) {
    if (_resultHandled || !mounted || !_camera.canDetect) return;
    final candidates = <String>{};
    for (final result in capture.barcodes) {
      final barcode = normalizeScannedBarcode(result.rawValue);
      if (barcode != null) candidates.add(barcode);
    }
    if (candidates.length != 1) {
      _confirmation.reset();
      return;
    }
    final barcode = candidates.single;
    if (!_confirmation.confirm(barcode, DateTime.now())) return;
    _resultHandled = true;
    Navigator.of(context).pop(barcode);
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
    if (_manualEntryOpen || _resultHandled) return;
    _manualEntryOpen = true;
    try {
      await _camera.suspend();
      if (!mounted) return;
      final barcode = await showManualBarcodeDialog(context);
      if (!mounted || barcode == null) return;
      _resultHandled = true;
      Navigator.of(context).pop(barcode);
    } finally {
      _manualEntryOpen = false;
      if (mounted && !_resultHandled) await _camera.resume();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.strings.productsScan)),
      body: Stack(
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
                      context.strings.scanCameraError(error.toString()),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
          ),
          IgnorePointer(
            child: Center(
              child: Container(
                width: MediaQuery.sizeOf(context).width * .83,
                height: 150,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 3),
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 24 + MediaQuery.of(context).padding.bottom,
            child: SafeArea(
              top: false,
              child: Card(
                color: Colors.black.withOpacity(0.78),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        context.strings.scanGuide,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        children: [
                          TextButton.icon(
                            onPressed: () => _setZoom(_zoom == 1 ? 2 : 1),
                            icon: const Icon(
                              Icons.zoom_in,
                              color: Colors.white,
                            ),
                            label: Text(
                              _zoom == 1 ? '2×' : '1×',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _toggleCloseRange,
                            icon: const Icon(
                              Icons.center_focus_strong,
                              color: Colors.white,
                            ),
                            label: Text(
                              _closeRange
                                  ? context.strings.scanNormal
                                  : context.strings.scanCloseUp,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () => _scanner.toggleTorch(),
                            icon: const Icon(
                              Icons.flashlight_on,
                              color: Colors.white,
                            ),
                            label: Text(
                              context.strings.scanTorch,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                      TextButton.icon(
                        onPressed: _enterManually,
                        icon: const Icon(Icons.keyboard, color: Colors.white),
                        label: Text(
                          context.strings.scanManual,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
