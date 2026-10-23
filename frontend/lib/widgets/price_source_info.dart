import 'package:flutter/material.dart';
import '../l10n/market_locale.dart';

Future<void> showPriceSourceInfo(BuildContext context) {
  if (context.strings.localeName.startsWith('en')) {
    return showDialog<void>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text(context.strings.priceCompareSourceTitle),
            content: SingleChildScrollView(
              child: Text(context.strings.priceCompareSourceBody),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(context.strings.priceCompareSourceClose),
              ),
            ],
          ),
    );
  }
  return showDialog<void>(
    context: context,
    builder:
        (dialogContext) => AlertDialog(
          title: const Text('Skąd pochodzą ceny?'),
          content: const SingleChildScrollView(
            child: Text(
              'Katalogi sklepów zawierają produkty z bazy aplikacji. '
              'Nie oznacza to, że każdy sklep sprzedaje każdą markę lub '
              'ma produkt aktualnie na półce.\n\n'
              'Cena bez daty sprawdzenia jest orientacyjna: służy do '
              'oszacowania budżetu, a nie jako potwierdzona oferta sklepu. '
              'Przy cenie pokazujemy jednostkę i ilość, których dotyczy. '
              'Potwierdzone ceny pochodzą z katalogów lub zaakceptowanych '
              'promocji; obok pozycji znajduje się data ich sprawdzenia. '
              'Starsza cena może być już nieaktualna.\n\n'
              'Po zeskanowaniu kodu nazwa, marka i wartości odżywcze są pobierane '
              'najpierw z własnej bazy Neon, a następnie z Open Food Facts, USDA '
              'FoodData Central. Jeśli kodu nadal nie ma, użytkownik może odczytać '
              'etykietę ze zdjęć i po sprawdzeniu zapisać produkt w Neon. '
              'Dla produktów zeskanowanych aplikacja może pokazać '
              'orientacyjne widełki dla rodzaju produktu, np. masło 6–10 zł.\n\n'
              'Marka sklepowa jest wyświetlana tylko wtedy, gdy została '
              'potwierdzona dla konkretnej sieci. W innym przypadku aplikacja '
              'pokazuje markę referencyjną producenta. Cena i dostępność '
              'w sklepie mogą się różnić zależnie od placówki, miasta, '
              'promocji i daty zakupu. Porównanie obejmuje pełne koszyki; '
              'braki w katalogu są oznaczane osobno.',
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
