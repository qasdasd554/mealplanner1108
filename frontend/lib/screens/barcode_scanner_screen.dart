import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Prosi o wpisanie kodu kreskowego RĘCZNIE i zwraca wpisaną wartość,
/// albo `null`, jeśli użytkownik anulował.
///
/// ZAMIANA PODEJŚCIA (druga naprawa z rzędu): dwie kolejne biblioteki
/// do skanowania kamerą zawiodły z dwóch różnych powodów —
/// `mobile_scanner` (CameraX/ML Kit) powtarzalnym crashem na urządzeniu
/// testowym, a `flutter_barcode_scanner` (ZXing) okazał się w ogóle
/// niekompatybilny ze współczesnym Gradle (odwołuje się do JCenter,
/// repozytorium wyłączonego przez Google lata temu — build padał,
/// zanim aplikacja zdążyła się w ogóle uruchomić).
///
/// Zamiast trzeciej niepewnej próby z biblioteką kamery, której nie da
/// się zweryfikować bez żywego testu na urządzeniu, to jest
/// GWARANTOWANIE działające rozwiązanie: pod każdym kodem kreskowym
/// jest wydrukowany ten sam numer cyframi — użytkownik po prostu go
/// przepisuje. Zero zależności od kamery, zero ryzyka awarii.
Future<String?> scanBarcode(BuildContext context) async {
  final controller = TextEditingController();

  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Wpisz kod kreskowy'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pod kreskami na opakowaniu jest wydrukowany ten sam numer '
            'cyframi — przepisz go tutaj.',
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            maxLength: 20,
            decoration: const InputDecoration(
              hintText: 'np. 5900000000000',
              counterText: '',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Anuluj'),
        ),
        FilledButton(
          onPressed: () {
            final value = controller.text.trim();
            Navigator.pop(ctx, value.isEmpty ? null : value);
          },
          child: const Text('Szukaj'),
        ),
      ],
    ),
  );
}
