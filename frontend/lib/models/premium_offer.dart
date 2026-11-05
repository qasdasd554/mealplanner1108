import '../l10n/app_localizations.dart';

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

  static PremiumOfferCopy forContext(
    PremiumOfferContext context, {
    AppLocalizations? strings,
  }) {
    return switch (context) {
      PremiumOfferContext.recipe => PremiumOfferCopy(
        eyebrow:
            (strings?.premiumContextRecipeEyebrow ?? 'PREMIUM DLA PRZEPISÓW'),
        title:
            (strings?.premiumContextRecipeTitle ??
                'Zamień inspirację w gotowy przepis'),
        description:
            (strings?.premiumContextRecipeDescription ??
                'Zapisz przepis z linku, zdjęcia lub opisu bez ręcznego przepisywania. W Premium import nie pobiera punktów.'),
        benefits: [
          (strings?.premiumContextRecipeBenefitImport ??
              'Przepis z linku, zdjęcia lub opisu'),
          (strings?.premiumContextRecipeBenefitSteps ??
              'Automatycznie ułożone składniki i kroki'),
          (strings?.premiumContextRecipeBenefitEdit ??
              'Edycja AI: 1 pkt także w Premium'),
        ],
      ),
      PremiumOfferContext.mealPlan => PremiumOfferCopy(
        eyebrow:
            (strings?.premiumContextMealPlanEyebrow ??
                'PREMIUM DLA PLANOWANIA'),
        title:
            (strings?.premiumContextMealPlanTitle ??
                'Kolejny tydzień gotowy automatycznie'),
        description:
            (strings?.premiumContextMealPlanDescription ??
                'Ustaw automatyczne planowanie na wybrany dzień. Twórz kolejne plany i listy wtedy, gdy ich potrzebujesz.'),
        benefits: [
          (strings?.premiumContextMealPlanBenefitUnlimited ??
              'Plany posiłków bez limitu'),
          (strings?.premiumContextMealPlanBenefitWeekly ??
              'Automatyczny plan na kolejny tydzień'),
          (strings?.premiumContextMealPlanBenefitSwap ??
              'Uwzględnianie preferencji składników'),
        ],
      ),
      PremiumOfferContext.barcodeScanner => PremiumOfferCopy(
        eyebrow:
            (strings?.premiumContextBarcodeEyebrow ?? 'PREMIUM DLA SKANOWANIA'),
        title:
            (strings?.premiumContextBarcodeTitle ??
                'Zeskanuj całe zakupy bez zamykania aparatu'),
        description:
            (strings?.premiumContextBarcodeDescription ??
                'Skanuj produkty jeden po drugim, a potem dodaj całą serię '
                    'do wybranych miejsc jednym ruchem.'),
        benefits: [
          (strings?.premiumContextBarcodeBenefitBatch ??
              'Seryjne skanowanie produktów'),
          (strings?.premiumContextBarcodeBenefitNutrition ??
              'Makro i kalorie przy znalezionych produktach'),
          (strings?.premiumContextBarcodeBenefitDestinations ??
              'Wspólne dodanie do Dziennika, spiżarni lub katalogu'),
        ],
      ),
      PremiumOfferContext.shoppingList => PremiumOfferCopy(
        eyebrow:
            (strings?.premiumContextShoppingEyebrow ?? 'PREMIUM DLA ZAKUPÓW'),
        title:
            (strings?.premiumContextShoppingTitle ??
                'Twórz listy zakupów bez limitu'),
        description:
            (strings?.premiumContextShoppingDescription ??
                'Przygotuj osobną listę na każdy plan lub przepis i połącz '
                    'listy dla tego samego sklepu.'),
        benefits: [
          (strings?.premiumContextShoppingBenefitLists ??
              'Dowolna liczba list zakupów'),
          (strings?.premiumContextShoppingBenefitMerge ??
              'Łączenie list dla jednego sklepu'),
          (strings?.premiumContextShoppingBenefitPantry ??
              'Produkty ze spiżarni liczone za 0 zł'),
        ],
      ),
      PremiumOfferContext.pantry => PremiumOfferCopy(
        eyebrow:
            (strings?.premiumContextPantryEyebrow ?? 'PREMIUM DLA SPIŻARNI'),
        title:
            (strings?.premiumContextPantryTitle ??
                'Wykorzystaj produkty, które już masz'),
        description:
            (strings?.premiumContextPantryDescription ??
                'Znajdź przepisy dopasowane do zawartości spiżarni i kup '
                    'tylko to, czego naprawdę brakuje.'),
        benefits: [
          (strings?.premiumContextPantryBenefitMatch ??
              'Przepisy z dostępnych składników'),
          (strings?.premiumContextPantryBenefitMissing ??
              'Mniej brakujących produktów'),
          (strings?.premiumContextPantryBenefitWaste ??
              'Mniej marnowania jedzenia'),
        ],
      ),
      PremiumOfferContext.journal => PremiumOfferCopy(
        eyebrow:
            (strings?.premiumContextJournalEyebrow ?? 'PREMIUM DLA DZIENNIKA'),
        title:
            (strings?.premiumContextJournalTitle ??
                'Wróć do całej historii swojego Dziennika'),
        description:
            (strings?.premiumContextJournalDescription ??
                'Przeglądaj wpisy starsze niż 30 dni i korzystaj z pełnych tygodniowych wniosków.'),
        benefits: [
          (strings?.premiumContextJournalBenefitHistory ??
              'Pełna historia Dziennika'),
          (strings?.premiumContextJournalBenefitCharts ??
              'Wpisy starsze niż 30 dni'),
          (strings?.premiumContextJournalBenefitWeight ??
              'Pełne tygodniowe wnioski'),
        ],
      ),
    };
  }
}

const recipePremiumOfferDelay = Duration(seconds: 3);
const recipePremiumOfferScrollThreshold = 120.0;

bool shouldTriggerRecipePremiumOffer({
  required bool viewedLongEnough,
  required double scrollOffset,
  required bool alreadyAttempted,
  required bool isCurrentRoute,
  double scrollThreshold = recipePremiumOfferScrollThreshold,
}) {
  return viewedLongEnough &&
      scrollOffset >= scrollThreshold &&
      !alreadyAttempted &&
      isCurrentRoute;
}
