import 'package:flutter/material.dart';

Future<void> showPriceSourceInfo(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder:
        (dialogContext) => AlertDialog(
          title: const Text('Skąd pochodzą ceny?'),
          content: const SingleChildScrollView(
            child: Text(
              'Ceny sklepowe oznaczone jako sprawdzone pochodzą z publicznych '
              'katalogów internetowych Biedronki, Lidla, Dino i Carrefour.\n\n'
              'Po zeskanowaniu kodu nazwa, marka i wartości odżywcze są pobierane '
              'najpierw z własnej bazy Neon, a następnie z Open Food Facts, USDA '
              'FoodData Central. Jeśli kodu nadal nie ma, użytkownik może odczytać '
              'etykietę ze zdjęć i po sprawdzeniu zapisać produkt w Neon. '
              'Aplikacja nie podaje pozornie '
              'dokładnej ceny produktu. Pokazuje szerokie, stałe widełki dla '
              'rodzaju produktu, np. masło 6–10 zł.\n\n'
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
