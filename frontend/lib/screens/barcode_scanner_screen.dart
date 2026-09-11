import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:image_picker/image_picker.dart';

/// Robi JEDNO zdjęcie kodu kreskowego, analizuje je i usuwa plik —
/// zamiast trzymać podgląd kamery na żywo i czekać, aż uda się złapać
/// kod w kadrze (co przy niektórych telefonach/oświetleniu potrafiło
/// trwać kilkanaście sekund i sprawiać wrażenie zawieszenia).
///
/// Zwraca zeskanowaną wartość, albo `null`, jeśli użytkownik anulował
/// zdjęcie albo nic nie udało się rozpoznać.
///
/// RYZYKO DO ŚWIADOMOŚCI: robienie zdjęcia przez `image_picker` to
/// mechanizm już sprawdzony w tej aplikacji (zdjęcia do AI, awatar) —
/// tu nie ma niepewności. Natomiast SAMO ROZPOZNANIE kodu ze
/// STATYCZNEGO zdjęcia (`zx.readBarcodeImagePath`) to funkcja
/// `flutter_zxing`, dopracowana przez kolejne błędy kompilacji zamiast
/// dokumentacji (niedostępnej z tego środowiska):
/// 1. Nazwa funkcji — potwierdzona poprawna.
/// 2. Wymaga DRUGIEGO argumentu — `DecodeParams()` okazał się
///    poprawną nazwą klasy (kompilator się o nią nie potknął).
/// 3. Pierwszy argument to `XFile` (obiekt z image_picker), NIE
///    tekstowa ścieżka — to ostatnia poprawiona pomyłka.
Future<String?> scanBarcode(BuildContext context) async {
  final photo = await ImagePicker().pickImage(
    source: ImageSource.camera,
    maxWidth: 1600,
    imageQuality: 85,
  );
  if (photo == null || !context.mounted) return null;

  // Ekran ładowania — widoczny natychmiast po zrobieniu zdjęcia, żeby
  // było jasne, że coś się dzieje, a nie że aplikacja zawiesiła się.
  // (Celowo bez `await` — ma się pokazać RÓWNOLEGLE z analizą poniżej,
  // nie przed nią.)
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const AlertDialog(
      content: Row(
        children: [
          CircularProgressIndicator(),
          SizedBox(width: 20),
          Expanded(child: Text('Skanowanie kodu kreskowego...')),
        ],
      ),
    ),
  );

  String? code;
  try {
    final result = await zx.readBarcodeImagePath(photo, DecodeParams());
    code = result.isValid ? result.text : null;
  } catch (_) {
    code = null;
  } finally {
    // Zdjęcie posłużyło tylko do jednorazowej analizy — kasujemy je,
    // zamiast zaśmiecać telefon użytkownika tymczasowymi plikami.
    try {
      await File(photo.path).delete();
    } catch (_) {
      // Nieudane skasowanie pliku tymczasowego nie jest błędem, na
      // który warto przerywać cokolwiek użytkownikowi.
    }
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
  }

  if (code == null || code.isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          duration: Duration(seconds: 3),
          content: Text('Nie udało się rozpoznać kodu — spróbuj ponownie albo wpisz ręcznie.'),
        ));
    }
    return null;
  }

  return code;
}
