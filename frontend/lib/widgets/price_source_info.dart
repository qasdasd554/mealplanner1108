import 'package:flutter/material.dart';

Future<void> showPriceSourceInfo(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder:
        (dialogContext) => AlertDialog(
          title: const Text('Skąd pochodzą ceny?'),
          content: const SingleChildScrollView(
            child: Text(
              'Ceny oznaczone jako sprawdzone pochodzą z publicznych katalogów '
              'internetowych Biedronki, Lidla, Dino i Carrefour. Pozostałe ceny '
              'są orientacyjnym szacunkiem obliczonym na podstawie ceny bazowej '
              'produktu i typowego poziomu cen danej sieci.\n\n'
              'Po zeskanowaniu kodu nazwa, marka i wartości odżywcze są pobierane '
              'z Open Food Facts. Aplikacja sprawdza też polskie wpisy w Open '
              'Prices. Jeśli nie ma tam aktualnej ceny, pokazuje cenę szacowaną.\n\n'
              'Marka sklepowa jest wyświetlana tylko wtedy, gdy została '
              'potwierdzona dla konkretnej sieci. W innym przypadku aplikacja '
              'pokazuje markę referencyjną producenta. Cena w sklepie może się '
              'różnić zależnie od miasta, promocji i daty zakupu.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Rozumiem'),
            ),
          ],
        ),
  );
}
