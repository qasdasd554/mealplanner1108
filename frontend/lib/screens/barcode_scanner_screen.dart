import 'package:flutter/material.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import '../utils/barcode_utils.dart';

/// Otwiera skaner działający na strumieniu obrazu z aparatu.
///
/// Poprzednia wersja robiła pojedyncze zdjęcie i próbowała odczytać kod z
/// mocno zależnego od ostrości pliku JPEG. Na wielu telefonach poprawny kod
/// nie był wykrywany. ReaderWidget analizuje kolejne klatki, obsługuje obrót,
/// odwrócone kolory i trudniejsze kody, dlatego daje użytkownikowi czas na
/// ustawienie ostrości i odległości.
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
  bool _resultHandled = false;

  void _onScan(Code result) {
    if (_resultHandled || !result.isValid) return;
    final barcode = normalizeScannedBarcode(result.text);
    if (barcode == null) return;

    _resultHandled = true;
    Navigator.of(context).pop(barcode);
  }

  Future<void> _enterManually() async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
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
          ReaderWidget(
            onScan: _onScan,
            codeFormat: Format.any,
            tryHarder: true,
            tryInverted: true,
            tryRotate: true,
            showScannerOverlay: true,
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
                        'Umieść cały kod w ramce i trzymaj telefon nieruchomo. '
                        'Skanowanie nastąpi automatycznie.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white),
                      ),
                      const SizedBox(height: 10),
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
