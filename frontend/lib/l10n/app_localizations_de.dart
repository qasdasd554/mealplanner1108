// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get receiptScanTitle => 'Kassenbon scannen';

  @override
  String get receiptQuickAddHint => 'Lebensmittel zum Vorrat hinzufügen';

  @override
  String get receiptPremiumMessage =>
      'Kassenbons scannen ist eine Premium-Funktion. Fotografiere deinen Bon und übernimm erkannte Lebensmittel in deinen Vorrat.';

  @override
  String get receiptPhotoGuide =>
      'Fotografiere alle Positionen auf dem Kassenbon.';

  @override
  String get receiptPhotoPrivacy =>
      'Das Foto wird zur KI-Erkennung übertragen. Lass Zahlungs- und Kundenkartendaten möglichst außerhalb des Bildes.';

  @override
  String get receiptPhotoSize => 'Wähle ein Foto unter 8 MB.';

  @override
  String get receiptPhotoError =>
      'Das Foto konnte nicht geöffnet werden. Nimm ein neues Foto auf oder wähle ein anderes aus.';

  @override
  String get receiptReadAction => 'Kassenbon auslesen';

  @override
  String get receiptReading => 'Kassenbon wird ausgelesen …';

  @override
  String get receiptReviewTitle => 'Lebensmittel überprüfen';

  @override
  String get receiptReviewHint =>
      'Entferne den Haken bei Artikeln, die du nicht speichern möchtest. Prüfe vor dem Speichern Mengen und Einheiten.';

  @override
  String get receiptQuantityUnreadable =>
      'Menge nicht erkennbar. Wähle den Artikel aus, um sie einzugeben.';

  @override
  String get receiptCheckQuantity => 'Menge prüfen';

  @override
  String get receiptEmpty =>
      'Auf dem Foto wurden keine Lebensmittel erkannt. Versuche es mit einem schärferen Foto.';

  @override
  String get receiptSaveAction => 'Im Vorrat speichern';

  @override
  String get receiptSaving => 'Lebensmittel werden gespeichert …';

  @override
  String get receiptNoCompatibleStock =>
      'Die Mengen im Vorrat sind unbekannt oder haben andere Einheiten. Passe sie vor einem erneuten Import an.';

  @override
  String get receiptAlreadySaved =>
      'Dieser Kassenbon wurde bereits gespeichert.';

  @override
  String receiptSaved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Artikel im Vorrat gespeichert.',
      one: '1 Artikel im Vorrat gespeichert.',
    );
    return '$_temp0';
  }

  @override
  String receiptSkipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count Artikel übersprungen, weil die Vorratsmengen nicht zusammengefasst werden konnten.',
      one:
          '1 Artikel übersprungen, weil die Vorratsmengen nicht zusammengefasst werden konnten.',
    );
    return '$_temp0';
  }

  @override
  String get scanPantryAmountHint =>
      'Wähle eine Menge in Gramm oder Millilitern';

  @override
  String get foodEntryTitle => 'Mahlzeit hinzufügen';

  @override
  String get foodEntryFromPlan => 'Aus dem Plan';

  @override
  String get foodEntryFromRecipes => 'Aus Rezepten';

  @override
  String get foodEntryProducts => 'Produkte';

  @override
  String get foodEntryServingsQuestion =>
      'Wie viele Portionen hast du gegessen?';

  @override
  String get foodEntryMealFailed => 'Konnte die Mahlzeit nicht hinzufügen';

  @override
  String get foodEntryProductFailed => 'Konnte das Produkt nicht hinzufügen';

  @override
  String get foodEntryMealType => 'Art der Mahlzeit';

  @override
  String get foodEntryAddDiary => 'Ins Tagebuch eintragen';

  @override
  String get foodEntryNoPlan =>
      'Du hast noch keinen aktiven Essensplan. Erstelle auf der Startseite einen Plan, um Mahlzeiten mit einem Tippen einzutragen.';

  @override
  String get foodEntryNoPlannedMeals =>
      'Keine Mahlzeiten für den ausgewählten Tag geplant.';

  @override
  String get foodEntryRecipesFailed => 'Konnte Rezepte nicht laden';

  @override
  String get foodEntryRecipeSearch => 'Rezepte suchen …';

  @override
  String get foodEntryNoResults => 'Keine Ergebnisse.';

  @override
  String get foodEntryServings => 'Anzahl der Portionen';

  @override
  String get foodEntryAdjustIngredients => 'Zutaten anpassen';

  @override
  String get foodEntryRepeatFailed => 'Kann den Eintrag nicht wiederholen';

  @override
  String get foodEntryRepeat => 'Nochmals hinzufügen';

  @override
  String get foodEntryMissingProduct =>
      'Produkt fehlt? Fügen Sie es dem Katalog hinzu';

  @override
  String get foodEntrySaveFailed => 'Konnte den Eintrag nicht hinzufügen';

  @override
  String get foodEntryChooseCatalogue => 'Wählen Sie aus dem Katalog';

  @override
  String get foodEntryProductName => 'Bezeichnung des Produkts/der Mahlzeit';

  @override
  String get foodEntryNameHint =>
      'Geben Sie einen Namen ein oder wählen Sie einen Vorschlag';

  @override
  String get foodEntryNameRequired => 'Name eintragen';

  @override
  String get foodEntryPortion => 'Portion (g/ml, optional)';

  @override
  String get foodEntryCalories => 'Kalorien (kcal)';

  @override
  String get foodEntryRequired => 'erforderlich';

  @override
  String get foodEntryProtein => 'Protein (g)';

  @override
  String get foodEntryCarbs => 'Kohlenhydrate (g)';

  @override
  String get foodEntryFat => 'Fett (g)';

  @override
  String get foodEntrySave => 'Im Tagebuch speichern';

  @override
  String get foodEntryInvalidNumber =>
      'Geben Sie eine gültige, nicht negative Zahl ein.';

  @override
  String get foodEntryInvalidPortion =>
      'Geben Sie einen Betrag über 0 an (max. 1000000).';

  @override
  String get scanZoomUnavailable => 'Diese Kamera unterstützt keinen Zoom.';

  @override
  String get scanZoomHint =>
      'Verwenden Sie 2x Zoom oder bewegen Sie das Telefon weiter weg.';

  @override
  String get scanLensFailed => 'Konnte die Kameraobjektive nicht wechseln.';

  @override
  String get scanEnterCode => 'Geben Sie einen Barcode ein';

  @override
  String get scanCodeHint => '8–14 Ziffern';

  @override
  String get scanBatchCodeHint => '8, 12, 13 oder 14 Stellen';

  @override
  String get scanSearch => 'Suchen';

  @override
  String get scanCodeInvalidLength => 'Der Code muss 8–14 Ziffern enthalten.';

  @override
  String get scanCodeInvalid =>
      'Der Code ist ungültig. Überprüfen Sie die Ziffern.';

  @override
  String get scanDuplicate => 'Dieses Produkt wurde bereits gescannt.';

  @override
  String get scanGuide =>
      'Richten Sie die Kamera auf einen Barcode und tippen Sie auf das Bild, um es zu fokussieren.';

  @override
  String get scanNormal => 'Normal';

  @override
  String get scanCloseUp => 'Nahaufnahme';

  @override
  String get scanTorch => 'Taschenlampe';

  @override
  String get scanManual => 'Code manuell eingeben';

  @override
  String get scanNormalLens => 'Standardobjektiv';

  @override
  String get scanCloseUpMode => 'Nahaufnahme';

  @override
  String get scanZoomTwo => 'Zoom 2x';

  @override
  String get scanZoomOne => 'Zoom 1x';

  @override
  String get scanMissing =>
      'Nicht gefunden. Tippen Sie auf, um das Produkt aus Fotos hinzuzufügen.';

  @override
  String get scanMissingNutrition =>
      'Produkt gefunden, aber Kalorien oder Makros fehlen. Tippen Sie, um die Daten von Etikettenfotos zu vervollständigen.';

  @override
  String get scanMissingPackage =>
      'Produkt gefunden, aber die ganze Packung Größe fehlt. Tippen Sie auf, um es von einem Etikett Foto zu lesen.';

  @override
  String get scanCorrectNutrition =>
      'Kalorien oder Makros fehlen, tippen Sie auf, um die Daten zu korrigieren.';

  @override
  String get scanCorrectPackage =>
      'Die Gesamtpackgröße konnte nicht gelesen werden. Tippen Sie, um die Fotos zu aktualisieren oder den Betrag manuell einzugeben.';

  @override
  String get scanAddedPantry => 'Zum Vorrat hinzugefügt';

  @override
  String get scanAddedDiary => 'Zum Tagebuch hinzugefügt';

  @override
  String get scanNutritionUnconfirmed =>
      'Der Server bestätigte die Nährwerte des Produkts nicht.';

  @override
  String get scanAlreadyCatalogue => 'Schon im Katalog';

  @override
  String get scanAddedCatalogue => 'Zum Katalog hinzugefügt';

  @override
  String get scanAlreadySubmitted => 'Bereits eingereichtes Produkt';

  @override
  String get scanWaitLookup => 'Warten Sie, bis alle Codes erkannt werden.';

  @override
  String get scanFirstProduct => 'Scannen Sie zuerst mindestens ein Produkt.';

  @override
  String get scanCompleteMissing =>
      'Nicht anerkannte Erzeugnisse ausfüllen oder erneut versuchen.';

  @override
  String get scanChooseDestinations =>
      'Wähle mindestens ein Ziel für alle gescannten Produkte.';

  @override
  String get scanBatchTitle => 'Stichprobenabtastung';

  @override
  String get scanFinish => 'Ende';

  @override
  String get scanBatchGuide =>
      'Scanne die Produkte nacheinander und wähle am Ende aus, wo du alle speichern möchtest.';

  @override
  String get scanBatchEmpty => 'Gescannte Produkte werden hier erscheinen.';

  @override
  String get scanPremiumPreview => 'Premium Feature Preview';

  @override
  String get scanPreviewTitle => 'Scannen Sie Ihren gesamten Shop auf einmal';

  @override
  String get scanPreviewBody =>
      'Die Kamera bleibt offen und erkannte Produkte erscheinen in einer Liste. Wählen Sie Ziele am Ende und bestätigen Sie alles einmal.';

  @override
  String get scanSampleYogurt => 'Naturjoghurt';

  @override
  String get scanSamplePasta => 'Vollweizenteigwaren';

  @override
  String get scanSampleYogurtMacro => '100 g: 62 kcal · P 4 g · F 3 g · C 5 g';

  @override
  String get scanSamplePastaMacro =>
      '100 g: 348 kcal · P 13 g · F 3 g · C 65 g';

  @override
  String get scanAllDestinations => 'Alles hinzufügen';

  @override
  String get scanTrial => 'Entdecken Sie Premium';

  @override
  String get scanPreviewNoCamera =>
      'Dies ist eine Vorschau - die Kamera wurde nicht gestartet.';

  @override
  String get scanMealTypeAll => 'Art der Mahlzeit für alle Produkte';

  @override
  String get scanAdding => 'Hinzufügen von Produkten...';

  @override
  String get scanRecognising => 'Anerkennung...';

  @override
  String get scanReady => 'Bereit zum Hinzufügen mit dem Batch';

  @override
  String get scanSaving => 'Hinzufügen von...';

  @override
  String get scanDone => 'Geschehen';

  @override
  String get scanTapComplete => 'Tippen Sie auf vollständige Produktdetails';

  @override
  String get scanTapRetry => 'Fehler. Tippen, um es erneut zu versuchen.';

  @override
  String get scanWhere => 'Wo möchten Sie dieses Produkt hinzufügen?';

  @override
  String get scanMultiHint =>
      'Sie können mehrere Ziele gleichzeitig auswählen.';

  @override
  String get scanNutritionMissingHint =>
      'Vollständige Nährwerte wurden nicht gefunden. Nach der Auswahl eines Ziels können Sie die Daten aus Verpackungsfotos vervollständigen.';

  @override
  String get scanDiaryDestination => 'Hinzufügen zum Tagebuch';

  @override
  String get scanDiaryDestinationHint =>
      'Wählen Sie eine Menge und Mahlzeit Art';

  @override
  String get scanCatalogueDestination => 'Hinzufügen zum Produktkatalog';

  @override
  String get scanCatalogueDestinationHint =>
      'Überprüfen Sie den Namen, die Marke und Ernährung';

  @override
  String get scanPantryDestination => 'Zum Vorrat hinzufügen';

  @override
  String get scanPantryDestinationHint => 'Sparen Sie als 1 ganze Packung';

  @override
  String get scanNext => 'Nächster Artikel';

  @override
  String get catalogueNutritionMissing =>
      'Vollständige Nährwerte konnten nicht online gefunden werden.';

  @override
  String get catalogueIncomplete =>
      'Dieses Produkt hat noch keine Nährwerte. Fügen Sie es dem Katalog mit Etikettendaten hinzu, um es im Tagebuch zu verwenden.';

  @override
  String get catalogueProductSearch => 'Produkte suchen …';

  @override
  String get catalogueNoMatch => 'Keine Produkte passen zu Ihrer Suche.';

  @override
  String get autocompleteCatalogue => 'App Katalog';

  @override
  String get autocompleteScanned => 'vorher gescannt';

  @override
  String get autocompleteHint =>
      'Sie können einen Vorschlag auswählen oder Ihren eigenen Namen behalten.';

  @override
  String foodEntryPlanDate(String date) {
    return 'Ihr aktiver Plan deckt das ausgewählte Datum nicht ab ($date).';
  }

  @override
  String foodEntryKcalServing(String kcal) {
    return '$kcal kcal / Serving';
  }

  @override
  String scanCameraError(String error) {
    return 'Die Kamera konnte nicht gestartet werden. Prüfen Sie die Erlaubnis der Kamera oder geben Sie den Code manuell ein.\n$error';
  }

  @override
  String scanBatchCameraError(String error) {
    return 'Die Kamera konnte nicht gestartet werden.\n$error';
  }

  @override
  String scanRetryError(String error) {
    return '$error Tippen Sie, um es noch einmal zu versuchen.';
  }

  @override
  String scanRetrySavedError(String error) {
    return '$error Erledigte Ziele werden nicht wieder hinzugefügt.';
  }

  @override
  String scanAddedPoints(int points) {
    return 'Zum Katalog hinzugefügt (+$points pt)';
  }

  @override
  String scanAddedCount(int count) {
    return 'Hinzugefügt $count Produkte.';
  }

  @override
  String scanAddedPartial(int saved, int total) {
    return '$saved von $total. Tippen Sie auf fehlgeschlagene Elemente, um es erneut zu versuchen.';
  }

  @override
  String scanQueueCount(int count) {
    return 'Produkte erkennen · $count warten';
  }

  @override
  String scanDoneCount(int count) {
    return 'Fertig · $count Erzeugnisse';
  }

  @override
  String scanAddAllCount(int count) {
    return 'Fügen Sie alle hinzu ($count)';
  }

  @override
  String scanCodeLabel(String code) {
    return 'Code: $code';
  }

  @override
  String scanDestinationsCount(int count) {
    return 'Zu $count Destinationen hinzufügen';
  }

  @override
  String scanPantryAddedName(String name) {
    return '$name zum Vorrat hinzugefügt.';
  }

  @override
  String get diaryCustomWater => 'Eigene Menge';

  @override
  String get rewardProductSemantics =>
      'Belohnung: ein Premium-Punkt für das Hinzufügen eines neuen, einzigartigen Produkts in den Katalog.';

  @override
  String get rewardProductTitle => '1 Premium-Punkt verdienen';

  @override
  String get rewardProductBody =>
      'Scannen Sie einen Barcode oder fügen Sie manuell ein neues, einzigartiges Produkt in den Katalog ein.';

  @override
  String get rewardProductPoint => '+1 pt';

  @override
  String get productsMarketUnavailable =>
      'Eine verifizierte Preisliste ist für diesen Markt nicht verfügbar.';

  @override
  String get home => 'Start';

  @override
  String get recipes => 'Rezepte';

  @override
  String get shopping => 'Einkauf';

  @override
  String get diary => 'Ernährungstagebuch';

  @override
  String get premium => 'Premium';

  @override
  String get profile => 'Profil';

  @override
  String get add => 'Hinzufügen';

  @override
  String get newPlan => 'Neuer Plan';

  @override
  String get planMeals => 'Planen Sie Ihre Mahlzeiten';

  @override
  String get productDatabase => 'Lebensmitteldatenbank';

  @override
  String get checkPrices => 'Kontrollpreise';

  @override
  String get promotions => 'Angebote';

  @override
  String get currentOffers => 'Aktuelle Angebote';

  @override
  String get pantry => 'Vorrat';

  @override
  String get whatYouHaveAtHome => 'Was Sie zu Hause haben';

  @override
  String get planArchive => 'Archivierte Pläne';

  @override
  String get scanBarcode => 'Scannen Sie einen Barcode';

  @override
  String get batchScan => 'Mehrere Produkte scannen';

  @override
  String get addRecipeWithAi => 'Rezept mit KI hinzufügen';

  @override
  String get addMeal => 'Hinzufügen einer Mahlzeit';

  @override
  String get addToPantry => 'Zum Vorrat hinzufügen';

  @override
  String get barcodeDestinations =>
      'Ins Tagebuch, in die Lebensmitteldatenbank oder in den Vorrat übernehmen';

  @override
  String get whatToAdd => 'Was möchten Sie hinzufügen?';

  @override
  String get scanProduct => 'Scannen Sie ein Produkt';

  @override
  String get batchDestinationHint =>
      'Wähle aus, wo du alle Produkte speichern möchtest, und bestätige einmal.';

  @override
  String get aiRecipeSources => 'Aus einem Foto, Text oder Link';

  @override
  String get recordCaloriesAndMacros => 'Kalorien und Makros aufzeichnen';

  @override
  String get premiumTwoPoints => 'Premium oder 2 Punkte';

  @override
  String recipeLoadError(String error) {
    return 'Rezepte konnten nicht geladen werden: $error';
  }

  @override
  String recipeLoadMoreError(String error) {
    return 'Weitere Rezepte konnten nicht geladen werden: $error';
  }

  @override
  String get recipeImportInProgress => 'Die KI fügt dein Rezept hinzu';

  @override
  String get recipeAuthorRanking => 'Rangliste der Rezeptautoren';

  @override
  String get recipeSearchHint => 'Rezept, Name oder Zutat …';

  @override
  String get clearSearch => 'Klare Suche';

  @override
  String get recipeFavourites => 'Favoriten';

  @override
  String get recipeMine => 'Meine Rezepte';

  @override
  String get recipeNew => 'Neu';

  @override
  String get recipeCommunity => 'Gemeinschaft';

  @override
  String get moreFilters => 'Mehr';

  @override
  String get loadingMore => 'Beladung...';

  @override
  String get showMoreRecipes => 'Mehr Rezepte anzeigen';

  @override
  String get addRecipe => 'Hinzufügen eines Rezepts';

  @override
  String get withAi => 'Mit KI';

  @override
  String get takeRecipePhoto => 'Machen Sie ein Foto';

  @override
  String get recipePhotoHint => 'mit einem Rezept oder einem fertigen Gericht';

  @override
  String get pasteText => 'Pastentext';

  @override
  String get pasteLink => 'Einfügen eines Links';

  @override
  String get addManually => 'Manuelles Hinzufügen';

  @override
  String get filters => 'Filter';

  @override
  String get clearFilters => 'klar';

  @override
  String get sortRecipes => 'Sortieren nach';

  @override
  String get sortAlphabetically => 'Alphabetisch';

  @override
  String get sortCaloriesLow => 'Kalorien: niedrigste erste';

  @override
  String get sortCaloriesHigh => 'Kalorien: höchste zuerst';

  @override
  String get sortQuickest => 'Schneller First';

  @override
  String get recipeDiet => 'Ernährungsform';

  @override
  String get allRecipes => 'alle';

  @override
  String get recipeMealType => 'Mahlzeit';

  @override
  String get filterBreakfast => 'Frühstück';

  @override
  String get filterLunch => 'Mittagessen';

  @override
  String get filterDinner => 'Abendessen';

  @override
  String get filterSnacks => 'Snacks';

  @override
  String get filterDesserts => 'Desserts';

  @override
  String get recipeDifficulty => 'Schwierigkeit';

  @override
  String get anyDifficulty => 'alle';

  @override
  String get filterEasy => 'Leicht';

  @override
  String get filterMedium => 'mittelgroß';

  @override
  String get filterHard => 'hart';

  @override
  String get showResults => 'Showergebnisse';

  @override
  String recipeCardSummary(int minutes, int calories) {
    return '$minutes Min. • $calories kcal pro Portion';
  }

  @override
  String get noRecipes => 'Keine Rezepte gefunden';

  @override
  String get noRecipesHint =>
      'Überprüfen Sie das Rezept, den Schöpfer oder den Zutatennamen.';

  @override
  String get mealBreakfast => 'Frühstück';

  @override
  String get mealLunch => 'Mittagessen';

  @override
  String get mealDinner => 'Abendessen';

  @override
  String get mealSnack => 'Snacks';

  @override
  String get mealDessert => 'Dessert';

  @override
  String get difficultyEasy => 'leicht';

  @override
  String get difficultyMedium => 'Medium';

  @override
  String get difficultyHard => 'hart';

  @override
  String get dietNoRestrictions => 'Keine Einschränkungen';

  @override
  String get dietVegetarian => 'Vegetarier';

  @override
  String get dietVegan => 'Vegan';

  @override
  String get dietGlutenFree => 'Glutenfrei';

  @override
  String get dietKeto => 'Keton';

  @override
  String get dietHighProtein => 'Proteinreich';

  @override
  String get dietNoRestrictionsDescription =>
      'Essen Sie alle Lebensmittel, die Sie genießen';

  @override
  String get dietVegetarianDescription => 'Mahlzeiten ohne Fleisch oder Fisch';

  @override
  String get dietVeganDescription => '100% pflanzliche Mahlzeiten';

  @override
  String get dietGlutenFreeDescription => 'Mahlzeiten ohne Gluten';

  @override
  String get dietKetoDescription => 'Kohlenhydratarme Mahlzeiten';

  @override
  String get dietHighProteinDescription =>
      'Für einen aktiven Lebensstil und Muskelaufbau';

  @override
  String get planStatusActive => 'aktiv';

  @override
  String get planStatusDraft => 'Entwurf';

  @override
  String get planStatusCompleted => 'abgeschlossen';

  @override
  String get planStatusArchived => 'archiviert';

  @override
  String get authCaptchaRequired =>
      'Bestätige zuerst, dass du kein Roboter bist.';

  @override
  String get authLoginFailed => 'Anmeldung fehlgeschlagen';

  @override
  String get authWelcomeBack => 'Willkommen zurück!';

  @override
  String get authLoginPrompt => 'Melde dich mit deinem Konto an.';

  @override
  String get authEmail => 'E-Mail';

  @override
  String get authEnterEmail => 'Gib deine E-Mail-Adresse ein.';

  @override
  String get authEnterValidEmail => 'Gib eine gültige E-Mail-Adresse ein.';

  @override
  String get authPassword => 'Passwort';

  @override
  String get authEnterPassword => 'Gib dein Passwort ein.';

  @override
  String get authPasswordMinSix =>
      'Ihr Passwort muss mindestens 6 Zeichen enthalten';

  @override
  String get authSignIn => 'Anmelden';

  @override
  String get authForgotPasswordQuestion => 'Passwort vergessen?';

  @override
  String get authOr => 'oder';

  @override
  String get authContinueApple => 'Weiter mit Apple';

  @override
  String get authContinueGoogle => 'Weiter mit Google';

  @override
  String get authNoAccount => 'Noch kein Konto?';

  @override
  String get authRegister => 'Registrieren';

  @override
  String authDocumentOpenFailed(String url) {
    return 'Konnte nicht geöffnet werden: $url';
  }

  @override
  String get authAcceptTermsRequired =>
      'Akzeptieren Sie die Bedingungen, um ein Konto zu erstellen.';

  @override
  String get authRegistrationFailed => 'Registrierung fehlgeschlagen';

  @override
  String get authCreateAccount => 'Konto erstellen';

  @override
  String get authJoinPlanner => 'Plane deine Mahlzeiten mit Meal Planner.';

  @override
  String get authDisplayName => 'Name oder Benutzername';

  @override
  String get authEnterName => 'Geben Sie Ihren Namen ein';

  @override
  String get authRepeatPassword => 'Passwort wiederholen';

  @override
  String get authConfirmPassword => 'Passwort bestätigen';

  @override
  String get authPasswordsMismatch => 'Die Passwörter stimmen nicht überein.';

  @override
  String get authAcceptPrefix => 'Ich akzeptiere die ';

  @override
  String get authTerms => 'Nutzungsbedingungen';

  @override
  String get authAnd => ' und ';

  @override
  String get authPrivacyPolicy => 'Datenschutzerklärung';

  @override
  String get authAlreadyAccount => 'Hast du bereits ein Konto?';

  @override
  String get authValidEmailRequired =>
      'Geben Sie eine gültige E-Mail-Adresse ein.';

  @override
  String get authCodeSixDigits => 'Der Code muss genau 6 Ziffern enthalten.';

  @override
  String get authNewPasswordMinEight =>
      'Ihr neues Passwort muss mindestens 8 Zeichen enthalten.';

  @override
  String get authPasswordChanged =>
      'Ihr Passwort wurde geändert, melden Sie sich mit Ihrem neuen Passwort an.';

  @override
  String get authForgotPasswordTitle => 'Passwort vergessen';

  @override
  String get authResetDescription =>
      'Geben Sie Ihre E-Mail-Adresse ein und wir senden Ihnen einen Passwort-Reset-Code.';

  @override
  String get authEmailAddress => 'E-Mail-Adresse';

  @override
  String get authSendCode => 'Code senden';

  @override
  String authResetCodeSentTo(String email) {
    return 'Wenn ein Konto mit der Adresse $email existiert, haben wir ihm einen 6-stelligen Code zugesandt.';
  }

  @override
  String get authCode => 'Code';

  @override
  String get authNewPassword => 'Neues Passwort';

  @override
  String get authChangePassword => 'Passwort ändern';

  @override
  String get authUseDifferentEmail => 'Verwenden Sie eine andere E-Mail';

  @override
  String get authNewCodeSent => 'Ein neuer Code wurde verschickt.';

  @override
  String get authCodeSendFailed => 'Konnte den Code nicht senden.';

  @override
  String get authVerifyEmailTitle => 'E-Mail-Adresse bestätigen';

  @override
  String authVerificationSentTo(String email) {
    return 'Wir haben einen 6-stelligen Code an\n$email';
  }

  @override
  String get authVerify => 'Bestätigen';

  @override
  String get authResendCode => 'Code erneut senden';

  @override
  String get onboardingAllergenGluten => 'Gluten';

  @override
  String get onboardingAllergenLactose => 'Laktose';

  @override
  String get onboardingAllergenNuts => 'Nüsse';

  @override
  String get onboardingAllergenEggs => 'Eier';

  @override
  String get onboardingAllergenSoy => 'Soja';

  @override
  String get onboardingAllergenCelery => 'Sellerie';

  @override
  String get onboardingAllergenFish => 'Fisch';

  @override
  String get onboardingAllergenShellfish => 'Krebstiere';

  @override
  String get onboardingSelectStoreRequired =>
      'Wähle deinen bevorzugten Markt aus.';

  @override
  String get onboardingPreferencesSaveFailed =>
      'Deine Einstellungen konnten nicht gespeichert werden.';

  @override
  String get onboardingBack => 'Zurück';

  @override
  String get onboardingDone => 'Fertig';

  @override
  String get onboardingNext => 'Weiter';

  @override
  String get onboardingStoreTitle => 'Wo kaufst du ein?';

  @override
  String get onboardingStoreDescription =>
      'Wähle den Markt, in dem du am häufigsten einkaufst. Wir berücksichtigen sein Sortiment bei deinem Essensplan.';

  @override
  String onboardingStoresLoadFailed(String error) {
    return 'Märkte konnten nicht geladen werden:\n$error';
  }

  @override
  String get onboardingAllergensTitle => 'Hast du Allergien?';

  @override
  String get onboardingAllergensDescription =>
      'Wähle die Zutaten aus, die du nicht verträgst. Rezepte mit diesen Allergenen werden dir nicht vorgeschlagen.';

  @override
  String get onboardingDietTitle => 'Wähle deine Ernährungsform';

  @override
  String get onboardingDietDescription =>
      'Wir passen die Rezeptvorschläge an deine Ernährungsform an.';

  @override
  String get onboardingHouseholdTitle => 'Für wie viele Leute kochst du?';

  @override
  String get onboardingHouseholdDescription =>
      'Wir passen die Zutatenmengen und Portionen automatisch an die Größe deines Haushalts an.';

  @override
  String get onboardingCookingForMyself => 'Ich koche nur für mich selbst';

  @override
  String onboardingHouseholdCount(int count) {
    return 'Personen in deinem Haushalt: $count';
  }

  @override
  String get onboardingProfileTitle => 'Dein Profil und dein Ziel';

  @override
  String get onboardingProfileDescription =>
      'Möchten Sie Ihren Kalorienbedarf berechnen und jetzt Ihr Gewicht, Ihre Größe und Ihr Ziel eingeben?';

  @override
  String get onboardingOpenCalorieCalculator => 'Kalorienrechner öffnen';

  @override
  String get onboardingProfileOptional =>
      'Dieser Schritt ist optional. Tippe auf „Weiter“, um ihn zu überspringen.';

  @override
  String get onboardingPantryTitle => 'Was hast du auf Vorrat?';

  @override
  String get onboardingPantryDescription =>
      'Erfasse deine Vorräte, um Rezepte mit Zutaten zu finden, die du schon zu Hause hast.';

  @override
  String get onboardingAddPantryProducts => 'Produkte zum Vorrat hinzufügen';

  @override
  String get onboardingPantryOptional =>
      'Du kannst diesen Schritt überspringen.';

  @override
  String get onboardingPremiumOrPoints => 'PREMIUM ODER PUNKTE';

  @override
  String get onboardingAiTitle => 'Füge dein Rezept in wenigen Schritten hinzu';

  @override
  String get onboardingAiDescription =>
      'Wähle unter „Rezepte“ die Option „Rezept hinzufügen“. Die KI erkennt Zutaten und Zubereitung aus:';

  @override
  String get onboardingAiImport => 'Rezept mit KI importieren';

  @override
  String get onboardingAiPhoto => 'Ein Foto';

  @override
  String get onboardingAiPhotoDescription =>
      'Fotografieren Sie ein schriftliches Rezept oder ein fertiges Gericht.';

  @override
  String get onboardingAiText => 'Text';

  @override
  String get onboardingAiTextDescription =>
      'Fügen Sie eine Beschreibung ein oder geben Sie einfach den Namen eines Gerichts ein.';

  @override
  String get onboardingAiLink => 'Ein Link';

  @override
  String get onboardingAiLinkDescription =>
      'Fügen Sie eine Website-Adresse ein oder teilen Sie sie von einer anderen App.';

  @override
  String get onboardingAiShareExample =>
      'Wähle beispielsweise in TikTok „Teilen“ und dann Meal Planner. Anschließend kannst du die KI bitten, das Rezept anzupassen, etwa laktosefrei.';

  @override
  String get onboardingAiPointCosts =>
      'Ohne Premium kostet ein Rezeptimport 2 Punkte. Das Anpassen mit KI kostet anschließend 1 Punkt.';

  @override
  String get welcomeAllSet => 'Alles bereit!';

  @override
  String welcomePointsIntro(int points) {
    return 'Als Dank für deine Anmeldung erhältst du $points Premium-Punkte.';
  }

  @override
  String get welcomeAiPointDescription =>
      'Für 2 Punkte erstellt die KI aus einem Link oder Foto ein Rezept.';

  @override
  String get welcomeTryNow => 'Jetzt ausprobieren';

  @override
  String get welcomeScanFirstProduct => 'Erstes Produkt scannen';

  @override
  String get welcomeAddRecipeLink => 'Rezept aus einem Link hinzufügen';

  @override
  String get welcomeStart => 'Loslegen';

  @override
  String get priceCompareTitle => 'Preisvergleich';

  @override
  String get priceCompareSourcesTooltip => 'Preis- und Markenquellen';

  @override
  String get priceCompareRetry => 'Erneut versuchen';

  @override
  String get priceCompareEmpty => 'Keine Preise zum Vergleichen verfügbar.';

  @override
  String get priceCompareIntro =>
      'Wir vergleichen die Kosten der gesamten Einkaufsliste. „~ bedeutet einen geschätzten Preis. Überprüfen Sie die aktuellen Preise und Verfügbarkeit mit Ihrem gewählten Shop.';

  @override
  String priceCompareSwitchSuccess(String storeName) {
    return 'Plan auf $storeName umgestellt';
  }

  @override
  String get priceCompareSwitchError =>
      'Der Markt konnte nicht gewechselt werden.';

  @override
  String priceCompareLoadError(String error) {
    return 'Preisvergleich konnte nicht geladen werden: $error';
  }

  @override
  String get priceCompareCurrencyError =>
      'Preise in verschiedenen Währungen können nicht verglichen werden, die Daten auffrischen und es erneut versuchen.';

  @override
  String get priceCompareCheapestEstimate => 'Niedrigste Schätzung';

  @override
  String get priceCompareCheapest => 'Billig';

  @override
  String priceCompareIncomplete(int count) {
    return 'Unvollständiger Warenkorb • fehlende Preise für $count Produkte';
  }

  @override
  String priceCompareProductCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Produkte',
      one: '1 Produkt',
    );
    return '$_temp0';
  }

  @override
  String get priceCompareEstimatedPrices => 'Geschätzte Preise';

  @override
  String priceCompareSavings(String amount) {
    return 'Differenz bis $amount';
  }

  @override
  String get priceCompareExpandHint => 'Tippen Sie, um die Liste anzuzeigen';

  @override
  String priceCompareMissing(String names) {
    return 'Preise nicht verfügbar für: $names Die Summe umfasst nur Artikel mit einem Preis.';
  }

  @override
  String get priceCompareEstimate => 'Geschätzter Preis';

  @override
  String get shoppingSubstituteFailed =>
      'Das Produkt konnte nicht ersetzt werden.';

  @override
  String shoppingSubstitutePack(String quantity, String unit) {
    return '$quantity $unit Packung';
  }

  @override
  String get priceCompareUnpricedTotal => 'Nicht verfügbar insgesamt';

  @override
  String priceCompareMissingUnpriced(String names) {
    return 'Preise nicht verfügbar für: $names Der gesamte Korb kann noch nicht bepreist werden.';
  }

  @override
  String priceComparePackages(int count, String quantity, String unit) {
    return 'Zu kaufen: $count × $quantity $unit';
  }

  @override
  String priceCompareVerified(String date) {
    return 'Preis geprüft am $date';
  }

  @override
  String get priceCompareSwitchStore => 'Zu diesem Markt wechseln';

  @override
  String get priceCompareSourceTitle => 'Woher kommen die Preise?';

  @override
  String get priceCompareSourceBody =>
      'Der Vergleich nutzt Katalogpreise für deinen Markt. Preise ohne Prüfdatum sind Schätzungen. Das Zeichen „~“ kennzeichnet sie. Prüfe Preise und Verfügbarkeit im Markt. Beträge in unterschiedlichen Währungen werden weder verglichen noch umgerechnet.';

  @override
  String get priceCompareSourceClose => 'Got it';

  @override
  String get priceCompareUnitPack => 'Packung';

  @override
  String get priceCompareUnitServing => 'Portion';

  @override
  String get priceCompareUnitPiece => 'Stk.';

  @override
  String get priceCompareUnitTeaspoon => 'TL';

  @override
  String get priceCompareUnitCup => 'Tasse';

  @override
  String homeBatchCompleted(int count) {
    return 'Verarbeitet: $count Produkte.';
  }

  @override
  String get homeShopFallback => 'Ladengeschäft';

  @override
  String homeGreeting(String name) {
    return 'Hallo, $name!';
  }

  @override
  String get homeUserFallback => 'dort';

  @override
  String get homeCookingToday => 'Was kochen wir heute?';

  @override
  String get homeQuickActions => 'Schnellzugriff';

  @override
  String get homePlanLoading => 'Laden Sie Ihren Speiseplan...';

  @override
  String get homePlanLoadError => 'Konnte Ihren Speiseplan nicht laden.';

  @override
  String get homeNextPlan => 'Dein nächster Mahlzeitenplan';

  @override
  String get homeActivePlan => 'Dein aktiver Essensplan';

  @override
  String get homeDetails => 'Einzelheiten';

  @override
  String homePlanChip(int day, int month, int days) {
    return 'Plan $day/$month · $days Tage';
  }

  @override
  String get homeNutritionLoading => 'Kalorien und Makros laden...';

  @override
  String get homeNutritionError => 'Konnte nicht Kalorien und Makros laden.';

  @override
  String get homeEatenToday => 'Heute gegessen';

  @override
  String get homeProtein => 'Protein';

  @override
  String get homeFat => 'Fett';

  @override
  String get homeCarbsShort => 'Kohlenhydrate';

  @override
  String get homeRetry => 'Versuchen Sie es noch einmal';

  @override
  String get homeTipOfTheDay => 'TIPP DES TAGES';

  @override
  String get homeHydration => 'Hydratation';

  @override
  String get homeDataLoading => 'Ladedaten...';

  @override
  String get homeDataError => 'Konnte die Daten nicht laden';

  @override
  String homeWaterProgress(int amount, int goal, int percent) {
    return '$amount von $goal ml · $percent% des Ziels';
  }

  @override
  String get homeWeeklyContest => 'Wöchentliche Herausforderung';

  @override
  String get homeWeeklyContestHint =>
      'Fügen Sie diese Woche die meisten Rezepte hinzu und verdienen Sie Premiumpunkte - 3 für den 1. Platz, 2 für den 2. und 1 für den 3. Platz.';

  @override
  String homePlanStarts(String date) {
    return 'Der Plan beginnt am $date';
  }

  @override
  String homePlanDay(int day, int days) {
    return 'Tag $day von $days';
  }

  @override
  String get homeViewPlan => 'Plan ansehen';

  @override
  String get homeNoPlan => 'Kein aktiver Essensplan';

  @override
  String get homeNoPlanHint =>
      'Erstelle einen Essensplan mit passender Einkaufsliste.';

  @override
  String get homeCreatePlan => 'Neuen Essensplan erstellen';

  @override
  String get homeAiPointsTitle => 'Sie haben Punkte für einen KI-Rezeptimport';

  @override
  String get homeAiPointsHint =>
      'Fügen Sie ein Rezept aus einem Foto, Text oder Link hinzu - kein Abonnement erforderlich.';

  @override
  String get homeTryAction => 'Versuchen Sie es';

  @override
  String get homeBatchTitle => 'Mehrere Produkte scannen?';

  @override
  String get homeBatchHint =>
      'Scannen Sie mit Premium den gesamten Batch, ohne die Kamera zu schließen.';

  @override
  String get homeViewPremium => 'Premium entdecken';

  @override
  String get homeAutoWeekTitle => 'Nächste Woche selbst planen lassen';

  @override
  String get homeAutoWeekHint =>
      'Premium bereitet einen wöchentlichen Mahlzeitenplan und eine optionale Einkaufsliste vor.';

  @override
  String get homeCheckAction => 'Werfen Sie einen Blick';

  @override
  String get homeHideHint => 'Entlassung';

  @override
  String get planSelectStoreRequired =>
      'Wählen Sie einen Shop, bevor Sie Ihren Plan erstellen!';

  @override
  String get planStoreMarketError =>
      'Wählen Sie einen Shop aus, der für das Land Ihres Kontos verfügbar ist. Aktualisieren Sie die Geschäfte und versuchen Sie es erneut.';

  @override
  String get planKcalValidation =>
      'Geben Sie zwischen 800 und 6000 kcal pro Person und Tag ein.';

  @override
  String get planGenerateError =>
      'Der Essensplan konnte nicht erstellt werden.';

  @override
  String get planFreeLimitTitle => 'Kostenloses Kontolimit';

  @override
  String get planUnderstood => 'Got it';

  @override
  String get planViewPremium => 'Premium ansehen';

  @override
  String get planReadyTitle => 'Dein Essensplan ist fertig';

  @override
  String planReadyFor(int days, int people) {
    String _temp0 = intl.Intl.pluralLogic(
      people,
      locale: localeName,
      other: '$people Personen',
      one: '1 Person',
    );
    return 'Dein Plan für $days Tage und $_temp0 ist fertig.';
  }

  @override
  String get planEstimatedBudget => 'Geschätzte Mindesteinkaufskosten';

  @override
  String get planShoppingLimitReached =>
      'Ihr Plan ist fertig, aber Sie haben bereits die kostenlose Einkaufsliste dieser Woche verwendet. Erstellen Sie nächste Woche oder mit Premium eine weitere Liste.';

  @override
  String get planStandardWeeklyLimit =>
      'Standardkonto: Ein neuer Plan pro Woche';

  @override
  String get planWeeklyLimitExplanation =>
      'Ihr Limit wird am Montag zurückgesetzt. Das Löschen eines Plans setzt ihn nicht zurück. Premium ermöglicht es Ihnen, unbegrenzte Pläne zu erstellen.';

  @override
  String get planExplorePremium => 'Entdecken Sie Premium';

  @override
  String get planViewAction => 'Plan ansehen';

  @override
  String get planNewTitle => 'Neuer Essensplan';

  @override
  String get planChooseStore => 'Markt wählen';

  @override
  String get planPriceEstimateHint =>
      'Die Plankosten sind eine Schätzung. Überprüfen Sie die aktuellen Produktpreise und Verfügbarkeit mit Ihrem gewählten Shop.';

  @override
  String planDurationTitle(int days) {
    return 'Plandauer: $days Tage';
  }

  @override
  String planDays(int days) {
    return '$days Tage';
  }

  @override
  String get planOneDay => '1 Tag';

  @override
  String planHouseholdTitle(int people) {
    String _temp0 = intl.Intl.pluralLogic(
      people,
      locale: localeName,
      other: '$people Personen',
      one: '1 Person',
    );
    return 'Du kochst für $_temp0';
  }

  @override
  String get planHouseholdHint =>
      'Von 1 bis 8 Personen. Aus Ihrem Profil standardmäßig übernommen; Änderungen gelten nur für diesen Plan.';

  @override
  String get planMealTypes => 'Mahlzeittypen';

  @override
  String get planDailyCalories => 'Tägliches Kalorienziel';

  @override
  String get planCaloriesField => 'Ziel kcal / Tag / Person';

  @override
  String get planCaloriesExample => 'z. B. 2000';

  @override
  String get planCaloriesHint =>
      'Verwendet Ihr Taschenrechnerziel; standardmäßig 2000 kcal, wenn keines gespeichert ist.';

  @override
  String get planBudgetOptional => 'Höchstbudget (optional)';

  @override
  String get planBudgetField => 'Maximale Mittelausstattung';

  @override
  String get planBudgetExample => 'z. B. 150,00';

  @override
  String get planIncludePantry => 'Vorräte berücksichtigen';

  @override
  String get planPantryHint =>
      'Was du bereits vorrätig hast, steht am Ende der Liste und kostet nichts. Fehlende Mengen bleiben auf der Einkaufsliste.';

  @override
  String get planIngredientPreferences => 'Likes/Dislikes';

  @override
  String get planIngredientPreferencesHint =>
      'Premium · eine maßgeschneiderte Mahlzeit pro Tag';

  @override
  String get planGenerating => 'Erzeugung...';

  @override
  String get planGenerate => 'Plan erstellen!';

  @override
  String get planGeneratingTitle => 'Setzen Sie Ihren Speiseplan zusammen ...';

  @override
  String get planGeneratingHint =>
      'Wir verwenden Zutaten für Mahlzeiten wieder, um Ihre Einkaufskosten zu senken.';

  @override
  String get planActivated =>
      'Plan bestätigt! Ihre Einkaufsliste wurde erstellt.';

  @override
  String get planGenericError => 'Irgendetwas ging schief';

  @override
  String planSwapTitle(String recipeName) {
    return 'Ersetzen: $recipeName';
  }

  @override
  String get planSwapSearch => 'Finde einen Teller';

  @override
  String get planSwapSearchHint => 'Geben Sie einen Rezeptnamen ein';

  @override
  String get planSwapLoadError =>
      'Ich konnte keine Rezepte laden. Bitte versuchen Sie es noch einmal.';

  @override
  String get planSwapNoAlternatives =>
      'Keine anderen Gerichte in dieser Kategorie';

  @override
  String get planSwapNoSearchResults =>
      'Keine Gerichte mit diesem Namen gefunden';

  @override
  String get planSwapSuccess => 'Rezept ersetzt';

  @override
  String get planSwapError => 'Konnte das Rezept nicht ersetzen';

  @override
  String get planFinishedTitle => 'Plan abgeschlossen';

  @override
  String get planArchivePremiumRequired =>
      'Archivvorschauen sind mit Premium verfügbar.';

  @override
  String get planFinishedHint => 'Dieser Plan ist abgeschlossen.';

  @override
  String get planOpenArchive => 'Offenes Archiv';

  @override
  String get planCreateNew => 'Erstellen Sie einen neuen Plan';

  @override
  String get planViewTitle => 'Mahlzeitenplan';

  @override
  String get planNotFound =>
      'Kein Essensplan gefunden. Generieren Sie einen neuen Plan.';

  @override
  String get planStoreFallback => 'Ladengeschäft';

  @override
  String get planDeleteTitle => 'Löschplan';

  @override
  String get planDeleteQuestion =>
      'Auf einem Standardkonto wird durch das Löschen eines Plans nicht das Limit eines neuen Plans pro Woche zurückgesetzt.';

  @override
  String get planCancel => 'Stornierung';

  @override
  String get planDeleteError => 'Kann den Plan nicht löschen';

  @override
  String get planDelete => 'Löschung';

  @override
  String planDay(int day) {
    return 'Tag $day';
  }

  @override
  String get planResumeArchive => 'Archiv · Lebenslaufplan';

  @override
  String get planChangeSettings => 'Änderung der Einstellungen';

  @override
  String get planActivate => 'Plan bestätigen';

  @override
  String get planGoShopping => 'Gehen Sie zum Einkaufen';

  @override
  String get manualRecipeDiscardTitle => 'Verändern Sie Ihre Discards?';

  @override
  String get manualRecipeUnsaved =>
      'Die von Ihnen eingegebenen Rezeptdetails wurden noch nicht gespeichert.';

  @override
  String get manualRecipeStay => 'Aufenthalt';

  @override
  String get manualRecipeDiscard => 'Rückwurf';

  @override
  String get manualRecipeNutritionRequired =>
      'Dieses Produkt hat keine Nährwerte. Wählen Sie ein anderes Ergebnis oder fügen Sie das Produkt mit den Angaben auf dem Etikett in die Datenbank ein.';

  @override
  String get manualRecipeIngredientRequired =>
      'Fügen Sie mindestens eine Zutat hinzu';

  @override
  String get manualRecipeStepRequired =>
      'Zugabe von mindestens einem Herstellungsschritt';

  @override
  String get manualRecipeTitle => 'Hinzufügen eines Rezepts manuell';

  @override
  String get manualRecipeName => 'Name des Rezepts';

  @override
  String get manualRecipeNameRequired => 'Name eintragen';

  @override
  String get manualRecipeDescription => 'Kurzbeschreibung (fakultativ)';

  @override
  String get manualRecipeMealType => 'Art der Mahlzeit';

  @override
  String get manualRecipePreparationMinutes => 'Zubereitung (min.)';

  @override
  String get manualRecipeCookingMinutes => 'Kochen (min.)';

  @override
  String get manualRecipeServings => 'Portionen';

  @override
  String get manualRecipeIngredients => 'Zutaten';

  @override
  String get manualRecipeNoIngredients => 'Keine Zutaten zugesetzt';

  @override
  String get manualRecipeSteps => 'Vorbereitungsschritte';

  @override
  String get manualRecipeAddStep => 'Einen Schritt hinzufügen';

  @override
  String get manualRecipeStepHint => 'Beschreiben Sie diesen Schritt...';

  @override
  String get manualRecipeSubmitToCatalogue =>
      'Einreichen in den gemeinsamen Katalog';

  @override
  String get manualRecipePublicHint =>
      'Sobald es von einem Administrator genehmigt wurde, ist es für alle sichtbar und zählt zum wöchentlichen Wettbewerb.';

  @override
  String get manualRecipeSave => 'Speicherrezeptur';

  @override
  String get manualRecipeChooseIngredient => 'Wählen Sie eine Zutat';

  @override
  String get manualRecipeIngredientSearch =>
      'Durchsuchen Sie den Katalog und die Produktdatenbank...';

  @override
  String get manualRecipeIngredientSearchHint =>
      'Geben Sie mindestens 2 Zeichen ein, um eine Zutat zu finden.';

  @override
  String get manualRecipeIngredientNotFound =>
      'Produkt nicht gefunden. Fügen Sie es zuerst in die Produktdatenbank mit den Nährwerten auf dem Etikett hinzu.';

  @override
  String get manualRecipeLabelRequired => 'Angaben zum Etikett erforderlich';

  @override
  String get manualRecipeNutritionMissing => 'Nährwerte sind unvollständig';

  @override
  String get aiRecipePhotoLoadFailed => 'Kann das Foto nicht laden';

  @override
  String get aiRecipeChooseGallery => 'Wählen Sie aus Galerie';

  @override
  String get aiRecipeServerUnavailable =>
      'KI-Import ist noch nicht auf dem Server verfügbar.';

  @override
  String get aiRecipePremiumOrPointsTitle => 'Sie brauchen Premium oder Punkte';

  @override
  String get aiRecipeCancel => 'Stornierung';

  @override
  String get aiRecipeBuyPoints => 'Kaufpunkte';

  @override
  String get aiRecipeBackToApp => 'Zurück zur App';

  @override
  String get aiRecipeTitle => 'Rezept mit KI hinzufügen';

  @override
  String get aiRecipePhoto => 'Foto';

  @override
  String get aiRecipeLink => 'Link';

  @override
  String get aiRecipeAccepting => 'Einreichen Ihres Rezepts...';

  @override
  String get aiRecipeAcceptingHint =>
      'Sie können die App in einem Moment wieder verwenden.';

  @override
  String get aiRecipePreparing => 'Ihr Rezept wird vorbereitet';

  @override
  String get aiRecipeReady => 'Ihr Rezept ist fertig';

  @override
  String get aiRecipeRecognitionFailed => 'Konnte das Rezept nicht erkennen';

  @override
  String get aiRecipeBackgroundHint =>
      'Wir informieren Sie über das Ergebnis in der App und, wenn Push-Benachrichtigungen aktiviert sind, auch auf Ihrem Telefon.';

  @override
  String get aiRecipeFindInMine =>
      'Sie können es auch in der Registerkarte Meine Rezepte finden.';

  @override
  String get aiRecipeRetrySentence => 'Bitte versuchen Sie es noch einmal.';

  @override
  String get aiRecipeOpen => 'Offenes Rezept';

  @override
  String get aiRecipeEditOnePoint => 'Mit KI anpassen · 1 Punkt';

  @override
  String get aiRecipeAddAnother => 'Ein anderes Rezept hinzufügen';

  @override
  String get aiRecipePasteTextTitle => 'Fügen Sie Ihren Rezepttext ein';

  @override
  String get aiRecipeTextDescription =>
      'Fügen Sie ein Rezept aus Ihren Notizen, einer Nachricht oder einer Website ein - KI erkennt seine Zutaten und Schritte. Oder geben Sie einfach einen Gerichtsnamen ein (wie \"Hühnersuppe\" oder \"Lasagne\") und KI erstellt ein komplettes Rezept von Grund auf neu.';

  @override
  String get aiRecipeTextHint =>
      'z.B. \"Hühnersuppe\" oder ein vollständiges Rezept mit Zutaten und Schritten...';

  @override
  String get aiRecipeRecognise => 'Rezept erkennen';

  @override
  String get aiRecipePhotoTitle => 'Machen Sie ein Rezeptfoto';

  @override
  String get aiRecipePhotoDescription =>
      'Fotografieren Sie eine Rezeptkarte, eine Kochbuchseite oder ein fertiges Gericht - KI wird dann ein wahrscheinliches Rezept schätzen.';

  @override
  String get aiRecipeTapAddPhoto => 'Tippen Sie, um ein Foto hinzuzufügen';

  @override
  String get aiRecipePasteLinkTitle => 'Einfügen eines Rezept-Links';

  @override
  String get aiRecipeLinkDescription =>
      'Food-Blog, TikTok, Instagram — KI wird versuchen, das Rezept aus dem Seiteninhalt zu erkennen. Wenn das Rezept nur in einem Video gesprochen wird und nicht in seiner Beschreibung enthalten ist, funktioniert die Erkennung möglicherweise nicht.';

  @override
  String get aiRecipePremiumFeature => 'Premium-Feature';

  @override
  String get aiRecipePremiumDescription =>
      'Fügen Sie Ihre eigenen Rezepte mit KI aus Text oder einem Foto mit einem aktiven Premium-Abonnement hinzu - oder für 2 Premium-Punkte ohne Abonnement.';

  @override
  String get aiRecipePremiumHint =>
      'Erkunden Sie die anderen Premium-Features oder kaufen Sie ein Punktepaket.';

  @override
  String get shoppingStoresLoadFailed => 'Konnte die Läden nicht laden.';

  @override
  String get shoppingChooseStore => 'Wählen Sie einen Shop für die neue Liste';

  @override
  String get shoppingCreateFailed =>
      'Die Einkaufsliste konnte nicht erstellt werden.';

  @override
  String get shoppingShareTitle => 'Einkaufsliste teilen';

  @override
  String get shoppingShareHint =>
      'Gib den Benutzernamen der Person ein, mit der du die Liste teilen möchtest. Sie braucht ein Meal-Planner-Konto und muss deine Einladung annehmen.';

  @override
  String get shoppingUsername => 'Benutzername';

  @override
  String get shoppingSendInvite => 'Einladung senden';

  @override
  String shoppingInviteSent(String nickname) {
    return 'Einladung an $nickname gesendet';
  }

  @override
  String get shoppingMergeTitle => 'Einkaufslisten zusammenführen';

  @override
  String shoppingMergeHint(String storeName) {
    return 'Wählen Sie die $storeName Listen, die Sie mit der aktuellen Liste zusammenführen möchten.Die vorherigen Listen werden aus dem Einkaufen entfernt, aber Ihre Mahlzeitenpläne bleiben unverändert.';
  }

  @override
  String shoppingListNumber(int number) {
    return 'Liste $number';
  }

  @override
  String shoppingListDate(int day, int month, int count) {
    return '$day/$month · $count Artikel';
  }

  @override
  String get shoppingMerge => 'Zusammenführen';

  @override
  String get shoppingMergeSuccess => 'Zusammengeführte Listen';

  @override
  String get shoppingMergeFailed => 'Konnte die Listen nicht zusammenführen';

  @override
  String get shoppingChooseSubstitute => 'Wählen Sie einen Ersatz';

  @override
  String get shoppingNoSubstitutes =>
      'Keine Alternativen in diesem Shop verfügbar.';

  @override
  String get shoppingCatalogueAlternatives => 'Alternativen für Kataloge';

  @override
  String get shoppingStoreAlternatives => 'Ausgewählte Shopangebote';

  @override
  String get shoppingCatalogueAvailability =>
      'Überprüfen Sie die Verfügbarkeit des Shops - geschätzter Preis.';

  @override
  String shoppingSubstituteFor(String name) {
    return 'Für Produkt: $name';
  }

  @override
  String get shoppingPriceUnknown => 'Preis nicht verfügbar';

  @override
  String shoppingSubstituteChanged(String name) {
    return 'Ersetzt durch: $name';
  }

  @override
  String get shoppingListTitle => 'Einkaufsliste';

  @override
  String get shoppingCreateAndAdd =>
      'Erstellen einer Liste und Hinzufügen eines Produkts';

  @override
  String get shoppingAddProduct => 'Fügen Sie ein Produkt zur Liste hinzu';

  @override
  String get shoppingInvites => 'Einladungen';

  @override
  String get shoppingShare => 'Teilen';

  @override
  String get shoppingRefresh => 'Aktualisieren';

  @override
  String get shoppingDeleteList => 'Liste löschen';

  @override
  String get shoppingMergeLists => 'Listen zusammenführen';

  @override
  String get shoppingCompare => 'Vergleichen';

  @override
  String get shoppingExport => 'Exportieren';

  @override
  String get shoppingInPantry => 'Im Vorrat';

  @override
  String get shoppingOther => 'Sonstiges';

  @override
  String shoppingPantryCount(int count, String amount) {
    return '$count bereits im Vorrat · $amount';
  }

  @override
  String shoppingBoughtCount(int checked, int total) {
    return '$checked von $total gekauft';
  }

  @override
  String shoppingDeleteTitle(int number) {
    return 'Liste $number löschen?';
  }

  @override
  String shoppingDeleteHint(String storeName) {
    return 'Die Einkaufsliste für $storeName und alle Artikel werden dauerhaft gelöscht. Ihr Speiseplan bleibt unverändert. Durch das Löschen einer Liste wird das wöchentliche Limit für ein Standardkonto nicht zurückgesetzt.';
  }

  @override
  String get shoppingDelete => 'Löschen';

  @override
  String get shoppingDeleted => 'Liste gelöscht';

  @override
  String get shoppingDeleteFailed => 'Die Liste konnte nicht gelöscht werden';

  @override
  String get shoppingHaveEverything => 'Du hast alles auf der Liste.';

  @override
  String get shoppingCompleteHint =>
      'Übernimm die gekauften Produkte in deinen Vorrat. Die App kann dir dann Rezepte mit deinen vorhandenen Zutaten vorschlagen.';

  @override
  String get shoppingMovePantry => 'In den Vorrat übernehmen';

  @override
  String get shoppingCompleteWithoutPantry => 'Ohne Übernahme abschließen';

  @override
  String get shoppingCompleteFailed => 'Konnte die Liste nicht ergänzen';

  @override
  String shoppingCompleteMoved(int count) {
    return 'Einkauf abgeschlossen. $count Produkte wurden in deinen Vorrat übernommen.';
  }

  @override
  String get shoppingCompleteSuccess => 'Einkauf abgeschlossen.';

  @override
  String shoppingProgressCount(int checked, int total) {
    return '$checked von $total Posten';
  }

  @override
  String get shoppingEverythingBought => 'Alles gekauft';

  @override
  String shoppingUnknownRemaining(String amount) {
    return 'Ab ~$amount · einige Preise fehlen';
  }

  @override
  String shoppingRemaining(String amount) {
    return 'Noch zu zahlen: ~$amount';
  }

  @override
  String shoppingBasketTotal(String basket, String total) {
    return 'Im Korb: $basket von ~$total';
  }

  @override
  String get shoppingItemSaveFailed =>
      'Der Artikel konnte nicht gespeichert werden.';

  @override
  String shoppingPackageBuy(int count, String quantity, String unit) {
    return 'Kaufen: $count × $quantity $unit';
  }

  @override
  String get shoppingSubstituteBadge => 'ERSATZPRODUKT';

  @override
  String shoppingPromotionBadge(int percent) {
    return 'Angebot -$percent%';
  }

  @override
  String get shoppingEmptyTitle => 'Keine aktive Einkaufsliste';

  @override
  String get shoppingEmptyHint =>
      'Tippen Sie auf +, wählen Sie ein Geschäft und fügen Sie Ihr erstes Produkt hinzu. Sie können auch eine Liste aus einem Speiseplan erstellen.';

  @override
  String get shoppingListInvites => 'Einladungen zu Einkaufslisten';

  @override
  String shoppingEstimatedTotal(String amount) {
    return 'Geschätzte Kosten: $amount';
  }

  @override
  String get shoppingFriendReadOnly =>
      'Geteilte Einkaufsliste · schreibgeschützt';

  @override
  String get priceCompareListSwitchStore =>
      'Wechseln Sie die Liste zu diesem Shop';

  @override
  String priceCompareListSwitchSuccess(String storeName) {
    return 'Auf $storeName umgestellte Liste';
  }

  @override
  String get shoppingNoItems => 'Keine Elemente auf der Liste';

  @override
  String get productsTitle => 'Produkte';

  @override
  String get productsPriceSources => 'Preis- und Markenquellen';

  @override
  String get productsShopTab => 'Ladengeschäft';

  @override
  String get productsCatalogueTab => 'Katalog';

  @override
  String get productsMineTab => 'Meine Produkte';

  @override
  String get productsScan => 'Scan-Barcode';

  @override
  String get productsBatchScan => 'Mehrere Produkte scannen';

  @override
  String get productsBrandSearch =>
      'Suche nach einem Produkt oder einer Marke...';

  @override
  String get productsClear => 'klar';

  @override
  String get productsRetry => 'Versuchen Sie es noch einmal';

  @override
  String get productsNotFound => 'Keine Produkte gefunden.';

  @override
  String get productsShowMore => 'Mehr anzeigen';

  @override
  String get productsSearch => 'Suche nach einem Produkt...';

  @override
  String get productsNoShop => 'Kein Shop ausgewählt';

  @override
  String get productsChooseShop =>
      'Um Produkte und Preise zu durchsuchen, wählen Sie einen Shop in Ihrem Profil oder aus der Liste oben.';

  @override
  String get productsError => 'Irgendetwas ging schief';

  @override
  String get productsEmpty => 'Keine Produkte';

  @override
  String get productsChangeSearch => 'Versuchen Sie eine andere Suche.';

  @override
  String get productsUnknown => 'Unbekanntes Produkt';

  @override
  String get productsUnavailable => 'nicht verfügbar';

  @override
  String get productsDeleteTitle => 'Produkt löschen?';

  @override
  String get productsCancel => 'Stornierung';

  @override
  String get productsDelete => 'Löschung';

  @override
  String get productsAdd => 'Produkt hinzufügen';

  @override
  String get productsNothingSubmitted =>
      'Sie haben noch keine Produkte eingereicht.';

  @override
  String get productsSubmitHint =>
      'Tippen Sie unten auf \"Produkt hinzufügen\", um etwas einzureichen\nim Katalog fehlt.';

  @override
  String get productsApproved => 'Im Katalog';

  @override
  String get productsRejected => 'abgelehnt';

  @override
  String get productsPending => 'Warten auf die Genehmigung';

  @override
  String get productsEdit => 'Edit';

  @override
  String get productsEstimatedPrice => 'Geschätzter Preis';

  @override
  String get productsUnknownQuantity => '/ Menge unbekannt';

  @override
  String get diaryTitle => 'Kalorientagebuch';

  @override
  String get diaryLoadError => 'Konnte dein Tagebuch nicht laden.';

  @override
  String get diaryPreviousDay => 'Vortag';

  @override
  String get diaryNextDay => 'Nächster Tag';

  @override
  String get diaryToday => 'Zurück zu heute';

  @override
  String get diaryRemainingKcal => 'kcal verbleibend';

  @override
  String get diaryActivity => 'Hinzufügen von Aktivität';

  @override
  String get diaryActivityName => 'Was hast du getan?';

  @override
  String get diaryActivityHint => 'z. B. Laufen, Radfahren, Fitnessstudio';

  @override
  String get diaryBurnedCalories => 'Kalorien verbrannt';

  @override
  String get diaryOptionalDuration => 'Dauer (optional)';

  @override
  String get diaryActivityInvalid =>
      'Geben Sie einen Aktivitätsnamen und verbrannte Kalorien ein.';

  @override
  String get diaryRecipeNoIngredients =>
      'Dieses Rezept enthält keine Zutaten zum Bearbeiten.';

  @override
  String get diaryUpdatedNutrition => 'Eintrag Ernährung aktualisiert';

  @override
  String get diarySaveError => 'Konnte Ihre Änderungen nicht speichern';

  @override
  String get diaryEditAmount => 'Menge bearbeiten';

  @override
  String get diaryInvalidAmount => 'Angabe eines gültigen Betrags';

  @override
  String get diarySave => 'Speichern';

  @override
  String get diaryAmountUpdated => 'Menge und Ernährung aktualisiert';

  @override
  String get diaryAmountSaveError =>
      'Die Menge konnte nicht gespeichert werden.';

  @override
  String get diaryLoadingWater => 'Beladung mit Hydratation...';

  @override
  String get diaryWaterError => 'Konnte keine Hydratation laden.';

  @override
  String get diaryHydration => 'Hydratation';

  @override
  String get diaryUndoGlass => 'Ein Glas abziehen';

  @override
  String get diaryWaterQuestion => 'Wie viel hast du getrunken?';

  @override
  String get diaryWaterHint => 'z. B. 300';

  @override
  String get diaryWaterInvalid => 'Geben Sie die Anzahl der Milliliter an.';

  @override
  String get diaryGlass => 'Glas';

  @override
  String get diaryBottle => 'Flasche';

  @override
  String get diaryProtein => 'Protein';

  @override
  String get diaryCarbs => 'Kohlenhydrate';

  @override
  String get diaryFat => 'Fett';

  @override
  String get diaryMacroTargets => 'Empfohlener Split für Ihr Kalorienziel';

  @override
  String get diaryNoMeals => 'Keine Mahlzeiten für diesen Tag protokolliert.';

  @override
  String get diaryDeleteMeal => 'Mehl löschen?';

  @override
  String get diaryRemoveEntry => 'Aus dem Tagebuch entfernen';

  @override
  String get amountPositive =>
      'Geben Sie einen Betrag an, der größer als Null ist';

  @override
  String get amountClose => 'Schließen';

  @override
  String get amountQuick => 'Schnelle Auswahl';

  @override
  String get amountQuickHint =>
      'Tippen Sie auf eine Option, um sie sofort auszuwählen.';

  @override
  String get amountCustom => 'Eigene Menge';

  @override
  String get amountUnit => 'Einheit';

  @override
  String get amountQuantity => 'Menge';

  @override
  String get amountChoose => 'Menge wählen';

  @override
  String get amountApproximate => 'ca. ';

  @override
  String get measurePack => 'Packung';

  @override
  String get measureServing => 'Portion';

  @override
  String get measurePiece => 'Stück';

  @override
  String get measureTeaspoon => 'Teelöffel';

  @override
  String get measureGlass => 'Glas';

  @override
  String get measureGrams => 'Gramm';

  @override
  String get measureMillilitres => 'Milliliter';

  @override
  String get nutritionMissing => 'Ernährung nicht verfügbar';

  @override
  String get recipeNutritionEstimated =>
      'Ungefähre Werte: Einige Zutaten wurden geschätzt, sie können vom Produktetikett abweichen.';

  @override
  String get recipeNutritionPartial =>
      'Unvollständige Daten. ≥ zeigt nur die Summe der bekannten Werte, nicht die volle Ernährung der Mahlzeit.';

  @override
  String get recipeNutritionNeedsDetails =>
      'Dieses Rezept hat fehlende Ernährung. Füllen Sie die Zutatenangaben im Rezept aus oder geben Sie die Ernährung der Mahlzeit manuell in Ihr Tagebuch ein.';

  @override
  String productsProcessed(int count) {
    return 'Verarbeitet: $count Produkte.';
  }

  @override
  String productsLoadFailed(String error) {
    return 'Konnte keine Produkte laden: $error';
  }

  @override
  String productsDeleteMessage(String name) {
    return '\"$name\" wird aus Ihren Eingaben entfernt, was nicht rückgängig gemacht werden kann.';
  }

  @override
  String productsShopBrand(String brand) {
    return 'Shop-Marke: $brand';
  }

  @override
  String productsBrand(String brand) {
    return 'Produktmarke: $brand';
  }

  @override
  String productsCheckedOn(String date) {
    return 'Geprüfter Preis $date';
  }

  @override
  String diaryTodayDate(String date) {
    return 'Heute $date';
  }

  @override
  String diaryActivityCalories(String calories) {
    return '+$calories aus Aktivität';
  }

  @override
  String diaryWaterProgress(String amount, String goal) {
    return '$amount von $goal ml';
  }

  @override
  String diaryDeleteMessage(String name) {
    return '\"$name\" wird aus deinem Tagebuch entfernt.';
  }

  @override
  String diaryAmountTimes(String amount) {
    return 'Menge: $amount ×';
  }

  @override
  String diaryPortionSize(String amount, String unit) {
    return '1 Portionierung = $amount $unit';
  }

  @override
  String nutritionMacroLine(
    String kcal,
    String protein,
    String fat,
    String carbs,
  ) {
    return '$kcal kcal • P $protein g • F $fat g • C $carbs g';
  }

  @override
  String get productFormEdit => 'Bearbeitendes Produkt';

  @override
  String get productFormAdd => 'Hinzufügen Ihres Produkts';

  @override
  String get productFormVisibility =>
      'Sie können dieses Produkt sofort verwenden. Andere Benutzer werden es sehen, nachdem ein Administrator es genehmigt hat.';

  @override
  String get productFormManualAfterScan =>
      'Sie können die Details immer noch manuell eingeben. Der Barcode wurde beibehalten.';

  @override
  String get productFormCatalogFilled =>
      'Im Katalog gefunden - Details automatisch ausgefüllt.';

  @override
  String get productFormScanFilled =>
      'Produkt gefunden - Name, Marke und Ernährung ausgefüllt.';

  @override
  String get productFormEditSaved =>
      'Gespeichert. Ein Administrator wird die Änderungen erneut überprüfen.';

  @override
  String get productFormAdded =>
      'Produkt hinzugefügt. Sie können es jetzt verwenden; andere werden es sehen, sobald ein Administrator es genehmigt hat.';

  @override
  String get productFormAlreadyExists =>
      'Dieses Produkt ist bereits im Katalog, Sie brauchen es nicht noch einmal hinzuzufügen.';

  @override
  String get productFormCloseExisting =>
      'Schließen – Produkt ist bereits im Katalog';

  @override
  String get productFormName => 'Produktbezeichnung *';

  @override
  String get productFormNameHint =>
      'Geben Sie einen Namen ein oder wählen Sie einen Vorschlag';

  @override
  String get productFormNameRequired => 'Geben Sie einen Produktnamen ein';

  @override
  String get productFormBrandOptional => 'Marke (fakultativ)';

  @override
  String get productFormBrand => 'Marke';

  @override
  String get productFormPrice => 'Preis im Shop gesehen (optional)';

  @override
  String get productFormPriceError =>
      'Geben Sie einen gültigen Preis ein (über 0, bis zu 10.000).';

  @override
  String get productFormUnit => 'Einheit';

  @override
  String get productFormPack => 'Gesamtpackungsgröße';

  @override
  String get productFormPackExample => 'z. B. 150';

  @override
  String get productFormPackHelp =>
      'Geben Sie das Nettogewicht oder -volumen der gesamten Packung, nicht eine Portion, ein; ist diese nicht bekannt, lassen Sie diese leer; die Packungsoption wird nicht angezeigt.';

  @override
  String get productFormPackError =>
      'Geben Sie eine Packungsgröße über 0 und bis zu 100.000 g/ml ein oder lassen Sie sie leer.';

  @override
  String get productFormNutritionHelp =>
      'Ohne vollständige Ernährung können Sie das Produkt immer noch auf einer Einkaufsliste verwenden. Füllen Sie die Ernährung aus, bevor Sie es in Ihr Ernährungstagebuch aufnehmen.';

  @override
  String get productFormCalories => 'Kalorien';

  @override
  String get productFormProtein => 'Protein';

  @override
  String get productFormFat => 'Fett';

  @override
  String get productFormCarbs => 'Kohlenhydrate';

  @override
  String get productFormShops => 'Welche Shops verkaufen es? (optional)';

  @override
  String get productFormShopsHelp =>
      'Sie können mehrere auswählen. Es wird in diesen Geschäften erst nach der Genehmigung erscheinen.';

  @override
  String get productFormSaveChanges => 'Speichern Sie Änderungen';

  @override
  String get productFormSave => 'Produkt speichern';

  @override
  String get productFormNumberError => 'Geben Sie eine gültige Nummer ein.';

  @override
  String get productFormRequestFailed =>
      'Konnte das Produkt nicht speichern. Ihre Daten wurden aufbewahrt – bitte versuchen Sie es noch einmal.';

  @override
  String get productLabelTitle => 'Fehlende Produktdetails hinzufügen';

  @override
  String get productLabelTakePhoto => 'Machen Sie ein Foto';

  @override
  String get productLabelGallery => 'Wählen Sie aus Galerie';

  @override
  String get productLabelBothPhotos =>
      'Fügen Sie beide Fotos hinzu: die Vorderseite und das Nährwertetikett.';

  @override
  String get productLabelNameError =>
      'Überprüfen Sie den Produktnamen (2-300 Zeichen).';

  @override
  String get productLabelReading => 'Das Etikett lesen...';

  @override
  String get productLabelRead => 'Leseetikett';

  @override
  String get productLabelFront => 'Vorderseite der Packung';

  @override
  String get productLabelNutrition => 'Nährwertkennzeichnung';

  @override
  String get productLabelReview =>
      'Überprüfen Sie die Details vor dem Speichern';

  @override
  String get productLabelConfirm => 'Bestätigen und speichern';

  @override
  String get productLabelMissingNutrition =>
      'Geben Sie kcal, Protein, Fett und Kohlenhydrate pro 100 g/ml an.';

  @override
  String get productLabelReadFailed =>
      'Ich konnte das Etikett nicht lesen. Ihre Fotos wurden aufbewahrt. Bitte versuchen Sie es noch einmal.';

  @override
  String get productLabelPhotoFailed =>
      'Ich konnte das Foto nicht öffnen. Überprüfen Sie den Zugang zur Kamera oder Galerie und versuchen Sie es erneut.';

  @override
  String get productFormBrandError =>
      'Die Marke kann bis zu 200 Zeichen haben.';

  @override
  String productFormScanned(String code) {
    return 'Gescannt: $code (Änderung)';
  }

  @override
  String productFormTypicalPrice(String minimum, String maximum) {
    return 'Typische Preisspanne: $minimum–$maximum PLN';
  }

  @override
  String productFormReward(int points) {
    return 'Produkt hinzugefügt • +$points Premium-Punkt';
  }

  @override
  String productFormBalance(int points) {
    return ' • Saldo: $points';
  }

  @override
  String productFormNutrition(String unit) {
    return 'Nährwerte pro 100 $unit (optional)';
  }

  @override
  String productLabelIntro(String code) {
    return 'Details fehlen beim Barcode $code. Zwei klare Fotos können sie ausfüllen, ohne alles einzutippen.';
  }

  @override
  String productLabelPer100(String unit) {
    return 'Werte pro 100 $unit';
  }

  @override
  String productFormNumberRange(String maximum) {
    return 'Geben Sie eine Zahl von 0 bis $maximum ein.';
  }

  @override
  String get productFormChooseUnit =>
      'Wählen Sie Gramm oder Milliliter für die Packungsgröße.';

  @override
  String get productFormLookupFailed =>
      'Konnte das Produkt nicht nachschlagen. Der Barcode wurde beibehalten — Sie können die Details manuell eingeben.';

  @override
  String get detailTikTokFailed =>
      'Das TikTok-Profil konnte nicht geöffnet werden.';

  @override
  String get detailAiUpdated => 'Ihr Rezept wurde mit KI aktualisiert.';

  @override
  String get detailAiAction => 'Rezept mit KI anpassen · 1 Punkt';

  @override
  String get detailRecipeAuthor => 'Der Autor des Rezepts';

  @override
  String get detailTime => 'Uhrzeit';

  @override
  String get detailServings => 'Portionen';

  @override
  String get detailNutrition => 'Ernährung';

  @override
  String get detailPerServing => 'je Zustellung';

  @override
  String get detailChange => 'Änderung';

  @override
  String get detailLoading => 'Beladung von Zutaten und Methode...';

  @override
  String get detailRetry => 'Versuchen Sie, die Details erneut zu laden';

  @override
  String get detailTemporary => 'Vorübergehende Änderung';

  @override
  String get detailTemporaryHelp =>
      'Das ursprüngliche Rezept hat sich nicht geändert. Das Erstellen einer Einkaufsliste speichert diese Version in Meine Rezepte, so dass die Liste die Zutaten und Mengen verwendet, die hier gezeigt werden.';

  @override
  String get detailSaveVariant => 'Speichern von Variationen zu Mine';

  @override
  String get detailUndo => 'Rückgängige Änderungen';

  @override
  String get detailIngredient => 'Zutaten';

  @override
  String get detailPastaTitle => 'Tipp: Pasta ohne Waage messen';

  @override
  String get detailPastaHelp =>
      'Rechne pro Person mit etwa 80–100 g trockenen Nudeln.';

  @override
  String get detailMethod => 'Methode';

  @override
  String get detailAlsoAdd => 'Sie können auch hinzufügen';

  @override
  String get detailSeasoningHelp =>
      'fakultative Würzstoffe für extra Geschmack';

  @override
  String get detailFiber => 'Faser';

  @override
  String get variantTitle => 'Bearbeiten von Zutaten';

  @override
  String get variantHelp =>
      'Diese Änderungen sind temporär. Das ursprüngliche Rezept bleibt unverändert.';

  @override
  String get variantAlreadyAdded =>
      'Dieses Produkt steht bereits auf der Liste.';

  @override
  String get variantRemove => 'Entfernen Sie die Zutat';

  @override
  String get variantApply => 'Befristete Anwendung';

  @override
  String variantQuantityError(int maximum) {
    return 'Geben Sie einen Betrag an, der größer als Null ist, bis zu $maximum.';
  }

  @override
  String get aiEditTitle => 'Rezept mit KI anpassen';

  @override
  String get aiEditPromptLabel => 'Was möchten Sie ändern oder hinzufügen?';

  @override
  String get aiEditPromptHint =>
      'Ersetzen Sie z. B. Huhn durch Tofu und aktualisieren Sie die Methode';

  @override
  String get aiEditBuyPoints => 'Kaufpunkte';

  @override
  String get aiEditSubmit => 'Rezept für das Update · 1 Punkt';

  @override
  String get detailFavoriteError => 'konnte Ihre Favoriten nicht aktualisieren';

  @override
  String get detailRemoveFavorite => 'Aus Favoriten entfernen';

  @override
  String get detailAddFavorite => 'Zu den Favoriten hinzufügen';

  @override
  String get detailDeleteTitle => 'Rezept löschen?';

  @override
  String get detailDeletePublicHelp =>
      'Dieses Rezept ist öffentlich. Das Löschen entfernt es auch von Einkaufslisten und Plänen, die es verwenden.';

  @override
  String get detailDeleteHelp => 'Das kann nicht rückgängig gemacht werden.';

  @override
  String get detailDeleteFailed => 'Das Rezept konnte nicht gelöscht werden';

  @override
  String get detailDelete => 'Rezeptur löschen';

  @override
  String get detailPublishTitle => 'Rezept veröffentlichen?';

  @override
  String get detailPublishHelp =>
      'Ein Administrator wird Ihr Rezept überprüfen. Sobald es genehmigt ist, wird es für andere Benutzer sichtbar sein.';

  @override
  String get detailPublishSubmit => 'Veröffentlichen';

  @override
  String get detailPublishSent =>
      'Eingereichtes Rezept – wartet auf die Genehmigung durch den Administrator.';

  @override
  String get detailPublishFailed =>
      'Ich konnte das Rezept nicht veröffentlichen.';

  @override
  String get detailPublish => 'Rezept für die Veröffentlichung';

  @override
  String get detailShopping => 'Einkaufsliste für dieses Gericht';

  @override
  String get detailChooseShop => 'Wählen Sie zuerst einen Shop in Ihrem Profil';

  @override
  String get detailPhotoSent =>
      'Danke! Ihr Foto erscheint, sobald ein Administrator es genehmigt hat.';

  @override
  String get detailPhotoReplaceHelp =>
      'Dieses Rezept hat bereits ein Foto. Wenn Ihr Rezept genehmigt ist, wird es das aktuelle ersetzen.';

  @override
  String get detailPhotoSending => 'Versenden...';

  @override
  String get detailPhotoReplace => 'Schlagen Sie ein weiteres Foto vor';

  @override
  String get detailPhotoAdd => 'Foto hinzufügen';

  @override
  String get detailAiPhoto => 'Illustratives Bild, das von KI erzeugt wird';

  @override
  String detailSavedVariant(String name) {
    return 'Gespeichert zu Mine als \"$name\".';
  }

  @override
  String detailAddedBy(String name) {
    return 'Hinzugefügt von $name';
  }

  @override
  String variantAmount(String unit) {
    return 'Betrag ($unit)';
  }

  @override
  String variantBrand(String brand) {
    return 'Marke: $brand';
  }

  @override
  String aiEditIntro(String name) {
    return 'Beschreiben Sie, was in „$name geändert werden soll. Fragen Sie beispielsweise nach einer milchfreien Version oder fügen Sie eine bestimmte Zutat hinzu.';
  }

  @override
  String aiEditCost(int points) {
    return 'Ein erfolgreiches Update kostet 1 Premium-Punkt. Ihr Saldo: $points Punkte.';
  }

  @override
  String detailExistingLists(int count, String word) {
    return 'Du hast bereits $count $word. Füge die Zutaten einer vorhandenen Liste hinzu oder erstelle eine neue.';
  }

  @override
  String detailListItems(int count) {
    return '$count Posten';
  }

  @override
  String get variantSearchHint => 'Geben Sie einen Produktnamen ein';

  @override
  String get detailAddToList => 'Hinzufügen zur Einkaufsliste';

  @override
  String get detailCreateList => 'Erstellen einer neuen Liste';

  @override
  String get productsOnlineCatalogue =>
      'Online-Katalog — lokale Verfügbarkeit kann variieren';

  @override
  String get productsGenericFood =>
      'Generische Lebensmittel — Verfügbarkeit in der Werkstatt überprüfen';

  @override
  String get productsNationalAverage =>
      'Britischer Durchschnitt · kein Händlerpreis';

  @override
  String get productsPriceUnavailable => 'Preis nicht verfügbar';

  @override
  String get commentsLoadFailed => 'Kann keine Kommentare laden';

  @override
  String get commentsPhotoFailed => 'Kann das Foto nicht laden';

  @override
  String get commentsCamera => 'Machen Sie ein Foto';

  @override
  String get commentsGallery => 'Wählen Sie aus Galerie';

  @override
  String get commentsDeleteTitle => 'Löschen Sie diesen Kommentar?';

  @override
  String get commentsDeleteBody => 'Das kann nicht rückgängig gemacht werden.';

  @override
  String get commentsCancel => 'Stornierung';

  @override
  String get commentsDelete => 'Löschung';

  @override
  String get commentsDeleteFailed => 'Kann den Kommentar nicht löschen';

  @override
  String get commentsLikeFailed => 'Konnte nicht retten Sie Ihre Like';

  @override
  String get commentsJustNow => 'gerade jetzt';

  @override
  String get commentsTitle => 'Kommentare und Fotos';

  @override
  String get commentsFirst =>
      'Seien Sie der Erste, der dieses Rezept kommentiert';

  @override
  String get commentsHint =>
      'Teilen Sie einen Gedanken oder einen Kochtipp ...';

  @override
  String get commentsPhoto => 'Foto hinzufügen';

  @override
  String get commentsAdd => 'Kommentieren';

  @override
  String get commentsDeleteTooltip => 'Anmerkung streichen';

  @override
  String get commentsModerateTooltip => 'Kommentar löschen (Moderation)';

  @override
  String get reportTitle => 'Inhalt des Berichts';

  @override
  String get reportReason => 'Grund für die Meldung:';

  @override
  String get reportDetails => 'Zusätzliche Angaben (fakultativ)';

  @override
  String get reportSend => 'Bericht';

  @override
  String get reportThanks =>
      'Vielen Dank. Unser Team wird Ihren Bericht überprüfen.';

  @override
  String get reportFailed =>
      'Ich konnte Ihren Bericht nicht senden. Bitte versuchen Sie es noch einmal.';

  @override
  String get reportSpam => 'Spam oder Werbung';

  @override
  String get reportInappropriate => 'Unangemessene Inhalte';

  @override
  String get reportHarassment => 'Belästigung oder Hassrede';

  @override
  String get reportMisinformation => 'Falsche Angaben';

  @override
  String get reportOther => 'Ein weiterer Grund';

  @override
  String get blockTitle => 'Blockieren Sie diesen Benutzer?';

  @override
  String get blockAction => 'Block';

  @override
  String get blockAuthor => 'Blockautor';

  @override
  String get blockFailed => 'Den Benutzer konnte er nicht blockieren.';

  @override
  String commentsMinutes(int count) {
    return '$count min ago';
  }

  @override
  String commentsHours(int count) {
    return '$count Vorher';
  }

  @override
  String commentsDays(int count) {
    return 'Vor $count Tagen';
  }

  @override
  String commentsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Anmerkungen',
      one: '1 Kommentar',
    );
    return '$_temp0';
  }

  @override
  String blockBody(String name) {
    return 'Sie sehen keine Rezepte oder Kommentare mehr von \"$name\". Sie können sie jederzeit in Profile → Blocked Users freigeben.';
  }

  @override
  String blockDone(String name) {
    return '\"$name\" wurde blockiert.';
  }

  @override
  String get profileTitle => 'Profil';

  @override
  String get profileNone => 'Nicht eingestellt';

  @override
  String get profileShop => 'Ladengeschäft';

  @override
  String get profileUser => 'Nutzer';

  @override
  String get profileExpiryToday => 'Ihr Abonnement läuft heute ab';

  @override
  String get profileHealth => 'Gesundheit und Ziele';

  @override
  String get profileCommunity => 'Gemeinschaft';

  @override
  String get profileFriends => 'Freunde';

  @override
  String get profileFriendsHint => 'Einladungen, Rezepte und Einkaufslisten';

  @override
  String get profileSubscription => 'Abonnement';

  @override
  String get profileUpgrade => 'Premium entdecken';

  @override
  String get profileUpgradeHint =>
      'Automatische Wochenpläne, mehrere Barcodes in Folge scannen und unbegrenzt Einkaufslisten erstellen';

  @override
  String get profileCompare => 'Vergleich der Pläne';

  @override
  String get profilePreferences => 'Präferenzen';

  @override
  String get profilePreferredShop => 'Bevorzugter Shop';

  @override
  String get profileDiet => 'Ernährungsform';

  @override
  String get profileHousehold => 'Menschen in Ihrem Haushalt';

  @override
  String get profileLikes => 'Vorlieben und Abneigungen';

  @override
  String get profileArchive => 'Planarchiv';

  @override
  String get profileArchiveHint => 'Premium · Ansicht und Wiederverwendung';

  @override
  String get profileDarkMode => 'Dunkelmodus';

  @override
  String get profilePrivacy => 'Konto und Privatsphäre';

  @override
  String get profileAddUsername => 'Fügen Sie einen Benutzernamen hinzu';

  @override
  String get profileLogout => 'Abmelden';

  @override
  String get profileBlocked => 'Blockierte Benutzer';

  @override
  String get profileDelete => 'Konto löschen';

  @override
  String get profileAdmin => 'Administratorgremium';

  @override
  String get profileChooseShop => 'Wählen Sie einen Shop';

  @override
  String get profileHealthTitle => 'Gewicht, Größe und Kalorienziel';

  @override
  String get profileHealthHint =>
      'Geben Sie Ihre Daten ein, um den BMI und den Kalorienbedarf zu berechnen';

  @override
  String get profileBmiLow => 'Untergewicht';

  @override
  String get profileBmiNormal => 'Gesundes Gewicht';

  @override
  String get profileBmiHigh => 'Übergewicht';

  @override
  String get profileBmiObese => 'Adipositas';

  @override
  String get profileMeasurementDate => 'Messdatum';

  @override
  String get profileSelect => 'Wählen';

  @override
  String get profileWeightInvalid =>
      'Geben Sie ein gültiges Gewicht zwischen 0,1 und 400 kg ein.';

  @override
  String get profileWeightTitle => 'Gewichtskontrolle';

  @override
  String get profileWeightHint =>
      'Speichern Sie eine Messung für den ausgewählten Tag. Speichern aktualisiert erneut den Eintrag für dieses Datum.';

  @override
  String get profileWeightOptional => 'Gewicht (optional)';

  @override
  String get profileSaveMeasurement => 'Messung speichern';

  @override
  String get profileStatistics => 'Statistik';

  @override
  String get profilePhotoFailed => 'Konnte das Foto nicht retten';

  @override
  String get profileAvatar => 'Wählen Sie einen Avatar';

  @override
  String get profileGallery => 'Aus der Galerie';

  @override
  String get profileAvatarOr => 'oder wählen Sie ein Icon';

  @override
  String get profileFemale => 'Frau';

  @override
  String get profileMale => 'Mann';

  @override
  String get profileNicknameTitle => 'Spitzname ändern';

  @override
  String get profileNickname => 'Spitzname';

  @override
  String get profileSave => 'Speichern';

  @override
  String get profileNicknameSaved => 'Nickname aktualisiert.';

  @override
  String get profileNicknameFailed =>
      'Deinen Spitznamen konnte ich nicht ändern.';

  @override
  String get profileTikTokFailed =>
      'Das TikTok-Profil konnte nicht geöffnet werden.';

  @override
  String get profileTikTokAdd => 'Hinzufügen von TikTok';

  @override
  String get profileTikTokEdit => 'TikTok-Profil bearbeiten';

  @override
  String get profileTikTokUsername => 'TikTok Benutzername';

  @override
  String get profileTikTokPlaceholder => '@yourname';

  @override
  String get profileTikTokHelp =>
      'Sie können auch den vollständigen Profillink einfügen.';

  @override
  String get profileTikTokInvalid =>
      'Verwende 2–24 Zeichen: Buchstaben, Zahlen, Punkte oder Unterstriche.';

  @override
  String get profileTikTokRemoved => 'TikTok-Benutzername entfernt.';

  @override
  String get profileTikTokSaved => 'TikTok Profillink hinzugefügt.';

  @override
  String get profileTikTokSaveFailed =>
      'Konnte Ihren TikTok-Benutzernamen nicht speichern.';

  @override
  String get profileDeleteTitle => 'Löschen Sie Ihr Konto dauerhaft?';

  @override
  String get profileNext => 'Weiter';

  @override
  String get profileDeleteFinal => 'Endgültige Bestätigung';

  @override
  String get profileDeleteFinalBody =>
      'Sind Sie sicher? Das kann nicht rückgängig gemacht werden.';

  @override
  String get profileDeleteFailed => 'Ich konnte dein Konto nicht löschen.';

  @override
  String get profileDietAny => 'Keine Einschränkungen';

  @override
  String get profileDietVegetarian => 'Vegetarier';

  @override
  String get profileDietVegan => 'Vegan';

  @override
  String get profileDietKeto => 'Ketogen';

  @override
  String get profileDietLactose => 'Laktosefrei';

  @override
  String get documentContact => 'Kontakt';

  @override
  String get documentEmailBody => 'E-Mail an uns unter:';

  @override
  String get documentCopy => 'Kopieradresse';

  @override
  String get documentClose => 'Schließen';

  @override
  String get documentOpenFailed =>
      'Ich konnte das Dokument nicht öffnen. Bitte versuchen Sie es noch einmal.';

  @override
  String get documentTerms => 'Nutzungsbedingungen (EULA)';

  @override
  String get documentPrivacy => 'Datenschutzpolitik';

  @override
  String get documentDeletion => 'Kontolöschungsinformationen';

  @override
  String get documentHelp => 'Hilfe';

  @override
  String get compareWeekly => 'Automatischer Wochenplan und Liste';

  @override
  String get compareArchive =>
      'Archivierung und Wiederverwendung fertiger Pläne';

  @override
  String get compareLikes =>
      'Likes / Dislikes: eine maßgeschneiderte Mahlzeit pro Tag';

  @override
  String get compareAi => 'KI Rezeptimport (Foto, Text, Link)';

  @override
  String get compareBatch => 'Batch-Scannen, ohne die Kamera zu schließen';

  @override
  String get comparePublish => 'Rezepte im gemeinsamen Katalog veröffentlichen';

  @override
  String get compareTikTok => 'TikTok Link zu Ihren Rezepten';

  @override
  String get compareLists => 'Einkaufslisten aus ausgewählten Rezepten';

  @override
  String get compareUnlimited => 'Unbegrenzt';

  @override
  String get compareOneWeek => '1 / Woche';

  @override
  String get compareGenerate => 'Generierung von Mahlzeiten';

  @override
  String get compareJournal => 'Kalorien- und Makrotagebuch';

  @override
  String get compareCalculator => 'Kalorienbedarf Rechner';

  @override
  String get compareCatalogue => 'Rezept und Produktkatalog';

  @override
  String get comparePrices => 'Produktpreisvergleich';

  @override
  String profileExpiryDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Abo noch $days Tage aktiv',
      one: 'Abo noch 1 Tag aktiv',
    );
    return '$_temp0';
  }

  @override
  String profilePeople(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Menschen',
      one: '1 Person',
    );
    return '$_temp0';
  }

  @override
  String profileWeightSaved(String weight) {
    return '$weight kg gespeichert.';
  }

  @override
  String profileDate(String date) {
    return 'Datum: $date';
  }

  @override
  String get profileDeleteBody =>
      'Dies kann nicht rückgängig gemacht werden. Sie verlieren alle gespeicherten Speisepläne, Einkaufslisten, Speisekammerartikel, Lieblingsrezepte, Kommentare und Premium-Punkte. Wenn Sie ein aktives Abonnement haben, kündigen Sie es separat im App Store / Google Play-Einstellungen - das Löschen Ihres Kontos storniert das Abonnement nicht.';

  @override
  String premiumTrialBadge(int days) {
    return '$days TAGE KOSTENLOS*';
  }

  @override
  String get premiumCheckTrial => 'Probeabo prüfen';

  @override
  String premiumTrialEligibilityFootnote(String store) {
    return '* Für berechtigte Konten. Vor der Bestätigung zeigt dir $store die Verfügbarkeit, den Preis nach der Probezeit und den Verlängerungstermin.';
  }

  @override
  String get premiumNotNow => 'Nicht jetzt';

  @override
  String get premiumPurchaseError => 'Es gab ein Problem mit Ihrem Kauf.';

  @override
  String get premiumAppleOfferOpenFailed =>
      'Das App Store Angebot konnte nicht geöffnet werden.';

  @override
  String premiumPaymentsUnavailable(String store) {
    return 'Käufe sind auf diesem Gerät nicht verfügbar. Prüfe dein Konto bei $store.';
  }

  @override
  String get premiumSubscriptionPricesUnavailable =>
      'Abopreise konnten nicht geladen werden.';

  @override
  String premiumPurchaseFailed(String error) {
    return 'Kauf fehlgeschlagen: $error';
  }

  @override
  String get premiumUnknownError => 'Unbekannter Fehler';

  @override
  String get premiumActive => 'Premium ist aktiv.';

  @override
  String get premiumActivated => 'Premium ist jetzt aktiv. Vielen Dank.';

  @override
  String premiumPurchaseVerificationFailed(String error) {
    return 'Ihr Kauf konnte nicht verifiziert werden: $error';
  }

  @override
  String premiumPointsAdded(int balance) {
    return 'Du hast jetzt $balance Punkte.';
  }

  @override
  String premiumPurchaseStartFailed(String error) {
    return 'Ihr Kauf konnte nicht gestartet werden: $error';
  }

  @override
  String get premiumRestoreEmpty =>
      'Es gibt keine früheren Käufe zum Wiederherstellen.';

  @override
  String premiumQuickActionPoints(String subtitle, int points) {
    String _temp0 = intl.Intl.pluralLogic(
      points,
      locale: localeName,
      other: '$points Punkte',
      one: '$points Punkt',
    );
    return '$subtitle Oder verwenden $_temp0 ohne Abonnement.';
  }

  @override
  String get premiumAutomaticWeekTitle => 'Automatischer Wochenplan';

  @override
  String get premiumAutomaticWeekDescription =>
      'Holen Sie sich einen Speiseplan und eine optionale Einkaufsliste an Ihrem gewählten Tag.';

  @override
  String get premiumBatchTitle => 'Mehrere Barcodes in Folge scannen';

  @override
  String get premiumBatchDescription =>
      'Scanne mehrere Produkte nacheinander und speichere sie gemeinsam an den gewählten Zielen.';

  @override
  String get premiumUnlimitedPlansTitle => 'Unbegrenzte Speisepläne';

  @override
  String get premiumUnlimitedPlansDescription =>
      'Erstellen Sie so viele Mahlzeit Pläne, wie Sie brauchen, ohne wöchentliches Limit.';

  @override
  String get premiumAiRecipesTitle => 'Rezeptimport mit KI';

  @override
  String get premiumAiRecipesDescription =>
      'Importieren Sie Rezepte aus Links, Texten oder Fotos, ohne Punkte auszugeben. KI-Bearbeitung kostet 1 Punkt, auch mit Premium.';

  @override
  String get premiumFullDiaryTitle => 'Vollständiger Tagebuchverlauf';

  @override
  String get premiumFullDiaryDescription =>
      'Sieh deine Einträge auch über die letzten 30 Tage hinaus.';

  @override
  String get premiumUnlimitedListsTitle => 'Unbegrenzte Einkaufslisten';

  @override
  String get premiumUnlimitedListsDescription =>
      'Erstellen Sie eine neue Einkaufsliste, wann immer Sie eine benötigen.';

  @override
  String get premiumProductName => 'Meal Planner Premium';

  @override
  String get premiumHeroTitle => 'Deine Woche auf einen Blick';

  @override
  String get premiumHeroDescription =>
      'Planen Sie Ihre Mahlzeiten, machen Sie den Einkauf und halten Sie Ihre Lieblingsrezepte griffbereit.';

  @override
  String get premiumAutomaticWeekSubtitle =>
      'Ihr Wochenplan und optionale Einkaufsliste, bereit jede Woche';

  @override
  String get premiumAutomaticWeekRequired =>
      'Die automatische Wochenplanung ist mit Premium verfügbar.';

  @override
  String get premiumAiActionTitle => 'Rezept mit KI hinzufügen';

  @override
  String get premiumAiActionSubtitle =>
      'Link, Foto oder Text. Importe verwenden keine Punkte mit Premium';

  @override
  String get premiumBatchActionTitle =>
      'Scannen Sie mehrere Produkte auf einmal';

  @override
  String get premiumBatchActionSubtitle =>
      'Ziele auswählen und alle Produkte gemeinsam speichern';

  @override
  String premiumBatchCompleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count verarbeitete Produkte.',
      one: '$count verarbeitetes Produkt.',
    );
    return '$_temp0';
  }

  @override
  String get premiumPublishActionTitle => 'Veröffentlichen Sie Ihre Rezepte';

  @override
  String get premiumPublishActionSubtitle =>
      'Teilen Sie Ihre Rezepte mit der Community';

  @override
  String get premiumRecipeListsTitle => 'Einkaufslisten aus Rezepten';

  @override
  String get premiumRecipeListsSubtitle => 'Unbegrenzt (Standard: 1 pro Woche)';

  @override
  String get premiumCookFromPantryTitle => 'Kochen Sie mit dem, was Sie haben';

  @override
  String get premiumCookFromPantrySubtitle =>
      'Wählen Sie die Zutaten, die Sie haben und finden Sie passende Rezepte';

  @override
  String get premiumPantryActionTitle => 'Dein Vorrat';

  @override
  String get premiumPantryActionSubtitle => 'Behalte deine Vorräte im Blick.';

  @override
  String premiumSubscriptionLegal(String store) {
    return 'Abonnements verlängern sich automatisch, wenn sie nicht mindestens 24 Stunden vor Ablauf des aktuellen Zeitraums storniert werden. Die Zahlung wird Ihrem $store-Konto in Rechnung gestellt, wenn Sie Ihren Kauf bestätigen. Verwalten oder stornieren Sie Ihr Abonnement in Ihren Shop-Kontoeinstellungen.';
  }

  @override
  String get premiumAlreadyActive => 'Ihr Premium-Abonnement ist aktiv';

  @override
  String get premiumExpiresToday => 'Läuft heute ab';

  @override
  String premiumDaysRemaining(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Noch $days Tage aktiv',
      one: 'Noch $days Tag aktiv',
    );
    return '$_temp0';
  }

  @override
  String get premiumRetry => 'Versuchen Sie es noch einmal';

  @override
  String get premiumWeekly => 'Wochenweise';

  @override
  String get premiumMonthly => 'Monatlich';

  @override
  String premiumMonthlyTrial(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days Tage kostenlos',
      one: '$days Tag kostenlos',
    );
    return '$_temp0';
  }

  @override
  String get premiumYearly => 'Jährlich';

  @override
  String premiumYearlySaving(int percent) {
    return 'Sparen Sie $percent%';
  }

  @override
  String get premiumTrialDisclosureApple =>
      'Verlängert sich automatisch jeden Monat. In deinen Apple-Kontoeinstellungen kannst du kündigen.';

  @override
  String get premiumTrialDisclosureGoogle =>
      'Verlängert sich automatisch jeden Monat. Du kannst das Abo in Google Play kündigen.';

  @override
  String get premiumRestorePurchases => 'Käufe wiederherstellen';

  @override
  String get premiumPointsTitle => 'Premium-Punkte';

  @override
  String premiumPointsBalance(int balance) {
    return 'Ihr Saldo: $balance';
  }

  @override
  String get premiumPointsExplanation =>
      'Importieren Sie ein Rezept aus einem Foto, Text oder Link für 2 Punkte. Bearbeiten Sie ein Rezept mit KI für 1 Punkt. Ein Abonnement ist optional.';

  @override
  String get premiumPointsPricesUnavailable =>
      'Punktepaketpreise konnten nicht geladen werden.';

  @override
  String premiumPointsAmount(int points) {
    String _temp0 = intl.Intl.pluralLogic(
      points,
      locale: localeName,
      other: '$points Punkte',
      one: '$points Punkt',
    );
    return '$_temp0';
  }

  @override
  String premiumPromotionalPrice(String price) {
    return 'Angebotspreis: $price';
  }

  @override
  String premiumPointsUses(int imports, int edits) {
    String _temp0 = intl.Intl.pluralLogic(
      imports,
      locale: localeName,
      other: '$imports Rezeptimporte',
      one: '$imports Rezeptimport',
    );
    String _temp1 = intl.Intl.pluralLogic(
      edits,
      locale: localeName,
      other: '$edits Rezeptanpassungen',
      one: '$edits Rezeptanpassung',
    );
    return '$_temp0\noder $_temp1';
  }

  @override
  String get premiumBuyInApple => 'Kaufen Sie im App Store';

  @override
  String get premiumBuyInGoogle => 'Kaufen Sie in Google Play';

  @override
  String premiumPriceAfterTrial(String price) {
    return 'Danach $price pro Monat';
  }

  @override
  String premiumPriceBeforeCode(String price) {
    return 'Preis vor Angebotscode: $price';
  }

  @override
  String get premiumTryFree => 'Kostenlos testen';

  @override
  String get premiumBuy => 'Premium buchen';

  @override
  String get premiumRedeemCode => 'Angebotscode einlösen';

  @override
  String get premiumBuyDiscount => 'Kaufen zum Angebotspreis';

  @override
  String get premiumContextRecipeEyebrow => 'Premium für Rezepte';

  @override
  String get premiumContextRecipeTitle =>
      'Verwandeln Sie eine Idee in ein Rezept';

  @override
  String get premiumContextRecipeDescription =>
      'Speichern Sie ein Rezept aus einem Link, Foto oder einer Beschreibung, ohne es einzugeben. Premium-Importe verwenden keine Punkte.';

  @override
  String get premiumContextRecipeBenefitImport =>
      'Ein Rezept aus einem Link, Foto oder einer Beschreibung';

  @override
  String get premiumContextRecipeBenefitSteps =>
      'Zutaten und Schritte für Sie zusammengestellt';

  @override
  String get premiumContextRecipeBenefitEdit =>
      'KI-Bearbeitung: 1 Punkt, auch mit Premium';

  @override
  String get premiumContextMealPlanEyebrow => 'Premium für die Planung';

  @override
  String get premiumContextMealPlanTitle =>
      'Ihre nächste Woche, automatisch geplant';

  @override
  String get premiumContextMealPlanDescription =>
      'Zeitplanplanung für den von Ihnen gewählten Tag. Erstellen Sie weitere Pläne und Einkaufslisten, wann immer Sie sie benötigen.';

  @override
  String get premiumContextMealPlanBenefitUnlimited =>
      'Unbegrenzte Speisepläne';

  @override
  String get premiumContextMealPlanBenefitWeekly =>
      'Ein automatischer Plan für nächste Woche';

  @override
  String get premiumContextMealPlanBenefitSwap =>
      'Berücksichtigte Präferenzen für Zutaten';

  @override
  String get premiumContextBarcodeEyebrow => 'Premium zum Scannen';

  @override
  String get premiumContextBarcodeTitle =>
      'Scannen Sie Ihre Lebensmittel in einem Zug';

  @override
  String get premiumContextBarcodeDescription =>
      'Scanne mehrere Produkte nacheinander und speichere sie gemeinsam an den gewählten Zielen.';

  @override
  String get premiumContextBarcodeBenefitBatch => 'Batch-Barcode-Scanning';

  @override
  String get premiumContextBarcodeBenefitNutrition =>
      'Kalorien und Makros für Matched Products';

  @override
  String get premiumContextBarcodeBenefitDestinations =>
      'Fügen Sie den Batch zu Ihrem Tagebuch, Pantry oder Katalog hinzu';

  @override
  String get premiumContextShoppingEyebrow => 'Premium zum Einkaufen';

  @override
  String get premiumContextShoppingTitle =>
      'Erstellen Sie so viele Einkaufslisten, wie Sie benötigen';

  @override
  String get premiumContextShoppingDescription =>
      'Machen Sie eine separate Liste für jeden Plan oder jedes Rezept. Merge-Listen für den gleichen Shop.';

  @override
  String get premiumContextShoppingBenefitLists => 'Unbegrenzte Einkaufslisten';

  @override
  String get premiumContextShoppingBenefitMerge =>
      'Merge-Listen für denselben Shop';

  @override
  String get premiumContextShoppingBenefitPantry =>
      'Essen aus Ihrer Speisekammer fügt keine Einkaufskosten hinzu';

  @override
  String get premiumContextPantryEyebrow => 'Premium für Ihre Pantry';

  @override
  String get premiumContextPantryTitle =>
      'Verwenden Sie das Essen, das Sie bereits haben';

  @override
  String get premiumContextPantryDescription =>
      'Finden Sie Rezepte, die Ihre Speisekammer Zutaten verwenden und kaufen Sie nur, was Sie brauchen.';

  @override
  String get premiumContextPantryBenefitMatch =>
      'Rezepte, die Ihre Zutaten verwenden';

  @override
  String get premiumContextPantryBenefitMissing => 'Weniger fehlende Zutaten';

  @override
  String get premiumContextPantryBenefitWaste => 'Weniger Lebensmittelabfälle';

  @override
  String get premiumContextJournalEyebrow => 'Premium für Ihr Tagebuch';

  @override
  String get premiumContextJournalTitle =>
      'Schauen Sie zurück durch Ihr komplettes Ernährungstagebuch';

  @override
  String get premiumContextJournalDescription =>
      'Durchsuchen sie einträge, die älter als 30 tage sind, und sehen sie alle ihre wöchentlichen einsichten.';

  @override
  String get premiumContextJournalBenefitHistory =>
      'Ihre vollständige Tagebuchgeschichte';

  @override
  String get premiumContextJournalBenefitCharts => 'Einträge älter als 30 Tage';

  @override
  String get premiumContextJournalBenefitWeight =>
      'Alle wöchentlichen Einblicke';

  @override
  String get premiumPackageSemantics => 'Paket';

  @override
  String premiumDiscountSemantics(int percent) {
    return '$percent % Abschlag';
  }

  @override
  String premiumDiscountRibbon(int percent) {
    return '$percent % SPAREN';
  }

  @override
  String get premiumSeePlans => 'Siehe Premiumpläne';

  @override
  String get archiveTitle => 'Planarchiv';

  @override
  String get archiveChooseStart => 'Wann sollte der Plan beginnen?';

  @override
  String get archiveChooseDate => 'Datum wählen';

  @override
  String get archiveResumeTitle => 'Lebenslaufplan';

  @override
  String archiveResumeBody(int days, String date) {
    return 'Die gleichen Mahlzeiten für $days Tage ab $date. Der ursprüngliche Plan bleibt im Archiv. Wir werden eine neue Einkaufsliste erstellen. Keine KI-Generation oder Premium-Punkte erforderlich.';
  }

  @override
  String get archiveResume => 'Lebenslauf';

  @override
  String get archiveResumed => 'Ihr Plan wurde wieder aufgenommen.';

  @override
  String get archiveResumeFailed => 'Konnte den Plan nicht wieder aufnehmen.';

  @override
  String archiveDuration(int days) {
    return '$days Tage';
  }

  @override
  String get archivePremiumHint =>
      'Mit Premium bleiben abgeschlossene Pläne in Ihrem Archiv. Sie können sie ohne KI-Generierung anzeigen und fortsetzen.';

  @override
  String get archiveSeePremium => 'Siehe Premium';

  @override
  String get archiveCompleted => 'Abgeschlossene Pläne';

  @override
  String get archiveHint =>
      'Verwenden Sie die gleichen Mahlzeiten wieder von einem neuen Datum. Keine KI-Generation oder Premium-Punkte erforderlich.';

  @override
  String get archiveEmpty =>
      'Noch keine abgeschlossenen Pläne. Ihr aktiver Plan wird hier nach seinem letzten Tag erscheinen.';

  @override
  String archivePlanTitle(int days) {
    return '$days-Tage-Plan';
  }

  @override
  String get archivePreview => 'Vorschau';

  @override
  String get archiveResuming => 'Wiederaufnahme...';

  @override
  String get automationTitle => 'Automatische Woche';

  @override
  String get automationHeading => 'Ihr Plan, bereit, bevor die Woche beginnt';

  @override
  String get automationHint =>
      'Jede Woche erstellen wir einen 7-Tage-Plan, der auf Ihrem Ziel, Ihren Vorlieben und Ihrem bevorzugten Shop basiert.';

  @override
  String get automationGenerate => 'Automatisch generieren';

  @override
  String get automationPremiumHint => 'Nur solange Premium aktiv ist';

  @override
  String get automationWeekday => 'Tag der Woche';

  @override
  String get automationMonday => 'Montag';

  @override
  String get automationTuesday => 'Dienstag';

  @override
  String get automationWednesday => 'Mittwoch';

  @override
  String get automationThursday => 'Donnerstag';

  @override
  String get automationFriday => 'Freitag';

  @override
  String get automationSaturday => 'Samstag';

  @override
  String get automationSunday => 'Sonntag';

  @override
  String get automationHour => 'Uhrzeit';

  @override
  String get automationCreateList => 'Erstellen Sie auch eine Einkaufsliste';

  @override
  String get automationLastPlan => 'Letzter erstellter Plan';

  @override
  String get automationSave => 'Speichereinstellungen';

  @override
  String get automationRun => 'Jetzt generieren';

  @override
  String get automationEnabled => 'Die automatische Woche läuft.';

  @override
  String get automationDisabled => 'Die automatische Woche ist aus.';

  @override
  String get automationReady => 'Dein Plan ist fertig. Finde ihn zu Hause.';

  @override
  String get errorSignIn => 'Sie müssen sich anmelden, um dies zu tun.';

  @override
  String get errorTooManyRequests =>
      'Zu viele Versuche. Bitte versuchen Sie es gleich noch einmal.';

  @override
  String get errorUnavailable =>
      'Der Service ist vorübergehend nicht verfügbar. Bitte versuchen Sie es gleich wieder.';

  @override
  String get errorServerTimeout =>
      'Der Server hat nicht rechtzeitig geantwortet. Bitte versuchen Sie es gleich noch einmal.';

  @override
  String get errorServer =>
      'Auf unserer Seite ist etwas schief gelaufen. Bitte versuchen Sie es gleich noch einmal.';

  @override
  String get errorOperationTimeout =>
      'Das hat zu lange gedauert. Bitte versuchen Sie es gleich wieder.';

  @override
  String get errorConnection =>
      'Konnte keine Verbindung zum Server herstellen. Überprüfen Sie Ihre Internetverbindung und versuchen Sie es erneut.';

  @override
  String get errorFormat =>
      'Konnte die Daten nicht lesen, den Bildschirm auffrischen und es noch einmal versuchen.';

  @override
  String get automationRetry => 'Wiederholen';

  @override
  String get ingredientPreferencesTitle => 'Präferenzen für Zutaten';

  @override
  String get ingredientPreferencesLimit =>
      'Sie können bis zu 50 Zutaten in jeder Gruppe auswählen.';

  @override
  String get ingredientPreferencesSavedMessage =>
      'Inhaltsstoffpräferenzen gespeichert.';

  @override
  String get ingredientPreferencesUnsavedTitle =>
      'Nicht gespeicherte Präferenzen';

  @override
  String get ingredientPreferencesUnsavedBody =>
      'Sie haben unerrettete Änderungen. Gehen Sie zurück, ohne zu sparen?';

  @override
  String get ingredientPreferencesStay => 'Aufenthalt';

  @override
  String get ingredientPreferencesDiscard => 'Gehen Sie zurück ohne zu sparen';

  @override
  String get ingredientPreferencesEmpty => 'Noch keine Zutaten ausgewählt.';

  @override
  String ingredientPreferencesRemove(String name) {
    return 'Entfernen $name';
  }

  @override
  String get ingredientPreferencesRetry => 'Versuchen Sie es noch einmal';

  @override
  String get ingredientPreferencesHint =>
      'Wir werden Ihre Vorlieben in einer Mahlzeit am Tag verwenden, wenn ein passendes Rezept verfügbar ist. Allergien und Diät haben Vorrang.';

  @override
  String get ingredientPreferencesLike => 'wie';

  @override
  String get ingredientPreferencesDislike => 'Abneigung';

  @override
  String get ingredientPreferencesAddLike => 'Zu Favoriten hinzufügen';

  @override
  String get ingredientPreferencesAddDislike =>
      'Zu unerwünschten Zutaten hinzufügen';

  @override
  String get ingredientPreferencesSearch => 'Suchen Sie Zutaten';

  @override
  String get ingredientPreferencesMoveHint =>
      'Die Auswahl einer Zutat in der anderen Gruppe bewegt sie dorthin.';

  @override
  String get ingredientPreferencesRetrySearch => 'Wieder suchen';

  @override
  String get ingredientPreferencesNoResults =>
      'Keine Zutaten passen zu diesem Namen.';

  @override
  String ingredientPreferencesSaveError(String error) {
    return 'Nicht gespeichert: $error';
  }

  @override
  String get ingredientPreferencesSaving => 'Rettung...';

  @override
  String get ingredientPreferencesSave => 'Speichern Sie Präferenzen';

  @override
  String get ingredientPreferencesSaved => 'Gespeicherte Präferenzen';

  @override
  String get ingredientPreferencesLocked =>
      'Wählen Sie Zutaten, die Sie mögen und nicht mögen. Premium verwendet sie in einer Mahlzeit am Tag, wenn ein passendes Rezept verfügbar ist.';

  @override
  String get ingredientPreferencesPremium => 'Premium ansehen';

  @override
  String get blockedUsersTitle => 'Blockierte Benutzer';

  @override
  String get blockedUsersEmpty => 'Sie haben noch niemanden blockiert.';

  @override
  String get blockedUsersUnknown => 'Nutzer';

  @override
  String get blockedUsersUnblock => 'Entsperrung';

  @override
  String blockedUsersUnblocked(String name) {
    return 'Entsperrt \"$name\". Sie können ihren Inhalt wieder sehen.';
  }

  @override
  String get calculatorTitle => 'Kalorienrechner';

  @override
  String get calculatorIntro =>
      'Geben Sie Ihre Daten ein, um Ihren täglichen Kalorienbedarf zu berechnen (die Mifflin-St Jeor-Formel, die auch vom polnischen NFZ-Kalorienrechner verwendet wird).';

  @override
  String get calculatorWeight => 'Gewicht (kg)';

  @override
  String get calculatorHeight => 'Höhe (cm)';

  @override
  String get calculatorAge => 'Alter (Jahre)';

  @override
  String get calculatorSex => 'Sex';

  @override
  String get calculatorFemale => 'Weiblich';

  @override
  String get calculatorMale => 'männlich';

  @override
  String get calculatorActivity => 'Körperliche Aktivität';

  @override
  String get calculatorSedentary => 'Sitzend';

  @override
  String get calculatorSedentaryHint => 'Wenig oder keine Übung';

  @override
  String get calculatorLight => 'Leicht aktiv';

  @override
  String get calculatorLightHint => 'Übung 1-3 Tage pro Woche';

  @override
  String get calculatorModerate => 'moderat aktiv';

  @override
  String get calculatorModerateHint => 'Übung 3-5 Tage pro Woche';

  @override
  String get calculatorActive => 'Aktiv';

  @override
  String get calculatorActiveHint => 'Übung 6-7 Tage pro Woche';

  @override
  String get calculatorVeryActive => 'Sehr aktiv';

  @override
  String get calculatorVeryActiveHint =>
      'Körperliche Arbeit und tägliches Training';

  @override
  String get calculatorNumbersRequired =>
      'Geben Sie in allen Feldern Zahlen ein (Gewicht, Größe und Alter).';

  @override
  String get calculatorCalculate => 'Kalkulieren Sie den Kalorienbedarf';

  @override
  String get calculatorSaveFailed => 'Konnte dein Ziel nicht retten.';

  @override
  String calculatorGoalSaved(int kcal) {
    return 'Gespeichertes Ziel: $kcal kcal/Tag';
  }

  @override
  String get calculatorChooseGoal => 'Wählen Sie Ihr Ziel';

  @override
  String get calculatorGoalHint =>
      'Tippen Sie auf eine Kachel, um sie auszuwählen, oder stimmen Sie sie mit dem Schieberegler unten ab.';

  @override
  String get calculatorLoss => 'Gewichtsabnahme';

  @override
  String get calculatorMaintenance => 'Behalten';

  @override
  String get calculatorGain => 'Gewichtszunahme';

  @override
  String calculatorCustomGoal(int kcal) {
    return 'Ihr Ziel: $kcal kcal/Tag';
  }

  @override
  String get calculatorMacros => 'Geschätzte Makronährstoffaufteilung';

  @override
  String get calculatorProtein => 'Protein';

  @override
  String get calculatorFat => 'Fett';

  @override
  String get calculatorCarbs => 'Kohlenhydrate';

  @override
  String get calculatorSaveGoal => 'Als mein Ziel speichern';

  @override
  String get socialInviteTitle => 'Laden Sie einen Freund ein';

  @override
  String get socialIdentifier => 'Benutzername oder E-Mail';

  @override
  String get socialSend => 'Senden';

  @override
  String get socialInvitationSent => 'Einladung verschickt.';

  @override
  String get socialInvitationAccepted => 'Einladung angenommen.';

  @override
  String get socialInvitationDeclined => 'Die Einladung ging zurück.';

  @override
  String get socialInvitationCancelled => 'Einladung abgesagt.';

  @override
  String get socialFriends => 'Freunde';

  @override
  String get socialInvite => 'Einladung';

  @override
  String get socialRetry => 'Versuchen Sie es noch einmal';

  @override
  String get socialIncoming => 'Einladungen für Sie';

  @override
  String get socialYourFriends => 'Deine Freunde';

  @override
  String get socialNoFriends =>
      'Du hast noch keine Freunde, schick deine erste Einladung.';

  @override
  String get socialFriendSubtitle => 'Rezepte und Einkaufsliste';

  @override
  String get socialOutgoing => 'Versendete Einladungen';

  @override
  String get socialAwaitingResponse => 'Warten auf eine Antwort';

  @override
  String get socialDecline => 'Rückgang';

  @override
  String get socialAccept => 'Akzeptieren';

  @override
  String get socialNoFriendRecipes =>
      'Dieser Freund hat noch keine gespeicherten Rezepte.';

  @override
  String socialRecipeSummary(int minutes, String meal) {
    return '$minutes min • $meal';
  }

  @override
  String get socialNoFriendLists =>
      'Dieser Freund hat derzeit keine aktive Einkaufsliste.';

  @override
  String get socialShareAccepted =>
      'Akzeptiert - die Liste erscheint in Ihren freigegebenen Listen.';

  @override
  String get socialSharesTitle => 'Einladungen für Einkaufslisten';

  @override
  String get socialNoPendingShares => 'Keine ausstehenden Einladungen.';

  @override
  String socialSharedListInvitation(String name) {
    return '$name teilten eine Einkaufsliste mit Ihnen';
  }

  @override
  String get socialSomeone => 'Jemand';

  @override
  String get socialShareRespond => 'Tippen Sie auf Antwort';

  @override
  String get socialShareAccept => 'Akzeptieren';

  @override
  String get notificationsTitle => 'Meldungen';

  @override
  String get notificationsLoadFailed =>
      'Meldungen konnten nicht geladen werden';

  @override
  String get notificationsMarkAllFailed =>
      'Konnte nicht alle Benachrichtigungen als gelesen markieren';

  @override
  String get notificationsPlanEnded => 'Dieser Plan ist beendet.';

  @override
  String get notificationsRecipeOpenFailed => 'Konnte das Rezept nicht öffnen';

  @override
  String get notificationsJustNow => 'gerade jetzt';

  @override
  String notificationsMinutes(int count) {
    return '$count min ago';
  }

  @override
  String notificationsHours(int count) {
    return '$count Vorher';
  }

  @override
  String notificationsDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Vor $count Tagen',
      one: 'Vor 1 Tag',
    );
    return '$_temp0';
  }

  @override
  String get notificationsMarkAll => 'Markieren Sie alles als gelesen';

  @override
  String get notificationsEmpty => 'Keine Meldungen';

  @override
  String get releasePromptTitle => 'Ein Update ist verfügbar';

  @override
  String get releasePromptRequired =>
      'Diese Version wird nicht mehr unterstützt. Aktualisieren Sie die App, um fortzufahren.';

  @override
  String get releasePromptStoreError => 'Konnte den App Store nicht öffnen.';

  @override
  String get releasePromptChanges =>
      '• Ein wärmeres Grün für den Kalorienbalken, Icons und Buttons.\n• Zentrierte Verknüpfungen auf Home und eine passende Add a recipe button.';

  @override
  String detailPlanPortionHelp(int servings, int baseServings) {
    return 'Die Zutaten werden auf $servings Portionen skaliert; die in der Methode angegebenen Mengen beziehen sich auf die ursprüngliche Rezeptur ($baseServings Portionen).';
  }

  @override
  String get releasePromptApple => 'Open App Store';

  @override
  String get releasePromptGoogle => 'Öffnen Sie Google Play';

  @override
  String get releasePromptLater => 'Später';

  @override
  String get pantryAddProduct => 'Produkt hinzufügen';

  @override
  String get pantryEmpty =>
      'Ihre Speisekammer ist leer. Fügen Sie die Produkte hinzu, die Sie zu Hause haben, um schnell herauszufinden, was Sie kochen können.';

  @override
  String get pantryEnterAmount => 'Tippe, um eine Menge einzugeben.';

  @override
  String get pantryRemove => 'Aus dem Vorrat entfernen';

  @override
  String get pantryScanBarcode => 'Scannen Sie einen Barcode';

  @override
  String get pantryScanMany => 'Mehrere Produkte scannen';

  @override
  String get pantrySearchHint => 'Suche nach einem Produkt...';

  @override
  String get pantrySearchStart => 'Geben Sie einen Produktnamen ein.';

  @override
  String get pantrySearchEmpty => 'Keine Ergebnisse.';

  @override
  String pantrySaved(String name) {
    return '„$name“ zum Vorrat hinzugefügt.';
  }

  @override
  String get matchTitle => 'Mit meinen Vorräten kochen';

  @override
  String get matchPremium => 'Premium-Feature';

  @override
  String get matchPremiumBody =>
      'Passende Rezepte zu dem, was Sie in Ihrer Speisekammer haben, sind mit einem aktiven Premium-Abonnement verfügbar.';

  @override
  String get matchSeePremium => 'Siehe Premium';

  @override
  String get matchSelectOne => 'Wählen Sie mindestens eine Zutat.';

  @override
  String get matchEmptyPantry =>
      'Ihre Speisekammer ist leer. Fügen Sie die Produkte hinzu, die Sie zu Hause haben, um passende Rezepte zu finden.';

  @override
  String get matchAddPantry => 'Produkt zum Vorrat hinzufügen';

  @override
  String matchSelected(int selected, int total) {
    return 'Ausgewählt $selected von $total';
  }

  @override
  String get matchDeselect => 'Deselect alle';

  @override
  String get matchSelectAll => 'Wählen Sie alle';

  @override
  String matchSearch(int count) {
    return 'Rezepte finden ($count)';
  }

  @override
  String get matchGenerate => 'Neues Rezept mit KI erstellen';

  @override
  String get matchResultsTitle => 'Passende Rezepturen';

  @override
  String get matchResultsEmpty =>
      'Keine Rezepte im Katalog passen zu den ausgewählten Zutaten. Sie können stattdessen mit KI ein neues Rezept generieren.';

  @override
  String get matchOtherAi => 'Nichts Passendes? Mit KI generieren';

  @override
  String get matchReady => 'Kochfertig';

  @override
  String matchMissing(String ingredients) {
    return 'Fehlend: $ingredients';
  }

  @override
  String matchSelectPrompt(String ingredients) {
    return 'Generieren Sie ein Rezept für ein Gericht, indem Sie hauptsächlich diese Zutaten verwenden, die ich zu Hause habe: $ingredients Sie können höchstens 2-3 allgemein verfügbare Zutaten wie Salz, Gewürze oder Olivenöl hinzufügen.';
  }

  @override
  String matchResultsPrompt(String ingredients) {
    return 'Generieren Sie ein Rezept für ein Gericht, indem Sie hauptsächlich diese Zutaten verwenden, die ich zu Hause habe: $ingredients Bei Bedarf können Sie höchstens 2-3 zusätzliche, allgemein verfügbare Zutaten (z. B. Salz, Gewürze, Olivenöl) hinzufügen.';
  }

  @override
  String get leaderTitle => 'Autoren-Ranking';

  @override
  String get leaderWeek => 'Diese Woche';

  @override
  String get leaderAll => 'Alle Zeiten';

  @override
  String get leaderEmptyWeek =>
      'Niemand hat ein genehmigtes Rezept hinzugefügt\nDiese Woche noch. Sei der Erste!';

  @override
  String get leaderEmptyAll =>
      'Niemand hat ein genehmigtes Rezept hinzugefügt\nZum gemeinsamen Katalog noch.';

  @override
  String leaderCount(int count, String noun) {
    return '$count $noun';
  }

  @override
  String get leaderRecipeSingular => 'Rezeptur';

  @override
  String get leaderRecipeFew => 'Rezepturen';

  @override
  String get leaderRecipeMany => 'Rezepturen';

  @override
  String get adGateTitle => 'Sehen Sie sich eine kurze Anzeige an';

  @override
  String get adGateBody =>
      'Um das Tagebuch zu öffnen, schauen Sie sich eine kurze Videoanzeige bis zum Ende an. Dies gilt nicht für Premium-Konten - ihr Tagebuch ist immer werbefrei.';

  @override
  String get adGateFailed =>
      'Konnte die Anzeige nicht laden. Überprüfen Sie Ihre Internetverbindung und versuchen Sie es erneut.';

  @override
  String get adGateLoading => 'Laden von Werbung...';

  @override
  String get adGateWatch => 'Anzeigen ansehen';

  @override
  String get adGateLater => 'Nicht jetzt';

  @override
  String get promosTitle => 'Absatzförderungen';

  @override
  String get promosAll => 'alle';

  @override
  String get promosFailed => 'Es konnte keine Promotionen laden.';

  @override
  String get promosLoyalty => 'Loyalitätskarte erforderlich';

  @override
  String get promosEmpty => 'Keine aktiven Promotionen im Moment.';

  @override
  String get statsTitle => 'Statistik';

  @override
  String get statsWeight => 'Gewichtszunahme';

  @override
  String get statsWeightEmpty =>
      'Fügen Sie mindestens eine Messung in Ihrem Profil hinzu.';

  @override
  String get statsAverageCalories => 'Durchschnittskalorien';

  @override
  String get statsHydration => 'Hydratation';

  @override
  String get statsFavorite => 'Lieblingsmahlzeit';

  @override
  String get statsNoData => 'Keine Daten';

  @override
  String get statsDailyCalories => 'Tägliche Kalorien';

  @override
  String get statsCaloriesEmpty =>
      'Fügen Sie Mahlzeiten im Tagebuch hinzu, um die Tabelle zu sehen.';

  @override
  String get statsCalories => 'Kalorien';

  @override
  String get statsDailyMacros => 'Tagesmakro';

  @override
  String get statsMacrosEmpty =>
      'Makros werden erscheinen, nachdem Sie Mahlzeiten hinzugefügt haben.';

  @override
  String get statsProtein => 'Protein';

  @override
  String get statsFat => 'Fett';

  @override
  String get statsCarbs => 'Kohlenhydrate';

  @override
  String get statsDailyWater => 'Tägliche Hydratation';

  @override
  String get statsWaterEmpty =>
      'Melden Sie Wasser im Tagebuch an, um das Diagramm zu sehen.';

  @override
  String get statsWater => 'Wasser';

  @override
  String get statsRecentDays => 'Kürzlich protokollierte Tage';

  @override
  String get statsRecentEmpty =>
      'Geloggte Mahlzeiten und Hydratation werden hier erscheinen.';

  @override
  String get statsWeekly => 'Einblicke aus den letzten 7 Tagen';

  @override
  String get statsPremiumTitle => 'Vollständiger Bericht mit Premium';

  @override
  String get statsPremiumBody =>
      'Entsperren Sie Kalorien-, Hydratations- und Gewichtsanalyse mit praktischen Erkenntnissen jede Woche.';

  @override
  String get statsPremiumAction => 'Vollständiger Bericht ansehen';

  @override
  String statsDailyMacroLine(
    String kcal,
    String protein,
    String fat,
    String carbs,
  ) {
    return '$kcal kcal • P $protein g • F $fat g • C $carbs g';
  }

  @override
  String statsWaterLine(int amount) {
    return 'Wasser: $amount ml';
  }

  @override
  String statsMaximum(String amount, String unit) {
    return 'Höchstens: $amount $unit';
  }

  @override
  String insightRegularity(int count) {
    return 'Konsistenz: $count von 7 Tagen';
  }

  @override
  String get insightEnough =>
      'Sie haben jetzt genug Daten, um Wochen zu vergleichen.';

  @override
  String insightMoreDays(int count) {
    return 'Log $count mehr Tage für einen genaueren Bericht.';
  }

  @override
  String insightCalories(int count) {
    return 'Durchschnittliche $count kcal pro Tag';
  }

  @override
  String get insightCaloriesDetail =>
      'Vergleichen Sie wöchentliche Durchschnittswerte, anstatt einen einzigen Tag zu beurteilen.';

  @override
  String get insightWaterMissing => 'Hydratationsdaten fehlen';

  @override
  String insightWaterAverage(int amount) {
    return 'Durchschnittliche $amount ml Wasser';
  }

  @override
  String get insightWaterEveryDay =>
      'Die Hydration wurde diese Woche jeden Tag protokolliert.';

  @override
  String insightWaterDays(int count) {
    return 'Die Hydratation wurde an $count von 7 Tagen angemeldet.';
  }

  @override
  String get insightWeightStable => 'Keine signifikante Gewichtsveränderung';

  @override
  String insightWeightChange(String amount) {
    return 'Gewichtsänderung $amount kg';
  }

  @override
  String get insightWeightDetail =>
      'Vergleich der ersten und letzten Messungen der letzten 7 Tage.';

  @override
  String get cookingTipsTitle => 'Kochtipps';

  @override
  String get splashSubtitle => 'Planen Sie Mahlzeiten mit Bedacht und sparen';

  @override
  String get onboardingStoresEmpty =>
      'Es gibt keine Läden. Versuchen Sie es noch einmal.';

  @override
  String get authCaptchaUnavailable =>
      'Konnte die Verifizierung nicht laden. Überprüfen Sie Ihre Verbindung.';

  @override
  String get authCaptchaRetry => 'Wiederholen';

  @override
  String get authCaptchaContinue => 'Weiter so oder so';

  @override
  String get authCaptchaRefresh => 'Erfrischende Überprüfung';

  @override
  String get adminProductsTitle => 'Eingereichte Produkte';

  @override
  String get adminProductsEmpty =>
      'Keine Produkte warten auf eine Überprüfung.';

  @override
  String get adminProductsRefresh => 'Erfrischende Einreichungen';

  @override
  String get adminProductApproved => 'Produkt zum Katalog hinzugefügt';

  @override
  String get adminProductRejected => 'Abgelehntes Produkt';

  @override
  String get adminNoNutrition => 'Keine Nährwertangaben';

  @override
  String adminProductNutrition(
    String kcal,
    String protein,
    String fat,
    String carbs,
  ) {
    return 'Für 100 g: $kcal kcal · P $protein · F $fat · C $carbs';
  }

  @override
  String get adminReject => 'Ablehnung';

  @override
  String get adminApprove => 'Genehmigen';

  @override
  String get adminAllRecipesTitle => 'Alle Benutzerrezepte';

  @override
  String get adminRecipesEmpty =>
      'Es wurden keine Rezepte von Benutzern hinzugefügt.';

  @override
  String get adminShowMore => 'Mehr anzeigen';

  @override
  String get adminPublic => 'öffentlich';

  @override
  String get adminPending => 'Ausstehend';

  @override
  String get adminRejected => 'abgelehnt';

  @override
  String get adminPrivate => 'Privat';

  @override
  String get adminUnknownAuthor => 'Unbekannter Autor';

  @override
  String get adminDeleteRecipeTooltip => 'Rezeptur löschen';

  @override
  String get adminDeleteRecipeTitle => 'Rezept löschen?';

  @override
  String adminDeleteRecipeBody(String name) {
    return 'Sie löschen \"$name\", seine Kommentare und seine Links zu Einkaufslisten und Essensplänen, die von anderen Benutzern verwendet werden.';
  }

  @override
  String get adminRecipeFallback => 'Dieses Rezept';

  @override
  String get adminUsersTitle => 'Nutzer';

  @override
  String get adminUsersSearch => 'Suche nach E-Mail oder Name...';

  @override
  String get adminUsersOnlyBanned => 'Nur verbotene Konten';

  @override
  String get adminUsersEmpty => 'Keine Ergebnisse.';

  @override
  String get adminUsersUnnamed => 'Nicht namentlich genannt';

  @override
  String adminUsersVersion(String version) {
    return 'Version: $version';
  }

  @override
  String adminUsersReason(String reason) {
    return 'Grund: $reason';
  }

  @override
  String adminUsersBanTitle(String name) {
    return 'Verbot $name?';
  }

  @override
  String get adminUsersBanBody =>
      'Dieses Konto verliert sofort den Zugang zur App, auch wenn es gerade angemeldet ist. Es werden keine Daten gelöscht und das Verbot kann rückgängig gemacht werden.';

  @override
  String get adminUsersReasonLabel => 'Grund (für den Benutzer sichtbar)';

  @override
  String get adminUsersBan => 'Verbot';

  @override
  String get adminUsersUnban => 'Unban';

  @override
  String get adminUsersBanned => 'Konto gesperrt';

  @override
  String get adminUsersUnbanned => 'Konto nicht verboten';

  @override
  String get adminCommentsTitle => 'Anmerkungen';

  @override
  String get adminCommentsSearch =>
      'Suchen Sie Kommentartext, Autor oder Rezept ...';

  @override
  String get adminCommentsEmpty => 'Keine Kommentare.';

  @override
  String adminCommentsRecipe(String name) {
    return 'am: $name';
  }

  @override
  String get adminCommentsPhotoOnly => '(nur Foto)';

  @override
  String get adminCommentsEmptyText => '(leer)';

  @override
  String get adminCommentsHasPhoto => 'Enthält ein Foto';

  @override
  String get adminCommentsDelete => 'Anmerkung streichen';

  @override
  String get adminCommentsDeleteTitle => 'Kommentar löschen?';

  @override
  String get adminCommentsDeleteBody =>
      'Das kann nicht rückgängig gemacht werden.';

  @override
  String get adminCommentsDeleted => 'Kommentar gelöscht';

  @override
  String get adminPhotosTitle => 'Fotos warten auf Überprüfung';

  @override
  String get adminPhotosEmpty => 'Keine Fotos warten auf eine Überprüfung.';

  @override
  String get adminPhotosApproved => 'Foto genehmigt';

  @override
  String get adminPhotosRejected => 'Foto abgelehnt';

  @override
  String get adminPhotosRecipe => 'Rezeptur';

  @override
  String get adminPhotosUnknownSubmitter => 'unbekannt';

  @override
  String adminPhotosSubmittedBy(String name) {
    return 'Eingereicht von: $name';
  }

  @override
  String get adminPhotosReplaceWarning =>
      'Bitte beachten Sie: Dieses Rezept hat bereits ein Foto - die Genehmigung dieses Rezepts wird es ersetzen.';

  @override
  String get adminPhotosLoadError => 'Kann das Foto nicht laden';

  @override
  String get adminPhotosApprove => 'Genehmigen';

  @override
  String get adminMainTitle => 'Admin-Panel';

  @override
  String adminMainBroadcastSent(String count) {
    return 'Gesendet an $count Benutzer.';
  }

  @override
  String get adminMainReportsTitle => 'Inhaltsberichte';

  @override
  String get adminMainReportsHelp =>
      'Rezepte und kommentare, die von nutzern als spam, belästigung oder andere verstöße gegen die bedingungen gemeldet werden.';

  @override
  String get adminMainReportsEmpty => 'Keine ungelösten Berichte.';

  @override
  String get adminMainRecipeType => 'Rezeptur';

  @override
  String get adminMainCommentType => 'Anmerkungen';

  @override
  String adminMainReportDetails(String details) {
    return 'Details von Reporter: $details';
  }

  @override
  String adminMainAuthor(String email) {
    return 'Autor: $email';
  }

  @override
  String adminMainReporter(String email) {
    return 'Gemeldet von: $email';
  }

  @override
  String get adminMainDismiss => 'Abweisungsbericht';

  @override
  String get adminMainDeleteContent => 'Löschen des Inhalts';

  @override
  String get adminMainResolve => 'Markierung als aufgelöst';

  @override
  String get adminMainBroadcastTitle =>
      'Senden Sie eine Benachrichtigung an alle';

  @override
  String get adminMainBroadcastHelp =>
      'Dies geht an JEDE In-App-Benachrichtigungen von Benutzern - es kann nicht rückgängig gemacht werden. Überprüfen Sie den Text vor dem Senden.';

  @override
  String get adminMainBroadcastHint => 'Notifizierungstext ...';

  @override
  String get adminMainBroadcastSend => 'Senden Sie an alle';

  @override
  String get adminMainPromotionsLoadFailed =>
      'Konnte ausstehende Promotions nicht laden.';

  @override
  String adminMainScanSummary(String found, String queued) {
    return 'Gefunden $found; Warteschlange $queued zur Genehmigung.';
  }

  @override
  String get adminMainScanPending =>
      'Das Scannen auf dem Server wird fortgesetzt. Sie können dieses Panel verlassen; die Ergebnisse werden in der Warteschlange zur Überprüfung angezeigt.';

  @override
  String get adminMainPromotionApproved => 'Zugelassene Absatzförderung';

  @override
  String get adminMainPromotionRejected => 'Ablehnung der Beförderung';

  @override
  String get adminMainActionFailed => 'Konnte die Aktion nicht abschließen';

  @override
  String get adminMainRecipesLoadFailed =>
      'Konnte keine ausstehenden Rezepte laden.';

  @override
  String get adminMainReportsLoadFailed =>
      'Berichte konnten nicht geladen werden.';

  @override
  String get adminMainDeleteContentTitle =>
      'Löschen Sie den gemeldeten Inhalt?';

  @override
  String get adminMainDeleteContentHelp =>
      'Der Kommentar oder das Rezept wird dauerhaft gelöscht und der Bericht geschlossen, was nicht rückgängig gemacht werden kann.';

  @override
  String get adminMainContentDeleted => 'Inhalt gelöscht; Bericht geschlossen';

  @override
  String get adminMainReportResolved => 'Bericht als gelöst gekennzeichnet';

  @override
  String get adminMainReportDismissed => 'Abgelehnter Bericht';

  @override
  String get adminMainRecipeApproved => 'Zugelassenes Rezept';

  @override
  String get adminMainRecipeRejected => 'Rezept abgelehnt';

  @override
  String get adminMainRecipesTitle => 'Rezepte warten auf Genehmigung';

  @override
  String get adminMainRecipesHelp =>
      'Rezepte, die von Premium-Nutzern zum gemeinsamen öffentlichen Katalog eingereicht werden.';

  @override
  String get adminMainRecipesEmpty =>
      'Es gibt keine Rezepte, die auf die Genehmigung warten.';

  @override
  String adminMainRecipeMeta(
    String mealType,
    String servings,
    String difficulty,
  ) {
    return '$mealType • $servings Portionen • $difficulty';
  }

  @override
  String get adminMainRecipePreview =>
      'Tippen Sie, um Zutaten, Anweisungen, Foto und Makros zu überprüfen';

  @override
  String get adminMainApprove => 'Genehmigen';

  @override
  String get adminMainAiTitle => 'Status des KI-Dienstes';

  @override
  String get adminMainAiHelp =>
      'Prüft, ob der Gemini-Schlüssel funktioniert und dass die Token-/Anforderungslimits nicht für jedes Modell separat erreicht wurden.';

  @override
  String get adminMainAiCheck => 'KI-Status überprüfen';

  @override
  String get adminMainAiKeyMissing =>
      'Der API-Schlüssel ist nicht konfiguriert.';

  @override
  String get adminMainScanTitle => 'Scan Promotion Merkblätter';

  @override
  String get adminMainScanHelp =>
      'KI sucht online nach dem aktuellen Merkblatt des Shops und erkennt dessen Promotions. Die Ergebnisse gehen in die unten stehende Genehmigungswarteschlange – nichts ändert sich automatisch.';

  @override
  String get adminMainDeScanUnavailable =>
      'Angebote deutscher Supermärkte können derzeit noch nicht gescannt werden.';

  @override
  String get adminMainUkScanUnavailable =>
      'Die britischen Werbequellen werden derzeit vorbereitet, der polnische Flugblattscanner erstellt keine Werbeaktionen im GBP-Bereich.';

  @override
  String adminMainScanShop(String store) {
    return 'Scan $store';
  }

  @override
  String adminMainScanningShop(String store) {
    return 'Das Scannen $store geht im Hintergrund weiter.';
  }

  @override
  String get adminMainPendingTitle => 'Warten auf die Genehmigung';

  @override
  String get adminMainPromotionsEmpty =>
      'Keine Promotionen warten auf die Genehmigung.';

  @override
  String get adminMainProductsNav => 'Produkte';

  @override
  String get adminMainUserRecipesNav => 'Benutzerrezepte';

  @override
  String get campaignTitle => 'Kampagnen';

  @override
  String get campaignRequired =>
      'Geben Sie den Namen, die Daten, die Konfiguration des Shopangebots und den Empfänger an.';

  @override
  String get campaignConfirmGoogle => 'Bestätigen Sie das Google Play Angebot';

  @override
  String get campaignConfirmApple => 'Bestätigen Sie das App Store Angebot';

  @override
  String campaignConfirmPoints(String store) {
    return 'Nur nach Festlegung eines temporären Preises für dieses Punktepaket in $store für alle Benutzer aktivieren Der In-App-Preis kommt direkt aus dem Store.';
  }

  @override
  String get campaignConfirmPremium =>
      'Aktivieren Sie nur, wenn das angegebene Shop-Angebot aktiv ist, genau diesen Rabatt hat und das richtige Produkt abdeckt.';

  @override
  String get campaignConfirm => 'Bestätigung';

  @override
  String get campaignDeleteTitle => 'Kampagne löschen?';

  @override
  String campaignDeleteBody(String name) {
    return 'Die Kampagne „$name wird aus diesem Panel entfernt. Sie müssen das Shopangebot separat deaktivieren.';
  }

  @override
  String get campaignMarketDe => 'Markt: Deutschland • EUR • Europe/Berlin';

  @override
  String get campaignMarketGb =>
      'Markt: Vereinigtes Königreich • GBP • Europa / London';

  @override
  String get campaignMarketPl => 'Markt: Polen • PLN • Europa/Warschau';

  @override
  String get campaignHeading => 'Premium und Points Promotion';

  @override
  String get campaignHelp =>
      'Bänder erscheinen auf den Symbolen im Premium-Panel. Ein iOS-Abonnement öffnet einen Apple-Angebotscode; Android wählt ein Google Play-Angebot aus. Legen Sie für Punkte einen temporären Produktpreis für alle im jeweiligen Shop fest.';

  @override
  String get campaignName => 'Name der Kampagne';

  @override
  String get campaignStore => 'Lagerhaus';

  @override
  String get campaignOffer => 'Angebot';

  @override
  String get campaignSubscription => 'Premium-Abo';

  @override
  String get campaignPoints => 'Prämienpunkte';

  @override
  String get campaignProduct => 'Unter das Angebot fallendes Produkt';

  @override
  String get campaignDiscount => 'Abzinsung';

  @override
  String get campaignAudience => 'Publikum';

  @override
  String get campaignEveryone => 'Jedermann';

  @override
  String get campaignOneUser => 'Ein Nutzer';

  @override
  String get campaignEmail => 'E-Mail des Nutzers';

  @override
  String get campaignDates => 'Wählen Sie Termine';

  @override
  String get campaignAppleUrl => 'Apple bietet Code Link';

  @override
  String get campaignAppleUrlHelp =>
      'Link: apps.apple.com/redeem?ctx=offercodes...';

  @override
  String get campaignBasePlan => 'Google Play: Basisplan ID';

  @override
  String get campaignAndroidOffer => 'Google Play: Angebot ID';

  @override
  String campaignPointsHelp(String store) {
    return 'Planen Sie zunächst eine vorübergehende Preissenkung für dieses Punktepaket in $store an. Die Kampagne zeigt ein Band, aber der Preis kommt immer direkt aus dem Laden.';
  }

  @override
  String get campaignSaving => 'Rettung...';

  @override
  String get campaignCreate => 'Kampagne erstellen (deaktiviert)';

  @override
  String get campaignSaved => 'Gespeicherte Kampagnen';

  @override
  String get campaignEmpty => 'Keine Kampagnen.';

  @override
  String get campaignActive => 'Aktiv';

  @override
  String get campaignDeleteTooltip => 'Kampagne löschen';

  @override
  String get adminMarketLabel => 'Katalogmarkt';

  @override
  String get adminMarketBusy =>
      'Warten Sie, bis die aktuelle Operation abgeschlossen ist.';

  @override
  String get adminMarketHelp =>
      'Ändert die Datenansicht, nicht das Land Ihres Kontos.';

  @override
  String get adminMarketPl => 'Polen';

  @override
  String get adminMarketDe => 'Deutschland';

  @override
  String get adminMarketGb => 'Vereinigtes Königreich';

  @override
  String get approvalRecipePending =>
      'Dieses Rezept wartet auf Ihre Genehmigung für den gemeinsamen Katalog';

  @override
  String get approvalRecipeApprove => 'Genehmigen';

  @override
  String get approvalRecipeApproved => 'Zugelassenes Rezept';

  @override
  String get approvalRecipeRejected => 'Rezept abgelehnt';

  @override
  String get approvalRecipeFailed => 'Konnte die Aktion nicht abschließen';

  @override
  String get shoppingAddQueryHint =>
      'Geben Sie einen beliebigen Artikel ein...';

  @override
  String get shoppingAddCustom =>
      'Fügen Sie den von Ihnen eingegebenen Artikel hinzu';

  @override
  String get shoppingAddMatches =>
      'Passende Produkte aus dem Katalog und früheren Scans';

  @override
  String get shoppingAddMinimumQuery =>
      'Geben Sie mindestens 2 Zeichen ein, um nach einem Produkt zu suchen.';

  @override
  String get shoppingAddNoResults =>
      'Es wurde kein Produkt mit diesem Namen gefunden.';

  @override
  String shoppingAddSuccess(String name) {
    return 'Hinzugefügt: $name';
  }

  @override
  String get shoppingAddCustomFailed => 'Konnte den Artikel nicht hinzufügen';

  @override
  String get shoppingAddProductFailed => 'Konnte das Produkt nicht hinzufügen';

  @override
  String get shoppingAddProductFallback => 'Produkt';

  @override
  String get shoppingAddCatalogSource => 'App Katalog';

  @override
  String get shoppingAddCacheSource => 'Zuvor gescannt';

  @override
  String exportListHeading(String store) {
    return 'Meine Einkaufsliste: $store';
  }

  @override
  String exportListSubject(String store) {
    return 'Einkaufsliste - $store';
  }

  @override
  String get exportListTitle => 'Ausfuhrliste';

  @override
  String get exportListCopy => 'Kopieren in die Zwischenablage';

  @override
  String get exportListCopied => 'Kopiert ins Clipboard!';

  @override
  String exportListOpenApp(String name) {
    return 'Geöffnet $name';
  }

  @override
  String get exportListAppMissing => 'Diese App ist nicht installiert.';

  @override
  String get exportListAppFailed => 'Die App konnte nicht geöffnet werden.';

  @override
  String get exportListComingSoon => 'Kommt bald';

  @override
  String get diarySignInView =>
      'Melden Sie sich an, um Ihr Tagebuch anzusehen.';

  @override
  String get diarySignInAdd =>
      'Melden Sie sich an, um einen Eintrag hinzuzufügen.';

  @override
  String get authStoredSessionFailed =>
      'Wir konnten Ihre gespeicherte Sitzung nicht wiederherstellen.';

  @override
  String authGoogleNativeFailed(Object code) {
    return 'Ich konnte mich nicht bei Google anmelden ($code).';
  }

  @override
  String get authGoogleTokenUnavailable =>
      'Konnte das Google Identity Token nicht erhalten.';

  @override
  String get authAppleNativeFailed =>
      'Ich konnte mich nicht bei Apple anmelden. Bitte versuchen Sie es noch einmal.';

  @override
  String get authAppleTokenUnavailable =>
      'Konnte das Apple Identity Token nicht erhalten.';

  @override
  String get shoppingLimitTitle =>
      'Mehr Einkaufen? Gehen Sie unbegrenzt mit Premium';

  @override
  String get shoppingLimitDescription =>
      'Sie haben diese Woche Ihre kostenlose Einkaufsliste genutzt. Mit Premium erstellen Sie separate Listen für Rezepte, Geschäfte und Ihren nächsten Shop – wann immer Sie sie brauchen.';

  @override
  String get shoppingLimitSeePremium => 'Entdecken Sie Premium';

  @override
  String get shoppingLimitBack => 'Zurück zu meiner Einkaufsliste';

  @override
  String get shoppingLimitShort =>
      'Sie haben das Listenlimit dieser Woche erreicht. Erstellen Sie weitere Listen mit Premium.';

  @override
  String get compareNoPoints => 'Keine Punkte erforderlich';

  @override
  String get compareImportPointCost => '2 Punkte / Import';
}
