// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Polish (`pl`).
class AppLocalizationsPl extends AppLocalizations {
  AppLocalizationsPl([String locale = 'pl']) : super(locale);

  @override
  String get scanPantryAmountHint => 'Wybierz ilość w gramach lub mililitrach';

  @override
  String get foodEntryTitle => 'Dodaj posiłek';

  @override
  String get foodEntryFromPlan => 'Z planu';

  @override
  String get foodEntryFromRecipes => 'Z przepisów';

  @override
  String get foodEntryProducts => 'Produkty';

  @override
  String get foodEntryServingsQuestion => 'Ile porcji zjadłeś/-aś?';

  @override
  String get foodEntryMealFailed => 'Nie udało się dodać posiłku';

  @override
  String get foodEntryProductFailed => 'Nie udało się dodać produktu';

  @override
  String get foodEntryMealType => 'Rodzaj posiłku';

  @override
  String get foodEntryAddDiary => 'Dodaj do dziennika';

  @override
  String get foodEntryNoPlan =>
      'Nie masz jeszcze aktywnego planu posiłków.\nUtwórz plan w zakładce \"Start\", żeby móc\nlogować z niego posiłki jednym dotknięciem.';

  @override
  String get foodEntryNoPlannedMeals =>
      'Brak zaplanowanych posiłków na wybrany dzień.';

  @override
  String get foodEntryRecipesFailed => 'Nie udało się załadować przepisów';

  @override
  String get foodEntryRecipeSearch => 'Szukaj przepisu...';

  @override
  String get foodEntryNoResults => 'Brak wyników.';

  @override
  String get foodEntryServings => 'Liczba porcji';

  @override
  String get foodEntryAdjustIngredients => 'Dopasuj składniki';

  @override
  String get foodEntryRepeatFailed => 'Nie udało się powtórzyć wpisu';

  @override
  String get foodEntryRepeat => 'Dodaj ponownie';

  @override
  String get foodEntryMissingProduct => 'Nie ma produktu? Dodaj go do bazy';

  @override
  String get foodEntrySaveFailed => 'Nie udało się dodać wpisu';

  @override
  String get foodEntryChooseCatalogue => 'Wybierz z katalogu';

  @override
  String get foodEntryProductName => 'Nazwa produktu / dania';

  @override
  String get foodEntryNameHint => 'Wpisz nazwę lub wybierz podpowiedź';

  @override
  String get foodEntryNameRequired => 'Podaj nazwę';

  @override
  String get foodEntryPortion => 'Porcja (g/ml, opcjonalnie)';

  @override
  String get foodEntryCalories => 'Kalorie (kcal)';

  @override
  String get foodEntryRequired => 'Wymagane';

  @override
  String get foodEntryProtein => 'Białko (g)';

  @override
  String get foodEntryCarbs => 'Węgle (g)';

  @override
  String get foodEntryFat => 'Tłuszcz (g)';

  @override
  String get foodEntrySave => 'Zapisz do dziennika';

  @override
  String get foodEntryInvalidNumber => 'Podaj prawidłową, nieujemną liczbę.';

  @override
  String get foodEntryInvalidPortion =>
      'Podaj ilość większą od 0 (maks. 1000000).';

  @override
  String get scanZoomUnavailable => 'Ten aparat nie obsługuje przybliżenia.';

  @override
  String get scanZoomHint => 'Przybliż kod przyciskiem 2× lub odsuń telefon.';

  @override
  String get scanLensFailed => 'Nie udało się przełączyć obiektywu.';

  @override
  String get scanEnterCode => 'Wpisz kod kreskowy';

  @override
  String get scanCodeHint => '8–14 cyfr';

  @override
  String get scanBatchCodeHint => '8, 12, 13 lub 14 cyfr';

  @override
  String get scanSearch => 'Wyszukaj';

  @override
  String get scanCodeInvalidLength => 'Kod musi zawierać od 8 do 14 cyfr.';

  @override
  String get scanCodeInvalid => 'Kod jest nieprawidłowy. Sprawdź cyfry.';

  @override
  String get scanDuplicate => 'Ten produkt jest już w tej serii.';

  @override
  String get scanGuide =>
      'Skieruj aparat na kod. Dotknij obrazu, aby ustawić ostrość.';

  @override
  String get scanNormal => 'Zwykły';

  @override
  String get scanCloseUp => 'Z bliska';

  @override
  String get scanTorch => 'Latarka';

  @override
  String get scanManual => 'Wpisz kod ręcznie';

  @override
  String get scanNormalLens => 'Zwykły obiektyw';

  @override
  String get scanCloseUpMode => 'Tryb z bliska';

  @override
  String get scanZoomTwo => 'Przybliż 2×';

  @override
  String get scanZoomOne => 'Przybliż 1×';

  @override
  String get scanMissing =>
      'Nie znaleziono. Dotknij, aby dodać produkt ze zdjęć.';

  @override
  String get scanMissingNutrition =>
      'Znaleziono produkt, ale brakuje kcal lub makro. Dotknij, aby uzupełnić dane ze zdjęć etykiety.';

  @override
  String get scanMissingPackage =>
      'Znaleziono produkt, ale brakuje masy całego opakowania. Dotknij, aby odczytać gramaturę ze zdjęcia etykiety.';

  @override
  String get scanCorrectNutrition =>
      'Brakuje kcal lub makro. Dotknij, aby poprawić dane.';

  @override
  String get scanCorrectPackage =>
      'Nie odczytano masy całego opakowania. Dotknij, aby poprawić zdjęcia lub wpisz gramaturę ręcznie.';

  @override
  String get scanAddedPantry => 'Dodano do spiżarni';

  @override
  String get scanAddedDiary => 'Dodano do Dziennika';

  @override
  String get scanNutritionUnconfirmed =>
      'Serwer nie potwierdził wartości odżywczych produktu.';

  @override
  String get scanAlreadyCatalogue => 'Już jest w katalogu';

  @override
  String get scanAddedCatalogue => 'Dodano do katalogu';

  @override
  String get scanAlreadySubmitted => 'Produkt jest już zgłoszony';

  @override
  String get scanWaitLookup => 'Poczekaj, aż rozpoznam wszystkie kody.';

  @override
  String get scanFirstProduct =>
      'Najpierw zeskanuj przynajmniej jeden produkt.';

  @override
  String get scanCompleteMissing =>
      'Uzupełnij lub ponów nierozpoznane produkty.';

  @override
  String get scanChooseDestinations =>
      'Wybierz co najmniej jedno miejsce dla całej serii.';

  @override
  String get scanBatchTitle => 'Skanowanie seryjne';

  @override
  String get scanFinish => 'Zakończ';

  @override
  String get scanBatchGuide =>
      'Skanuj kolejne produkty. Miejsca wybierzesz raz dla całej serii.';

  @override
  String get scanBatchEmpty => 'Zeskanowane produkty pojawią się tutaj.';

  @override
  String get scanPremiumPreview => 'Podgląd funkcji Premium';

  @override
  String get scanPreviewTitle => 'Całe zakupy jednym skanowaniem';

  @override
  String get scanPreviewBody =>
      'Aparat pozostaje otwarty, a rozpoznane produkty trafiają na jedną listę. Na końcu wybierasz miejsca i zatwierdzasz wszystko raz.';

  @override
  String get scanSampleYogurt => 'Jogurt naturalny';

  @override
  String get scanSamplePasta => 'Makaron pełnoziarnisty';

  @override
  String get scanSampleYogurtMacro => '100 g: 62 kcal · B 4 g · T 3 g · W 5 g';

  @override
  String get scanSamplePastaMacro =>
      '100 g: 348 kcal · B 13 g · T 3 g · W 65 g';

  @override
  String get scanAllDestinations => 'Dodaj wszystkie do';

  @override
  String get scanTrial => 'Wypróbuj Premium przez 7 dni';

  @override
  String get scanPreviewNoCamera =>
      'To jest podgląd — aparat nie został uruchomiony.';

  @override
  String get scanMealTypeAll => 'Rodzaj posiłku dla wszystkich';

  @override
  String get scanAdding => 'Dodaję produkty…';

  @override
  String get scanRecognising => 'Rozpoznawanie…';

  @override
  String get scanReady => 'Gotowy do wspólnego dodania';

  @override
  String get scanSaving => 'Dodawanie…';

  @override
  String get scanDone => 'Gotowe';

  @override
  String get scanTapComplete => 'Dotknij, aby uzupełnić produkt';

  @override
  String get scanTapRetry => 'Błąd. Dotknij, aby ponowić.';

  @override
  String get scanWhere => 'Gdzie dodać produkt?';

  @override
  String get scanMultiHint => 'Możesz zaznaczyć kilka miejsc jednocześnie.';

  @override
  String get scanNutritionMissingHint =>
      'Nie odnaleziono kompletnych makroskładników. Po wybraniu miejsca uzupełnisz dane ze zdjęć opakowania.';

  @override
  String get scanDiaryDestination => 'Dodaj do Dziennika';

  @override
  String get scanDiaryDestinationHint => 'Wybierz ilość i rodzaj posiłku';

  @override
  String get scanCatalogueDestination => 'Dodaj do bazy produktów';

  @override
  String get scanCatalogueDestinationHint =>
      'Sprawdź nazwę, markę i makroskładniki';

  @override
  String get scanPantryDestination => 'Dodaj do spiżarni';

  @override
  String get scanPantryDestinationHint => 'Zapisz jako 1 całe opakowanie';

  @override
  String get scanNext => 'Dalej';

  @override
  String get catalogueNutritionMissing =>
      'Nie odnaleziono kompletnych makroskładników w internecie. Uzupełnij dane ze zdjęć opakowania.';

  @override
  String get catalogueIncomplete =>
      'Ten produkt nie ma jeszcze wartości odżywczych. Dodaj go do bazy z danymi z etykiety, aby użyć go w Dzienniku.';

  @override
  String get catalogueProductSearch => 'Szukaj produktu...';

  @override
  String get catalogueNoMatch => 'Brak produktów pasujących do wyszukiwania.';

  @override
  String get autocompleteCatalogue => 'katalog aplikacji';

  @override
  String get autocompleteScanned => 'wcześniej zeskanowany';

  @override
  String get autocompleteHint =>
      'Możesz wybrać podpowiedź albo pozostawić własną nazwę.';

  @override
  String foodEntryPlanDate(String date) {
    return 'Twój aktywny plan nie obejmuje wybranej daty ($date).';
  }

  @override
  String foodEntryKcalServing(String kcal) {
    return '$kcal kcal / porcja';
  }

  @override
  String scanCameraError(String error) {
    return 'Nie można uruchomić aparatu. Sprawdź uprawnienie do kamery albo wpisz kod ręcznie.\n$error';
  }

  @override
  String scanBatchCameraError(String error) {
    return 'Nie można uruchomić aparatu. Sprawdź uprawnienie do kamery.\n$error';
  }

  @override
  String scanRetryError(String error) {
    return '$error Dotknij, aby spróbować ponownie.';
  }

  @override
  String scanRetrySavedError(String error) {
    return '$error Zapisane miejsca nie zostaną dodane ponownie. Dotknij, aby ponowić.';
  }

  @override
  String scanAddedPoints(int points) {
    return 'Dodano do katalogu (+$points pkt)';
  }

  @override
  String scanAddedCount(int count) {
    return 'Dodano $count produktów.';
  }

  @override
  String scanAddedPartial(int saved, int total) {
    return 'Dodano $saved z $total. Dotknij błędnych pozycji i spróbuj ponownie.';
  }

  @override
  String scanQueueCount(int count) {
    return 'Rozpoznaję produkty · oczekuje $count';
  }

  @override
  String scanDoneCount(int count) {
    return 'Gotowe · $count produktów';
  }

  @override
  String scanAddAllCount(int count) {
    return 'Dodaj wszystkie ($count)';
  }

  @override
  String scanCodeLabel(String code) {
    return 'Kod: $code';
  }

  @override
  String scanDestinationsCount(int count) {
    return 'Dodaj do $count miejsc';
  }

  @override
  String scanPantryAddedName(String name) {
    return '$name dodano do spiżarni.';
  }

  @override
  String get diaryCustomWater => 'Inna ilość';

  @override
  String get rewardProductSemantics =>
      'Nagroda: jeden punkt Premium za dodanie nowego, unikalnego produktu do bazy.';

  @override
  String get rewardProductTitle => 'Zyskaj 1 punkt Premium';

  @override
  String get rewardProductBody =>
      'Zeskanuj kod lub dodaj ręcznie nowy, unikalny produkt do bazy.';

  @override
  String get rewardProductPoint => '+1 pkt';

  @override
  String get productsMarketUnavailable =>
      'Brak potwierdzonego cennika dla tego rynku.';

  @override
  String get home => 'Start';

  @override
  String get recipes => 'Przepisy';

  @override
  String get shopping => 'Zakupy';

  @override
  String get diary => 'Dziennik';

  @override
  String get premium => 'Premium';

  @override
  String get profile => 'Profil';

  @override
  String get add => 'Dodaj';

  @override
  String get newPlan => 'Nowy plan';

  @override
  String get planMeals => 'Zaplanuj posiłki';

  @override
  String get productDatabase => 'Baza produktów';

  @override
  String get checkPrices => 'Sprawdź ceny';

  @override
  String get promotions => 'Promocje';

  @override
  String get currentOffers => 'Aktualne okazje';

  @override
  String get pantry => 'Spiżarnia';

  @override
  String get whatYouHaveAtHome => 'Co masz w domu';

  @override
  String get planArchive => 'Archiwum planów';

  @override
  String get scanBarcode => 'Skanuj kod kreskowy';

  @override
  String get batchScan => 'Skanuj wiele produktów';

  @override
  String get addRecipeWithAi => 'Dodaj przepis z AI';

  @override
  String get addMeal => 'Dodaj posiłek';

  @override
  String get addToPantry => 'Dodaj do spiżarni';

  @override
  String get barcodeDestinations =>
      'Dodaj do Dziennika, bazy produktów albo spiżarni';

  @override
  String get whatToAdd => 'Co chcesz dodać?';

  @override
  String get scanProduct => 'Zeskanuj produkt';

  @override
  String get batchDestinationHint =>
      'Jeden cel i jedno zatwierdzenie dla całej serii';

  @override
  String get aiRecipeSources => 'Ze zdjęcia, tekstu albo linku';

  @override
  String get recordCaloriesAndMacros => 'Zapisz kalorie i makroskładniki';

  @override
  String get premiumTwoPoints => 'PREMIUM · 2 PKT';

  @override
  String recipeLoadError(String error) {
    return 'Błąd podczas pobierania przepisów: $error';
  }

  @override
  String recipeLoadMoreError(String error) {
    return 'Nie udało się wczytać kolejnych przepisów: $error';
  }

  @override
  String get recipeImportInProgress => 'Trwa dodawanie przepisu przez AI';

  @override
  String get recipeAuthorRanking => 'Ranking autorów przepisów';

  @override
  String get recipeSearchHint => 'Nazwa, autor lub składnik...';

  @override
  String get clearSearch => 'Wyczyść wyszukiwanie';

  @override
  String get recipeFavourites => 'Ulubione';

  @override
  String get recipeMine => 'Moje';

  @override
  String get recipeNew => 'Nowość';

  @override
  String get recipeCommunity => 'Społeczność';

  @override
  String get moreFilters => 'Więcej';

  @override
  String get loadingMore => 'Wczytywanie…';

  @override
  String get showMoreRecipes => 'Pokaż więcej przepisów';

  @override
  String get addRecipe => 'Dodaj przepis';

  @override
  String get withAi => 'Z pomocą AI';

  @override
  String get takeRecipePhoto => 'Zrób zdjęcie';

  @override
  String get recipePhotoHint => 'Przepisu albo gotowego dania';

  @override
  String get pasteText => 'Wklej tekst';

  @override
  String get pasteLink => 'Wklej link';

  @override
  String get addManually => 'Dodaj ręcznie';

  @override
  String get filters => 'Filtry';

  @override
  String get clearFilters => 'Wyczyść';

  @override
  String get sortRecipes => 'Sortowanie';

  @override
  String get sortAlphabetically => 'Alfabetycznie';

  @override
  String get sortCaloriesLow => 'Kalorie: mniej';

  @override
  String get sortCaloriesHigh => 'Kalorie: więcej';

  @override
  String get sortQuickest => 'Czas: najszybsze';

  @override
  String get recipeDiet => 'Dieta';

  @override
  String get allRecipes => 'Wszystkie';

  @override
  String get recipeMealType => 'Typ posiłku';

  @override
  String get filterBreakfast => 'Śniadania';

  @override
  String get filterLunch => 'Obiady';

  @override
  String get filterDinner => 'Kolacje';

  @override
  String get filterSnacks => 'Przekąski';

  @override
  String get filterDesserts => 'Desery';

  @override
  String get recipeDifficulty => 'Trudność';

  @override
  String get anyDifficulty => 'Każda';

  @override
  String get filterEasy => 'Łatwe';

  @override
  String get filterMedium => 'Średnie';

  @override
  String get filterHard => 'Trudne';

  @override
  String get showResults => 'Pokaż wyniki';

  @override
  String recipeCardSummary(int minutes, int calories) {
    return '$minutes min • $calories kcal/porcję';
  }

  @override
  String get noRecipes => 'Brak przepisów';

  @override
  String get noRecipesHint => 'Sprawdź nazwę przepisu, autora lub składnika.';

  @override
  String get mealBreakfast => 'śniadanie';

  @override
  String get mealLunch => 'obiad';

  @override
  String get mealDinner => 'kolacja';

  @override
  String get mealSnack => 'przekąska';

  @override
  String get mealDessert => 'deser';

  @override
  String get difficultyEasy => 'łatwy';

  @override
  String get difficultyMedium => 'średni';

  @override
  String get difficultyHard => 'trudny';

  @override
  String get dietNoRestrictions => 'Bez ograniczeń';

  @override
  String get dietVegetarian => 'Wegetariańska';

  @override
  String get dietVegan => 'Wegańska';

  @override
  String get dietGlutenFree => 'Bezglutenowa';

  @override
  String get dietKeto => 'Keto';

  @override
  String get dietHighProtein => 'Wysokobiałkowa';

  @override
  String get dietNoRestrictionsDescription =>
      'Jesz wszystko, na co masz ochotę';

  @override
  String get dietVegetarianDescription => 'Posiłki bez mięsa i ryb';

  @override
  String get dietVeganDescription => 'Posiłki w 100% roślinne';

  @override
  String get dietGlutenFreeDescription => 'Dania bez zawartości glutenu';

  @override
  String get dietKetoDescription => 'Niska zawartość węglowodanów';

  @override
  String get dietHighProteinDescription => 'Dla aktywnych, budujących masę';

  @override
  String get planStatusActive => 'active';

  @override
  String get planStatusDraft => 'draft';

  @override
  String get planStatusCompleted => 'completed';

  @override
  String get planStatusArchived => 'archived';

  @override
  String get authCaptchaRequired =>
      'Najpierw potwierdź, że nie jesteś robotem.';

  @override
  String get authLoginFailed => 'Logowanie nie powiodło się';

  @override
  String get authWelcomeBack => 'Witaj ponownie!';

  @override
  String get authLoginPrompt => 'Zaloguj się do swojego konta';

  @override
  String get authEmail => 'E-mail';

  @override
  String get authEnterEmail => 'Wprowadź adres e-mail';

  @override
  String get authEnterValidEmail => 'Wprowadź poprawny adres e-mail';

  @override
  String get authPassword => 'Hasło';

  @override
  String get authEnterPassword => 'Wprowadź hasło';

  @override
  String get authPasswordMinSix => 'Hasło musi mieć co najmniej 6 znaków';

  @override
  String get authSignIn => 'Zaloguj się';

  @override
  String get authForgotPasswordQuestion => 'Zapomniałeś hasła?';

  @override
  String get authOr => 'lub';

  @override
  String get authContinueApple => 'Kontynuuj z Apple';

  @override
  String get authContinueGoogle => 'Kontynuuj z Google';

  @override
  String get authNoAccount => 'Nie masz konta?';

  @override
  String get authRegister => 'Zarejestruj się';

  @override
  String authDocumentOpenFailed(String url) {
    return 'Nie udało się otworzyć: $url';
  }

  @override
  String get authAcceptTermsRequired =>
      'Zaakceptuj regulamin, aby założyć konto.';

  @override
  String get authRegistrationFailed => 'Rejestracja nie powiodła się';

  @override
  String get authCreateAccount => 'Utwórz konto';

  @override
  String get authJoinPlanner => 'Dołącz do Meal Planner i planuj sprytnie';

  @override
  String get authDisplayName => 'Imię / Nazwa użytkownika';

  @override
  String get authEnterName => 'Wprowadź swoje imię';

  @override
  String get authRepeatPassword => 'Powtórz hasło';

  @override
  String get authConfirmPassword => 'Potwierdź hasło';

  @override
  String get authPasswordsMismatch => 'Hasła nie są identyczne';

  @override
  String get authAcceptPrefix => 'Akceptuję ';

  @override
  String get authTerms => 'regulamin';

  @override
  String get authAnd => ' oraz ';

  @override
  String get authPrivacyPolicy => 'politykę prywatności';

  @override
  String get authAlreadyAccount => 'Masz już konto?';

  @override
  String get authValidEmailRequired => 'Podaj prawidłowy adres e-mail.';

  @override
  String get authCodeSixDigits => 'Kod musi mieć dokładnie 6 cyfr.';

  @override
  String get authNewPasswordMinEight =>
      'Nowe hasło musi mieć co najmniej 8 znaków.';

  @override
  String get authPasswordChanged =>
      'Hasło zostało zmienione. Zaloguj się nowym hasłem.';

  @override
  String get authForgotPasswordTitle => 'Zapomniałem hasła';

  @override
  String get authResetDescription =>
      'Podaj adres e-mail, na który wyślemy kod do zresetowania hasła.';

  @override
  String get authEmailAddress => 'Adres e-mail';

  @override
  String get authSendCode => 'Wyślij kod';

  @override
  String authResetCodeSentTo(String email) {
    return 'Jeśli konto z adresem $email istnieje, wysłaliśmy na nie 6-cyfrowy kod. Wpisz go poniżej razem z nowym hasłem.';
  }

  @override
  String get authCode => 'Kod';

  @override
  String get authNewPassword => 'Nowe hasło';

  @override
  String get authChangePassword => 'Zmień hasło';

  @override
  String get authUseDifferentEmail => 'Podaj inny e-mail';

  @override
  String get authNewCodeSent => 'Nowy kod został wysłany.';

  @override
  String get authCodeSendFailed => 'Nie udało się wysłać kodu.';

  @override
  String get authVerifyEmailTitle => 'Potwierdź swój e-mail';

  @override
  String authVerificationSentTo(String email) {
    return 'Wysłaliśmy 6-cyfrowy kod na adres\n$email';
  }

  @override
  String get authVerify => 'Potwierdź';

  @override
  String get authResendCode => 'Wyślij kod ponownie';

  @override
  String get onboardingAllergenGluten => 'Gluten';

  @override
  String get onboardingAllergenLactose => 'Laktoza';

  @override
  String get onboardingAllergenNuts => 'Orzechy';

  @override
  String get onboardingAllergenEggs => 'Jaja';

  @override
  String get onboardingAllergenSoy => 'Soja';

  @override
  String get onboardingAllergenCelery => 'Seler';

  @override
  String get onboardingAllergenFish => 'Ryby';

  @override
  String get onboardingAllergenShellfish => 'Skorupiaki';

  @override
  String get onboardingSelectStoreRequired => 'Wybierz swój preferowany sklep!';

  @override
  String get onboardingPreferencesSaveFailed =>
      'Nie udało się zapisać preferencji';

  @override
  String get onboardingBack => 'Wstecz';

  @override
  String get onboardingDone => 'Gotowe!';

  @override
  String get onboardingNext => 'Dalej';

  @override
  String get onboardingStoreTitle => 'Gdzie robisz zakupy?';

  @override
  String get onboardingStoreDescription =>
      'Wybierz sklep, w którym najczęściej robisz zakupy. Dostosujemy plan posiłków i produkty pod ten konkretny asortyment.';

  @override
  String onboardingStoresLoadFailed(String error) {
    return 'Błąd wczytywania sklepów:\n$error';
  }

  @override
  String get onboardingAllergensTitle => 'Czy masz jakieś alergie?';

  @override
  String get onboardingAllergensDescription =>
      'Wybierz składniki, których nie możesz jeść. Przepisy zawierające te alergeny nie będą sugerowane.';

  @override
  String get onboardingDietTitle => 'Wybierz swoją dietę';

  @override
  String get onboardingDietDescription =>
      'Dostosujemy rekomendacje przepisów do Twojego stylu żywieniowego.';

  @override
  String get onboardingHouseholdTitle => 'Dla ilu osób gotujesz?';

  @override
  String get onboardingHouseholdDescription =>
      'Automatycznie dopasujemy ilości składników w przepisach oraz porcje w liście zakupowej.';

  @override
  String get onboardingCookingForMyself => 'Gotuję tylko dla siebie';

  @override
  String onboardingHouseholdCount(int count) {
    return 'Liczba osób w gospodarstwie: $count';
  }

  @override
  String get onboardingProfileTitle => 'Twój profil i cel';

  @override
  String get onboardingProfileDescription =>
      'Chcesz teraz obliczyć zapotrzebowanie kaloryczne i uzupełnić wagę, wzrost oraz cel? Możesz też zrobić to później w profilu.';

  @override
  String get onboardingOpenCalorieCalculator =>
      'Otwórz kalkulator zapotrzebowania';

  @override
  String get onboardingProfileOptional =>
      'Ten krok jest opcjonalny. Wybierz „Dalej”, aby go pominąć.';

  @override
  String get onboardingPantryTitle => 'Co masz w spiżarni?';

  @override
  String get onboardingPantryDescription =>
      'Dodaj produkty, które masz już w domu. Dzięki temu łatwiej znajdziesz przepisy bez dodatkowych zakupów.';

  @override
  String get onboardingAddPantryProducts => 'Dodaj produkty do spiżarni';

  @override
  String get onboardingPantryOptional => 'Ten krok możesz pominąć.';

  @override
  String get onboardingPremiumOrPoints => 'PREMIUM • LUB PUNKTY';

  @override
  String get onboardingAiTitle => 'Masz przepis? Dodaj go w chwilę';

  @override
  String get onboardingAiDescription =>
      'W zakładce Przepisy wybierz „Dodaj przepis”. AI przygotuje składniki i kroki na podstawie:';

  @override
  String get onboardingAiImport => 'Import przepisu z AI';

  @override
  String get onboardingAiPhoto => 'Zdjęcia';

  @override
  String get onboardingAiPhotoDescription =>
      'Sfotografuj kartkę z przepisem albo gotowe danie.';

  @override
  String get onboardingAiText => 'Tekstu';

  @override
  String get onboardingAiTextDescription =>
      'Wklej opis lub wpisz samą nazwę potrawy.';

  @override
  String get onboardingAiLink => 'Linku';

  @override
  String get onboardingAiLinkDescription =>
      'Wklej adres strony lub udostępnij go z innej aplikacji.';

  @override
  String get onboardingAiShareExample =>
      'Przykład: w TikToku wybierz „Udostępnij” → Meal Planner Polska. Gdy przepis będzie gotowy, możesz poprosić AI o zmianę, np. wersję bez laktozy.';

  @override
  String get onboardingAiPointCosts =>
      'Dodanie przepisu kosztuje 2 punkty bez subskrypcji Premium. Późniejsza zmiana przez AI kosztuje 1 punkt.';

  @override
  String get welcomeAllSet => 'Wszystko gotowe!';

  @override
  String welcomePointsIntro(int points) {
    return 'Na start dorzucamy Ci $points punkty premium — to nasze podziękowanie za założenie konta i skonfigurowanie aplikacji.';
  }

  @override
  String get welcomeAiPointDescription =>
      'Za 2 punkty dodasz przepis z dowolnego linku lub zdjęcia — zrobi to za Ciebie AI.';

  @override
  String get welcomeTryNow => 'Wypróbuj teraz';

  @override
  String get welcomeScanFirstProduct => 'Zeskanuj pierwszy produkt';

  @override
  String get welcomeAddRecipeLink => 'Dodaj przepis z linku';

  @override
  String get welcomeStart => 'Zaczynamy';

  @override
  String get priceCompareTitle => 'Porównanie cen';

  @override
  String get priceCompareSourcesTooltip => 'Źródła cen i marek';

  @override
  String get priceCompareRetry => 'Spróbuj ponownie';

  @override
  String get priceCompareEmpty => 'Brak danych do porównania.';

  @override
  String get priceCompareIntro =>
      'Porównujemy koszt całej listy. „~” oznacza cenę orientacyjną. Dostępność i aktualną cenę potwierdź w wybranym sklepie.';

  @override
  String priceCompareSwitchSuccess(String storeName) {
    return 'Plan przełączony na $storeName';
  }

  @override
  String get priceCompareSwitchError => 'Nie udało się przełączyć sklepu';

  @override
  String priceCompareLoadError(String error) {
    return 'Nie udało się załadować porównania: $error';
  }

  @override
  String get priceCompareCurrencyError =>
      'Nie można porównać cen w różnych walutach. Odśwież dane i spróbuj ponownie.';

  @override
  String get priceCompareCheapestEstimate => 'Najniższy szacunek';

  @override
  String get priceCompareCheapest => 'Najtaniej';

  @override
  String priceCompareIncomplete(int count) {
    return 'Niepełny koszyk • brak cen dla $count produktów';
  }

  @override
  String priceCompareProductCount(int count) {
    return '$count produktów';
  }

  @override
  String get priceCompareEstimatedPrices => 'ceny orientacyjne';

  @override
  String priceCompareSavings(String amount) {
    return 'różnica do $amount';
  }

  @override
  String get priceCompareExpandHint => 'dotknij, aby zobaczyć listę';

  @override
  String priceCompareMissing(String names) {
    return 'Brak danych cenowych: $names. Pokazana suma dotyczy tylko pozycji z ceną.';
  }

  @override
  String get priceCompareEstimate => 'cena orientacyjna';

  @override
  String get shoppingSubstituteFailed => 'Nie udało się zamienić produktu.';

  @override
  String shoppingSubstitutePack(String quantity, String unit) {
    return '$quantity $unit w opakowaniu';
  }

  @override
  String get priceCompareUnpricedTotal => 'Brak pełnej wyceny';

  @override
  String priceCompareMissingUnpriced(String names) {
    return 'Brak cen dla: $names. Nie można jeszcze wycenić całego koszyka.';
  }

  @override
  String priceComparePackages(int count, String quantity, String unit) {
    return 'Do kupienia: $count × $quantity $unit';
  }

  @override
  String priceCompareVerified(String date) {
    return 'cena sprawdzona $date';
  }

  @override
  String get priceCompareSwitchStore => 'Przełącz plan na ten sklep';

  @override
  String get priceCompareSourceTitle => 'Skąd pochodzą ceny?';

  @override
  String get priceCompareSourceBody =>
      'Porównanie obejmuje ceny produktów dostępnych w katalogu dla Twojego rynku. Cena bez daty sprawdzenia jest orientacyjna, a nie potwierdzoną ofertą sklepu. Pokazujemy ilość i jednostkę, których dotyczy cena. Znacznik „~” oznacza szacunek. Dostępność i aktualną cenę potwierdź w sklepie. Nie porównujemy ani nie przeliczamy cen pomiędzy PLN i GBP.';

  @override
  String get priceCompareSourceClose => 'Rozumiem';

  @override
  String get priceCompareUnitPack => 'opak.';

  @override
  String get priceCompareUnitServing => 'porcja';

  @override
  String get priceCompareUnitPiece => 'szt.';

  @override
  String get priceCompareUnitTeaspoon => 'łyżeczka';

  @override
  String get priceCompareUnitCup => 'szklanka';

  @override
  String homeBatchCompleted(int count) {
    return 'Obsłużono: $count produktów.';
  }

  @override
  String get homeShopFallback => 'Sklep';

  @override
  String homeGreeting(String name) {
    return 'Cześć, $name!';
  }

  @override
  String get homeUserFallback => 'użytkowniku';

  @override
  String get homeCookingToday => 'Co dziś gotujemy?';

  @override
  String get homeQuickActions => 'Szybkie akcje';

  @override
  String get homePlanLoading => 'Wczytywanie planu posiłków…';

  @override
  String get homePlanLoadError => 'Nie udało się wczytać planu posiłków.';

  @override
  String get homeNextPlan => 'Twój najbliższy plan';

  @override
  String get homeActivePlan => 'Twój aktywny plan';

  @override
  String get homeDetails => 'Szczegóły';

  @override
  String homePlanChip(int day, int month, int days) {
    return 'Plan $day.$month · $days dni';
  }

  @override
  String get homeNutritionLoading => 'Wczytywanie kalorii i makroskładników…';

  @override
  String get homeNutritionError =>
      'Nie udało się wczytać kalorii i makroskładników.';

  @override
  String get homeEatenToday => 'Dziś zjedzono';

  @override
  String get homeProtein => 'Białko';

  @override
  String get homeFat => 'Tłuszcz';

  @override
  String get homeCarbsShort => 'Węgl.';

  @override
  String get homeRetry => 'Spróbuj ponownie';

  @override
  String get homeTipOfTheDay => 'PORADA DNIA';

  @override
  String get homeHydration => 'Nawodnienie';

  @override
  String get homeDataLoading => 'Wczytywanie danych…';

  @override
  String get homeDataError => 'Nie udało się wczytać danych';

  @override
  String homeWaterProgress(int amount, int goal, int percent) {
    return '$amount z $goal ml · $percent% celu';
  }

  @override
  String get homeWeeklyContest => 'Konkurs tygodnia';

  @override
  String get homeWeeklyContestHint =>
      'Dodaj najwięcej przepisów w tym tygodniu i zgarnij punkty premium — 3 za 1. miejsce, 2 za 2., 1 za 3.';

  @override
  String homePlanStarts(String date) {
    return 'Plan od $date';
  }

  @override
  String homePlanDay(int day, int days) {
    return 'Dzień $day z $days';
  }

  @override
  String get homeViewPlan => 'Zobacz plan';

  @override
  String get homeNoPlan => 'Brak aktywnego planu posiłków';

  @override
  String get homeNoPlanHint =>
      'Wygeneruj zbilansowany plan posiłków, zminimalizuj koszty i wygeneruj inteligentną listę zakupów.';

  @override
  String get homeCreatePlan => 'Stwórz nowy plan posiłków';

  @override
  String get homeAiPointsTitle => 'Masz punkty na import przepisu AI';

  @override
  String get homeAiPointsHint =>
      'Dodaj przepis ze zdjęcia, tekstu albo linku — bez subskrypcji.';

  @override
  String get homeTryAction => 'Wypróbuj';

  @override
  String get homeBatchTitle => 'Skanujesz kilka produktów?';

  @override
  String get homeBatchHint =>
      'W Premium zeskanujesz całą serię bez zamykania aparatu.';

  @override
  String get homeViewPremium => 'Zobacz Premium';

  @override
  String get homeAutoWeekTitle => 'Następny tydzień może zrobić się sam';

  @override
  String get homeAutoWeekHint =>
      'Premium przygotuje co tydzień plan i opcjonalną listę zakupów.';

  @override
  String get homeCheckAction => 'Sprawdź';

  @override
  String get homeHideHint => 'Ukryj';

  @override
  String get planSelectStoreRequired =>
      'Wybierz sklep przed wygenerowaniem planu!';

  @override
  String get planStoreMarketError =>
      'Wybierz sklep dostępny dla kraju Twojego konta. Odśwież listę sklepów i spróbuj ponownie.';

  @override
  String get planKcalValidation =>
      'Wpisz od 800 do 6000 kcal na osobę dziennie.';

  @override
  String get planGenerateError => 'Nie udało się wygenerować planu';

  @override
  String get planFreeLimitTitle => 'Limit darmowego konta';

  @override
  String get planUnderstood => 'Rozumiem';

  @override
  String get planViewPremium => 'Zobacz Premium';

  @override
  String get planReadyTitle => 'Plan gotowy';

  @override
  String planReadyFor(int days, int people) {
    String _temp0 = intl.Intl.pluralLogic(
      people,
      locale: localeName,
      other: '$people osób',
      one: '1 osoby',
    );
    return 'Twój plan na $days dni dla $_temp0 jest gotowy.';
  }

  @override
  String get planEstimatedBudget => 'Szacowany minimalny koszt zakupów';

  @override
  String get planShoppingLimitReached =>
      'Plan jest gotowy, ale w tym tygodniu wykorzystano już darmowy limit jednej nowej listy zakupów. Kolejną listę utworzysz w przyszłym tygodniu lub z Premium.';

  @override
  String get planStandardWeeklyLimit =>
      'Konto standardowe: jeden nowy plan tygodniowo';

  @override
  String get planWeeklyLimitExplanation =>
      'Limit odnawia się w poniedziałek. Usunięcie planu go nie odnawia. Premium pozwala tworzyć plany bez limitu.';

  @override
  String get planExplorePremium => 'Poznaj Premium';

  @override
  String get planViewAction => 'Zobacz plan';

  @override
  String get planNewTitle => 'Nowy plan posiłków';

  @override
  String get planChooseStore => 'Wybierz sklep';

  @override
  String get planPriceEstimateHint =>
      'Koszt planu jest szacunkiem. Ceny i dostępność produktów potwierdź w wybranym sklepie.';

  @override
  String planDurationTitle(int days) {
    return 'Czas trwania planu: $days dni';
  }

  @override
  String planDays(int days) {
    return '$days dni';
  }

  @override
  String get planOneDay => '1 dzień';

  @override
  String planHouseholdTitle(int people) {
    String _temp0 = intl.Intl.pluralLogic(
      people,
      locale: localeName,
      other: '$people osób',
      few: '$people osoby',
      one: '1 osoba',
    );
    return 'Dla ilu osób gotujesz: $_temp0';
  }

  @override
  String get planHouseholdHint =>
      'Od 1 do 8 osób. Domyślnie z profilu — zmiana dotyczy tylko tego planu.';

  @override
  String get planMealTypes => 'Typy posiłków';

  @override
  String get planDailyCalories => 'Cel kaloryczny dziennie';

  @override
  String get planCaloriesField => 'Docelowe kcal / dzień / osoba';

  @override
  String get planCaloriesExample => 'np. 2000';

  @override
  String get planCaloriesHint =>
      'Cel z kalkulatora; bez zapisanego celu: 2000 kcal.';

  @override
  String get planBudgetOptional => 'Maksymalny budżet (opcjonalnie)';

  @override
  String get planBudgetField => 'Maksymalny budżet';

  @override
  String get planBudgetExample => 'np. 150.00';

  @override
  String get planIncludePantry => 'Uwzględnij spiżarnię';

  @override
  String get planPantryHint =>
      'Posiadane produkty trafią na koniec listy za 0 zł. Brakującą ilość nadal dodamy do zakupów.';

  @override
  String get planIngredientPreferences => 'Lubię / Nie lubię';

  @override
  String get planIngredientPreferencesHint =>
      'Premium · jedno dopasowane danie dziennie';

  @override
  String get planGenerating => 'Generowanie...';

  @override
  String get planGenerate => 'Wygeneruj plan!';

  @override
  String get planGeneratingTitle => 'Układamy Twój optymalny plan posiłków...';

  @override
  String get planGeneratingHint =>
      'Maksymalizujemy ponowne wykorzystanie składników, aby zmniejszyć cenę zakupów.';

  @override
  String get planActivated =>
      'Plan został zatwierdzony! Lista zakupów wygenerowana.';

  @override
  String get planGenericError => 'Wystąpił błąd';

  @override
  String planSwapTitle(String recipeName) {
    return 'Zamień: $recipeName';
  }

  @override
  String get planSwapSearch => 'Szukaj dania';

  @override
  String get planSwapSearchHint => 'Wpisz nazwę przepisu';

  @override
  String get planSwapLoadError =>
      'Nie udało się pobrać przepisów. Spróbuj ponownie.';

  @override
  String get planSwapNoAlternatives => 'Brak innych dań w tej kategorii';

  @override
  String get planSwapNoSearchResults => 'Nie znaleziono dania o tej nazwie';

  @override
  String get planSwapSuccess => 'Przepis został zamieniony';

  @override
  String get planSwapError => 'Nie udało się zamienić przepisu';

  @override
  String get planFinishedTitle => 'Plan zakończony';

  @override
  String get planArchivePremiumRequired =>
      'Podgląd archiwum jest dostępny z Premium.';

  @override
  String get planFinishedHint => 'Ten plan już się zakończył.';

  @override
  String get planOpenArchive => 'Otwórz archiwum';

  @override
  String get planCreateNew => 'Utwórz nowy plan';

  @override
  String get planViewTitle => 'Plan posiłków';

  @override
  String get planNotFound =>
      'Nie znaleziono planu posiłków. Wygeneruj nowy plan.';

  @override
  String get planStoreFallback => 'Sklep';

  @override
  String get planDeleteTitle => 'Usuń plan';

  @override
  String get planDeleteQuestion =>
      'Czy na pewno chcesz usunąć ten plan posiłków? Na koncie standardowym usunięcie nie odnawia limitu jednego nowego planu tygodniowo.';

  @override
  String get planCancel => 'Anuluj';

  @override
  String get planDeleteError => 'Nie udało się usunąć planu';

  @override
  String get planDelete => 'Usuń';

  @override
  String planDay(int day) {
    return 'Dzień $day';
  }

  @override
  String get planResumeArchive => 'Archiwum · wznów plan';

  @override
  String get planChangeSettings => 'Zmień parametry';

  @override
  String get planActivate => 'Zatwierdź plan';

  @override
  String get planGoShopping => 'Przejdź do zakupów';

  @override
  String get manualRecipeDiscardTitle => 'Odrzucić zmiany?';

  @override
  String get manualRecipeUnsaved =>
      'Wpisane dane przepisu nie zostały jeszcze zapisane.';

  @override
  String get manualRecipeStay => 'Zostań';

  @override
  String get manualRecipeDiscard => 'Odrzuć';

  @override
  String get manualRecipeNutritionRequired =>
      'Ten produkt nie ma pełnych wartości odżywczych. Wybierz inny wynik albo dodaj produkt do bazy z danymi z etykiety.';

  @override
  String get manualRecipeIngredientRequired =>
      'Dodaj przynajmniej jeden składnik';

  @override
  String get manualRecipeStepRequired =>
      'Dodaj przynajmniej jeden krok przygotowania';

  @override
  String get manualRecipeTitle => 'Dodaj przepis ręcznie';

  @override
  String get manualRecipeName => 'Nazwa przepisu';

  @override
  String get manualRecipeNameRequired => 'Podaj nazwę';

  @override
  String get manualRecipeDescription => 'Krótki opis (opcjonalnie)';

  @override
  String get manualRecipeMealType => 'Rodzaj posiłku';

  @override
  String get manualRecipePreparationMinutes => 'Przygotowanie (min)';

  @override
  String get manualRecipeCookingMinutes => 'Gotowanie (min)';

  @override
  String get manualRecipeServings => 'Porcje';

  @override
  String get manualRecipeIngredients => 'Składniki';

  @override
  String get manualRecipeNoIngredients => 'Brak dodanych składników';

  @override
  String get manualRecipeSteps => 'Kroki przygotowania';

  @override
  String get manualRecipeAddStep => 'Dodaj krok';

  @override
  String get manualRecipeStepHint => 'Opisz ten krok...';

  @override
  String get manualRecipeSubmitToCatalogue => 'Zgłoś do wspólnego katalogu';

  @override
  String get manualRecipePublicHint =>
      'Po akceptacji administratora będzie widoczny dla wszystkich i policzy się do cotygodniowego konkursu.';

  @override
  String get manualRecipeSave => 'Zapisz przepis';

  @override
  String get manualRecipeChooseIngredient => 'Wybierz składnik';

  @override
  String get manualRecipeIngredientSearch =>
      'Szukaj w katalogu i bazie produktów...';

  @override
  String get manualRecipeIngredientSearchHint =>
      'Wpisz co najmniej 2 znaki, aby znaleźć składnik.';

  @override
  String get manualRecipeIngredientNotFound =>
      'Nie znaleziono produktu. Dodaj go najpierw do bazy produktów wraz z wartościami z etykiety.';

  @override
  String get manualRecipeLabelRequired => 'Wymaga uzupełnienia etykiety';

  @override
  String get manualRecipeNutritionMissing => 'Brak pełnych wartości odżywczych';

  @override
  String get aiRecipePhotoLoadFailed => 'Nie udało się pobrać zdjęcia';

  @override
  String get aiRecipeChooseGallery => 'Wybierz z galerii';

  @override
  String get aiRecipeServerUnavailable =>
      'Serwer nie ma jeszcze funkcji importu AI. Dokończ wdrożenie backendu na Renderze.';

  @override
  String get aiRecipePremiumOrPointsTitle =>
      'Potrzebujesz Premium albo punktów';

  @override
  String get aiRecipeCancel => 'Anuluj';

  @override
  String get aiRecipeBuyPoints => 'Kup punkty';

  @override
  String get aiRecipeBackToApp => 'Wróć do aplikacji';

  @override
  String get aiRecipeTitle => 'Dodaj przepis przez AI';

  @override
  String get aiRecipePhoto => 'Zdjęcie';

  @override
  String get aiRecipeLink => 'Link';

  @override
  String get aiRecipeAccepting => 'Przyjmuję przepis...';

  @override
  String get aiRecipeAcceptingHint =>
      'Za chwilę możesz wrócić do korzystania z aplikacji.';

  @override
  String get aiRecipePreparing => 'Twój przepis jest przygotowywany';

  @override
  String get aiRecipeReady => 'Przepis jest gotowy';

  @override
  String get aiRecipeRecognitionFailed => 'Nie udało się rozpoznać przepisu';

  @override
  String get aiRecipeBackgroundHint =>
      'Możesz wyjść z tego ekranu. O wyniku poinformujemy Cię w aplikacji, a przy włączonych pushach także na telefonie.';

  @override
  String get aiRecipeFindInMine => 'Znajdziesz go też w zakładce Moje.';

  @override
  String get aiRecipeRetrySentence => 'Spróbuj ponownie.';

  @override
  String get aiRecipeOpen => 'Otwórz przepis';

  @override
  String get aiRecipeEditOnePoint => 'Dostosuj z AI · 1 pkt';

  @override
  String get aiRecipeAddAnother => 'Dodaj kolejny przepis';

  @override
  String get aiRecipePasteTextTitle => 'Wklej treść przepisu';

  @override
  String get aiRecipeTextDescription =>
      'Wklej gotowy przepis (z notatnika, wiadomości, strony internetowej) — AI rozpozna składniki i kroki. Albo po prostu wpisz samą nazwę dania (np. \"rosół\" albo \"lasagne\") — AI ułoży dla Ciebie cały przepis od zera.';

  @override
  String get aiRecipeTextHint =>
      'np. \"rosół\" albo pełny przepis ze składnikami i krokami...';

  @override
  String get aiRecipeRecognise => 'Rozpoznaj przepis';

  @override
  String get aiRecipePhotoTitle => 'Zrób zdjęcie przepisu';

  @override
  String get aiRecipePhotoDescription =>
      'Zdjęcie karty przepisu, strony książki kucharskiej, albo gotowego dania — AI oszacuje wtedy prawdopodobny przepis.';

  @override
  String get aiRecipeTapAddPhoto => 'Dotknij, aby dodać zdjęcie';

  @override
  String get aiRecipePasteLinkTitle => 'Wklej link do przepisu';

  @override
  String get aiRecipeLinkDescription =>
      'Blog kulinarny, TikTok, Instagram — AI spróbuje rozpoznać przepis na podstawie treści strony. Jeśli przepis pada wyłącznie w mowie w nagraniu (nie ma go w opisie), rozpoznanie może się nie udać.';

  @override
  String get aiRecipePremiumFeature => 'Funkcja Premium';

  @override
  String get aiRecipePremiumDescription =>
      'Dodawanie własnych przepisów przez AI (z tekstu albo zdjęcia) jest dostępne dla kont z aktywną subskrypcją Premium — albo za 2 punkty premium, bez subskrypcji.';

  @override
  String get aiRecipePremiumHint =>
      'Zobacz, co jeszcze zyskujesz z Premium, albo kup pakiet punktów.';

  @override
  String get shoppingStoresLoadFailed => 'Nie udało się pobrać listy sklepów.';

  @override
  String get shoppingChooseStore => 'Wybierz sklep dla nowej listy';

  @override
  String get shoppingCreateFailed => 'Nie udało się utworzyć listy zakupów.';

  @override
  String get shoppingShareTitle => 'Udostępnij listę zakupów';

  @override
  String get shoppingShareHint =>
      'Podaj nazwę użytkownika osoby, której chcesz udostępnić listę. Musi ona mieć konto w Meal Planner Polska i zaakceptować zaproszenie, zanim zobaczy listę.';

  @override
  String get shoppingUsername => 'Nazwa użytkownika';

  @override
  String get shoppingSendInvite => 'Wyślij zaproszenie';

  @override
  String shoppingInviteSent(String nickname) {
    return 'Wysłano zaproszenie do $nickname';
  }

  @override
  String get shoppingMergeTitle => 'Połącz listy zakupów';

  @override
  String shoppingMergeHint(String storeName) {
    return 'Wybierz listy sklepu $storeName, które chcesz połączyć z obecną listą. Poprzednie listy znikną z Zakupów, ale plany posiłków pozostaną bez zmian.';
  }

  @override
  String shoppingListNumber(int number) {
    return 'Lista $number';
  }

  @override
  String shoppingListDate(int day, int month, int count) {
    return '$day.$month · $count produktów';
  }

  @override
  String get shoppingMerge => 'Połącz';

  @override
  String get shoppingMergeSuccess => 'Listy zostały połączone';

  @override
  String get shoppingMergeFailed => 'Nie udało się połączyć list';

  @override
  String get shoppingChooseSubstitute => 'Wybierz zamiennik';

  @override
  String get shoppingNoSubstitutes =>
      'Brak dostępnych zamienników w tym sklepie.';

  @override
  String get shoppingCatalogueAlternatives => 'Zamienniki katalogowe';

  @override
  String get shoppingStoreAlternatives => 'Oferty wybranego sklepu';

  @override
  String get shoppingCatalogueAvailability =>
      'Sprawdź dostępność w sklepie — cena orientacyjna.';

  @override
  String shoppingSubstituteFor(String name) {
    return 'Dla produktu: $name';
  }

  @override
  String get shoppingPriceUnknown => 'Cena nieznana';

  @override
  String shoppingSubstituteChanged(String name) {
    return 'Zamieniono na: $name';
  }

  @override
  String get shoppingListTitle => 'Lista zakupów';

  @override
  String get shoppingCreateAndAdd => 'Utwórz listę i dodaj produkt';

  @override
  String get shoppingAddProduct => 'Dodaj produkt do listy';

  @override
  String get shoppingInvites => 'Zaproszenia';

  @override
  String get shoppingShare => 'Udostępnij';

  @override
  String get shoppingRefresh => 'Odśwież';

  @override
  String get shoppingDeleteList => 'Usuń listę';

  @override
  String get shoppingMergeLists => 'Połącz listy';

  @override
  String get shoppingCompare => 'Porównaj';

  @override
  String get shoppingExport => 'Eksportuj';

  @override
  String get shoppingInPantry => 'W spiżarni';

  @override
  String get shoppingOther => 'Inne';

  @override
  String shoppingPantryCount(int count, String amount) {
    return '$count produktów już masz · $amount';
  }

  @override
  String shoppingBoughtCount(int checked, int total) {
    return '$checked z $total kupione';
  }

  @override
  String shoppingDeleteTitle(int number) {
    return 'Usunąć listę $number?';
  }

  @override
  String shoppingDeleteHint(String storeName) {
    return 'Lista zakupów dla sklepu $storeName zostanie trwale usunięta wraz ze wszystkimi pozycjami. Plan posiłków pozostaje bez zmian. Usunięcie nie odnawia tygodniowego limitu tworzenia list na koncie standardowym.';
  }

  @override
  String get shoppingDelete => 'Usuń';

  @override
  String get shoppingDeleted => 'Lista usunięta';

  @override
  String get shoppingDeleteFailed => 'Nie udało się usunąć listy';

  @override
  String get shoppingHaveEverything => 'Masz wszystko z listy';

  @override
  String get shoppingCompleteHint =>
      'Przenieś kupione produkty do spiżarni, żeby aplikacja mogła podpowiadać przepisy z tego, co masz w domu.';

  @override
  String get shoppingMovePantry => 'Przenieś do spiżarni';

  @override
  String get shoppingCompleteWithoutPantry => 'Zakończ bez przenoszenia';

  @override
  String get shoppingCompleteFailed => 'Nie udało się zakończyć listy';

  @override
  String shoppingCompleteMoved(int count) {
    return 'Zakupy zakończone. Do spiżarni trafiło $count produktów.';
  }

  @override
  String get shoppingCompleteSuccess => 'Zakupy zakończone.';

  @override
  String shoppingProgressCount(int checked, int total) {
    return '$checked z $total produktów';
  }

  @override
  String get shoppingEverythingBought => 'Wszystko kupione';

  @override
  String shoppingUnknownRemaining(String amount) {
    return 'Od ~$amount · część cen nieznana';
  }

  @override
  String shoppingRemaining(String amount) {
    return 'Do zapłaty: ~$amount';
  }

  @override
  String shoppingBasketTotal(String basket, String total) {
    return 'w koszyku: $basket z ~$total';
  }

  @override
  String get shoppingItemSaveFailed => 'Nie udało się zapisać pozycji.';

  @override
  String shoppingPackageBuy(int count, String quantity, String unit) {
    return 'Do kupienia: $count × $quantity $unit';
  }

  @override
  String get shoppingSubstituteBadge => 'ZAMIENNIK';

  @override
  String shoppingPromotionBadge(int percent) {
    return 'PROMOCJA -$percent%';
  }

  @override
  String get shoppingEmptyTitle => 'Brak aktywnej listy zakupów';

  @override
  String get shoppingEmptyHint =>
      'Kliknij +, wybierz sklep i dodaj pierwszy produkt. Możesz też wygenerować listę z planu posiłków.';

  @override
  String get shoppingListInvites => 'Zaproszenia do list';

  @override
  String shoppingEstimatedTotal(String amount) {
    return 'Szacowany koszt: $amount';
  }

  @override
  String get shoppingFriendReadOnly =>
      'Podgląd listy znajomego — tylko do odczytu';

  @override
  String get priceCompareListSwitchStore => 'Przełącz listę na ten sklep';

  @override
  String priceCompareListSwitchSuccess(String storeName) {
    return 'Lista przełączona na $storeName';
  }

  @override
  String get shoppingNoItems => 'Brak pozycji na liście';

  @override
  String get productsTitle => 'Produkty';

  @override
  String get productsPriceSources => 'Źródła cen i marek';

  @override
  String get productsShopTab => 'Sklep';

  @override
  String get productsCatalogueTab => 'Katalog';

  @override
  String get productsMineTab => 'Moje';

  @override
  String get productsScan => 'Skanuj kod kreskowy';

  @override
  String get productsBatchScan => 'Skanuj wiele produktów';

  @override
  String get productsBrandSearch => 'Szukaj produktu lub marki…';

  @override
  String get productsClear => 'Wyczyść';

  @override
  String get productsRetry => 'Spróbuj ponownie';

  @override
  String get productsNotFound => 'Nie znaleziono produktów.';

  @override
  String get productsShowMore => 'Pokaż więcej';

  @override
  String get productsSearch => 'Szukaj produktu...';

  @override
  String get productsNoShop => 'Brak wybranego sklepu';

  @override
  String get productsChooseShop =>
      'Aby przeglądać produkty i ceny, wybierz sklep w swoim profilu lub z listy powyżej.';

  @override
  String get productsError => 'Coś poszło nie tak';

  @override
  String get productsEmpty => 'Brak produktów';

  @override
  String get productsChangeSearch => 'Spróbuj zmienić wyszukiwaną frazę.';

  @override
  String get productsUnknown => 'Nieznany produkt';

  @override
  String get productsUnavailable => 'niedostępny';

  @override
  String get productsDeleteTitle => 'Usunąć produkt?';

  @override
  String get productsCancel => 'Anuluj';

  @override
  String get productsDelete => 'Usuń';

  @override
  String get productsAdd => 'Dodaj produkt';

  @override
  String get productsNothingSubmitted =>
      'Nie zgłosiłeś/aś jeszcze żadnego produktu.';

  @override
  String get productsSubmitHint =>
      'Dotknij „Dodaj produkt” poniżej, żeby zgłosić coś,\nczego nie ma w katalogu.';

  @override
  String get productsApproved => 'W katalogu';

  @override
  String get productsRejected => 'Odrzucony';

  @override
  String get productsPending => 'Oczekuje na akceptację';

  @override
  String get productsEdit => 'Edytuj';

  @override
  String get productsEstimatedPrice => 'cena orientacyjna';

  @override
  String get productsUnknownQuantity => '/ jednostka nieokreślona';

  @override
  String get diaryTitle => 'Dziennik kalorii';

  @override
  String get diaryLoadError => 'Nie udało się załadować dziennika.';

  @override
  String get diaryPreviousDay => 'Poprzedni dzień';

  @override
  String get diaryNextDay => 'Następny dzień';

  @override
  String get diaryToday => 'Wróć do dziś';

  @override
  String get diaryRemainingKcal => 'kcal pozostało';

  @override
  String get diaryActivity => 'Dodaj aktywność';

  @override
  String get diaryActivityName => 'Co robiłeś/aś?';

  @override
  String get diaryActivityHint => 'np. bieganie, rower, siłownia';

  @override
  String get diaryBurnedCalories => 'Spalone kalorie';

  @override
  String get diaryOptionalDuration => 'Czas (opcjonalnie)';

  @override
  String get diaryActivityInvalid => 'Podaj nazwę i liczbę spalonych kalorii.';

  @override
  String get diaryRecipeNoIngredients =>
      'Ten przepis nie ma listy składników do edycji.';

  @override
  String get diaryUpdatedNutrition => 'Zaktualizowano kaloryczność wpisu';

  @override
  String get diarySaveError => 'Nie udało się zapisać zmian';

  @override
  String get diaryEditAmount => 'Edytuj ilość';

  @override
  String get diaryInvalidAmount => 'Podaj prawidłową ilość';

  @override
  String get diarySave => 'Zapisz';

  @override
  String get diaryAmountUpdated => 'Zaktualizowano ilość i wartości odżywcze';

  @override
  String get diaryAmountSaveError => 'Nie udało się zapisać ilości';

  @override
  String get diaryLoadingWater => 'Wczytywanie nawodnienia…';

  @override
  String get diaryWaterError => 'Nie udało się wczytać nawodnienia.';

  @override
  String get diaryHydration => 'Nawodnienie';

  @override
  String get diaryUndoGlass => 'Cofnij szklankę';

  @override
  String get diaryWaterQuestion => 'Ile wypiłeś/aś?';

  @override
  String get diaryWaterHint => 'np. 300';

  @override
  String get diaryWaterInvalid => 'Podaj liczbę mililitrów.';

  @override
  String get diaryGlass => 'Szklanka';

  @override
  String get diaryBottle => 'Butelka';

  @override
  String get diaryProtein => 'Białko';

  @override
  String get diaryCarbs => 'Węgle';

  @override
  String get diaryFat => 'Tłuszcze';

  @override
  String get diaryMacroTargets => 'Optymalny podział dla Twojego celu kcal';

  @override
  String get diaryNoMeals => 'Brak zjedzonych posiłków w tym dniu.';

  @override
  String get diaryDeleteMeal => 'Usunąć posiłek?';

  @override
  String get diaryRemoveEntry => 'Usuń z Dziennika';

  @override
  String get amountPositive => 'Podaj ilość większą od zera';

  @override
  String get amountClose => 'Zamknij';

  @override
  String get amountQuick => 'Szybki wybór';

  @override
  String get amountQuickHint => 'Dotknij wariantu, aby od razu go wybrać.';

  @override
  String get amountCustom => 'Własna ilość';

  @override
  String get amountUnit => 'Jednostka';

  @override
  String get amountQuantity => 'Ilość';

  @override
  String get amountChoose => 'Wybierz ilość';

  @override
  String get amountApproximate => 'ok. ';

  @override
  String get measurePack => 'opakowanie';

  @override
  String get measureServing => 'porcja';

  @override
  String get measurePiece => 'sztuka';

  @override
  String get measureTeaspoon => 'łyżeczka';

  @override
  String get measureGlass => 'szklanka';

  @override
  String get measureGrams => 'gramy';

  @override
  String get measureMillilitres => 'mililitry';

  @override
  String get nutritionMissing => 'Brak danych odżywczych';

  @override
  String get recipeNutritionEstimated =>
      'Wartości orientacyjne: część składników oszacowano. Mogą różnić się od danych na etykiecie.';

  @override
  String get recipeNutritionPartial =>
      'Niepełne dane. ≥ pokazuje wyłącznie sumę znanych wartości, a nie pełne makro posiłku.';

  @override
  String get recipeNutritionNeedsDetails =>
      'Ten przepis ma brakujące dane odżywcze. Uzupełnij składniki w przepisie lub wpisz wartości posiłku ręcznie w Dzienniku.';

  @override
  String productsProcessed(int count) {
    return 'Obsłużono: $count produktów.';
  }

  @override
  String productsLoadFailed(String error) {
    return 'Nie udało się pobrać produktów: $error';
  }

  @override
  String productsDeleteMessage(String name) {
    return 'Usuniesz \"$name\" ze swoich zgłoszeń. Tej operacji nie da się cofnąć.';
  }

  @override
  String productsShopBrand(String brand) {
    return 'Marka w sklepie: $brand';
  }

  @override
  String productsBrand(String brand) {
    return 'Marka produktu: $brand';
  }

  @override
  String productsCheckedOn(String date) {
    return 'cena sprawdzona $date';
  }

  @override
  String diaryTodayDate(String date) {
    return 'Dzisiaj, $date';
  }

  @override
  String diaryActivityCalories(String calories) {
    return '+$calories z aktywności';
  }

  @override
  String diaryWaterProgress(String amount, String goal) {
    return '$amount z $goal ml';
  }

  @override
  String diaryDeleteMessage(String name) {
    return '„$name” zostanie usunięty z Dziennika.';
  }

  @override
  String diaryAmountTimes(String amount) {
    return 'Ilość: $amount×';
  }

  @override
  String diaryPortionSize(String amount, String unit) {
    return '1 porcja = $amount $unit';
  }

  @override
  String nutritionMacroLine(
    String kcal,
    String protein,
    String fat,
    String carbs,
  ) {
    return '$kcal kcal  •  B $protein g  •  T $fat g  •  W $carbs g';
  }

  @override
  String get productFormEdit => 'Edytuj produkt';

  @override
  String get productFormAdd => 'Dodaj własny produkt';

  @override
  String get productFormVisibility =>
      'Produkt będzie od razu dostępny dla Ciebie. Pozostali użytkownicy zobaczą go po zatwierdzeniu przez administratora.';

  @override
  String get productFormManualAfterScan =>
      'Możesz nadal wpisać dane ręcznie. Kod zostanie zachowany.';

  @override
  String get productFormCatalogFilled =>
      'Znaleziono w katalogu — dane wypełnione automatycznie.';

  @override
  String get productFormScanFilled =>
      'Znaleziono produkt — nazwa, marka i makro zostały uzupełnione.';

  @override
  String get productFormEditSaved =>
      'Zapisano. Zmiany trafiają ponownie do sprawdzenia przez administratora.';

  @override
  String get productFormAdded =>
      'Produkt dodany. Możesz go już używać; pozostali zobaczą go po zatwierdzeniu przez administratora.';

  @override
  String get productFormAlreadyExists =>
      'Ten produkt jest już zapisany w bazie. Nie trzeba dodawać go ponownie.';

  @override
  String get productFormCloseExisting => 'Zamknij — produkt jest już w bazie';

  @override
  String get productFormName => 'Nazwa produktu *';

  @override
  String get productFormNameHint => 'Wpisz nazwę lub wybierz podpowiedź';

  @override
  String get productFormNameRequired => 'Podaj nazwę produktu';

  @override
  String get productFormBrandOptional => 'Marka (opcjonalnie)';

  @override
  String get productFormBrand => 'Marka';

  @override
  String get productFormPrice => 'Cena widoczna w sklepie (opcjonalnie)';

  @override
  String get productFormPriceError =>
      'Podaj prawidłową cenę (więcej niż 0, maks. 10 000).';

  @override
  String get productFormUnit => 'Jedn.';

  @override
  String get productFormPack => 'Masa całego opakowania';

  @override
  String get productFormPackExample => 'np. 150';

  @override
  String get productFormPackHelp =>
      'Podaj masę netto całego opakowania, nie wielkość porcji. Jeśli jej nie znasz, zostaw pole puste — aplikacja nie pokaże wtedy opcji „opakowanie”.';

  @override
  String get productFormPackError =>
      'Podaj wielkość opakowania większą niż 0, maks. 100 000 g/ml, lub zostaw puste.';

  @override
  String get productFormNutritionHelp =>
      'Bez pełnych danych produkt nadal przyda się na liście zakupów. Przed dodaniem do dziennika trzeba będzie uzupełnić makro.';

  @override
  String get productFormCalories => 'Kalorie';

  @override
  String get productFormProtein => 'Białko';

  @override
  String get productFormFat => 'Tłuszcze';

  @override
  String get productFormCarbs => 'Węglow.';

  @override
  String get productFormShops =>
      'W jakich sklepach ma być dostępny? (opcjonalnie)';

  @override
  String get productFormShopsHelp =>
      'Można zaznaczyć kilka. Widoczność w wybranych sklepach pojawi się dopiero po akceptacji.';

  @override
  String get productFormSaveChanges => 'Zapisz zmiany';

  @override
  String get productFormSave => 'Dodaj produkt';

  @override
  String get productFormNumberError => 'Podaj prawidłową liczbę.';

  @override
  String get productFormRequestFailed =>
      'Nie udało się zapisać produktu. Dane zostały zachowane — spróbuj ponownie.';

  @override
  String get productLabelTitle => 'Dodaj brakujący produkt';

  @override
  String get productLabelTakePhoto => 'Zrób zdjęcie';

  @override
  String get productLabelGallery => 'Wybierz z galerii';

  @override
  String get productLabelBothPhotos =>
      'Dodaj oba zdjęcia: przód i tabelę wartości.';

  @override
  String get productLabelNameError =>
      'Sprawdź i uzupełnij nazwę produktu (2–300 znaków).';

  @override
  String get productLabelReading => 'Odczytywanie etykiety…';

  @override
  String get productLabelRead => 'Odczytaj dane';

  @override
  String get productLabelFront => 'Przód opakowania';

  @override
  String get productLabelNutrition => 'Tabela wartości';

  @override
  String get productLabelReview => 'Sprawdź dane przed zapisaniem';

  @override
  String get productLabelConfirm => 'Potwierdź i zapisz';

  @override
  String get productLabelMissingNutrition =>
      'Uzupełnij kcal, białko, tłuszcz i węglowodany na 100 g/ml.';

  @override
  String get productLabelReadFailed =>
      'Nie udało się odczytać etykiety. Zdjęcia zostały zachowane — spróbuj ponownie.';

  @override
  String get productLabelPhotoFailed =>
      'Nie udało się otworzyć zdjęcia. Sprawdź dostęp do aparatu lub galerii i spróbuj ponownie.';

  @override
  String get productFormBrandError => 'Marka może mieć maksymalnie 200 znaków.';

  @override
  String productFormScanned(String code) {
    return 'Zeskanowano: $code (zmień)';
  }

  @override
  String productFormTypicalPrice(String minimum, String maximum) {
    return 'Typowy zakres cen: $minimum–$maximum zł';
  }

  @override
  String productFormReward(int points) {
    return 'Produkt dodany • +$points punkt Premium';
  }

  @override
  String productFormBalance(int points) {
    return ' • saldo: $points';
  }

  @override
  String productFormNutrition(String unit) {
    return 'Wartości odżywcze na 100 $unit (opcjonalnie)';
  }

  @override
  String productLabelIntro(String code) {
    return 'Brakuje pełnych danych dla kodu $code. Dwa wyraźne zdjęcia pozwolą odczytać je bez ręcznego przepisywania.';
  }

  @override
  String productLabelPer100(String unit) {
    return 'Wartości na 100 $unit';
  }

  @override
  String productFormNumberRange(String maximum) {
    return 'Podaj liczbę od 0 do $maximum.';
  }

  @override
  String get productFormChooseUnit =>
      'Wybierz gramy lub mililitry dla wielkości opakowania.';

  @override
  String get productFormLookupFailed =>
      'Nie udało się wyszukać produktu. Kod zachowano — możesz wpisać dane ręcznie.';

  @override
  String get detailTikTokFailed => 'Nie udało się otworzyć profilu TikTok.';

  @override
  String get detailAiUpdated => 'Przepis został zmieniony przez AI.';

  @override
  String get detailAiAction => 'Dostosuj przepis z AI · 1 pkt';

  @override
  String get detailRecipeAuthor => 'autora przepisu';

  @override
  String get detailTime => 'Czas';

  @override
  String get detailServings => 'Porcje';

  @override
  String get detailNutrition => 'Wartości odżywcze';

  @override
  String get detailPerServing => 'na 1 porcję';

  @override
  String get detailChange => 'Zmień';

  @override
  String get detailLoading => 'Ładowanie składników i sposobu przygotowania…';

  @override
  String get detailRetry => 'Spróbuj ponownie wczytać szczegóły';

  @override
  String get detailTemporary => 'Wariant tymczasowy';

  @override
  String get detailTemporaryHelp =>
      'Oryginalny przepis nie został zmieniony. Przy tworzeniu listy zakupów ten wariant zapisze się w Moje, aby lista zawierała widoczne tutaj składniki i ilości. Po zapisie przeliczymy wartości odżywcze.';

  @override
  String get detailSaveVariant => 'Zapisz wariant w Moje';

  @override
  String get detailUndo => 'Cofnij zmiany';

  @override
  String get detailIngredient => 'Składnik';

  @override
  String get detailPastaTitle => 'Lifehack: porcja makaronu bez wagi';

  @override
  String get detailPastaHelp =>
      'Chwyć suchy makaron w dwa palce, formując kółko — jeśli jego średnica odpowiada mniej więcej monecie 5 zł, to jedna porcja (ok. 80-100 g) na osobę.';

  @override
  String get detailMethod => 'Sposób przygotowania';

  @override
  String get detailAlsoAdd => 'Możesz też dodać';

  @override
  String get detailSeasoningHelp => 'opcjonalne przyprawy, żeby wzbogacić smak';

  @override
  String get detailFiber => 'Błonnik';

  @override
  String get variantTitle => 'Zmień składniki';

  @override
  String get variantHelp =>
      'Zmiany są tymczasowe. Oryginalny przepis pozostanie bez zmian.';

  @override
  String get variantAlreadyAdded => 'Ten produkt jest już na liście.';

  @override
  String get variantRemove => 'Usuń składnik';

  @override
  String get variantApply => 'Zastosuj tymczasowo';

  @override
  String variantQuantityError(int maximum) {
    return 'Wpisz ilość większą od zera, nie większą niż $maximum.';
  }

  @override
  String get aiEditTitle => 'Dostosuj przepis z AI';

  @override
  String get aiEditPromptLabel => 'Co zmienić lub dodać?';

  @override
  String get aiEditPromptHint =>
      'Np. zamień kurczaka na tofu i zmień kroki przygotowania';

  @override
  String get aiEditBuyPoints => 'Kup punkty';

  @override
  String get aiEditSubmit => 'Zmień przepis · 1 pkt';

  @override
  String get detailFavoriteError => 'Nie udało się zaktualizować ulubionych';

  @override
  String get detailRemoveFavorite => 'Usuń z ulubionych';

  @override
  String get detailAddFavorite => 'Dodaj do ulubionych';

  @override
  String get detailDeleteTitle => 'Usunąć przepis?';

  @override
  String get detailDeletePublicHelp =>
      'Ten przepis jest widoczny dla wszystkich — usunięcie go usunie go też z list zakupów i planów innych osób, które go używały. Tej operacji nie da się cofnąć.';

  @override
  String get detailDeleteHelp => 'Tej operacji nie da się cofnąć.';

  @override
  String get detailDeleteFailed => 'Nie udało się usunąć przepisu';

  @override
  String get detailDelete => 'Usuń przepis';

  @override
  String get detailPublishTitle => 'Opublikować przepis?';

  @override
  String get detailPublishHelp =>
      'Przepis trafi do kolejki oczekującej na akceptację administratora. Po zatwierdzeniu będzie widoczny dla wszystkich użytkowników aplikacji.';

  @override
  String get detailPublishSubmit => 'Opublikuj';

  @override
  String get detailPublishSent =>
      'Przepis zgłoszony — czeka na akceptację administratora.';

  @override
  String get detailPublishFailed => 'Nie udało się opublikować przepisu.';

  @override
  String get detailPublish => 'Opublikuj przepis';

  @override
  String get detailShopping => 'Lista zakupów na to danie';

  @override
  String get detailChooseShop => 'Wybierz najpierw sklep w swoim profilu';

  @override
  String get detailPhotoSent =>
      'Dziękujemy! Zdjęcie pojawi się po akceptacji przez administratora.';

  @override
  String get detailPhotoReplaceHelp =>
      'Ten przepis ma już zdjęcie. Jeśli Twoje zostanie zaakceptowane, zastąpi obecne.';

  @override
  String get detailPhotoSending => 'Wysyłanie…';

  @override
  String get detailPhotoReplace => 'Zaproponuj inne zdjęcie';

  @override
  String get detailPhotoAdd => 'Dodaj zdjęcie';

  @override
  String get detailAiPhoto => 'Zdjęcie poglądowe, wygenerowane przez AI';

  @override
  String detailSavedVariant(String name) {
    return 'Zapisano w Moje jako „$name”.';
  }

  @override
  String detailAddedBy(String name) {
    return 'Dodane przez $name';
  }

  @override
  String variantAmount(String unit) {
    return 'Ilość ($unit)';
  }

  @override
  String variantBrand(String brand) {
    return 'Marka: $brand';
  }

  @override
  String aiEditIntro(String name) {
    return 'Napisz, co zmienić w „$name”. Możesz np. poprosić o wersję bez mleka albo dodać konkretny składnik.';
  }

  @override
  String aiEditCost(int points) {
    return 'Udana zmiana kosztuje 1 punkt premium. Masz: $points pkt.';
  }

  @override
  String detailExistingLists(int count, String word) {
    return 'Masz już $count $word — dodaj do niej, albo stwórz nową.';
  }

  @override
  String detailListItems(int count) {
    return '$count pozycji';
  }

  @override
  String get variantSearchHint => 'Wpisz nazwę produktu';

  @override
  String get detailAddToList => 'Dodaj do listy zakupów';

  @override
  String get detailCreateList => 'Stwórz nową listę';

  @override
  String get productsOnlineCatalogue =>
      'Katalog online — dostępność lokalna może się różnić';

  @override
  String get productsGenericFood =>
      'Produkt ogólny — sprawdź dostępność w sklepie';

  @override
  String get productsNationalAverage => 'Średnia UK, nie cena sklepowa';

  @override
  String get productsPriceUnavailable => 'Brak ceny';

  @override
  String get commentsLoadFailed => 'Nie udało się załadować komentarzy';

  @override
  String get commentsPhotoFailed => 'Nie udało się pobrać zdjęcia';

  @override
  String get commentsCamera => 'Zrób zdjęcie';

  @override
  String get commentsGallery => 'Wybierz z galerii';

  @override
  String get commentsDeleteTitle => 'Usunąć komentarz?';

  @override
  String get commentsDeleteBody => 'Tej operacji nie da się cofnąć.';

  @override
  String get commentsCancel => 'Anuluj';

  @override
  String get commentsDelete => 'Usuń';

  @override
  String get commentsDeleteFailed => 'Nie udało się usunąć komentarza';

  @override
  String get commentsLikeFailed => 'Nie udało się zapisać polubienia';

  @override
  String get commentsJustNow => 'przed chwilą';

  @override
  String get commentsTitle => 'Komentarze i zdjęcia';

  @override
  String get commentsFirst =>
      'Bądź pierwszą osobą, która skomentuje ten przepis';

  @override
  String get commentsHint => 'Podziel się swoją opinią lub wskazówką...';

  @override
  String get commentsPhoto => 'Dodaj zdjęcie';

  @override
  String get commentsAdd => 'Dodaj';

  @override
  String get commentsDeleteTooltip => 'Usuń komentarz';

  @override
  String get commentsModerateTooltip => 'Usuń komentarz (moderacja)';

  @override
  String get reportTitle => 'Zgłoś treść';

  @override
  String get reportReason => 'Powód zgłoszenia:';

  @override
  String get reportDetails => 'Dodatkowe szczegóły (opcjonalnie)';

  @override
  String get reportSend => 'Zgłoś';

  @override
  String get reportThanks =>
      'Dziękujemy za zgłoszenie. Nasz zespół je sprawdzi.';

  @override
  String get reportFailed =>
      'Nie udało się wysłać zgłoszenia. Spróbuj ponownie.';

  @override
  String get reportSpam => 'Spam albo reklama';

  @override
  String get reportInappropriate => 'Treść nieodpowiednia';

  @override
  String get reportHarassment => 'Nękanie albo mowa nienawiści';

  @override
  String get reportMisinformation => 'Fałszywe informacje';

  @override
  String get reportOther => 'Inny powód';

  @override
  String get blockTitle => 'Zablokować tego użytkownika?';

  @override
  String get blockAction => 'Zablokuj';

  @override
  String get blockAuthor => 'Zablokuj autora';

  @override
  String get blockFailed => 'Nie udało się zablokować użytkownika.';

  @override
  String commentsMinutes(int count) {
    return '$count min temu';
  }

  @override
  String commentsHours(int count) {
    return '$count godz. temu';
  }

  @override
  String commentsDays(int count) {
    return '$count dni temu';
  }

  @override
  String commentsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count komentarza',
      many: '$count komentarzy',
      few: '$count komentarze',
      one: '1 komentarz',
    );
    return '$_temp0';
  }

  @override
  String blockBody(String name) {
    return 'Nie będziesz już widzieć przepisów ani komentarzy od \"$name\". Możesz cofnąć blokadę w dowolnym momencie w Profil → Zablokowani użytkownicy.';
  }

  @override
  String blockDone(String name) {
    return 'Użytkownik \"$name\" został zablokowany.';
  }

  @override
  String get profileTitle => 'Profil';

  @override
  String get profileNone => 'Brak';

  @override
  String get profileShop => 'Sklep';

  @override
  String get profileUser => 'Użytkownik';

  @override
  String get profileExpiryToday => 'Subskrypcja wygasa dziś';

  @override
  String get profileHealth => 'Zdrowie i cele';

  @override
  String get profileCommunity => 'Społeczność';

  @override
  String get profileFriends => 'Znajomi';

  @override
  String get profileFriendsHint => 'Zaproszenia, przepisy i listy zakupów';

  @override
  String get profileSubscription => 'Subskrypcja';

  @override
  String get profileUpgrade => 'Zostań Premium';

  @override
  String get profileUpgradeHint =>
      'Automatyczny plan tygodnia, seryjne skanowanie i listy bez limitu';

  @override
  String get profileCompare => 'Porównanie planów';

  @override
  String get profilePreferences => 'Preferencje';

  @override
  String get profilePreferredShop => 'Preferowany sklep';

  @override
  String get profileDiet => 'Rodzaj diety';

  @override
  String get profileHousehold => 'Liczba osób w gospodarstwie';

  @override
  String get profileLikes => 'Lubię / Nie lubię';

  @override
  String get profileArchive => 'Archiwum planów';

  @override
  String get profileArchiveHint => 'Premium · podgląd i wznowienie';

  @override
  String get profileDarkMode => 'Tryb ciemny';

  @override
  String get profilePrivacy => 'Konto i prywatność';

  @override
  String get profileAddUsername => 'Dodaj nazwę użytkownika';

  @override
  String get profileLogout => 'Wyloguj się';

  @override
  String get profileBlocked => 'Zablokowani użytkownicy';

  @override
  String get profileDelete => 'Usuń konto';

  @override
  String get profileAdmin => 'Panel administratora';

  @override
  String get profileChooseShop => 'Wybierz sklep';

  @override
  String get profileHealthTitle => 'Waga, wzrost i cel kaloryczny';

  @override
  String get profileHealthHint =>
      'Uzupełnij dane, aby obliczyć BMI i zapotrzebowanie';

  @override
  String get profileBmiLow => 'niedowaga';

  @override
  String get profileBmiNormal => 'waga prawidłowa';

  @override
  String get profileBmiHigh => 'nadwaga';

  @override
  String get profileBmiObese => 'otyłość';

  @override
  String get profileMeasurementDate => 'Data pomiaru';

  @override
  String get profileSelect => 'Wybierz';

  @override
  String get profileWeightInvalid => 'Podaj prawidłową wagę od 0,1 do 400 kg.';

  @override
  String get profileWeightTitle => 'Śledzenie wagi';

  @override
  String get profileWeightHint =>
      'Zapisz pomiar dla wybranego dnia. Ponowny zapis poprawi wpis z tej samej daty.';

  @override
  String get profileWeightOptional => 'Waga (opcjonalnie)';

  @override
  String get profileSaveMeasurement => 'Zapisz pomiar';

  @override
  String get profileStatistics => 'Statystyki';

  @override
  String get profilePhotoFailed => 'Nie udało się zapisać zdjęcia';

  @override
  String get profileAvatar => 'Wybierz awatar';

  @override
  String get profileGallery => 'Z galerii';

  @override
  String get profileAvatarOr => 'albo wybierz ikonę';

  @override
  String get profileFemale => 'Kobieta';

  @override
  String get profileMale => 'Mężczyzna';

  @override
  String get profileNicknameTitle => 'Zmień pseudonim';

  @override
  String get profileNickname => 'Pseudonim';

  @override
  String get profileSave => 'Zapisz';

  @override
  String get profileNicknameSaved => 'Pseudonim zaktualizowany.';

  @override
  String get profileNicknameFailed => 'Nie udało się zmienić pseudonimu.';

  @override
  String get profileTikTokFailed => 'Nie udało się otworzyć profilu TikTok.';

  @override
  String get profileTikTokAdd => 'Dodaj TikTok';

  @override
  String get profileTikTokEdit => 'Edytuj TikTok';

  @override
  String get profileTikTokUsername => 'Nazwa użytkownika TikTok';

  @override
  String get profileTikTokPlaceholder => '@twojanazwa';

  @override
  String get profileTikTokHelp => 'Możesz wkleić także pełny link do profilu.';

  @override
  String get profileTikTokInvalid =>
      'Wpisz 2–24 znaki: litery, cyfry, kropki lub podkreślenia.';

  @override
  String get profileTikTokRemoved => 'Usunięto nazwę TikTok.';

  @override
  String get profileTikTokSaved => 'Dodano odnośnik do profilu TikTok.';

  @override
  String get profileTikTokSaveFailed => 'Nie udało się zapisać nazwy TikTok.';

  @override
  String get profileDeleteTitle => 'Usunąć konto na stałe?';

  @override
  String get profileNext => 'Dalej';

  @override
  String get profileDeleteFinal => 'Ostatnie potwierdzenie';

  @override
  String get profileDeleteFinalBody =>
      'Na pewno? Tej operacji nie da się cofnąć.';

  @override
  String get profileDeleteFailed =>
      'Nie udało się usunąć konta. Spróbuj ponownie.';

  @override
  String get profileDietAny => 'Bez ograniczeń';

  @override
  String get profileDietVegetarian => 'Wegetariańska';

  @override
  String get profileDietVegan => 'Wegańska';

  @override
  String get profileDietKeto => 'Keto';

  @override
  String get profileDietLactose => 'Bez laktozy';

  @override
  String get documentContact => 'Kontakt';

  @override
  String get documentEmailBody => 'Napisz do nas na adres:';

  @override
  String get documentCopy => 'Kopiuj adres';

  @override
  String get documentClose => 'Zamknij';

  @override
  String get documentOpenFailed =>
      'Nie udało się otworzyć dokumentu. Spróbuj ponownie.';

  @override
  String get documentTerms => 'Regulamin (EULA)';

  @override
  String get documentPrivacy => 'Polityka prywatności';

  @override
  String get documentDeletion => 'Usuwanie konta — informacje';

  @override
  String get documentHelp => 'Pomoc';

  @override
  String get compareWeekly => 'Automatyczny plan i lista co tydzień';

  @override
  String get compareArchive => 'Archiwum i wznowienie zakończonych planów';

  @override
  String get compareLikes =>
      'Lubię / Nie lubię: jedno dopasowane danie dziennie';

  @override
  String get compareAi => 'Import przepisu przez AI (zdjęcie, tekst, link)';

  @override
  String get compareBatch =>
      'Seryjne skanowanie produktów bez zamykania aparatu';

  @override
  String get comparePublish => 'Publikacja przepisów we wspólnym katalogu';

  @override
  String get compareTikTok => 'Odnośnik TikTok przy własnych przepisach';

  @override
  String get compareLists => 'Listy zakupów z wybranych przepisów';

  @override
  String get compareUnlimited => 'Bez limitu';

  @override
  String get compareOneWeek => '1 / tydzień';

  @override
  String get compareGenerate => 'Generowanie planu posiłków';

  @override
  String get compareJournal => 'Dziennik kalorii i makroskładników';

  @override
  String get compareCalculator => 'Kalkulator zapotrzebowania kalorycznego';

  @override
  String get compareCatalogue => 'Baza przepisów i produktów';

  @override
  String get comparePrices => 'Porównywarka cen produktów';

  @override
  String profileExpiryDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days dni',
      one: '1 dzień',
    );
    return 'Subskrypcja aktywna jeszcze przez $_temp0';
  }

  @override
  String profilePeople(int count) {
    return '$count os.';
  }

  @override
  String profileWeightSaved(String weight) {
    return 'Zapisano $weight kg.';
  }

  @override
  String profileDate(String date) {
    return 'Data: $date';
  }

  @override
  String get profileDeleteBody =>
      'Ta operacja jest NIEODWRACALNA. Stracisz wszystkie zapisane plany posiłków, listy zakupów, spiżarnię, ulubione przepisy, komentarze i punkty premium. Jeśli masz aktywną subskrypcję, pamiętaj, żeby anulować ją osobno w ustawieniach App Store / Google Play — usunięcie konta samo jej nie anuluje.';

  @override
  String premiumTrialBadge(int days) {
    return '$days DNI ZA 0 ZŁ*';
  }

  @override
  String get premiumCheckTrial => 'Sprawdź okres próbny';

  @override
  String premiumTrialEligibilityFootnote(String store) {
    return '* Dla kont uprawnionych do oferty. Dostępność, cena po okresie próbnym i termin odnowienia zostaną pokazane przez $store przed potwierdzeniem.';
  }

  @override
  String get premiumNotNow => 'Nie teraz';

  @override
  String get premiumPurchaseError => 'Wystąpił błąd podczas zakupu.';

  @override
  String get premiumAppleOfferOpenFailed =>
      'Nie udało się otworzyć oferty w App Store.';

  @override
  String premiumPaymentsUnavailable(String store) {
    return 'Płatności są niedostępne na tym urządzeniu (sprawdź konto $store).';
  }

  @override
  String get premiumSubscriptionPricesUnavailable =>
      'Nie udało się pobrać cen subskrypcji. Spróbuj ponownie za chwilę.';

  @override
  String premiumPurchaseFailed(String error) {
    return 'Zakup nie powiódł się: $error';
  }

  @override
  String get premiumUnknownError => 'nieznany błąd';

  @override
  String get premiumActive => 'Premium jest aktywne.';

  @override
  String get premiumActivated => 'Premium aktywowane — dziękujemy!';

  @override
  String premiumPurchaseVerificationFailed(String error) {
    return 'Nie udało się potwierdzić zakupu: $error';
  }

  @override
  String premiumPointsAdded(int balance) {
    return 'Dodano punkty! Masz teraz $balance punktów.';
  }

  @override
  String premiumPurchaseStartFailed(String error) {
    return 'Nie udało się rozpocząć zakupu: $error';
  }

  @override
  String get premiumRestoreEmpty =>
      'Nie znaleziono żadnych wcześniejszych zakupów do przywrócenia.';

  @override
  String premiumQuickActionPoints(String subtitle, int points) {
    return '$subtitle — albo $points pkt bez subskrypcji';
  }

  @override
  String get premiumAutomaticWeekTitle => 'Automatyczny tydzień';

  @override
  String get premiumAutomaticWeekDescription =>
      'W wybranym dniu przygotujemy plan i opcjonalną listę zakupów.';

  @override
  String get premiumBatchTitle => 'Skanowanie seryjne';

  @override
  String get premiumBatchDescription =>
      'Skanuj bez zamykania aparatu i dodaj całą serię do wybranych miejsc.';

  @override
  String get premiumUnlimitedPlansTitle => 'Plany posiłków bez limitu';

  @override
  String get premiumUnlimitedPlansDescription =>
      'Generuj tyle planów, ile chcesz — bez tygodniowego limitu.';

  @override
  String get premiumAiRecipesTitle => 'Przepisy rozpoznawane przez AI';

  @override
  String get premiumAiRecipesDescription =>
      'Dodawaj własne przepisy z wklejonego tekstu albo zdjęcia.';

  @override
  String get premiumFullDiaryTitle => 'Pełna historia Dziennika';

  @override
  String get premiumFullDiaryDescription =>
      'Przeglądaj całą historię kalorii, bez limitu 30 dni wstecz.';

  @override
  String get premiumUnlimitedListsTitle => 'Listy zakupów bez limitu';

  @override
  String get premiumUnlimitedListsDescription =>
      'Twórz nowe listy zakupów wtedy, kiedy ich potrzebujesz.';

  @override
  String get premiumProductName => 'Meal Planner Premium';

  @override
  String get premiumHeroDescription =>
      'Zaplanuj cały tydzień, zeskanuj zakupy i przygotuj listę w kilka minut.';

  @override
  String get premiumAutomaticWeekSubtitle =>
      'Plan i opcjonalna lista zakupów gotowe co tydzień';

  @override
  String get premiumAutomaticWeekRequired =>
      'Automatyczny tydzień jest dostępny w Premium.';

  @override
  String get premiumAiActionTitle => 'Dodaj przepis przez AI';

  @override
  String get premiumAiActionSubtitle =>
      'Zdjęcie, tekst albo link — AI zrobi resztę';

  @override
  String get premiumBatchActionTitle => 'Skanuj wiele produktów po kolei';

  @override
  String get premiumBatchActionSubtitle =>
      'Wybierz kilka miejsc i zatwierdź całą serię';

  @override
  String premiumBatchCompleted(int count) {
    return 'Obsłużono: $count produktów.';
  }

  @override
  String get premiumPublishActionTitle => 'Publikuj przepisy we wspólnocie';

  @override
  String get premiumPublishActionSubtitle =>
      'Podziel się swoimi przepisami z innymi';

  @override
  String get premiumRecipeListsTitle => 'Listy zakupów z przepisów';

  @override
  String get premiumRecipeListsSubtitle =>
      'Bez limitu (standard: 1 tygodniowo)';

  @override
  String get premiumCookFromPantryTitle => 'Co ugotować z tego, co mam';

  @override
  String get premiumCookFromPantrySubtitle =>
      'Zaznacz składniki w domu, dopasujemy przepisy';

  @override
  String get premiumPantryActionTitle => 'Twoja spiżarnia';

  @override
  String get premiumPantryActionSubtitle =>
      'Zarządzaj produktami, które masz w domu';

  @override
  String premiumSubscriptionLegal(String store) {
    return 'Subskrypcje odnawiają się automatycznie, chyba że zostaną anulowane co najmniej 24 godziny przed końcem bieżącego okresu. Płatność jest pobierana z konta $store po potwierdzeniu zakupu. Możesz zarządzać subskrypcją albo ją anulować w ustawieniach swojego konta w sklepie.';
  }

  @override
  String get premiumAlreadyActive => 'Masz już aktywne Premium';

  @override
  String get premiumExpiresToday => 'Wygasa dziś';

  @override
  String premiumDaysRemaining(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days dnia',
      many: '$days dni',
      few: '$days dni',
      one: '$days dzień',
    );
    return 'Aktywne jeszcze przez $_temp0';
  }

  @override
  String get premiumRetry => 'Spróbuj ponownie';

  @override
  String get premiumWeekly => 'Tygodniowo';

  @override
  String get premiumMonthly => 'Miesięcznie';

  @override
  String premiumMonthlyTrial(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days dnia za darmo',
      many: '$days dni za darmo',
      few: '$days dni za darmo',
      one: '$days dzień za darmo',
    );
    return '$_temp0';
  }

  @override
  String get premiumYearly => 'Rocznie';

  @override
  String premiumYearlySaving(int percent) {
    return 'Oszczędzasz $percent%';
  }

  @override
  String premiumTrialDisclosureApple(int days) {
    return '$days-dniowy okres próbny jest dostępny dla uprawnionych kont. Potem subskrypcja odnawia się za cenę pokazaną powyżej; możesz ją anulować w ustawieniach Apple ID.';
  }

  @override
  String premiumTrialDisclosureGoogle(int days) {
    return '$days-dniowy okres próbny jest dostępny dla uprawnionych kont. Potem subskrypcja odnawia się za cenę pokazaną powyżej; możesz ją anulować w Google Play.';
  }

  @override
  String get premiumRestorePurchases => 'Przywróć zakupy';

  @override
  String get premiumPointsTitle => 'Punkty premium';

  @override
  String premiumPointsBalance(int balance) {
    return 'Masz: $balance';
  }

  @override
  String get premiumPointsExplanation =>
      'Import przepisu ze zdjęcia, tekstu lub linku kosztuje 2 punkty, a edycja AI 1 punkt — bez subskrypcji.';

  @override
  String get premiumPointsPricesUnavailable =>
      'Nie udało się pobrać cen pakietów punktów.';

  @override
  String premiumPointsAmount(int points) {
    return '$points pkt';
  }

  @override
  String premiumPromotionalPrice(String price) {
    return 'Cena promocyjna: $price';
  }

  @override
  String premiumPointsUses(int imports, int edits) {
    return '$imports importów AI\nlub $edits edycji AI';
  }

  @override
  String get premiumBuyInApple => 'Kup w App Store';

  @override
  String get premiumBuyInGoogle => 'Kup w Google Play';

  @override
  String premiumPriceAfterTrial(String price) {
    return 'Potem $price miesięcznie';
  }

  @override
  String premiumPriceBeforeCode(String price) {
    return 'Cena przed kodem: $price';
  }

  @override
  String get premiumTryFree => 'Wypróbuj za 0 zł';

  @override
  String get premiumBuy => 'Kup Premium';

  @override
  String get premiumRedeemCode => 'Odbierz kod';

  @override
  String get premiumBuyDiscount => 'Kup z rabatem';

  @override
  String get premiumContextRecipeEyebrow => 'PREMIUM DLA PRZEPISÓW';

  @override
  String get premiumContextRecipeTitle => 'Zamień inspirację w gotowy przepis';

  @override
  String get premiumContextRecipeDescription =>
      'Dodaj link, zdjęcie albo krótki opis. Otrzymasz składniki, porcje i kolejne kroki bez ręcznego przepisywania.';

  @override
  String get premiumContextRecipeBenefitImport =>
      'Przepis z linku, zdjęcia lub opisu';

  @override
  String get premiumContextRecipeBenefitSteps =>
      'Automatycznie ułożone składniki i kroki';

  @override
  String get premiumContextRecipeBenefitEdit => 'Edycja przepisu z pomocą AI';

  @override
  String get premiumContextMealPlanEyebrow => 'PREMIUM DLA PLANOWANIA';

  @override
  String get premiumContextMealPlanTitle =>
      'Zaplanuj kolejne tygodnie bez limitu';

  @override
  String get premiumContextMealPlanDescription =>
      'Twórz tyle planów, ile potrzebujesz, i szybciej dopasuj posiłki do swojego dnia.';

  @override
  String get premiumContextMealPlanBenefitUnlimited =>
      'Plany posiłków bez limitu';

  @override
  String get premiumContextMealPlanBenefitWeekly =>
      'Automatyczny plan na kolejny tydzień';

  @override
  String get premiumContextMealPlanBenefitSwap =>
      'Wygodna zamiana i wyszukiwanie dań';

  @override
  String get premiumContextBarcodeEyebrow => 'PREMIUM DLA SKANOWANIA';

  @override
  String get premiumContextBarcodeTitle =>
      'Zeskanuj całe zakupy bez zamykania aparatu';

  @override
  String get premiumContextBarcodeDescription =>
      'Skanuj produkty jeden po drugim, a potem dodaj całą serię do wybranych miejsc jednym ruchem.';

  @override
  String get premiumContextBarcodeBenefitBatch =>
      'Seryjne skanowanie produktów';

  @override
  String get premiumContextBarcodeBenefitNutrition =>
      'Makro i kalorie przy znalezionych produktach';

  @override
  String get premiumContextBarcodeBenefitDestinations =>
      'Wspólne dodanie do Dziennika, spiżarni lub katalogu';

  @override
  String get premiumContextShoppingEyebrow => 'PREMIUM DLA ZAKUPÓW';

  @override
  String get premiumContextShoppingTitle => 'Twórz listy zakupów bez limitu';

  @override
  String get premiumContextShoppingDescription =>
      'Przygotuj osobną listę na każdy plan lub przepis i połącz listy dla tego samego sklepu.';

  @override
  String get premiumContextShoppingBenefitLists =>
      'Dowolna liczba list zakupów';

  @override
  String get premiumContextShoppingBenefitMerge =>
      'Łączenie list dla jednego sklepu';

  @override
  String get premiumContextShoppingBenefitPantry =>
      'Produkty ze spiżarni liczone za 0 zł';

  @override
  String get premiumContextPantryEyebrow => 'PREMIUM DLA SPIŻARNI';

  @override
  String get premiumContextPantryTitle =>
      'Wykorzystaj produkty, które już masz';

  @override
  String get premiumContextPantryDescription =>
      'Znajdź przepisy dopasowane do zawartości spiżarni i kup tylko to, czego naprawdę brakuje.';

  @override
  String get premiumContextPantryBenefitMatch =>
      'Przepisy z dostępnych składników';

  @override
  String get premiumContextPantryBenefitMissing =>
      'Mniej brakujących produktów';

  @override
  String get premiumContextPantryBenefitWaste => 'Mniej marnowania jedzenia';

  @override
  String get premiumContextJournalEyebrow => 'PREMIUM DLA DZIENNIKA';

  @override
  String get premiumContextJournalTitle =>
      'Zobacz, jak zmieniają się Twoje wyniki';

  @override
  String get premiumContextJournalDescription =>
      'Śledź dłuższy okres i łatwiej zauważaj zmiany w kaloriach, makro, nawodnieniu oraz wadze.';

  @override
  String get premiumContextJournalBenefitHistory => 'Pełna historia Dziennika';

  @override
  String get premiumContextJournalBenefitCharts =>
      'Wykresy kalorii, makro i nawodnienia';

  @override
  String get premiumContextJournalBenefitWeight => 'Postępy wagi w czasie';

  @override
  String get premiumPackageSemantics => 'Pakiet';

  @override
  String premiumDiscountSemantics(int percent) {
    return 'Rabat $percent procent';
  }

  @override
  String premiumDiscountRibbon(int percent) {
    return 'RABAT -$percent%';
  }

  @override
  String get premiumSeePlans => 'Zobacz plany Premium';

  @override
  String get archiveTitle => 'Archiwum planów';

  @override
  String get archiveChooseStart => 'Od kiedy wznowić plan?';

  @override
  String get archiveChooseDate => 'Wybierz datę';

  @override
  String get archiveResumeTitle => 'Wznów plan';

  @override
  String archiveResumeBody(int days, String date) {
    return 'Te same posiłki na $days dni od $date. Plan pozostanie też w archiwum. Utworzymy nową listę zakupów. Bez generowania AI i bez wydawania punktów.';
  }

  @override
  String get archiveResume => 'Wznów';

  @override
  String get archiveResumed => 'Plan został wznowiony.';

  @override
  String get archiveResumeFailed =>
      'Nie udało się wznowić planu. Spróbuj ponownie.';

  @override
  String archiveDuration(int days) {
    return '$days dni';
  }

  @override
  String get archivePremiumHint =>
      'Z Premium zakończone plany pozostają w archiwum. Możesz je przeglądać i wznowić bez generowania przez AI.';

  @override
  String get archiveSeePremium => 'Zobacz Premium';

  @override
  String get archiveCompleted => 'Zakończone plany';

  @override
  String get archiveHint =>
      'Wznów ten sam zestaw posiłków od nowej daty. Nie używamy AI ani punktów Premium.';

  @override
  String get archiveEmpty =>
      'Nie masz jeszcze zakończonych planów. Po ostatnim dniu aktywny plan trafi tutaj.';

  @override
  String archivePlanTitle(int days) {
    return 'Plan na $days dni';
  }

  @override
  String get archivePreview => 'Podgląd';

  @override
  String get archiveResuming => 'Wznawianie…';

  @override
  String get automationTitle => 'Automatyczny tydzień';

  @override
  String get automationHeading => 'Plan gotowy, zanim zacznie się tydzień';

  @override
  String get automationHint =>
      'Co tydzień przygotujemy 7-dniowy plan na podstawie Twojego celu, preferencji i ulubionego sklepu.';

  @override
  String get automationGenerate => 'Generuj automatycznie';

  @override
  String get automationPremiumHint => 'Tylko podczas aktywnego Premium';

  @override
  String get automationWeekday => 'Dzień tygodnia';

  @override
  String get automationMonday => 'Poniedziałek';

  @override
  String get automationTuesday => 'Wtorek';

  @override
  String get automationWednesday => 'Środa';

  @override
  String get automationThursday => 'Czwartek';

  @override
  String get automationFriday => 'Piątek';

  @override
  String get automationSaturday => 'Sobota';

  @override
  String get automationSunday => 'Niedziela';

  @override
  String get automationHour => 'Godzina';

  @override
  String get automationCreateList => 'Utwórz też listę zakupów';

  @override
  String get automationLastPlan => 'Ostatni plan utworzony';

  @override
  String get automationSave => 'Zapisz ustawienia';

  @override
  String get automationRun => 'Wygeneruj teraz';

  @override
  String get automationEnabled => 'Automatyczny tydzień jest włączony.';

  @override
  String get automationDisabled => 'Automatyczny tydzień jest wyłączony.';

  @override
  String get automationReady =>
      'Plan jest gotowy. Sprawdź go w zakładce Start.';

  @override
  String get errorSignIn => 'Musisz być zalogowany, żeby to zrobić.';

  @override
  String get errorTooManyRequests =>
      'Zbyt wiele prób w krótkim czasie — spróbuj ponownie za chwilę.';

  @override
  String get errorUnavailable =>
      'Usługa jest chwilowo niedostępna. Spróbuj ponownie za chwilę.';

  @override
  String get errorServerTimeout =>
      'Serwer nie odpowiedział na czas. Spróbuj ponownie za chwilę.';

  @override
  String get errorServer =>
      'Coś poszło nie tak po naszej stronie. Spróbuj ponownie za chwilę.';

  @override
  String get errorOperationTimeout =>
      'Operacja trwała zbyt długo. Spróbuj ponownie za chwilę.';

  @override
  String get errorConnection =>
      'Nie udało się połączyć z serwerem. Sprawdź internet i spróbuj ponownie.';

  @override
  String get errorFormat =>
      'Nie udało się odczytać danych. Odśwież ekran i spróbuj ponownie.';

  @override
  String get automationRetry => 'Ponów';

  @override
  String get ingredientPreferencesTitle => 'Preferencje składników';

  @override
  String get ingredientPreferencesLimit =>
      'Możesz wybrać do 50 składników w każdej grupie.';

  @override
  String get ingredientPreferencesSavedMessage =>
      'Zapisano preferencje składników.';

  @override
  String get ingredientPreferencesUnsavedTitle => 'Niezapisane preferencje';

  @override
  String get ingredientPreferencesUnsavedBody =>
      'Masz niezapisane zmiany. Wrócić bez zapisywania?';

  @override
  String get ingredientPreferencesStay => 'Zostań';

  @override
  String get ingredientPreferencesDiscard => 'Wróć bez zapisu';

  @override
  String get ingredientPreferencesEmpty => 'Jeszcze nie wybrano składników.';

  @override
  String ingredientPreferencesRemove(String name) {
    return 'Usuń $name';
  }

  @override
  String get ingredientPreferencesRetry => 'Spróbuj ponownie';

  @override
  String get ingredientPreferencesHint =>
      'Uwzględnimy preferencje w jednym daniu dziennie, jeśli znajdziemy pasujący przepis. Alergie i dieta mają pierwszeństwo.';

  @override
  String get ingredientPreferencesLike => 'Lubię';

  @override
  String get ingredientPreferencesDislike => 'Nie lubię';

  @override
  String get ingredientPreferencesAddLike => 'Dodaj do: Lubię';

  @override
  String get ingredientPreferencesAddDislike => 'Dodaj do: Nie lubię';

  @override
  String get ingredientPreferencesSearch => 'Szukaj składnika';

  @override
  String get ingredientPreferencesMoveHint =>
      'Wybranie w drugiej grupie przenosi składnik.';

  @override
  String get ingredientPreferencesRetrySearch => 'Ponów wyszukiwanie';

  @override
  String get ingredientPreferencesNoResults => 'Brak składników o tej nazwie.';

  @override
  String ingredientPreferencesSaveError(String error) {
    return 'Nie zapisano: $error';
  }

  @override
  String get ingredientPreferencesSaving => 'Zapisywanie…';

  @override
  String get ingredientPreferencesSave => 'Zapisz preferencje';

  @override
  String get ingredientPreferencesSaved => 'Preferencje zapisane';

  @override
  String get ingredientPreferencesLocked =>
      'Wybierz składniki, które lubisz i których nie lubisz. Premium uwzględni je w jednym daniu dziennie, jeśli znajdziemy pasujący przepis.';

  @override
  String get ingredientPreferencesPremium => 'Zobacz Premium';

  @override
  String get blockedUsersTitle => 'Zablokowani użytkownicy';

  @override
  String get blockedUsersEmpty => 'Nie zablokowałeś jeszcze nikogo.';

  @override
  String get blockedUsersUnknown => 'Użytkownik';

  @override
  String get blockedUsersUnblock => 'Odblokuj';

  @override
  String blockedUsersUnblocked(String name) {
    return 'Odblokowano \"$name\". Znów zobaczysz jej/jego treści.';
  }

  @override
  String get calculatorTitle => 'Kalkulator zapotrzebowania kalorycznego';

  @override
  String get calculatorIntro =>
      'Podaj swoje dane, żeby obliczyć dzienne zapotrzebowanie kaloryczne (wzór Mifflin-St Jeor — ten sam standard, na którym opiera się m.in. kalkulator NFZ).';

  @override
  String get calculatorWeight => 'Waga (kg)';

  @override
  String get calculatorHeight => 'Wzrost (cm)';

  @override
  String get calculatorAge => 'Wiek (lata)';

  @override
  String get calculatorSex => 'Płeć';

  @override
  String get calculatorFemale => 'Kobieta';

  @override
  String get calculatorMale => 'Mężczyzna';

  @override
  String get calculatorActivity => 'Poziom aktywności fizycznej';

  @override
  String get calculatorSedentary => 'Siedzący tryb życia';

  @override
  String get calculatorSedentaryHint => 'Mało lub brak ćwiczeń';

  @override
  String get calculatorLight => 'Lekka aktywność';

  @override
  String get calculatorLightHint => 'Trening 1–3 dni/tydzień';

  @override
  String get calculatorModerate => 'Umiarkowana aktywność';

  @override
  String get calculatorModerateHint => 'Trening 3–5 dni/tydzień';

  @override
  String get calculatorActive => 'Duża aktywność';

  @override
  String get calculatorActiveHint => 'Trening 6–7 dni/tydzień';

  @override
  String get calculatorVeryActive => 'Bardzo duża aktywność';

  @override
  String get calculatorVeryActiveHint => 'Praca fizyczna + codzienny trening';

  @override
  String get calculatorNumbersRequired =>
      'Wypełnij wszystkie pola liczbami (waga, wzrost, wiek).';

  @override
  String get calculatorCalculate => 'Oblicz zapotrzebowanie';

  @override
  String get calculatorSaveFailed => 'Nie udało się zapisać celu.';

  @override
  String calculatorGoalSaved(int kcal) {
    return 'Cel zapisany: $kcal kcal/dzień';
  }

  @override
  String get calculatorChooseGoal => 'Wybierz swój cel';

  @override
  String get calculatorGoalHint =>
      'Dotknij kafelek, żeby go wybrać, albo dostrój suwakiem poniżej.';

  @override
  String get calculatorLoss => 'Redukcja';

  @override
  String get calculatorMaintenance => 'Utrzymanie';

  @override
  String get calculatorGain => 'Przyrost';

  @override
  String calculatorCustomGoal(int kcal) {
    return 'Własna wartość: $kcal kcal/dzień';
  }

  @override
  String get calculatorMacros => 'Orientacyjny podział makroskładników';

  @override
  String get calculatorProtein => 'Białko';

  @override
  String get calculatorFat => 'Tłuszcz';

  @override
  String get calculatorCarbs => 'Węgl.';

  @override
  String get calculatorSaveGoal => 'Zapisz jako mój cel';

  @override
  String get socialInviteTitle => 'Zaproś znajomego';

  @override
  String get socialIdentifier => 'Nazwa użytkownika lub e-mail';

  @override
  String get socialSend => 'Wyślij';

  @override
  String get socialInvitationSent => 'Zaproszenie zostało wysłane.';

  @override
  String get socialInvitationAccepted => 'Zaproszenie zostało przyjęte.';

  @override
  String get socialInvitationDeclined => 'Zaproszenie zostało odrzucone.';

  @override
  String get socialInvitationCancelled => 'Zaproszenie zostało anulowane.';

  @override
  String get socialFriends => 'Znajomi';

  @override
  String get socialInvite => 'Zaproś';

  @override
  String get socialRetry => 'Spróbuj ponownie';

  @override
  String get socialIncoming => 'Zaproszenia do Ciebie';

  @override
  String get socialYourFriends => 'Twoi znajomi';

  @override
  String get socialNoFriends =>
      'Nie masz jeszcze znajomych. Wyślij pierwsze zaproszenie.';

  @override
  String get socialFriendSubtitle => 'Przepisy i lista zakupów';

  @override
  String get socialOutgoing => 'Wysłane zaproszenia';

  @override
  String get socialAwaitingResponse => 'Oczekuje na odpowiedź';

  @override
  String get socialDecline => 'Odrzuć';

  @override
  String get socialAccept => 'Przyjmij';

  @override
  String get socialNoFriendRecipes =>
      'Ten znajomy nie ma jeszcze zapisanych przepisów.';

  @override
  String socialRecipeSummary(int minutes, String meal) {
    return '$minutes min • $meal';
  }

  @override
  String get socialNoFriendLists =>
      'Ten znajomy nie ma teraz aktywnej listy zakupów.';

  @override
  String get socialShareAccepted =>
      'Zaakceptowano — lista pojawi się jako udostępniona.';

  @override
  String get socialSharesTitle => 'Zaproszenia do list zakupów';

  @override
  String get socialNoPendingShares => 'Brak oczekujących zaproszeń.';

  @override
  String socialSharedListInvitation(String name) {
    return '$name udostępnił Ci listę zakupów';
  }

  @override
  String get socialSomeone => 'Ktoś';

  @override
  String get socialShareRespond => 'Dotknij, aby odpowiedzieć';

  @override
  String get socialShareAccept => 'Zaakceptuj';

  @override
  String get notificationsTitle => 'Powiadomienia';

  @override
  String get notificationsLoadFailed => 'Nie udało się załadować powiadomień';

  @override
  String get notificationsMarkAllFailed =>
      'Nie udało się oznaczyć wszystkich jako przeczytane';

  @override
  String get notificationsPlanEnded => 'Ten plan już się zakończył.';

  @override
  String get notificationsRecipeOpenFailed => 'Nie udało się otworzyć przepisu';

  @override
  String get notificationsJustNow => 'przed chwilą';

  @override
  String notificationsMinutes(int count) {
    return '$count min temu';
  }

  @override
  String notificationsHours(int count) {
    return '$count godz. temu';
  }

  @override
  String notificationsDays(int count) {
    return '$count dni temu';
  }

  @override
  String get notificationsMarkAll => 'Oznacz wszystkie';

  @override
  String get notificationsEmpty => 'Brak powiadomień';

  @override
  String get releasePromptTitle => 'Dostępna nowa wersja';

  @override
  String get releasePromptRequired =>
      'Ta wersja aplikacji nie jest już obsługiwana. Zaktualizuj ją, aby korzystać dalej.';

  @override
  String get releasePromptStoreError => 'Nie udało się otworzyć sklepu.';

  @override
  String get releasePromptChanges =>
      '• Łączymy powtarzające się składniki na liście zakupów i poprawnie przeliczamy miary.\n• Jajka i znane produkty sztukowe pokazujemy z przeliczeniem na sztuki.\n• Zamienniki katalogowe są wyraźnie oddzielone od ofert sklepu.\n• Poprawiliśmy tłumaczenia i dopasowanie przycisków w Dzienniku.';

  @override
  String get releasePromptApple => 'Otwórz App Store';

  @override
  String get releasePromptGoogle => 'Otwórz Google Play';

  @override
  String get releasePromptLater => 'Później';

  @override
  String get pantryAddProduct => 'Dodaj produkt';

  @override
  String get pantryEmpty =>
      'Spiżarnia jest pusta. Dodaj produkty, które masz w domu, żeby móc szybko sprawdzić, co z nich ugotować.';

  @override
  String get pantryEnterAmount => 'Dotknij, aby wpisać ilość';

  @override
  String get pantryRemove => 'Usuń ze spiżarni';

  @override
  String get pantryScanBarcode => 'Skanuj kod kreskowy';

  @override
  String get pantryScanMany => 'Skanuj wiele produktów';

  @override
  String get pantrySearchHint => 'Szukaj produktu...';

  @override
  String get pantrySearchStart => 'Wpisz nazwę produktu.';

  @override
  String get pantrySearchEmpty => 'Brak wyników.';

  @override
  String pantrySaved(String name) {
    return 'Dodano \"$name\" do spiżarni.';
  }

  @override
  String get matchTitle => 'Co ugotować z tego, co mam';

  @override
  String get matchPremium => 'Funkcja Premium';

  @override
  String get matchPremiumBody =>
      'Dopasowywanie przepisów do tego, co masz w spiżarni, jest dostępne dla kont z aktywną subskrypcją Premium.';

  @override
  String get matchSeePremium => 'Zobacz Premium';

  @override
  String get matchSelectOne => 'Zaznacz przynajmniej jeden składnik.';

  @override
  String get matchEmptyPantry =>
      'Twoja spiżarnia jest pusta. Dodaj do niej produkty, które masz w domu, żeby dopasować przepisy.';

  @override
  String get matchAddPantry => 'Dodaj produkt do spiżarni';

  @override
  String matchSelected(int selected, int total) {
    return 'Zaznaczono $selected z $total';
  }

  @override
  String get matchDeselect => 'Odznacz wszystko';

  @override
  String get matchSelectAll => 'Zaznacz wszystko';

  @override
  String matchSearch(int count) {
    return 'Szukaj przepisów ($count)';
  }

  @override
  String get matchGenerate => 'Wygeneruj nowy przepis przez AI';

  @override
  String get matchResultsTitle => 'Dopasowane przepisy';

  @override
  String get matchResultsEmpty =>
      'Nie znaleziono żadnego przepisu w bazie pasującego do wybranych składników. Możesz zamiast tego wygenerować nowy przepis przez AI.';

  @override
  String get matchOtherAi => 'Żaden nie pasuje? Wygeneruj przez AI';

  @override
  String get matchReady => 'Możesz ugotować teraz';

  @override
  String matchMissing(String ingredients) {
    return 'Brakuje: $ingredients';
  }

  @override
  String matchSelectPrompt(String ingredients) {
    return 'Wygeneruj przepis na danie wykorzystujące głównie te składniki, które mam w domu: $ingredients. Możesz dodać maksymalnie 2–3 powszechnie dostępne składniki, na przykład sól, przyprawy lub oliwę.';
  }

  @override
  String matchResultsPrompt(String ingredients) {
    return 'Wygeneruj przepis na danie wykorzystujące GŁÓWNIE te składniki, które mam w domu: $ingredients. Możesz dodać maksymalnie 2-3 dodatkowe, powszechnie dostępne składniki (np. sól, przyprawy, oliwę), jeśli są potrzebne.';
  }

  @override
  String get leaderTitle => 'Ranking autorów przepisów';

  @override
  String get leaderWeek => 'Ten tydzień';

  @override
  String get leaderAll => 'Cały czas';

  @override
  String get leaderEmptyWeek =>
      'W tym tygodniu nikt jeszcze nie dodał\nzaakceptowanego przepisu. Bądź pierwszy!';

  @override
  String get leaderEmptyAll =>
      'Jeszcze nikt nie dodał zaakceptowanego przepisu\ndo wspólnego katalogu.';

  @override
  String leaderCount(int count, String noun) {
    return '$count $noun';
  }

  @override
  String get leaderRecipeSingular => 'przepis';

  @override
  String get leaderRecipeFew => 'przepisy';

  @override
  String get leaderRecipeMany => 'przepisów';

  @override
  String get adGateTitle => 'Obejrzyj krótką reklamę';

  @override
  String get adGateBody =>
      'Żeby przejść do Dziennika, obejrzyj krótką reklamę wideo do końca. To ograniczenie nie dotyczy kont Premium — tam Dziennik jest zawsze bez reklam.';

  @override
  String get adGateFailed =>
      'Nie udało się załadować reklamy. Sprawdź połączenie z internetem i spróbuj ponownie.';

  @override
  String get adGateLoading => 'Ładowanie reklamy...';

  @override
  String get adGateWatch => 'Obejrzyj reklamę';

  @override
  String get adGateLater => 'Nie teraz';

  @override
  String get promosTitle => 'Promocje';

  @override
  String get promosAll => 'Wszystkie';

  @override
  String get promosFailed => 'Nie udało się załadować promocji.';

  @override
  String get promosLoyalty => 'Wymaga karty lojalnościowej';

  @override
  String get promosEmpty => 'Brak aktywnych promocji w tej chwili.';

  @override
  String get statsTitle => 'Statystyki';

  @override
  String get statsWeight => 'Zmiana wagi';

  @override
  String get statsWeightEmpty => 'Dodaj co najmniej jeden pomiar w profilu.';

  @override
  String get statsAverageCalories => 'Średnio kcal';

  @override
  String get statsHydration => 'Nawodnienie';

  @override
  String get statsFavorite => 'Ulubiony posiłek';

  @override
  String get statsNoData => 'Brak danych';

  @override
  String get statsDailyCalories => 'Kalorie dziennie';

  @override
  String get statsCaloriesEmpty =>
      'Dodaj posiłki w Dzienniku, aby zobaczyć wykres.';

  @override
  String get statsCalories => 'Kalorie';

  @override
  String get statsDailyMacros => 'Makroskładniki dziennie';

  @override
  String get statsMacrosEmpty =>
      'Makroskładniki pojawią się po dodaniu posiłków.';

  @override
  String get statsProtein => 'Białko';

  @override
  String get statsFat => 'Tłuszcze';

  @override
  String get statsCarbs => 'Węglowodany';

  @override
  String get statsDailyWater => 'Nawodnienie dziennie';

  @override
  String get statsWaterEmpty =>
      'Zapisuj wodę w Dzienniku, aby zobaczyć wykres.';

  @override
  String get statsWater => 'Woda';

  @override
  String get statsRecentDays => 'Ostatnie zapisane dni';

  @override
  String get statsRecentEmpty =>
      'Zapisane posiłki i nawodnienie pojawią się tutaj.';

  @override
  String get statsWeekly => 'Wnioski z ostatnich 7 dni';

  @override
  String get statsPremiumTitle => 'Pełny raport w Premium';

  @override
  String get statsPremiumBody =>
      'Odblokuj analizę kalorii, nawodnienia i zmian wagi z konkretnymi wnioskami na każdy tydzień.';

  @override
  String get statsPremiumAction => 'Zobacz pełny raport';

  @override
  String statsDailyMacroLine(
    String kcal,
    String protein,
    String fat,
    String carbs,
  ) {
    return '$kcal kcal  •  B $protein g  •  T $fat g  •  W $carbs g';
  }

  @override
  String statsWaterLine(int amount) {
    return 'Woda: $amount ml';
  }

  @override
  String statsMaximum(String amount, String unit) {
    return 'Maksimum: $amount $unit';
  }

  @override
  String insightRegularity(int count) {
    return 'Regularność: $count z 7 dni';
  }

  @override
  String get insightEnough =>
      'Masz już wystarczająco dużo danych, aby porównywać tygodnie.';

  @override
  String insightMoreDays(int count) {
    return 'Uzupełnij jeszcze $count dni, aby raport był dokładniejszy.';
  }

  @override
  String insightCalories(int count) {
    return 'Średnio $count kcal dziennie';
  }

  @override
  String get insightCaloriesDetail =>
      'Porównuj średnią tydzień do tygodnia, zamiast oceniać pojedynczy dzień.';

  @override
  String get insightWaterMissing => 'Brakuje danych o nawodnieniu';

  @override
  String insightWaterAverage(int amount) {
    return 'Średnio $amount ml wody';
  }

  @override
  String get insightWaterEveryDay =>
      'Nawodnienie zostało zapisane każdego dnia tego tygodnia.';

  @override
  String insightWaterDays(int count) {
    return 'Zapisano nawodnienie w $count z 7 dni.';
  }

  @override
  String get insightWeightStable => 'Waga bez większej zmiany';

  @override
  String insightWeightChange(String amount) {
    return 'Zmiana wagi $amount kg';
  }

  @override
  String get insightWeightDetail =>
      'Porównanie pierwszego i ostatniego pomiaru z ostatnich 7 dni.';

  @override
  String get cookingTipsTitle => 'Porady kulinarne';

  @override
  String get splashSubtitle => 'Planuj posiłki mądrze i oszczędzaj';

  @override
  String get onboardingStoresEmpty =>
      'Nie znaleziono sklepów. Spróbuj ponownie.';

  @override
  String get authCaptchaUnavailable =>
      'Nie udało się wczytać weryfikacji. Sprawdź połączenie.';

  @override
  String get authCaptchaRetry => 'Ponów';

  @override
  String get authCaptchaContinue => 'Kontynuuj mimo to';

  @override
  String get authCaptchaRefresh => 'Odśwież weryfikację';

  @override
  String get adminProductsTitle => 'Zgłoszone produkty';

  @override
  String get adminProductsEmpty =>
      'Brak produktów oczekujących na sprawdzenie.';

  @override
  String get adminProductsRefresh => 'Odśwież zgłoszenia';

  @override
  String get adminProductApproved => 'Produkt dodany do katalogu';

  @override
  String get adminProductRejected => 'Produkt odrzucony';

  @override
  String get adminNoNutrition => 'Bez wartości odżywczych';

  @override
  String adminProductNutrition(
    String kcal,
    String protein,
    String fat,
    String carbs,
  ) {
    return 'Na 100 g: $kcal kcal · B $protein · T $fat · W $carbs';
  }

  @override
  String get adminReject => 'Odrzuć';

  @override
  String get adminApprove => 'Akceptuj';

  @override
  String get adminAllRecipesTitle => 'Wszystkie przepisy użytkowników';

  @override
  String get adminRecipesEmpty => 'Brak przepisów dodanych przez użytkowników.';

  @override
  String get adminShowMore => 'Pokaż więcej';

  @override
  String get adminPublic => 'Publiczny';

  @override
  String get adminPending => 'Oczekuje';

  @override
  String get adminRejected => 'Odrzucony';

  @override
  String get adminPrivate => 'Prywatny';

  @override
  String get adminUnknownAuthor => 'Nieznany autor';

  @override
  String get adminDeleteRecipeTooltip => 'Usuń przepis';

  @override
  String get adminDeleteRecipeTitle => 'Usunąć przepis?';

  @override
  String adminDeleteRecipeBody(String name) {
    return 'Usuniesz \"$name\" oraz jego komentarze i powiązania (listy zakupów, plany posiłków innych użytkowników, którzy go używali). Tej operacji nie da się cofnąć.';
  }

  @override
  String get adminRecipeFallback => 'ten przepis';

  @override
  String get adminUsersTitle => 'Użytkownicy';

  @override
  String get adminUsersSearch => 'Szukaj po e-mailu lub nazwie…';

  @override
  String get adminUsersOnlyBanned => 'Tylko zablokowani';

  @override
  String get adminUsersEmpty => 'Brak wyników.';

  @override
  String get adminUsersUnnamed => 'Bez nazwy';

  @override
  String adminUsersVersion(String version) {
    return 'Wersja: $version';
  }

  @override
  String adminUsersReason(String reason) {
    return 'Powód: $reason';
  }

  @override
  String adminUsersBanTitle(String name) {
    return 'Zablokować $name?';
  }

  @override
  String get adminUsersBanBody =>
      'Konto straci dostęp do aplikacji natychmiast — również jeśli jest właśnie zalogowane. Dane nie zostaną usunięte, blokadę można cofnąć.';

  @override
  String get adminUsersReasonLabel => 'Powód (widoczny dla użytkownika)';

  @override
  String get adminUsersBan => 'Zablokuj';

  @override
  String get adminUsersUnban => 'Odblokuj';

  @override
  String get adminUsersBanned => 'Konto zablokowane';

  @override
  String get adminUsersUnbanned => 'Konto odblokowane';

  @override
  String get adminCommentsTitle => 'Komentarze';

  @override
  String get adminCommentsSearch => 'Szukaj w treści, autorze lub przepisie…';

  @override
  String get adminCommentsEmpty => 'Brak komentarzy.';

  @override
  String adminCommentsRecipe(String name) {
    return 'pod: $name';
  }

  @override
  String get adminCommentsPhotoOnly => '(samo zdjęcie)';

  @override
  String get adminCommentsEmptyText => '(pusty)';

  @override
  String get adminCommentsHasPhoto => 'zawiera zdjęcie';

  @override
  String get adminCommentsDelete => 'Usuń komentarz';

  @override
  String get adminCommentsDeleteTitle => 'Usunąć komentarz?';

  @override
  String get adminCommentsDeleteBody => 'Tej operacji nie da się cofnąć.';

  @override
  String get adminCommentsDeleted => 'Komentarz usunięty';

  @override
  String get adminPhotosTitle => 'Zdjęcia do akceptacji';

  @override
  String get adminPhotosEmpty => 'Brak zdjęć oczekujących na akceptację.';

  @override
  String get adminPhotosApproved => 'Zdjęcie zaakceptowane';

  @override
  String get adminPhotosRejected => 'Zdjęcie odrzucone';

  @override
  String get adminPhotosRecipe => 'Przepis';

  @override
  String get adminPhotosUnknownSubmitter => 'nieznany';

  @override
  String adminPhotosSubmittedBy(String name) {
    return 'Zgłosił: $name';
  }

  @override
  String get adminPhotosReplaceWarning =>
      'Uwaga: ten przepis ma już zdjęcie — akceptacja je zastąpi.';

  @override
  String get adminPhotosLoadError => 'Nie udało się wczytać zdjęcia';

  @override
  String get adminPhotosApprove => 'Zaakceptuj';

  @override
  String get adminMainTitle => 'Panel administratora';

  @override
  String adminMainBroadcastSent(String count) {
    return 'Wysłano do $count użytkowników.';
  }

  @override
  String get adminMainReportsTitle => 'Zgłoszenia treści';

  @override
  String get adminMainReportsHelp =>
      'Przepisy i komentarze zgłoszone przez użytkowników jako spam, nękanie albo inne naruszenie regulaminu.';

  @override
  String get adminMainReportsEmpty => 'Brak nierozpatrzonych zgłoszeń.';

  @override
  String get adminMainRecipeType => 'Przepis';

  @override
  String get adminMainCommentType => 'Komentarz';

  @override
  String adminMainReportDetails(String details) {
    return 'Szczegóły od zgłaszającego: $details';
  }

  @override
  String adminMainAuthor(String email) {
    return 'Autor: $email';
  }

  @override
  String adminMainReporter(String email) {
    return 'Zgłosił: $email';
  }

  @override
  String get adminMainDismiss => 'Odrzuć zgłoszenie';

  @override
  String get adminMainDeleteContent => 'Usuń treść';

  @override
  String get adminMainResolve => 'Oznacz jako rozpatrzone';

  @override
  String get adminMainBroadcastTitle => 'Wyślij powiadomienie do wszystkich';

  @override
  String get adminMainBroadcastHelp =>
      'Trafi do dzwoneczka powiadomień KAŻDEGO użytkownika aplikacji — nieodwracalne, sprawdź treść przed wysłaniem.';

  @override
  String get adminMainBroadcastHint => 'Treść powiadomienia...';

  @override
  String get adminMainBroadcastSend => 'Wyślij do wszystkich';

  @override
  String get adminMainPromotionsLoadFailed =>
      'Nie udało się wczytać listy oczekujących promocji.';

  @override
  String adminMainScanSummary(String found, String queued) {
    return 'Znaleziono $found, zakolejkowano $queued do akceptacji.';
  }

  @override
  String get adminMainScanPending =>
      'Skanowanie trwa na serwerze. Możesz wyjść z panelu; wyniki pojawią się w kolejce do akceptacji.';

  @override
  String get adminMainPromotionApproved => 'Promocja zaakceptowana';

  @override
  String get adminMainPromotionRejected => 'Promocja odrzucona';

  @override
  String get adminMainActionFailed => 'Nie udało się wykonać akcji';

  @override
  String get adminMainRecipesLoadFailed =>
      'Nie udało się wczytać listy oczekujących przepisów.';

  @override
  String get adminMainReportsLoadFailed => 'Nie udało się wczytać zgłoszeń.';

  @override
  String get adminMainDeleteContentTitle => 'Usunąć zgłoszoną treść?';

  @override
  String get adminMainDeleteContentHelp =>
      'Komentarz albo przepis zostanie trwale usunięty, a zgłoszenie zamknięte. Tej operacji nie da się cofnąć.';

  @override
  String get adminMainContentDeleted => 'Treść usunięta, zgłoszenie zamknięte';

  @override
  String get adminMainReportResolved => 'Zgłoszenie oznaczone jako rozpatrzone';

  @override
  String get adminMainReportDismissed => 'Zgłoszenie odrzucone';

  @override
  String get adminMainRecipeApproved => 'Przepis zaakceptowany';

  @override
  String get adminMainRecipeRejected => 'Przepis odrzucony';

  @override
  String get adminMainRecipesTitle => 'Przepisy oczekujące na akceptację';

  @override
  String get adminMainRecipesHelp =>
      'Przepisy zgłoszone przez użytkowników Premium do wspólnego, publicznego katalogu.';

  @override
  String get adminMainRecipesEmpty =>
      'Brak przepisów czekających na akceptację.';

  @override
  String adminMainRecipeMeta(
    String mealType,
    String servings,
    String difficulty,
  ) {
    return '$mealType • $servings porcji • $difficulty';
  }

  @override
  String get adminMainRecipePreview =>
      'Dotknij, aby sprawdzić składniki, instrukcję, zdjęcie i makro';

  @override
  String get adminMainApprove => 'Zaakceptuj';

  @override
  String get adminMainAiTitle => 'Stan usługi AI';

  @override
  String get adminMainAiHelp =>
      'Sprawdza, czy klucz Gemini działa i czy limit tokenów/zapytań nie został wyczerpany — dla każdego modelu z osobna.';

  @override
  String get adminMainAiCheck => 'Sprawdź stan AI';

  @override
  String get adminMainAiKeyMissing => 'Klucz API nie jest skonfigurowany.';

  @override
  String get adminMainScanTitle => 'Skanuj gazetki promocyjne';

  @override
  String get adminMainScanHelp =>
      'AI przeszuka internet w poszukiwaniu aktualnej gazetki danego sklepu i rozpozna z niej promocje. Wynik trafi poniżej do akceptacji — nic nie zmienia się automatycznie.';

  @override
  String get adminMainUkScanUnavailable =>
      'Brytyjskie źródła promocji są w przygotowaniu. Skaner polskich gazetek nie tworzy promocji w GBP.';

  @override
  String adminMainScanShop(String store) {
    return 'Skanuj $store';
  }

  @override
  String adminMainScanningShop(String store) {
    return 'Skanowanie $store trwa w tle. Możesz opuścić panel.';
  }

  @override
  String get adminMainPendingTitle => 'Oczekujące na akceptację';

  @override
  String get adminMainPromotionsEmpty =>
      'Brak promocji czekających na akceptację.';

  @override
  String get adminMainProductsNav => 'Produkty';

  @override
  String get adminMainUserRecipesNav => 'Przepisy użytkowników';

  @override
  String get campaignTitle => 'Kampanie';

  @override
  String get campaignRequired =>
      'Uzupełnij nazwę, daty, konfigurację oferty sklepu i odbiorcę.';

  @override
  String get campaignConfirmGoogle => 'Potwierdź ofertę w Google Play';

  @override
  String get campaignConfirmApple => 'Potwierdź ofertę w App Store';

  @override
  String campaignConfirmPoints(String store) {
    return 'Włącz tylko po ustawieniu czasowej ceny tego pakietu punktów w $store dla wszystkich użytkowników. Cena w aplikacji pochodzi bezpośrednio ze sklepu.';
  }

  @override
  String get campaignConfirmPremium =>
      'Włącz tylko wtedy, gdy wskazana oferta sklepu jest aktywna, ma dokładnie ten rabat i obejmuje właściwy produkt. Aplikacja nie zmienia ceny samodzielnie.';

  @override
  String get campaignConfirm => 'Potwierdzam';

  @override
  String get campaignDeleteTitle => 'Usunąć kampanię?';

  @override
  String campaignDeleteBody(String name) {
    return 'Kampania „$name” zniknie z panelu. Ofertę w sklepie trzeba wyłączyć osobno.';
  }

  @override
  String get campaignMarketGb => 'Rynek: Wielka Brytania • GBP • Europe/London';

  @override
  String get campaignMarketPl => 'Rynek: Polska • PLN • Europe/Warsaw';

  @override
  String get campaignHeading => 'Promocja Premium i punktów';

  @override
  String get campaignHelp =>
      'Szarfy pojawiają się na ikonkach w panelu Premium. Subskrypcja iOS otwiera kod ofertowy Apple, a Android wybiera ofertę Google Play. Dla punktów ustaw czasową cenę produktu w odpowiednim sklepie dla wszystkich.';

  @override
  String get campaignName => 'Nazwa kampanii';

  @override
  String get campaignStore => 'Sklep';

  @override
  String get campaignOffer => 'Oferta';

  @override
  String get campaignSubscription => 'Subskrypcja Premium';

  @override
  String get campaignPoints => 'Punkty premium';

  @override
  String get campaignProduct => 'Pakiet objęty ofertą';

  @override
  String get campaignDiscount => 'Rabat';

  @override
  String get campaignAudience => 'Odbiorcy';

  @override
  String get campaignEveryone => 'Wszyscy';

  @override
  String get campaignOneUser => 'Jeden użytkownik';

  @override
  String get campaignEmail => 'E-mail użytkownika';

  @override
  String get campaignDates => 'Wybierz termin';

  @override
  String get campaignAppleUrl => 'Link do kodu ofertowego Apple';

  @override
  String get campaignAppleUrlHelp =>
      'Link apps.apple.com/redeem?ctx=offercodes…';

  @override
  String get campaignBasePlan => 'Google Play: ID planu bazowego';

  @override
  String get campaignAndroidOffer => 'Google Play: ID oferty';

  @override
  String campaignPointsHelp(String store) {
    return 'Najpierw zaplanuj czasową obniżkę ceny tego pakietu punktów w $store. Kampania pokazuje szarfę, ale kwotę zawsze pobiera bezpośrednio ze sklepu.';
  }

  @override
  String get campaignSaving => 'Zapisuję…';

  @override
  String get campaignCreate => 'Utwórz kampanię (wyłączoną)';

  @override
  String get campaignSaved => 'Zapisane kampanie';

  @override
  String get campaignEmpty => 'Brak kampanii.';

  @override
  String get campaignActive => 'Aktywna';

  @override
  String get campaignDeleteTooltip => 'Usuń kampanię';

  @override
  String get adminMarketLabel => 'Rynek katalogu';

  @override
  String get adminMarketBusy => 'Poczekaj na zakończenie bieżącej operacji.';

  @override
  String get adminMarketHelp => 'Zmienia widok danych, nie kraj Twojego konta.';

  @override
  String get adminMarketPl => 'Polska';

  @override
  String get adminMarketGb => 'Wielka Brytania';

  @override
  String get approvalRecipePending =>
      'Ten przepis czeka na Twoją akceptację do wspólnego katalogu';

  @override
  String get approvalRecipeApprove => 'Zaakceptuj';

  @override
  String get approvalRecipeApproved => 'Przepis zaakceptowany';

  @override
  String get approvalRecipeRejected => 'Przepis odrzucony';

  @override
  String get approvalRecipeFailed => 'Nie udało się wykonać akcji';

  @override
  String get shoppingAddQueryHint => 'Wpisz dowolną pozycję…';

  @override
  String get shoppingAddCustom => 'Dodaj wpisaną pozycję';

  @override
  String get shoppingAddMatches =>
      'Pasujące produkty z bazy i wcześniejszych skanów';

  @override
  String get shoppingAddMinimumQuery =>
      'Wpisz co najmniej 2 znaki, żeby wyszukać produkt.';

  @override
  String get shoppingAddNoResults => 'Nie znaleziono produktu o takiej nazwie.';

  @override
  String shoppingAddSuccess(String name) {
    return 'Dodano: $name';
  }

  @override
  String get shoppingAddCustomFailed => 'Nie udało się dodać pozycji';

  @override
  String get shoppingAddProductFailed => 'Nie udało się dodać produktu';

  @override
  String get shoppingAddProductFallback => 'Produkt';

  @override
  String get shoppingAddCatalogSource => 'Katalog aplikacji';

  @override
  String get shoppingAddCacheSource => 'Wcześniej zeskanowany';

  @override
  String exportListHeading(String store) {
    return 'Moja lista zakupów: $store';
  }

  @override
  String exportListSubject(String store) {
    return 'Lista zakupów - $store';
  }

  @override
  String get exportListTitle => 'Eksportuj listę';

  @override
  String get exportListCopy => 'Kopiuj do schowka';

  @override
  String get exportListCopied => 'Skopiowano do schowka!';

  @override
  String exportListOpenApp(String name) {
    return 'Otwórz $name';
  }

  @override
  String get exportListAppMissing => 'Aplikacja nie jest zainstalowana.';

  @override
  String get exportListAppFailed => 'Nie udało się otworzyć aplikacji.';

  @override
  String get exportListComingSoon => 'Wkrótce';

  @override
  String get diarySignInView => 'Musisz być zalogowany, aby zobaczyć dziennik.';

  @override
  String get diarySignInAdd => 'Musisz być zalogowany, aby dodać wpis.';

  @override
  String get authStoredSessionFailed =>
      'Nie udało się odtworzyć zapisanej sesji. Spróbuj zalogować się ponownie.';

  @override
  String authGoogleNativeFailed(Object code) {
    return 'Nie udało się zalogować przez Google ($code). Spróbuj ponownie.';
  }

  @override
  String get authGoogleTokenUnavailable =>
      'Nie udało się uzyskać tokenu tożsamości Google.';

  @override
  String get authAppleNativeFailed =>
      'Nie udało się zalogować przez Apple. Spróbuj ponownie.';

  @override
  String get authAppleTokenUnavailable =>
      'Nie udało się uzyskać tokenu tożsamości Apple.';

  @override
  String get shoppingLimitTitle => 'Kolejne zakupy? Z Premium bez limitu';

  @override
  String get shoppingLimitDescription =>
      'Wykorzystano już jedną bezpłatną listę w tym tygodniu. Z Premium twórz osobne listy na przepisy, sklepy i kolejne zakupy — kiedy potrzebujesz.';

  @override
  String get shoppingLimitSeePremium => 'Zobacz Premium';

  @override
  String get shoppingLimitBack => 'Wróć do mojej listy';

  @override
  String get shoppingLimitShort =>
      'Tygodniowy limit list został wykorzystany. Z Premium tworzysz kolejne bez limitu.';
}
