import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../utils/barcode_utils.dart';

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
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  final MobileScannerController _scanner = MobileScannerController(
    facing: CameraFacing.back,
    lensType: CameraLensType.normal,
    detectionSpeed: DetectionSpeed.noDuplicates,
    autoZoom: true, // Obsługiwane na Androidzie; iOS ma tryb zbliżeń poniżej.
    formats: [
      BarcodeFormat.ean8,
      BarcodeFormat.ean13,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
      BarcodeFormat.code128,
      BarcodeFormat.itf,
    ],
  );
  bool _resultHandled = false;
  bool _closeRange = false;
  double _zoom = 1;

  @override
  void dispose() {
    _scanner.dispose();
    super.dispose();
  }

  void _onScan(BarcodeCapture capture) {
    if (_resultHandled || !mounted) return;
    for (final result in capture.barcodes) {
      final barcode = normalizeScannedBarcode(result.rawValue);
      if (barcode == null) continue;
      _resultHandled = true;
      Navigator.of(context).pop(barcode);
      return;
    }
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
          const SnackBar(content: Text('Ten aparat nie obsługuje przybliżenia.')),
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
      if (best == null || best == CameraLensType.normal || !supported.contains(best)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Przybliż kod przyciskiem 2× lub odsuń telefon.')),
          );
        }
        return;
      }
      await _scanner.switchCamera(
        SelectCamera(facingDirection: CameraFacing.back, lensType: best),
      );
      if (mounted) setState(() => _closeRange = true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nie udało się przełączyć obiektywu.')),
        );
      }
    }
  }

  Future<void> _enterManually() async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Wpisz kod kreskowy'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'EAN/UPC',
            hintText: '8–14 cyfr',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Anuluj'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Wyszukaj'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (!mounted || value == null) return;

    final barcode = normalizeScannedBarcode(value);
    if (barcode == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kod musi zawierać od 8 do 14 cyfr.')),
      );
      return;
    }
    _resultHandled = true;
    Navigator.of(context).pop(barcode);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Skanuj kod kreskowy')),
      body: Stack(
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
                  'Nie można uruchomić aparatu. Sprawdź uprawnienie do kamery albo wpisz kod ręcznie.\n$error',
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
                      const Text(
                        'Skieruj aparat na kod. Dotknij obrazu, aby ustawić ostrość.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        children: [
                          TextButton.icon(
                            onPressed: () => _setZoom(_zoom == 1 ? 2 : 1),
                            icon: const Icon(Icons.zoom_in, color: Colors.white),
                            label: Text(_zoom == 1 ? '2×' : '1×',
                                style: const TextStyle(color: Colors.white)),
                          ),
                          TextButton.icon(
                            onPressed: _toggleCloseRange,
                            icon: const Icon(Icons.center_focus_strong, color: Colors.white),
                            label: Text(_closeRange ? 'Zwykły' : 'Z bliska',
                                style: const TextStyle(color: Colors.white)),
                          ),
                          TextButton.icon(
                            onPressed: () => _scanner.toggleTorch(),
                            icon: const Icon(Icons.flashlight_on, color: Colors.white),
                            label: const Text('Latarka',
                                style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                      TextButton.icon(
                        onPressed: _enterManually,
                        icon: const Icon(Icons.keyboard, color: Colors.white),
                        label: const Text(
                          'Wpisz kod ręcznie',
                          style: TextStyle(color: Colors.white),
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
