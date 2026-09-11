import 'package:flutter/material.dart';
import 'package:flutter_zxing/flutter_zxing.dart';

/// Skanuje kod kreskowy kamerą i zwraca zeskanowaną wartość, albo
/// `null`, jeśli użytkownik anulował.
///
/// TRZECIA PRÓBA (kamera): dwie poprzednie biblioteki zawiodły z dwóch
/// różnych powodów — `mobile_scanner` (CameraX/ML Kit) powtarzalnym
/// crashem na urządzeniu testowym, `flutter_barcode_scanner` (stare
/// ZXing przez JCenter) w ogóle się nie kompilował ze współczesnym
/// Gradle. `flutter_zxing` kompiluje silnik ZXing bezpośrednio jako
/// kod natywny C++ — architektonicznie inne podejście niż obie
/// poprzednie próby.
///
/// ŚWIADOME ZABEZPIECZENIE: nie mając możliwości przetestowania tej
/// biblioteki na żywym urządzeniu przed wysłaniem, ekran ma ZAWSZE
/// widoczny przycisk "Wpisz ręcznie" — jednym dotknięciem, bez
/// czekania na kolejną turę poprawek, gdyby kamera znów zawiodła na
/// konkretnym telefonie.
Future<String?> scanBarcode(BuildContext context) async {
  return Navigator.of(context).push<String>(
    MaterialPageRoute(builder: (_) => const _BarcodeScannerScreen()),
  );
}

class _BarcodeScannerScreen extends StatelessWidget {
  const _BarcodeScannerScreen();

  Future<void> _enterManually(BuildContext context) async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Wpisz kod kreskowy'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          maxLength: 20,
          decoration: const InputDecoration(
            hintText: 'np. 5900000000000',
            counterText: '',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Anuluj')),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              Navigator.pop(ctx, value.isEmpty ? null : value);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (code != null && context.mounted) {
      Navigator.of(context).pop(code);
    }
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
          // ZAWSZE widoczne, niezależnie od tego, czy podgląd kamery
          // poniżej działa poprawnie — patrz komentarz przy funkcji
          // scanBarcode() wyżej.
          TextButton(
            onPressed: () => _enterManually(context),
            child: const Text('Wpisz ręcznie', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: ReaderWidget(
        onScan: (Code result) {
          final text = result.text;
          if (text != null && text.isNotEmpty) {
            Navigator.of(context).pop(text);
          }
        },
        isMultiScan: false,
      ),
    );
  }
}
