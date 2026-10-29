import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_pl.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('en', 'GB'),
    Locale('pl'),
  ];

  /// No description provided for @scanPantryAmountHint.
  ///
  /// In pl, this message translates to:
  /// **'Wybierz ilość w gramach lub mililitrach'**
  String get scanPantryAmountHint;

  /// No description provided for @foodEntryTitle.
  ///
  /// In pl, this message translates to:
  /// **'Dodaj posiłek'**
  String get foodEntryTitle;

  /// No description provided for @foodEntryFromPlan.
  ///
  /// In pl, this message translates to:
  /// **'Z planu'**
  String get foodEntryFromPlan;

  /// No description provided for @foodEntryFromRecipes.
  ///
  /// In pl, this message translates to:
  /// **'Z przepisów'**
  String get foodEntryFromRecipes;

  /// No description provided for @foodEntryProducts.
  ///
  /// In pl, this message translates to:
  /// **'Produkty'**
  String get foodEntryProducts;

  /// No description provided for @foodEntryServingsQuestion.
  ///
  /// In pl, this message translates to:
  /// **'Ile porcji zjadłeś/-aś?'**
  String get foodEntryServingsQuestion;

  /// No description provided for @foodEntryMealFailed.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się dodać posiłku'**
  String get foodEntryMealFailed;

  /// No description provided for @foodEntryProductFailed.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się dodać produktu'**
  String get foodEntryProductFailed;

  /// No description provided for @foodEntryMealType.
  ///
  /// In pl, this message translates to:
  /// **'Rodzaj posiłku'**
  String get foodEntryMealType;

  /// No description provided for @foodEntryAddDiary.
  ///
  /// In pl, this message translates to:
  /// **'Dodaj do dziennika'**
  String get foodEntryAddDiary;

  /// No description provided for @foodEntryNoPlan.
  ///
  /// In pl, this message translates to:
  /// **'Nie masz jeszcze aktywnego planu posiłków.\nUtwórz plan w zakładce \"Start\", żeby móc\nlogować z niego posiłki jednym dotknięciem.'**
  String get foodEntryNoPlan;

  /// No description provided for @foodEntryNoPlannedMeals.
  ///
  /// In pl, this message translates to:
  /// **'Brak zaplanowanych posiłków na wybrany dzień.'**
  String get foodEntryNoPlannedMeals;

  /// No description provided for @foodEntryRecipesFailed.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się załadować przepisów'**
  String get foodEntryRecipesFailed;

  /// No description provided for @foodEntryRecipeSearch.
  ///
  /// In pl, this message translates to:
  /// **'Szukaj przepisu...'**
  String get foodEntryRecipeSearch;

  /// No description provided for @foodEntryNoResults.
  ///
  /// In pl, this message translates to:
  /// **'Brak wyników.'**
  String get foodEntryNoResults;

  /// No description provided for @foodEntryServings.
  ///
  /// In pl, this message translates to:
  /// **'Liczba porcji'**
  String get foodEntryServings;

  /// No description provided for @foodEntryAdjustIngredients.
  ///
  /// In pl, this message translates to:
  /// **'Dopasuj składniki'**
  String get foodEntryAdjustIngredients;

  /// No description provided for @foodEntryRepeatFailed.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się powtórzyć wpisu'**
  String get foodEntryRepeatFailed;

  /// No description provided for @foodEntryRepeat.
  ///
  /// In pl, this message translates to:
  /// **'Dodaj ponownie'**
  String get foodEntryRepeat;

  /// No description provided for @foodEntryMissingProduct.
  ///
  /// In pl, this message translates to:
  /// **'Nie ma produktu? Dodaj go do bazy'**
  String get foodEntryMissingProduct;

  /// No description provided for @foodEntrySaveFailed.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się dodać wpisu'**
  String get foodEntrySaveFailed;

  /// No description provided for @foodEntryChooseCatalogue.
  ///
  /// In pl, this message translates to:
  /// **'Wybierz z katalogu'**
  String get foodEntryChooseCatalogue;

  /// No description provided for @foodEntryProductName.
  ///
  /// In pl, this message translates to:
  /// **'Nazwa produktu / dania'**
  String get foodEntryProductName;

  /// No description provided for @foodEntryNameHint.
  ///
  /// In pl, this message translates to:
  /// **'Wpisz nazwę lub wybierz podpowiedź'**
  String get foodEntryNameHint;

  /// No description provided for @foodEntryNameRequired.
  ///
  /// In pl, this message translates to:
  /// **'Podaj nazwę'**
  String get foodEntryNameRequired;

  /// No description provided for @foodEntryPortion.
  ///
  /// In pl, this message translates to:
  /// **'Porcja (g/ml, opcjonalnie)'**
  String get foodEntryPortion;

  /// No description provided for @foodEntryCalories.
  ///
  /// In pl, this message translates to:
  /// **'Kalorie (kcal)'**
  String get foodEntryCalories;

  /// No description provided for @foodEntryRequired.
  ///
  /// In pl, this message translates to:
  /// **'Wymagane'**
  String get foodEntryRequired;

  /// No description provided for @foodEntryProtein.
  ///
  /// In pl, this message translates to:
  /// **'Białko (g)'**
  String get foodEntryProtein;

  /// No description provided for @foodEntryCarbs.
  ///
  /// In pl, this message translates to:
  /// **'Węgle (g)'**
  String get foodEntryCarbs;

  /// No description provided for @foodEntryFat.
  ///
  /// In pl, this message translates to:
  /// **'Tłuszcz (g)'**
  String get foodEntryFat;

  /// No description provided for @foodEntrySave.
  ///
  /// In pl, this message translates to:
  /// **'Zapisz do dziennika'**
  String get foodEntrySave;

  /// No description provided for @foodEntryInvalidNumber.
  ///
  /// In pl, this message translates to:
  /// **'Podaj prawidłową, nieujemną liczbę.'**
  String get foodEntryInvalidNumber;

  /// No description provided for @foodEntryInvalidPortion.
  ///
  /// In pl, this message translates to:
  /// **'Podaj ilość większą od 0 (maks. 1000000).'**
  String get foodEntryInvalidPortion;

  /// No description provided for @scanZoomUnavailable.
  ///
  /// In pl, this message translates to:
  /// **'Ten aparat nie obsługuje przybliżenia.'**
  String get scanZoomUnavailable;

  /// No description provided for @scanZoomHint.
  ///
  /// In pl, this message translates to:
  /// **'Przybliż kod przyciskiem 2× lub odsuń telefon.'**
  String get scanZoomHint;

  /// No description provided for @scanLensFailed.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się przełączyć obiektywu.'**
  String get scanLensFailed;

  /// No description provided for @scanEnterCode.
  ///
  /// In pl, this message translates to:
  /// **'Wpisz kod kreskowy'**
  String get scanEnterCode;

  /// No description provided for @scanCodeHint.
  ///
  /// In pl, this message translates to:
  /// **'8–14 cyfr'**
  String get scanCodeHint;

  /// No description provided for @scanBatchCodeHint.
  ///
  /// In pl, this message translates to:
  /// **'8, 12, 13 lub 14 cyfr'**
  String get scanBatchCodeHint;

  /// No description provided for @scanSearch.
  ///
  /// In pl, this message translates to:
  /// **'Wyszukaj'**
  String get scanSearch;

  /// No description provided for @scanCodeInvalidLength.
  ///
  /// In pl, this message translates to:
  /// **'Kod musi zawierać od 8 do 14 cyfr.'**
  String get scanCodeInvalidLength;

  /// No description provided for @scanCodeInvalid.
  ///
  /// In pl, this message translates to:
  /// **'Kod jest nieprawidłowy. Sprawdź cyfry.'**
  String get scanCodeInvalid;

  /// No description provided for @scanDuplicate.
  ///
  /// In pl, this message translates to:
  /// **'Ten produkt jest już w tej serii.'**
  String get scanDuplicate;

  /// No description provided for @scanGuide.
  ///
  /// In pl, this message translates to:
  /// **'Skieruj aparat na kod. Dotknij obrazu, aby ustawić ostrość.'**
  String get scanGuide;

  /// No description provided for @scanNormal.
  ///
  /// In pl, this message translates to:
  /// **'Zwykły'**
  String get scanNormal;

  /// No description provided for @scanCloseUp.
  ///
  /// In pl, this message translates to:
  /// **'Z bliska'**
  String get scanCloseUp;

  /// No description provided for @scanTorch.
  ///
  /// In pl, this message translates to:
  /// **'Latarka'**
  String get scanTorch;

  /// No description provided for @scanManual.
  ///
  /// In pl, this message translates to:
  /// **'Wpisz kod ręcznie'**
  String get scanManual;

  /// No description provided for @scanNormalLens.
  ///
  /// In pl, this message translates to:
  /// **'Zwykły obiektyw'**
  String get scanNormalLens;

  /// No description provided for @scanCloseUpMode.
  ///
  /// In pl, this message translates to:
  /// **'Tryb z bliska'**
  String get scanCloseUpMode;

  /// No description provided for @scanZoomTwo.
  ///
  /// In pl, this message translates to:
  /// **'Przybliż 2×'**
  String get scanZoomTwo;

  /// No description provided for @scanZoomOne.
  ///
  /// In pl, this message translates to:
  /// **'Przybliż 1×'**
  String get scanZoomOne;

  /// No description provided for @scanMissing.
  ///
  /// In pl, this message translates to:
  /// **'Nie znaleziono. Dotknij, aby dodać produkt ze zdjęć.'**
  String get scanMissing;

  /// No description provided for @scanMissingNutrition.
  ///
  /// In pl, this message translates to:
  /// **'Znaleziono produkt, ale brakuje kcal lub makro. Dotknij, aby uzupełnić dane ze zdjęć etykiety.'**
  String get scanMissingNutrition;

  /// No description provided for @scanMissingPackage.
  ///
  /// In pl, this message translates to:
  /// **'Znaleziono produkt, ale brakuje masy całego opakowania. Dotknij, aby odczytać gramaturę ze zdjęcia etykiety.'**
  String get scanMissingPackage;

  /// No description provided for @scanCorrectNutrition.
  ///
  /// In pl, this message translates to:
  /// **'Brakuje kcal lub makro. Dotknij, aby poprawić dane.'**
  String get scanCorrectNutrition;

  /// No description provided for @scanCorrectPackage.
  ///
  /// In pl, this message translates to:
  /// **'Nie odczytano masy całego opakowania. Dotknij, aby poprawić zdjęcia lub wpisz gramaturę ręcznie.'**
  String get scanCorrectPackage;

  /// No description provided for @scanAddedPantry.
  ///
  /// In pl, this message translates to:
  /// **'Dodano do spiżarni'**
  String get scanAddedPantry;

  /// No description provided for @scanAddedDiary.
  ///
  /// In pl, this message translates to:
  /// **'Dodano do Dziennika'**
  String get scanAddedDiary;

  /// No description provided for @scanNutritionUnconfirmed.
  ///
  /// In pl, this message translates to:
  /// **'Serwer nie potwierdził wartości odżywczych produktu.'**
  String get scanNutritionUnconfirmed;

  /// No description provided for @scanAlreadyCatalogue.
  ///
  /// In pl, this message translates to:
  /// **'Już jest w katalogu'**
  String get scanAlreadyCatalogue;

  /// No description provided for @scanAddedCatalogue.
  ///
  /// In pl, this message translates to:
  /// **'Dodano do katalogu'**
  String get scanAddedCatalogue;

  /// No description provided for @scanAlreadySubmitted.
  ///
  /// In pl, this message translates to:
  /// **'Produkt jest już zgłoszony'**
  String get scanAlreadySubmitted;

  /// No description provided for @scanWaitLookup.
  ///
  /// In pl, this message translates to:
  /// **'Poczekaj, aż rozpoznam wszystkie kody.'**
  String get scanWaitLookup;

  /// No description provided for @scanFirstProduct.
  ///
  /// In pl, this message translates to:
  /// **'Najpierw zeskanuj przynajmniej jeden produkt.'**
  String get scanFirstProduct;

  /// No description provided for @scanCompleteMissing.
  ///
  /// In pl, this message translates to:
  /// **'Uzupełnij lub ponów nierozpoznane produkty.'**
  String get scanCompleteMissing;

  /// No description provided for @scanChooseDestinations.
  ///
  /// In pl, this message translates to:
  /// **'Wybierz co najmniej jedno miejsce dla całej serii.'**
  String get scanChooseDestinations;

  /// No description provided for @scanBatchTitle.
  ///
  /// In pl, this message translates to:
  /// **'Skanowanie seryjne'**
  String get scanBatchTitle;

  /// No description provided for @scanFinish.
  ///
  /// In pl, this message translates to:
  /// **'Zakończ'**
  String get scanFinish;

  /// No description provided for @scanBatchGuide.
  ///
  /// In pl, this message translates to:
  /// **'Skanuj kolejne produkty. Miejsca wybierzesz raz dla całej serii.'**
  String get scanBatchGuide;

  /// No description provided for @scanBatchEmpty.
  ///
  /// In pl, this message translates to:
  /// **'Zeskanowane produkty pojawią się tutaj.'**
  String get scanBatchEmpty;

  /// No description provided for @scanPremiumPreview.
  ///
  /// In pl, this message translates to:
  /// **'Podgląd funkcji Premium'**
  String get scanPremiumPreview;

  /// No description provided for @scanPreviewTitle.
  ///
  /// In pl, this message translates to:
  /// **'Całe zakupy jednym skanowaniem'**
  String get scanPreviewTitle;

  /// No description provided for @scanPreviewBody.
  ///
  /// In pl, this message translates to:
  /// **'Aparat pozostaje otwarty, a rozpoznane produkty trafiają na jedną listę. Na końcu wybierasz miejsca i zatwierdzasz wszystko raz.'**
  String get scanPreviewBody;

  /// No description provided for @scanSampleYogurt.
  ///
  /// In pl, this message translates to:
  /// **'Jogurt naturalny'**
  String get scanSampleYogurt;

  /// No description provided for @scanSamplePasta.
  ///
  /// In pl, this message translates to:
  /// **'Makaron pełnoziarnisty'**
  String get scanSamplePasta;

  /// No description provided for @scanSampleYogurtMacro.
  ///
  /// In pl, this message translates to:
  /// **'100 g: 62 kcal · B 4 g · T 3 g · W 5 g'**
  String get scanSampleYogurtMacro;

  /// No description provided for @scanSamplePastaMacro.
  ///
  /// In pl, this message translates to:
  /// **'100 g: 348 kcal · B 13 g · T 3 g · W 65 g'**
  String get scanSamplePastaMacro;

  /// No description provided for @scanAllDestinations.
  ///
  /// In pl, this message translates to:
  /// **'Dodaj wszystkie do'**
  String get scanAllDestinations;

  /// No description provided for @scanTrial.
  ///
  /// In pl, this message translates to:
  /// **'Zobacz Premium'**
  String get scanTrial;

  /// No description provided for @scanPreviewNoCamera.
  ///
  /// In pl, this message translates to:
  /// **'To jest podgląd — aparat nie został uruchomiony.'**
  String get scanPreviewNoCamera;

  /// No description provided for @scanMealTypeAll.
  ///
  /// In pl, this message translates to:
  /// **'Rodzaj posiłku dla wszystkich'**
  String get scanMealTypeAll;

  /// No description provided for @scanAdding.
  ///
  /// In pl, this message translates to:
  /// **'Dodaję produkty…'**
  String get scanAdding;

  /// No description provided for @scanRecognising.
  ///
  /// In pl, this message translates to:
  /// **'Rozpoznawanie…'**
  String get scanRecognising;

  /// No description provided for @scanReady.
  ///
  /// In pl, this message translates to:
  /// **'Gotowy do wspólnego dodania'**
  String get scanReady;

  /// No description provided for @scanSaving.
  ///
  /// In pl, this message translates to:
  /// **'Dodawanie…'**
  String get scanSaving;

  /// No description provided for @scanDone.
  ///
  /// In pl, this message translates to:
  /// **'Gotowe'**
  String get scanDone;

  /// No description provided for @scanTapComplete.
  ///
  /// In pl, this message translates to:
  /// **'Dotknij, aby uzupełnić produkt'**
  String get scanTapComplete;

  /// No description provided for @scanTapRetry.
  ///
  /// In pl, this message translates to:
  /// **'Błąd. Dotknij, aby ponowić.'**
  String get scanTapRetry;

  /// No description provided for @scanWhere.
  ///
  /// In pl, this message translates to:
  /// **'Gdzie dodać produkt?'**
  String get scanWhere;

  /// No description provided for @scanMultiHint.
  ///
  /// In pl, this message translates to:
  /// **'Możesz zaznaczyć kilka miejsc jednocześnie.'**
  String get scanMultiHint;

  /// No description provided for @scanNutritionMissingHint.
  ///
  /// In pl, this message translates to:
  /// **'Nie odnaleziono kompletnych makroskładników. Po wybraniu miejsca uzupełnisz dane ze zdjęć opakowania.'**
  String get scanNutritionMissingHint;

  /// No description provided for @scanDiaryDestination.
  ///
  /// In pl, this message translates to:
  /// **'Dodaj do Dziennika'**
  String get scanDiaryDestination;

  /// No description provided for @scanDiaryDestinationHint.
  ///
  /// In pl, this message translates to:
  /// **'Wybierz ilość i rodzaj posiłku'**
  String get scanDiaryDestinationHint;

  /// No description provided for @scanCatalogueDestination.
  ///
  /// In pl, this message translates to:
  /// **'Dodaj do bazy produktów'**
  String get scanCatalogueDestination;

  /// No description provided for @scanCatalogueDestinationHint.
  ///
  /// In pl, this message translates to:
  /// **'Sprawdź nazwę, markę i makroskładniki'**
  String get scanCatalogueDestinationHint;

  /// No description provided for @scanPantryDestination.
  ///
  /// In pl, this message translates to:
  /// **'Dodaj do spiżarni'**
  String get scanPantryDestination;

  /// No description provided for @scanPantryDestinationHint.
  ///
  /// In pl, this message translates to:
  /// **'Zapisz jako 1 całe opakowanie'**
  String get scanPantryDestinationHint;

  /// No description provided for @scanNext.
  ///
  /// In pl, this message translates to:
  /// **'Dalej'**
  String get scanNext;

  /// No description provided for @catalogueNutritionMissing.
  ///
  /// In pl, this message translates to:
  /// **'Nie odnaleziono kompletnych makroskładników w internecie. Uzupełnij dane ze zdjęć opakowania.'**
  String get catalogueNutritionMissing;

  /// No description provided for @catalogueIncomplete.
  ///
  /// In pl, this message translates to:
  /// **'Ten produkt nie ma jeszcze wartości odżywczych. Dodaj go do bazy z danymi z etykiety, aby użyć go w Dzienniku.'**
  String get catalogueIncomplete;

  /// No description provided for @catalogueProductSearch.
  ///
  /// In pl, this message translates to:
  /// **'Szukaj produktu...'**
  String get catalogueProductSearch;

  /// No description provided for @catalogueNoMatch.
  ///
  /// In pl, this message translates to:
  /// **'Brak produktów pasujących do wyszukiwania.'**
  String get catalogueNoMatch;

  /// No description provided for @autocompleteCatalogue.
  ///
  /// In pl, this message translates to:
  /// **'katalog aplikacji'**
  String get autocompleteCatalogue;

  /// No description provided for @autocompleteScanned.
  ///
  /// In pl, this message translates to:
  /// **'wcześniej zeskanowany'**
  String get autocompleteScanned;

  /// No description provided for @autocompleteHint.
  ///
  /// In pl, this message translates to:
  /// **'Możesz wybrać podpowiedź albo pozostawić własną nazwę.'**
  String get autocompleteHint;

  /// No description provided for @foodEntryPlanDate.
  ///
  /// In pl, this message translates to:
  /// **'Twój aktywny plan nie obejmuje wybranej daty ({date}).'**
  String foodEntryPlanDate(String date);

  /// No description provided for @foodEntryKcalServing.
  ///
  /// In pl, this message translates to:
  /// **'{kcal} kcal / porcja'**
  String foodEntryKcalServing(String kcal);

  /// No description provided for @scanCameraError.
  ///
  /// In pl, this message translates to:
  /// **'Nie można uruchomić aparatu. Sprawdź uprawnienie do kamery albo wpisz kod ręcznie.\n{error}'**
  String scanCameraError(String error);

  /// No description provided for @scanBatchCameraError.
  ///
  /// In pl, this message translates to:
  /// **'Nie można uruchomić aparatu. Sprawdź uprawnienie do kamery.\n{error}'**
  String scanBatchCameraError(String error);

  /// No description provided for @scanRetryError.
  ///
  /// In pl, this message translates to:
  /// **'{error} Dotknij, aby spróbować ponownie.'**
  String scanRetryError(String error);

  /// No description provided for @scanRetrySavedError.
  ///
  /// In pl, this message translates to:
  /// **'{error} Zapisane miejsca nie zostaną dodane ponownie. Dotknij, aby ponowić.'**
  String scanRetrySavedError(String error);

  /// No description provided for @scanAddedPoints.
  ///
  /// In pl, this message translates to:
  /// **'Dodano do katalogu (+{points} pkt)'**
  String scanAddedPoints(int points);

  /// No description provided for @scanAddedCount.
  ///
  /// In pl, this message translates to:
  /// **'Dodano {count} produktów.'**
  String scanAddedCount(int count);

  /// No description provided for @scanAddedPartial.
  ///
  /// In pl, this message translates to:
  /// **'Dodano {saved} z {total}. Dotknij błędnych pozycji i spróbuj ponownie.'**
  String scanAddedPartial(int saved, int total);

  /// No description provided for @scanQueueCount.
  ///
  /// In pl, this message translates to:
  /// **'Rozpoznaję produkty · oczekuje {count}'**
  String scanQueueCount(int count);

  /// No description provided for @scanDoneCount.
  ///
  /// In pl, this message translates to:
  /// **'Gotowe · {count} produktów'**
  String scanDoneCount(int count);

  /// No description provided for @scanAddAllCount.
  ///
  /// In pl, this message translates to:
  /// **'Dodaj wszystkie ({count})'**
  String scanAddAllCount(int count);

  /// No description provided for @scanCodeLabel.
  ///
  /// In pl, this message translates to:
  /// **'Kod: {code}'**
  String scanCodeLabel(String code);

  /// No description provided for @scanDestinationsCount.
  ///
  /// In pl, this message translates to:
  /// **'Dodaj do {count} miejsc'**
  String scanDestinationsCount(int count);

  /// No description provided for @scanPantryAddedName.
  ///
  /// In pl, this message translates to:
  /// **'{name} dodano do spiżarni.'**
  String scanPantryAddedName(String name);

  /// No description provided for @diaryCustomWater.
  ///
  /// In pl, this message translates to:
  /// **'Inna ilość'**
  String get diaryCustomWater;

  /// No description provided for @rewardProductSemantics.
  ///
  /// In pl, this message translates to:
  /// **'Nagroda: jeden punkt Premium za dodanie nowego, unikalnego produktu do bazy.'**
  String get rewardProductSemantics;

  /// No description provided for @rewardProductTitle.
  ///
  /// In pl, this message translates to:
  /// **'Zyskaj 1 punkt Premium'**
  String get rewardProductTitle;

  /// No description provided for @rewardProductBody.
  ///
  /// In pl, this message translates to:
  /// **'Zeskanuj kod lub dodaj ręcznie nowy, unikalny produkt do bazy.'**
  String get rewardProductBody;

  /// No description provided for @rewardProductPoint.
  ///
  /// In pl, this message translates to:
  /// **'+1 pkt'**
  String get rewardProductPoint;

  /// No description provided for @productsMarketUnavailable.
  ///
  /// In pl, this message translates to:
  /// **'Brak potwierdzonego cennika dla tego rynku.'**
  String get productsMarketUnavailable;

  /// No description provided for @home.
  ///
  /// In pl, this message translates to:
  /// **'Start'**
  String get home;

  /// No description provided for @recipes.
  ///
  /// In pl, this message translates to:
  /// **'Przepisy'**
  String get recipes;

  /// No description provided for @shopping.
  ///
  /// In pl, this message translates to:
  /// **'Zakupy'**
  String get shopping;

  /// No description provided for @diary.
  ///
  /// In pl, this message translates to:
  /// **'Dziennik'**
  String get diary;

  /// No description provided for @premium.
  ///
  /// In pl, this message translates to:
  /// **'Premium'**
  String get premium;

  /// No description provided for @profile.
  ///
  /// In pl, this message translates to:
  /// **'Profil'**
  String get profile;

  /// No description provided for @add.
  ///
  /// In pl, this message translates to:
  /// **'Dodaj'**
  String get add;

  /// No description provided for @newPlan.
  ///
  /// In pl, this message translates to:
  /// **'Nowy plan'**
  String get newPlan;

  /// No description provided for @planMeals.
  ///
  /// In pl, this message translates to:
  /// **'Zaplanuj posiłki'**
  String get planMeals;

  /// No description provided for @productDatabase.
  ///
  /// In pl, this message translates to:
  /// **'Baza produktów'**
  String get productDatabase;

  /// No description provided for @checkPrices.
  ///
  /// In pl, this message translates to:
  /// **'Sprawdź ceny'**
  String get checkPrices;

  /// No description provided for @promotions.
  ///
  /// In pl, this message translates to:
  /// **'Promocje'**
  String get promotions;

  /// No description provided for @currentOffers.
  ///
  /// In pl, this message translates to:
  /// **'Aktualne okazje'**
  String get currentOffers;

  /// No description provided for @pantry.
  ///
  /// In pl, this message translates to:
  /// **'Spiżarnia'**
  String get pantry;

  /// No description provided for @whatYouHaveAtHome.
  ///
  /// In pl, this message translates to:
  /// **'Co masz w domu'**
  String get whatYouHaveAtHome;

  /// No description provided for @planArchive.
  ///
  /// In pl, this message translates to:
  /// **'Archiwum planów'**
  String get planArchive;

  /// No description provided for @scanBarcode.
  ///
  /// In pl, this message translates to:
  /// **'Skanuj kod kreskowy'**
  String get scanBarcode;

  /// No description provided for @batchScan.
  ///
  /// In pl, this message translates to:
  /// **'Skanuj wiele produktów'**
  String get batchScan;

  /// No description provided for @addRecipeWithAi.
  ///
  /// In pl, this message translates to:
  /// **'Dodaj przepis z AI'**
  String get addRecipeWithAi;

  /// No description provided for @addMeal.
  ///
  /// In pl, this message translates to:
  /// **'Dodaj posiłek'**
  String get addMeal;

  /// No description provided for @addToPantry.
  ///
  /// In pl, this message translates to:
  /// **'Dodaj do spiżarni'**
  String get addToPantry;

  /// No description provided for @barcodeDestinations.
  ///
  /// In pl, this message translates to:
  /// **'Dodaj do Dziennika, bazy produktów albo spiżarni'**
  String get barcodeDestinations;

  /// No description provided for @whatToAdd.
  ///
  /// In pl, this message translates to:
  /// **'Co chcesz dodać?'**
  String get whatToAdd;

  /// No description provided for @scanProduct.
  ///
  /// In pl, this message translates to:
  /// **'Zeskanuj produkt'**
  String get scanProduct;

  /// No description provided for @batchDestinationHint.
  ///
  /// In pl, this message translates to:
  /// **'Jeden cel i jedno zatwierdzenie dla całej serii'**
  String get batchDestinationHint;

  /// No description provided for @aiRecipeSources.
  ///
  /// In pl, this message translates to:
  /// **'Ze zdjęcia, tekstu albo linku'**
  String get aiRecipeSources;

  /// No description provided for @recordCaloriesAndMacros.
  ///
  /// In pl, this message translates to:
  /// **'Zapisz kalorie i makroskładniki'**
  String get recordCaloriesAndMacros;

  /// No description provided for @premiumTwoPoints.
  ///
  /// In pl, this message translates to:
  /// **'PREMIUM · 2 PKT'**
  String get premiumTwoPoints;

  /// No description provided for @recipeLoadError.
  ///
  /// In pl, this message translates to:
  /// **'Błąd podczas pobierania przepisów: {error}'**
  String recipeLoadError(String error);

  /// No description provided for @recipeLoadMoreError.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się wczytać kolejnych przepisów: {error}'**
  String recipeLoadMoreError(String error);

  /// No description provided for @recipeImportInProgress.
  ///
  /// In pl, this message translates to:
  /// **'Trwa dodawanie przepisu przez AI'**
  String get recipeImportInProgress;

  /// No description provided for @recipeAuthorRanking.
  ///
  /// In pl, this message translates to:
  /// **'Ranking autorów przepisów'**
  String get recipeAuthorRanking;

  /// No description provided for @recipeSearchHint.
  ///
  /// In pl, this message translates to:
  /// **'Nazwa, autor lub składnik...'**
  String get recipeSearchHint;

  /// No description provided for @clearSearch.
  ///
  /// In pl, this message translates to:
  /// **'Wyczyść wyszukiwanie'**
  String get clearSearch;

  /// No description provided for @recipeFavourites.
  ///
  /// In pl, this message translates to:
  /// **'Ulubione'**
  String get recipeFavourites;

  /// No description provided for @recipeMine.
  ///
  /// In pl, this message translates to:
  /// **'Moje'**
  String get recipeMine;

  /// No description provided for @recipeNew.
  ///
  /// In pl, this message translates to:
  /// **'Nowość'**
  String get recipeNew;

  /// No description provided for @recipeCommunity.
  ///
  /// In pl, this message translates to:
  /// **'Społeczność'**
  String get recipeCommunity;

  /// No description provided for @moreFilters.
  ///
  /// In pl, this message translates to:
  /// **'Więcej'**
  String get moreFilters;

  /// No description provided for @loadingMore.
  ///
  /// In pl, this message translates to:
  /// **'Wczytywanie…'**
  String get loadingMore;

  /// No description provided for @showMoreRecipes.
  ///
  /// In pl, this message translates to:
  /// **'Pokaż więcej przepisów'**
  String get showMoreRecipes;

  /// No description provided for @addRecipe.
  ///
  /// In pl, this message translates to:
  /// **'Dodaj przepis'**
  String get addRecipe;

  /// No description provided for @withAi.
  ///
  /// In pl, this message translates to:
  /// **'Z pomocą AI'**
  String get withAi;

  /// No description provided for @takeRecipePhoto.
  ///
  /// In pl, this message translates to:
  /// **'Zrób zdjęcie'**
  String get takeRecipePhoto;

  /// No description provided for @recipePhotoHint.
  ///
  /// In pl, this message translates to:
  /// **'Przepisu albo gotowego dania'**
  String get recipePhotoHint;

  /// No description provided for @pasteText.
  ///
  /// In pl, this message translates to:
  /// **'Wklej tekst'**
  String get pasteText;

  /// No description provided for @pasteLink.
  ///
  /// In pl, this message translates to:
  /// **'Wklej link'**
  String get pasteLink;

  /// No description provided for @addManually.
  ///
  /// In pl, this message translates to:
  /// **'Dodaj ręcznie'**
  String get addManually;

  /// No description provided for @filters.
  ///
  /// In pl, this message translates to:
  /// **'Filtry'**
  String get filters;

  /// No description provided for @clearFilters.
  ///
  /// In pl, this message translates to:
  /// **'Wyczyść'**
  String get clearFilters;

  /// No description provided for @sortRecipes.
  ///
  /// In pl, this message translates to:
  /// **'Sortowanie'**
  String get sortRecipes;

  /// No description provided for @sortAlphabetically.
  ///
  /// In pl, this message translates to:
  /// **'Alfabetycznie'**
  String get sortAlphabetically;

  /// No description provided for @sortCaloriesLow.
  ///
  /// In pl, this message translates to:
  /// **'Kalorie: mniej'**
  String get sortCaloriesLow;

  /// No description provided for @sortCaloriesHigh.
  ///
  /// In pl, this message translates to:
  /// **'Kalorie: więcej'**
  String get sortCaloriesHigh;

  /// No description provided for @sortQuickest.
  ///
  /// In pl, this message translates to:
  /// **'Czas: najszybsze'**
  String get sortQuickest;

  /// No description provided for @recipeDiet.
  ///
  /// In pl, this message translates to:
  /// **'Dieta'**
  String get recipeDiet;

  /// No description provided for @allRecipes.
  ///
  /// In pl, this message translates to:
  /// **'Wszystkie'**
  String get allRecipes;

  /// No description provided for @recipeMealType.
  ///
  /// In pl, this message translates to:
  /// **'Typ posiłku'**
  String get recipeMealType;

  /// No description provided for @filterBreakfast.
  ///
  /// In pl, this message translates to:
  /// **'Śniadania'**
  String get filterBreakfast;

  /// No description provided for @filterLunch.
  ///
  /// In pl, this message translates to:
  /// **'Obiady'**
  String get filterLunch;

  /// No description provided for @filterDinner.
  ///
  /// In pl, this message translates to:
  /// **'Kolacje'**
  String get filterDinner;

  /// No description provided for @filterSnacks.
  ///
  /// In pl, this message translates to:
  /// **'Przekąski'**
  String get filterSnacks;

  /// No description provided for @filterDesserts.
  ///
  /// In pl, this message translates to:
  /// **'Desery'**
  String get filterDesserts;

  /// No description provided for @recipeDifficulty.
  ///
  /// In pl, this message translates to:
  /// **'Trudność'**
  String get recipeDifficulty;

  /// No description provided for @anyDifficulty.
  ///
  /// In pl, this message translates to:
  /// **'Każda'**
  String get anyDifficulty;

  /// No description provided for @filterEasy.
  ///
  /// In pl, this message translates to:
  /// **'Łatwe'**
  String get filterEasy;

  /// No description provided for @filterMedium.
  ///
  /// In pl, this message translates to:
  /// **'Średnie'**
  String get filterMedium;

  /// No description provided for @filterHard.
  ///
  /// In pl, this message translates to:
  /// **'Trudne'**
  String get filterHard;

  /// No description provided for @showResults.
  ///
  /// In pl, this message translates to:
  /// **'Pokaż wyniki'**
  String get showResults;

  /// No description provided for @recipeCardSummary.
  ///
  /// In pl, this message translates to:
  /// **'{minutes} min • {calories} kcal/porcję'**
  String recipeCardSummary(int minutes, int calories);

  /// No description provided for @noRecipes.
  ///
  /// In pl, this message translates to:
  /// **'Brak przepisów'**
  String get noRecipes;

  /// No description provided for @noRecipesHint.
  ///
  /// In pl, this message translates to:
  /// **'Sprawdź nazwę przepisu, autora lub składnika.'**
  String get noRecipesHint;

  /// No description provided for @mealBreakfast.
  ///
  /// In pl, this message translates to:
  /// **'śniadanie'**
  String get mealBreakfast;

  /// No description provided for @mealLunch.
  ///
  /// In pl, this message translates to:
  /// **'obiad'**
  String get mealLunch;

  /// No description provided for @mealDinner.
  ///
  /// In pl, this message translates to:
  /// **'kolacja'**
  String get mealDinner;

  /// No description provided for @mealSnack.
  ///
  /// In pl, this message translates to:
  /// **'przekąska'**
  String get mealSnack;

  /// No description provided for @mealDessert.
  ///
  /// In pl, this message translates to:
  /// **'deser'**
  String get mealDessert;

  /// No description provided for @difficultyEasy.
  ///
  /// In pl, this message translates to:
  /// **'łatwy'**
  String get difficultyEasy;

  /// No description provided for @difficultyMedium.
  ///
  /// In pl, this message translates to:
  /// **'średni'**
  String get difficultyMedium;

  /// No description provided for @difficultyHard.
  ///
  /// In pl, this message translates to:
  /// **'trudny'**
  String get difficultyHard;

  /// No description provided for @dietNoRestrictions.
  ///
  /// In pl, this message translates to:
  /// **'Bez ograniczeń'**
  String get dietNoRestrictions;

  /// No description provided for @dietVegetarian.
  ///
  /// In pl, this message translates to:
  /// **'Wegetariańska'**
  String get dietVegetarian;

  /// No description provided for @dietVegan.
  ///
  /// In pl, this message translates to:
  /// **'Wegańska'**
  String get dietVegan;

  /// No description provided for @dietGlutenFree.
  ///
  /// In pl, this message translates to:
  /// **'Bezglutenowa'**
  String get dietGlutenFree;

  /// No description provided for @dietKeto.
  ///
  /// In pl, this message translates to:
  /// **'Keto'**
  String get dietKeto;

  /// No description provided for @dietHighProtein.
  ///
  /// In pl, this message translates to:
  /// **'Wysokobiałkowa'**
  String get dietHighProtein;

  /// No description provided for @dietNoRestrictionsDescription.
  ///
  /// In pl, this message translates to:
  /// **'Jesz wszystko, na co masz ochotę'**
  String get dietNoRestrictionsDescription;

  /// No description provided for @dietVegetarianDescription.
  ///
  /// In pl, this message translates to:
  /// **'Posiłki bez mięsa i ryb'**
  String get dietVegetarianDescription;

  /// No description provided for @dietVeganDescription.
  ///
  /// In pl, this message translates to:
  /// **'Posiłki w 100% roślinne'**
  String get dietVeganDescription;

  /// No description provided for @dietGlutenFreeDescription.
  ///
  /// In pl, this message translates to:
  /// **'Dania bez zawartości glutenu'**
  String get dietGlutenFreeDescription;

  /// No description provided for @dietKetoDescription.
  ///
  /// In pl, this message translates to:
  /// **'Niska zawartość węglowodanów'**
  String get dietKetoDescription;

  /// No description provided for @dietHighProteinDescription.
  ///
  /// In pl, this message translates to:
  /// **'Dla aktywnych, budujących masę'**
  String get dietHighProteinDescription;

  /// No description provided for @planStatusActive.
  ///
  /// In pl, this message translates to:
  /// **'active'**
  String get planStatusActive;

  /// No description provided for @planStatusDraft.
  ///
  /// In pl, this message translates to:
  /// **'draft'**
  String get planStatusDraft;

  /// No description provided for @planStatusCompleted.
  ///
  /// In pl, this message translates to:
  /// **'completed'**
  String get planStatusCompleted;

  /// No description provided for @planStatusArchived.
  ///
  /// In pl, this message translates to:
  /// **'archived'**
  String get planStatusArchived;

  /// No description provided for @authCaptchaRequired.
  ///
  /// In pl, this message translates to:
  /// **'Najpierw potwierdź, że nie jesteś robotem.'**
  String get authCaptchaRequired;

  /// No description provided for @authLoginFailed.
  ///
  /// In pl, this message translates to:
  /// **'Logowanie nie powiodło się'**
  String get authLoginFailed;

  /// No description provided for @authWelcomeBack.
  ///
  /// In pl, this message translates to:
  /// **'Witaj ponownie!'**
  String get authWelcomeBack;

  /// No description provided for @authLoginPrompt.
  ///
  /// In pl, this message translates to:
  /// **'Zaloguj się do swojego konta'**
  String get authLoginPrompt;

  /// No description provided for @authEmail.
  ///
  /// In pl, this message translates to:
  /// **'E-mail'**
  String get authEmail;

  /// No description provided for @authEnterEmail.
  ///
  /// In pl, this message translates to:
  /// **'Wprowadź adres e-mail'**
  String get authEnterEmail;

  /// No description provided for @authEnterValidEmail.
  ///
  /// In pl, this message translates to:
  /// **'Wprowadź poprawny adres e-mail'**
  String get authEnterValidEmail;

  /// No description provided for @authPassword.
  ///
  /// In pl, this message translates to:
  /// **'Hasło'**
  String get authPassword;

  /// No description provided for @authEnterPassword.
  ///
  /// In pl, this message translates to:
  /// **'Wprowadź hasło'**
  String get authEnterPassword;

  /// No description provided for @authPasswordMinSix.
  ///
  /// In pl, this message translates to:
  /// **'Hasło musi mieć co najmniej 6 znaków'**
  String get authPasswordMinSix;

  /// No description provided for @authSignIn.
  ///
  /// In pl, this message translates to:
  /// **'Zaloguj się'**
  String get authSignIn;

  /// No description provided for @authForgotPasswordQuestion.
  ///
  /// In pl, this message translates to:
  /// **'Zapomniałeś hasła?'**
  String get authForgotPasswordQuestion;

  /// No description provided for @authOr.
  ///
  /// In pl, this message translates to:
  /// **'lub'**
  String get authOr;

  /// No description provided for @authContinueApple.
  ///
  /// In pl, this message translates to:
  /// **'Kontynuuj z Apple'**
  String get authContinueApple;

  /// No description provided for @authContinueGoogle.
  ///
  /// In pl, this message translates to:
  /// **'Kontynuuj z Google'**
  String get authContinueGoogle;

  /// No description provided for @authNoAccount.
  ///
  /// In pl, this message translates to:
  /// **'Nie masz konta?'**
  String get authNoAccount;

  /// No description provided for @authRegister.
  ///
  /// In pl, this message translates to:
  /// **'Zarejestruj się'**
  String get authRegister;

  /// No description provided for @authDocumentOpenFailed.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się otworzyć: {url}'**
  String authDocumentOpenFailed(String url);

  /// No description provided for @authAcceptTermsRequired.
  ///
  /// In pl, this message translates to:
  /// **'Zaakceptuj regulamin, aby założyć konto.'**
  String get authAcceptTermsRequired;

  /// No description provided for @authRegistrationFailed.
  ///
  /// In pl, this message translates to:
  /// **'Rejestracja nie powiodła się'**
  String get authRegistrationFailed;

  /// No description provided for @authCreateAccount.
  ///
  /// In pl, this message translates to:
  /// **'Utwórz konto'**
  String get authCreateAccount;

  /// No description provided for @authJoinPlanner.
  ///
  /// In pl, this message translates to:
  /// **'Dołącz do Meal Planner i planuj sprytnie'**
  String get authJoinPlanner;

  /// No description provided for @authDisplayName.
  ///
  /// In pl, this message translates to:
  /// **'Imię / Nazwa użytkownika'**
  String get authDisplayName;

  /// No description provided for @authEnterName.
  ///
  /// In pl, this message translates to:
  /// **'Wprowadź swoje imię'**
  String get authEnterName;

  /// No description provided for @authRepeatPassword.
  ///
  /// In pl, this message translates to:
  /// **'Powtórz hasło'**
  String get authRepeatPassword;

  /// No description provided for @authConfirmPassword.
  ///
  /// In pl, this message translates to:
  /// **'Potwierdź hasło'**
  String get authConfirmPassword;

  /// No description provided for @authPasswordsMismatch.
  ///
  /// In pl, this message translates to:
  /// **'Hasła nie są identyczne'**
  String get authPasswordsMismatch;

  /// No description provided for @authAcceptPrefix.
  ///
  /// In pl, this message translates to:
  /// **'Akceptuję '**
  String get authAcceptPrefix;

  /// No description provided for @authTerms.
  ///
  /// In pl, this message translates to:
  /// **'regulamin'**
  String get authTerms;

  /// No description provided for @authAnd.
  ///
  /// In pl, this message translates to:
  /// **' oraz '**
  String get authAnd;

  /// No description provided for @authPrivacyPolicy.
  ///
  /// In pl, this message translates to:
  /// **'politykę prywatności'**
  String get authPrivacyPolicy;

  /// No description provided for @authAlreadyAccount.
  ///
  /// In pl, this message translates to:
  /// **'Masz już konto?'**
  String get authAlreadyAccount;

  /// No description provided for @authValidEmailRequired.
  ///
  /// In pl, this message translates to:
  /// **'Podaj prawidłowy adres e-mail.'**
  String get authValidEmailRequired;

  /// No description provided for @authCodeSixDigits.
  ///
  /// In pl, this message translates to:
  /// **'Kod musi mieć dokładnie 6 cyfr.'**
  String get authCodeSixDigits;

  /// No description provided for @authNewPasswordMinEight.
  ///
  /// In pl, this message translates to:
  /// **'Nowe hasło musi mieć co najmniej 8 znaków.'**
  String get authNewPasswordMinEight;

  /// No description provided for @authPasswordChanged.
  ///
  /// In pl, this message translates to:
  /// **'Hasło zostało zmienione. Zaloguj się nowym hasłem.'**
  String get authPasswordChanged;

  /// No description provided for @authForgotPasswordTitle.
  ///
  /// In pl, this message translates to:
  /// **'Zapomniałem hasła'**
  String get authForgotPasswordTitle;

  /// No description provided for @authResetDescription.
  ///
  /// In pl, this message translates to:
  /// **'Podaj adres e-mail, na który wyślemy kod do zresetowania hasła.'**
  String get authResetDescription;

  /// No description provided for @authEmailAddress.
  ///
  /// In pl, this message translates to:
  /// **'Adres e-mail'**
  String get authEmailAddress;

  /// No description provided for @authSendCode.
  ///
  /// In pl, this message translates to:
  /// **'Wyślij kod'**
  String get authSendCode;

  /// No description provided for @authResetCodeSentTo.
  ///
  /// In pl, this message translates to:
  /// **'Jeśli konto z adresem {email} istnieje, wysłaliśmy na nie 6-cyfrowy kod. Wpisz go poniżej razem z nowym hasłem.'**
  String authResetCodeSentTo(String email);

  /// No description provided for @authCode.
  ///
  /// In pl, this message translates to:
  /// **'Kod'**
  String get authCode;

  /// No description provided for @authNewPassword.
  ///
  /// In pl, this message translates to:
  /// **'Nowe hasło'**
  String get authNewPassword;

  /// No description provided for @authChangePassword.
  ///
  /// In pl, this message translates to:
  /// **'Zmień hasło'**
  String get authChangePassword;

  /// No description provided for @authUseDifferentEmail.
  ///
  /// In pl, this message translates to:
  /// **'Podaj inny e-mail'**
  String get authUseDifferentEmail;

  /// No description provided for @authNewCodeSent.
  ///
  /// In pl, this message translates to:
  /// **'Nowy kod został wysłany.'**
  String get authNewCodeSent;

  /// No description provided for @authCodeSendFailed.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się wysłać kodu.'**
  String get authCodeSendFailed;

  /// No description provided for @authVerifyEmailTitle.
  ///
  /// In pl, this message translates to:
  /// **'Potwierdź swój e-mail'**
  String get authVerifyEmailTitle;

  /// No description provided for @authVerificationSentTo.
  ///
  /// In pl, this message translates to:
  /// **'Wysłaliśmy 6-cyfrowy kod na adres\n{email}'**
  String authVerificationSentTo(String email);

  /// No description provided for @authVerify.
  ///
  /// In pl, this message translates to:
  /// **'Potwierdź'**
  String get authVerify;

  /// No description provided for @authResendCode.
  ///
  /// In pl, this message translates to:
  /// **'Wyślij kod ponownie'**
  String get authResendCode;

  /// No description provided for @onboardingAllergenGluten.
  ///
  /// In pl, this message translates to:
  /// **'Gluten'**
  String get onboardingAllergenGluten;

  /// No description provided for @onboardingAllergenLactose.
  ///
  /// In pl, this message translates to:
  /// **'Laktoza'**
  String get onboardingAllergenLactose;

  /// No description provided for @onboardingAllergenNuts.
  ///
  /// In pl, this message translates to:
  /// **'Orzechy'**
  String get onboardingAllergenNuts;

  /// No description provided for @onboardingAllergenEggs.
  ///
  /// In pl, this message translates to:
  /// **'Jaja'**
  String get onboardingAllergenEggs;

  /// No description provided for @onboardingAllergenSoy.
  ///
  /// In pl, this message translates to:
  /// **'Soja'**
  String get onboardingAllergenSoy;

  /// No description provided for @onboardingAllergenCelery.
  ///
  /// In pl, this message translates to:
  /// **'Seler'**
  String get onboardingAllergenCelery;

  /// No description provided for @onboardingAllergenFish.
  ///
  /// In pl, this message translates to:
  /// **'Ryby'**
  String get onboardingAllergenFish;

  /// No description provided for @onboardingAllergenShellfish.
  ///
  /// In pl, this message translates to:
  /// **'Skorupiaki'**
  String get onboardingAllergenShellfish;

  /// No description provided for @onboardingSelectStoreRequired.
  ///
  /// In pl, this message translates to:
  /// **'Wybierz swój preferowany sklep!'**
  String get onboardingSelectStoreRequired;

  /// No description provided for @onboardingPreferencesSaveFailed.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się zapisać preferencji'**
  String get onboardingPreferencesSaveFailed;

  /// No description provided for @onboardingBack.
  ///
  /// In pl, this message translates to:
  /// **'Wstecz'**
  String get onboardingBack;

  /// No description provided for @onboardingDone.
  ///
  /// In pl, this message translates to:
  /// **'Gotowe!'**
  String get onboardingDone;

  /// No description provided for @onboardingNext.
  ///
  /// In pl, this message translates to:
  /// **'Dalej'**
  String get onboardingNext;

  /// No description provided for @onboardingStoreTitle.
  ///
  /// In pl, this message translates to:
  /// **'Gdzie robisz zakupy?'**
  String get onboardingStoreTitle;

  /// No description provided for @onboardingStoreDescription.
  ///
  /// In pl, this message translates to:
  /// **'Wybierz sklep, w którym najczęściej robisz zakupy. Dostosujemy plan posiłków i produkty pod ten konkretny asortyment.'**
  String get onboardingStoreDescription;

  /// No description provided for @onboardingStoresLoadFailed.
  ///
  /// In pl, this message translates to:
  /// **'Błąd wczytywania sklepów:\n{error}'**
  String onboardingStoresLoadFailed(String error);

  /// No description provided for @onboardingAllergensTitle.
  ///
  /// In pl, this message translates to:
  /// **'Czy masz jakieś alergie?'**
  String get onboardingAllergensTitle;

  /// No description provided for @onboardingAllergensDescription.
  ///
  /// In pl, this message translates to:
  /// **'Wybierz składniki, których nie możesz jeść. Przepisy zawierające te alergeny nie będą sugerowane.'**
  String get onboardingAllergensDescription;

  /// No description provided for @onboardingDietTitle.
  ///
  /// In pl, this message translates to:
  /// **'Wybierz swoją dietę'**
  String get onboardingDietTitle;

  /// No description provided for @onboardingDietDescription.
  ///
  /// In pl, this message translates to:
  /// **'Dostosujemy rekomendacje przepisów do Twojego stylu żywieniowego.'**
  String get onboardingDietDescription;

  /// No description provided for @onboardingHouseholdTitle.
  ///
  /// In pl, this message translates to:
  /// **'Dla ilu osób gotujesz?'**
  String get onboardingHouseholdTitle;

  /// No description provided for @onboardingHouseholdDescription.
  ///
  /// In pl, this message translates to:
  /// **'Automatycznie dopasujemy ilości składników w przepisach oraz porcje w liście zakupowej.'**
  String get onboardingHouseholdDescription;

  /// No description provided for @onboardingCookingForMyself.
  ///
  /// In pl, this message translates to:
  /// **'Gotuję tylko dla siebie'**
  String get onboardingCookingForMyself;

  /// No description provided for @onboardingHouseholdCount.
  ///
  /// In pl, this message translates to:
  /// **'Liczba osób w gospodarstwie: {count}'**
  String onboardingHouseholdCount(int count);

  /// No description provided for @onboardingProfileTitle.
  ///
  /// In pl, this message translates to:
  /// **'Twój profil i cel'**
  String get onboardingProfileTitle;

  /// No description provided for @onboardingProfileDescription.
  ///
  /// In pl, this message translates to:
  /// **'Chcesz teraz obliczyć zapotrzebowanie kaloryczne i uzupełnić wagę, wzrost oraz cel? Możesz też zrobić to później w profilu.'**
  String get onboardingProfileDescription;

  /// No description provided for @onboardingOpenCalorieCalculator.
  ///
  /// In pl, this message translates to:
  /// **'Otwórz kalkulator zapotrzebowania'**
  String get onboardingOpenCalorieCalculator;

  /// No description provided for @onboardingProfileOptional.
  ///
  /// In pl, this message translates to:
  /// **'Ten krok jest opcjonalny. Wybierz „Dalej”, aby go pominąć.'**
  String get onboardingProfileOptional;

  /// No description provided for @onboardingPantryTitle.
  ///
  /// In pl, this message translates to:
  /// **'Co masz w spiżarni?'**
  String get onboardingPantryTitle;

  /// No description provided for @onboardingPantryDescription.
  ///
  /// In pl, this message translates to:
  /// **'Dodaj produkty, które masz już w domu. Dzięki temu łatwiej znajdziesz przepisy bez dodatkowych zakupów.'**
  String get onboardingPantryDescription;

  /// No description provided for @onboardingAddPantryProducts.
  ///
  /// In pl, this message translates to:
  /// **'Dodaj produkty do spiżarni'**
  String get onboardingAddPantryProducts;

  /// No description provided for @onboardingPantryOptional.
  ///
  /// In pl, this message translates to:
  /// **'Ten krok możesz pominąć.'**
  String get onboardingPantryOptional;

  /// No description provided for @onboardingPremiumOrPoints.
  ///
  /// In pl, this message translates to:
  /// **'PREMIUM • LUB PUNKTY'**
  String get onboardingPremiumOrPoints;

  /// No description provided for @onboardingAiTitle.
  ///
  /// In pl, this message translates to:
  /// **'Masz przepis? Dodaj go w chwilę'**
  String get onboardingAiTitle;

  /// No description provided for @onboardingAiDescription.
  ///
  /// In pl, this message translates to:
  /// **'W zakładce Przepisy wybierz „Dodaj przepis”. AI przygotuje składniki i kroki na podstawie:'**
  String get onboardingAiDescription;

  /// No description provided for @onboardingAiImport.
  ///
  /// In pl, this message translates to:
  /// **'Import przepisu z AI'**
  String get onboardingAiImport;

  /// No description provided for @onboardingAiPhoto.
  ///
  /// In pl, this message translates to:
  /// **'Zdjęcia'**
  String get onboardingAiPhoto;

  /// No description provided for @onboardingAiPhotoDescription.
  ///
  /// In pl, this message translates to:
  /// **'Sfotografuj kartkę z przepisem albo gotowe danie.'**
  String get onboardingAiPhotoDescription;

  /// No description provided for @onboardingAiText.
  ///
  /// In pl, this message translates to:
  /// **'Tekstu'**
  String get onboardingAiText;

  /// No description provided for @onboardingAiTextDescription.
  ///
  /// In pl, this message translates to:
  /// **'Wklej opis lub wpisz samą nazwę potrawy.'**
  String get onboardingAiTextDescription;

  /// No description provided for @onboardingAiLink.
  ///
  /// In pl, this message translates to:
  /// **'Linku'**
  String get onboardingAiLink;

  /// No description provided for @onboardingAiLinkDescription.
  ///
  /// In pl, this message translates to:
  /// **'Wklej adres strony lub udostępnij go z innej aplikacji.'**
  String get onboardingAiLinkDescription;

  /// No description provided for @onboardingAiShareExample.
  ///
  /// In pl, this message translates to:
  /// **'Przykład: w TikToku wybierz „Udostępnij” → Meal Planner Polska. Gdy przepis będzie gotowy, możesz poprosić AI o zmianę, np. wersję bez laktozy.'**
  String get onboardingAiShareExample;

  /// No description provided for @onboardingAiPointCosts.
  ///
  /// In pl, this message translates to:
  /// **'Dodanie przepisu kosztuje 2 punkty bez subskrypcji Premium. Późniejsza zmiana przez AI kosztuje 1 punkt.'**
  String get onboardingAiPointCosts;

  /// No description provided for @welcomeAllSet.
  ///
  /// In pl, this message translates to:
  /// **'Wszystko gotowe!'**
  String get welcomeAllSet;

  /// No description provided for @welcomePointsIntro.
  ///
  /// In pl, this message translates to:
  /// **'Na start dorzucamy Ci {points} punkty premium — to nasze podziękowanie za założenie konta i skonfigurowanie aplikacji.'**
  String welcomePointsIntro(int points);

  /// No description provided for @welcomeAiPointDescription.
  ///
  /// In pl, this message translates to:
  /// **'Za 2 punkty dodasz przepis z dowolnego linku lub zdjęcia — zrobi to za Ciebie AI.'**
  String get welcomeAiPointDescription;

  /// No description provided for @welcomeTryNow.
  ///
  /// In pl, this message translates to:
  /// **'Wypróbuj teraz'**
  String get welcomeTryNow;

  /// No description provided for @welcomeScanFirstProduct.
  ///
  /// In pl, this message translates to:
  /// **'Zeskanuj pierwszy produkt'**
  String get welcomeScanFirstProduct;

  /// No description provided for @welcomeAddRecipeLink.
  ///
  /// In pl, this message translates to:
  /// **'Dodaj przepis z linku'**
  String get welcomeAddRecipeLink;

  /// No description provided for @welcomeStart.
  ///
  /// In pl, this message translates to:
  /// **'Zaczynamy'**
  String get welcomeStart;

  /// No description provided for @priceCompareTitle.
  ///
  /// In pl, this message translates to:
  /// **'Porównanie cen'**
  String get priceCompareTitle;

  /// No description provided for @priceCompareSourcesTooltip.
  ///
  /// In pl, this message translates to:
  /// **'Źródła cen i marek'**
  String get priceCompareSourcesTooltip;

  /// No description provided for @priceCompareRetry.
  ///
  /// In pl, this message translates to:
  /// **'Spróbuj ponownie'**
  String get priceCompareRetry;

  /// No description provided for @priceCompareEmpty.
  ///
  /// In pl, this message translates to:
  /// **'Brak danych do porównania.'**
  String get priceCompareEmpty;

  /// No description provided for @priceCompareIntro.
  ///
  /// In pl, this message translates to:
  /// **'Porównujemy koszt całej listy. „~” oznacza cenę orientacyjną. Dostępność i aktualną cenę potwierdź w wybranym sklepie.'**
  String get priceCompareIntro;

  /// No description provided for @priceCompareSwitchSuccess.
  ///
  /// In pl, this message translates to:
  /// **'Plan przełączony na {storeName}'**
  String priceCompareSwitchSuccess(String storeName);

  /// No description provided for @priceCompareSwitchError.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się przełączyć sklepu'**
  String get priceCompareSwitchError;

  /// No description provided for @priceCompareLoadError.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się załadować porównania: {error}'**
  String priceCompareLoadError(String error);

  /// No description provided for @priceCompareCurrencyError.
  ///
  /// In pl, this message translates to:
  /// **'Nie można porównać cen w różnych walutach. Odśwież dane i spróbuj ponownie.'**
  String get priceCompareCurrencyError;

  /// No description provided for @priceCompareCheapestEstimate.
  ///
  /// In pl, this message translates to:
  /// **'Najniższy szacunek'**
  String get priceCompareCheapestEstimate;

  /// No description provided for @priceCompareCheapest.
  ///
  /// In pl, this message translates to:
  /// **'Najtaniej'**
  String get priceCompareCheapest;

  /// No description provided for @priceCompareIncomplete.
  ///
  /// In pl, this message translates to:
  /// **'Niepełny koszyk • brak cen dla {count} produktów'**
  String priceCompareIncomplete(int count);

  /// No description provided for @priceCompareProductCount.
  ///
  /// In pl, this message translates to:
  /// **'{count} produktów'**
  String priceCompareProductCount(int count);

  /// No description provided for @priceCompareEstimatedPrices.
  ///
  /// In pl, this message translates to:
  /// **'ceny orientacyjne'**
  String get priceCompareEstimatedPrices;

  /// No description provided for @priceCompareSavings.
  ///
  /// In pl, this message translates to:
  /// **'różnica do {amount}'**
  String priceCompareSavings(String amount);

  /// No description provided for @priceCompareExpandHint.
  ///
  /// In pl, this message translates to:
  /// **'dotknij, aby zobaczyć listę'**
  String get priceCompareExpandHint;

  /// No description provided for @priceCompareMissing.
  ///
  /// In pl, this message translates to:
  /// **'Brak danych cenowych: {names}. Pokazana suma dotyczy tylko pozycji z ceną.'**
  String priceCompareMissing(String names);

  /// No description provided for @priceCompareEstimate.
  ///
  /// In pl, this message translates to:
  /// **'cena orientacyjna'**
  String get priceCompareEstimate;

  /// Substitution failed; keep the picker open and do not claim success.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się zamienić produktu.'**
  String get shoppingSubstituteFailed;

  /// The substitute price refers to this local package, not the whole recipe requirement.
  ///
  /// In pl, this message translates to:
  /// **'{quantity} {unit} w opakowaniu'**
  String shoppingSubstitutePack(String quantity, String unit);

  /// No description provided for @priceCompareUnpricedTotal.
  ///
  /// In pl, this message translates to:
  /// **'Brak pełnej wyceny'**
  String get priceCompareUnpricedTotal;

  /// No description provided for @priceCompareMissingUnpriced.
  ///
  /// In pl, this message translates to:
  /// **'Brak cen dla: {names}. Nie można jeszcze wycenić całego koszyka.'**
  String priceCompareMissingUnpriced(String names);

  /// No description provided for @priceComparePackages.
  ///
  /// In pl, this message translates to:
  /// **'Do kupienia: {count} × {quantity} {unit}'**
  String priceComparePackages(int count, String quantity, String unit);

  /// No description provided for @priceCompareVerified.
  ///
  /// In pl, this message translates to:
  /// **'cena sprawdzona {date}'**
  String priceCompareVerified(String date);

  /// No description provided for @priceCompareSwitchStore.
  ///
  /// In pl, this message translates to:
  /// **'Przełącz plan na ten sklep'**
  String get priceCompareSwitchStore;

  /// No description provided for @priceCompareSourceTitle.
  ///
  /// In pl, this message translates to:
  /// **'Skąd pochodzą ceny?'**
  String get priceCompareSourceTitle;

  /// No description provided for @priceCompareSourceBody.
  ///
  /// In pl, this message translates to:
  /// **'Porównanie obejmuje ceny produktów dostępnych w katalogu dla Twojego rynku. Cena bez daty sprawdzenia jest orientacyjna, a nie potwierdzoną ofertą sklepu. Pokazujemy ilość i jednostkę, których dotyczy cena. Znacznik „~” oznacza szacunek. Dostępność i aktualną cenę potwierdź w sklepie. Nie porównujemy ani nie przeliczamy cen pomiędzy PLN i GBP.'**
  String get priceCompareSourceBody;

  /// No description provided for @priceCompareSourceClose.
  ///
  /// In pl, this message translates to:
  /// **'Rozumiem'**
  String get priceCompareSourceClose;

  /// No description provided for @priceCompareUnitPack.
  ///
  /// In pl, this message translates to:
  /// **'opak.'**
  String get priceCompareUnitPack;

  /// No description provided for @priceCompareUnitServing.
  ///
  /// In pl, this message translates to:
  /// **'porcja'**
  String get priceCompareUnitServing;

  /// No description provided for @priceCompareUnitPiece.
  ///
  /// In pl, this message translates to:
  /// **'szt.'**
  String get priceCompareUnitPiece;

  /// No description provided for @priceCompareUnitTeaspoon.
  ///
  /// In pl, this message translates to:
  /// **'łyżeczka'**
  String get priceCompareUnitTeaspoon;

  /// No description provided for @priceCompareUnitCup.
  ///
  /// In pl, this message translates to:
  /// **'szklanka'**
  String get priceCompareUnitCup;

  /// No description provided for @homeBatchCompleted.
  ///
  /// In pl, this message translates to:
  /// **'Obsłużono: {count} produktów.'**
  String homeBatchCompleted(int count);

  /// No description provided for @homeShopFallback.
  ///
  /// In pl, this message translates to:
  /// **'Sklep'**
  String get homeShopFallback;

  /// No description provided for @homeGreeting.
  ///
  /// In pl, this message translates to:
  /// **'Cześć, {name}!'**
  String homeGreeting(String name);

  /// No description provided for @homeUserFallback.
  ///
  /// In pl, this message translates to:
  /// **'użytkowniku'**
  String get homeUserFallback;

  /// No description provided for @homeCookingToday.
  ///
  /// In pl, this message translates to:
  /// **'Co dziś gotujemy?'**
  String get homeCookingToday;

  /// No description provided for @homeQuickActions.
  ///
  /// In pl, this message translates to:
  /// **'Szybkie akcje'**
  String get homeQuickActions;

  /// No description provided for @homePlanLoading.
  ///
  /// In pl, this message translates to:
  /// **'Wczytywanie planu posiłków…'**
  String get homePlanLoading;

  /// No description provided for @homePlanLoadError.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się wczytać planu posiłków.'**
  String get homePlanLoadError;

  /// No description provided for @homeNextPlan.
  ///
  /// In pl, this message translates to:
  /// **'Twój najbliższy plan'**
  String get homeNextPlan;

  /// No description provided for @homeActivePlan.
  ///
  /// In pl, this message translates to:
  /// **'Twój aktywny plan'**
  String get homeActivePlan;

  /// No description provided for @homeDetails.
  ///
  /// In pl, this message translates to:
  /// **'Szczegóły'**
  String get homeDetails;

  /// No description provided for @homePlanChip.
  ///
  /// In pl, this message translates to:
  /// **'Plan {day}.{month} · {days} dni'**
  String homePlanChip(int day, int month, int days);

  /// No description provided for @homeNutritionLoading.
  ///
  /// In pl, this message translates to:
  /// **'Wczytywanie kalorii i makroskładników…'**
  String get homeNutritionLoading;

  /// No description provided for @homeNutritionError.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się wczytać kalorii i makroskładników.'**
  String get homeNutritionError;

  /// No description provided for @homeEatenToday.
  ///
  /// In pl, this message translates to:
  /// **'Dziś zjedzono'**
  String get homeEatenToday;

  /// No description provided for @homeProtein.
  ///
  /// In pl, this message translates to:
  /// **'Białko'**
  String get homeProtein;

  /// No description provided for @homeFat.
  ///
  /// In pl, this message translates to:
  /// **'Tłuszcz'**
  String get homeFat;

  /// No description provided for @homeCarbsShort.
  ///
  /// In pl, this message translates to:
  /// **'Węgl.'**
  String get homeCarbsShort;

  /// No description provided for @homeRetry.
  ///
  /// In pl, this message translates to:
  /// **'Spróbuj ponownie'**
  String get homeRetry;

  /// No description provided for @homeTipOfTheDay.
  ///
  /// In pl, this message translates to:
  /// **'PORADA DNIA'**
  String get homeTipOfTheDay;

  /// No description provided for @homeHydration.
  ///
  /// In pl, this message translates to:
  /// **'Nawodnienie'**
  String get homeHydration;

  /// No description provided for @homeDataLoading.
  ///
  /// In pl, this message translates to:
  /// **'Wczytywanie danych…'**
  String get homeDataLoading;

  /// No description provided for @homeDataError.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się wczytać danych'**
  String get homeDataError;

  /// No description provided for @homeWaterProgress.
  ///
  /// In pl, this message translates to:
  /// **'{amount} z {goal} ml · {percent}% celu'**
  String homeWaterProgress(int amount, int goal, int percent);

  /// No description provided for @homeWeeklyContest.
  ///
  /// In pl, this message translates to:
  /// **'Konkurs tygodnia'**
  String get homeWeeklyContest;

  /// No description provided for @homeWeeklyContestHint.
  ///
  /// In pl, this message translates to:
  /// **'Dodaj najwięcej przepisów w tym tygodniu i zgarnij punkty premium — 3 za 1. miejsce, 2 za 2., 1 za 3.'**
  String get homeWeeklyContestHint;

  /// No description provided for @homePlanStarts.
  ///
  /// In pl, this message translates to:
  /// **'Plan od {date}'**
  String homePlanStarts(String date);

  /// No description provided for @homePlanDay.
  ///
  /// In pl, this message translates to:
  /// **'Dzień {day} z {days}'**
  String homePlanDay(int day, int days);

  /// No description provided for @homeViewPlan.
  ///
  /// In pl, this message translates to:
  /// **'Zobacz plan'**
  String get homeViewPlan;

  /// No description provided for @homeNoPlan.
  ///
  /// In pl, this message translates to:
  /// **'Brak aktywnego planu posiłków'**
  String get homeNoPlan;

  /// No description provided for @homeNoPlanHint.
  ///
  /// In pl, this message translates to:
  /// **'Wygeneruj zbilansowany plan posiłków, zminimalizuj koszty i wygeneruj inteligentną listę zakupów.'**
  String get homeNoPlanHint;

  /// No description provided for @homeCreatePlan.
  ///
  /// In pl, this message translates to:
  /// **'Stwórz nowy plan posiłków'**
  String get homeCreatePlan;

  /// No description provided for @homeAiPointsTitle.
  ///
  /// In pl, this message translates to:
  /// **'Masz punkty na import przepisu AI'**
  String get homeAiPointsTitle;

  /// No description provided for @homeAiPointsHint.
  ///
  /// In pl, this message translates to:
  /// **'Dodaj przepis ze zdjęcia, tekstu albo linku — bez subskrypcji.'**
  String get homeAiPointsHint;

  /// No description provided for @homeTryAction.
  ///
  /// In pl, this message translates to:
  /// **'Wypróbuj'**
  String get homeTryAction;

  /// No description provided for @homeBatchTitle.
  ///
  /// In pl, this message translates to:
  /// **'Skanujesz kilka produktów?'**
  String get homeBatchTitle;

  /// No description provided for @homeBatchHint.
  ///
  /// In pl, this message translates to:
  /// **'W Premium zeskanujesz całą serię bez zamykania aparatu.'**
  String get homeBatchHint;

  /// No description provided for @homeViewPremium.
  ///
  /// In pl, this message translates to:
  /// **'Zobacz Premium'**
  String get homeViewPremium;

  /// No description provided for @homeAutoWeekTitle.
  ///
  /// In pl, this message translates to:
  /// **'Następny tydzień może zrobić się sam'**
  String get homeAutoWeekTitle;

  /// No description provided for @homeAutoWeekHint.
  ///
  /// In pl, this message translates to:
  /// **'Premium przygotuje co tydzień plan i opcjonalną listę zakupów.'**
  String get homeAutoWeekHint;

  /// No description provided for @homeCheckAction.
  ///
  /// In pl, this message translates to:
  /// **'Sprawdź'**
  String get homeCheckAction;

  /// No description provided for @homeHideHint.
  ///
  /// In pl, this message translates to:
  /// **'Ukryj'**
  String get homeHideHint;

  /// No description provided for @planSelectStoreRequired.
  ///
  /// In pl, this message translates to:
  /// **'Wybierz sklep przed wygenerowaniem planu!'**
  String get planSelectStoreRequired;

  /// No description provided for @planStoreMarketError.
  ///
  /// In pl, this message translates to:
  /// **'Wybierz sklep dostępny dla kraju Twojego konta. Odśwież listę sklepów i spróbuj ponownie.'**
  String get planStoreMarketError;

  /// No description provided for @planKcalValidation.
  ///
  /// In pl, this message translates to:
  /// **'Wpisz od 800 do 6000 kcal na osobę dziennie.'**
  String get planKcalValidation;

  /// No description provided for @planGenerateError.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się wygenerować planu'**
  String get planGenerateError;

  /// No description provided for @planFreeLimitTitle.
  ///
  /// In pl, this message translates to:
  /// **'Limit darmowego konta'**
  String get planFreeLimitTitle;

  /// No description provided for @planUnderstood.
  ///
  /// In pl, this message translates to:
  /// **'Rozumiem'**
  String get planUnderstood;

  /// No description provided for @planViewPremium.
  ///
  /// In pl, this message translates to:
  /// **'Zobacz Premium'**
  String get planViewPremium;

  /// No description provided for @planReadyTitle.
  ///
  /// In pl, this message translates to:
  /// **'Plan gotowy'**
  String get planReadyTitle;

  /// No description provided for @planReadyFor.
  ///
  /// In pl, this message translates to:
  /// **'Twój plan na {days} dni dla {people, plural, =1{1 osoby} other{{people} osób}} jest gotowy.'**
  String planReadyFor(int days, int people);

  /// No description provided for @planEstimatedBudget.
  ///
  /// In pl, this message translates to:
  /// **'Szacowany minimalny koszt zakupów'**
  String get planEstimatedBudget;

  /// No description provided for @planShoppingLimitReached.
  ///
  /// In pl, this message translates to:
  /// **'Plan jest gotowy, ale w tym tygodniu wykorzystano już darmowy limit jednej nowej listy zakupów. Kolejną listę utworzysz w przyszłym tygodniu lub z Premium.'**
  String get planShoppingLimitReached;

  /// No description provided for @planStandardWeeklyLimit.
  ///
  /// In pl, this message translates to:
  /// **'Konto standardowe: jeden nowy plan tygodniowo'**
  String get planStandardWeeklyLimit;

  /// No description provided for @planWeeklyLimitExplanation.
  ///
  /// In pl, this message translates to:
  /// **'Limit odnawia się w poniedziałek. Usunięcie planu go nie odnawia. Premium pozwala tworzyć plany bez limitu.'**
  String get planWeeklyLimitExplanation;

  /// No description provided for @planExplorePremium.
  ///
  /// In pl, this message translates to:
  /// **'Poznaj Premium'**
  String get planExplorePremium;

  /// No description provided for @planViewAction.
  ///
  /// In pl, this message translates to:
  /// **'Zobacz plan'**
  String get planViewAction;

  /// No description provided for @planNewTitle.
  ///
  /// In pl, this message translates to:
  /// **'Nowy plan posiłków'**
  String get planNewTitle;

  /// No description provided for @planChooseStore.
  ///
  /// In pl, this message translates to:
  /// **'Wybierz sklep'**
  String get planChooseStore;

  /// No description provided for @planPriceEstimateHint.
  ///
  /// In pl, this message translates to:
  /// **'Koszt planu jest szacunkiem. Ceny i dostępność produktów potwierdź w wybranym sklepie.'**
  String get planPriceEstimateHint;

  /// No description provided for @planDurationTitle.
  ///
  /// In pl, this message translates to:
  /// **'Czas trwania planu: {days} dni'**
  String planDurationTitle(int days);

  /// No description provided for @planDays.
  ///
  /// In pl, this message translates to:
  /// **'{days} dni'**
  String planDays(int days);

  /// No description provided for @planOneDay.
  ///
  /// In pl, this message translates to:
  /// **'1 dzień'**
  String get planOneDay;

  /// No description provided for @planHouseholdTitle.
  ///
  /// In pl, this message translates to:
  /// **'Dla ilu osób gotujesz: {people, plural, one{1 osoba} few{{people} osoby} other{{people} osób}}'**
  String planHouseholdTitle(int people);

  /// No description provided for @planHouseholdHint.
  ///
  /// In pl, this message translates to:
  /// **'Od 1 do 8 osób. Domyślnie z profilu — zmiana dotyczy tylko tego planu.'**
  String get planHouseholdHint;

  /// No description provided for @planMealTypes.
  ///
  /// In pl, this message translates to:
  /// **'Typy posiłków'**
  String get planMealTypes;

  /// No description provided for @planDailyCalories.
  ///
  /// In pl, this message translates to:
  /// **'Cel kaloryczny dziennie'**
  String get planDailyCalories;

  /// No description provided for @planCaloriesField.
  ///
  /// In pl, this message translates to:
  /// **'Docelowe kcal / dzień / osoba'**
  String get planCaloriesField;

  /// No description provided for @planCaloriesExample.
  ///
  /// In pl, this message translates to:
  /// **'np. 2000'**
  String get planCaloriesExample;

  /// No description provided for @planCaloriesHint.
  ///
  /// In pl, this message translates to:
  /// **'Cel z kalkulatora; bez zapisanego celu: 2000 kcal.'**
  String get planCaloriesHint;

  /// No description provided for @planBudgetOptional.
  ///
  /// In pl, this message translates to:
  /// **'Maksymalny budżet (opcjonalnie)'**
  String get planBudgetOptional;

  /// No description provided for @planBudgetField.
  ///
  /// In pl, this message translates to:
  /// **'Maksymalny budżet'**
  String get planBudgetField;

  /// No description provided for @planBudgetExample.
  ///
  /// In pl, this message translates to:
  /// **'np. 150.00'**
  String get planBudgetExample;

  /// No description provided for @planIncludePantry.
  ///
  /// In pl, this message translates to:
  /// **'Uwzględnij spiżarnię'**
  String get planIncludePantry;

  /// No description provided for @planPantryHint.
  ///
  /// In pl, this message translates to:
  /// **'Posiadane produkty trafią na koniec listy za 0 zł. Brakującą ilość nadal dodamy do zakupów.'**
  String get planPantryHint;

  /// No description provided for @planIngredientPreferences.
  ///
  /// In pl, this message translates to:
  /// **'Lubię / Nie lubię'**
  String get planIngredientPreferences;

  /// No description provided for @planIngredientPreferencesHint.
  ///
  /// In pl, this message translates to:
  /// **'Premium · jedno dopasowane danie dziennie'**
  String get planIngredientPreferencesHint;

  /// No description provided for @planGenerating.
  ///
  /// In pl, this message translates to:
  /// **'Generowanie...'**
  String get planGenerating;

  /// No description provided for @planGenerate.
  ///
  /// In pl, this message translates to:
  /// **'Wygeneruj plan!'**
  String get planGenerate;

  /// No description provided for @planGeneratingTitle.
  ///
  /// In pl, this message translates to:
  /// **'Układamy Twój optymalny plan posiłków...'**
  String get planGeneratingTitle;

  /// No description provided for @planGeneratingHint.
  ///
  /// In pl, this message translates to:
  /// **'Maksymalizujemy ponowne wykorzystanie składników, aby zmniejszyć cenę zakupów.'**
  String get planGeneratingHint;

  /// No description provided for @planActivated.
  ///
  /// In pl, this message translates to:
  /// **'Plan został zatwierdzony! Lista zakupów wygenerowana.'**
  String get planActivated;

  /// No description provided for @planGenericError.
  ///
  /// In pl, this message translates to:
  /// **'Wystąpił błąd'**
  String get planGenericError;

  /// No description provided for @planSwapTitle.
  ///
  /// In pl, this message translates to:
  /// **'Zamień: {recipeName}'**
  String planSwapTitle(String recipeName);

  /// No description provided for @planSwapSearch.
  ///
  /// In pl, this message translates to:
  /// **'Szukaj dania'**
  String get planSwapSearch;

  /// No description provided for @planSwapSearchHint.
  ///
  /// In pl, this message translates to:
  /// **'Wpisz nazwę przepisu'**
  String get planSwapSearchHint;

  /// No description provided for @planSwapLoadError.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się pobrać przepisów. Spróbuj ponownie.'**
  String get planSwapLoadError;

  /// No description provided for @planSwapNoAlternatives.
  ///
  /// In pl, this message translates to:
  /// **'Brak innych dań w tej kategorii'**
  String get planSwapNoAlternatives;

  /// No description provided for @planSwapNoSearchResults.
  ///
  /// In pl, this message translates to:
  /// **'Nie znaleziono dania o tej nazwie'**
  String get planSwapNoSearchResults;

  /// No description provided for @planSwapSuccess.
  ///
  /// In pl, this message translates to:
  /// **'Przepis został zamieniony'**
  String get planSwapSuccess;

  /// No description provided for @planSwapError.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się zamienić przepisu'**
  String get planSwapError;

  /// No description provided for @planFinishedTitle.
  ///
  /// In pl, this message translates to:
  /// **'Plan zakończony'**
  String get planFinishedTitle;

  /// No description provided for @planArchivePremiumRequired.
  ///
  /// In pl, this message translates to:
  /// **'Podgląd archiwum jest dostępny z Premium.'**
  String get planArchivePremiumRequired;

  /// No description provided for @planFinishedHint.
  ///
  /// In pl, this message translates to:
  /// **'Ten plan już się zakończył.'**
  String get planFinishedHint;

  /// No description provided for @planOpenArchive.
  ///
  /// In pl, this message translates to:
  /// **'Otwórz archiwum'**
  String get planOpenArchive;

  /// No description provided for @planCreateNew.
  ///
  /// In pl, this message translates to:
  /// **'Utwórz nowy plan'**
  String get planCreateNew;

  /// No description provided for @planViewTitle.
  ///
  /// In pl, this message translates to:
  /// **'Plan posiłków'**
  String get planViewTitle;

  /// No description provided for @planNotFound.
  ///
  /// In pl, this message translates to:
  /// **'Nie znaleziono planu posiłków. Wygeneruj nowy plan.'**
  String get planNotFound;

  /// No description provided for @planStoreFallback.
  ///
  /// In pl, this message translates to:
  /// **'Sklep'**
  String get planStoreFallback;

  /// No description provided for @planDeleteTitle.
  ///
  /// In pl, this message translates to:
  /// **'Usuń plan'**
  String get planDeleteTitle;

  /// No description provided for @planDeleteQuestion.
  ///
  /// In pl, this message translates to:
  /// **'Czy na pewno chcesz usunąć ten plan posiłków? Na koncie standardowym usunięcie nie odnawia limitu jednego nowego planu tygodniowo.'**
  String get planDeleteQuestion;

  /// No description provided for @planCancel.
  ///
  /// In pl, this message translates to:
  /// **'Anuluj'**
  String get planCancel;

  /// No description provided for @planDeleteError.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się usunąć planu'**
  String get planDeleteError;

  /// No description provided for @planDelete.
  ///
  /// In pl, this message translates to:
  /// **'Usuń'**
  String get planDelete;

  /// No description provided for @planDay.
  ///
  /// In pl, this message translates to:
  /// **'Dzień {day}'**
  String planDay(int day);

  /// No description provided for @planResumeArchive.
  ///
  /// In pl, this message translates to:
  /// **'Archiwum · wznów plan'**
  String get planResumeArchive;

  /// No description provided for @planChangeSettings.
  ///
  /// In pl, this message translates to:
  /// **'Zmień parametry'**
  String get planChangeSettings;

  /// No description provided for @planActivate.
  ///
  /// In pl, this message translates to:
  /// **'Zatwierdź plan'**
  String get planActivate;

  /// No description provided for @planGoShopping.
  ///
  /// In pl, this message translates to:
  /// **'Przejdź do zakupów'**
  String get planGoShopping;

  /// Recipe creation screen display text. API identifiers and point costs remain unchanged.
  ///
  /// In pl, this message translates to:
  /// **'Odrzucić zmiany?'**
  String get manualRecipeDiscardTitle;

  /// Recipe creation screen display text. API identifiers and point costs remain unchanged.
  ///
  /// In pl, this message translates to:
  /// **'Wpisane dane przepisu nie zostały jeszcze zapisane.'**
  String get manualRecipeUnsaved;

  /// Recipe creation screen display text. API identifiers and point costs remain unchanged.
  ///
  /// In pl, this message translates to:
  /// **'Zostań'**
  String get manualRecipeStay;

  /// Recipe creation screen display text. API identifiers and point costs remain unchanged.
  ///
  /// In pl, this message translates to:
  /// **'Odrzuć'**
  String get manualRecipeDiscard;

  /// Recipe creation screen display text. API identifiers and point costs remain unchanged.
  ///
  /// In pl, this message translates to:
  /// **'Ten produkt nie ma pełnych wartości odżywczych. Wybierz inny wynik albo dodaj produkt do bazy z danymi z etykiety.'**
  String get manualRecipeNutritionRequired;

  /// Recipe creation screen display text. API identifiers and point costs remain unchanged.
  ///
  /// In pl, this message translates to:
  /// **'Dodaj przynajmniej jeden składnik'**
  String get manualRecipeIngredientRequired;

  /// Recipe creation screen display text. API identifiers and point costs remain unchanged.
  ///
  /// In pl, this message translates to:
  /// **'Dodaj przynajmniej jeden krok przygotowania'**
  String get manualRecipeStepRequired;

  /// Recipe creation screen display text. API identifiers and point costs remain unchanged.
  ///
  /// In pl, this message translates to:
  /// **'Dodaj przepis ręcznie'**
  String get manualRecipeTitle;

  /// Recipe creation screen display text. API identifiers and point costs remain unchanged.
  ///
  /// In pl, this message translates to:
  /// **'Nazwa przepisu'**
  String get manualRecipeName;

  /// Recipe creation screen display text. API identifiers and point costs remain unchanged.
  ///
  /// In pl, this message translates to:
  /// **'Podaj nazwę'**
  String get manualRecipeNameRequired;

  /// Recipe creation screen display text. API identifiers and point costs remain unchanged.
  ///
  /// In pl, this message translates to:
  /// **'Krótki opis (opcjonalnie)'**
  String get manualRecipeDescription;

  /// Recipe creation screen display text. API identifiers and point costs remain unchanged.
  ///
  /// In pl, this message translates to:
  /// **'Rodzaj posiłku'**
  String get manualRecipeMealType;

  /// Recipe creation screen display text. API identifiers and point costs remain unchanged.
  ///
  /// In pl, this message translates to:
  /// **'Przygotowanie (min)'**
  String get manualRecipePreparationMinutes;

  /// Recipe creation screen display text. API identifiers and point costs remain unchanged.
  ///
  /// In pl, this message translates to:
  /// **'Gotowanie (min)'**
  String get manualRecipeCookingMinutes;

  /// Recipe creation screen display text. API identifiers and point costs remain unchanged.
  ///
  /// In pl, this message translates to:
  /// **'Porcje'**
  String get manualRecipeServings;

  /// Recipe creation screen display text. API identifiers and point costs remain unchanged.
  ///
  /// In pl, this message translates to:
  /// **'Składniki'**
  String get manualRecipeIngredients;

  /// Recipe creation screen display text. API identifiers and point costs remain unchanged.
  ///
  /// In pl, this message translates to:
  /// **'Brak dodanych składników'**
  String get manualRecipeNoIngredients;

  /// Recipe creation screen display text. API identifiers and point costs remain unchanged.
  ///
  /// In pl, this message translates to:
  /// **'Kroki przygotowania'**
  String get manualRecipeSteps;

  /// Recipe creation screen display text. API identifiers and point costs remain unchanged.
  ///
  /// In pl, this message translates to:
  /// **'Dodaj krok'**
  String get manualRecipeAddStep;

  /// Recipe creation screen display text. API identifiers and point costs remain unchanged.
  ///
  /// In pl, this message translates to:
  /// **'Opisz ten krok...'**
  String get manualRecipeStepHint;

  /// Recipe creation screen display text. API identifiers and point costs remain unchanged.
  ///
  /// In pl, this message translates to:
  /// **'Zgłoś do wspólnego katalogu'**
  String get manualRecipeSubmitToCatalogue;

  /// Recipe creation screen display text. API identifiers and point costs remain unchanged.
  ///
  /// In pl, this message translates to:
  /// **'Po akceptacji administratora będzie widoczny dla wszystkich i policzy się do cotygodniowego konkursu.'**
  String get manualRecipePublicHint;

  /// Recipe creation screen display text. API identifiers and point costs remain unchanged.
  ///
  /// In pl, this message translates to:
  /// **'Zapisz przepis'**
  String get manualRecipeSave;

  /// Recipe creation screen display text. API identifiers and point costs remain unchanged.
  ///
  /// In pl, this message translates to:
  /// **'Wybierz składnik'**
  String get manualRecipeChooseIngredient;

  /// Recipe creation screen display text. API identifiers and point costs remain unchanged.
  ///
  /// In pl, this message translates to:
  /// **'Szukaj w katalogu i bazie produktów...'**
  String get manualRecipeIngredientSearch;

  /// Recipe creation screen display text. API identifiers and point costs remain unchanged.
  ///
  /// In pl, this message translates to:
  /// **'Wpisz co najmniej 2 znaki, aby znaleźć składnik.'**
  String get manualRecipeIngredientSearchHint;

  /// Recipe creation screen display text. API identifiers and point costs remain unchanged.
  ///
  /// In pl, this message translates to:
  /// **'Nie znaleziono produktu. Dodaj go najpierw do bazy produktów wraz z wartościami z etykiety.'**
  String get manualRecipeIngredientNotFound;

  /// Recipe creation screen display text. API identifiers and point costs remain unchanged.
  ///
  /// In pl, this message translates to:
  /// **'Wymaga uzupełnienia etykiety'**
  String get manualRecipeLabelRequired;

  /// Recipe creation screen display text. API identifiers and point costs remain unchanged.
  ///
  /// In pl, this message translates to:
  /// **'Brak pełnych wartości odżywczych'**
  String get manualRecipeNutritionMissing;

  /// Recipe creation screen display text. API identifiers and point costs remain unchanged.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się pobrać zdjęcia'**
  String get aiRecipePhotoLoadFailed;

  /// Recipe creation screen display text. API identifiers and point costs remain unchanged.
  ///
  /// In pl, this message translates to:
  /// **'Wybierz z galerii'**
  String get aiRecipeChooseGallery;

  /// Recipe creation screen display text. API identifiers and point costs remain unchanged.
  ///
  /// In pl, this message translates to:
  /// **'Serwer nie ma jeszcze funkcji importu AI. Dokończ wdrożenie backendu na Renderze.'**
  String get aiRecipeServerUnavailable;

  /// Recipe creation screen display text. API identifiers and point costs remain unchanged.
  ///
  /// In pl, this message translates to:
  /// **'Potrzebujesz Premium albo punktów'**
  String get aiRecipePremiumOrPointsTitle;

  /// Recipe creation screen display text. API identifiers and point costs remain unchanged.
  ///
  /// In pl, this message translates to:
  /// **'Anuluj'**
  String get aiRecipeCancel;

  /// Recipe creation screen display text. API identifiers and point costs remain unchanged.
  ///
  /// In pl, this message translates to:
  /// **'Kup punkty'**
  String get aiRecipeBuyPoints;

  /// Recipe creation screen display text. API identifiers and point costs remain unchanged.
  ///
  /// In pl, this message translates to:
  /// **'Wróć do aplikacji'**
  String get aiRecipeBackToApp;

  /// Recipe creation screen display text. API identifiers and point costs remain unchanged.
  ///
  /// In pl, this message translates to:
  /// **'Dodaj przepis przez AI'**
  String get aiRecipeTitle;

  /// Recipe creation screen display text. API identifiers and point costs remain unchanged.
  ///
  /// In pl, this message translates to:
  /// **'Zdjęcie'**
  String get aiRecipePhoto;

  /// Recipe creation screen display text. API identifiers and point costs remain unchanged.
  ///
  /// In pl, this message translates to:
  /// **'Link'**
  String get aiRecipeLink;

  /// Recipe creation screen display text. API identifiers and point costs remain unchanged.
  ///
  /// In pl, this message translates to:
  /// **'Przyjmuję przepis...'**
  String get aiRecipeAccepting;

  /// Recipe creation screen display text. API identifiers and point costs remain unchanged.
  ///
  /// In pl, this message translates to:
  /// **'Za chwilę możesz wrócić do korzystania z aplikacji.'**
  String get aiRecipeAcceptingHint;

  /// Recipe creation screen display text. API identifiers and point costs remain unchanged.
  ///
  /// In pl, this message translates to:
  /// **'Twój przepis jest przygotowywany'**
  String get aiRecipePreparing;

  /// Recipe creation screen display text. API identifiers and point costs remain unchanged.
  ///
  /// In pl, this message translates to:
  /// **'Przepis jest gotowy'**
  String get aiRecipeReady;

  /// Recipe creation screen display text. API identifiers and point costs remain unchanged.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się rozpoznać przepisu'**
  String get aiRecipeRecognitionFailed;

  /// Recipe creation screen display text. API identifiers and point costs remain unchanged.
  ///
  /// In pl, this message translates to:
  /// **'Możesz wyjść z tego ekranu. O wyniku poinformujemy Cię w aplikacji, a przy włączonych pushach także na telefonie.'**
  String get aiRecipeBackgroundHint;

  /// Recipe creation screen display text. API identifiers and point costs remain unchanged.
  ///
  /// In pl, this message translates to:
  /// **'Znajdziesz go też w zakładce Moje.'**
  String get aiRecipeFindInMine;

  /// Recipe creation screen display text. API identifiers and point costs remain unchanged.
  ///
  /// In pl, this message translates to:
  /// **'Spróbuj ponownie.'**
  String get aiRecipeRetrySentence;

  /// Recipe creation screen display text. API identifiers and point costs remain unchanged.
  ///
  /// In pl, this message translates to:
  /// **'Otwórz przepis'**
  String get aiRecipeOpen;

  /// Recipe creation screen display text. API identifiers and point costs remain unchanged.
  ///
  /// In pl, this message translates to:
  /// **'Dostosuj z AI · 1 pkt'**
  String get aiRecipeEditOnePoint;

  /// Recipe creation screen display text. API identifiers and point costs remain unchanged.
  ///
  /// In pl, this message translates to:
  /// **'Dodaj kolejny przepis'**
  String get aiRecipeAddAnother;

  /// Recipe creation screen display text. API identifiers and point costs remain unchanged.
  ///
  /// In pl, this message translates to:
  /// **'Wklej treść przepisu'**
  String get aiRecipePasteTextTitle;

  /// Recipe creation screen display text. API identifiers and point costs remain unchanged.
  ///
  /// In pl, this message translates to:
  /// **'Wklej gotowy przepis (z notatnika, wiadomości, strony internetowej) — AI rozpozna składniki i kroki. Albo po prostu wpisz samą nazwę dania (np. \"rosół\" albo \"lasagne\") — AI ułoży dla Ciebie cały przepis od zera.'**
  String get aiRecipeTextDescription;

  /// Recipe creation screen display text. API identifiers and point costs remain unchanged.
  ///
  /// In pl, this message translates to:
  /// **'np. \"rosół\" albo pełny przepis ze składnikami i krokami...'**
  String get aiRecipeTextHint;

  /// Recipe creation screen display text. API identifiers and point costs remain unchanged.
  ///
  /// In pl, this message translates to:
  /// **'Rozpoznaj przepis'**
  String get aiRecipeRecognise;

  /// Recipe creation screen display text. API identifiers and point costs remain unchanged.
  ///
  /// In pl, this message translates to:
  /// **'Zrób zdjęcie przepisu'**
  String get aiRecipePhotoTitle;

  /// Recipe creation screen display text. API identifiers and point costs remain unchanged.
  ///
  /// In pl, this message translates to:
  /// **'Zdjęcie karty przepisu, strony książki kucharskiej, albo gotowego dania — AI oszacuje wtedy prawdopodobny przepis.'**
  String get aiRecipePhotoDescription;

  /// Recipe creation screen display text. API identifiers and point costs remain unchanged.
  ///
  /// In pl, this message translates to:
  /// **'Dotknij, aby dodać zdjęcie'**
  String get aiRecipeTapAddPhoto;

  /// Recipe creation screen display text. API identifiers and point costs remain unchanged.
  ///
  /// In pl, this message translates to:
  /// **'Wklej link do przepisu'**
  String get aiRecipePasteLinkTitle;

  /// Recipe creation screen display text. API identifiers and point costs remain unchanged.
  ///
  /// In pl, this message translates to:
  /// **'Blog kulinarny, TikTok, Instagram — AI spróbuje rozpoznać przepis na podstawie treści strony. Jeśli przepis pada wyłącznie w mowie w nagraniu (nie ma go w opisie), rozpoznanie może się nie udać.'**
  String get aiRecipeLinkDescription;

  /// Recipe creation screen display text. API identifiers and point costs remain unchanged.
  ///
  /// In pl, this message translates to:
  /// **'Funkcja Premium'**
  String get aiRecipePremiumFeature;

  /// Recipe creation screen display text. API identifiers and point costs remain unchanged.
  ///
  /// In pl, this message translates to:
  /// **'Dodawanie własnych przepisów przez AI (z tekstu albo zdjęcia) jest dostępne dla kont z aktywną subskrypcją Premium — albo za 2 punkty premium, bez subskrypcji.'**
  String get aiRecipePremiumDescription;

  /// Recipe creation screen display text. API identifiers and point costs remain unchanged.
  ///
  /// In pl, this message translates to:
  /// **'Zobacz, co jeszcze zyskujesz z Premium, albo kup pakiet punktów.'**
  String get aiRecipePremiumHint;

  /// Shopping list display label. Currency and package data come from the response snapshot.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się pobrać listy sklepów.'**
  String get shoppingStoresLoadFailed;

  /// Shopping list display label. Currency and package data come from the response snapshot.
  ///
  /// In pl, this message translates to:
  /// **'Wybierz sklep dla nowej listy'**
  String get shoppingChooseStore;

  /// Shopping list display label. Currency and package data come from the response snapshot.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się utworzyć listy zakupów.'**
  String get shoppingCreateFailed;

  /// Shopping list display label. Currency and package data come from the response snapshot.
  ///
  /// In pl, this message translates to:
  /// **'Udostępnij listę zakupów'**
  String get shoppingShareTitle;

  /// Shopping list display label. Currency and package data come from the response snapshot.
  ///
  /// In pl, this message translates to:
  /// **'Podaj nazwę użytkownika osoby, której chcesz udostępnić listę. Musi ona mieć konto w Meal Planner Polska i zaakceptować zaproszenie, zanim zobaczy listę.'**
  String get shoppingShareHint;

  /// Shopping list display label. Currency and package data come from the response snapshot.
  ///
  /// In pl, this message translates to:
  /// **'Nazwa użytkownika'**
  String get shoppingUsername;

  /// Shopping list display label. Currency and package data come from the response snapshot.
  ///
  /// In pl, this message translates to:
  /// **'Wyślij zaproszenie'**
  String get shoppingSendInvite;

  /// Shopping list display label. Currency and package data come from the response snapshot.
  ///
  /// In pl, this message translates to:
  /// **'Wysłano zaproszenie do {nickname}'**
  String shoppingInviteSent(String nickname);

  /// Shopping list display label. Currency and package data come from the response snapshot.
  ///
  /// In pl, this message translates to:
  /// **'Połącz listy zakupów'**
  String get shoppingMergeTitle;

  /// Shopping list display label. Currency and package data come from the response snapshot.
  ///
  /// In pl, this message translates to:
  /// **'Wybierz listy sklepu {storeName}, które chcesz połączyć z obecną listą. Poprzednie listy znikną z Zakupów, ale plany posiłków pozostaną bez zmian.'**
  String shoppingMergeHint(String storeName);

  /// Shopping list display label. Currency and package data come from the response snapshot.
  ///
  /// In pl, this message translates to:
  /// **'Lista {number}'**
  String shoppingListNumber(int number);

  /// Shopping list display label. Currency and package data come from the response snapshot.
  ///
  /// In pl, this message translates to:
  /// **'{day}.{month} · {count} produktów'**
  String shoppingListDate(int day, int month, int count);

  /// Shopping list display label. Currency and package data come from the response snapshot.
  ///
  /// In pl, this message translates to:
  /// **'Połącz'**
  String get shoppingMerge;

  /// Shopping list display label. Currency and package data come from the response snapshot.
  ///
  /// In pl, this message translates to:
  /// **'Listy zostały połączone'**
  String get shoppingMergeSuccess;

  /// Shopping list display label. Currency and package data come from the response snapshot.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się połączyć list'**
  String get shoppingMergeFailed;

  /// Shopping list display label. Currency and package data come from the response snapshot.
  ///
  /// In pl, this message translates to:
  /// **'Wybierz zamiennik'**
  String get shoppingChooseSubstitute;

  /// No description provided for @shoppingNoSubstitutes.
  ///
  /// In pl, this message translates to:
  /// **'Brak dostępnych zamienników w tym sklepie.'**
  String get shoppingNoSubstitutes;

  /// No description provided for @shoppingCatalogueAlternatives.
  ///
  /// In pl, this message translates to:
  /// **'Zamienniki katalogowe'**
  String get shoppingCatalogueAlternatives;

  /// No description provided for @shoppingStoreAlternatives.
  ///
  /// In pl, this message translates to:
  /// **'Oferty wybranego sklepu'**
  String get shoppingStoreAlternatives;

  /// No description provided for @shoppingCatalogueAvailability.
  ///
  /// In pl, this message translates to:
  /// **'Sprawdź dostępność w sklepie — cena orientacyjna.'**
  String get shoppingCatalogueAvailability;

  /// Shopping list display label. Currency and package data come from the response snapshot.
  ///
  /// In pl, this message translates to:
  /// **'Dla produktu: {name}'**
  String shoppingSubstituteFor(String name);

  /// Shopping list display label. Currency and package data come from the response snapshot.
  ///
  /// In pl, this message translates to:
  /// **'Cena nieznana'**
  String get shoppingPriceUnknown;

  /// Shopping list display label. Currency and package data come from the response snapshot.
  ///
  /// In pl, this message translates to:
  /// **'Zamieniono na: {name}'**
  String shoppingSubstituteChanged(String name);

  /// Shopping list display label. Currency and package data come from the response snapshot.
  ///
  /// In pl, this message translates to:
  /// **'Lista zakupów'**
  String get shoppingListTitle;

  /// Shopping list display label. Currency and package data come from the response snapshot.
  ///
  /// In pl, this message translates to:
  /// **'Utwórz listę i dodaj produkt'**
  String get shoppingCreateAndAdd;

  /// Shopping list display label. Currency and package data come from the response snapshot.
  ///
  /// In pl, this message translates to:
  /// **'Dodaj produkt do listy'**
  String get shoppingAddProduct;

  /// Shopping list display label. Currency and package data come from the response snapshot.
  ///
  /// In pl, this message translates to:
  /// **'Zaproszenia'**
  String get shoppingInvites;

  /// Shopping list display label. Currency and package data come from the response snapshot.
  ///
  /// In pl, this message translates to:
  /// **'Udostępnij'**
  String get shoppingShare;

  /// Shopping list display label. Currency and package data come from the response snapshot.
  ///
  /// In pl, this message translates to:
  /// **'Odśwież'**
  String get shoppingRefresh;

  /// Shopping list display label. Currency and package data come from the response snapshot.
  ///
  /// In pl, this message translates to:
  /// **'Usuń listę'**
  String get shoppingDeleteList;

  /// Shopping list display label. Currency and package data come from the response snapshot.
  ///
  /// In pl, this message translates to:
  /// **'Połącz listy'**
  String get shoppingMergeLists;

  /// Shopping list display label. Currency and package data come from the response snapshot.
  ///
  /// In pl, this message translates to:
  /// **'Porównaj'**
  String get shoppingCompare;

  /// Shopping list display label. Currency and package data come from the response snapshot.
  ///
  /// In pl, this message translates to:
  /// **'Eksportuj'**
  String get shoppingExport;

  /// Shopping list display label. Currency and package data come from the response snapshot.
  ///
  /// In pl, this message translates to:
  /// **'W spiżarni'**
  String get shoppingInPantry;

  /// Shopping list display label. Currency and package data come from the response snapshot.
  ///
  /// In pl, this message translates to:
  /// **'Inne'**
  String get shoppingOther;

  /// Shopping list display label. Currency and package data come from the response snapshot.
  ///
  /// In pl, this message translates to:
  /// **'{count} produktów już masz · {amount}'**
  String shoppingPantryCount(int count, String amount);

  /// Shopping list display label. Currency and package data come from the response snapshot.
  ///
  /// In pl, this message translates to:
  /// **'{checked} z {total} kupione'**
  String shoppingBoughtCount(int checked, int total);

  /// Shopping list display label. Currency and package data come from the response snapshot.
  ///
  /// In pl, this message translates to:
  /// **'Usunąć listę {number}?'**
  String shoppingDeleteTitle(int number);

  /// Shopping list display label. Currency and package data come from the response snapshot.
  ///
  /// In pl, this message translates to:
  /// **'Lista zakupów dla sklepu {storeName} zostanie trwale usunięta wraz ze wszystkimi pozycjami. Plan posiłków pozostaje bez zmian. Usunięcie nie odnawia tygodniowego limitu tworzenia list na koncie standardowym.'**
  String shoppingDeleteHint(String storeName);

  /// Shopping list display label. Currency and package data come from the response snapshot.
  ///
  /// In pl, this message translates to:
  /// **'Usuń'**
  String get shoppingDelete;

  /// Shopping list display label. Currency and package data come from the response snapshot.
  ///
  /// In pl, this message translates to:
  /// **'Lista usunięta'**
  String get shoppingDeleted;

  /// Shopping list display label. Currency and package data come from the response snapshot.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się usunąć listy'**
  String get shoppingDeleteFailed;

  /// Shopping list display label. Currency and package data come from the response snapshot.
  ///
  /// In pl, this message translates to:
  /// **'Masz wszystko z listy'**
  String get shoppingHaveEverything;

  /// Shopping list display label. Currency and package data come from the response snapshot.
  ///
  /// In pl, this message translates to:
  /// **'Przenieś kupione produkty do spiżarni, żeby aplikacja mogła podpowiadać przepisy z tego, co masz w domu.'**
  String get shoppingCompleteHint;

  /// Shopping list display label. Currency and package data come from the response snapshot.
  ///
  /// In pl, this message translates to:
  /// **'Przenieś do spiżarni'**
  String get shoppingMovePantry;

  /// Shopping list display label. Currency and package data come from the response snapshot.
  ///
  /// In pl, this message translates to:
  /// **'Zakończ bez przenoszenia'**
  String get shoppingCompleteWithoutPantry;

  /// Shopping list display label. Currency and package data come from the response snapshot.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się zakończyć listy'**
  String get shoppingCompleteFailed;

  /// Shopping list display label. Currency and package data come from the response snapshot.
  ///
  /// In pl, this message translates to:
  /// **'Zakupy zakończone. Do spiżarni trafiło {count} produktów.'**
  String shoppingCompleteMoved(int count);

  /// Shopping list display label. Currency and package data come from the response snapshot.
  ///
  /// In pl, this message translates to:
  /// **'Zakupy zakończone.'**
  String get shoppingCompleteSuccess;

  /// Shopping list display label. Currency and package data come from the response snapshot.
  ///
  /// In pl, this message translates to:
  /// **'{checked} z {total} produktów'**
  String shoppingProgressCount(int checked, int total);

  /// Shopping list display label. Currency and package data come from the response snapshot.
  ///
  /// In pl, this message translates to:
  /// **'Wszystko kupione'**
  String get shoppingEverythingBought;

  /// Shopping list display label. Currency and package data come from the response snapshot.
  ///
  /// In pl, this message translates to:
  /// **'Od ~{amount} · część cen nieznana'**
  String shoppingUnknownRemaining(String amount);

  /// Shopping list display label. Currency and package data come from the response snapshot.
  ///
  /// In pl, this message translates to:
  /// **'Do zapłaty: ~{amount}'**
  String shoppingRemaining(String amount);

  /// Shopping list display label. Currency and package data come from the response snapshot.
  ///
  /// In pl, this message translates to:
  /// **'w koszyku: {basket} z ~{total}'**
  String shoppingBasketTotal(String basket, String total);

  /// Shopping list display label. Currency and package data come from the response snapshot.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się zapisać pozycji.'**
  String get shoppingItemSaveFailed;

  /// Shopping list display label. Currency and package data come from the response snapshot.
  ///
  /// In pl, this message translates to:
  /// **'Do kupienia: {count} × {quantity} {unit}'**
  String shoppingPackageBuy(int count, String quantity, String unit);

  /// Shopping list display label. Currency and package data come from the response snapshot.
  ///
  /// In pl, this message translates to:
  /// **'ZAMIENNIK'**
  String get shoppingSubstituteBadge;

  /// Shopping list display label. Currency and package data come from the response snapshot.
  ///
  /// In pl, this message translates to:
  /// **'PROMOCJA -{percent}%'**
  String shoppingPromotionBadge(int percent);

  /// Shopping list display label. Currency and package data come from the response snapshot.
  ///
  /// In pl, this message translates to:
  /// **'Brak aktywnej listy zakupów'**
  String get shoppingEmptyTitle;

  /// Shopping list display label. Currency and package data come from the response snapshot.
  ///
  /// In pl, this message translates to:
  /// **'Kliknij +, wybierz sklep i dodaj pierwszy produkt. Możesz też wygenerować listę z planu posiłków.'**
  String get shoppingEmptyHint;

  /// Shopping list display label. Currency and package data come from the response snapshot.
  ///
  /// In pl, this message translates to:
  /// **'Zaproszenia do list'**
  String get shoppingListInvites;

  /// Shopping list display label. Currency and package data come from the response snapshot.
  ///
  /// In pl, this message translates to:
  /// **'Szacowany koszt: {amount}'**
  String shoppingEstimatedTotal(String amount);

  /// Shopping list display label. Currency and package data come from the response snapshot.
  ///
  /// In pl, this message translates to:
  /// **'Podgląd listy znajomego — tylko do odczytu'**
  String get shoppingFriendReadOnly;

  /// No description provided for @priceCompareListSwitchStore.
  ///
  /// In pl, this message translates to:
  /// **'Przełącz listę na ten sklep'**
  String get priceCompareListSwitchStore;

  /// No description provided for @priceCompareListSwitchSuccess.
  ///
  /// In pl, this message translates to:
  /// **'Lista przełączona na {storeName}'**
  String priceCompareListSwitchSuccess(String storeName);

  /// Shopping list display label. Currency and package data come from the response snapshot.
  ///
  /// In pl, this message translates to:
  /// **'Brak pozycji na liście'**
  String get shoppingNoItems;

  /// No description provided for @productsTitle.
  ///
  /// In pl, this message translates to:
  /// **'Produkty'**
  String get productsTitle;

  /// No description provided for @productsPriceSources.
  ///
  /// In pl, this message translates to:
  /// **'Źródła cen i marek'**
  String get productsPriceSources;

  /// No description provided for @productsShopTab.
  ///
  /// In pl, this message translates to:
  /// **'Sklep'**
  String get productsShopTab;

  /// No description provided for @productsCatalogueTab.
  ///
  /// In pl, this message translates to:
  /// **'Katalog'**
  String get productsCatalogueTab;

  /// No description provided for @productsMineTab.
  ///
  /// In pl, this message translates to:
  /// **'Moje'**
  String get productsMineTab;

  /// No description provided for @productsScan.
  ///
  /// In pl, this message translates to:
  /// **'Skanuj kod kreskowy'**
  String get productsScan;

  /// No description provided for @productsBatchScan.
  ///
  /// In pl, this message translates to:
  /// **'Skanuj wiele produktów'**
  String get productsBatchScan;

  /// No description provided for @productsBrandSearch.
  ///
  /// In pl, this message translates to:
  /// **'Szukaj produktu lub marki…'**
  String get productsBrandSearch;

  /// No description provided for @productsClear.
  ///
  /// In pl, this message translates to:
  /// **'Wyczyść'**
  String get productsClear;

  /// No description provided for @productsRetry.
  ///
  /// In pl, this message translates to:
  /// **'Spróbuj ponownie'**
  String get productsRetry;

  /// No description provided for @productsNotFound.
  ///
  /// In pl, this message translates to:
  /// **'Nie znaleziono produktów.'**
  String get productsNotFound;

  /// No description provided for @productsShowMore.
  ///
  /// In pl, this message translates to:
  /// **'Pokaż więcej'**
  String get productsShowMore;

  /// No description provided for @productsSearch.
  ///
  /// In pl, this message translates to:
  /// **'Szukaj produktu...'**
  String get productsSearch;

  /// No description provided for @productsNoShop.
  ///
  /// In pl, this message translates to:
  /// **'Brak wybranego sklepu'**
  String get productsNoShop;

  /// No description provided for @productsChooseShop.
  ///
  /// In pl, this message translates to:
  /// **'Aby przeglądać produkty i ceny, wybierz sklep w swoim profilu lub z listy powyżej.'**
  String get productsChooseShop;

  /// No description provided for @productsError.
  ///
  /// In pl, this message translates to:
  /// **'Coś poszło nie tak'**
  String get productsError;

  /// No description provided for @productsEmpty.
  ///
  /// In pl, this message translates to:
  /// **'Brak produktów'**
  String get productsEmpty;

  /// No description provided for @productsChangeSearch.
  ///
  /// In pl, this message translates to:
  /// **'Spróbuj zmienić wyszukiwaną frazę.'**
  String get productsChangeSearch;

  /// No description provided for @productsUnknown.
  ///
  /// In pl, this message translates to:
  /// **'Nieznany produkt'**
  String get productsUnknown;

  /// No description provided for @productsUnavailable.
  ///
  /// In pl, this message translates to:
  /// **'niedostępny'**
  String get productsUnavailable;

  /// No description provided for @productsDeleteTitle.
  ///
  /// In pl, this message translates to:
  /// **'Usunąć produkt?'**
  String get productsDeleteTitle;

  /// No description provided for @productsCancel.
  ///
  /// In pl, this message translates to:
  /// **'Anuluj'**
  String get productsCancel;

  /// No description provided for @productsDelete.
  ///
  /// In pl, this message translates to:
  /// **'Usuń'**
  String get productsDelete;

  /// No description provided for @productsAdd.
  ///
  /// In pl, this message translates to:
  /// **'Dodaj produkt'**
  String get productsAdd;

  /// No description provided for @productsNothingSubmitted.
  ///
  /// In pl, this message translates to:
  /// **'Nie zgłosiłeś/aś jeszcze żadnego produktu.'**
  String get productsNothingSubmitted;

  /// No description provided for @productsSubmitHint.
  ///
  /// In pl, this message translates to:
  /// **'Dotknij „Dodaj produkt” poniżej, żeby zgłosić coś,\nczego nie ma w katalogu.'**
  String get productsSubmitHint;

  /// No description provided for @productsApproved.
  ///
  /// In pl, this message translates to:
  /// **'W katalogu'**
  String get productsApproved;

  /// No description provided for @productsRejected.
  ///
  /// In pl, this message translates to:
  /// **'Odrzucony'**
  String get productsRejected;

  /// No description provided for @productsPending.
  ///
  /// In pl, this message translates to:
  /// **'Oczekuje na akceptację'**
  String get productsPending;

  /// No description provided for @productsEdit.
  ///
  /// In pl, this message translates to:
  /// **'Edytuj'**
  String get productsEdit;

  /// No description provided for @productsEstimatedPrice.
  ///
  /// In pl, this message translates to:
  /// **'cena orientacyjna'**
  String get productsEstimatedPrice;

  /// No description provided for @productsUnknownQuantity.
  ///
  /// In pl, this message translates to:
  /// **'/ jednostka nieokreślona'**
  String get productsUnknownQuantity;

  /// No description provided for @diaryTitle.
  ///
  /// In pl, this message translates to:
  /// **'Dziennik kalorii'**
  String get diaryTitle;

  /// No description provided for @diaryLoadError.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się załadować dziennika.'**
  String get diaryLoadError;

  /// No description provided for @diaryPreviousDay.
  ///
  /// In pl, this message translates to:
  /// **'Poprzedni dzień'**
  String get diaryPreviousDay;

  /// No description provided for @diaryNextDay.
  ///
  /// In pl, this message translates to:
  /// **'Następny dzień'**
  String get diaryNextDay;

  /// No description provided for @diaryToday.
  ///
  /// In pl, this message translates to:
  /// **'Wróć do dziś'**
  String get diaryToday;

  /// No description provided for @diaryRemainingKcal.
  ///
  /// In pl, this message translates to:
  /// **'kcal pozostało'**
  String get diaryRemainingKcal;

  /// No description provided for @diaryActivity.
  ///
  /// In pl, this message translates to:
  /// **'Dodaj aktywność'**
  String get diaryActivity;

  /// No description provided for @diaryActivityName.
  ///
  /// In pl, this message translates to:
  /// **'Co robiłeś/aś?'**
  String get diaryActivityName;

  /// No description provided for @diaryActivityHint.
  ///
  /// In pl, this message translates to:
  /// **'np. bieganie, rower, siłownia'**
  String get diaryActivityHint;

  /// No description provided for @diaryBurnedCalories.
  ///
  /// In pl, this message translates to:
  /// **'Spalone kalorie'**
  String get diaryBurnedCalories;

  /// No description provided for @diaryOptionalDuration.
  ///
  /// In pl, this message translates to:
  /// **'Czas (opcjonalnie)'**
  String get diaryOptionalDuration;

  /// No description provided for @diaryActivityInvalid.
  ///
  /// In pl, this message translates to:
  /// **'Podaj nazwę i liczbę spalonych kalorii.'**
  String get diaryActivityInvalid;

  /// No description provided for @diaryRecipeNoIngredients.
  ///
  /// In pl, this message translates to:
  /// **'Ten przepis nie ma listy składników do edycji.'**
  String get diaryRecipeNoIngredients;

  /// No description provided for @diaryUpdatedNutrition.
  ///
  /// In pl, this message translates to:
  /// **'Zaktualizowano kaloryczność wpisu'**
  String get diaryUpdatedNutrition;

  /// No description provided for @diarySaveError.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się zapisać zmian'**
  String get diarySaveError;

  /// No description provided for @diaryEditAmount.
  ///
  /// In pl, this message translates to:
  /// **'Edytuj ilość'**
  String get diaryEditAmount;

  /// No description provided for @diaryInvalidAmount.
  ///
  /// In pl, this message translates to:
  /// **'Podaj prawidłową ilość'**
  String get diaryInvalidAmount;

  /// No description provided for @diarySave.
  ///
  /// In pl, this message translates to:
  /// **'Zapisz'**
  String get diarySave;

  /// No description provided for @diaryAmountUpdated.
  ///
  /// In pl, this message translates to:
  /// **'Zaktualizowano ilość i wartości odżywcze'**
  String get diaryAmountUpdated;

  /// No description provided for @diaryAmountSaveError.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się zapisać ilości'**
  String get diaryAmountSaveError;

  /// No description provided for @diaryLoadingWater.
  ///
  /// In pl, this message translates to:
  /// **'Wczytywanie nawodnienia…'**
  String get diaryLoadingWater;

  /// No description provided for @diaryWaterError.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się wczytać nawodnienia.'**
  String get diaryWaterError;

  /// No description provided for @diaryHydration.
  ///
  /// In pl, this message translates to:
  /// **'Nawodnienie'**
  String get diaryHydration;

  /// No description provided for @diaryUndoGlass.
  ///
  /// In pl, this message translates to:
  /// **'Cofnij szklankę'**
  String get diaryUndoGlass;

  /// No description provided for @diaryWaterQuestion.
  ///
  /// In pl, this message translates to:
  /// **'Ile wypiłeś/aś?'**
  String get diaryWaterQuestion;

  /// No description provided for @diaryWaterHint.
  ///
  /// In pl, this message translates to:
  /// **'np. 300'**
  String get diaryWaterHint;

  /// No description provided for @diaryWaterInvalid.
  ///
  /// In pl, this message translates to:
  /// **'Podaj liczbę mililitrów.'**
  String get diaryWaterInvalid;

  /// No description provided for @diaryGlass.
  ///
  /// In pl, this message translates to:
  /// **'Szklanka'**
  String get diaryGlass;

  /// No description provided for @diaryBottle.
  ///
  /// In pl, this message translates to:
  /// **'Butelka'**
  String get diaryBottle;

  /// No description provided for @diaryProtein.
  ///
  /// In pl, this message translates to:
  /// **'Białko'**
  String get diaryProtein;

  /// No description provided for @diaryCarbs.
  ///
  /// In pl, this message translates to:
  /// **'Węgle'**
  String get diaryCarbs;

  /// No description provided for @diaryFat.
  ///
  /// In pl, this message translates to:
  /// **'Tłuszcze'**
  String get diaryFat;

  /// No description provided for @diaryMacroTargets.
  ///
  /// In pl, this message translates to:
  /// **'Optymalny podział dla Twojego celu kcal'**
  String get diaryMacroTargets;

  /// No description provided for @diaryNoMeals.
  ///
  /// In pl, this message translates to:
  /// **'Brak zjedzonych posiłków w tym dniu.'**
  String get diaryNoMeals;

  /// No description provided for @diaryDeleteMeal.
  ///
  /// In pl, this message translates to:
  /// **'Usunąć posiłek?'**
  String get diaryDeleteMeal;

  /// No description provided for @diaryRemoveEntry.
  ///
  /// In pl, this message translates to:
  /// **'Usuń z Dziennika'**
  String get diaryRemoveEntry;

  /// No description provided for @amountPositive.
  ///
  /// In pl, this message translates to:
  /// **'Podaj ilość większą od zera'**
  String get amountPositive;

  /// No description provided for @amountClose.
  ///
  /// In pl, this message translates to:
  /// **'Zamknij'**
  String get amountClose;

  /// No description provided for @amountQuick.
  ///
  /// In pl, this message translates to:
  /// **'Szybki wybór'**
  String get amountQuick;

  /// No description provided for @amountQuickHint.
  ///
  /// In pl, this message translates to:
  /// **'Dotknij wariantu, aby od razu go wybrać.'**
  String get amountQuickHint;

  /// No description provided for @amountCustom.
  ///
  /// In pl, this message translates to:
  /// **'Własna ilość'**
  String get amountCustom;

  /// No description provided for @amountUnit.
  ///
  /// In pl, this message translates to:
  /// **'Jednostka'**
  String get amountUnit;

  /// No description provided for @amountQuantity.
  ///
  /// In pl, this message translates to:
  /// **'Ilość'**
  String get amountQuantity;

  /// No description provided for @amountChoose.
  ///
  /// In pl, this message translates to:
  /// **'Wybierz ilość'**
  String get amountChoose;

  /// No description provided for @amountApproximate.
  ///
  /// In pl, this message translates to:
  /// **'ok. '**
  String get amountApproximate;

  /// No description provided for @measurePack.
  ///
  /// In pl, this message translates to:
  /// **'opakowanie'**
  String get measurePack;

  /// No description provided for @measureServing.
  ///
  /// In pl, this message translates to:
  /// **'porcja'**
  String get measureServing;

  /// No description provided for @measurePiece.
  ///
  /// In pl, this message translates to:
  /// **'sztuka'**
  String get measurePiece;

  /// No description provided for @measureTeaspoon.
  ///
  /// In pl, this message translates to:
  /// **'łyżeczka'**
  String get measureTeaspoon;

  /// No description provided for @measureGlass.
  ///
  /// In pl, this message translates to:
  /// **'szklanka'**
  String get measureGlass;

  /// No description provided for @measureGrams.
  ///
  /// In pl, this message translates to:
  /// **'gramy'**
  String get measureGrams;

  /// No description provided for @measureMillilitres.
  ///
  /// In pl, this message translates to:
  /// **'mililitry'**
  String get measureMillilitres;

  /// No description provided for @nutritionMissing.
  ///
  /// In pl, this message translates to:
  /// **'Brak danych odżywczych'**
  String get nutritionMissing;

  /// No description provided for @recipeNutritionEstimated.
  ///
  /// In pl, this message translates to:
  /// **'Wartości orientacyjne: część składników oszacowano. Mogą różnić się od danych na etykiecie.'**
  String get recipeNutritionEstimated;

  /// No description provided for @recipeNutritionPartial.
  ///
  /// In pl, this message translates to:
  /// **'Niepełne dane. ≥ pokazuje wyłącznie sumę znanych wartości, a nie pełne makro posiłku.'**
  String get recipeNutritionPartial;

  /// No description provided for @recipeNutritionNeedsDetails.
  ///
  /// In pl, this message translates to:
  /// **'Ten przepis ma brakujące dane odżywcze. Uzupełnij składniki w przepisie lub wpisz wartości posiłku ręcznie w Dzienniku.'**
  String get recipeNutritionNeedsDetails;

  /// No description provided for @productsProcessed.
  ///
  /// In pl, this message translates to:
  /// **'Obsłużono: {count} produktów.'**
  String productsProcessed(int count);

  /// No description provided for @productsLoadFailed.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się pobrać produktów: {error}'**
  String productsLoadFailed(String error);

  /// No description provided for @productsDeleteMessage.
  ///
  /// In pl, this message translates to:
  /// **'Usuniesz \"{name}\" ze swoich zgłoszeń. Tej operacji nie da się cofnąć.'**
  String productsDeleteMessage(String name);

  /// No description provided for @productsShopBrand.
  ///
  /// In pl, this message translates to:
  /// **'Marka w sklepie: {brand}'**
  String productsShopBrand(String brand);

  /// No description provided for @productsBrand.
  ///
  /// In pl, this message translates to:
  /// **'Marka produktu: {brand}'**
  String productsBrand(String brand);

  /// No description provided for @productsCheckedOn.
  ///
  /// In pl, this message translates to:
  /// **'cena sprawdzona {date}'**
  String productsCheckedOn(String date);

  /// No description provided for @diaryTodayDate.
  ///
  /// In pl, this message translates to:
  /// **'Dzisiaj, {date}'**
  String diaryTodayDate(String date);

  /// No description provided for @diaryActivityCalories.
  ///
  /// In pl, this message translates to:
  /// **'+{calories} z aktywności'**
  String diaryActivityCalories(String calories);

  /// No description provided for @diaryWaterProgress.
  ///
  /// In pl, this message translates to:
  /// **'{amount} z {goal} ml'**
  String diaryWaterProgress(String amount, String goal);

  /// No description provided for @diaryDeleteMessage.
  ///
  /// In pl, this message translates to:
  /// **'„{name}” zostanie usunięty z Dziennika.'**
  String diaryDeleteMessage(String name);

  /// No description provided for @diaryAmountTimes.
  ///
  /// In pl, this message translates to:
  /// **'Ilość: {amount}×'**
  String diaryAmountTimes(String amount);

  /// No description provided for @diaryPortionSize.
  ///
  /// In pl, this message translates to:
  /// **'1 porcja = {amount} {unit}'**
  String diaryPortionSize(String amount, String unit);

  /// No description provided for @nutritionMacroLine.
  ///
  /// In pl, this message translates to:
  /// **'{kcal} kcal  •  B {protein} g  •  T {fat} g  •  W {carbs} g'**
  String nutritionMacroLine(
    String kcal,
    String protein,
    String fat,
    String carbs,
  );

  /// No description provided for @productFormEdit.
  ///
  /// In pl, this message translates to:
  /// **'Edytuj produkt'**
  String get productFormEdit;

  /// No description provided for @productFormAdd.
  ///
  /// In pl, this message translates to:
  /// **'Dodaj własny produkt'**
  String get productFormAdd;

  /// No description provided for @productFormVisibility.
  ///
  /// In pl, this message translates to:
  /// **'Produkt będzie od razu dostępny dla Ciebie. Pozostali użytkownicy zobaczą go po zatwierdzeniu przez administratora.'**
  String get productFormVisibility;

  /// No description provided for @productFormManualAfterScan.
  ///
  /// In pl, this message translates to:
  /// **'Możesz nadal wpisać dane ręcznie. Kod zostanie zachowany.'**
  String get productFormManualAfterScan;

  /// No description provided for @productFormCatalogFilled.
  ///
  /// In pl, this message translates to:
  /// **'Znaleziono w katalogu — dane wypełnione automatycznie.'**
  String get productFormCatalogFilled;

  /// No description provided for @productFormScanFilled.
  ///
  /// In pl, this message translates to:
  /// **'Znaleziono produkt — nazwa, marka i makro zostały uzupełnione.'**
  String get productFormScanFilled;

  /// No description provided for @productFormEditSaved.
  ///
  /// In pl, this message translates to:
  /// **'Zapisano. Zmiany trafiają ponownie do sprawdzenia przez administratora.'**
  String get productFormEditSaved;

  /// No description provided for @productFormAdded.
  ///
  /// In pl, this message translates to:
  /// **'Produkt dodany. Możesz go już używać; pozostali zobaczą go po zatwierdzeniu przez administratora.'**
  String get productFormAdded;

  /// No description provided for @productFormAlreadyExists.
  ///
  /// In pl, this message translates to:
  /// **'Ten produkt jest już zapisany w bazie. Nie trzeba dodawać go ponownie.'**
  String get productFormAlreadyExists;

  /// No description provided for @productFormCloseExisting.
  ///
  /// In pl, this message translates to:
  /// **'Zamknij — produkt jest już w bazie'**
  String get productFormCloseExisting;

  /// No description provided for @productFormName.
  ///
  /// In pl, this message translates to:
  /// **'Nazwa produktu *'**
  String get productFormName;

  /// No description provided for @productFormNameHint.
  ///
  /// In pl, this message translates to:
  /// **'Wpisz nazwę lub wybierz podpowiedź'**
  String get productFormNameHint;

  /// No description provided for @productFormNameRequired.
  ///
  /// In pl, this message translates to:
  /// **'Podaj nazwę produktu'**
  String get productFormNameRequired;

  /// No description provided for @productFormBrandOptional.
  ///
  /// In pl, this message translates to:
  /// **'Marka (opcjonalnie)'**
  String get productFormBrandOptional;

  /// No description provided for @productFormBrand.
  ///
  /// In pl, this message translates to:
  /// **'Marka'**
  String get productFormBrand;

  /// No description provided for @productFormPrice.
  ///
  /// In pl, this message translates to:
  /// **'Cena widoczna w sklepie (opcjonalnie)'**
  String get productFormPrice;

  /// No description provided for @productFormPriceError.
  ///
  /// In pl, this message translates to:
  /// **'Podaj prawidłową cenę (więcej niż 0, maks. 10 000).'**
  String get productFormPriceError;

  /// No description provided for @productFormUnit.
  ///
  /// In pl, this message translates to:
  /// **'Jedn.'**
  String get productFormUnit;

  /// No description provided for @productFormPack.
  ///
  /// In pl, this message translates to:
  /// **'Masa całego opakowania'**
  String get productFormPack;

  /// No description provided for @productFormPackExample.
  ///
  /// In pl, this message translates to:
  /// **'np. 150'**
  String get productFormPackExample;

  /// No description provided for @productFormPackHelp.
  ///
  /// In pl, this message translates to:
  /// **'Podaj masę netto całego opakowania, nie wielkość porcji. Jeśli jej nie znasz, zostaw pole puste — aplikacja nie pokaże wtedy opcji „opakowanie”.'**
  String get productFormPackHelp;

  /// No description provided for @productFormPackError.
  ///
  /// In pl, this message translates to:
  /// **'Podaj wielkość opakowania większą niż 0, maks. 100 000 g/ml, lub zostaw puste.'**
  String get productFormPackError;

  /// No description provided for @productFormNutritionHelp.
  ///
  /// In pl, this message translates to:
  /// **'Bez pełnych danych produkt nadal przyda się na liście zakupów. Przed dodaniem do dziennika trzeba będzie uzupełnić makro.'**
  String get productFormNutritionHelp;

  /// No description provided for @productFormCalories.
  ///
  /// In pl, this message translates to:
  /// **'Kalorie'**
  String get productFormCalories;

  /// No description provided for @productFormProtein.
  ///
  /// In pl, this message translates to:
  /// **'Białko'**
  String get productFormProtein;

  /// No description provided for @productFormFat.
  ///
  /// In pl, this message translates to:
  /// **'Tłuszcze'**
  String get productFormFat;

  /// No description provided for @productFormCarbs.
  ///
  /// In pl, this message translates to:
  /// **'Węglow.'**
  String get productFormCarbs;

  /// No description provided for @productFormShops.
  ///
  /// In pl, this message translates to:
  /// **'W jakich sklepach ma być dostępny? (opcjonalnie)'**
  String get productFormShops;

  /// No description provided for @productFormShopsHelp.
  ///
  /// In pl, this message translates to:
  /// **'Można zaznaczyć kilka. Widoczność w wybranych sklepach pojawi się dopiero po akceptacji.'**
  String get productFormShopsHelp;

  /// No description provided for @productFormSaveChanges.
  ///
  /// In pl, this message translates to:
  /// **'Zapisz zmiany'**
  String get productFormSaveChanges;

  /// No description provided for @productFormSave.
  ///
  /// In pl, this message translates to:
  /// **'Dodaj produkt'**
  String get productFormSave;

  /// No description provided for @productFormNumberError.
  ///
  /// In pl, this message translates to:
  /// **'Podaj prawidłową liczbę.'**
  String get productFormNumberError;

  /// No description provided for @productFormRequestFailed.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się zapisać produktu. Dane zostały zachowane — spróbuj ponownie.'**
  String get productFormRequestFailed;

  /// No description provided for @productLabelTitle.
  ///
  /// In pl, this message translates to:
  /// **'Dodaj brakujący produkt'**
  String get productLabelTitle;

  /// No description provided for @productLabelTakePhoto.
  ///
  /// In pl, this message translates to:
  /// **'Zrób zdjęcie'**
  String get productLabelTakePhoto;

  /// No description provided for @productLabelGallery.
  ///
  /// In pl, this message translates to:
  /// **'Wybierz z galerii'**
  String get productLabelGallery;

  /// No description provided for @productLabelBothPhotos.
  ///
  /// In pl, this message translates to:
  /// **'Dodaj oba zdjęcia: przód i tabelę wartości.'**
  String get productLabelBothPhotos;

  /// No description provided for @productLabelNameError.
  ///
  /// In pl, this message translates to:
  /// **'Sprawdź i uzupełnij nazwę produktu (2–300 znaków).'**
  String get productLabelNameError;

  /// No description provided for @productLabelReading.
  ///
  /// In pl, this message translates to:
  /// **'Odczytywanie etykiety…'**
  String get productLabelReading;

  /// No description provided for @productLabelRead.
  ///
  /// In pl, this message translates to:
  /// **'Odczytaj dane'**
  String get productLabelRead;

  /// No description provided for @productLabelFront.
  ///
  /// In pl, this message translates to:
  /// **'Przód opakowania'**
  String get productLabelFront;

  /// No description provided for @productLabelNutrition.
  ///
  /// In pl, this message translates to:
  /// **'Tabela wartości'**
  String get productLabelNutrition;

  /// No description provided for @productLabelReview.
  ///
  /// In pl, this message translates to:
  /// **'Sprawdź dane przed zapisaniem'**
  String get productLabelReview;

  /// No description provided for @productLabelConfirm.
  ///
  /// In pl, this message translates to:
  /// **'Potwierdź i zapisz'**
  String get productLabelConfirm;

  /// No description provided for @productLabelMissingNutrition.
  ///
  /// In pl, this message translates to:
  /// **'Uzupełnij kcal, białko, tłuszcz i węglowodany na 100 g/ml.'**
  String get productLabelMissingNutrition;

  /// No description provided for @productLabelReadFailed.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się odczytać etykiety. Zdjęcia zostały zachowane — spróbuj ponownie.'**
  String get productLabelReadFailed;

  /// No description provided for @productLabelPhotoFailed.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się otworzyć zdjęcia. Sprawdź dostęp do aparatu lub galerii i spróbuj ponownie.'**
  String get productLabelPhotoFailed;

  /// No description provided for @productFormBrandError.
  ///
  /// In pl, this message translates to:
  /// **'Marka może mieć maksymalnie 200 znaków.'**
  String get productFormBrandError;

  /// No description provided for @productFormScanned.
  ///
  /// In pl, this message translates to:
  /// **'Zeskanowano: {code} (zmień)'**
  String productFormScanned(String code);

  /// No description provided for @productFormTypicalPrice.
  ///
  /// In pl, this message translates to:
  /// **'Typowy zakres cen: {minimum}–{maximum} zł'**
  String productFormTypicalPrice(String minimum, String maximum);

  /// No description provided for @productFormReward.
  ///
  /// In pl, this message translates to:
  /// **'Produkt dodany • +{points} punkt Premium'**
  String productFormReward(int points);

  /// No description provided for @productFormBalance.
  ///
  /// In pl, this message translates to:
  /// **' • saldo: {points}'**
  String productFormBalance(int points);

  /// No description provided for @productFormNutrition.
  ///
  /// In pl, this message translates to:
  /// **'Wartości odżywcze na 100 {unit} (opcjonalnie)'**
  String productFormNutrition(String unit);

  /// No description provided for @productLabelIntro.
  ///
  /// In pl, this message translates to:
  /// **'Brakuje pełnych danych dla kodu {code}. Dwa wyraźne zdjęcia pozwolą odczytać je bez ręcznego przepisywania.'**
  String productLabelIntro(String code);

  /// No description provided for @productLabelPer100.
  ///
  /// In pl, this message translates to:
  /// **'Wartości na 100 {unit}'**
  String productLabelPer100(String unit);

  /// No description provided for @productFormNumberRange.
  ///
  /// In pl, this message translates to:
  /// **'Podaj liczbę od 0 do {maximum}.'**
  String productFormNumberRange(String maximum);

  /// No description provided for @productFormChooseUnit.
  ///
  /// In pl, this message translates to:
  /// **'Wybierz gramy lub mililitry dla wielkości opakowania.'**
  String get productFormChooseUnit;

  /// No description provided for @productFormLookupFailed.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się wyszukać produktu. Kod zachowano — możesz wpisać dane ręcznie.'**
  String get productFormLookupFailed;

  /// No description provided for @detailTikTokFailed.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się otworzyć profilu TikTok.'**
  String get detailTikTokFailed;

  /// No description provided for @detailAiUpdated.
  ///
  /// In pl, this message translates to:
  /// **'Przepis został zmieniony przez AI.'**
  String get detailAiUpdated;

  /// No description provided for @detailAiAction.
  ///
  /// In pl, this message translates to:
  /// **'Dostosuj przepis z AI · 1 pkt'**
  String get detailAiAction;

  /// No description provided for @detailRecipeAuthor.
  ///
  /// In pl, this message translates to:
  /// **'autora przepisu'**
  String get detailRecipeAuthor;

  /// No description provided for @detailTime.
  ///
  /// In pl, this message translates to:
  /// **'Czas'**
  String get detailTime;

  /// No description provided for @detailServings.
  ///
  /// In pl, this message translates to:
  /// **'Porcje'**
  String get detailServings;

  /// No description provided for @detailNutrition.
  ///
  /// In pl, this message translates to:
  /// **'Wartości odżywcze'**
  String get detailNutrition;

  /// No description provided for @detailPerServing.
  ///
  /// In pl, this message translates to:
  /// **'na 1 porcję'**
  String get detailPerServing;

  /// No description provided for @detailChange.
  ///
  /// In pl, this message translates to:
  /// **'Zmień'**
  String get detailChange;

  /// No description provided for @detailLoading.
  ///
  /// In pl, this message translates to:
  /// **'Ładowanie składników i sposobu przygotowania…'**
  String get detailLoading;

  /// No description provided for @detailRetry.
  ///
  /// In pl, this message translates to:
  /// **'Spróbuj ponownie wczytać szczegóły'**
  String get detailRetry;

  /// No description provided for @detailTemporary.
  ///
  /// In pl, this message translates to:
  /// **'Wariant tymczasowy'**
  String get detailTemporary;

  /// No description provided for @detailTemporaryHelp.
  ///
  /// In pl, this message translates to:
  /// **'Oryginalny przepis nie został zmieniony. Przy tworzeniu listy zakupów ten wariant zapisze się w Moje, aby lista zawierała widoczne tutaj składniki i ilości. Po zapisie przeliczymy wartości odżywcze.'**
  String get detailTemporaryHelp;

  /// No description provided for @detailSaveVariant.
  ///
  /// In pl, this message translates to:
  /// **'Zapisz wariant w Moje'**
  String get detailSaveVariant;

  /// No description provided for @detailUndo.
  ///
  /// In pl, this message translates to:
  /// **'Cofnij zmiany'**
  String get detailUndo;

  /// No description provided for @detailIngredient.
  ///
  /// In pl, this message translates to:
  /// **'Składnik'**
  String get detailIngredient;

  /// No description provided for @detailPastaTitle.
  ///
  /// In pl, this message translates to:
  /// **'Lifehack: porcja makaronu bez wagi'**
  String get detailPastaTitle;

  /// No description provided for @detailPastaHelp.
  ///
  /// In pl, this message translates to:
  /// **'Chwyć suchy makaron w dwa palce, formując kółko — jeśli jego średnica odpowiada mniej więcej monecie 5 zł, to jedna porcja (ok. 80-100 g) na osobę.'**
  String get detailPastaHelp;

  /// No description provided for @detailMethod.
  ///
  /// In pl, this message translates to:
  /// **'Sposób przygotowania'**
  String get detailMethod;

  /// No description provided for @detailAlsoAdd.
  ///
  /// In pl, this message translates to:
  /// **'Możesz też dodać'**
  String get detailAlsoAdd;

  /// No description provided for @detailSeasoningHelp.
  ///
  /// In pl, this message translates to:
  /// **'opcjonalne przyprawy, żeby wzbogacić smak'**
  String get detailSeasoningHelp;

  /// No description provided for @detailFiber.
  ///
  /// In pl, this message translates to:
  /// **'Błonnik'**
  String get detailFiber;

  /// No description provided for @variantTitle.
  ///
  /// In pl, this message translates to:
  /// **'Zmień składniki'**
  String get variantTitle;

  /// No description provided for @variantHelp.
  ///
  /// In pl, this message translates to:
  /// **'Zmiany są tymczasowe. Oryginalny przepis pozostanie bez zmian.'**
  String get variantHelp;

  /// No description provided for @variantAlreadyAdded.
  ///
  /// In pl, this message translates to:
  /// **'Ten produkt jest już na liście.'**
  String get variantAlreadyAdded;

  /// No description provided for @variantRemove.
  ///
  /// In pl, this message translates to:
  /// **'Usuń składnik'**
  String get variantRemove;

  /// No description provided for @variantApply.
  ///
  /// In pl, this message translates to:
  /// **'Zastosuj tymczasowo'**
  String get variantApply;

  /// No description provided for @variantQuantityError.
  ///
  /// In pl, this message translates to:
  /// **'Wpisz ilość większą od zera, nie większą niż {maximum}.'**
  String variantQuantityError(int maximum);

  /// No description provided for @aiEditTitle.
  ///
  /// In pl, this message translates to:
  /// **'Dostosuj przepis z AI'**
  String get aiEditTitle;

  /// No description provided for @aiEditPromptLabel.
  ///
  /// In pl, this message translates to:
  /// **'Co zmienić lub dodać?'**
  String get aiEditPromptLabel;

  /// No description provided for @aiEditPromptHint.
  ///
  /// In pl, this message translates to:
  /// **'Np. zamień kurczaka na tofu i zmień kroki przygotowania'**
  String get aiEditPromptHint;

  /// No description provided for @aiEditBuyPoints.
  ///
  /// In pl, this message translates to:
  /// **'Kup punkty'**
  String get aiEditBuyPoints;

  /// No description provided for @aiEditSubmit.
  ///
  /// In pl, this message translates to:
  /// **'Zmień przepis · 1 pkt'**
  String get aiEditSubmit;

  /// No description provided for @detailFavoriteError.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się zaktualizować ulubionych'**
  String get detailFavoriteError;

  /// No description provided for @detailRemoveFavorite.
  ///
  /// In pl, this message translates to:
  /// **'Usuń z ulubionych'**
  String get detailRemoveFavorite;

  /// No description provided for @detailAddFavorite.
  ///
  /// In pl, this message translates to:
  /// **'Dodaj do ulubionych'**
  String get detailAddFavorite;

  /// No description provided for @detailDeleteTitle.
  ///
  /// In pl, this message translates to:
  /// **'Usunąć przepis?'**
  String get detailDeleteTitle;

  /// No description provided for @detailDeletePublicHelp.
  ///
  /// In pl, this message translates to:
  /// **'Ten przepis jest widoczny dla wszystkich — usunięcie go usunie go też z list zakupów i planów innych osób, które go używały. Tej operacji nie da się cofnąć.'**
  String get detailDeletePublicHelp;

  /// No description provided for @detailDeleteHelp.
  ///
  /// In pl, this message translates to:
  /// **'Tej operacji nie da się cofnąć.'**
  String get detailDeleteHelp;

  /// No description provided for @detailDeleteFailed.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się usunąć przepisu'**
  String get detailDeleteFailed;

  /// No description provided for @detailDelete.
  ///
  /// In pl, this message translates to:
  /// **'Usuń przepis'**
  String get detailDelete;

  /// No description provided for @detailPublishTitle.
  ///
  /// In pl, this message translates to:
  /// **'Opublikować przepis?'**
  String get detailPublishTitle;

  /// No description provided for @detailPublishHelp.
  ///
  /// In pl, this message translates to:
  /// **'Przepis trafi do kolejki oczekującej na akceptację administratora. Po zatwierdzeniu będzie widoczny dla wszystkich użytkowników aplikacji.'**
  String get detailPublishHelp;

  /// No description provided for @detailPublishSubmit.
  ///
  /// In pl, this message translates to:
  /// **'Opublikuj'**
  String get detailPublishSubmit;

  /// No description provided for @detailPublishSent.
  ///
  /// In pl, this message translates to:
  /// **'Przepis zgłoszony — czeka na akceptację administratora.'**
  String get detailPublishSent;

  /// No description provided for @detailPublishFailed.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się opublikować przepisu.'**
  String get detailPublishFailed;

  /// No description provided for @detailPublish.
  ///
  /// In pl, this message translates to:
  /// **'Opublikuj przepis'**
  String get detailPublish;

  /// No description provided for @detailShopping.
  ///
  /// In pl, this message translates to:
  /// **'Lista zakupów na to danie'**
  String get detailShopping;

  /// No description provided for @detailChooseShop.
  ///
  /// In pl, this message translates to:
  /// **'Wybierz najpierw sklep w swoim profilu'**
  String get detailChooseShop;

  /// No description provided for @detailPhotoSent.
  ///
  /// In pl, this message translates to:
  /// **'Dziękujemy! Zdjęcie pojawi się po akceptacji przez administratora.'**
  String get detailPhotoSent;

  /// No description provided for @detailPhotoReplaceHelp.
  ///
  /// In pl, this message translates to:
  /// **'Ten przepis ma już zdjęcie. Jeśli Twoje zostanie zaakceptowane, zastąpi obecne.'**
  String get detailPhotoReplaceHelp;

  /// No description provided for @detailPhotoSending.
  ///
  /// In pl, this message translates to:
  /// **'Wysyłanie…'**
  String get detailPhotoSending;

  /// No description provided for @detailPhotoReplace.
  ///
  /// In pl, this message translates to:
  /// **'Zaproponuj inne zdjęcie'**
  String get detailPhotoReplace;

  /// No description provided for @detailPhotoAdd.
  ///
  /// In pl, this message translates to:
  /// **'Dodaj zdjęcie'**
  String get detailPhotoAdd;

  /// No description provided for @detailAiPhoto.
  ///
  /// In pl, this message translates to:
  /// **'Zdjęcie poglądowe, wygenerowane przez AI'**
  String get detailAiPhoto;

  /// No description provided for @detailSavedVariant.
  ///
  /// In pl, this message translates to:
  /// **'Zapisano w Moje jako „{name}”.'**
  String detailSavedVariant(String name);

  /// No description provided for @detailAddedBy.
  ///
  /// In pl, this message translates to:
  /// **'Dodane przez {name}'**
  String detailAddedBy(String name);

  /// No description provided for @variantAmount.
  ///
  /// In pl, this message translates to:
  /// **'Ilość ({unit})'**
  String variantAmount(String unit);

  /// No description provided for @variantBrand.
  ///
  /// In pl, this message translates to:
  /// **'Marka: {brand}'**
  String variantBrand(String brand);

  /// No description provided for @aiEditIntro.
  ///
  /// In pl, this message translates to:
  /// **'Napisz, co zmienić w „{name}”. Możesz np. poprosić o wersję bez mleka albo dodać konkretny składnik.'**
  String aiEditIntro(String name);

  /// No description provided for @aiEditCost.
  ///
  /// In pl, this message translates to:
  /// **'Udana zmiana kosztuje 1 punkt premium. Masz: {points} pkt.'**
  String aiEditCost(int points);

  /// No description provided for @detailExistingLists.
  ///
  /// In pl, this message translates to:
  /// **'Masz już {count} {word} — dodaj do niej, albo stwórz nową.'**
  String detailExistingLists(int count, String word);

  /// No description provided for @detailListItems.
  ///
  /// In pl, this message translates to:
  /// **'{count} pozycji'**
  String detailListItems(int count);

  /// No description provided for @variantSearchHint.
  ///
  /// In pl, this message translates to:
  /// **'Wpisz nazwę produktu'**
  String get variantSearchHint;

  /// No description provided for @detailAddToList.
  ///
  /// In pl, this message translates to:
  /// **'Dodaj do listy zakupów'**
  String get detailAddToList;

  /// No description provided for @detailCreateList.
  ///
  /// In pl, this message translates to:
  /// **'Stwórz nową listę'**
  String get detailCreateList;

  /// No description provided for @productsOnlineCatalogue.
  ///
  /// In pl, this message translates to:
  /// **'Katalog online — dostępność lokalna może się różnić'**
  String get productsOnlineCatalogue;

  /// No description provided for @productsGenericFood.
  ///
  /// In pl, this message translates to:
  /// **'Produkt ogólny — sprawdź dostępność w sklepie'**
  String get productsGenericFood;

  /// No description provided for @productsNationalAverage.
  ///
  /// In pl, this message translates to:
  /// **'Średnia UK, nie cena sklepowa'**
  String get productsNationalAverage;

  /// No description provided for @productsPriceUnavailable.
  ///
  /// In pl, this message translates to:
  /// **'Brak ceny'**
  String get productsPriceUnavailable;

  /// No description provided for @commentsLoadFailed.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się załadować komentarzy'**
  String get commentsLoadFailed;

  /// No description provided for @commentsPhotoFailed.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się pobrać zdjęcia'**
  String get commentsPhotoFailed;

  /// No description provided for @commentsCamera.
  ///
  /// In pl, this message translates to:
  /// **'Zrób zdjęcie'**
  String get commentsCamera;

  /// No description provided for @commentsGallery.
  ///
  /// In pl, this message translates to:
  /// **'Wybierz z galerii'**
  String get commentsGallery;

  /// No description provided for @commentsDeleteTitle.
  ///
  /// In pl, this message translates to:
  /// **'Usunąć komentarz?'**
  String get commentsDeleteTitle;

  /// No description provided for @commentsDeleteBody.
  ///
  /// In pl, this message translates to:
  /// **'Tej operacji nie da się cofnąć.'**
  String get commentsDeleteBody;

  /// No description provided for @commentsCancel.
  ///
  /// In pl, this message translates to:
  /// **'Anuluj'**
  String get commentsCancel;

  /// No description provided for @commentsDelete.
  ///
  /// In pl, this message translates to:
  /// **'Usuń'**
  String get commentsDelete;

  /// No description provided for @commentsDeleteFailed.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się usunąć komentarza'**
  String get commentsDeleteFailed;

  /// No description provided for @commentsLikeFailed.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się zapisać polubienia'**
  String get commentsLikeFailed;

  /// No description provided for @commentsJustNow.
  ///
  /// In pl, this message translates to:
  /// **'przed chwilą'**
  String get commentsJustNow;

  /// No description provided for @commentsTitle.
  ///
  /// In pl, this message translates to:
  /// **'Komentarze i zdjęcia'**
  String get commentsTitle;

  /// No description provided for @commentsFirst.
  ///
  /// In pl, this message translates to:
  /// **'Bądź pierwszą osobą, która skomentuje ten przepis'**
  String get commentsFirst;

  /// No description provided for @commentsHint.
  ///
  /// In pl, this message translates to:
  /// **'Podziel się swoją opinią lub wskazówką...'**
  String get commentsHint;

  /// No description provided for @commentsPhoto.
  ///
  /// In pl, this message translates to:
  /// **'Dodaj zdjęcie'**
  String get commentsPhoto;

  /// No description provided for @commentsAdd.
  ///
  /// In pl, this message translates to:
  /// **'Dodaj'**
  String get commentsAdd;

  /// No description provided for @commentsDeleteTooltip.
  ///
  /// In pl, this message translates to:
  /// **'Usuń komentarz'**
  String get commentsDeleteTooltip;

  /// No description provided for @commentsModerateTooltip.
  ///
  /// In pl, this message translates to:
  /// **'Usuń komentarz (moderacja)'**
  String get commentsModerateTooltip;

  /// No description provided for @reportTitle.
  ///
  /// In pl, this message translates to:
  /// **'Zgłoś treść'**
  String get reportTitle;

  /// No description provided for @reportReason.
  ///
  /// In pl, this message translates to:
  /// **'Powód zgłoszenia:'**
  String get reportReason;

  /// No description provided for @reportDetails.
  ///
  /// In pl, this message translates to:
  /// **'Dodatkowe szczegóły (opcjonalnie)'**
  String get reportDetails;

  /// No description provided for @reportSend.
  ///
  /// In pl, this message translates to:
  /// **'Zgłoś'**
  String get reportSend;

  /// No description provided for @reportThanks.
  ///
  /// In pl, this message translates to:
  /// **'Dziękujemy za zgłoszenie. Nasz zespół je sprawdzi.'**
  String get reportThanks;

  /// No description provided for @reportFailed.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się wysłać zgłoszenia. Spróbuj ponownie.'**
  String get reportFailed;

  /// No description provided for @reportSpam.
  ///
  /// In pl, this message translates to:
  /// **'Spam albo reklama'**
  String get reportSpam;

  /// No description provided for @reportInappropriate.
  ///
  /// In pl, this message translates to:
  /// **'Treść nieodpowiednia'**
  String get reportInappropriate;

  /// No description provided for @reportHarassment.
  ///
  /// In pl, this message translates to:
  /// **'Nękanie albo mowa nienawiści'**
  String get reportHarassment;

  /// No description provided for @reportMisinformation.
  ///
  /// In pl, this message translates to:
  /// **'Fałszywe informacje'**
  String get reportMisinformation;

  /// No description provided for @reportOther.
  ///
  /// In pl, this message translates to:
  /// **'Inny powód'**
  String get reportOther;

  /// No description provided for @blockTitle.
  ///
  /// In pl, this message translates to:
  /// **'Zablokować tego użytkownika?'**
  String get blockTitle;

  /// No description provided for @blockAction.
  ///
  /// In pl, this message translates to:
  /// **'Zablokuj'**
  String get blockAction;

  /// No description provided for @blockAuthor.
  ///
  /// In pl, this message translates to:
  /// **'Zablokuj autora'**
  String get blockAuthor;

  /// No description provided for @blockFailed.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się zablokować użytkownika.'**
  String get blockFailed;

  /// No description provided for @commentsMinutes.
  ///
  /// In pl, this message translates to:
  /// **'{count} min temu'**
  String commentsMinutes(int count);

  /// No description provided for @commentsHours.
  ///
  /// In pl, this message translates to:
  /// **'{count} godz. temu'**
  String commentsHours(int count);

  /// No description provided for @commentsDays.
  ///
  /// In pl, this message translates to:
  /// **'{count} dni temu'**
  String commentsDays(int count);

  /// No description provided for @commentsCount.
  ///
  /// In pl, this message translates to:
  /// **'{count, plural, one{1 komentarz} few{{count} komentarze} many{{count} komentarzy} other{{count} komentarza}}'**
  String commentsCount(int count);

  /// No description provided for @blockBody.
  ///
  /// In pl, this message translates to:
  /// **'Nie będziesz już widzieć przepisów ani komentarzy od \"{name}\". Możesz cofnąć blokadę w dowolnym momencie w Profil → Zablokowani użytkownicy.'**
  String blockBody(String name);

  /// No description provided for @blockDone.
  ///
  /// In pl, this message translates to:
  /// **'Użytkownik \"{name}\" został zablokowany.'**
  String blockDone(String name);

  /// No description provided for @profileTitle.
  ///
  /// In pl, this message translates to:
  /// **'Profil'**
  String get profileTitle;

  /// No description provided for @profileNone.
  ///
  /// In pl, this message translates to:
  /// **'Brak'**
  String get profileNone;

  /// No description provided for @profileShop.
  ///
  /// In pl, this message translates to:
  /// **'Sklep'**
  String get profileShop;

  /// No description provided for @profileUser.
  ///
  /// In pl, this message translates to:
  /// **'Użytkownik'**
  String get profileUser;

  /// No description provided for @profileExpiryToday.
  ///
  /// In pl, this message translates to:
  /// **'Subskrypcja wygasa dziś'**
  String get profileExpiryToday;

  /// No description provided for @profileHealth.
  ///
  /// In pl, this message translates to:
  /// **'Zdrowie i cele'**
  String get profileHealth;

  /// No description provided for @profileCommunity.
  ///
  /// In pl, this message translates to:
  /// **'Społeczność'**
  String get profileCommunity;

  /// No description provided for @profileFriends.
  ///
  /// In pl, this message translates to:
  /// **'Znajomi'**
  String get profileFriends;

  /// No description provided for @profileFriendsHint.
  ///
  /// In pl, this message translates to:
  /// **'Zaproszenia, przepisy i listy zakupów'**
  String get profileFriendsHint;

  /// No description provided for @profileSubscription.
  ///
  /// In pl, this message translates to:
  /// **'Subskrypcja'**
  String get profileSubscription;

  /// No description provided for @profileUpgrade.
  ///
  /// In pl, this message translates to:
  /// **'Zostań Premium'**
  String get profileUpgrade;

  /// No description provided for @profileUpgradeHint.
  ///
  /// In pl, this message translates to:
  /// **'Automatyczny plan tygodnia, seryjne skanowanie i listy bez limitu'**
  String get profileUpgradeHint;

  /// No description provided for @profileCompare.
  ///
  /// In pl, this message translates to:
  /// **'Porównanie planów'**
  String get profileCompare;

  /// No description provided for @profilePreferences.
  ///
  /// In pl, this message translates to:
  /// **'Preferencje'**
  String get profilePreferences;

  /// No description provided for @profilePreferredShop.
  ///
  /// In pl, this message translates to:
  /// **'Preferowany sklep'**
  String get profilePreferredShop;

  /// No description provided for @profileDiet.
  ///
  /// In pl, this message translates to:
  /// **'Rodzaj diety'**
  String get profileDiet;

  /// No description provided for @profileHousehold.
  ///
  /// In pl, this message translates to:
  /// **'Liczba osób w gospodarstwie'**
  String get profileHousehold;

  /// No description provided for @profileLikes.
  ///
  /// In pl, this message translates to:
  /// **'Lubię / Nie lubię'**
  String get profileLikes;

  /// No description provided for @profileArchive.
  ///
  /// In pl, this message translates to:
  /// **'Archiwum planów'**
  String get profileArchive;

  /// No description provided for @profileArchiveHint.
  ///
  /// In pl, this message translates to:
  /// **'Premium · podgląd i wznowienie'**
  String get profileArchiveHint;

  /// No description provided for @profileDarkMode.
  ///
  /// In pl, this message translates to:
  /// **'Tryb ciemny'**
  String get profileDarkMode;

  /// No description provided for @profilePrivacy.
  ///
  /// In pl, this message translates to:
  /// **'Konto i prywatność'**
  String get profilePrivacy;

  /// No description provided for @profileAddUsername.
  ///
  /// In pl, this message translates to:
  /// **'Dodaj nazwę użytkownika'**
  String get profileAddUsername;

  /// No description provided for @profileLogout.
  ///
  /// In pl, this message translates to:
  /// **'Wyloguj się'**
  String get profileLogout;

  /// No description provided for @profileBlocked.
  ///
  /// In pl, this message translates to:
  /// **'Zablokowani użytkownicy'**
  String get profileBlocked;

  /// No description provided for @profileDelete.
  ///
  /// In pl, this message translates to:
  /// **'Usuń konto'**
  String get profileDelete;

  /// No description provided for @profileAdmin.
  ///
  /// In pl, this message translates to:
  /// **'Panel administratora'**
  String get profileAdmin;

  /// No description provided for @profileChooseShop.
  ///
  /// In pl, this message translates to:
  /// **'Wybierz sklep'**
  String get profileChooseShop;

  /// No description provided for @profileHealthTitle.
  ///
  /// In pl, this message translates to:
  /// **'Waga, wzrost i cel kaloryczny'**
  String get profileHealthTitle;

  /// No description provided for @profileHealthHint.
  ///
  /// In pl, this message translates to:
  /// **'Uzupełnij dane, aby obliczyć BMI i zapotrzebowanie'**
  String get profileHealthHint;

  /// No description provided for @profileBmiLow.
  ///
  /// In pl, this message translates to:
  /// **'niedowaga'**
  String get profileBmiLow;

  /// No description provided for @profileBmiNormal.
  ///
  /// In pl, this message translates to:
  /// **'waga prawidłowa'**
  String get profileBmiNormal;

  /// No description provided for @profileBmiHigh.
  ///
  /// In pl, this message translates to:
  /// **'nadwaga'**
  String get profileBmiHigh;

  /// No description provided for @profileBmiObese.
  ///
  /// In pl, this message translates to:
  /// **'otyłość'**
  String get profileBmiObese;

  /// No description provided for @profileMeasurementDate.
  ///
  /// In pl, this message translates to:
  /// **'Data pomiaru'**
  String get profileMeasurementDate;

  /// No description provided for @profileSelect.
  ///
  /// In pl, this message translates to:
  /// **'Wybierz'**
  String get profileSelect;

  /// No description provided for @profileWeightInvalid.
  ///
  /// In pl, this message translates to:
  /// **'Podaj prawidłową wagę od 0,1 do 400 kg.'**
  String get profileWeightInvalid;

  /// No description provided for @profileWeightTitle.
  ///
  /// In pl, this message translates to:
  /// **'Śledzenie wagi'**
  String get profileWeightTitle;

  /// No description provided for @profileWeightHint.
  ///
  /// In pl, this message translates to:
  /// **'Zapisz pomiar dla wybranego dnia. Ponowny zapis poprawi wpis z tej samej daty.'**
  String get profileWeightHint;

  /// No description provided for @profileWeightOptional.
  ///
  /// In pl, this message translates to:
  /// **'Waga (opcjonalnie)'**
  String get profileWeightOptional;

  /// No description provided for @profileSaveMeasurement.
  ///
  /// In pl, this message translates to:
  /// **'Zapisz pomiar'**
  String get profileSaveMeasurement;

  /// No description provided for @profileStatistics.
  ///
  /// In pl, this message translates to:
  /// **'Statystyki'**
  String get profileStatistics;

  /// No description provided for @profilePhotoFailed.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się zapisać zdjęcia'**
  String get profilePhotoFailed;

  /// No description provided for @profileAvatar.
  ///
  /// In pl, this message translates to:
  /// **'Wybierz awatar'**
  String get profileAvatar;

  /// No description provided for @profileGallery.
  ///
  /// In pl, this message translates to:
  /// **'Z galerii'**
  String get profileGallery;

  /// No description provided for @profileAvatarOr.
  ///
  /// In pl, this message translates to:
  /// **'albo wybierz ikonę'**
  String get profileAvatarOr;

  /// No description provided for @profileFemale.
  ///
  /// In pl, this message translates to:
  /// **'Kobieta'**
  String get profileFemale;

  /// No description provided for @profileMale.
  ///
  /// In pl, this message translates to:
  /// **'Mężczyzna'**
  String get profileMale;

  /// No description provided for @profileNicknameTitle.
  ///
  /// In pl, this message translates to:
  /// **'Zmień pseudonim'**
  String get profileNicknameTitle;

  /// No description provided for @profileNickname.
  ///
  /// In pl, this message translates to:
  /// **'Pseudonim'**
  String get profileNickname;

  /// No description provided for @profileSave.
  ///
  /// In pl, this message translates to:
  /// **'Zapisz'**
  String get profileSave;

  /// No description provided for @profileNicknameSaved.
  ///
  /// In pl, this message translates to:
  /// **'Pseudonim zaktualizowany.'**
  String get profileNicknameSaved;

  /// No description provided for @profileNicknameFailed.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się zmienić pseudonimu.'**
  String get profileNicknameFailed;

  /// No description provided for @profileTikTokFailed.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się otworzyć profilu TikTok.'**
  String get profileTikTokFailed;

  /// No description provided for @profileTikTokAdd.
  ///
  /// In pl, this message translates to:
  /// **'Dodaj TikTok'**
  String get profileTikTokAdd;

  /// No description provided for @profileTikTokEdit.
  ///
  /// In pl, this message translates to:
  /// **'Edytuj TikTok'**
  String get profileTikTokEdit;

  /// No description provided for @profileTikTokUsername.
  ///
  /// In pl, this message translates to:
  /// **'Nazwa użytkownika TikTok'**
  String get profileTikTokUsername;

  /// No description provided for @profileTikTokPlaceholder.
  ///
  /// In pl, this message translates to:
  /// **'@twojanazwa'**
  String get profileTikTokPlaceholder;

  /// No description provided for @profileTikTokHelp.
  ///
  /// In pl, this message translates to:
  /// **'Możesz wkleić także pełny link do profilu.'**
  String get profileTikTokHelp;

  /// No description provided for @profileTikTokInvalid.
  ///
  /// In pl, this message translates to:
  /// **'Wpisz 2–24 znaki: litery, cyfry, kropki lub podkreślenia.'**
  String get profileTikTokInvalid;

  /// No description provided for @profileTikTokRemoved.
  ///
  /// In pl, this message translates to:
  /// **'Usunięto nazwę TikTok.'**
  String get profileTikTokRemoved;

  /// No description provided for @profileTikTokSaved.
  ///
  /// In pl, this message translates to:
  /// **'Dodano odnośnik do profilu TikTok.'**
  String get profileTikTokSaved;

  /// No description provided for @profileTikTokSaveFailed.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się zapisać nazwy TikTok.'**
  String get profileTikTokSaveFailed;

  /// No description provided for @profileDeleteTitle.
  ///
  /// In pl, this message translates to:
  /// **'Usunąć konto na stałe?'**
  String get profileDeleteTitle;

  /// No description provided for @profileNext.
  ///
  /// In pl, this message translates to:
  /// **'Dalej'**
  String get profileNext;

  /// No description provided for @profileDeleteFinal.
  ///
  /// In pl, this message translates to:
  /// **'Ostatnie potwierdzenie'**
  String get profileDeleteFinal;

  /// No description provided for @profileDeleteFinalBody.
  ///
  /// In pl, this message translates to:
  /// **'Na pewno? Tej operacji nie da się cofnąć.'**
  String get profileDeleteFinalBody;

  /// No description provided for @profileDeleteFailed.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się usunąć konta. Spróbuj ponownie.'**
  String get profileDeleteFailed;

  /// No description provided for @profileDietAny.
  ///
  /// In pl, this message translates to:
  /// **'Bez ograniczeń'**
  String get profileDietAny;

  /// No description provided for @profileDietVegetarian.
  ///
  /// In pl, this message translates to:
  /// **'Wegetariańska'**
  String get profileDietVegetarian;

  /// No description provided for @profileDietVegan.
  ///
  /// In pl, this message translates to:
  /// **'Wegańska'**
  String get profileDietVegan;

  /// No description provided for @profileDietKeto.
  ///
  /// In pl, this message translates to:
  /// **'Keto'**
  String get profileDietKeto;

  /// No description provided for @profileDietLactose.
  ///
  /// In pl, this message translates to:
  /// **'Bez laktozy'**
  String get profileDietLactose;

  /// No description provided for @documentContact.
  ///
  /// In pl, this message translates to:
  /// **'Kontakt'**
  String get documentContact;

  /// No description provided for @documentEmailBody.
  ///
  /// In pl, this message translates to:
  /// **'Napisz do nas na adres:'**
  String get documentEmailBody;

  /// No description provided for @documentCopy.
  ///
  /// In pl, this message translates to:
  /// **'Kopiuj adres'**
  String get documentCopy;

  /// No description provided for @documentClose.
  ///
  /// In pl, this message translates to:
  /// **'Zamknij'**
  String get documentClose;

  /// No description provided for @documentOpenFailed.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się otworzyć dokumentu. Spróbuj ponownie.'**
  String get documentOpenFailed;

  /// No description provided for @documentTerms.
  ///
  /// In pl, this message translates to:
  /// **'Regulamin (EULA)'**
  String get documentTerms;

  /// No description provided for @documentPrivacy.
  ///
  /// In pl, this message translates to:
  /// **'Polityka prywatności'**
  String get documentPrivacy;

  /// No description provided for @documentDeletion.
  ///
  /// In pl, this message translates to:
  /// **'Usuwanie konta — informacje'**
  String get documentDeletion;

  /// No description provided for @documentHelp.
  ///
  /// In pl, this message translates to:
  /// **'Pomoc'**
  String get documentHelp;

  /// No description provided for @compareWeekly.
  ///
  /// In pl, this message translates to:
  /// **'Automatyczny plan i lista co tydzień'**
  String get compareWeekly;

  /// No description provided for @compareArchive.
  ///
  /// In pl, this message translates to:
  /// **'Archiwum i wznowienie zakończonych planów'**
  String get compareArchive;

  /// No description provided for @compareLikes.
  ///
  /// In pl, this message translates to:
  /// **'Lubię / Nie lubię: jedno dopasowane danie dziennie'**
  String get compareLikes;

  /// No description provided for @compareAi.
  ///
  /// In pl, this message translates to:
  /// **'Import przepisu przez AI (zdjęcie, tekst, link)'**
  String get compareAi;

  /// No description provided for @compareBatch.
  ///
  /// In pl, this message translates to:
  /// **'Seryjne skanowanie produktów bez zamykania aparatu'**
  String get compareBatch;

  /// No description provided for @comparePublish.
  ///
  /// In pl, this message translates to:
  /// **'Publikacja przepisów we wspólnym katalogu'**
  String get comparePublish;

  /// No description provided for @compareTikTok.
  ///
  /// In pl, this message translates to:
  /// **'Odnośnik TikTok przy własnych przepisach'**
  String get compareTikTok;

  /// No description provided for @compareLists.
  ///
  /// In pl, this message translates to:
  /// **'Listy zakupów z wybranych przepisów'**
  String get compareLists;

  /// No description provided for @compareUnlimited.
  ///
  /// In pl, this message translates to:
  /// **'Bez limitu'**
  String get compareUnlimited;

  /// No description provided for @compareOneWeek.
  ///
  /// In pl, this message translates to:
  /// **'1 / tydzień'**
  String get compareOneWeek;

  /// No description provided for @compareGenerate.
  ///
  /// In pl, this message translates to:
  /// **'Generowanie planu posiłków'**
  String get compareGenerate;

  /// No description provided for @compareJournal.
  ///
  /// In pl, this message translates to:
  /// **'Dziennik kalorii i makroskładników'**
  String get compareJournal;

  /// No description provided for @compareCalculator.
  ///
  /// In pl, this message translates to:
  /// **'Kalkulator zapotrzebowania kalorycznego'**
  String get compareCalculator;

  /// No description provided for @compareCatalogue.
  ///
  /// In pl, this message translates to:
  /// **'Baza przepisów i produktów'**
  String get compareCatalogue;

  /// No description provided for @comparePrices.
  ///
  /// In pl, this message translates to:
  /// **'Porównywarka cen produktów'**
  String get comparePrices;

  /// No description provided for @profileExpiryDays.
  ///
  /// In pl, this message translates to:
  /// **'Subskrypcja aktywna jeszcze przez {days, plural, one{1 dzień} other{{days} dni}}'**
  String profileExpiryDays(int days);

  /// No description provided for @profilePeople.
  ///
  /// In pl, this message translates to:
  /// **'{count} os.'**
  String profilePeople(int count);

  /// No description provided for @profileWeightSaved.
  ///
  /// In pl, this message translates to:
  /// **'Zapisano {weight} kg.'**
  String profileWeightSaved(String weight);

  /// No description provided for @profileDate.
  ///
  /// In pl, this message translates to:
  /// **'Data: {date}'**
  String profileDate(String date);

  /// No description provided for @profileDeleteBody.
  ///
  /// In pl, this message translates to:
  /// **'Ta operacja jest NIEODWRACALNA. Stracisz wszystkie zapisane plany posiłków, listy zakupów, spiżarnię, ulubione przepisy, komentarze i punkty premium. Jeśli masz aktywną subskrypcję, pamiętaj, żeby anulować ją osobno w ustawieniach App Store / Google Play — usunięcie konta samo jej nie anuluje.'**
  String get profileDeleteBody;

  /// No description provided for @premiumTrialBadge.
  ///
  /// In pl, this message translates to:
  /// **'{days} DNI ZA 0 ZŁ*'**
  String premiumTrialBadge(int days);

  /// No description provided for @premiumCheckTrial.
  ///
  /// In pl, this message translates to:
  /// **'Sprawdź okres próbny'**
  String get premiumCheckTrial;

  /// No description provided for @premiumTrialEligibilityFootnote.
  ///
  /// In pl, this message translates to:
  /// **'* Dla kont uprawnionych do oferty. Dostępność, cena po okresie próbnym i termin odnowienia zostaną pokazane przez {store} przed potwierdzeniem.'**
  String premiumTrialEligibilityFootnote(String store);

  /// No description provided for @premiumNotNow.
  ///
  /// In pl, this message translates to:
  /// **'Nie teraz'**
  String get premiumNotNow;

  /// No description provided for @premiumPurchaseError.
  ///
  /// In pl, this message translates to:
  /// **'Wystąpił błąd podczas zakupu.'**
  String get premiumPurchaseError;

  /// No description provided for @premiumAppleOfferOpenFailed.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się otworzyć oferty w App Store.'**
  String get premiumAppleOfferOpenFailed;

  /// No description provided for @premiumPaymentsUnavailable.
  ///
  /// In pl, this message translates to:
  /// **'Płatności są niedostępne na tym urządzeniu (sprawdź konto {store}).'**
  String premiumPaymentsUnavailable(String store);

  /// No description provided for @premiumSubscriptionPricesUnavailable.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się pobrać cen subskrypcji. Spróbuj ponownie za chwilę.'**
  String get premiumSubscriptionPricesUnavailable;

  /// No description provided for @premiumPurchaseFailed.
  ///
  /// In pl, this message translates to:
  /// **'Zakup nie powiódł się: {error}'**
  String premiumPurchaseFailed(String error);

  /// No description provided for @premiumUnknownError.
  ///
  /// In pl, this message translates to:
  /// **'nieznany błąd'**
  String get premiumUnknownError;

  /// No description provided for @premiumActive.
  ///
  /// In pl, this message translates to:
  /// **'Premium jest aktywne.'**
  String get premiumActive;

  /// No description provided for @premiumActivated.
  ///
  /// In pl, this message translates to:
  /// **'Premium aktywowane — dziękujemy!'**
  String get premiumActivated;

  /// No description provided for @premiumPurchaseVerificationFailed.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się potwierdzić zakupu: {error}'**
  String premiumPurchaseVerificationFailed(String error);

  /// No description provided for @premiumPointsAdded.
  ///
  /// In pl, this message translates to:
  /// **'Dodano punkty! Masz teraz {balance} punktów.'**
  String premiumPointsAdded(int balance);

  /// No description provided for @premiumPurchaseStartFailed.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się rozpocząć zakupu: {error}'**
  String premiumPurchaseStartFailed(String error);

  /// No description provided for @premiumRestoreEmpty.
  ///
  /// In pl, this message translates to:
  /// **'Nie znaleziono żadnych wcześniejszych zakupów do przywrócenia.'**
  String get premiumRestoreEmpty;

  /// No description provided for @premiumQuickActionPoints.
  ///
  /// In pl, this message translates to:
  /// **'{subtitle} — albo {points} pkt bez subskrypcji'**
  String premiumQuickActionPoints(String subtitle, int points);

  /// No description provided for @premiumAutomaticWeekTitle.
  ///
  /// In pl, this message translates to:
  /// **'Automatyczny tydzień'**
  String get premiumAutomaticWeekTitle;

  /// No description provided for @premiumAutomaticWeekDescription.
  ///
  /// In pl, this message translates to:
  /// **'W wybranym dniu przygotujemy plan i opcjonalną listę zakupów.'**
  String get premiumAutomaticWeekDescription;

  /// No description provided for @premiumBatchTitle.
  ///
  /// In pl, this message translates to:
  /// **'Skanowanie seryjne'**
  String get premiumBatchTitle;

  /// No description provided for @premiumBatchDescription.
  ///
  /// In pl, this message translates to:
  /// **'Skanuj bez zamykania aparatu i dodaj całą serię do wybranych miejsc.'**
  String get premiumBatchDescription;

  /// No description provided for @premiumUnlimitedPlansTitle.
  ///
  /// In pl, this message translates to:
  /// **'Plany posiłków bez limitu'**
  String get premiumUnlimitedPlansTitle;

  /// No description provided for @premiumUnlimitedPlansDescription.
  ///
  /// In pl, this message translates to:
  /// **'Generuj tyle planów, ile chcesz — bez tygodniowego limitu.'**
  String get premiumUnlimitedPlansDescription;

  /// No description provided for @premiumAiRecipesTitle.
  ///
  /// In pl, this message translates to:
  /// **'Przepisy rozpoznawane przez AI'**
  String get premiumAiRecipesTitle;

  /// No description provided for @premiumAiRecipesDescription.
  ///
  /// In pl, this message translates to:
  /// **'Dodawaj własne przepisy z wklejonego tekstu albo zdjęcia.'**
  String get premiumAiRecipesDescription;

  /// No description provided for @premiumFullDiaryTitle.
  ///
  /// In pl, this message translates to:
  /// **'Pełna historia Dziennika'**
  String get premiumFullDiaryTitle;

  /// No description provided for @premiumFullDiaryDescription.
  ///
  /// In pl, this message translates to:
  /// **'Przeglądaj całą historię kalorii, bez limitu 30 dni wstecz.'**
  String get premiumFullDiaryDescription;

  /// No description provided for @premiumUnlimitedListsTitle.
  ///
  /// In pl, this message translates to:
  /// **'Listy zakupów bez limitu'**
  String get premiumUnlimitedListsTitle;

  /// No description provided for @premiumUnlimitedListsDescription.
  ///
  /// In pl, this message translates to:
  /// **'Twórz nowe listy zakupów wtedy, kiedy ich potrzebujesz.'**
  String get premiumUnlimitedListsDescription;

  /// No description provided for @premiumProductName.
  ///
  /// In pl, this message translates to:
  /// **'Meal Planner Premium'**
  String get premiumProductName;

  /// No description provided for @premiumHeroDescription.
  ///
  /// In pl, this message translates to:
  /// **'Zaplanuj cały tydzień, zeskanuj zakupy i przygotuj listę w kilka minut.'**
  String get premiumHeroDescription;

  /// No description provided for @premiumAutomaticWeekSubtitle.
  ///
  /// In pl, this message translates to:
  /// **'Plan i opcjonalna lista zakupów gotowe co tydzień'**
  String get premiumAutomaticWeekSubtitle;

  /// No description provided for @premiumAutomaticWeekRequired.
  ///
  /// In pl, this message translates to:
  /// **'Automatyczny tydzień jest dostępny w Premium.'**
  String get premiumAutomaticWeekRequired;

  /// No description provided for @premiumAiActionTitle.
  ///
  /// In pl, this message translates to:
  /// **'Dodaj przepis przez AI'**
  String get premiumAiActionTitle;

  /// No description provided for @premiumAiActionSubtitle.
  ///
  /// In pl, this message translates to:
  /// **'Zdjęcie, tekst albo link — AI zrobi resztę'**
  String get premiumAiActionSubtitle;

  /// No description provided for @premiumBatchActionTitle.
  ///
  /// In pl, this message translates to:
  /// **'Skanuj wiele produktów po kolei'**
  String get premiumBatchActionTitle;

  /// No description provided for @premiumBatchActionSubtitle.
  ///
  /// In pl, this message translates to:
  /// **'Wybierz kilka miejsc i zatwierdź całą serię'**
  String get premiumBatchActionSubtitle;

  /// No description provided for @premiumBatchCompleted.
  ///
  /// In pl, this message translates to:
  /// **'Obsłużono: {count} produktów.'**
  String premiumBatchCompleted(int count);

  /// No description provided for @premiumPublishActionTitle.
  ///
  /// In pl, this message translates to:
  /// **'Publikuj przepisy we wspólnocie'**
  String get premiumPublishActionTitle;

  /// No description provided for @premiumPublishActionSubtitle.
  ///
  /// In pl, this message translates to:
  /// **'Podziel się swoimi przepisami z innymi'**
  String get premiumPublishActionSubtitle;

  /// No description provided for @premiumRecipeListsTitle.
  ///
  /// In pl, this message translates to:
  /// **'Listy zakupów z przepisów'**
  String get premiumRecipeListsTitle;

  /// No description provided for @premiumRecipeListsSubtitle.
  ///
  /// In pl, this message translates to:
  /// **'Bez limitu (standard: 1 tygodniowo)'**
  String get premiumRecipeListsSubtitle;

  /// No description provided for @premiumCookFromPantryTitle.
  ///
  /// In pl, this message translates to:
  /// **'Co ugotować z tego, co mam'**
  String get premiumCookFromPantryTitle;

  /// No description provided for @premiumCookFromPantrySubtitle.
  ///
  /// In pl, this message translates to:
  /// **'Zaznacz składniki w domu, dopasujemy przepisy'**
  String get premiumCookFromPantrySubtitle;

  /// No description provided for @premiumPantryActionTitle.
  ///
  /// In pl, this message translates to:
  /// **'Twoja spiżarnia'**
  String get premiumPantryActionTitle;

  /// No description provided for @premiumPantryActionSubtitle.
  ///
  /// In pl, this message translates to:
  /// **'Zarządzaj produktami, które masz w domu'**
  String get premiumPantryActionSubtitle;

  /// No description provided for @premiumSubscriptionLegal.
  ///
  /// In pl, this message translates to:
  /// **'Subskrypcje odnawiają się automatycznie, chyba że zostaną anulowane co najmniej 24 godziny przed końcem bieżącego okresu. Płatność jest pobierana z konta {store} po potwierdzeniu zakupu. Możesz zarządzać subskrypcją albo ją anulować w ustawieniach swojego konta w sklepie.'**
  String premiumSubscriptionLegal(String store);

  /// No description provided for @premiumAlreadyActive.
  ///
  /// In pl, this message translates to:
  /// **'Masz już aktywne Premium'**
  String get premiumAlreadyActive;

  /// No description provided for @premiumExpiresToday.
  ///
  /// In pl, this message translates to:
  /// **'Wygasa dziś'**
  String get premiumExpiresToday;

  /// No description provided for @premiumDaysRemaining.
  ///
  /// In pl, this message translates to:
  /// **'Aktywne jeszcze przez {days, plural, one{{days} dzień} few{{days} dni} many{{days} dni} other{{days} dnia}}'**
  String premiumDaysRemaining(int days);

  /// No description provided for @premiumRetry.
  ///
  /// In pl, this message translates to:
  /// **'Spróbuj ponownie'**
  String get premiumRetry;

  /// No description provided for @premiumWeekly.
  ///
  /// In pl, this message translates to:
  /// **'Tygodniowo'**
  String get premiumWeekly;

  /// No description provided for @premiumMonthly.
  ///
  /// In pl, this message translates to:
  /// **'Miesięcznie'**
  String get premiumMonthly;

  /// No description provided for @premiumMonthlyTrial.
  ///
  /// In pl, this message translates to:
  /// **'{days, plural, one{{days} dzień za darmo} few{{days} dni za darmo} many{{days} dni za darmo} other{{days} dnia za darmo}}'**
  String premiumMonthlyTrial(int days);

  /// No description provided for @premiumYearly.
  ///
  /// In pl, this message translates to:
  /// **'Rocznie'**
  String get premiumYearly;

  /// No description provided for @premiumYearlySaving.
  ///
  /// In pl, this message translates to:
  /// **'Oszczędzasz {percent}%'**
  String premiumYearlySaving(int percent);

  /// No description provided for @premiumTrialDisclosureApple.
  ///
  /// In pl, this message translates to:
  /// **'{days}-dniowy okres próbny jest dostępny dla uprawnionych kont. Potem subskrypcja odnawia się za cenę pokazaną powyżej; możesz ją anulować w ustawieniach Apple ID.'**
  String premiumTrialDisclosureApple(int days);

  /// No description provided for @premiumTrialDisclosureGoogle.
  ///
  /// In pl, this message translates to:
  /// **'{days}-dniowy okres próbny jest dostępny dla uprawnionych kont. Potem subskrypcja odnawia się za cenę pokazaną powyżej; możesz ją anulować w Google Play.'**
  String premiumTrialDisclosureGoogle(int days);

  /// No description provided for @premiumRestorePurchases.
  ///
  /// In pl, this message translates to:
  /// **'Przywróć zakupy'**
  String get premiumRestorePurchases;

  /// No description provided for @premiumPointsTitle.
  ///
  /// In pl, this message translates to:
  /// **'Punkty premium'**
  String get premiumPointsTitle;

  /// No description provided for @premiumPointsBalance.
  ///
  /// In pl, this message translates to:
  /// **'Masz: {balance}'**
  String premiumPointsBalance(int balance);

  /// No description provided for @premiumPointsExplanation.
  ///
  /// In pl, this message translates to:
  /// **'Import przepisu ze zdjęcia, tekstu lub linku kosztuje 2 punkty, a edycja AI 1 punkt — bez subskrypcji.'**
  String get premiumPointsExplanation;

  /// No description provided for @premiumPointsPricesUnavailable.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się pobrać cen pakietów punktów.'**
  String get premiumPointsPricesUnavailable;

  /// No description provided for @premiumPointsAmount.
  ///
  /// In pl, this message translates to:
  /// **'{points} pkt'**
  String premiumPointsAmount(int points);

  /// No description provided for @premiumPromotionalPrice.
  ///
  /// In pl, this message translates to:
  /// **'Cena promocyjna: {price}'**
  String premiumPromotionalPrice(String price);

  /// No description provided for @premiumPointsUses.
  ///
  /// In pl, this message translates to:
  /// **'{imports} importów AI\nlub {edits} edycji AI'**
  String premiumPointsUses(int imports, int edits);

  /// No description provided for @premiumBuyInApple.
  ///
  /// In pl, this message translates to:
  /// **'Kup w App Store'**
  String get premiumBuyInApple;

  /// No description provided for @premiumBuyInGoogle.
  ///
  /// In pl, this message translates to:
  /// **'Kup w Google Play'**
  String get premiumBuyInGoogle;

  /// No description provided for @premiumPriceAfterTrial.
  ///
  /// In pl, this message translates to:
  /// **'Potem {price} miesięcznie'**
  String premiumPriceAfterTrial(String price);

  /// No description provided for @premiumPriceBeforeCode.
  ///
  /// In pl, this message translates to:
  /// **'Cena przed kodem: {price}'**
  String premiumPriceBeforeCode(String price);

  /// No description provided for @premiumTryFree.
  ///
  /// In pl, this message translates to:
  /// **'Wypróbuj za 0 zł'**
  String get premiumTryFree;

  /// No description provided for @premiumBuy.
  ///
  /// In pl, this message translates to:
  /// **'Kup Premium'**
  String get premiumBuy;

  /// No description provided for @premiumRedeemCode.
  ///
  /// In pl, this message translates to:
  /// **'Odbierz kod'**
  String get premiumRedeemCode;

  /// No description provided for @premiumBuyDiscount.
  ///
  /// In pl, this message translates to:
  /// **'Kup z rabatem'**
  String get premiumBuyDiscount;

  /// No description provided for @premiumContextRecipeEyebrow.
  ///
  /// In pl, this message translates to:
  /// **'PREMIUM DLA PRZEPISÓW'**
  String get premiumContextRecipeEyebrow;

  /// No description provided for @premiumContextRecipeTitle.
  ///
  /// In pl, this message translates to:
  /// **'Zamień inspirację w gotowy przepis'**
  String get premiumContextRecipeTitle;

  /// No description provided for @premiumContextRecipeDescription.
  ///
  /// In pl, this message translates to:
  /// **'Dodaj link, zdjęcie albo krótki opis. Otrzymasz składniki, porcje i kolejne kroki bez ręcznego przepisywania.'**
  String get premiumContextRecipeDescription;

  /// No description provided for @premiumContextRecipeBenefitImport.
  ///
  /// In pl, this message translates to:
  /// **'Przepis z linku, zdjęcia lub opisu'**
  String get premiumContextRecipeBenefitImport;

  /// No description provided for @premiumContextRecipeBenefitSteps.
  ///
  /// In pl, this message translates to:
  /// **'Automatycznie ułożone składniki i kroki'**
  String get premiumContextRecipeBenefitSteps;

  /// No description provided for @premiumContextRecipeBenefitEdit.
  ///
  /// In pl, this message translates to:
  /// **'Edycja przepisu z pomocą AI'**
  String get premiumContextRecipeBenefitEdit;

  /// No description provided for @premiumContextMealPlanEyebrow.
  ///
  /// In pl, this message translates to:
  /// **'PREMIUM DLA PLANOWANIA'**
  String get premiumContextMealPlanEyebrow;

  /// No description provided for @premiumContextMealPlanTitle.
  ///
  /// In pl, this message translates to:
  /// **'Zaplanuj kolejne tygodnie bez limitu'**
  String get premiumContextMealPlanTitle;

  /// No description provided for @premiumContextMealPlanDescription.
  ///
  /// In pl, this message translates to:
  /// **'Twórz tyle planów, ile potrzebujesz, i szybciej dopasuj posiłki do swojego dnia.'**
  String get premiumContextMealPlanDescription;

  /// No description provided for @premiumContextMealPlanBenefitUnlimited.
  ///
  /// In pl, this message translates to:
  /// **'Plany posiłków bez limitu'**
  String get premiumContextMealPlanBenefitUnlimited;

  /// No description provided for @premiumContextMealPlanBenefitWeekly.
  ///
  /// In pl, this message translates to:
  /// **'Automatyczny plan na kolejny tydzień'**
  String get premiumContextMealPlanBenefitWeekly;

  /// No description provided for @premiumContextMealPlanBenefitSwap.
  ///
  /// In pl, this message translates to:
  /// **'Wygodna zamiana i wyszukiwanie dań'**
  String get premiumContextMealPlanBenefitSwap;

  /// No description provided for @premiumContextBarcodeEyebrow.
  ///
  /// In pl, this message translates to:
  /// **'PREMIUM DLA SKANOWANIA'**
  String get premiumContextBarcodeEyebrow;

  /// No description provided for @premiumContextBarcodeTitle.
  ///
  /// In pl, this message translates to:
  /// **'Zeskanuj całe zakupy bez zamykania aparatu'**
  String get premiumContextBarcodeTitle;

  /// No description provided for @premiumContextBarcodeDescription.
  ///
  /// In pl, this message translates to:
  /// **'Skanuj produkty jeden po drugim, a potem dodaj całą serię do wybranych miejsc jednym ruchem.'**
  String get premiumContextBarcodeDescription;

  /// No description provided for @premiumContextBarcodeBenefitBatch.
  ///
  /// In pl, this message translates to:
  /// **'Seryjne skanowanie produktów'**
  String get premiumContextBarcodeBenefitBatch;

  /// No description provided for @premiumContextBarcodeBenefitNutrition.
  ///
  /// In pl, this message translates to:
  /// **'Makro i kalorie przy znalezionych produktach'**
  String get premiumContextBarcodeBenefitNutrition;

  /// No description provided for @premiumContextBarcodeBenefitDestinations.
  ///
  /// In pl, this message translates to:
  /// **'Wspólne dodanie do Dziennika, spiżarni lub katalogu'**
  String get premiumContextBarcodeBenefitDestinations;

  /// No description provided for @premiumContextShoppingEyebrow.
  ///
  /// In pl, this message translates to:
  /// **'PREMIUM DLA ZAKUPÓW'**
  String get premiumContextShoppingEyebrow;

  /// No description provided for @premiumContextShoppingTitle.
  ///
  /// In pl, this message translates to:
  /// **'Twórz listy zakupów bez limitu'**
  String get premiumContextShoppingTitle;

  /// No description provided for @premiumContextShoppingDescription.
  ///
  /// In pl, this message translates to:
  /// **'Przygotuj osobną listę na każdy plan lub przepis i połącz listy dla tego samego sklepu.'**
  String get premiumContextShoppingDescription;

  /// No description provided for @premiumContextShoppingBenefitLists.
  ///
  /// In pl, this message translates to:
  /// **'Dowolna liczba list zakupów'**
  String get premiumContextShoppingBenefitLists;

  /// No description provided for @premiumContextShoppingBenefitMerge.
  ///
  /// In pl, this message translates to:
  /// **'Łączenie list dla jednego sklepu'**
  String get premiumContextShoppingBenefitMerge;

  /// No description provided for @premiumContextShoppingBenefitPantry.
  ///
  /// In pl, this message translates to:
  /// **'Produkty ze spiżarni liczone za 0 zł'**
  String get premiumContextShoppingBenefitPantry;

  /// No description provided for @premiumContextPantryEyebrow.
  ///
  /// In pl, this message translates to:
  /// **'PREMIUM DLA SPIŻARNI'**
  String get premiumContextPantryEyebrow;

  /// No description provided for @premiumContextPantryTitle.
  ///
  /// In pl, this message translates to:
  /// **'Wykorzystaj produkty, które już masz'**
  String get premiumContextPantryTitle;

  /// No description provided for @premiumContextPantryDescription.
  ///
  /// In pl, this message translates to:
  /// **'Znajdź przepisy dopasowane do zawartości spiżarni i kup tylko to, czego naprawdę brakuje.'**
  String get premiumContextPantryDescription;

  /// No description provided for @premiumContextPantryBenefitMatch.
  ///
  /// In pl, this message translates to:
  /// **'Przepisy z dostępnych składników'**
  String get premiumContextPantryBenefitMatch;

  /// No description provided for @premiumContextPantryBenefitMissing.
  ///
  /// In pl, this message translates to:
  /// **'Mniej brakujących produktów'**
  String get premiumContextPantryBenefitMissing;

  /// No description provided for @premiumContextPantryBenefitWaste.
  ///
  /// In pl, this message translates to:
  /// **'Mniej marnowania jedzenia'**
  String get premiumContextPantryBenefitWaste;

  /// No description provided for @premiumContextJournalEyebrow.
  ///
  /// In pl, this message translates to:
  /// **'PREMIUM DLA DZIENNIKA'**
  String get premiumContextJournalEyebrow;

  /// No description provided for @premiumContextJournalTitle.
  ///
  /// In pl, this message translates to:
  /// **'Zobacz, jak zmieniają się Twoje wyniki'**
  String get premiumContextJournalTitle;

  /// No description provided for @premiumContextJournalDescription.
  ///
  /// In pl, this message translates to:
  /// **'Śledź dłuższy okres i łatwiej zauważaj zmiany w kaloriach, makro, nawodnieniu oraz wadze.'**
  String get premiumContextJournalDescription;

  /// No description provided for @premiumContextJournalBenefitHistory.
  ///
  /// In pl, this message translates to:
  /// **'Pełna historia Dziennika'**
  String get premiumContextJournalBenefitHistory;

  /// No description provided for @premiumContextJournalBenefitCharts.
  ///
  /// In pl, this message translates to:
  /// **'Wykresy kalorii, makro i nawodnienia'**
  String get premiumContextJournalBenefitCharts;

  /// No description provided for @premiumContextJournalBenefitWeight.
  ///
  /// In pl, this message translates to:
  /// **'Postępy wagi w czasie'**
  String get premiumContextJournalBenefitWeight;

  /// No description provided for @premiumPackageSemantics.
  ///
  /// In pl, this message translates to:
  /// **'Pakiet'**
  String get premiumPackageSemantics;

  /// No description provided for @premiumDiscountSemantics.
  ///
  /// In pl, this message translates to:
  /// **'Rabat {percent} procent'**
  String premiumDiscountSemantics(int percent);

  /// No description provided for @premiumDiscountRibbon.
  ///
  /// In pl, this message translates to:
  /// **'RABAT -{percent}%'**
  String premiumDiscountRibbon(int percent);

  /// No description provided for @premiumSeePlans.
  ///
  /// In pl, this message translates to:
  /// **'Zobacz plany Premium'**
  String get premiumSeePlans;

  /// No description provided for @archiveTitle.
  ///
  /// In pl, this message translates to:
  /// **'Archiwum planów'**
  String get archiveTitle;

  /// No description provided for @archiveChooseStart.
  ///
  /// In pl, this message translates to:
  /// **'Od kiedy wznowić plan?'**
  String get archiveChooseStart;

  /// No description provided for @archiveChooseDate.
  ///
  /// In pl, this message translates to:
  /// **'Wybierz datę'**
  String get archiveChooseDate;

  /// No description provided for @archiveResumeTitle.
  ///
  /// In pl, this message translates to:
  /// **'Wznów plan'**
  String get archiveResumeTitle;

  /// No description provided for @archiveResumeBody.
  ///
  /// In pl, this message translates to:
  /// **'Te same posiłki na {days} dni od {date}. Plan pozostanie też w archiwum. Utworzymy nową listę zakupów. Bez generowania AI i bez wydawania punktów.'**
  String archiveResumeBody(int days, String date);

  /// No description provided for @archiveResume.
  ///
  /// In pl, this message translates to:
  /// **'Wznów'**
  String get archiveResume;

  /// No description provided for @archiveResumed.
  ///
  /// In pl, this message translates to:
  /// **'Plan został wznowiony.'**
  String get archiveResumed;

  /// No description provided for @archiveResumeFailed.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się wznowić planu. Spróbuj ponownie.'**
  String get archiveResumeFailed;

  /// No description provided for @archiveDuration.
  ///
  /// In pl, this message translates to:
  /// **'{days} dni'**
  String archiveDuration(int days);

  /// No description provided for @archivePremiumHint.
  ///
  /// In pl, this message translates to:
  /// **'Z Premium zakończone plany pozostają w archiwum. Możesz je przeglądać i wznowić bez generowania przez AI.'**
  String get archivePremiumHint;

  /// No description provided for @archiveSeePremium.
  ///
  /// In pl, this message translates to:
  /// **'Zobacz Premium'**
  String get archiveSeePremium;

  /// No description provided for @archiveCompleted.
  ///
  /// In pl, this message translates to:
  /// **'Zakończone plany'**
  String get archiveCompleted;

  /// No description provided for @archiveHint.
  ///
  /// In pl, this message translates to:
  /// **'Wznów ten sam zestaw posiłków od nowej daty. Nie używamy AI ani punktów Premium.'**
  String get archiveHint;

  /// No description provided for @archiveEmpty.
  ///
  /// In pl, this message translates to:
  /// **'Nie masz jeszcze zakończonych planów. Po ostatnim dniu aktywny plan trafi tutaj.'**
  String get archiveEmpty;

  /// No description provided for @archivePlanTitle.
  ///
  /// In pl, this message translates to:
  /// **'Plan na {days} dni'**
  String archivePlanTitle(int days);

  /// No description provided for @archivePreview.
  ///
  /// In pl, this message translates to:
  /// **'Podgląd'**
  String get archivePreview;

  /// No description provided for @archiveResuming.
  ///
  /// In pl, this message translates to:
  /// **'Wznawianie…'**
  String get archiveResuming;

  /// No description provided for @automationTitle.
  ///
  /// In pl, this message translates to:
  /// **'Automatyczny tydzień'**
  String get automationTitle;

  /// No description provided for @automationHeading.
  ///
  /// In pl, this message translates to:
  /// **'Plan gotowy, zanim zacznie się tydzień'**
  String get automationHeading;

  /// No description provided for @automationHint.
  ///
  /// In pl, this message translates to:
  /// **'Co tydzień przygotujemy 7-dniowy plan na podstawie Twojego celu, preferencji i ulubionego sklepu.'**
  String get automationHint;

  /// No description provided for @automationGenerate.
  ///
  /// In pl, this message translates to:
  /// **'Generuj automatycznie'**
  String get automationGenerate;

  /// No description provided for @automationPremiumHint.
  ///
  /// In pl, this message translates to:
  /// **'Tylko podczas aktywnego Premium'**
  String get automationPremiumHint;

  /// No description provided for @automationWeekday.
  ///
  /// In pl, this message translates to:
  /// **'Dzień tygodnia'**
  String get automationWeekday;

  /// No description provided for @automationMonday.
  ///
  /// In pl, this message translates to:
  /// **'Poniedziałek'**
  String get automationMonday;

  /// No description provided for @automationTuesday.
  ///
  /// In pl, this message translates to:
  /// **'Wtorek'**
  String get automationTuesday;

  /// No description provided for @automationWednesday.
  ///
  /// In pl, this message translates to:
  /// **'Środa'**
  String get automationWednesday;

  /// No description provided for @automationThursday.
  ///
  /// In pl, this message translates to:
  /// **'Czwartek'**
  String get automationThursday;

  /// No description provided for @automationFriday.
  ///
  /// In pl, this message translates to:
  /// **'Piątek'**
  String get automationFriday;

  /// No description provided for @automationSaturday.
  ///
  /// In pl, this message translates to:
  /// **'Sobota'**
  String get automationSaturday;

  /// No description provided for @automationSunday.
  ///
  /// In pl, this message translates to:
  /// **'Niedziela'**
  String get automationSunday;

  /// No description provided for @automationHour.
  ///
  /// In pl, this message translates to:
  /// **'Godzina'**
  String get automationHour;

  /// No description provided for @automationCreateList.
  ///
  /// In pl, this message translates to:
  /// **'Utwórz też listę zakupów'**
  String get automationCreateList;

  /// No description provided for @automationLastPlan.
  ///
  /// In pl, this message translates to:
  /// **'Ostatni plan utworzony'**
  String get automationLastPlan;

  /// No description provided for @automationSave.
  ///
  /// In pl, this message translates to:
  /// **'Zapisz ustawienia'**
  String get automationSave;

  /// No description provided for @automationRun.
  ///
  /// In pl, this message translates to:
  /// **'Wygeneruj teraz'**
  String get automationRun;

  /// No description provided for @automationEnabled.
  ///
  /// In pl, this message translates to:
  /// **'Automatyczny tydzień jest włączony.'**
  String get automationEnabled;

  /// No description provided for @automationDisabled.
  ///
  /// In pl, this message translates to:
  /// **'Automatyczny tydzień jest wyłączony.'**
  String get automationDisabled;

  /// No description provided for @automationReady.
  ///
  /// In pl, this message translates to:
  /// **'Plan jest gotowy. Sprawdź go w zakładce Start.'**
  String get automationReady;

  /// No description provided for @errorSignIn.
  ///
  /// In pl, this message translates to:
  /// **'Musisz być zalogowany, żeby to zrobić.'**
  String get errorSignIn;

  /// No description provided for @errorTooManyRequests.
  ///
  /// In pl, this message translates to:
  /// **'Zbyt wiele prób w krótkim czasie — spróbuj ponownie za chwilę.'**
  String get errorTooManyRequests;

  /// No description provided for @errorUnavailable.
  ///
  /// In pl, this message translates to:
  /// **'Usługa jest chwilowo niedostępna. Spróbuj ponownie za chwilę.'**
  String get errorUnavailable;

  /// No description provided for @errorServerTimeout.
  ///
  /// In pl, this message translates to:
  /// **'Serwer nie odpowiedział na czas. Spróbuj ponownie za chwilę.'**
  String get errorServerTimeout;

  /// No description provided for @errorServer.
  ///
  /// In pl, this message translates to:
  /// **'Coś poszło nie tak po naszej stronie. Spróbuj ponownie za chwilę.'**
  String get errorServer;

  /// No description provided for @errorOperationTimeout.
  ///
  /// In pl, this message translates to:
  /// **'Operacja trwała zbyt długo. Spróbuj ponownie za chwilę.'**
  String get errorOperationTimeout;

  /// No description provided for @errorConnection.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się połączyć z serwerem. Sprawdź internet i spróbuj ponownie.'**
  String get errorConnection;

  /// No description provided for @errorFormat.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się odczytać danych. Odśwież ekran i spróbuj ponownie.'**
  String get errorFormat;

  /// No description provided for @automationRetry.
  ///
  /// In pl, this message translates to:
  /// **'Ponów'**
  String get automationRetry;

  /// No description provided for @ingredientPreferencesTitle.
  ///
  /// In pl, this message translates to:
  /// **'Preferencje składników'**
  String get ingredientPreferencesTitle;

  /// No description provided for @ingredientPreferencesLimit.
  ///
  /// In pl, this message translates to:
  /// **'Możesz wybrać do 50 składników w każdej grupie.'**
  String get ingredientPreferencesLimit;

  /// No description provided for @ingredientPreferencesSavedMessage.
  ///
  /// In pl, this message translates to:
  /// **'Zapisano preferencje składników.'**
  String get ingredientPreferencesSavedMessage;

  /// No description provided for @ingredientPreferencesUnsavedTitle.
  ///
  /// In pl, this message translates to:
  /// **'Niezapisane preferencje'**
  String get ingredientPreferencesUnsavedTitle;

  /// No description provided for @ingredientPreferencesUnsavedBody.
  ///
  /// In pl, this message translates to:
  /// **'Masz niezapisane zmiany. Wrócić bez zapisywania?'**
  String get ingredientPreferencesUnsavedBody;

  /// No description provided for @ingredientPreferencesStay.
  ///
  /// In pl, this message translates to:
  /// **'Zostań'**
  String get ingredientPreferencesStay;

  /// No description provided for @ingredientPreferencesDiscard.
  ///
  /// In pl, this message translates to:
  /// **'Wróć bez zapisu'**
  String get ingredientPreferencesDiscard;

  /// No description provided for @ingredientPreferencesEmpty.
  ///
  /// In pl, this message translates to:
  /// **'Jeszcze nie wybrano składników.'**
  String get ingredientPreferencesEmpty;

  /// No description provided for @ingredientPreferencesRemove.
  ///
  /// In pl, this message translates to:
  /// **'Usuń {name}'**
  String ingredientPreferencesRemove(String name);

  /// No description provided for @ingredientPreferencesRetry.
  ///
  /// In pl, this message translates to:
  /// **'Spróbuj ponownie'**
  String get ingredientPreferencesRetry;

  /// No description provided for @ingredientPreferencesHint.
  ///
  /// In pl, this message translates to:
  /// **'Uwzględnimy preferencje w jednym daniu dziennie, jeśli znajdziemy pasujący przepis. Alergie i dieta mają pierwszeństwo.'**
  String get ingredientPreferencesHint;

  /// No description provided for @ingredientPreferencesLike.
  ///
  /// In pl, this message translates to:
  /// **'Lubię'**
  String get ingredientPreferencesLike;

  /// No description provided for @ingredientPreferencesDislike.
  ///
  /// In pl, this message translates to:
  /// **'Nie lubię'**
  String get ingredientPreferencesDislike;

  /// No description provided for @ingredientPreferencesAddLike.
  ///
  /// In pl, this message translates to:
  /// **'Dodaj do: Lubię'**
  String get ingredientPreferencesAddLike;

  /// No description provided for @ingredientPreferencesAddDislike.
  ///
  /// In pl, this message translates to:
  /// **'Dodaj do: Nie lubię'**
  String get ingredientPreferencesAddDislike;

  /// No description provided for @ingredientPreferencesSearch.
  ///
  /// In pl, this message translates to:
  /// **'Szukaj składnika'**
  String get ingredientPreferencesSearch;

  /// No description provided for @ingredientPreferencesMoveHint.
  ///
  /// In pl, this message translates to:
  /// **'Wybranie w drugiej grupie przenosi składnik.'**
  String get ingredientPreferencesMoveHint;

  /// No description provided for @ingredientPreferencesRetrySearch.
  ///
  /// In pl, this message translates to:
  /// **'Ponów wyszukiwanie'**
  String get ingredientPreferencesRetrySearch;

  /// No description provided for @ingredientPreferencesNoResults.
  ///
  /// In pl, this message translates to:
  /// **'Brak składników o tej nazwie.'**
  String get ingredientPreferencesNoResults;

  /// No description provided for @ingredientPreferencesSaveError.
  ///
  /// In pl, this message translates to:
  /// **'Nie zapisano: {error}'**
  String ingredientPreferencesSaveError(String error);

  /// No description provided for @ingredientPreferencesSaving.
  ///
  /// In pl, this message translates to:
  /// **'Zapisywanie…'**
  String get ingredientPreferencesSaving;

  /// No description provided for @ingredientPreferencesSave.
  ///
  /// In pl, this message translates to:
  /// **'Zapisz preferencje'**
  String get ingredientPreferencesSave;

  /// No description provided for @ingredientPreferencesSaved.
  ///
  /// In pl, this message translates to:
  /// **'Preferencje zapisane'**
  String get ingredientPreferencesSaved;

  /// No description provided for @ingredientPreferencesLocked.
  ///
  /// In pl, this message translates to:
  /// **'Wybierz składniki, które lubisz i których nie lubisz. Premium uwzględni je w jednym daniu dziennie, jeśli znajdziemy pasujący przepis.'**
  String get ingredientPreferencesLocked;

  /// No description provided for @ingredientPreferencesPremium.
  ///
  /// In pl, this message translates to:
  /// **'Zobacz Premium'**
  String get ingredientPreferencesPremium;

  /// No description provided for @blockedUsersTitle.
  ///
  /// In pl, this message translates to:
  /// **'Zablokowani użytkownicy'**
  String get blockedUsersTitle;

  /// No description provided for @blockedUsersEmpty.
  ///
  /// In pl, this message translates to:
  /// **'Nie zablokowałeś jeszcze nikogo.'**
  String get blockedUsersEmpty;

  /// No description provided for @blockedUsersUnknown.
  ///
  /// In pl, this message translates to:
  /// **'Użytkownik'**
  String get blockedUsersUnknown;

  /// No description provided for @blockedUsersUnblock.
  ///
  /// In pl, this message translates to:
  /// **'Odblokuj'**
  String get blockedUsersUnblock;

  /// No description provided for @blockedUsersUnblocked.
  ///
  /// In pl, this message translates to:
  /// **'Odblokowano \"{name}\". Znów zobaczysz jej/jego treści.'**
  String blockedUsersUnblocked(String name);

  /// No description provided for @calculatorTitle.
  ///
  /// In pl, this message translates to:
  /// **'Kalkulator zapotrzebowania kalorycznego'**
  String get calculatorTitle;

  /// No description provided for @calculatorIntro.
  ///
  /// In pl, this message translates to:
  /// **'Podaj swoje dane, żeby obliczyć dzienne zapotrzebowanie kaloryczne (wzór Mifflin-St Jeor — ten sam standard, na którym opiera się m.in. kalkulator NFZ).'**
  String get calculatorIntro;

  /// No description provided for @calculatorWeight.
  ///
  /// In pl, this message translates to:
  /// **'Waga (kg)'**
  String get calculatorWeight;

  /// No description provided for @calculatorHeight.
  ///
  /// In pl, this message translates to:
  /// **'Wzrost (cm)'**
  String get calculatorHeight;

  /// No description provided for @calculatorAge.
  ///
  /// In pl, this message translates to:
  /// **'Wiek (lata)'**
  String get calculatorAge;

  /// No description provided for @calculatorSex.
  ///
  /// In pl, this message translates to:
  /// **'Płeć'**
  String get calculatorSex;

  /// No description provided for @calculatorFemale.
  ///
  /// In pl, this message translates to:
  /// **'Kobieta'**
  String get calculatorFemale;

  /// No description provided for @calculatorMale.
  ///
  /// In pl, this message translates to:
  /// **'Mężczyzna'**
  String get calculatorMale;

  /// No description provided for @calculatorActivity.
  ///
  /// In pl, this message translates to:
  /// **'Poziom aktywności fizycznej'**
  String get calculatorActivity;

  /// No description provided for @calculatorSedentary.
  ///
  /// In pl, this message translates to:
  /// **'Siedzący tryb życia'**
  String get calculatorSedentary;

  /// No description provided for @calculatorSedentaryHint.
  ///
  /// In pl, this message translates to:
  /// **'Mało lub brak ćwiczeń'**
  String get calculatorSedentaryHint;

  /// No description provided for @calculatorLight.
  ///
  /// In pl, this message translates to:
  /// **'Lekka aktywność'**
  String get calculatorLight;

  /// No description provided for @calculatorLightHint.
  ///
  /// In pl, this message translates to:
  /// **'Trening 1–3 dni/tydzień'**
  String get calculatorLightHint;

  /// No description provided for @calculatorModerate.
  ///
  /// In pl, this message translates to:
  /// **'Umiarkowana aktywność'**
  String get calculatorModerate;

  /// No description provided for @calculatorModerateHint.
  ///
  /// In pl, this message translates to:
  /// **'Trening 3–5 dni/tydzień'**
  String get calculatorModerateHint;

  /// No description provided for @calculatorActive.
  ///
  /// In pl, this message translates to:
  /// **'Duża aktywność'**
  String get calculatorActive;

  /// No description provided for @calculatorActiveHint.
  ///
  /// In pl, this message translates to:
  /// **'Trening 6–7 dni/tydzień'**
  String get calculatorActiveHint;

  /// No description provided for @calculatorVeryActive.
  ///
  /// In pl, this message translates to:
  /// **'Bardzo duża aktywność'**
  String get calculatorVeryActive;

  /// No description provided for @calculatorVeryActiveHint.
  ///
  /// In pl, this message translates to:
  /// **'Praca fizyczna + codzienny trening'**
  String get calculatorVeryActiveHint;

  /// No description provided for @calculatorNumbersRequired.
  ///
  /// In pl, this message translates to:
  /// **'Wypełnij wszystkie pola liczbami (waga, wzrost, wiek).'**
  String get calculatorNumbersRequired;

  /// No description provided for @calculatorCalculate.
  ///
  /// In pl, this message translates to:
  /// **'Oblicz zapotrzebowanie'**
  String get calculatorCalculate;

  /// No description provided for @calculatorSaveFailed.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się zapisać celu.'**
  String get calculatorSaveFailed;

  /// No description provided for @calculatorGoalSaved.
  ///
  /// In pl, this message translates to:
  /// **'Cel zapisany: {kcal} kcal/dzień'**
  String calculatorGoalSaved(int kcal);

  /// No description provided for @calculatorChooseGoal.
  ///
  /// In pl, this message translates to:
  /// **'Wybierz swój cel'**
  String get calculatorChooseGoal;

  /// No description provided for @calculatorGoalHint.
  ///
  /// In pl, this message translates to:
  /// **'Dotknij kafelek, żeby go wybrać, albo dostrój suwakiem poniżej.'**
  String get calculatorGoalHint;

  /// No description provided for @calculatorLoss.
  ///
  /// In pl, this message translates to:
  /// **'Redukcja'**
  String get calculatorLoss;

  /// No description provided for @calculatorMaintenance.
  ///
  /// In pl, this message translates to:
  /// **'Utrzymanie'**
  String get calculatorMaintenance;

  /// No description provided for @calculatorGain.
  ///
  /// In pl, this message translates to:
  /// **'Przyrost'**
  String get calculatorGain;

  /// No description provided for @calculatorCustomGoal.
  ///
  /// In pl, this message translates to:
  /// **'Własna wartość: {kcal} kcal/dzień'**
  String calculatorCustomGoal(int kcal);

  /// No description provided for @calculatorMacros.
  ///
  /// In pl, this message translates to:
  /// **'Orientacyjny podział makroskładników'**
  String get calculatorMacros;

  /// No description provided for @calculatorProtein.
  ///
  /// In pl, this message translates to:
  /// **'Białko'**
  String get calculatorProtein;

  /// No description provided for @calculatorFat.
  ///
  /// In pl, this message translates to:
  /// **'Tłuszcz'**
  String get calculatorFat;

  /// No description provided for @calculatorCarbs.
  ///
  /// In pl, this message translates to:
  /// **'Węgl.'**
  String get calculatorCarbs;

  /// No description provided for @calculatorSaveGoal.
  ///
  /// In pl, this message translates to:
  /// **'Zapisz jako mój cel'**
  String get calculatorSaveGoal;

  /// No description provided for @socialInviteTitle.
  ///
  /// In pl, this message translates to:
  /// **'Zaproś znajomego'**
  String get socialInviteTitle;

  /// No description provided for @socialIdentifier.
  ///
  /// In pl, this message translates to:
  /// **'Nazwa użytkownika lub e-mail'**
  String get socialIdentifier;

  /// No description provided for @socialSend.
  ///
  /// In pl, this message translates to:
  /// **'Wyślij'**
  String get socialSend;

  /// No description provided for @socialInvitationSent.
  ///
  /// In pl, this message translates to:
  /// **'Zaproszenie zostało wysłane.'**
  String get socialInvitationSent;

  /// No description provided for @socialInvitationAccepted.
  ///
  /// In pl, this message translates to:
  /// **'Zaproszenie zostało przyjęte.'**
  String get socialInvitationAccepted;

  /// No description provided for @socialInvitationDeclined.
  ///
  /// In pl, this message translates to:
  /// **'Zaproszenie zostało odrzucone.'**
  String get socialInvitationDeclined;

  /// No description provided for @socialInvitationCancelled.
  ///
  /// In pl, this message translates to:
  /// **'Zaproszenie zostało anulowane.'**
  String get socialInvitationCancelled;

  /// No description provided for @socialFriends.
  ///
  /// In pl, this message translates to:
  /// **'Znajomi'**
  String get socialFriends;

  /// No description provided for @socialInvite.
  ///
  /// In pl, this message translates to:
  /// **'Zaproś'**
  String get socialInvite;

  /// No description provided for @socialRetry.
  ///
  /// In pl, this message translates to:
  /// **'Spróbuj ponownie'**
  String get socialRetry;

  /// No description provided for @socialIncoming.
  ///
  /// In pl, this message translates to:
  /// **'Zaproszenia do Ciebie'**
  String get socialIncoming;

  /// No description provided for @socialYourFriends.
  ///
  /// In pl, this message translates to:
  /// **'Twoi znajomi'**
  String get socialYourFriends;

  /// No description provided for @socialNoFriends.
  ///
  /// In pl, this message translates to:
  /// **'Nie masz jeszcze znajomych. Wyślij pierwsze zaproszenie.'**
  String get socialNoFriends;

  /// No description provided for @socialFriendSubtitle.
  ///
  /// In pl, this message translates to:
  /// **'Przepisy i lista zakupów'**
  String get socialFriendSubtitle;

  /// No description provided for @socialOutgoing.
  ///
  /// In pl, this message translates to:
  /// **'Wysłane zaproszenia'**
  String get socialOutgoing;

  /// No description provided for @socialAwaitingResponse.
  ///
  /// In pl, this message translates to:
  /// **'Oczekuje na odpowiedź'**
  String get socialAwaitingResponse;

  /// No description provided for @socialDecline.
  ///
  /// In pl, this message translates to:
  /// **'Odrzuć'**
  String get socialDecline;

  /// No description provided for @socialAccept.
  ///
  /// In pl, this message translates to:
  /// **'Przyjmij'**
  String get socialAccept;

  /// No description provided for @socialNoFriendRecipes.
  ///
  /// In pl, this message translates to:
  /// **'Ten znajomy nie ma jeszcze zapisanych przepisów.'**
  String get socialNoFriendRecipes;

  /// No description provided for @socialRecipeSummary.
  ///
  /// In pl, this message translates to:
  /// **'{minutes} min • {meal}'**
  String socialRecipeSummary(int minutes, String meal);

  /// No description provided for @socialNoFriendLists.
  ///
  /// In pl, this message translates to:
  /// **'Ten znajomy nie ma teraz aktywnej listy zakupów.'**
  String get socialNoFriendLists;

  /// No description provided for @socialShareAccepted.
  ///
  /// In pl, this message translates to:
  /// **'Zaakceptowano — lista pojawi się jako udostępniona.'**
  String get socialShareAccepted;

  /// No description provided for @socialSharesTitle.
  ///
  /// In pl, this message translates to:
  /// **'Zaproszenia do list zakupów'**
  String get socialSharesTitle;

  /// No description provided for @socialNoPendingShares.
  ///
  /// In pl, this message translates to:
  /// **'Brak oczekujących zaproszeń.'**
  String get socialNoPendingShares;

  /// No description provided for @socialSharedListInvitation.
  ///
  /// In pl, this message translates to:
  /// **'{name} udostępnił Ci listę zakupów'**
  String socialSharedListInvitation(String name);

  /// No description provided for @socialSomeone.
  ///
  /// In pl, this message translates to:
  /// **'Ktoś'**
  String get socialSomeone;

  /// No description provided for @socialShareRespond.
  ///
  /// In pl, this message translates to:
  /// **'Dotknij, aby odpowiedzieć'**
  String get socialShareRespond;

  /// No description provided for @socialShareAccept.
  ///
  /// In pl, this message translates to:
  /// **'Zaakceptuj'**
  String get socialShareAccept;

  /// No description provided for @notificationsTitle.
  ///
  /// In pl, this message translates to:
  /// **'Powiadomienia'**
  String get notificationsTitle;

  /// No description provided for @notificationsLoadFailed.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się załadować powiadomień'**
  String get notificationsLoadFailed;

  /// No description provided for @notificationsMarkAllFailed.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się oznaczyć wszystkich jako przeczytane'**
  String get notificationsMarkAllFailed;

  /// No description provided for @notificationsPlanEnded.
  ///
  /// In pl, this message translates to:
  /// **'Ten plan już się zakończył.'**
  String get notificationsPlanEnded;

  /// No description provided for @notificationsRecipeOpenFailed.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się otworzyć przepisu'**
  String get notificationsRecipeOpenFailed;

  /// No description provided for @notificationsJustNow.
  ///
  /// In pl, this message translates to:
  /// **'przed chwilą'**
  String get notificationsJustNow;

  /// No description provided for @notificationsMinutes.
  ///
  /// In pl, this message translates to:
  /// **'{count} min temu'**
  String notificationsMinutes(int count);

  /// No description provided for @notificationsHours.
  ///
  /// In pl, this message translates to:
  /// **'{count} godz. temu'**
  String notificationsHours(int count);

  /// No description provided for @notificationsDays.
  ///
  /// In pl, this message translates to:
  /// **'{count} dni temu'**
  String notificationsDays(int count);

  /// No description provided for @notificationsMarkAll.
  ///
  /// In pl, this message translates to:
  /// **'Oznacz wszystkie'**
  String get notificationsMarkAll;

  /// No description provided for @notificationsEmpty.
  ///
  /// In pl, this message translates to:
  /// **'Brak powiadomień'**
  String get notificationsEmpty;

  /// No description provided for @releasePromptTitle.
  ///
  /// In pl, this message translates to:
  /// **'Dostępna nowa wersja'**
  String get releasePromptTitle;

  /// No description provided for @releasePromptRequired.
  ///
  /// In pl, this message translates to:
  /// **'Ta wersja aplikacji nie jest już obsługiwana. Zaktualizuj ją, aby korzystać dalej.'**
  String get releasePromptRequired;

  /// No description provided for @releasePromptStoreError.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się otworzyć sklepu.'**
  String get releasePromptStoreError;

  /// No description provided for @releasePromptChanges.
  ///
  /// In pl, this message translates to:
  /// **'• Poprawiliśmy aktywację i przywracanie Premium po płatności.\n• Punkty Premium są naliczane prawidłowo także po przerwaniu połączenia lub ponowieniu płatności.\n• Ponowne skanowanie i wybór ilości zachowują gramaturę oraz jednostkę opakowania.\n• Poprawiliśmy podpowiedzi produktów i komunikaty w polskiej oraz angielskiej wersji.'**
  String get releasePromptChanges;

  /// No description provided for @detailPlanPortionHelp.
  ///
  /// In pl, this message translates to:
  /// **'Składniki przeliczono na {servings} porcji. Ilości wpisane w opisie przygotowania dotyczą bazowego przepisu ({baseServings} porcji).'**
  String detailPlanPortionHelp(int servings, int baseServings);

  /// No description provided for @releasePromptApple.
  ///
  /// In pl, this message translates to:
  /// **'Otwórz App Store'**
  String get releasePromptApple;

  /// No description provided for @releasePromptGoogle.
  ///
  /// In pl, this message translates to:
  /// **'Otwórz Google Play'**
  String get releasePromptGoogle;

  /// No description provided for @releasePromptLater.
  ///
  /// In pl, this message translates to:
  /// **'Później'**
  String get releasePromptLater;

  /// No description provided for @pantryAddProduct.
  ///
  /// In pl, this message translates to:
  /// **'Dodaj produkt'**
  String get pantryAddProduct;

  /// No description provided for @pantryEmpty.
  ///
  /// In pl, this message translates to:
  /// **'Spiżarnia jest pusta. Dodaj produkty, które masz w domu, żeby móc szybko sprawdzić, co z nich ugotować.'**
  String get pantryEmpty;

  /// No description provided for @pantryEnterAmount.
  ///
  /// In pl, this message translates to:
  /// **'Dotknij, aby wpisać ilość'**
  String get pantryEnterAmount;

  /// No description provided for @pantryRemove.
  ///
  /// In pl, this message translates to:
  /// **'Usuń ze spiżarni'**
  String get pantryRemove;

  /// No description provided for @pantryScanBarcode.
  ///
  /// In pl, this message translates to:
  /// **'Skanuj kod kreskowy'**
  String get pantryScanBarcode;

  /// No description provided for @pantryScanMany.
  ///
  /// In pl, this message translates to:
  /// **'Skanuj wiele produktów'**
  String get pantryScanMany;

  /// No description provided for @pantrySearchHint.
  ///
  /// In pl, this message translates to:
  /// **'Szukaj produktu...'**
  String get pantrySearchHint;

  /// No description provided for @pantrySearchStart.
  ///
  /// In pl, this message translates to:
  /// **'Wpisz nazwę produktu.'**
  String get pantrySearchStart;

  /// No description provided for @pantrySearchEmpty.
  ///
  /// In pl, this message translates to:
  /// **'Brak wyników.'**
  String get pantrySearchEmpty;

  /// No description provided for @pantrySaved.
  ///
  /// In pl, this message translates to:
  /// **'Dodano \"{name}\" do spiżarni.'**
  String pantrySaved(String name);

  /// No description provided for @matchTitle.
  ///
  /// In pl, this message translates to:
  /// **'Co ugotować z tego, co mam'**
  String get matchTitle;

  /// No description provided for @matchPremium.
  ///
  /// In pl, this message translates to:
  /// **'Funkcja Premium'**
  String get matchPremium;

  /// No description provided for @matchPremiumBody.
  ///
  /// In pl, this message translates to:
  /// **'Dopasowywanie przepisów do tego, co masz w spiżarni, jest dostępne dla kont z aktywną subskrypcją Premium.'**
  String get matchPremiumBody;

  /// No description provided for @matchSeePremium.
  ///
  /// In pl, this message translates to:
  /// **'Zobacz Premium'**
  String get matchSeePremium;

  /// No description provided for @matchSelectOne.
  ///
  /// In pl, this message translates to:
  /// **'Zaznacz przynajmniej jeden składnik.'**
  String get matchSelectOne;

  /// No description provided for @matchEmptyPantry.
  ///
  /// In pl, this message translates to:
  /// **'Twoja spiżarnia jest pusta. Dodaj do niej produkty, które masz w domu, żeby dopasować przepisy.'**
  String get matchEmptyPantry;

  /// No description provided for @matchAddPantry.
  ///
  /// In pl, this message translates to:
  /// **'Dodaj produkt do spiżarni'**
  String get matchAddPantry;

  /// No description provided for @matchSelected.
  ///
  /// In pl, this message translates to:
  /// **'Zaznaczono {selected} z {total}'**
  String matchSelected(int selected, int total);

  /// No description provided for @matchDeselect.
  ///
  /// In pl, this message translates to:
  /// **'Odznacz wszystko'**
  String get matchDeselect;

  /// No description provided for @matchSelectAll.
  ///
  /// In pl, this message translates to:
  /// **'Zaznacz wszystko'**
  String get matchSelectAll;

  /// No description provided for @matchSearch.
  ///
  /// In pl, this message translates to:
  /// **'Szukaj przepisów ({count})'**
  String matchSearch(int count);

  /// No description provided for @matchGenerate.
  ///
  /// In pl, this message translates to:
  /// **'Wygeneruj nowy przepis przez AI'**
  String get matchGenerate;

  /// No description provided for @matchResultsTitle.
  ///
  /// In pl, this message translates to:
  /// **'Dopasowane przepisy'**
  String get matchResultsTitle;

  /// No description provided for @matchResultsEmpty.
  ///
  /// In pl, this message translates to:
  /// **'Nie znaleziono żadnego przepisu w bazie pasującego do wybranych składników. Możesz zamiast tego wygenerować nowy przepis przez AI.'**
  String get matchResultsEmpty;

  /// No description provided for @matchOtherAi.
  ///
  /// In pl, this message translates to:
  /// **'Żaden nie pasuje? Wygeneruj przez AI'**
  String get matchOtherAi;

  /// No description provided for @matchReady.
  ///
  /// In pl, this message translates to:
  /// **'Możesz ugotować teraz'**
  String get matchReady;

  /// No description provided for @matchMissing.
  ///
  /// In pl, this message translates to:
  /// **'Brakuje: {ingredients}'**
  String matchMissing(String ingredients);

  /// No description provided for @matchSelectPrompt.
  ///
  /// In pl, this message translates to:
  /// **'Wygeneruj przepis na danie wykorzystujące głównie te składniki, które mam w domu: {ingredients}. Możesz dodać maksymalnie 2–3 powszechnie dostępne składniki, na przykład sól, przyprawy lub oliwę.'**
  String matchSelectPrompt(String ingredients);

  /// No description provided for @matchResultsPrompt.
  ///
  /// In pl, this message translates to:
  /// **'Wygeneruj przepis na danie wykorzystujące GŁÓWNIE te składniki, które mam w domu: {ingredients}. Możesz dodać maksymalnie 2-3 dodatkowe, powszechnie dostępne składniki (np. sól, przyprawy, oliwę), jeśli są potrzebne.'**
  String matchResultsPrompt(String ingredients);

  /// No description provided for @leaderTitle.
  ///
  /// In pl, this message translates to:
  /// **'Ranking autorów przepisów'**
  String get leaderTitle;

  /// No description provided for @leaderWeek.
  ///
  /// In pl, this message translates to:
  /// **'Ten tydzień'**
  String get leaderWeek;

  /// No description provided for @leaderAll.
  ///
  /// In pl, this message translates to:
  /// **'Cały czas'**
  String get leaderAll;

  /// No description provided for @leaderEmptyWeek.
  ///
  /// In pl, this message translates to:
  /// **'W tym tygodniu nikt jeszcze nie dodał\nzaakceptowanego przepisu. Bądź pierwszy!'**
  String get leaderEmptyWeek;

  /// No description provided for @leaderEmptyAll.
  ///
  /// In pl, this message translates to:
  /// **'Jeszcze nikt nie dodał zaakceptowanego przepisu\ndo wspólnego katalogu.'**
  String get leaderEmptyAll;

  /// No description provided for @leaderCount.
  ///
  /// In pl, this message translates to:
  /// **'{count} {noun}'**
  String leaderCount(int count, String noun);

  /// No description provided for @leaderRecipeSingular.
  ///
  /// In pl, this message translates to:
  /// **'przepis'**
  String get leaderRecipeSingular;

  /// No description provided for @leaderRecipeFew.
  ///
  /// In pl, this message translates to:
  /// **'przepisy'**
  String get leaderRecipeFew;

  /// No description provided for @leaderRecipeMany.
  ///
  /// In pl, this message translates to:
  /// **'przepisów'**
  String get leaderRecipeMany;

  /// No description provided for @adGateTitle.
  ///
  /// In pl, this message translates to:
  /// **'Obejrzyj krótką reklamę'**
  String get adGateTitle;

  /// No description provided for @adGateBody.
  ///
  /// In pl, this message translates to:
  /// **'Żeby przejść do Dziennika, obejrzyj krótką reklamę wideo do końca. To ograniczenie nie dotyczy kont Premium — tam Dziennik jest zawsze bez reklam.'**
  String get adGateBody;

  /// No description provided for @adGateFailed.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się załadować reklamy. Sprawdź połączenie z internetem i spróbuj ponownie.'**
  String get adGateFailed;

  /// No description provided for @adGateLoading.
  ///
  /// In pl, this message translates to:
  /// **'Ładowanie reklamy...'**
  String get adGateLoading;

  /// No description provided for @adGateWatch.
  ///
  /// In pl, this message translates to:
  /// **'Obejrzyj reklamę'**
  String get adGateWatch;

  /// No description provided for @adGateLater.
  ///
  /// In pl, this message translates to:
  /// **'Nie teraz'**
  String get adGateLater;

  /// No description provided for @promosTitle.
  ///
  /// In pl, this message translates to:
  /// **'Promocje'**
  String get promosTitle;

  /// No description provided for @promosAll.
  ///
  /// In pl, this message translates to:
  /// **'Wszystkie'**
  String get promosAll;

  /// No description provided for @promosFailed.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się załadować promocji.'**
  String get promosFailed;

  /// No description provided for @promosLoyalty.
  ///
  /// In pl, this message translates to:
  /// **'Wymaga karty lojalnościowej'**
  String get promosLoyalty;

  /// No description provided for @promosEmpty.
  ///
  /// In pl, this message translates to:
  /// **'Brak aktywnych promocji w tej chwili.'**
  String get promosEmpty;

  /// No description provided for @statsTitle.
  ///
  /// In pl, this message translates to:
  /// **'Statystyki'**
  String get statsTitle;

  /// No description provided for @statsWeight.
  ///
  /// In pl, this message translates to:
  /// **'Zmiana wagi'**
  String get statsWeight;

  /// No description provided for @statsWeightEmpty.
  ///
  /// In pl, this message translates to:
  /// **'Dodaj co najmniej jeden pomiar w profilu.'**
  String get statsWeightEmpty;

  /// No description provided for @statsAverageCalories.
  ///
  /// In pl, this message translates to:
  /// **'Średnio kcal'**
  String get statsAverageCalories;

  /// No description provided for @statsHydration.
  ///
  /// In pl, this message translates to:
  /// **'Nawodnienie'**
  String get statsHydration;

  /// No description provided for @statsFavorite.
  ///
  /// In pl, this message translates to:
  /// **'Ulubiony posiłek'**
  String get statsFavorite;

  /// No description provided for @statsNoData.
  ///
  /// In pl, this message translates to:
  /// **'Brak danych'**
  String get statsNoData;

  /// No description provided for @statsDailyCalories.
  ///
  /// In pl, this message translates to:
  /// **'Kalorie dziennie'**
  String get statsDailyCalories;

  /// No description provided for @statsCaloriesEmpty.
  ///
  /// In pl, this message translates to:
  /// **'Dodaj posiłki w Dzienniku, aby zobaczyć wykres.'**
  String get statsCaloriesEmpty;

  /// No description provided for @statsCalories.
  ///
  /// In pl, this message translates to:
  /// **'Kalorie'**
  String get statsCalories;

  /// No description provided for @statsDailyMacros.
  ///
  /// In pl, this message translates to:
  /// **'Makroskładniki dziennie'**
  String get statsDailyMacros;

  /// No description provided for @statsMacrosEmpty.
  ///
  /// In pl, this message translates to:
  /// **'Makroskładniki pojawią się po dodaniu posiłków.'**
  String get statsMacrosEmpty;

  /// No description provided for @statsProtein.
  ///
  /// In pl, this message translates to:
  /// **'Białko'**
  String get statsProtein;

  /// No description provided for @statsFat.
  ///
  /// In pl, this message translates to:
  /// **'Tłuszcze'**
  String get statsFat;

  /// No description provided for @statsCarbs.
  ///
  /// In pl, this message translates to:
  /// **'Węglowodany'**
  String get statsCarbs;

  /// No description provided for @statsDailyWater.
  ///
  /// In pl, this message translates to:
  /// **'Nawodnienie dziennie'**
  String get statsDailyWater;

  /// No description provided for @statsWaterEmpty.
  ///
  /// In pl, this message translates to:
  /// **'Zapisuj wodę w Dzienniku, aby zobaczyć wykres.'**
  String get statsWaterEmpty;

  /// No description provided for @statsWater.
  ///
  /// In pl, this message translates to:
  /// **'Woda'**
  String get statsWater;

  /// No description provided for @statsRecentDays.
  ///
  /// In pl, this message translates to:
  /// **'Ostatnie zapisane dni'**
  String get statsRecentDays;

  /// No description provided for @statsRecentEmpty.
  ///
  /// In pl, this message translates to:
  /// **'Zapisane posiłki i nawodnienie pojawią się tutaj.'**
  String get statsRecentEmpty;

  /// No description provided for @statsWeekly.
  ///
  /// In pl, this message translates to:
  /// **'Wnioski z ostatnich 7 dni'**
  String get statsWeekly;

  /// No description provided for @statsPremiumTitle.
  ///
  /// In pl, this message translates to:
  /// **'Pełny raport w Premium'**
  String get statsPremiumTitle;

  /// No description provided for @statsPremiumBody.
  ///
  /// In pl, this message translates to:
  /// **'Odblokuj analizę kalorii, nawodnienia i zmian wagi z konkretnymi wnioskami na każdy tydzień.'**
  String get statsPremiumBody;

  /// No description provided for @statsPremiumAction.
  ///
  /// In pl, this message translates to:
  /// **'Zobacz pełny raport'**
  String get statsPremiumAction;

  /// No description provided for @statsDailyMacroLine.
  ///
  /// In pl, this message translates to:
  /// **'{kcal} kcal  •  B {protein} g  •  T {fat} g  •  W {carbs} g'**
  String statsDailyMacroLine(
    String kcal,
    String protein,
    String fat,
    String carbs,
  );

  /// No description provided for @statsWaterLine.
  ///
  /// In pl, this message translates to:
  /// **'Woda: {amount} ml'**
  String statsWaterLine(int amount);

  /// No description provided for @statsMaximum.
  ///
  /// In pl, this message translates to:
  /// **'Maksimum: {amount} {unit}'**
  String statsMaximum(String amount, String unit);

  /// No description provided for @insightRegularity.
  ///
  /// In pl, this message translates to:
  /// **'Regularność: {count} z 7 dni'**
  String insightRegularity(int count);

  /// No description provided for @insightEnough.
  ///
  /// In pl, this message translates to:
  /// **'Masz już wystarczająco dużo danych, aby porównywać tygodnie.'**
  String get insightEnough;

  /// No description provided for @insightMoreDays.
  ///
  /// In pl, this message translates to:
  /// **'Uzupełnij jeszcze {count} dni, aby raport był dokładniejszy.'**
  String insightMoreDays(int count);

  /// No description provided for @insightCalories.
  ///
  /// In pl, this message translates to:
  /// **'Średnio {count} kcal dziennie'**
  String insightCalories(int count);

  /// No description provided for @insightCaloriesDetail.
  ///
  /// In pl, this message translates to:
  /// **'Porównuj średnią tydzień do tygodnia, zamiast oceniać pojedynczy dzień.'**
  String get insightCaloriesDetail;

  /// No description provided for @insightWaterMissing.
  ///
  /// In pl, this message translates to:
  /// **'Brakuje danych o nawodnieniu'**
  String get insightWaterMissing;

  /// No description provided for @insightWaterAverage.
  ///
  /// In pl, this message translates to:
  /// **'Średnio {amount} ml wody'**
  String insightWaterAverage(int amount);

  /// No description provided for @insightWaterEveryDay.
  ///
  /// In pl, this message translates to:
  /// **'Nawodnienie zostało zapisane każdego dnia tego tygodnia.'**
  String get insightWaterEveryDay;

  /// No description provided for @insightWaterDays.
  ///
  /// In pl, this message translates to:
  /// **'Zapisano nawodnienie w {count} z 7 dni.'**
  String insightWaterDays(int count);

  /// No description provided for @insightWeightStable.
  ///
  /// In pl, this message translates to:
  /// **'Waga bez większej zmiany'**
  String get insightWeightStable;

  /// No description provided for @insightWeightChange.
  ///
  /// In pl, this message translates to:
  /// **'Zmiana wagi {amount} kg'**
  String insightWeightChange(String amount);

  /// No description provided for @insightWeightDetail.
  ///
  /// In pl, this message translates to:
  /// **'Porównanie pierwszego i ostatniego pomiaru z ostatnich 7 dni.'**
  String get insightWeightDetail;

  /// No description provided for @cookingTipsTitle.
  ///
  /// In pl, this message translates to:
  /// **'Porady kulinarne'**
  String get cookingTipsTitle;

  /// No description provided for @splashSubtitle.
  ///
  /// In pl, this message translates to:
  /// **'Planuj posiłki mądrze i oszczędzaj'**
  String get splashSubtitle;

  /// No description provided for @onboardingStoresEmpty.
  ///
  /// In pl, this message translates to:
  /// **'Nie znaleziono sklepów. Spróbuj ponownie.'**
  String get onboardingStoresEmpty;

  /// No description provided for @authCaptchaUnavailable.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się wczytać weryfikacji. Sprawdź połączenie.'**
  String get authCaptchaUnavailable;

  /// No description provided for @authCaptchaRetry.
  ///
  /// In pl, this message translates to:
  /// **'Ponów'**
  String get authCaptchaRetry;

  /// No description provided for @authCaptchaContinue.
  ///
  /// In pl, this message translates to:
  /// **'Kontynuuj mimo to'**
  String get authCaptchaContinue;

  /// No description provided for @authCaptchaRefresh.
  ///
  /// In pl, this message translates to:
  /// **'Odśwież weryfikację'**
  String get authCaptchaRefresh;

  /// No description provided for @adminProductsTitle.
  ///
  /// In pl, this message translates to:
  /// **'Zgłoszone produkty'**
  String get adminProductsTitle;

  /// No description provided for @adminProductsEmpty.
  ///
  /// In pl, this message translates to:
  /// **'Brak produktów oczekujących na sprawdzenie.'**
  String get adminProductsEmpty;

  /// No description provided for @adminProductsRefresh.
  ///
  /// In pl, this message translates to:
  /// **'Odśwież zgłoszenia'**
  String get adminProductsRefresh;

  /// No description provided for @adminProductApproved.
  ///
  /// In pl, this message translates to:
  /// **'Produkt dodany do katalogu'**
  String get adminProductApproved;

  /// No description provided for @adminProductRejected.
  ///
  /// In pl, this message translates to:
  /// **'Produkt odrzucony'**
  String get adminProductRejected;

  /// No description provided for @adminNoNutrition.
  ///
  /// In pl, this message translates to:
  /// **'Bez wartości odżywczych'**
  String get adminNoNutrition;

  /// No description provided for @adminProductNutrition.
  ///
  /// In pl, this message translates to:
  /// **'Na 100 g: {kcal} kcal · B {protein} · T {fat} · W {carbs}'**
  String adminProductNutrition(
    String kcal,
    String protein,
    String fat,
    String carbs,
  );

  /// No description provided for @adminReject.
  ///
  /// In pl, this message translates to:
  /// **'Odrzuć'**
  String get adminReject;

  /// No description provided for @adminApprove.
  ///
  /// In pl, this message translates to:
  /// **'Akceptuj'**
  String get adminApprove;

  /// No description provided for @adminAllRecipesTitle.
  ///
  /// In pl, this message translates to:
  /// **'Wszystkie przepisy użytkowników'**
  String get adminAllRecipesTitle;

  /// No description provided for @adminRecipesEmpty.
  ///
  /// In pl, this message translates to:
  /// **'Brak przepisów dodanych przez użytkowników.'**
  String get adminRecipesEmpty;

  /// No description provided for @adminShowMore.
  ///
  /// In pl, this message translates to:
  /// **'Pokaż więcej'**
  String get adminShowMore;

  /// No description provided for @adminPublic.
  ///
  /// In pl, this message translates to:
  /// **'Publiczny'**
  String get adminPublic;

  /// No description provided for @adminPending.
  ///
  /// In pl, this message translates to:
  /// **'Oczekuje'**
  String get adminPending;

  /// No description provided for @adminRejected.
  ///
  /// In pl, this message translates to:
  /// **'Odrzucony'**
  String get adminRejected;

  /// No description provided for @adminPrivate.
  ///
  /// In pl, this message translates to:
  /// **'Prywatny'**
  String get adminPrivate;

  /// No description provided for @adminUnknownAuthor.
  ///
  /// In pl, this message translates to:
  /// **'Nieznany autor'**
  String get adminUnknownAuthor;

  /// No description provided for @adminDeleteRecipeTooltip.
  ///
  /// In pl, this message translates to:
  /// **'Usuń przepis'**
  String get adminDeleteRecipeTooltip;

  /// No description provided for @adminDeleteRecipeTitle.
  ///
  /// In pl, this message translates to:
  /// **'Usunąć przepis?'**
  String get adminDeleteRecipeTitle;

  /// No description provided for @adminDeleteRecipeBody.
  ///
  /// In pl, this message translates to:
  /// **'Usuniesz \"{name}\" oraz jego komentarze i powiązania (listy zakupów, plany posiłków innych użytkowników, którzy go używali). Tej operacji nie da się cofnąć.'**
  String adminDeleteRecipeBody(String name);

  /// No description provided for @adminRecipeFallback.
  ///
  /// In pl, this message translates to:
  /// **'ten przepis'**
  String get adminRecipeFallback;

  /// No description provided for @adminUsersTitle.
  ///
  /// In pl, this message translates to:
  /// **'Użytkownicy'**
  String get adminUsersTitle;

  /// No description provided for @adminUsersSearch.
  ///
  /// In pl, this message translates to:
  /// **'Szukaj po e-mailu lub nazwie…'**
  String get adminUsersSearch;

  /// No description provided for @adminUsersOnlyBanned.
  ///
  /// In pl, this message translates to:
  /// **'Tylko zablokowani'**
  String get adminUsersOnlyBanned;

  /// No description provided for @adminUsersEmpty.
  ///
  /// In pl, this message translates to:
  /// **'Brak wyników.'**
  String get adminUsersEmpty;

  /// No description provided for @adminUsersUnnamed.
  ///
  /// In pl, this message translates to:
  /// **'Bez nazwy'**
  String get adminUsersUnnamed;

  /// No description provided for @adminUsersVersion.
  ///
  /// In pl, this message translates to:
  /// **'Wersja: {version}'**
  String adminUsersVersion(String version);

  /// No description provided for @adminUsersReason.
  ///
  /// In pl, this message translates to:
  /// **'Powód: {reason}'**
  String adminUsersReason(String reason);

  /// No description provided for @adminUsersBanTitle.
  ///
  /// In pl, this message translates to:
  /// **'Zablokować {name}?'**
  String adminUsersBanTitle(String name);

  /// No description provided for @adminUsersBanBody.
  ///
  /// In pl, this message translates to:
  /// **'Konto straci dostęp do aplikacji natychmiast — również jeśli jest właśnie zalogowane. Dane nie zostaną usunięte, blokadę można cofnąć.'**
  String get adminUsersBanBody;

  /// No description provided for @adminUsersReasonLabel.
  ///
  /// In pl, this message translates to:
  /// **'Powód (widoczny dla użytkownika)'**
  String get adminUsersReasonLabel;

  /// No description provided for @adminUsersBan.
  ///
  /// In pl, this message translates to:
  /// **'Zablokuj'**
  String get adminUsersBan;

  /// No description provided for @adminUsersUnban.
  ///
  /// In pl, this message translates to:
  /// **'Odblokuj'**
  String get adminUsersUnban;

  /// No description provided for @adminUsersBanned.
  ///
  /// In pl, this message translates to:
  /// **'Konto zablokowane'**
  String get adminUsersBanned;

  /// No description provided for @adminUsersUnbanned.
  ///
  /// In pl, this message translates to:
  /// **'Konto odblokowane'**
  String get adminUsersUnbanned;

  /// No description provided for @adminCommentsTitle.
  ///
  /// In pl, this message translates to:
  /// **'Komentarze'**
  String get adminCommentsTitle;

  /// No description provided for @adminCommentsSearch.
  ///
  /// In pl, this message translates to:
  /// **'Szukaj w treści, autorze lub przepisie…'**
  String get adminCommentsSearch;

  /// No description provided for @adminCommentsEmpty.
  ///
  /// In pl, this message translates to:
  /// **'Brak komentarzy.'**
  String get adminCommentsEmpty;

  /// No description provided for @adminCommentsRecipe.
  ///
  /// In pl, this message translates to:
  /// **'pod: {name}'**
  String adminCommentsRecipe(String name);

  /// No description provided for @adminCommentsPhotoOnly.
  ///
  /// In pl, this message translates to:
  /// **'(samo zdjęcie)'**
  String get adminCommentsPhotoOnly;

  /// No description provided for @adminCommentsEmptyText.
  ///
  /// In pl, this message translates to:
  /// **'(pusty)'**
  String get adminCommentsEmptyText;

  /// No description provided for @adminCommentsHasPhoto.
  ///
  /// In pl, this message translates to:
  /// **'zawiera zdjęcie'**
  String get adminCommentsHasPhoto;

  /// No description provided for @adminCommentsDelete.
  ///
  /// In pl, this message translates to:
  /// **'Usuń komentarz'**
  String get adminCommentsDelete;

  /// No description provided for @adminCommentsDeleteTitle.
  ///
  /// In pl, this message translates to:
  /// **'Usunąć komentarz?'**
  String get adminCommentsDeleteTitle;

  /// No description provided for @adminCommentsDeleteBody.
  ///
  /// In pl, this message translates to:
  /// **'Tej operacji nie da się cofnąć.'**
  String get adminCommentsDeleteBody;

  /// No description provided for @adminCommentsDeleted.
  ///
  /// In pl, this message translates to:
  /// **'Komentarz usunięty'**
  String get adminCommentsDeleted;

  /// No description provided for @adminPhotosTitle.
  ///
  /// In pl, this message translates to:
  /// **'Zdjęcia do akceptacji'**
  String get adminPhotosTitle;

  /// No description provided for @adminPhotosEmpty.
  ///
  /// In pl, this message translates to:
  /// **'Brak zdjęć oczekujących na akceptację.'**
  String get adminPhotosEmpty;

  /// No description provided for @adminPhotosApproved.
  ///
  /// In pl, this message translates to:
  /// **'Zdjęcie zaakceptowane'**
  String get adminPhotosApproved;

  /// No description provided for @adminPhotosRejected.
  ///
  /// In pl, this message translates to:
  /// **'Zdjęcie odrzucone'**
  String get adminPhotosRejected;

  /// No description provided for @adminPhotosRecipe.
  ///
  /// In pl, this message translates to:
  /// **'Przepis'**
  String get adminPhotosRecipe;

  /// No description provided for @adminPhotosUnknownSubmitter.
  ///
  /// In pl, this message translates to:
  /// **'nieznany'**
  String get adminPhotosUnknownSubmitter;

  /// No description provided for @adminPhotosSubmittedBy.
  ///
  /// In pl, this message translates to:
  /// **'Zgłosił: {name}'**
  String adminPhotosSubmittedBy(String name);

  /// No description provided for @adminPhotosReplaceWarning.
  ///
  /// In pl, this message translates to:
  /// **'Uwaga: ten przepis ma już zdjęcie — akceptacja je zastąpi.'**
  String get adminPhotosReplaceWarning;

  /// No description provided for @adminPhotosLoadError.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się wczytać zdjęcia'**
  String get adminPhotosLoadError;

  /// No description provided for @adminPhotosApprove.
  ///
  /// In pl, this message translates to:
  /// **'Zaakceptuj'**
  String get adminPhotosApprove;

  /// No description provided for @adminMainTitle.
  ///
  /// In pl, this message translates to:
  /// **'Panel administratora'**
  String get adminMainTitle;

  /// No description provided for @adminMainBroadcastSent.
  ///
  /// In pl, this message translates to:
  /// **'Wysłano do {count} użytkowników.'**
  String adminMainBroadcastSent(String count);

  /// No description provided for @adminMainReportsTitle.
  ///
  /// In pl, this message translates to:
  /// **'Zgłoszenia treści'**
  String get adminMainReportsTitle;

  /// No description provided for @adminMainReportsHelp.
  ///
  /// In pl, this message translates to:
  /// **'Przepisy i komentarze zgłoszone przez użytkowników jako spam, nękanie albo inne naruszenie regulaminu.'**
  String get adminMainReportsHelp;

  /// No description provided for @adminMainReportsEmpty.
  ///
  /// In pl, this message translates to:
  /// **'Brak nierozpatrzonych zgłoszeń.'**
  String get adminMainReportsEmpty;

  /// No description provided for @adminMainRecipeType.
  ///
  /// In pl, this message translates to:
  /// **'Przepis'**
  String get adminMainRecipeType;

  /// No description provided for @adminMainCommentType.
  ///
  /// In pl, this message translates to:
  /// **'Komentarz'**
  String get adminMainCommentType;

  /// No description provided for @adminMainReportDetails.
  ///
  /// In pl, this message translates to:
  /// **'Szczegóły od zgłaszającego: {details}'**
  String adminMainReportDetails(String details);

  /// No description provided for @adminMainAuthor.
  ///
  /// In pl, this message translates to:
  /// **'Autor: {email}'**
  String adminMainAuthor(String email);

  /// No description provided for @adminMainReporter.
  ///
  /// In pl, this message translates to:
  /// **'Zgłosił: {email}'**
  String adminMainReporter(String email);

  /// No description provided for @adminMainDismiss.
  ///
  /// In pl, this message translates to:
  /// **'Odrzuć zgłoszenie'**
  String get adminMainDismiss;

  /// No description provided for @adminMainDeleteContent.
  ///
  /// In pl, this message translates to:
  /// **'Usuń treść'**
  String get adminMainDeleteContent;

  /// No description provided for @adminMainResolve.
  ///
  /// In pl, this message translates to:
  /// **'Oznacz jako rozpatrzone'**
  String get adminMainResolve;

  /// No description provided for @adminMainBroadcastTitle.
  ///
  /// In pl, this message translates to:
  /// **'Wyślij powiadomienie do wszystkich'**
  String get adminMainBroadcastTitle;

  /// No description provided for @adminMainBroadcastHelp.
  ///
  /// In pl, this message translates to:
  /// **'Trafi do dzwoneczka powiadomień KAŻDEGO użytkownika aplikacji — nieodwracalne, sprawdź treść przed wysłaniem.'**
  String get adminMainBroadcastHelp;

  /// No description provided for @adminMainBroadcastHint.
  ///
  /// In pl, this message translates to:
  /// **'Treść powiadomienia...'**
  String get adminMainBroadcastHint;

  /// No description provided for @adminMainBroadcastSend.
  ///
  /// In pl, this message translates to:
  /// **'Wyślij do wszystkich'**
  String get adminMainBroadcastSend;

  /// No description provided for @adminMainPromotionsLoadFailed.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się wczytać listy oczekujących promocji.'**
  String get adminMainPromotionsLoadFailed;

  /// No description provided for @adminMainScanSummary.
  ///
  /// In pl, this message translates to:
  /// **'Znaleziono {found}, zakolejkowano {queued} do akceptacji.'**
  String adminMainScanSummary(String found, String queued);

  /// No description provided for @adminMainScanPending.
  ///
  /// In pl, this message translates to:
  /// **'Skanowanie trwa na serwerze. Możesz wyjść z panelu; wyniki pojawią się w kolejce do akceptacji.'**
  String get adminMainScanPending;

  /// No description provided for @adminMainPromotionApproved.
  ///
  /// In pl, this message translates to:
  /// **'Promocja zaakceptowana'**
  String get adminMainPromotionApproved;

  /// No description provided for @adminMainPromotionRejected.
  ///
  /// In pl, this message translates to:
  /// **'Promocja odrzucona'**
  String get adminMainPromotionRejected;

  /// No description provided for @adminMainActionFailed.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się wykonać akcji'**
  String get adminMainActionFailed;

  /// No description provided for @adminMainRecipesLoadFailed.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się wczytać listy oczekujących przepisów.'**
  String get adminMainRecipesLoadFailed;

  /// No description provided for @adminMainReportsLoadFailed.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się wczytać zgłoszeń.'**
  String get adminMainReportsLoadFailed;

  /// No description provided for @adminMainDeleteContentTitle.
  ///
  /// In pl, this message translates to:
  /// **'Usunąć zgłoszoną treść?'**
  String get adminMainDeleteContentTitle;

  /// No description provided for @adminMainDeleteContentHelp.
  ///
  /// In pl, this message translates to:
  /// **'Komentarz albo przepis zostanie trwale usunięty, a zgłoszenie zamknięte. Tej operacji nie da się cofnąć.'**
  String get adminMainDeleteContentHelp;

  /// No description provided for @adminMainContentDeleted.
  ///
  /// In pl, this message translates to:
  /// **'Treść usunięta, zgłoszenie zamknięte'**
  String get adminMainContentDeleted;

  /// No description provided for @adminMainReportResolved.
  ///
  /// In pl, this message translates to:
  /// **'Zgłoszenie oznaczone jako rozpatrzone'**
  String get adminMainReportResolved;

  /// No description provided for @adminMainReportDismissed.
  ///
  /// In pl, this message translates to:
  /// **'Zgłoszenie odrzucone'**
  String get adminMainReportDismissed;

  /// No description provided for @adminMainRecipeApproved.
  ///
  /// In pl, this message translates to:
  /// **'Przepis zaakceptowany'**
  String get adminMainRecipeApproved;

  /// No description provided for @adminMainRecipeRejected.
  ///
  /// In pl, this message translates to:
  /// **'Przepis odrzucony'**
  String get adminMainRecipeRejected;

  /// No description provided for @adminMainRecipesTitle.
  ///
  /// In pl, this message translates to:
  /// **'Przepisy oczekujące na akceptację'**
  String get adminMainRecipesTitle;

  /// No description provided for @adminMainRecipesHelp.
  ///
  /// In pl, this message translates to:
  /// **'Przepisy zgłoszone przez użytkowników Premium do wspólnego, publicznego katalogu.'**
  String get adminMainRecipesHelp;

  /// No description provided for @adminMainRecipesEmpty.
  ///
  /// In pl, this message translates to:
  /// **'Brak przepisów czekających na akceptację.'**
  String get adminMainRecipesEmpty;

  /// No description provided for @adminMainRecipeMeta.
  ///
  /// In pl, this message translates to:
  /// **'{mealType} • {servings} porcji • {difficulty}'**
  String adminMainRecipeMeta(
    String mealType,
    String servings,
    String difficulty,
  );

  /// No description provided for @adminMainRecipePreview.
  ///
  /// In pl, this message translates to:
  /// **'Dotknij, aby sprawdzić składniki, instrukcję, zdjęcie i makro'**
  String get adminMainRecipePreview;

  /// No description provided for @adminMainApprove.
  ///
  /// In pl, this message translates to:
  /// **'Zaakceptuj'**
  String get adminMainApprove;

  /// No description provided for @adminMainAiTitle.
  ///
  /// In pl, this message translates to:
  /// **'Stan usługi AI'**
  String get adminMainAiTitle;

  /// No description provided for @adminMainAiHelp.
  ///
  /// In pl, this message translates to:
  /// **'Sprawdza, czy klucz Gemini działa i czy limit tokenów/zapytań nie został wyczerpany — dla każdego modelu z osobna.'**
  String get adminMainAiHelp;

  /// No description provided for @adminMainAiCheck.
  ///
  /// In pl, this message translates to:
  /// **'Sprawdź stan AI'**
  String get adminMainAiCheck;

  /// No description provided for @adminMainAiKeyMissing.
  ///
  /// In pl, this message translates to:
  /// **'Klucz API nie jest skonfigurowany.'**
  String get adminMainAiKeyMissing;

  /// No description provided for @adminMainScanTitle.
  ///
  /// In pl, this message translates to:
  /// **'Skanuj gazetki promocyjne'**
  String get adminMainScanTitle;

  /// No description provided for @adminMainScanHelp.
  ///
  /// In pl, this message translates to:
  /// **'AI przeszuka internet w poszukiwaniu aktualnej gazetki danego sklepu i rozpozna z niej promocje. Wynik trafi poniżej do akceptacji — nic nie zmienia się automatycznie.'**
  String get adminMainScanHelp;

  /// No description provided for @adminMainUkScanUnavailable.
  ///
  /// In pl, this message translates to:
  /// **'Brytyjskie źródła promocji są w przygotowaniu. Skaner polskich gazetek nie tworzy promocji w GBP.'**
  String get adminMainUkScanUnavailable;

  /// No description provided for @adminMainScanShop.
  ///
  /// In pl, this message translates to:
  /// **'Skanuj {store}'**
  String adminMainScanShop(String store);

  /// No description provided for @adminMainScanningShop.
  ///
  /// In pl, this message translates to:
  /// **'Skanowanie {store} trwa w tle. Możesz opuścić panel.'**
  String adminMainScanningShop(String store);

  /// No description provided for @adminMainPendingTitle.
  ///
  /// In pl, this message translates to:
  /// **'Oczekujące na akceptację'**
  String get adminMainPendingTitle;

  /// No description provided for @adminMainPromotionsEmpty.
  ///
  /// In pl, this message translates to:
  /// **'Brak promocji czekających na akceptację.'**
  String get adminMainPromotionsEmpty;

  /// No description provided for @adminMainProductsNav.
  ///
  /// In pl, this message translates to:
  /// **'Produkty'**
  String get adminMainProductsNav;

  /// No description provided for @adminMainUserRecipesNav.
  ///
  /// In pl, this message translates to:
  /// **'Przepisy użytkowników'**
  String get adminMainUserRecipesNav;

  /// No description provided for @campaignTitle.
  ///
  /// In pl, this message translates to:
  /// **'Kampanie'**
  String get campaignTitle;

  /// No description provided for @campaignRequired.
  ///
  /// In pl, this message translates to:
  /// **'Uzupełnij nazwę, daty, konfigurację oferty sklepu i odbiorcę.'**
  String get campaignRequired;

  /// No description provided for @campaignConfirmGoogle.
  ///
  /// In pl, this message translates to:
  /// **'Potwierdź ofertę w Google Play'**
  String get campaignConfirmGoogle;

  /// No description provided for @campaignConfirmApple.
  ///
  /// In pl, this message translates to:
  /// **'Potwierdź ofertę w App Store'**
  String get campaignConfirmApple;

  /// No description provided for @campaignConfirmPoints.
  ///
  /// In pl, this message translates to:
  /// **'Włącz tylko po ustawieniu czasowej ceny tego pakietu punktów w {store} dla wszystkich użytkowników. Cena w aplikacji pochodzi bezpośrednio ze sklepu.'**
  String campaignConfirmPoints(String store);

  /// No description provided for @campaignConfirmPremium.
  ///
  /// In pl, this message translates to:
  /// **'Włącz tylko wtedy, gdy wskazana oferta sklepu jest aktywna, ma dokładnie ten rabat i obejmuje właściwy produkt. Aplikacja nie zmienia ceny samodzielnie.'**
  String get campaignConfirmPremium;

  /// No description provided for @campaignConfirm.
  ///
  /// In pl, this message translates to:
  /// **'Potwierdzam'**
  String get campaignConfirm;

  /// No description provided for @campaignDeleteTitle.
  ///
  /// In pl, this message translates to:
  /// **'Usunąć kampanię?'**
  String get campaignDeleteTitle;

  /// No description provided for @campaignDeleteBody.
  ///
  /// In pl, this message translates to:
  /// **'Kampania „{name}” zniknie z panelu. Ofertę w sklepie trzeba wyłączyć osobno.'**
  String campaignDeleteBody(String name);

  /// No description provided for @campaignMarketGb.
  ///
  /// In pl, this message translates to:
  /// **'Rynek: Wielka Brytania • GBP • Europe/London'**
  String get campaignMarketGb;

  /// No description provided for @campaignMarketPl.
  ///
  /// In pl, this message translates to:
  /// **'Rynek: Polska • PLN • Europe/Warsaw'**
  String get campaignMarketPl;

  /// No description provided for @campaignHeading.
  ///
  /// In pl, this message translates to:
  /// **'Promocja Premium i punktów'**
  String get campaignHeading;

  /// No description provided for @campaignHelp.
  ///
  /// In pl, this message translates to:
  /// **'Szarfy pojawiają się na ikonkach w panelu Premium. Subskrypcja iOS otwiera kod ofertowy Apple, a Android wybiera ofertę Google Play. Dla punktów ustaw czasową cenę produktu w odpowiednim sklepie dla wszystkich.'**
  String get campaignHelp;

  /// No description provided for @campaignName.
  ///
  /// In pl, this message translates to:
  /// **'Nazwa kampanii'**
  String get campaignName;

  /// No description provided for @campaignStore.
  ///
  /// In pl, this message translates to:
  /// **'Sklep'**
  String get campaignStore;

  /// No description provided for @campaignOffer.
  ///
  /// In pl, this message translates to:
  /// **'Oferta'**
  String get campaignOffer;

  /// No description provided for @campaignSubscription.
  ///
  /// In pl, this message translates to:
  /// **'Subskrypcja Premium'**
  String get campaignSubscription;

  /// No description provided for @campaignPoints.
  ///
  /// In pl, this message translates to:
  /// **'Punkty premium'**
  String get campaignPoints;

  /// No description provided for @campaignProduct.
  ///
  /// In pl, this message translates to:
  /// **'Pakiet objęty ofertą'**
  String get campaignProduct;

  /// No description provided for @campaignDiscount.
  ///
  /// In pl, this message translates to:
  /// **'Rabat'**
  String get campaignDiscount;

  /// No description provided for @campaignAudience.
  ///
  /// In pl, this message translates to:
  /// **'Odbiorcy'**
  String get campaignAudience;

  /// No description provided for @campaignEveryone.
  ///
  /// In pl, this message translates to:
  /// **'Wszyscy'**
  String get campaignEveryone;

  /// No description provided for @campaignOneUser.
  ///
  /// In pl, this message translates to:
  /// **'Jeden użytkownik'**
  String get campaignOneUser;

  /// No description provided for @campaignEmail.
  ///
  /// In pl, this message translates to:
  /// **'E-mail użytkownika'**
  String get campaignEmail;

  /// No description provided for @campaignDates.
  ///
  /// In pl, this message translates to:
  /// **'Wybierz termin'**
  String get campaignDates;

  /// No description provided for @campaignAppleUrl.
  ///
  /// In pl, this message translates to:
  /// **'Link do kodu ofertowego Apple'**
  String get campaignAppleUrl;

  /// No description provided for @campaignAppleUrlHelp.
  ///
  /// In pl, this message translates to:
  /// **'Link apps.apple.com/redeem?ctx=offercodes…'**
  String get campaignAppleUrlHelp;

  /// No description provided for @campaignBasePlan.
  ///
  /// In pl, this message translates to:
  /// **'Google Play: ID planu bazowego'**
  String get campaignBasePlan;

  /// No description provided for @campaignAndroidOffer.
  ///
  /// In pl, this message translates to:
  /// **'Google Play: ID oferty'**
  String get campaignAndroidOffer;

  /// No description provided for @campaignPointsHelp.
  ///
  /// In pl, this message translates to:
  /// **'Najpierw zaplanuj czasową obniżkę ceny tego pakietu punktów w {store}. Kampania pokazuje szarfę, ale kwotę zawsze pobiera bezpośrednio ze sklepu.'**
  String campaignPointsHelp(String store);

  /// No description provided for @campaignSaving.
  ///
  /// In pl, this message translates to:
  /// **'Zapisuję…'**
  String get campaignSaving;

  /// No description provided for @campaignCreate.
  ///
  /// In pl, this message translates to:
  /// **'Utwórz kampanię (wyłączoną)'**
  String get campaignCreate;

  /// No description provided for @campaignSaved.
  ///
  /// In pl, this message translates to:
  /// **'Zapisane kampanie'**
  String get campaignSaved;

  /// No description provided for @campaignEmpty.
  ///
  /// In pl, this message translates to:
  /// **'Brak kampanii.'**
  String get campaignEmpty;

  /// No description provided for @campaignActive.
  ///
  /// In pl, this message translates to:
  /// **'Aktywna'**
  String get campaignActive;

  /// No description provided for @campaignDeleteTooltip.
  ///
  /// In pl, this message translates to:
  /// **'Usuń kampanię'**
  String get campaignDeleteTooltip;

  /// No description provided for @adminMarketLabel.
  ///
  /// In pl, this message translates to:
  /// **'Rynek katalogu'**
  String get adminMarketLabel;

  /// No description provided for @adminMarketBusy.
  ///
  /// In pl, this message translates to:
  /// **'Poczekaj na zakończenie bieżącej operacji.'**
  String get adminMarketBusy;

  /// No description provided for @adminMarketHelp.
  ///
  /// In pl, this message translates to:
  /// **'Zmienia widok danych, nie kraj Twojego konta.'**
  String get adminMarketHelp;

  /// No description provided for @adminMarketPl.
  ///
  /// In pl, this message translates to:
  /// **'Polska'**
  String get adminMarketPl;

  /// No description provided for @adminMarketGb.
  ///
  /// In pl, this message translates to:
  /// **'Wielka Brytania'**
  String get adminMarketGb;

  /// No description provided for @approvalRecipePending.
  ///
  /// In pl, this message translates to:
  /// **'Ten przepis czeka na Twoją akceptację do wspólnego katalogu'**
  String get approvalRecipePending;

  /// No description provided for @approvalRecipeApprove.
  ///
  /// In pl, this message translates to:
  /// **'Zaakceptuj'**
  String get approvalRecipeApprove;

  /// No description provided for @approvalRecipeApproved.
  ///
  /// In pl, this message translates to:
  /// **'Przepis zaakceptowany'**
  String get approvalRecipeApproved;

  /// No description provided for @approvalRecipeRejected.
  ///
  /// In pl, this message translates to:
  /// **'Przepis odrzucony'**
  String get approvalRecipeRejected;

  /// No description provided for @approvalRecipeFailed.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się wykonać akcji'**
  String get approvalRecipeFailed;

  /// No description provided for @shoppingAddQueryHint.
  ///
  /// In pl, this message translates to:
  /// **'Wpisz dowolną pozycję…'**
  String get shoppingAddQueryHint;

  /// No description provided for @shoppingAddCustom.
  ///
  /// In pl, this message translates to:
  /// **'Dodaj wpisaną pozycję'**
  String get shoppingAddCustom;

  /// No description provided for @shoppingAddMatches.
  ///
  /// In pl, this message translates to:
  /// **'Pasujące produkty z bazy i wcześniejszych skanów'**
  String get shoppingAddMatches;

  /// No description provided for @shoppingAddMinimumQuery.
  ///
  /// In pl, this message translates to:
  /// **'Wpisz co najmniej 2 znaki, żeby wyszukać produkt.'**
  String get shoppingAddMinimumQuery;

  /// No description provided for @shoppingAddNoResults.
  ///
  /// In pl, this message translates to:
  /// **'Nie znaleziono produktu o takiej nazwie.'**
  String get shoppingAddNoResults;

  /// No description provided for @shoppingAddSuccess.
  ///
  /// In pl, this message translates to:
  /// **'Dodano: {name}'**
  String shoppingAddSuccess(String name);

  /// No description provided for @shoppingAddCustomFailed.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się dodać pozycji'**
  String get shoppingAddCustomFailed;

  /// No description provided for @shoppingAddProductFailed.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się dodać produktu'**
  String get shoppingAddProductFailed;

  /// No description provided for @shoppingAddProductFallback.
  ///
  /// In pl, this message translates to:
  /// **'Produkt'**
  String get shoppingAddProductFallback;

  /// No description provided for @shoppingAddCatalogSource.
  ///
  /// In pl, this message translates to:
  /// **'Katalog aplikacji'**
  String get shoppingAddCatalogSource;

  /// No description provided for @shoppingAddCacheSource.
  ///
  /// In pl, this message translates to:
  /// **'Wcześniej zeskanowany'**
  String get shoppingAddCacheSource;

  /// No description provided for @exportListHeading.
  ///
  /// In pl, this message translates to:
  /// **'Moja lista zakupów: {store}'**
  String exportListHeading(String store);

  /// No description provided for @exportListSubject.
  ///
  /// In pl, this message translates to:
  /// **'Lista zakupów - {store}'**
  String exportListSubject(String store);

  /// No description provided for @exportListTitle.
  ///
  /// In pl, this message translates to:
  /// **'Eksportuj listę'**
  String get exportListTitle;

  /// No description provided for @exportListCopy.
  ///
  /// In pl, this message translates to:
  /// **'Kopiuj do schowka'**
  String get exportListCopy;

  /// No description provided for @exportListCopied.
  ///
  /// In pl, this message translates to:
  /// **'Skopiowano do schowka!'**
  String get exportListCopied;

  /// No description provided for @exportListOpenApp.
  ///
  /// In pl, this message translates to:
  /// **'Otwórz {name}'**
  String exportListOpenApp(String name);

  /// No description provided for @exportListAppMissing.
  ///
  /// In pl, this message translates to:
  /// **'Aplikacja nie jest zainstalowana.'**
  String get exportListAppMissing;

  /// No description provided for @exportListAppFailed.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się otworzyć aplikacji.'**
  String get exportListAppFailed;

  /// No description provided for @exportListComingSoon.
  ///
  /// In pl, this message translates to:
  /// **'Wkrótce'**
  String get exportListComingSoon;

  /// No description provided for @diarySignInView.
  ///
  /// In pl, this message translates to:
  /// **'Musisz być zalogowany, aby zobaczyć dziennik.'**
  String get diarySignInView;

  /// No description provided for @diarySignInAdd.
  ///
  /// In pl, this message translates to:
  /// **'Musisz być zalogowany, aby dodać wpis.'**
  String get diarySignInAdd;

  /// No description provided for @authStoredSessionFailed.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się odtworzyć zapisanej sesji. Spróbuj zalogować się ponownie.'**
  String get authStoredSessionFailed;

  /// No description provided for @authGoogleNativeFailed.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się zalogować przez Google ({code}). Spróbuj ponownie.'**
  String authGoogleNativeFailed(Object code);

  /// No description provided for @authGoogleTokenUnavailable.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się uzyskać tokenu tożsamości Google.'**
  String get authGoogleTokenUnavailable;

  /// No description provided for @authAppleNativeFailed.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się zalogować przez Apple. Spróbuj ponownie.'**
  String get authAppleNativeFailed;

  /// No description provided for @authAppleTokenUnavailable.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się uzyskać tokenu tożsamości Apple.'**
  String get authAppleTokenUnavailable;

  /// No description provided for @shoppingLimitTitle.
  ///
  /// In pl, this message translates to:
  /// **'Kolejne zakupy? Z Premium bez limitu'**
  String get shoppingLimitTitle;

  /// No description provided for @shoppingLimitDescription.
  ///
  /// In pl, this message translates to:
  /// **'Wykorzystano już jedną bezpłatną listę w tym tygodniu. Z Premium twórz osobne listy na przepisy, sklepy i kolejne zakupy — kiedy potrzebujesz.'**
  String get shoppingLimitDescription;

  /// No description provided for @shoppingLimitSeePremium.
  ///
  /// In pl, this message translates to:
  /// **'Zobacz Premium'**
  String get shoppingLimitSeePremium;

  /// No description provided for @shoppingLimitBack.
  ///
  /// In pl, this message translates to:
  /// **'Wróć do mojej listy'**
  String get shoppingLimitBack;

  /// No description provided for @shoppingLimitShort.
  ///
  /// In pl, this message translates to:
  /// **'Tygodniowy limit list został wykorzystany. Z Premium tworzysz kolejne bez limitu.'**
  String get shoppingLimitShort;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'pl'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+country codes are specified.
  switch (locale.languageCode) {
    case 'en':
      {
        switch (locale.countryCode) {
          case 'GB':
            return AppLocalizationsEnGb();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'pl':
      return AppLocalizationsPl();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
