enum PremiumOfferContext {
  recipe('recipe'),
  mealPlan('meal_plan'),
  barcodeScanner('barcode_scanner'),
  shoppingList('shopping_list'),
  pantry('pantry'),
  journal('journal');

  const PremiumOfferContext(this.apiValue);
  final String apiValue;
}

class PremiumOfferCopy {
  const PremiumOfferCopy({
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.benefits,
  });

  final String eyebrow;
  final String title;
  final String description;
  final List<String> benefits;

  static PremiumOfferCopy forContext(PremiumOfferContext context) {
    return switch (context) {
      PremiumOfferContext.recipe => const PremiumOfferCopy(
        eyebrow: 'PREMIUM DLA PRZEPISÓW',
        title: 'Zamień inspirację w gotowy przepis',
        description:
            'Dodaj link, zdjęcie albo krótki opis. Otrzymasz składniki, '
            'porcje i kolejne kroki bez ręcznego przepisywania.',
        benefits: [
          'Przepis z linku, zdjęcia lub opisu',
          'Automatycznie ułożone składniki i kroki',
          'Edycja przepisu z pomocą AI',
        ],
      ),
      PremiumOfferContext.mealPlan => const PremiumOfferCopy(
        eyebrow: 'PREMIUM DLA PLANOWANIA',
        title: 'Zaplanuj kolejne tygodnie bez limitu',
        description:
            'Twórz tyle planów, ile potrzebujesz, i szybciej dopasuj '
            'posiłki do swojego dnia.',
        benefits: [
          'Plany posiłków bez limitu',
          'Automatyczny plan na kolejny tydzień',
          'Wygodna zamiana i wyszukiwanie dań',
        ],
      ),
      PremiumOfferContext.barcodeScanner => const PremiumOfferCopy(
        eyebrow: 'PREMIUM DLA SKANOWANIA',
        title: 'Zeskanuj całe zakupy bez zamykania aparatu',
        description:
            'Skanuj produkty jeden po drugim, a potem dodaj całą serię '
            'do wybranych miejsc jednym ruchem.',
        benefits: [
          'Seryjne skanowanie produktów',
          'Makro i kalorie przy znalezionych produktach',
          'Wspólne dodanie do Dziennika, spiżarni lub katalogu',
        ],
      ),
      PremiumOfferContext.shoppingList => const PremiumOfferCopy(
        eyebrow: 'PREMIUM DLA ZAKUPÓW',
        title: 'Twórz listy zakupów bez limitu',
        description:
            'Przygotuj osobną listę na każdy plan lub przepis i połącz '
            'listy dla tego samego sklepu.',
        benefits: [
          'Dowolna liczba list zakupów',
          'Łączenie list dla jednego sklepu',
          'Produkty ze spiżarni liczone za 0 zł',
        ],
      ),
      PremiumOfferContext.pantry => const PremiumOfferCopy(
        eyebrow: 'PREMIUM DLA SPIŻARNI',
        title: 'Wykorzystaj produkty, które już masz',
        description:
            'Znajdź przepisy dopasowane do zawartości spiżarni i kup '
            'tylko to, czego naprawdę brakuje.',
        benefits: [
          'Przepisy z dostępnych składników',
          'Mniej brakujących produktów',
          'Mniej marnowania jedzenia',
        ],
      ),
      PremiumOfferContext.journal => const PremiumOfferCopy(
        eyebrow: 'PREMIUM DLA DZIENNIKA',
        title: 'Zobacz, jak zmieniają się Twoje wyniki',
        description:
            'Śledź dłuższy okres i łatwiej zauważaj zmiany w kaloriach, '
            'makro, nawodnieniu oraz wadze.',
        benefits: [
          'Pełna historia Dziennika',
          'Wykresy kalorii, makro i nawodnienia',
          'Postępy wagi w czasie',
        ],
      ),
    };
  }
}

bool shouldTriggerRecipePremiumOffer({
  required bool viewedLongEnough,
  required double scrollOffset,
  required bool alreadyAttempted,
  required bool isCurrentRoute,
  double scrollThreshold = 220,
}) {
  return viewedLongEnough &&
      scrollOffset >= scrollThreshold &&
      !alreadyAttempted &&
      isCurrentRoute;
}
