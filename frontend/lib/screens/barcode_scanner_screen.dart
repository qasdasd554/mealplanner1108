import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../theme/app_theme.dart';

/// Pełnoekranowy skaner kodów kreskowych. Zwraca zeskanowany kod
/// (String) przez `Navigator.pop(context, code)`, albo `null`, jeśli
/// użytkownik anulował.
///
/// Używa aparatu — wymaga uprawnienia NSCameraUsageDescription na iOS
/// (już dodane wcześniej dla zdjęć AI/awatara) i android.permission.CAMERA
/// na Androidzie (też już obecne).
class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    // Ograniczone do formatów kodów kreskowych PRODUKTÓW (EAN-13/EAN-8/
    // UPC-A) — bez QR i innych, żeby skaner nie łapał przypadkiem
    // niezwiązanego kodu QR w kadrze.
    formats: const [BarcodeFormat.ean13, BarcodeFormat.ean8, BarcodeFormat.upcA],
  );

  // Zabezpieczenie przed WIELOKROTNYM odpaleniem onDetect dla tego
  // samego kadru — kamera potrafi zgłosić kilka klatek z tym samym
  // kodem, zanim zdążymy zamknąć ekran po pierwszym trafieniu.
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final code = capture.barcodes.firstOrNull?.rawValue;
    if (code == null || code.isEmpty) return;
    _handled = true;
    Navigator.of(context).pop(code);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Skanuj kod kreskowy'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            tooltip: 'Latarka',
            onPressed: () => _controller.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          // Ramka wizualna, żeby użytkownik wiedział, gdzie celować —
          // sam podgląd kamery na pełnym ekranie tego nie sugeruje.
          IgnorePointer(
            child: Container(
              width: 260,
              height: 160,
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.primaryColor, width: 3),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Wyceluj w kod kreskowy na opakowaniu',
                style: TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
