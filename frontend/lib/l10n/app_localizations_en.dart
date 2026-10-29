// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get scanPantryAmountHint => 'Choose an amount in grams or millilitres';

  @override
  String get foodEntryTitle => 'Add a meal';

  @override
  String get foodEntryFromPlan => 'From plan';

  @override
  String get foodEntryFromRecipes => 'From recipes';

  @override
  String get foodEntryProducts => 'Products';

  @override
  String get foodEntryServingsQuestion => 'How many servings did you eat?';

  @override
  String get foodEntryMealFailed => 'Could not add the meal';

  @override
  String get foodEntryProductFailed => 'Could not add the product';

  @override
  String get foodEntryMealType => 'Meal type';

  @override
  String get foodEntryAddDiary => 'Add to diary';

  @override
  String get foodEntryNoPlan =>
      'You do not have an active meal plan yet.\nCreate a plan in Home to log its meals\nwith one tap.';

  @override
  String get foodEntryNoPlannedMeals =>
      'No meals planned for the selected day.';

  @override
  String get foodEntryRecipesFailed => 'Could not load recipes';

  @override
  String get foodEntryRecipeSearch => 'Search recipes...';

  @override
  String get foodEntryNoResults => 'No results.';

  @override
  String get foodEntryServings => 'Number of servings';

  @override
  String get foodEntryAdjustIngredients => 'Adjust ingredients';

  @override
  String get foodEntryRepeatFailed => 'Could not repeat the entry';

  @override
  String get foodEntryRepeat => 'Add again';

  @override
  String get foodEntryMissingProduct =>
      'Product missing? Add it to the catalogue';

  @override
  String get foodEntrySaveFailed => 'Could not add the entry';

  @override
  String get foodEntryChooseCatalogue => 'Choose from catalogue';

  @override
  String get foodEntryProductName => 'Product / meal name';

  @override
  String get foodEntryNameHint => 'Enter a name or choose a suggestion';

  @override
  String get foodEntryNameRequired => 'Enter a name';

  @override
  String get foodEntryPortion => 'Serving (g/ml, optional)';

  @override
  String get foodEntryCalories => 'Calories (kcal)';

  @override
  String get foodEntryRequired => 'Required';

  @override
  String get foodEntryProtein => 'Protein (g)';

  @override
  String get foodEntryCarbs => 'Carbs (g)';

  @override
  String get foodEntryFat => 'Fat (g)';

  @override
  String get foodEntrySave => 'Save to diary';

  @override
  String get foodEntryInvalidNumber => 'Enter a valid, non-negative number.';

  @override
  String get foodEntryInvalidPortion =>
      'Enter an amount above 0 (max. 1000000).';

  @override
  String get scanZoomUnavailable => 'This camera does not support zoom.';

  @override
  String get scanZoomHint => 'Use 2× zoom or move the phone further away.';

  @override
  String get scanLensFailed => 'Could not switch camera lenses.';

  @override
  String get scanEnterCode => 'Enter a barcode';

  @override
  String get scanCodeHint => '8–14 digits';

  @override
  String get scanBatchCodeHint => '8, 12, 13 or 14 digits';

  @override
  String get scanSearch => 'Search';

  @override
  String get scanCodeInvalidLength => 'The code must contain 8–14 digits.';

  @override
  String get scanCodeInvalid => 'The code is invalid. Check the digits.';

  @override
  String get scanDuplicate => 'This product is already in this batch.';

  @override
  String get scanGuide =>
      'Point the camera at a barcode. Tap the image to focus.';

  @override
  String get scanNormal => 'Normal';

  @override
  String get scanCloseUp => 'Close-up';

  @override
  String get scanTorch => 'Torch';

  @override
  String get scanManual => 'Enter code manually';

  @override
  String get scanNormalLens => 'Normal lens';

  @override
  String get scanCloseUpMode => 'Close-up mode';

  @override
  String get scanZoomTwo => 'Zoom 2×';

  @override
  String get scanZoomOne => 'Zoom 1×';

  @override
  String get scanMissing => 'Not found. Tap to add the product from photos.';

  @override
  String get scanMissingNutrition =>
      'Product found, but calories or macros are missing. Tap to complete the data from label photos.';

  @override
  String get scanMissingPackage =>
      'Product found, but the whole-pack size is missing. Tap to read it from a label photo.';

  @override
  String get scanCorrectNutrition =>
      'Calories or macros are missing. Tap to correct the data.';

  @override
  String get scanCorrectPackage =>
      'The whole-pack size could not be read. Tap to update the photos or enter the amount manually.';

  @override
  String get scanAddedPantry => 'Added to pantry';

  @override
  String get scanAddedDiary => 'Added to diary';

  @override
  String get scanNutritionUnconfirmed =>
      'The server did not confirm the product\'s nutrition values.';

  @override
  String get scanAlreadyCatalogue => 'Already in the catalogue';

  @override
  String get scanAddedCatalogue => 'Added to catalogue';

  @override
  String get scanAlreadySubmitted => 'Product already submitted';

  @override
  String get scanWaitLookup => 'Wait for all codes to be recognised.';

  @override
  String get scanFirstProduct => 'Scan at least one product first.';

  @override
  String get scanCompleteMissing => 'Complete or retry unrecognised products.';

  @override
  String get scanChooseDestinations =>
      'Choose at least one destination for the whole batch.';

  @override
  String get scanBatchTitle => 'Batch scanning';

  @override
  String get scanFinish => 'Finish';

  @override
  String get scanBatchGuide =>
      'Scan the next products. Choose destinations once for the whole batch.';

  @override
  String get scanBatchEmpty => 'Scanned products will appear here.';

  @override
  String get scanPremiumPreview => 'Premium feature preview';

  @override
  String get scanPreviewTitle => 'Scan your whole shop in one go';

  @override
  String get scanPreviewBody =>
      'The camera stays open and recognised products appear in one list. Choose destinations at the end and confirm everything once.';

  @override
  String get scanSampleYogurt => 'Natural yoghurt';

  @override
  String get scanSamplePasta => 'Wholewheat pasta';

  @override
  String get scanSampleYogurtMacro => '100 g: 62 kcal · P 4 g · F 3 g · C 5 g';

  @override
  String get scanSamplePastaMacro =>
      '100 g: 348 kcal · P 13 g · F 3 g · C 65 g';

  @override
  String get scanAllDestinations => 'Add all to';

  @override
  String get scanTrial => 'Explore Premium';

  @override
  String get scanPreviewNoCamera =>
      'This is a preview — the camera has not been started.';

  @override
  String get scanMealTypeAll => 'Meal type for all products';

  @override
  String get scanAdding => 'Adding products…';

  @override
  String get scanRecognising => 'Recognising…';

  @override
  String get scanReady => 'Ready to add with the batch';

  @override
  String get scanSaving => 'Adding…';

  @override
  String get scanDone => 'Done';

  @override
  String get scanTapComplete => 'Tap to complete product details';

  @override
  String get scanTapRetry => 'Error. Tap to retry.';

  @override
  String get scanWhere => 'Where would you like to add this product?';

  @override
  String get scanMultiHint => 'You can select several destinations at once.';

  @override
  String get scanNutritionMissingHint =>
      'Complete nutrition values were not found. After choosing a destination, you can complete the data from packaging photos.';

  @override
  String get scanDiaryDestination => 'Add to diary';

  @override
  String get scanDiaryDestinationHint => 'Choose an amount and meal type';

  @override
  String get scanCatalogueDestination => 'Add to product catalogue';

  @override
  String get scanCatalogueDestinationHint =>
      'Check the name, brand and nutrition';

  @override
  String get scanPantryDestination => 'Add to pantry';

  @override
  String get scanPantryDestinationHint => 'Save as 1 whole pack';

  @override
  String get scanNext => 'Next';

  @override
  String get catalogueNutritionMissing =>
      'Complete nutrition values could not be found online. Complete the data from packaging photos.';

  @override
  String get catalogueIncomplete =>
      'This product does not have nutrition values yet. Add it to the catalogue with label data to use it in the diary.';

  @override
  String get catalogueProductSearch => 'Search products...';

  @override
  String get catalogueNoMatch => 'No products match your search.';

  @override
  String get autocompleteCatalogue => 'app catalogue';

  @override
  String get autocompleteScanned => 'previously scanned';

  @override
  String get autocompleteHint =>
      'You can choose a suggestion or keep your own name.';

  @override
  String foodEntryPlanDate(String date) {
    return 'Your active plan does not cover the selected date ($date).';
  }

  @override
  String foodEntryKcalServing(String kcal) {
    return '$kcal kcal / serving';
  }

  @override
  String scanCameraError(String error) {
    return 'The camera could not be started. Check camera permission or enter the code manually.\n$error';
  }

  @override
  String scanBatchCameraError(String error) {
    return 'The camera could not be started. Check camera permission.\n$error';
  }

  @override
  String scanRetryError(String error) {
    return '$error Tap to try again.';
  }

  @override
  String scanRetrySavedError(String error) {
    return '$error Completed destinations will not be added again. Tap to retry.';
  }

  @override
  String scanAddedPoints(int points) {
    return 'Added to catalogue (+$points pt)';
  }

  @override
  String scanAddedCount(int count) {
    return 'Added $count products.';
  }

  @override
  String scanAddedPartial(int saved, int total) {
    return 'Added $saved of $total. Tap failed items to try again.';
  }

  @override
  String scanQueueCount(int count) {
    return 'Recognising products · $count waiting';
  }

  @override
  String scanDoneCount(int count) {
    return 'Done · $count products';
  }

  @override
  String scanAddAllCount(int count) {
    return 'Add all ($count)';
  }

  @override
  String scanCodeLabel(String code) {
    return 'Code: $code';
  }

  @override
  String scanDestinationsCount(int count) {
    return 'Add to $count destinations';
  }

  @override
  String scanPantryAddedName(String name) {
    return '$name added to pantry.';
  }

  @override
  String get diaryCustomWater => 'Custom amount';

  @override
  String get rewardProductSemantics =>
      'Reward: one Premium point for adding a new, unique product to the catalogue.';

  @override
  String get rewardProductTitle => 'Earn 1 Premium point';

  @override
  String get rewardProductBody =>
      'Scan a barcode or manually add a new, unique product to the catalogue.';

  @override
  String get rewardProductPoint => '+1 pt';

  @override
  String get productsMarketUnavailable =>
      'A verified price list is not available for this market.';

  @override
  String get home => 'Home';

  @override
  String get recipes => 'Recipes';

  @override
  String get shopping => 'Shopping';

  @override
  String get diary => 'Food diary';

  @override
  String get premium => 'Premium';

  @override
  String get profile => 'Profile';

  @override
  String get add => 'Add';

  @override
  String get newPlan => 'New plan';

  @override
  String get planMeals => 'Plan your meals';

  @override
  String get productDatabase => 'Food database';

  @override
  String get checkPrices => 'Check prices';

  @override
  String get promotions => 'Offers';

  @override
  String get currentOffers => 'Current offers';

  @override
  String get pantry => 'Pantry';

  @override
  String get whatYouHaveAtHome => 'What you have at home';

  @override
  String get planArchive => 'Archived plans';

  @override
  String get scanBarcode => 'Scan a barcode';

  @override
  String get batchScan => 'Scan multiple products';

  @override
  String get addRecipeWithAi => 'Add a recipe with AI';

  @override
  String get addMeal => 'Add a meal';

  @override
  String get addToPantry => 'Add to pantry';

  @override
  String get barcodeDestinations =>
      'Add to your food diary, food database or pantry';

  @override
  String get whatToAdd => 'What would you like to add?';

  @override
  String get scanProduct => 'Scan a product';

  @override
  String get batchDestinationHint =>
      'Choose where to save the whole batch and confirm once';

  @override
  String get aiRecipeSources => 'From a photo, text or link';

  @override
  String get recordCaloriesAndMacros => 'Record calories and macros';

  @override
  String get premiumTwoPoints => 'PREMIUM · 2 PTS';

  @override
  String recipeLoadError(String error) {
    return 'Could not load recipes: $error';
  }

  @override
  String recipeLoadMoreError(String error) {
    return 'Could not load more recipes: $error';
  }

  @override
  String get recipeImportInProgress => 'AI is adding your recipe';

  @override
  String get recipeAuthorRanking => 'Recipe creator leaderboard';

  @override
  String get recipeSearchHint => 'Recipe, creator or ingredient...';

  @override
  String get clearSearch => 'Clear search';

  @override
  String get recipeFavourites => 'Favourites';

  @override
  String get recipeMine => 'Mine';

  @override
  String get recipeNew => 'New';

  @override
  String get recipeCommunity => 'Community';

  @override
  String get moreFilters => 'More';

  @override
  String get loadingMore => 'Loading…';

  @override
  String get showMoreRecipes => 'Show more recipes';

  @override
  String get addRecipe => 'Add a recipe';

  @override
  String get withAi => 'With AI';

  @override
  String get takeRecipePhoto => 'Take a photo';

  @override
  String get recipePhotoHint => 'Of a recipe or a finished dish';

  @override
  String get pasteText => 'Paste text';

  @override
  String get pasteLink => 'Paste a link';

  @override
  String get addManually => 'Add manually';

  @override
  String get filters => 'Filters';

  @override
  String get clearFilters => 'Clear';

  @override
  String get sortRecipes => 'Sort by';

  @override
  String get sortAlphabetically => 'Alphabetical';

  @override
  String get sortCaloriesLow => 'Calories: lowest first';

  @override
  String get sortCaloriesHigh => 'Calories: highest first';

  @override
  String get sortQuickest => 'Quickest first';

  @override
  String get recipeDiet => 'Diet';

  @override
  String get allRecipes => 'All';

  @override
  String get recipeMealType => 'Meal type';

  @override
  String get filterBreakfast => 'Breakfast';

  @override
  String get filterLunch => 'Lunch';

  @override
  String get filterDinner => 'Dinner';

  @override
  String get filterSnacks => 'Snacks';

  @override
  String get filterDesserts => 'Desserts';

  @override
  String get recipeDifficulty => 'Difficulty';

  @override
  String get anyDifficulty => 'Any';

  @override
  String get filterEasy => 'Easy';

  @override
  String get filterMedium => 'Medium';

  @override
  String get filterHard => 'Hard';

  @override
  String get showResults => 'Show results';

  @override
  String recipeCardSummary(int minutes, int calories) {
    return '$minutes min • $calories kcal/serving';
  }

  @override
  String get noRecipes => 'No recipes found';

  @override
  String get noRecipesHint => 'Check the recipe, creator or ingredient name.';

  @override
  String get mealBreakfast => 'breakfast';

  @override
  String get mealLunch => 'lunch';

  @override
  String get mealDinner => 'dinner';

  @override
  String get mealSnack => 'snack';

  @override
  String get mealDessert => 'dessert';

  @override
  String get difficultyEasy => 'easy';

  @override
  String get difficultyMedium => 'medium';

  @override
  String get difficultyHard => 'hard';

  @override
  String get dietNoRestrictions => 'No restrictions';

  @override
  String get dietVegetarian => 'Vegetarian';

  @override
  String get dietVegan => 'Vegan';

  @override
  String get dietGlutenFree => 'Gluten-free';

  @override
  String get dietKeto => 'Keto';

  @override
  String get dietHighProtein => 'High-protein';

  @override
  String get dietNoRestrictionsDescription => 'Eat all the foods you enjoy';

  @override
  String get dietVegetarianDescription => 'Meals without meat or fish';

  @override
  String get dietVeganDescription => '100% plant-based meals';

  @override
  String get dietGlutenFreeDescription => 'Meals without gluten';

  @override
  String get dietKetoDescription => 'Low-carbohydrate meals';

  @override
  String get dietHighProteinDescription =>
      'For active lifestyles and building muscle';

  @override
  String get planStatusActive => 'active';

  @override
  String get planStatusDraft => 'draft';

  @override
  String get planStatusCompleted => 'completed';

  @override
  String get planStatusArchived => 'archived';

  @override
  String get authCaptchaRequired => 'Please confirm you are not a robot first.';

  @override
  String get authLoginFailed => 'Sign-in failed';

  @override
  String get authWelcomeBack => 'Welcome back!';

  @override
  String get authLoginPrompt => 'Sign in to your account';

  @override
  String get authEmail => 'Email';

  @override
  String get authEnterEmail => 'Enter your email address';

  @override
  String get authEnterValidEmail => 'Enter a valid email address';

  @override
  String get authPassword => 'Password';

  @override
  String get authEnterPassword => 'Enter your password';

  @override
  String get authPasswordMinSix =>
      'Your password must contain at least 6 characters';

  @override
  String get authSignIn => 'Sign in';

  @override
  String get authForgotPasswordQuestion => 'Forgot your password?';

  @override
  String get authOr => 'or';

  @override
  String get authContinueApple => 'Continue with Apple';

  @override
  String get authContinueGoogle => 'Continue with Google';

  @override
  String get authNoAccount => 'Don\'t have an account?';

  @override
  String get authRegister => 'Sign up';

  @override
  String authDocumentOpenFailed(String url) {
    return 'Could not open: $url';
  }

  @override
  String get authAcceptTermsRequired =>
      'Accept the terms to create an account.';

  @override
  String get authRegistrationFailed => 'Registration failed';

  @override
  String get authCreateAccount => 'Create an account';

  @override
  String get authJoinPlanner => 'Join Meal Planner and plan smarter';

  @override
  String get authDisplayName => 'Name / Username';

  @override
  String get authEnterName => 'Enter your name';

  @override
  String get authRepeatPassword => 'Repeat password';

  @override
  String get authConfirmPassword => 'Confirm your password';

  @override
  String get authPasswordsMismatch => 'The passwords do not match';

  @override
  String get authAcceptPrefix => 'I accept the ';

  @override
  String get authTerms => 'terms of use';

  @override
  String get authAnd => ' and ';

  @override
  String get authPrivacyPolicy => 'privacy policy';

  @override
  String get authAlreadyAccount => 'Already have an account?';

  @override
  String get authValidEmailRequired => 'Enter a valid email address.';

  @override
  String get authCodeSixDigits => 'The code must contain exactly 6 digits.';

  @override
  String get authNewPasswordMinEight =>
      'Your new password must contain at least 8 characters.';

  @override
  String get authPasswordChanged =>
      'Your password has been changed. Sign in with your new password.';

  @override
  String get authForgotPasswordTitle => 'Forgot password';

  @override
  String get authResetDescription =>
      'Enter your email address and we will send you a password reset code.';

  @override
  String get authEmailAddress => 'Email address';

  @override
  String get authSendCode => 'Send code';

  @override
  String authResetCodeSentTo(String email) {
    return 'If an account with the address $email exists, we have sent it a 6-digit code. Enter the code below along with your new password.';
  }

  @override
  String get authCode => 'Code';

  @override
  String get authNewPassword => 'New password';

  @override
  String get authChangePassword => 'Change password';

  @override
  String get authUseDifferentEmail => 'Use a different email';

  @override
  String get authNewCodeSent => 'A new code has been sent.';

  @override
  String get authCodeSendFailed => 'Could not send the code.';

  @override
  String get authVerifyEmailTitle => 'Verify your email';

  @override
  String authVerificationSentTo(String email) {
    return 'We have sent a 6-digit code to\n$email';
  }

  @override
  String get authVerify => 'Verify';

  @override
  String get authResendCode => 'Send code again';

  @override
  String get onboardingAllergenGluten => 'Gluten';

  @override
  String get onboardingAllergenLactose => 'Lactose';

  @override
  String get onboardingAllergenNuts => 'Nuts';

  @override
  String get onboardingAllergenEggs => 'Eggs';

  @override
  String get onboardingAllergenSoy => 'Soya';

  @override
  String get onboardingAllergenCelery => 'Celery';

  @override
  String get onboardingAllergenFish => 'Fish';

  @override
  String get onboardingAllergenShellfish => 'Shellfish';

  @override
  String get onboardingSelectStoreRequired => 'Choose your preferred shop!';

  @override
  String get onboardingPreferencesSaveFailed =>
      'Could not save your preferences';

  @override
  String get onboardingBack => 'Back';

  @override
  String get onboardingDone => 'Done!';

  @override
  String get onboardingNext => 'Next';

  @override
  String get onboardingStoreTitle => 'Where do you shop?';

  @override
  String get onboardingStoreDescription =>
      'Choose the shop you use most often. We will tailor your meal plan and products to its range.';

  @override
  String onboardingStoresLoadFailed(String error) {
    return 'Could not load shops:\n$error';
  }

  @override
  String get onboardingAllergensTitle => 'Do you have any allergies?';

  @override
  String get onboardingAllergensDescription =>
      'Choose the ingredients you cannot eat. Recipes containing these allergens will not be suggested.';

  @override
  String get onboardingDietTitle => 'Choose your diet';

  @override
  String get onboardingDietDescription =>
      'We will tailor recipe recommendations to the way you eat.';

  @override
  String get onboardingHouseholdTitle => 'How many people do you cook for?';

  @override
  String get onboardingHouseholdDescription =>
      'We will adjust ingredient quantities in recipes and portions on your shopping list automatically.';

  @override
  String get onboardingCookingForMyself => 'I only cook for myself';

  @override
  String onboardingHouseholdCount(int count) {
    return 'People in your household: $count';
  }

  @override
  String get onboardingProfileTitle => 'Your profile and goal';

  @override
  String get onboardingProfileDescription =>
      'Would you like to calculate your calorie needs and enter your weight, height and goal now? You can also do this later in your profile.';

  @override
  String get onboardingOpenCalorieCalculator => 'Open the calorie calculator';

  @override
  String get onboardingProfileOptional =>
      'This step is optional. Choose ‘Next’ to skip it.';

  @override
  String get onboardingPantryTitle => 'What is in your pantry?';

  @override
  String get onboardingPantryDescription =>
      'Add the products you already have at home to help you find recipes without extra shopping.';

  @override
  String get onboardingAddPantryProducts => 'Add products to your pantry';

  @override
  String get onboardingPantryOptional => 'You can skip this step.';

  @override
  String get onboardingPremiumOrPoints => 'PREMIUM • OR POINTS';

  @override
  String get onboardingAiTitle => 'Have a recipe? Add it in moments';

  @override
  String get onboardingAiDescription =>
      'In Recipes, choose ‘Add recipe’. AI will prepare the ingredients and steps from:';

  @override
  String get onboardingAiImport => 'Import a recipe with AI';

  @override
  String get onboardingAiPhoto => 'A photo';

  @override
  String get onboardingAiPhotoDescription =>
      'Photograph a written recipe or a finished dish.';

  @override
  String get onboardingAiText => 'Text';

  @override
  String get onboardingAiTextDescription =>
      'Paste a description or just enter the name of a dish.';

  @override
  String get onboardingAiLink => 'A link';

  @override
  String get onboardingAiLinkDescription =>
      'Paste a website address or share it from another app.';

  @override
  String get onboardingAiShareExample =>
      'For example, in TikTok choose ‘Share’ → Meal Planner Polska. Once your recipe is ready, you can ask AI to change it, for example to make it lactose-free.';

  @override
  String get onboardingAiPointCosts =>
      'Adding a recipe costs 2 points without a Premium subscription. Editing it with AI afterwards costs 1 point.';

  @override
  String get welcomeAllSet => 'You are all set!';

  @override
  String welcomePointsIntro(int points) {
    return 'Here are $points premium points to get you started — our thanks for creating an account and setting up the app.';
  }

  @override
  String get welcomeAiPointDescription =>
      'For 2 points, AI can turn a link or photo into a recipe for you.';

  @override
  String get welcomeTryNow => 'Try it now';

  @override
  String get welcomeScanFirstProduct => 'Scan your first product';

  @override
  String get welcomeAddRecipeLink => 'Add a recipe from a link';

  @override
  String get welcomeStart => 'Let\'s get started';

  @override
  String get priceCompareTitle => 'Price comparison';

  @override
  String get priceCompareSourcesTooltip => 'Price and brand sources';

  @override
  String get priceCompareRetry => 'Try again';

  @override
  String get priceCompareEmpty => 'No prices available to compare.';

  @override
  String get priceCompareIntro =>
      'We compare the cost of the whole shopping list. “~” means an estimated price. Check current prices and availability with your chosen shop.';

  @override
  String priceCompareSwitchSuccess(String storeName) {
    return 'Plan switched to $storeName';
  }

  @override
  String get priceCompareSwitchError => 'Could not switch the shop';

  @override
  String priceCompareLoadError(String error) {
    return 'Could not load the comparison: $error';
  }

  @override
  String get priceCompareCurrencyError =>
      'Prices in different currencies cannot be compared. Refresh the data and try again.';

  @override
  String get priceCompareCheapestEstimate => 'Lowest estimate';

  @override
  String get priceCompareCheapest => 'Cheapest';

  @override
  String priceCompareIncomplete(int count) {
    return 'Incomplete basket • prices missing for $count products';
  }

  @override
  String priceCompareProductCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count products',
      one: '1 product',
    );
    return '$_temp0';
  }

  @override
  String get priceCompareEstimatedPrices => 'estimated prices';

  @override
  String priceCompareSavings(String amount) {
    return 'difference up to $amount';
  }

  @override
  String get priceCompareExpandHint => 'tap to view the list';

  @override
  String priceCompareMissing(String names) {
    return 'Prices unavailable for: $names. The total only includes items with a price.';
  }

  @override
  String get priceCompareEstimate => 'estimated price';

  @override
  String get shoppingSubstituteFailed => 'Could not replace the product.';

  @override
  String shoppingSubstitutePack(String quantity, String unit) {
    return '$quantity $unit pack';
  }

  @override
  String get priceCompareUnpricedTotal => 'Total unavailable';

  @override
  String priceCompareMissingUnpriced(String names) {
    return 'Prices unavailable for: $names. The whole basket cannot be priced yet.';
  }

  @override
  String priceComparePackages(int count, String quantity, String unit) {
    return 'To buy: $count × $quantity $unit';
  }

  @override
  String priceCompareVerified(String date) {
    return 'price checked on $date';
  }

  @override
  String get priceCompareSwitchStore => 'Switch plan to this shop';

  @override
  String get priceCompareSourceTitle => 'Where do prices come from?';

  @override
  String get priceCompareSourceBody =>
      'The comparison uses product prices in the catalogue for your market. A price without a checked date is an estimate, not a confirmed shop offer. Each price shows its quantity and unit. “~” marks estimates. Confirm current prices and availability with the shop. Prices in PLN and GBP are never compared or converted.';

  @override
  String get priceCompareSourceClose => 'Got it';

  @override
  String get priceCompareUnitPack => 'pack';

  @override
  String get priceCompareUnitServing => 'serving';

  @override
  String get priceCompareUnitPiece => 'pcs';

  @override
  String get priceCompareUnitTeaspoon => 'tsp';

  @override
  String get priceCompareUnitCup => 'cup';

  @override
  String homeBatchCompleted(int count) {
    return 'Processed: $count products.';
  }

  @override
  String get homeShopFallback => 'Shop';

  @override
  String homeGreeting(String name) {
    return 'Hi, $name!';
  }

  @override
  String get homeUserFallback => 'there';

  @override
  String get homeCookingToday => 'What are we cooking today?';

  @override
  String get homeQuickActions => 'Quick actions';

  @override
  String get homePlanLoading => 'Loading your meal plan…';

  @override
  String get homePlanLoadError => 'Could not load your meal plan.';

  @override
  String get homeNextPlan => 'Your next meal plan';

  @override
  String get homeActivePlan => 'Your active meal plan';

  @override
  String get homeDetails => 'Details';

  @override
  String homePlanChip(int day, int month, int days) {
    return 'Plan $day/$month · $days days';
  }

  @override
  String get homeNutritionLoading => 'Loading calories and macros…';

  @override
  String get homeNutritionError => 'Could not load calories and macros.';

  @override
  String get homeEatenToday => 'Eaten today';

  @override
  String get homeProtein => 'Protein';

  @override
  String get homeFat => 'Fat';

  @override
  String get homeCarbsShort => 'Carbs';

  @override
  String get homeRetry => 'Try again';

  @override
  String get homeTipOfTheDay => 'TIP OF THE DAY';

  @override
  String get homeHydration => 'Hydration';

  @override
  String get homeDataLoading => 'Loading data…';

  @override
  String get homeDataError => 'Could not load the data';

  @override
  String homeWaterProgress(int amount, int goal, int percent) {
    return '$amount of $goal ml · $percent% of goal';
  }

  @override
  String get homeWeeklyContest => 'Weekly challenge';

  @override
  String get homeWeeklyContestHint =>
      'Add the most recipes this week and earn premium points — 3 for 1st place, 2 for 2nd and 1 for 3rd.';

  @override
  String homePlanStarts(String date) {
    return 'Plan starts on $date';
  }

  @override
  String homePlanDay(int day, int days) {
    return 'Day $day of $days';
  }

  @override
  String get homeViewPlan => 'View plan';

  @override
  String get homeNoPlan => 'No active meal plan';

  @override
  String get homeNoPlanHint =>
      'Generate a balanced meal plan, keep costs down and create a smart shopping list.';

  @override
  String get homeCreatePlan => 'Create a new meal plan';

  @override
  String get homeAiPointsTitle => 'You have points for an AI recipe import';

  @override
  String get homeAiPointsHint =>
      'Add a recipe from a photo, text or link — no subscription needed.';

  @override
  String get homeTryAction => 'Try it';

  @override
  String get homeBatchTitle => 'Scanning several products?';

  @override
  String get homeBatchHint =>
      'With Premium, scan the whole batch without closing the camera.';

  @override
  String get homeViewPremium => 'Explore Premium';

  @override
  String get homeAutoWeekTitle => 'Let next week plan itself';

  @override
  String get homeAutoWeekHint =>
      'Premium prepares a weekly meal plan and an optional shopping list.';

  @override
  String get homeCheckAction => 'Take a look';

  @override
  String get homeHideHint => 'Dismiss';

  @override
  String get planSelectStoreRequired =>
      'Choose a shop before generating your plan!';

  @override
  String get planStoreMarketError =>
      'Choose a shop available for your account\'s country. Refresh the shops and try again.';

  @override
  String get planKcalValidation =>
      'Enter between 800 and 6000 kcal per person per day.';

  @override
  String get planGenerateError => 'Could not generate the plan';

  @override
  String get planFreeLimitTitle => 'Free account limit';

  @override
  String get planUnderstood => 'Got it';

  @override
  String get planViewPremium => 'View Premium';

  @override
  String get planReadyTitle => 'Your plan is ready';

  @override
  String planReadyFor(int days, int people) {
    String _temp0 = intl.Intl.pluralLogic(
      people,
      locale: localeName,
      other: '$people people',
      one: '1 person',
    );
    return 'Your $days-day plan for $_temp0 is ready.';
  }

  @override
  String get planEstimatedBudget => 'Estimated minimum shopping cost';

  @override
  String get planShoppingLimitReached =>
      'Your plan is ready, but you have already used this week\'s free shopping list. Create another list next week or with Premium.';

  @override
  String get planStandardWeeklyLimit => 'Standard account: one new plan a week';

  @override
  String get planWeeklyLimitExplanation =>
      'Your limit resets on Monday. Deleting a plan does not reset it. Premium lets you create unlimited plans.';

  @override
  String get planExplorePremium => 'Explore Premium';

  @override
  String get planViewAction => 'View plan';

  @override
  String get planNewTitle => 'New meal plan';

  @override
  String get planChooseStore => 'Choose a shop';

  @override
  String get planPriceEstimateHint =>
      'The plan cost is an estimate. Check current product prices and availability with your chosen shop.';

  @override
  String planDurationTitle(int days) {
    return 'Plan duration: $days days';
  }

  @override
  String planDays(int days) {
    return '$days days';
  }

  @override
  String get planOneDay => '1 day';

  @override
  String planHouseholdTitle(int people) {
    String _temp0 = intl.Intl.pluralLogic(
      people,
      locale: localeName,
      other: '$people people',
      one: '1 person',
    );
    return 'Cooking for: $_temp0';
  }

  @override
  String get planHouseholdHint =>
      'From 1 to 8 people. Taken from your profile by default; changes only apply to this plan.';

  @override
  String get planMealTypes => 'Meal types';

  @override
  String get planDailyCalories => 'Daily calorie goal';

  @override
  String get planCaloriesField => 'Target kcal / day / person';

  @override
  String get planCaloriesExample => 'e.g. 2000';

  @override
  String get planCaloriesHint =>
      'Uses your calculator goal; defaults to 2000 kcal if none is saved.';

  @override
  String get planBudgetOptional => 'Maximum budget (optional)';

  @override
  String get planBudgetField => 'Maximum budget';

  @override
  String get planBudgetExample => 'e.g. 150.00';

  @override
  String get planIncludePantry => 'Include pantry';

  @override
  String get planPantryHint =>
      'Products you already have appear at the end of the list for £0. Any missing quantity is still added to your shopping.';

  @override
  String get planIngredientPreferences => 'Likes / Dislikes';

  @override
  String get planIngredientPreferencesHint =>
      'Premium · one tailored meal a day';

  @override
  String get planGenerating => 'Generating...';

  @override
  String get planGenerate => 'Generate plan!';

  @override
  String get planGeneratingTitle => 'Putting together your meal plan...';

  @override
  String get planGeneratingHint =>
      'We reuse ingredients across meals to reduce your shopping cost.';

  @override
  String get planActivated =>
      'Plan confirmed! Your shopping list has been generated.';

  @override
  String get planGenericError => 'Something went wrong';

  @override
  String planSwapTitle(String recipeName) {
    return 'Replace: $recipeName';
  }

  @override
  String get planSwapSearch => 'Find a dish';

  @override
  String get planSwapSearchHint => 'Enter a recipe name';

  @override
  String get planSwapLoadError => 'Could not load recipes. Please try again.';

  @override
  String get planSwapNoAlternatives => 'No other dishes in this category';

  @override
  String get planSwapNoSearchResults => 'No dishes found with this name';

  @override
  String get planSwapSuccess => 'Recipe replaced';

  @override
  String get planSwapError => 'Could not replace the recipe';

  @override
  String get planFinishedTitle => 'Plan finished';

  @override
  String get planArchivePremiumRequired =>
      'Archive previews are available with Premium.';

  @override
  String get planFinishedHint => 'This plan has finished.';

  @override
  String get planOpenArchive => 'Open archive';

  @override
  String get planCreateNew => 'Create a new plan';

  @override
  String get planViewTitle => 'Meal plan';

  @override
  String get planNotFound => 'No meal plan found. Generate a new plan.';

  @override
  String get planStoreFallback => 'Shop';

  @override
  String get planDeleteTitle => 'Delete plan';

  @override
  String get planDeleteQuestion =>
      'Are you sure you want to delete this meal plan? On a standard account, deleting a plan does not reset the limit of one new plan a week.';

  @override
  String get planCancel => 'Cancel';

  @override
  String get planDeleteError => 'Could not delete the plan';

  @override
  String get planDelete => 'Delete';

  @override
  String planDay(int day) {
    return 'Day $day';
  }

  @override
  String get planResumeArchive => 'Archive · resume plan';

  @override
  String get planChangeSettings => 'Change settings';

  @override
  String get planActivate => 'Confirm plan';

  @override
  String get planGoShopping => 'Go to shopping';

  @override
  String get manualRecipeDiscardTitle => 'Discard changes?';

  @override
  String get manualRecipeUnsaved =>
      'The recipe details you entered have not been saved yet.';

  @override
  String get manualRecipeStay => 'Stay';

  @override
  String get manualRecipeDiscard => 'Discard';

  @override
  String get manualRecipeNutritionRequired =>
      'This product is missing nutritional values. Choose another result or add the product to the database with the details from its label.';

  @override
  String get manualRecipeIngredientRequired => 'Add at least one ingredient';

  @override
  String get manualRecipeStepRequired => 'Add at least one preparation step';

  @override
  String get manualRecipeTitle => 'Add a recipe manually';

  @override
  String get manualRecipeName => 'Recipe name';

  @override
  String get manualRecipeNameRequired => 'Enter a name';

  @override
  String get manualRecipeDescription => 'Short description (optional)';

  @override
  String get manualRecipeMealType => 'Meal type';

  @override
  String get manualRecipePreparationMinutes => 'Preparation (min)';

  @override
  String get manualRecipeCookingMinutes => 'Cooking (min)';

  @override
  String get manualRecipeServings => 'Servings';

  @override
  String get manualRecipeIngredients => 'Ingredients';

  @override
  String get manualRecipeNoIngredients => 'No ingredients added';

  @override
  String get manualRecipeSteps => 'Preparation steps';

  @override
  String get manualRecipeAddStep => 'Add a step';

  @override
  String get manualRecipeStepHint => 'Describe this step...';

  @override
  String get manualRecipeSubmitToCatalogue => 'Submit to the shared catalogue';

  @override
  String get manualRecipePublicHint =>
      'Once approved by an administrator, it will be visible to everyone and count towards the weekly competition.';

  @override
  String get manualRecipeSave => 'Save recipe';

  @override
  String get manualRecipeChooseIngredient => 'Choose an ingredient';

  @override
  String get manualRecipeIngredientSearch =>
      'Search the catalogue and product database...';

  @override
  String get manualRecipeIngredientSearchHint =>
      'Enter at least 2 characters to find an ingredient.';

  @override
  String get manualRecipeIngredientNotFound =>
      'Product not found. First add it to the product database with the nutritional values from its label.';

  @override
  String get manualRecipeLabelRequired => 'Label details required';

  @override
  String get manualRecipeNutritionMissing =>
      'Nutritional values are incomplete';

  @override
  String get aiRecipePhotoLoadFailed => 'Could not load the photo';

  @override
  String get aiRecipeChooseGallery => 'Choose from gallery';

  @override
  String get aiRecipeServerUnavailable =>
      'AI import is not available on the server yet. Complete the backend deployment on Render.';

  @override
  String get aiRecipePremiumOrPointsTitle => 'You need Premium or points';

  @override
  String get aiRecipeCancel => 'Cancel';

  @override
  String get aiRecipeBuyPoints => 'Buy points';

  @override
  String get aiRecipeBackToApp => 'Back to the app';

  @override
  String get aiRecipeTitle => 'Add a recipe with AI';

  @override
  String get aiRecipePhoto => 'Photo';

  @override
  String get aiRecipeLink => 'Link';

  @override
  String get aiRecipeAccepting => 'Submitting your recipe...';

  @override
  String get aiRecipeAcceptingHint =>
      'You can get back to using the app in a moment.';

  @override
  String get aiRecipePreparing => 'Your recipe is being prepared';

  @override
  String get aiRecipeReady => 'Your recipe is ready';

  @override
  String get aiRecipeRecognitionFailed => 'Could not recognise the recipe';

  @override
  String get aiRecipeBackgroundHint =>
      'You can leave this screen. We will let you know the result in the app and, if push notifications are enabled, on your phone too.';

  @override
  String get aiRecipeFindInMine =>
      'You can also find it in the My recipes tab.';

  @override
  String get aiRecipeRetrySentence => 'Please try again.';

  @override
  String get aiRecipeOpen => 'Open recipe';

  @override
  String get aiRecipeEditOnePoint => 'Adjust with AI · 1 pt';

  @override
  String get aiRecipeAddAnother => 'Add another recipe';

  @override
  String get aiRecipePasteTextTitle => 'Paste your recipe text';

  @override
  String get aiRecipeTextDescription =>
      'Paste a recipe from your notes, a message or a website — AI will recognise its ingredients and steps. Or just enter a dish name (such as \"chicken soup\" or \"lasagne\") and AI will create a complete recipe from scratch.';

  @override
  String get aiRecipeTextHint =>
      'e.g. \"chicken soup\", or a full recipe with ingredients and steps...';

  @override
  String get aiRecipeRecognise => 'Recognise recipe';

  @override
  String get aiRecipePhotoTitle => 'Take a recipe photo';

  @override
  String get aiRecipePhotoDescription =>
      'Photograph a recipe card, a cookbook page or a finished dish — AI will then estimate a likely recipe.';

  @override
  String get aiRecipeTapAddPhoto => 'Tap to add a photo';

  @override
  String get aiRecipePasteLinkTitle => 'Paste a recipe link';

  @override
  String get aiRecipeLinkDescription =>
      'Food blog, TikTok, Instagram — AI will try to recognise the recipe from the page content. If the recipe is only spoken in a video and not included in its description, recognition may not work.';

  @override
  String get aiRecipePremiumFeature => 'Premium feature';

  @override
  String get aiRecipePremiumDescription =>
      'Add your own recipes with AI from text or a photo with an active Premium subscription — or for 2 premium points without a subscription.';

  @override
  String get aiRecipePremiumHint =>
      'Explore the other Premium features or buy a points pack.';

  @override
  String get shoppingStoresLoadFailed => 'Could not load the stores.';

  @override
  String get shoppingChooseStore => 'Choose a store for the new list';

  @override
  String get shoppingCreateFailed => 'Could not create the shopping list.';

  @override
  String get shoppingShareTitle => 'Share shopping list';

  @override
  String get shoppingShareHint =>
      'Enter the username of the person you want to share the list with. They need a Meal Planner Polska account and must accept the invitation before they can view the list.';

  @override
  String get shoppingUsername => 'Username';

  @override
  String get shoppingSendInvite => 'Send invitation';

  @override
  String shoppingInviteSent(String nickname) {
    return 'Invitation sent to $nickname';
  }

  @override
  String get shoppingMergeTitle => 'Merge shopping lists';

  @override
  String shoppingMergeHint(String storeName) {
    return 'Choose the $storeName lists you want to merge with the current list. The previous lists will be removed from Shopping, but your meal plans will stay unchanged.';
  }

  @override
  String shoppingListNumber(int number) {
    return 'List $number';
  }

  @override
  String shoppingListDate(int day, int month, int count) {
    return '$day/$month · $count items';
  }

  @override
  String get shoppingMerge => 'Merge';

  @override
  String get shoppingMergeSuccess => 'Lists merged';

  @override
  String get shoppingMergeFailed => 'Could not merge the lists';

  @override
  String get shoppingChooseSubstitute => 'Choose a substitute';

  @override
  String get shoppingNoSubstitutes => 'No available alternatives in this shop.';

  @override
  String get shoppingCatalogueAlternatives => 'Catalogue alternatives';

  @override
  String get shoppingStoreAlternatives => 'Selected shop offers';

  @override
  String get shoppingCatalogueAvailability =>
      'Check shop availability — estimated price.';

  @override
  String shoppingSubstituteFor(String name) {
    return 'For product: $name';
  }

  @override
  String get shoppingPriceUnknown => 'Price unavailable';

  @override
  String shoppingSubstituteChanged(String name) {
    return 'Replaced with: $name';
  }

  @override
  String get shoppingListTitle => 'Shopping list';

  @override
  String get shoppingCreateAndAdd => 'Create a list and add a product';

  @override
  String get shoppingAddProduct => 'Add a product to the list';

  @override
  String get shoppingInvites => 'Invitations';

  @override
  String get shoppingShare => 'Share';

  @override
  String get shoppingRefresh => 'Refresh';

  @override
  String get shoppingDeleteList => 'Delete list';

  @override
  String get shoppingMergeLists => 'Merge lists';

  @override
  String get shoppingCompare => 'Compare';

  @override
  String get shoppingExport => 'Export';

  @override
  String get shoppingInPantry => 'In your pantry';

  @override
  String get shoppingOther => 'Other';

  @override
  String shoppingPantryCount(int count, String amount) {
    return 'You already have $count items · $amount';
  }

  @override
  String shoppingBoughtCount(int checked, int total) {
    return '$checked of $total bought';
  }

  @override
  String shoppingDeleteTitle(int number) {
    return 'Delete list $number?';
  }

  @override
  String shoppingDeleteHint(String storeName) {
    return 'The shopping list for $storeName and all its items will be permanently deleted. Your meal plan will stay unchanged. Deleting a list does not reset the weekly limit on a standard account.';
  }

  @override
  String get shoppingDelete => 'Delete';

  @override
  String get shoppingDeleted => 'List deleted';

  @override
  String get shoppingDeleteFailed => 'Could not delete the list';

  @override
  String get shoppingHaveEverything => 'You have everything on the list';

  @override
  String get shoppingCompleteHint =>
      'Move the products you bought to your pantry so the app can suggest recipes using what you have at home.';

  @override
  String get shoppingMovePantry => 'Move to pantry';

  @override
  String get shoppingCompleteWithoutPantry => 'Finish without moving';

  @override
  String get shoppingCompleteFailed => 'Could not complete the list';

  @override
  String shoppingCompleteMoved(int count) {
    return 'Shopping complete. $count products were moved to your pantry.';
  }

  @override
  String get shoppingCompleteSuccess => 'Shopping complete.';

  @override
  String shoppingProgressCount(int checked, int total) {
    return '$checked of $total items';
  }

  @override
  String get shoppingEverythingBought => 'Everything bought';

  @override
  String shoppingUnknownRemaining(String amount) {
    return 'From ~$amount · some prices unavailable';
  }

  @override
  String shoppingRemaining(String amount) {
    return 'Left to pay: ~$amount';
  }

  @override
  String shoppingBasketTotal(String basket, String total) {
    return 'in basket: $basket of ~$total';
  }

  @override
  String get shoppingItemSaveFailed => 'Could not save the item.';

  @override
  String shoppingPackageBuy(int count, String quantity, String unit) {
    return 'Buy: $count × $quantity $unit';
  }

  @override
  String get shoppingSubstituteBadge => 'SUBSTITUTE';

  @override
  String shoppingPromotionBadge(int percent) {
    return 'OFFER -$percent%';
  }

  @override
  String get shoppingEmptyTitle => 'No active shopping list';

  @override
  String get shoppingEmptyHint =>
      'Tap +, choose a store and add your first product. You can also generate a list from a meal plan.';

  @override
  String get shoppingListInvites => 'List invitations';

  @override
  String shoppingEstimatedTotal(String amount) {
    return 'Estimated cost: $amount';
  }

  @override
  String get shoppingFriendReadOnly => 'Friend\'s list preview — read-only';

  @override
  String get priceCompareListSwitchStore => 'Switch list to this shop';

  @override
  String priceCompareListSwitchSuccess(String storeName) {
    return 'List switched to $storeName';
  }

  @override
  String get shoppingNoItems => 'No items on the list';

  @override
  String get productsTitle => 'Products';

  @override
  String get productsPriceSources => 'Price and brand sources';

  @override
  String get productsShopTab => 'Shop';

  @override
  String get productsCatalogueTab => 'Catalogue';

  @override
  String get productsMineTab => 'My products';

  @override
  String get productsScan => 'Scan barcode';

  @override
  String get productsBatchScan => 'Scan multiple products';

  @override
  String get productsBrandSearch => 'Search for a product or brand…';

  @override
  String get productsClear => 'Clear';

  @override
  String get productsRetry => 'Try again';

  @override
  String get productsNotFound => 'No products found.';

  @override
  String get productsShowMore => 'Show more';

  @override
  String get productsSearch => 'Search for a product...';

  @override
  String get productsNoShop => 'No shop selected';

  @override
  String get productsChooseShop =>
      'To browse products and prices, select a shop in your profile or from the list above.';

  @override
  String get productsError => 'Something went wrong';

  @override
  String get productsEmpty => 'No products';

  @override
  String get productsChangeSearch => 'Try a different search.';

  @override
  String get productsUnknown => 'Unknown product';

  @override
  String get productsUnavailable => 'unavailable';

  @override
  String get productsDeleteTitle => 'Delete product?';

  @override
  String get productsCancel => 'Cancel';

  @override
  String get productsDelete => 'Delete';

  @override
  String get productsAdd => 'Add product';

  @override
  String get productsNothingSubmitted =>
      'You haven\'t submitted any products yet.';

  @override
  String get productsSubmitHint =>
      'Tap “Add product” below to submit something\nmissing from the catalogue.';

  @override
  String get productsApproved => 'In catalogue';

  @override
  String get productsRejected => 'Rejected';

  @override
  String get productsPending => 'Awaiting approval';

  @override
  String get productsEdit => 'Edit';

  @override
  String get productsEstimatedPrice => 'estimated price';

  @override
  String get productsUnknownQuantity => '/ quantity unknown';

  @override
  String get diaryTitle => 'Calorie diary';

  @override
  String get diaryLoadError => 'Couldn\'t load your diary.';

  @override
  String get diaryPreviousDay => 'Previous day';

  @override
  String get diaryNextDay => 'Next day';

  @override
  String get diaryToday => 'Back to today';

  @override
  String get diaryRemainingKcal => 'kcal remaining';

  @override
  String get diaryActivity => 'Add activity';

  @override
  String get diaryActivityName => 'What did you do?';

  @override
  String get diaryActivityHint => 'e.g. running, cycling, gym';

  @override
  String get diaryBurnedCalories => 'Calories burned';

  @override
  String get diaryOptionalDuration => 'Duration (optional)';

  @override
  String get diaryActivityInvalid =>
      'Enter an activity name and calories burned.';

  @override
  String get diaryRecipeNoIngredients =>
      'This recipe has no ingredients to edit.';

  @override
  String get diaryUpdatedNutrition => 'Entry nutrition updated';

  @override
  String get diarySaveError => 'Couldn\'t save your changes';

  @override
  String get diaryEditAmount => 'Edit amount';

  @override
  String get diaryInvalidAmount => 'Enter a valid amount';

  @override
  String get diarySave => 'Save';

  @override
  String get diaryAmountUpdated => 'Amount and nutrition updated';

  @override
  String get diaryAmountSaveError => 'Couldn\'t save the amount';

  @override
  String get diaryLoadingWater => 'Loading hydration…';

  @override
  String get diaryWaterError => 'Couldn\'t load hydration.';

  @override
  String get diaryHydration => 'Hydration';

  @override
  String get diaryUndoGlass => 'Undo a glass';

  @override
  String get diaryWaterQuestion => 'How much did you drink?';

  @override
  String get diaryWaterHint => 'e.g. 300';

  @override
  String get diaryWaterInvalid => 'Enter the number of millilitres.';

  @override
  String get diaryGlass => 'Glass';

  @override
  String get diaryBottle => 'Bottle';

  @override
  String get diaryProtein => 'Protein';

  @override
  String get diaryCarbs => 'Carbs';

  @override
  String get diaryFat => 'Fat';

  @override
  String get diaryMacroTargets => 'Suggested split for your calorie goal';

  @override
  String get diaryNoMeals => 'No meals logged for this day.';

  @override
  String get diaryDeleteMeal => 'Delete meal?';

  @override
  String get diaryRemoveEntry => 'Remove from diary';

  @override
  String get amountPositive => 'Enter an amount greater than zero';

  @override
  String get amountClose => 'Close';

  @override
  String get amountQuick => 'Quick selection';

  @override
  String get amountQuickHint => 'Tap an option to select it straight away.';

  @override
  String get amountCustom => 'Custom amount';

  @override
  String get amountUnit => 'Unit';

  @override
  String get amountQuantity => 'Amount';

  @override
  String get amountChoose => 'Select amount';

  @override
  String get amountApproximate => 'approx. ';

  @override
  String get measurePack => 'pack';

  @override
  String get measureServing => 'serving';

  @override
  String get measurePiece => 'item';

  @override
  String get measureTeaspoon => 'teaspoon';

  @override
  String get measureGlass => 'glass';

  @override
  String get measureGrams => 'grams';

  @override
  String get measureMillilitres => 'millilitres';

  @override
  String get nutritionMissing => 'Nutrition unavailable';

  @override
  String get recipeNutritionEstimated =>
      'Approximate values: some ingredients were estimated. They may differ from the product label.';

  @override
  String get recipeNutritionPartial =>
      'Incomplete data. ≥ shows only the sum of known values, not the meal\'s full nutrition.';

  @override
  String get recipeNutritionNeedsDetails =>
      'This recipe has missing nutrition. Complete the ingredient details in the recipe or enter the meal\'s nutrition manually in your Diary.';

  @override
  String productsProcessed(int count) {
    return 'Processed: $count products.';
  }

  @override
  String productsLoadFailed(String error) {
    return 'Couldn\'t load products: $error';
  }

  @override
  String productsDeleteMessage(String name) {
    return '“$name” will be removed from your submissions. This cannot be undone.';
  }

  @override
  String productsShopBrand(String brand) {
    return 'Shop brand: $brand';
  }

  @override
  String productsBrand(String brand) {
    return 'Product brand: $brand';
  }

  @override
  String productsCheckedOn(String date) {
    return 'price checked $date';
  }

  @override
  String diaryTodayDate(String date) {
    return 'Today, $date';
  }

  @override
  String diaryActivityCalories(String calories) {
    return '+$calories from activity';
  }

  @override
  String diaryWaterProgress(String amount, String goal) {
    return '$amount of $goal ml';
  }

  @override
  String diaryDeleteMessage(String name) {
    return '“$name” will be removed from your diary.';
  }

  @override
  String diaryAmountTimes(String amount) {
    return 'Amount: $amount×';
  }

  @override
  String diaryPortionSize(String amount, String unit) {
    return '1 serving = $amount $unit';
  }

  @override
  String nutritionMacroLine(
    String kcal,
    String protein,
    String fat,
    String carbs,
  ) {
    return '$kcal kcal  •  P $protein g  •  F $fat g  •  C $carbs g';
  }

  @override
  String get productFormEdit => 'Edit product';

  @override
  String get productFormAdd => 'Add your product';

  @override
  String get productFormVisibility =>
      'You can use this product straight away. Other users will see it after an administrator approves it.';

  @override
  String get productFormManualAfterScan =>
      'You can still enter the details manually. The barcode has been kept.';

  @override
  String get productFormCatalogFilled =>
      'Found in the catalogue — details filled in automatically.';

  @override
  String get productFormScanFilled =>
      'Product found — name, brand and nutrition filled in.';

  @override
  String get productFormEditSaved =>
      'Saved. An administrator will review the changes again.';

  @override
  String get productFormAdded =>
      'Product added. You can use it now; others will see it once an administrator approves it.';

  @override
  String get productFormAlreadyExists =>
      'This product is already in the catalogue. You do not need to add it again.';

  @override
  String get productFormCloseExisting => 'Close — product already in catalogue';

  @override
  String get productFormName => 'Product name *';

  @override
  String get productFormNameHint => 'Enter a name or choose a suggestion';

  @override
  String get productFormNameRequired => 'Enter a product name';

  @override
  String get productFormBrandOptional => 'Brand (optional)';

  @override
  String get productFormBrand => 'Brand';

  @override
  String get productFormPrice => 'Price seen in the shop (optional)';

  @override
  String get productFormPriceError =>
      'Enter a valid price (over 0, up to 10,000).';

  @override
  String get productFormUnit => 'Unit';

  @override
  String get productFormPack => 'Whole pack size';

  @override
  String get productFormPackExample => 'e.g. 150';

  @override
  String get productFormPackHelp =>
      'Enter the net weight or volume of the whole pack, not a serving. If it is unknown, leave this blank — the pack option will not be shown.';

  @override
  String get productFormPackError =>
      'Enter a pack size over 0 and up to 100,000 g/ml, or leave it blank.';

  @override
  String get productFormNutritionHelp =>
      'Without complete nutrition, you can still use the product on a shopping list. Complete the nutrition before adding it to your food diary.';

  @override
  String get productFormCalories => 'Calories';

  @override
  String get productFormProtein => 'Protein';

  @override
  String get productFormFat => 'Fat';

  @override
  String get productFormCarbs => 'Carbs';

  @override
  String get productFormShops => 'Which shops sell it? (optional)';

  @override
  String get productFormShopsHelp =>
      'You can select several. It will appear in these shops only after approval.';

  @override
  String get productFormSaveChanges => 'Save changes';

  @override
  String get productFormSave => 'Add product';

  @override
  String get productFormNumberError => 'Enter a valid number.';

  @override
  String get productFormRequestFailed =>
      'Could not save the product. Your details have been kept — please try again.';

  @override
  String get productLabelTitle => 'Add missing product details';

  @override
  String get productLabelTakePhoto => 'Take a photo';

  @override
  String get productLabelGallery => 'Choose from gallery';

  @override
  String get productLabelBothPhotos =>
      'Add both photos: the front and the nutrition label.';

  @override
  String get productLabelNameError =>
      'Check the product name (2–300 characters).';

  @override
  String get productLabelReading => 'Reading the label…';

  @override
  String get productLabelRead => 'Read label';

  @override
  String get productLabelFront => 'Front of pack';

  @override
  String get productLabelNutrition => 'Nutrition label';

  @override
  String get productLabelReview => 'Check the details before saving';

  @override
  String get productLabelConfirm => 'Confirm and save';

  @override
  String get productLabelMissingNutrition =>
      'Enter kcal, protein, fat and carbs per 100 g/ml.';

  @override
  String get productLabelReadFailed =>
      'Could not read the label. Your photos have been kept — please try again.';

  @override
  String get productLabelPhotoFailed =>
      'Could not open the photo. Check camera or gallery access and try again.';

  @override
  String get productFormBrandError =>
      'The brand can have up to 200 characters.';

  @override
  String productFormScanned(String code) {
    return 'Scanned: $code (change)';
  }

  @override
  String productFormTypicalPrice(String minimum, String maximum) {
    return 'Typical price range: $minimum–$maximum PLN';
  }

  @override
  String productFormReward(int points) {
    return 'Product added • +$points Premium point';
  }

  @override
  String productFormBalance(int points) {
    return ' • balance: $points';
  }

  @override
  String productFormNutrition(String unit) {
    return 'Nutrition per 100 $unit (optional)';
  }

  @override
  String productLabelIntro(String code) {
    return 'Details are missing for barcode $code. Two clear photos can fill them in without typing everything.';
  }

  @override
  String productLabelPer100(String unit) {
    return 'Values per 100 $unit';
  }

  @override
  String productFormNumberRange(String maximum) {
    return 'Enter a number from 0 to $maximum.';
  }

  @override
  String get productFormChooseUnit =>
      'Choose grams or millilitres for the pack size.';

  @override
  String get productFormLookupFailed =>
      'Could not look up the product. The barcode has been kept — you can enter the details manually.';

  @override
  String get detailTikTokFailed => 'Could not open the TikTok profile.';

  @override
  String get detailAiUpdated => 'Your recipe has been updated with AI.';

  @override
  String get detailAiAction => 'Adjust recipe with AI · 1 point';

  @override
  String get detailRecipeAuthor => 'the recipe author';

  @override
  String get detailTime => 'Time';

  @override
  String get detailServings => 'Servings';

  @override
  String get detailNutrition => 'Nutrition';

  @override
  String get detailPerServing => 'per serving';

  @override
  String get detailChange => 'Change';

  @override
  String get detailLoading => 'Loading ingredients and method…';

  @override
  String get detailRetry => 'Try loading the details again';

  @override
  String get detailTemporary => 'Temporary variation';

  @override
  String get detailTemporaryHelp =>
      'The original recipe has not changed. Creating a shopping list will save this version in My recipes so the list uses the ingredients and amounts shown here. Saving recalculates the nutrition.';

  @override
  String get detailSaveVariant => 'Save variation to Mine';

  @override
  String get detailUndo => 'Undo changes';

  @override
  String get detailIngredient => 'Ingredient';

  @override
  String get detailPastaTitle => 'Tip: measure pasta without scales';

  @override
  String get detailPastaHelp =>
      'Hold dry pasta between two fingers in a circle roughly the diameter of a Polish 5 zł coin — about one serving (80–100 g) per person.';

  @override
  String get detailMethod => 'Method';

  @override
  String get detailAlsoAdd => 'You could also add';

  @override
  String get detailSeasoningHelp => 'optional seasonings for extra flavour';

  @override
  String get detailFiber => 'Fibre';

  @override
  String get variantTitle => 'Edit ingredients';

  @override
  String get variantHelp =>
      'These changes are temporary. The original recipe will stay unchanged.';

  @override
  String get variantAlreadyAdded => 'This product is already on the list.';

  @override
  String get variantRemove => 'Remove ingredient';

  @override
  String get variantApply => 'Apply temporarily';

  @override
  String variantQuantityError(int maximum) {
    return 'Enter an amount greater than zero, up to $maximum.';
  }

  @override
  String get aiEditTitle => 'Adjust recipe with AI';

  @override
  String get aiEditPromptLabel => 'What would you like to change or add?';

  @override
  String get aiEditPromptHint =>
      'e.g. replace chicken with tofu and update the method';

  @override
  String get aiEditBuyPoints => 'Buy points';

  @override
  String get aiEditSubmit => 'Update recipe · 1 point';

  @override
  String get detailFavoriteError => 'Could not update your favourites';

  @override
  String get detailRemoveFavorite => 'Remove from favourites';

  @override
  String get detailAddFavorite => 'Add to favourites';

  @override
  String get detailDeleteTitle => 'Delete recipe?';

  @override
  String get detailDeletePublicHelp =>
      'This recipe is public. Deleting it also removes it from shopping lists and plans that use it. This cannot be undone.';

  @override
  String get detailDeleteHelp => 'This cannot be undone.';

  @override
  String get detailDeleteFailed => 'Could not delete the recipe';

  @override
  String get detailDelete => 'Delete recipe';

  @override
  String get detailPublishTitle => 'Publish recipe?';

  @override
  String get detailPublishHelp =>
      'An administrator will review your recipe. Once approved, it will be visible to other users.';

  @override
  String get detailPublishSubmit => 'Publish';

  @override
  String get detailPublishSent =>
      'Recipe submitted — awaiting administrator approval.';

  @override
  String get detailPublishFailed => 'Could not publish the recipe.';

  @override
  String get detailPublish => 'Publish recipe';

  @override
  String get detailShopping => 'Shopping list for this dish';

  @override
  String get detailChooseShop => 'Choose a shop in your profile first';

  @override
  String get detailPhotoSent =>
      'Thank you! Your photo will appear once an administrator approves it.';

  @override
  String get detailPhotoReplaceHelp =>
      'This recipe already has a photo. If yours is approved, it will replace the current one.';

  @override
  String get detailPhotoSending => 'Sending…';

  @override
  String get detailPhotoReplace => 'Suggest another photo';

  @override
  String get detailPhotoAdd => 'Add photo';

  @override
  String get detailAiPhoto => 'Illustrative image generated by AI';

  @override
  String detailSavedVariant(String name) {
    return 'Saved to Mine as “$name”.';
  }

  @override
  String detailAddedBy(String name) {
    return 'Added by $name';
  }

  @override
  String variantAmount(String unit) {
    return 'Amount ($unit)';
  }

  @override
  String variantBrand(String brand) {
    return 'Brand: $brand';
  }

  @override
  String aiEditIntro(String name) {
    return 'Describe what to change in “$name”. For example, ask for a dairy-free version or add a particular ingredient.';
  }

  @override
  String aiEditCost(int points) {
    return 'A successful update costs 1 Premium point. Your balance: $points points.';
  }

  @override
  String detailExistingLists(int count, String word) {
    return 'You already have $count $word — add to an existing list or create a new one.';
  }

  @override
  String detailListItems(int count) {
    return '$count items';
  }

  @override
  String get variantSearchHint => 'Enter a product name';

  @override
  String get detailAddToList => 'Add to shopping list';

  @override
  String get detailCreateList => 'Create a new list';

  @override
  String get productsOnlineCatalogue =>
      'Online catalogue — local availability may vary';

  @override
  String get productsGenericFood => 'Generic food — check shop availability';

  @override
  String get productsNationalAverage => 'UK average, not a shop price';

  @override
  String get productsPriceUnavailable => 'Price unavailable';

  @override
  String get commentsLoadFailed => 'Could not load comments';

  @override
  String get commentsPhotoFailed => 'Could not load the photo';

  @override
  String get commentsCamera => 'Take a photo';

  @override
  String get commentsGallery => 'Choose from gallery';

  @override
  String get commentsDeleteTitle => 'Delete this comment?';

  @override
  String get commentsDeleteBody => 'This cannot be undone.';

  @override
  String get commentsCancel => 'Cancel';

  @override
  String get commentsDelete => 'Delete';

  @override
  String get commentsDeleteFailed => 'Could not delete the comment';

  @override
  String get commentsLikeFailed => 'Could not save your like';

  @override
  String get commentsJustNow => 'just now';

  @override
  String get commentsTitle => 'Comments and photos';

  @override
  String get commentsFirst => 'Be the first to comment on this recipe';

  @override
  String get commentsHint => 'Share a thought or a cooking tip…';

  @override
  String get commentsPhoto => 'Add photo';

  @override
  String get commentsAdd => 'Add';

  @override
  String get commentsDeleteTooltip => 'Delete comment';

  @override
  String get commentsModerateTooltip => 'Delete comment (moderation)';

  @override
  String get reportTitle => 'Report content';

  @override
  String get reportReason => 'Reason for reporting:';

  @override
  String get reportDetails => 'Additional details (optional)';

  @override
  String get reportSend => 'Report';

  @override
  String get reportThanks => 'Thank you. Our team will review your report.';

  @override
  String get reportFailed => 'Could not send your report. Please try again.';

  @override
  String get reportSpam => 'Spam or advertising';

  @override
  String get reportInappropriate => 'Inappropriate content';

  @override
  String get reportHarassment => 'Harassment or hate speech';

  @override
  String get reportMisinformation => 'False information';

  @override
  String get reportOther => 'Another reason';

  @override
  String get blockTitle => 'Block this user?';

  @override
  String get blockAction => 'Block';

  @override
  String get blockAuthor => 'Block author';

  @override
  String get blockFailed => 'Could not block the user.';

  @override
  String commentsMinutes(int count) {
    return '$count min ago';
  }

  @override
  String commentsHours(int count) {
    return '$count hr ago';
  }

  @override
  String commentsDays(int count) {
    return '$count days ago';
  }

  @override
  String commentsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count comments',
      one: '1 comment',
    );
    return '$_temp0';
  }

  @override
  String blockBody(String name) {
    return 'You will no longer see recipes or comments from \"$name\". You can unblock them at any time in Profile → Blocked users.';
  }

  @override
  String blockDone(String name) {
    return '\"$name\" has been blocked.';
  }

  @override
  String get profileTitle => 'Profile';

  @override
  String get profileNone => 'Not set';

  @override
  String get profileShop => 'Shop';

  @override
  String get profileUser => 'User';

  @override
  String get profileExpiryToday => 'Your subscription expires today';

  @override
  String get profileHealth => 'Health and goals';

  @override
  String get profileCommunity => 'Community';

  @override
  String get profileFriends => 'Friends';

  @override
  String get profileFriendsHint => 'Invitations, recipes and shopping lists';

  @override
  String get profileSubscription => 'Subscription';

  @override
  String get profileUpgrade => 'Get Premium';

  @override
  String get profileUpgradeHint =>
      'Automatic weekly plans, batch scanning and unlimited lists';

  @override
  String get profileCompare => 'Compare plans';

  @override
  String get profilePreferences => 'Preferences';

  @override
  String get profilePreferredShop => 'Preferred shop';

  @override
  String get profileDiet => 'Diet';

  @override
  String get profileHousehold => 'People in your household';

  @override
  String get profileLikes => 'Likes / Dislikes';

  @override
  String get profileArchive => 'Plan archive';

  @override
  String get profileArchiveHint => 'Premium · view and reuse';

  @override
  String get profileDarkMode => 'Dark mode';

  @override
  String get profilePrivacy => 'Account and privacy';

  @override
  String get profileAddUsername => 'Add a username';

  @override
  String get profileLogout => 'Sign out';

  @override
  String get profileBlocked => 'Blocked users';

  @override
  String get profileDelete => 'Delete account';

  @override
  String get profileAdmin => 'Administrator panel';

  @override
  String get profileChooseShop => 'Choose a shop';

  @override
  String get profileHealthTitle => 'Weight, height and calorie goal';

  @override
  String get profileHealthHint =>
      'Enter your details to calculate BMI and calorie needs';

  @override
  String get profileBmiLow => 'underweight';

  @override
  String get profileBmiNormal => 'healthy weight';

  @override
  String get profileBmiHigh => 'overweight';

  @override
  String get profileBmiObese => 'obesity';

  @override
  String get profileMeasurementDate => 'Measurement date';

  @override
  String get profileSelect => 'Select';

  @override
  String get profileWeightInvalid =>
      'Enter a valid weight between 0.1 and 400 kg.';

  @override
  String get profileWeightTitle => 'Weight tracking';

  @override
  String get profileWeightHint =>
      'Save a measurement for the selected day. Saving again updates the entry for that date.';

  @override
  String get profileWeightOptional => 'Weight (optional)';

  @override
  String get profileSaveMeasurement => 'Save measurement';

  @override
  String get profileStatistics => 'Statistics';

  @override
  String get profilePhotoFailed => 'Could not save the photo';

  @override
  String get profileAvatar => 'Choose an avatar';

  @override
  String get profileGallery => 'From gallery';

  @override
  String get profileAvatarOr => 'or choose an icon';

  @override
  String get profileFemale => 'Woman';

  @override
  String get profileMale => 'Man';

  @override
  String get profileNicknameTitle => 'Change nickname';

  @override
  String get profileNickname => 'Nickname';

  @override
  String get profileSave => 'Save';

  @override
  String get profileNicknameSaved => 'Nickname updated.';

  @override
  String get profileNicknameFailed => 'Could not change your nickname.';

  @override
  String get profileTikTokFailed => 'Could not open the TikTok profile.';

  @override
  String get profileTikTokAdd => 'Add TikTok';

  @override
  String get profileTikTokEdit => 'Edit TikTok';

  @override
  String get profileTikTokUsername => 'TikTok username';

  @override
  String get profileTikTokPlaceholder => '@yourname';

  @override
  String get profileTikTokHelp => 'You can also paste the full profile link.';

  @override
  String get profileTikTokInvalid =>
      'Use 2–24 characters: letters, numbers, full stops or underscores.';

  @override
  String get profileTikTokRemoved => 'TikTok username removed.';

  @override
  String get profileTikTokSaved => 'TikTok profile link added.';

  @override
  String get profileTikTokSaveFailed => 'Could not save your TikTok username.';

  @override
  String get profileDeleteTitle => 'Permanently delete your account?';

  @override
  String get profileNext => 'Continue';

  @override
  String get profileDeleteFinal => 'Final confirmation';

  @override
  String get profileDeleteFinalBody => 'Are you sure? This cannot be undone.';

  @override
  String get profileDeleteFailed =>
      'Could not delete your account. Please try again.';

  @override
  String get profileDietAny => 'No restrictions';

  @override
  String get profileDietVegetarian => 'Vegetarian';

  @override
  String get profileDietVegan => 'Vegan';

  @override
  String get profileDietKeto => 'Keto';

  @override
  String get profileDietLactose => 'Lactose-free';

  @override
  String get documentContact => 'Contact';

  @override
  String get documentEmailBody => 'Email us at:';

  @override
  String get documentCopy => 'Copy address';

  @override
  String get documentClose => 'Close';

  @override
  String get documentOpenFailed =>
      'Could not open the document. Please try again.';

  @override
  String get documentTerms => 'Terms of Use (EULA)';

  @override
  String get documentPrivacy => 'Privacy policy';

  @override
  String get documentDeletion => 'Account deletion information';

  @override
  String get documentHelp => 'Help';

  @override
  String get compareWeekly => 'Automatic weekly plan and list';

  @override
  String get compareArchive => 'Archive and reuse finished plans';

  @override
  String get compareLikes => 'Likes / Dislikes: one tailored meal a day';

  @override
  String get compareAi => 'AI recipe import (photo, text, link)';

  @override
  String get compareBatch => 'Batch scanning without closing the camera';

  @override
  String get comparePublish => 'Publish recipes in the shared catalogue';

  @override
  String get compareTikTok => 'TikTok link on your recipes';

  @override
  String get compareLists => 'Shopping lists from selected recipes';

  @override
  String get compareUnlimited => 'Unlimited';

  @override
  String get compareOneWeek => '1 / week';

  @override
  String get compareGenerate => 'Meal plan generation';

  @override
  String get compareJournal => 'Calorie and macro diary';

  @override
  String get compareCalculator => 'Calorie needs calculator';

  @override
  String get compareCatalogue => 'Recipe and product catalogue';

  @override
  String get comparePrices => 'Product price comparison';

  @override
  String profileExpiryDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days more days',
      one: '1 more day',
    );
    return 'Subscription active for $_temp0';
  }

  @override
  String profilePeople(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people',
      one: '1 person',
    );
    return '$_temp0';
  }

  @override
  String profileWeightSaved(String weight) {
    return 'Saved $weight kg.';
  }

  @override
  String profileDate(String date) {
    return 'Date: $date';
  }

  @override
  String get profileDeleteBody =>
      'This cannot be undone. You will lose all saved meal plans, shopping lists, pantry items, favourite recipes, comments and Premium points. If you have an active subscription, cancel it separately in App Store / Google Play settings — deleting your account does not cancel the subscription.';

  @override
  String premiumTrialBadge(int days) {
    return '$days DAYS FREE*';
  }

  @override
  String get premiumCheckTrial => 'See free trial';

  @override
  String premiumTrialEligibilityFootnote(String store) {
    return '* For eligible accounts. $store will show availability, the price after your trial and the renewal date before you confirm.';
  }

  @override
  String get premiumNotNow => 'Not now';

  @override
  String get premiumPurchaseError => 'There was a problem with your purchase.';

  @override
  String get premiumAppleOfferOpenFailed =>
      'The App Store offer could not be opened.';

  @override
  String premiumPaymentsUnavailable(String store) {
    return 'Purchases are unavailable on this device. Please check your $store account.';
  }

  @override
  String get premiumSubscriptionPricesUnavailable =>
      'Subscription prices could not be loaded. Please try again shortly.';

  @override
  String premiumPurchaseFailed(String error) {
    return 'Purchase failed: $error';
  }

  @override
  String get premiumUnknownError => 'unknown error';

  @override
  String get premiumActive => 'Premium is active.';

  @override
  String get premiumActivated => 'Premium is now active. Thank you.';

  @override
  String premiumPurchaseVerificationFailed(String error) {
    return 'Your purchase could not be verified: $error';
  }

  @override
  String premiumPointsAdded(int balance) {
    return 'Points added. Your balance is $balance.';
  }

  @override
  String premiumPurchaseStartFailed(String error) {
    return 'Your purchase could not be started: $error';
  }

  @override
  String get premiumRestoreEmpty =>
      'There are no previous purchases to restore.';

  @override
  String premiumQuickActionPoints(String subtitle, int points) {
    String _temp0 = intl.Intl.pluralLogic(
      points,
      locale: localeName,
      other: '$points points',
      one: '$points point',
    );
    return '$subtitle. Or use $_temp0 without a subscription.';
  }

  @override
  String get premiumAutomaticWeekTitle => 'Automatic weekly plan';

  @override
  String get premiumAutomaticWeekDescription =>
      'Get a meal plan and an optional shopping list on your chosen day.';

  @override
  String get premiumBatchTitle => 'Batch barcode scanning';

  @override
  String get premiumBatchDescription =>
      'Scan one product after another, then add the whole batch to your chosen destinations.';

  @override
  String get premiumUnlimitedPlansTitle => 'Unlimited meal plans';

  @override
  String get premiumUnlimitedPlansDescription =>
      'Create as many meal plans as you need, with no weekly limit.';

  @override
  String get premiumAiRecipesTitle => 'AI recipe import';

  @override
  String get premiumAiRecipesDescription =>
      'Add your own recipes from pasted text or a photo.';

  @override
  String get premiumFullDiaryTitle => 'Full Diary history';

  @override
  String get premiumFullDiaryDescription =>
      'View your full calorie history beyond the last 30 days.';

  @override
  String get premiumUnlimitedListsTitle => 'Unlimited shopping lists';

  @override
  String get premiumUnlimitedListsDescription =>
      'Create a new shopping list whenever you need one.';

  @override
  String get premiumProductName => 'Meal Planner Premium';

  @override
  String get premiumHeroDescription =>
      'Plan your week, scan your groceries and put together a shopping list in minutes.';

  @override
  String get premiumAutomaticWeekSubtitle =>
      'Your weekly plan and optional shopping list, ready each week';

  @override
  String get premiumAutomaticWeekRequired =>
      'Automatic weekly planning is available with Premium.';

  @override
  String get premiumAiActionTitle => 'Add a recipe with AI';

  @override
  String get premiumAiActionSubtitle =>
      'Start with a photo, text or link and let AI build the recipe';

  @override
  String get premiumBatchActionTitle => 'Scan several products in one go';

  @override
  String get premiumBatchActionSubtitle =>
      'Choose your destinations and confirm the whole batch';

  @override
  String premiumBatchCompleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count products processed.',
      one: '$count product processed.',
    );
    return '$_temp0';
  }

  @override
  String get premiumPublishActionTitle => 'Publish your recipes';

  @override
  String get premiumPublishActionSubtitle =>
      'Share your recipes with the community';

  @override
  String get premiumRecipeListsTitle => 'Shopping lists from recipes';

  @override
  String get premiumRecipeListsSubtitle => 'Unlimited (Standard: 1 per week)';

  @override
  String get premiumCookFromPantryTitle => 'Cook with what you have';

  @override
  String get premiumCookFromPantrySubtitle =>
      'Select the ingredients you have and find matching recipes';

  @override
  String get premiumPantryActionTitle => 'Your pantry';

  @override
  String get premiumPantryActionSubtitle =>
      'Keep track of the food you have at home';

  @override
  String premiumSubscriptionLegal(String store) {
    return 'Subscriptions renew automatically unless cancelled at least 24 hours before the current period ends. Payment is charged to your $store account when you confirm your purchase. Manage or cancel your subscription in your store account settings.';
  }

  @override
  String get premiumAlreadyActive => 'Your Premium subscription is active';

  @override
  String get premiumExpiresToday => 'Expires today';

  @override
  String premiumDaysRemaining(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Active for $days more days',
      one: 'Active for $days more day',
    );
    return '$_temp0';
  }

  @override
  String get premiumRetry => 'Try again';

  @override
  String get premiumWeekly => 'Weekly';

  @override
  String get premiumMonthly => 'Monthly';

  @override
  String premiumMonthlyTrial(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days free',
      one: '$days day free',
    );
    return '$_temp0';
  }

  @override
  String get premiumYearly => 'Yearly';

  @override
  String premiumYearlySaving(int percent) {
    return 'Save $percent%';
  }

  @override
  String premiumTrialDisclosureApple(int days) {
    return 'Eligible accounts can try Premium free for $days days. It then renews at the price shown above. You can cancel in your Apple account settings.';
  }

  @override
  String premiumTrialDisclosureGoogle(int days) {
    return 'Eligible accounts can try Premium free for $days days. It then renews at the price shown above. You can cancel in Google Play.';
  }

  @override
  String get premiumRestorePurchases => 'Restore purchases';

  @override
  String get premiumPointsTitle => 'Premium points';

  @override
  String premiumPointsBalance(int balance) {
    return 'Your balance: $balance';
  }

  @override
  String get premiumPointsExplanation =>
      'Import a recipe from a photo, text or link for 2 points. Edit a recipe with AI for 1 point. A subscription is optional.';

  @override
  String get premiumPointsPricesUnavailable =>
      'Point package prices could not be loaded.';

  @override
  String premiumPointsAmount(int points) {
    String _temp0 = intl.Intl.pluralLogic(
      points,
      locale: localeName,
      other: '$points points',
      one: '$points point',
    );
    return '$_temp0';
  }

  @override
  String premiumPromotionalPrice(String price) {
    return 'Offer price: $price';
  }

  @override
  String premiumPointsUses(int imports, int edits) {
    String _temp0 = intl.Intl.pluralLogic(
      imports,
      locale: localeName,
      other: '$imports AI imports',
      one: '$imports AI import',
    );
    String _temp1 = intl.Intl.pluralLogic(
      edits,
      locale: localeName,
      other: '$edits AI edits',
      one: '$edits AI edit',
    );
    return '$_temp0\nor $_temp1';
  }

  @override
  String get premiumBuyInApple => 'Buy in the App Store';

  @override
  String get premiumBuyInGoogle => 'Buy in Google Play';

  @override
  String premiumPriceAfterTrial(String price) {
    return 'Then $price per month';
  }

  @override
  String premiumPriceBeforeCode(String price) {
    return 'Price before offer code: $price';
  }

  @override
  String get premiumTryFree => 'Try for free';

  @override
  String get premiumBuy => 'Get Premium';

  @override
  String get premiumRedeemCode => 'Get offer code';

  @override
  String get premiumBuyDiscount => 'Buy at the offer price';

  @override
  String get premiumContextRecipeEyebrow => 'PREMIUM FOR RECIPES';

  @override
  String get premiumContextRecipeTitle => 'Turn an idea into a recipe';

  @override
  String get premiumContextRecipeDescription =>
      'Paste a link, add a photo or describe a dish. Get a recipe with ingredients, servings and clear steps.';

  @override
  String get premiumContextRecipeBenefitImport =>
      'A recipe from a link, photo or description';

  @override
  String get premiumContextRecipeBenefitSteps =>
      'Ingredients and steps put together for you';

  @override
  String get premiumContextRecipeBenefitEdit => 'Edit recipes with AI';

  @override
  String get premiumContextMealPlanEyebrow => 'PREMIUM FOR PLANNING';

  @override
  String get premiumContextMealPlanTitle => 'Plan as many weeks as you need';

  @override
  String get premiumContextMealPlanDescription =>
      'Create as many meal plans as you need and fit your meals around your day.';

  @override
  String get premiumContextMealPlanBenefitUnlimited => 'Unlimited meal plans';

  @override
  String get premiumContextMealPlanBenefitWeekly =>
      'An automatic plan for next week';

  @override
  String get premiumContextMealPlanBenefitSwap => 'Find and swap meals';

  @override
  String get premiumContextBarcodeEyebrow => 'PREMIUM FOR SCANNING';

  @override
  String get premiumContextBarcodeTitle => 'Scan your groceries in one go';

  @override
  String get premiumContextBarcodeDescription =>
      'Scan products one after another, then add the whole batch to your chosen destinations.';

  @override
  String get premiumContextBarcodeBenefitBatch => 'Batch barcode scanning';

  @override
  String get premiumContextBarcodeBenefitNutrition =>
      'Calories and macros for matched products';

  @override
  String get premiumContextBarcodeBenefitDestinations =>
      'Add the batch to your Diary, pantry or catalogue';

  @override
  String get premiumContextShoppingEyebrow => 'PREMIUM FOR SHOPPING';

  @override
  String get premiumContextShoppingTitle =>
      'Create as many shopping lists as you need';

  @override
  String get premiumContextShoppingDescription =>
      'Make a separate list for each plan or recipe. Merge lists for the same shop.';

  @override
  String get premiumContextShoppingBenefitLists => 'Unlimited shopping lists';

  @override
  String get premiumContextShoppingBenefitMerge =>
      'Merge lists for the same shop';

  @override
  String get premiumContextShoppingBenefitPantry =>
      'Food from your pantry adds no shopping cost';

  @override
  String get premiumContextPantryEyebrow => 'PREMIUM FOR YOUR PANTRY';

  @override
  String get premiumContextPantryTitle => 'Use the food you already have';

  @override
  String get premiumContextPantryDescription =>
      'Find recipes that use your pantry ingredients and buy only what you need.';

  @override
  String get premiumContextPantryBenefitMatch =>
      'Recipes that use your ingredients';

  @override
  String get premiumContextPantryBenefitMissing => 'Fewer missing ingredients';

  @override
  String get premiumContextPantryBenefitWaste => 'Less food waste';

  @override
  String get premiumContextJournalEyebrow => 'PREMIUM FOR YOUR DIARY';

  @override
  String get premiumContextJournalTitle => 'See your progress over time';

  @override
  String get premiumContextJournalDescription =>
      'Look back over a longer period to spot changes in calories, macros, hydration and weight.';

  @override
  String get premiumContextJournalBenefitHistory => 'Your full Diary history';

  @override
  String get premiumContextJournalBenefitCharts =>
      'Calorie, macro and hydration charts';

  @override
  String get premiumContextJournalBenefitWeight => 'Weight progress over time';

  @override
  String get premiumPackageSemantics => 'Package';

  @override
  String premiumDiscountSemantics(int percent) {
    return '$percent per cent discount';
  }

  @override
  String premiumDiscountRibbon(int percent) {
    return 'SAVE $percent%';
  }

  @override
  String get premiumSeePlans => 'See Premium plans';

  @override
  String get archiveTitle => 'Plan archive';

  @override
  String get archiveChooseStart => 'When should the plan start?';

  @override
  String get archiveChooseDate => 'Choose date';

  @override
  String get archiveResumeTitle => 'Resume plan';

  @override
  String archiveResumeBody(int days, String date) {
    return 'The same meals for $days days from $date. The original plan will stay in the archive. We will create a new shopping list. No AI generation or Premium points needed.';
  }

  @override
  String get archiveResume => 'Resume';

  @override
  String get archiveResumed => 'Your plan has been resumed.';

  @override
  String get archiveResumeFailed =>
      'Could not resume the plan. Please try again.';

  @override
  String archiveDuration(int days) {
    return '$days days';
  }

  @override
  String get archivePremiumHint =>
      'With Premium, completed plans stay in your archive. You can view and resume them without AI generation.';

  @override
  String get archiveSeePremium => 'See Premium';

  @override
  String get archiveCompleted => 'Completed plans';

  @override
  String get archiveHint =>
      'Use the same meals again from a new date. No AI generation or Premium points needed.';

  @override
  String get archiveEmpty =>
      'No completed plans yet. Your active plan will appear here after its last day.';

  @override
  String archivePlanTitle(int days) {
    return '$days-day plan';
  }

  @override
  String get archivePreview => 'Preview';

  @override
  String get archiveResuming => 'Resuming…';

  @override
  String get automationTitle => 'Automatic week';

  @override
  String get automationHeading => 'Your plan, ready before the week begins';

  @override
  String get automationHint =>
      'Each week, we will prepare a 7-day plan based on your goal, preferences and preferred shop.';

  @override
  String get automationGenerate => 'Generate automatically';

  @override
  String get automationPremiumHint => 'Only while Premium is active';

  @override
  String get automationWeekday => 'Day of the week';

  @override
  String get automationMonday => 'Monday';

  @override
  String get automationTuesday => 'Tuesday';

  @override
  String get automationWednesday => 'Wednesday';

  @override
  String get automationThursday => 'Thursday';

  @override
  String get automationFriday => 'Friday';

  @override
  String get automationSaturday => 'Saturday';

  @override
  String get automationSunday => 'Sunday';

  @override
  String get automationHour => 'Time';

  @override
  String get automationCreateList => 'Also create a shopping list';

  @override
  String get automationLastPlan => 'Last plan created';

  @override
  String get automationSave => 'Save settings';

  @override
  String get automationRun => 'Generate now';

  @override
  String get automationEnabled => 'Automatic week is on.';

  @override
  String get automationDisabled => 'Automatic week is off.';

  @override
  String get automationReady => 'Your plan is ready. Find it in Home.';

  @override
  String get errorSignIn => 'You need to sign in to do this.';

  @override
  String get errorTooManyRequests =>
      'Too many attempts. Please try again shortly.';

  @override
  String get errorUnavailable =>
      'The service is temporarily unavailable. Please try again shortly.';

  @override
  String get errorServerTimeout =>
      'The server did not respond in time. Please try again shortly.';

  @override
  String get errorServer =>
      'Something went wrong on our side. Please try again shortly.';

  @override
  String get errorOperationTimeout =>
      'This took too long. Please try again shortly.';

  @override
  String get errorConnection =>
      'Could not connect to the server. Check your internet connection and try again.';

  @override
  String get errorFormat =>
      'Could not read the data. Refresh the screen and try again.';

  @override
  String get automationRetry => 'Retry';

  @override
  String get ingredientPreferencesTitle => 'Ingredient preferences';

  @override
  String get ingredientPreferencesLimit =>
      'You can choose up to 50 ingredients in each group.';

  @override
  String get ingredientPreferencesSavedMessage =>
      'Ingredient preferences saved.';

  @override
  String get ingredientPreferencesUnsavedTitle => 'Unsaved preferences';

  @override
  String get ingredientPreferencesUnsavedBody =>
      'You have unsaved changes. Go back without saving?';

  @override
  String get ingredientPreferencesStay => 'Stay';

  @override
  String get ingredientPreferencesDiscard => 'Go back without saving';

  @override
  String get ingredientPreferencesEmpty => 'No ingredients selected yet.';

  @override
  String ingredientPreferencesRemove(String name) {
    return 'Remove $name';
  }

  @override
  String get ingredientPreferencesRetry => 'Try again';

  @override
  String get ingredientPreferencesHint =>
      'We will use your preferences in one meal a day when a matching recipe is available. Allergies and diet take priority.';

  @override
  String get ingredientPreferencesLike => 'Like';

  @override
  String get ingredientPreferencesDislike => 'Dislike';

  @override
  String get ingredientPreferencesAddLike => 'Add to: Like';

  @override
  String get ingredientPreferencesAddDislike => 'Add to: Dislike';

  @override
  String get ingredientPreferencesSearch => 'Search ingredients';

  @override
  String get ingredientPreferencesMoveHint =>
      'Selecting an ingredient in the other group moves it there.';

  @override
  String get ingredientPreferencesRetrySearch => 'Search again';

  @override
  String get ingredientPreferencesNoResults =>
      'No ingredients match this name.';

  @override
  String ingredientPreferencesSaveError(String error) {
    return 'Not saved: $error';
  }

  @override
  String get ingredientPreferencesSaving => 'Saving…';

  @override
  String get ingredientPreferencesSave => 'Save preferences';

  @override
  String get ingredientPreferencesSaved => 'Preferences saved';

  @override
  String get ingredientPreferencesLocked =>
      'Choose ingredients you like and dislike. Premium uses them in one meal a day when a matching recipe is available.';

  @override
  String get ingredientPreferencesPremium => 'View Premium';

  @override
  String get blockedUsersTitle => 'Blocked users';

  @override
  String get blockedUsersEmpty => 'You have not blocked anyone yet.';

  @override
  String get blockedUsersUnknown => 'User';

  @override
  String get blockedUsersUnblock => 'Unblock';

  @override
  String blockedUsersUnblocked(String name) {
    return 'Unblocked \"$name\". You can see their content again.';
  }

  @override
  String get calculatorTitle => 'Calorie calculator';

  @override
  String get calculatorIntro =>
      'Enter your details to calculate your daily calorie needs (the Mifflin–St Jeor formula, also used by Poland\'s NFZ calorie calculator).';

  @override
  String get calculatorWeight => 'Weight (kg)';

  @override
  String get calculatorHeight => 'Height (cm)';

  @override
  String get calculatorAge => 'Age (years)';

  @override
  String get calculatorSex => 'Sex';

  @override
  String get calculatorFemale => 'Female';

  @override
  String get calculatorMale => 'Male';

  @override
  String get calculatorActivity => 'Physical activity level';

  @override
  String get calculatorSedentary => 'Sedentary';

  @override
  String get calculatorSedentaryHint => 'Little or no exercise';

  @override
  String get calculatorLight => 'Lightly active';

  @override
  String get calculatorLightHint => 'Exercise 1–3 days a week';

  @override
  String get calculatorModerate => 'Moderately active';

  @override
  String get calculatorModerateHint => 'Exercise 3–5 days a week';

  @override
  String get calculatorActive => 'Active';

  @override
  String get calculatorActiveHint => 'Exercise 6–7 days a week';

  @override
  String get calculatorVeryActive => 'Very active';

  @override
  String get calculatorVeryActiveHint => 'Physical work and daily training';

  @override
  String get calculatorNumbersRequired =>
      'Enter numbers in all fields (weight, height and age).';

  @override
  String get calculatorCalculate => 'Calculate calorie needs';

  @override
  String get calculatorSaveFailed => 'Could not save your goal.';

  @override
  String calculatorGoalSaved(int kcal) {
    return 'Goal saved: $kcal kcal/day';
  }

  @override
  String get calculatorChooseGoal => 'Choose your goal';

  @override
  String get calculatorGoalHint =>
      'Tap a tile to select it, or fine-tune it with the slider below.';

  @override
  String get calculatorLoss => 'Weight loss';

  @override
  String get calculatorMaintenance => 'Maintain';

  @override
  String get calculatorGain => 'Weight gain';

  @override
  String calculatorCustomGoal(int kcal) {
    return 'Your target: $kcal kcal/day';
  }

  @override
  String get calculatorMacros => 'Estimated macronutrient split';

  @override
  String get calculatorProtein => 'Protein';

  @override
  String get calculatorFat => 'Fat';

  @override
  String get calculatorCarbs => 'Carbs';

  @override
  String get calculatorSaveGoal => 'Save as my goal';

  @override
  String get socialInviteTitle => 'Invite a friend';

  @override
  String get socialIdentifier => 'Username or email';

  @override
  String get socialSend => 'Send';

  @override
  String get socialInvitationSent => 'Invitation sent.';

  @override
  String get socialInvitationAccepted => 'Invitation accepted.';

  @override
  String get socialInvitationDeclined => 'Invitation declined.';

  @override
  String get socialInvitationCancelled => 'Invitation cancelled.';

  @override
  String get socialFriends => 'Friends';

  @override
  String get socialInvite => 'Invite';

  @override
  String get socialRetry => 'Try again';

  @override
  String get socialIncoming => 'Invitations for you';

  @override
  String get socialYourFriends => 'Your friends';

  @override
  String get socialNoFriends =>
      'You do not have any friends yet. Send your first invitation.';

  @override
  String get socialFriendSubtitle => 'Recipes and shopping list';

  @override
  String get socialOutgoing => 'Sent invitations';

  @override
  String get socialAwaitingResponse => 'Awaiting a response';

  @override
  String get socialDecline => 'Decline';

  @override
  String get socialAccept => 'Accept';

  @override
  String get socialNoFriendRecipes =>
      'This friend does not have any saved recipes yet.';

  @override
  String socialRecipeSummary(int minutes, String meal) {
    return '$minutes min • $meal';
  }

  @override
  String get socialNoFriendLists =>
      'This friend does not have an active shopping list right now.';

  @override
  String get socialShareAccepted =>
      'Accepted — the list will appear in your shared lists.';

  @override
  String get socialSharesTitle => 'Shopping list invitations';

  @override
  String get socialNoPendingShares => 'No pending invitations.';

  @override
  String socialSharedListInvitation(String name) {
    return '$name shared a shopping list with you';
  }

  @override
  String get socialSomeone => 'Someone';

  @override
  String get socialShareRespond => 'Tap to respond';

  @override
  String get socialShareAccept => 'Accept';

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String get notificationsLoadFailed => 'Could not load notifications';

  @override
  String get notificationsMarkAllFailed =>
      'Could not mark all notifications as read';

  @override
  String get notificationsPlanEnded => 'This plan has ended.';

  @override
  String get notificationsRecipeOpenFailed => 'Could not open the recipe';

  @override
  String get notificationsJustNow => 'just now';

  @override
  String notificationsMinutes(int count) {
    return '$count min ago';
  }

  @override
  String notificationsHours(int count) {
    return '$count hr ago';
  }

  @override
  String notificationsDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days ago',
      one: '1 day ago',
    );
    return '$_temp0';
  }

  @override
  String get notificationsMarkAll => 'Mark all as read';

  @override
  String get notificationsEmpty => 'No notifications';

  @override
  String get releasePromptTitle => 'An update is available';

  @override
  String get releasePromptRequired =>
      'This version is no longer supported. Update the app to continue.';

  @override
  String get releasePromptStoreError => 'Could not open the app store.';

  @override
  String get releasePromptChanges =>
      '• Improved Premium activation and purchase restoration.\n• Premium points are credited correctly after a connection interruption or payment retry.\n• Repeat scans and amount selection retain pack size and units.\n• Improved product suggestions and messages in Polish and English.';

  @override
  String detailPlanPortionHelp(int servings, int baseServings) {
    return 'Ingredients are scaled to $servings portions. Quantities written in the method refer to the original recipe ($baseServings portions).';
  }

  @override
  String get releasePromptApple => 'Open App Store';

  @override
  String get releasePromptGoogle => 'Open Google Play';

  @override
  String get releasePromptLater => 'Later';

  @override
  String get pantryAddProduct => 'Add product';

  @override
  String get pantryEmpty =>
      'Your pantry is empty. Add the products you have at home to quickly find out what you can cook.';

  @override
  String get pantryEnterAmount => 'Tap to enter an amount';

  @override
  String get pantryRemove => 'Remove from pantry';

  @override
  String get pantryScanBarcode => 'Scan a barcode';

  @override
  String get pantryScanMany => 'Scan multiple products';

  @override
  String get pantrySearchHint => 'Search for a product...';

  @override
  String get pantrySearchStart => 'Enter a product name.';

  @override
  String get pantrySearchEmpty => 'No results.';

  @override
  String pantrySaved(String name) {
    return 'Added \"$name\" to pantry.';
  }

  @override
  String get matchTitle => 'Cook from my pantry';

  @override
  String get matchPremium => 'Premium feature';

  @override
  String get matchPremiumBody =>
      'Matching recipes to what you have in your pantry is available with an active Premium subscription.';

  @override
  String get matchSeePremium => 'See Premium';

  @override
  String get matchSelectOne => 'Select at least one ingredient.';

  @override
  String get matchEmptyPantry =>
      'Your pantry is empty. Add the products you have at home to find matching recipes.';

  @override
  String get matchAddPantry => 'Add a product to pantry';

  @override
  String matchSelected(int selected, int total) {
    return 'Selected $selected of $total';
  }

  @override
  String get matchDeselect => 'Deselect all';

  @override
  String get matchSelectAll => 'Select all';

  @override
  String matchSearch(int count) {
    return 'Find recipes ($count)';
  }

  @override
  String get matchGenerate => 'Generate a new recipe with AI';

  @override
  String get matchResultsTitle => 'Matching recipes';

  @override
  String get matchResultsEmpty =>
      'No recipes in the catalogue match the selected ingredients. You can generate a new recipe with AI instead.';

  @override
  String get matchOtherAi => 'Nothing suitable? Generate with AI';

  @override
  String get matchReady => 'Ready to cook';

  @override
  String matchMissing(String ingredients) {
    return 'Missing: $ingredients';
  }

  @override
  String matchSelectPrompt(String ingredients) {
    return 'Generate a recipe for a dish using mainly these ingredients I have at home: $ingredients. You may add at most 2–3 commonly available ingredients, such as salt, spices or olive oil.';
  }

  @override
  String matchResultsPrompt(String ingredients) {
    return 'Generate a recipe for a dish using MAINLY these ingredients I have at home: $ingredients. You may add at most 2-3 extra commonly available ingredients (e.g. salt, spices, olive oil), if needed.';
  }

  @override
  String get leaderTitle => 'Recipe author ranking';

  @override
  String get leaderWeek => 'This week';

  @override
  String get leaderAll => 'All time';

  @override
  String get leaderEmptyWeek =>
      'No one has added an approved recipe\nthis week yet. Be the first!';

  @override
  String get leaderEmptyAll =>
      'No one has added an approved recipe\nto the shared catalogue yet.';

  @override
  String leaderCount(int count, String noun) {
    return '$count $noun';
  }

  @override
  String get leaderRecipeSingular => 'recipe';

  @override
  String get leaderRecipeFew => 'recipes';

  @override
  String get leaderRecipeMany => 'recipes';

  @override
  String get adGateTitle => 'Watch a short advert';

  @override
  String get adGateBody =>
      'To open the Diary, watch a short video advert to the end. This does not apply to Premium accounts — their Diary is always ad-free.';

  @override
  String get adGateFailed =>
      'Could not load the advert. Check your internet connection and try again.';

  @override
  String get adGateLoading => 'Loading advert...';

  @override
  String get adGateWatch => 'Watch advert';

  @override
  String get adGateLater => 'Not now';

  @override
  String get promosTitle => 'Promotions';

  @override
  String get promosAll => 'All';

  @override
  String get promosFailed => 'Could not load promotions.';

  @override
  String get promosLoyalty => 'Loyalty card required';

  @override
  String get promosEmpty => 'No active promotions at the moment.';

  @override
  String get statsTitle => 'Statistics';

  @override
  String get statsWeight => 'Weight change';

  @override
  String get statsWeightEmpty =>
      'Add at least one measurement in your profile.';

  @override
  String get statsAverageCalories => 'Average calories';

  @override
  String get statsHydration => 'Hydration';

  @override
  String get statsFavorite => 'Favourite meal';

  @override
  String get statsNoData => 'No data';

  @override
  String get statsDailyCalories => 'Daily calories';

  @override
  String get statsCaloriesEmpty => 'Add meals in the Diary to see the chart.';

  @override
  String get statsCalories => 'Calories';

  @override
  String get statsDailyMacros => 'Daily macros';

  @override
  String get statsMacrosEmpty => 'Macros will appear after you add meals.';

  @override
  String get statsProtein => 'Protein';

  @override
  String get statsFat => 'Fat';

  @override
  String get statsCarbs => 'Carbohydrates';

  @override
  String get statsDailyWater => 'Daily hydration';

  @override
  String get statsWaterEmpty => 'Log water in the Diary to see the chart.';

  @override
  String get statsWater => 'Water';

  @override
  String get statsRecentDays => 'Recently logged days';

  @override
  String get statsRecentEmpty => 'Logged meals and hydration will appear here.';

  @override
  String get statsWeekly => 'Insights from the last 7 days';

  @override
  String get statsPremiumTitle => 'Full report with Premium';

  @override
  String get statsPremiumBody =>
      'Unlock calorie, hydration and weight analysis with practical insights each week.';

  @override
  String get statsPremiumAction => 'View full report';

  @override
  String statsDailyMacroLine(
    String kcal,
    String protein,
    String fat,
    String carbs,
  ) {
    return '$kcal kcal  •  P $protein g  •  F $fat g  •  C $carbs g';
  }

  @override
  String statsWaterLine(int amount) {
    return 'Water: $amount ml';
  }

  @override
  String statsMaximum(String amount, String unit) {
    return 'Maximum: $amount $unit';
  }

  @override
  String insightRegularity(int count) {
    return 'Consistency: $count of 7 days';
  }

  @override
  String get insightEnough => 'You now have enough data to compare weeks.';

  @override
  String insightMoreDays(int count) {
    return 'Log $count more days for a more accurate report.';
  }

  @override
  String insightCalories(int count) {
    return 'Average $count kcal per day';
  }

  @override
  String get insightCaloriesDetail =>
      'Compare weekly averages rather than judging a single day.';

  @override
  String get insightWaterMissing => 'Hydration data is missing';

  @override
  String insightWaterAverage(int amount) {
    return 'Average $amount ml of water';
  }

  @override
  String get insightWaterEveryDay =>
      'Hydration was logged every day this week.';

  @override
  String insightWaterDays(int count) {
    return 'Hydration was logged on $count of 7 days.';
  }

  @override
  String get insightWeightStable => 'No significant weight change';

  @override
  String insightWeightChange(String amount) {
    return 'Weight change $amount kg';
  }

  @override
  String get insightWeightDetail =>
      'Comparison of the first and last measurements from the past 7 days.';

  @override
  String get cookingTipsTitle => 'Cooking tips';

  @override
  String get splashSubtitle => 'Plan meals wisely and save';

  @override
  String get onboardingStoresEmpty => 'No shops are available. Try again.';

  @override
  String get authCaptchaUnavailable =>
      'Could not load verification. Check your connection.';

  @override
  String get authCaptchaRetry => 'Retry';

  @override
  String get authCaptchaContinue => 'Continue anyway';

  @override
  String get authCaptchaRefresh => 'Refresh verification';

  @override
  String get adminProductsTitle => 'Submitted products';

  @override
  String get adminProductsEmpty => 'No products are awaiting review.';

  @override
  String get adminProductsRefresh => 'Refresh submissions';

  @override
  String get adminProductApproved => 'Product added to catalogue';

  @override
  String get adminProductRejected => 'Product rejected';

  @override
  String get adminNoNutrition => 'No nutritional information';

  @override
  String adminProductNutrition(
    String kcal,
    String protein,
    String fat,
    String carbs,
  ) {
    return 'Per 100 g: $kcal kcal · P $protein · F $fat · C $carbs';
  }

  @override
  String get adminReject => 'Reject';

  @override
  String get adminApprove => 'Approve';

  @override
  String get adminAllRecipesTitle => 'All user recipes';

  @override
  String get adminRecipesEmpty => 'No recipes have been added by users.';

  @override
  String get adminShowMore => 'Show more';

  @override
  String get adminPublic => 'Public';

  @override
  String get adminPending => 'Pending';

  @override
  String get adminRejected => 'Rejected';

  @override
  String get adminPrivate => 'Private';

  @override
  String get adminUnknownAuthor => 'Unknown author';

  @override
  String get adminDeleteRecipeTooltip => 'Delete recipe';

  @override
  String get adminDeleteRecipeTitle => 'Delete recipe?';

  @override
  String adminDeleteRecipeBody(String name) {
    return 'You will delete \"$name\", its comments and its links to shopping lists and meal plans used by other users. This cannot be undone.';
  }

  @override
  String get adminRecipeFallback => 'this recipe';

  @override
  String get adminUsersTitle => 'Users';

  @override
  String get adminUsersSearch => 'Search by email or name…';

  @override
  String get adminUsersOnlyBanned => 'Banned accounts only';

  @override
  String get adminUsersEmpty => 'No results.';

  @override
  String get adminUsersUnnamed => 'Unnamed';

  @override
  String adminUsersVersion(String version) {
    return 'Version: $version';
  }

  @override
  String adminUsersReason(String reason) {
    return 'Reason: $reason';
  }

  @override
  String adminUsersBanTitle(String name) {
    return 'Ban $name?';
  }

  @override
  String get adminUsersBanBody =>
      'This account will lose access to the app immediately, even if it is currently signed in. No data will be deleted, and the ban can be reversed.';

  @override
  String get adminUsersReasonLabel => 'Reason (visible to the user)';

  @override
  String get adminUsersBan => 'Ban';

  @override
  String get adminUsersUnban => 'Unban';

  @override
  String get adminUsersBanned => 'Account banned';

  @override
  String get adminUsersUnbanned => 'Account unbanned';

  @override
  String get adminCommentsTitle => 'Comments';

  @override
  String get adminCommentsSearch => 'Search comment text, author or recipe…';

  @override
  String get adminCommentsEmpty => 'No comments.';

  @override
  String adminCommentsRecipe(String name) {
    return 'on: $name';
  }

  @override
  String get adminCommentsPhotoOnly => '(photo only)';

  @override
  String get adminCommentsEmptyText => '(empty)';

  @override
  String get adminCommentsHasPhoto => 'includes a photo';

  @override
  String get adminCommentsDelete => 'Delete comment';

  @override
  String get adminCommentsDeleteTitle => 'Delete comment?';

  @override
  String get adminCommentsDeleteBody => 'This cannot be undone.';

  @override
  String get adminCommentsDeleted => 'Comment deleted';

  @override
  String get adminPhotosTitle => 'Photos awaiting review';

  @override
  String get adminPhotosEmpty => 'No photos are awaiting review.';

  @override
  String get adminPhotosApproved => 'Photo approved';

  @override
  String get adminPhotosRejected => 'Photo rejected';

  @override
  String get adminPhotosRecipe => 'Recipe';

  @override
  String get adminPhotosUnknownSubmitter => 'unknown';

  @override
  String adminPhotosSubmittedBy(String name) {
    return 'Submitted by: $name';
  }

  @override
  String get adminPhotosReplaceWarning =>
      'Please note: this recipe already has a photo — approving this one will replace it.';

  @override
  String get adminPhotosLoadError => 'Could not load the photo';

  @override
  String get adminPhotosApprove => 'Approve';

  @override
  String get adminMainTitle => 'Admin panel';

  @override
  String adminMainBroadcastSent(String count) {
    return 'Sent to $count users.';
  }

  @override
  String get adminMainReportsTitle => 'Content reports';

  @override
  String get adminMainReportsHelp =>
      'Recipes and comments reported by users as spam, harassment or other breaches of the terms.';

  @override
  String get adminMainReportsEmpty => 'No unresolved reports.';

  @override
  String get adminMainRecipeType => 'Recipe';

  @override
  String get adminMainCommentType => 'Comment';

  @override
  String adminMainReportDetails(String details) {
    return 'Details from reporter: $details';
  }

  @override
  String adminMainAuthor(String email) {
    return 'Author: $email';
  }

  @override
  String adminMainReporter(String email) {
    return 'Reported by: $email';
  }

  @override
  String get adminMainDismiss => 'Dismiss report';

  @override
  String get adminMainDeleteContent => 'Delete content';

  @override
  String get adminMainResolve => 'Mark as resolved';

  @override
  String get adminMainBroadcastTitle => 'Send a notification to everyone';

  @override
  String get adminMainBroadcastHelp =>
      'This goes to EVERY user’s in-app notifications — it cannot be undone. Check the text before sending.';

  @override
  String get adminMainBroadcastHint => 'Notification text...';

  @override
  String get adminMainBroadcastSend => 'Send to everyone';

  @override
  String get adminMainPromotionsLoadFailed =>
      'Could not load pending promotions.';

  @override
  String adminMainScanSummary(String found, String queued) {
    return 'Found $found; queued $queued for approval.';
  }

  @override
  String get adminMainScanPending =>
      'Scanning is continuing on the server. You can leave this panel; results will appear in the review queue.';

  @override
  String get adminMainPromotionApproved => 'Promotion approved';

  @override
  String get adminMainPromotionRejected => 'Promotion rejected';

  @override
  String get adminMainActionFailed => 'Could not complete the action';

  @override
  String get adminMainRecipesLoadFailed => 'Could not load pending recipes.';

  @override
  String get adminMainReportsLoadFailed => 'Could not load reports.';

  @override
  String get adminMainDeleteContentTitle => 'Delete the reported content?';

  @override
  String get adminMainDeleteContentHelp =>
      'The comment or recipe will be permanently deleted and the report closed. This cannot be undone.';

  @override
  String get adminMainContentDeleted => 'Content deleted; report closed';

  @override
  String get adminMainReportResolved => 'Report marked as resolved';

  @override
  String get adminMainReportDismissed => 'Report dismissed';

  @override
  String get adminMainRecipeApproved => 'Recipe approved';

  @override
  String get adminMainRecipeRejected => 'Recipe rejected';

  @override
  String get adminMainRecipesTitle => 'Recipes awaiting approval';

  @override
  String get adminMainRecipesHelp =>
      'Recipes submitted by Premium users to the shared public catalogue.';

  @override
  String get adminMainRecipesEmpty => 'No recipes are awaiting approval.';

  @override
  String adminMainRecipeMeta(
    String mealType,
    String servings,
    String difficulty,
  ) {
    return '$mealType • $servings servings • $difficulty';
  }

  @override
  String get adminMainRecipePreview =>
      'Tap to check ingredients, instructions, photo and macros';

  @override
  String get adminMainApprove => 'Approve';

  @override
  String get adminMainAiTitle => 'AI service status';

  @override
  String get adminMainAiHelp =>
      'Checks that the Gemini key works and that token/request limits have not been reached, for each model separately.';

  @override
  String get adminMainAiCheck => 'Check AI status';

  @override
  String get adminMainAiKeyMissing => 'The API key is not configured.';

  @override
  String get adminMainScanTitle => 'Scan promotional leaflets';

  @override
  String get adminMainScanHelp =>
      'AI searches online for the shop’s current leaflet and recognises its promotions. Results go to the approval queue below — nothing changes automatically.';

  @override
  String get adminMainUkScanUnavailable =>
      'UK promotion sources are being prepared. The Polish leaflet scanner does not create GBP promotions.';

  @override
  String adminMainScanShop(String store) {
    return 'Scan $store';
  }

  @override
  String adminMainScanningShop(String store) {
    return 'Scanning $store is continuing in the background. You can leave this panel.';
  }

  @override
  String get adminMainPendingTitle => 'Awaiting approval';

  @override
  String get adminMainPromotionsEmpty => 'No promotions are awaiting approval.';

  @override
  String get adminMainProductsNav => 'Products';

  @override
  String get adminMainUserRecipesNav => 'User recipes';

  @override
  String get campaignTitle => 'Campaigns';

  @override
  String get campaignRequired =>
      'Fill in the name, dates, shop offer configuration and recipient.';

  @override
  String get campaignConfirmGoogle => 'Confirm the Google Play offer';

  @override
  String get campaignConfirmApple => 'Confirm the App Store offer';

  @override
  String campaignConfirmPoints(String store) {
    return 'Enable only after setting a temporary price for this points pack in $store for all users. The in-app price comes directly from the store.';
  }

  @override
  String get campaignConfirmPremium =>
      'Enable only when the specified store offer is active, has exactly this discount and covers the right product. The app does not change the price itself.';

  @override
  String get campaignConfirm => 'Confirm';

  @override
  String get campaignDeleteTitle => 'Delete campaign?';

  @override
  String campaignDeleteBody(String name) {
    return 'Campaign “$name” will be removed from this panel. You must disable the store offer separately.';
  }

  @override
  String get campaignMarketGb => 'Market: United Kingdom • GBP • Europe/London';

  @override
  String get campaignMarketPl => 'Market: Poland • PLN • Europe/Warsaw';

  @override
  String get campaignHeading => 'Premium and points promotion';

  @override
  String get campaignHelp =>
      'Ribbons appear on the icons in the Premium panel. An iOS subscription opens an Apple offer code; Android selects a Google Play offer. For points, set a temporary product price for everyone in the relevant store.';

  @override
  String get campaignName => 'Campaign name';

  @override
  String get campaignStore => 'Store';

  @override
  String get campaignOffer => 'Offer';

  @override
  String get campaignSubscription => 'Premium subscription';

  @override
  String get campaignPoints => 'Premium points';

  @override
  String get campaignProduct => 'Product covered by offer';

  @override
  String get campaignDiscount => 'Discount';

  @override
  String get campaignAudience => 'Audience';

  @override
  String get campaignEveryone => 'Everyone';

  @override
  String get campaignOneUser => 'One user';

  @override
  String get campaignEmail => 'User email';

  @override
  String get campaignDates => 'Choose dates';

  @override
  String get campaignAppleUrl => 'Apple offer code link';

  @override
  String get campaignAppleUrlHelp =>
      'Link: apps.apple.com/redeem?ctx=offercodes…';

  @override
  String get campaignBasePlan => 'Google Play: base plan ID';

  @override
  String get campaignAndroidOffer => 'Google Play: offer ID';

  @override
  String campaignPointsHelp(String store) {
    return 'First schedule a temporary price reduction for this points pack in $store. The campaign displays a ribbon, but the price always comes directly from the store.';
  }

  @override
  String get campaignSaving => 'Saving…';

  @override
  String get campaignCreate => 'Create campaign (disabled)';

  @override
  String get campaignSaved => 'Saved campaigns';

  @override
  String get campaignEmpty => 'No campaigns.';

  @override
  String get campaignActive => 'Active';

  @override
  String get campaignDeleteTooltip => 'Delete campaign';

  @override
  String get adminMarketLabel => 'Catalogue market';

  @override
  String get adminMarketBusy => 'Wait for the current operation to finish.';

  @override
  String get adminMarketHelp =>
      'Changes the data view, not your account’s country.';

  @override
  String get adminMarketPl => 'Poland';

  @override
  String get adminMarketGb => 'United Kingdom';

  @override
  String get approvalRecipePending =>
      'This recipe is awaiting your approval for the shared catalogue';

  @override
  String get approvalRecipeApprove => 'Approve';

  @override
  String get approvalRecipeApproved => 'Recipe approved';

  @override
  String get approvalRecipeRejected => 'Recipe rejected';

  @override
  String get approvalRecipeFailed => 'Could not complete the action';

  @override
  String get shoppingAddQueryHint => 'Enter any item…';

  @override
  String get shoppingAddCustom => 'Add the item you entered';

  @override
  String get shoppingAddMatches =>
      'Matching products from the catalogue and previous scans';

  @override
  String get shoppingAddMinimumQuery =>
      'Enter at least 2 characters to search for a product.';

  @override
  String get shoppingAddNoResults => 'No product with this name was found.';

  @override
  String shoppingAddSuccess(String name) {
    return 'Added: $name';
  }

  @override
  String get shoppingAddCustomFailed => 'Could not add the item';

  @override
  String get shoppingAddProductFailed => 'Could not add the product';

  @override
  String get shoppingAddProductFallback => 'Product';

  @override
  String get shoppingAddCatalogSource => 'App catalogue';

  @override
  String get shoppingAddCacheSource => 'Previously scanned';

  @override
  String exportListHeading(String store) {
    return 'My shopping list: $store';
  }

  @override
  String exportListSubject(String store) {
    return 'Shopping list - $store';
  }

  @override
  String get exportListTitle => 'Export list';

  @override
  String get exportListCopy => 'Copy to clipboard';

  @override
  String get exportListCopied => 'Copied to clipboard!';

  @override
  String exportListOpenApp(String name) {
    return 'Open $name';
  }

  @override
  String get exportListAppMissing => 'This app is not installed.';

  @override
  String get exportListAppFailed => 'Could not open the app.';

  @override
  String get exportListComingSoon => 'Coming soon';

  @override
  String get diarySignInView => 'Sign in to view your diary.';

  @override
  String get diarySignInAdd => 'Sign in to add an entry.';

  @override
  String get authStoredSessionFailed =>
      'We could not restore your saved session. Please try signing in again.';

  @override
  String authGoogleNativeFailed(Object code) {
    return 'Could not sign in with Google ($code). Please try again.';
  }

  @override
  String get authGoogleTokenUnavailable =>
      'Could not obtain the Google identity token.';

  @override
  String get authAppleNativeFailed =>
      'Could not sign in with Apple. Please try again.';

  @override
  String get authAppleTokenUnavailable =>
      'Could not obtain the Apple identity token.';

  @override
  String get shoppingLimitTitle => 'More shopping? Go unlimited with Premium';

  @override
  String get shoppingLimitDescription =>
      'You have used your free shopping list this week. With Premium, create separate lists for recipes, shops and your next shop — whenever you need them.';

  @override
  String get shoppingLimitSeePremium => 'Explore Premium';

  @override
  String get shoppingLimitBack => 'Back to my shopping list';

  @override
  String get shoppingLimitShort =>
      'You have reached this week\'s list limit. Create more lists with Premium.';
}

/// The translations for English, as used in the United Kingdom (`en_GB`).
class AppLocalizationsEnGb extends AppLocalizationsEn {
  AppLocalizationsEnGb() : super('en_GB');

  @override
  String get scanPantryAmountHint => 'Choose an amount in grams or millilitres';

  @override
  String get foodEntryTitle => 'Add a meal';

  @override
  String get foodEntryFromPlan => 'From plan';

  @override
  String get foodEntryFromRecipes => 'From recipes';

  @override
  String get foodEntryProducts => 'Products';

  @override
  String get foodEntryServingsQuestion => 'How many servings did you eat?';

  @override
  String get foodEntryMealFailed => 'Could not add the meal';

  @override
  String get foodEntryProductFailed => 'Could not add the product';

  @override
  String get foodEntryMealType => 'Meal type';

  @override
  String get foodEntryAddDiary => 'Add to diary';

  @override
  String get foodEntryNoPlan =>
      'You do not have an active meal plan yet.\nCreate a plan in Home to log its meals\nwith one tap.';

  @override
  String get foodEntryNoPlannedMeals =>
      'No meals planned for the selected day.';

  @override
  String get foodEntryRecipesFailed => 'Could not load recipes';

  @override
  String get foodEntryRecipeSearch => 'Search recipes...';

  @override
  String get foodEntryNoResults => 'No results.';

  @override
  String get foodEntryServings => 'Number of servings';

  @override
  String get foodEntryAdjustIngredients => 'Adjust ingredients';

  @override
  String get foodEntryRepeatFailed => 'Could not repeat the entry';

  @override
  String get foodEntryRepeat => 'Add again';

  @override
  String get foodEntryMissingProduct =>
      'Product missing? Add it to the catalogue';

  @override
  String get foodEntrySaveFailed => 'Could not add the entry';

  @override
  String get foodEntryChooseCatalogue => 'Choose from catalogue';

  @override
  String get foodEntryProductName => 'Product / meal name';

  @override
  String get foodEntryNameHint => 'Enter a name or choose a suggestion';

  @override
  String get foodEntryNameRequired => 'Enter a name';

  @override
  String get foodEntryPortion => 'Serving (g/ml, optional)';

  @override
  String get foodEntryCalories => 'Calories (kcal)';

  @override
  String get foodEntryRequired => 'Required';

  @override
  String get foodEntryProtein => 'Protein (g)';

  @override
  String get foodEntryCarbs => 'Carbs (g)';

  @override
  String get foodEntryFat => 'Fat (g)';

  @override
  String get foodEntrySave => 'Save to diary';

  @override
  String get foodEntryInvalidNumber => 'Enter a valid, non-negative number.';

  @override
  String get foodEntryInvalidPortion =>
      'Enter an amount above 0 (max. 1000000).';

  @override
  String get scanZoomUnavailable => 'This camera does not support zoom.';

  @override
  String get scanZoomHint => 'Use 2× zoom or move the phone further away.';

  @override
  String get scanLensFailed => 'Could not switch camera lenses.';

  @override
  String get scanEnterCode => 'Enter a barcode';

  @override
  String get scanCodeHint => '8–14 digits';

  @override
  String get scanBatchCodeHint => '8, 12, 13 or 14 digits';

  @override
  String get scanSearch => 'Search';

  @override
  String get scanCodeInvalidLength => 'The code must contain 8–14 digits.';

  @override
  String get scanCodeInvalid => 'The code is invalid. Check the digits.';

  @override
  String get scanDuplicate => 'This product is already in this batch.';

  @override
  String get scanGuide =>
      'Point the camera at a barcode. Tap the image to focus.';

  @override
  String get scanNormal => 'Normal';

  @override
  String get scanCloseUp => 'Close-up';

  @override
  String get scanTorch => 'Torch';

  @override
  String get scanManual => 'Enter code manually';

  @override
  String get scanNormalLens => 'Normal lens';

  @override
  String get scanCloseUpMode => 'Close-up mode';

  @override
  String get scanZoomTwo => 'Zoom 2×';

  @override
  String get scanZoomOne => 'Zoom 1×';

  @override
  String get scanMissing => 'Not found. Tap to add the product from photos.';

  @override
  String get scanMissingNutrition =>
      'Product found, but calories or macros are missing. Tap to complete the data from label photos.';

  @override
  String get scanMissingPackage =>
      'Product found, but the whole-pack size is missing. Tap to read it from a label photo.';

  @override
  String get scanCorrectNutrition =>
      'Calories or macros are missing. Tap to correct the data.';

  @override
  String get scanCorrectPackage =>
      'The whole-pack size could not be read. Tap to update the photos or enter the amount manually.';

  @override
  String get scanAddedPantry => 'Added to pantry';

  @override
  String get scanAddedDiary => 'Added to diary';

  @override
  String get scanNutritionUnconfirmed =>
      'The server did not confirm the product\'s nutrition values.';

  @override
  String get scanAlreadyCatalogue => 'Already in the catalogue';

  @override
  String get scanAddedCatalogue => 'Added to catalogue';

  @override
  String get scanAlreadySubmitted => 'Product already submitted';

  @override
  String get scanWaitLookup => 'Wait for all codes to be recognised.';

  @override
  String get scanFirstProduct => 'Scan at least one product first.';

  @override
  String get scanCompleteMissing => 'Complete or retry unrecognised products.';

  @override
  String get scanChooseDestinations =>
      'Choose at least one destination for the whole batch.';

  @override
  String get scanBatchTitle => 'Batch scanning';

  @override
  String get scanFinish => 'Finish';

  @override
  String get scanBatchGuide =>
      'Scan the next products. Choose destinations once for the whole batch.';

  @override
  String get scanBatchEmpty => 'Scanned products will appear here.';

  @override
  String get scanPremiumPreview => 'Premium feature preview';

  @override
  String get scanPreviewTitle => 'Scan your whole shop in one go';

  @override
  String get scanPreviewBody =>
      'The camera stays open and recognised products appear in one list. Choose destinations at the end and confirm everything once.';

  @override
  String get scanSampleYogurt => 'Natural yoghurt';

  @override
  String get scanSamplePasta => 'Wholewheat pasta';

  @override
  String get scanSampleYogurtMacro => '100 g: 62 kcal · P 4 g · F 3 g · C 5 g';

  @override
  String get scanSamplePastaMacro =>
      '100 g: 348 kcal · P 13 g · F 3 g · C 65 g';

  @override
  String get scanAllDestinations => 'Add all to';

  @override
  String get scanTrial => 'Explore Premium';

  @override
  String get scanPreviewNoCamera =>
      'This is a preview — the camera has not been started.';

  @override
  String get scanMealTypeAll => 'Meal type for all products';

  @override
  String get scanAdding => 'Adding products…';

  @override
  String get scanRecognising => 'Recognising…';

  @override
  String get scanReady => 'Ready to add with the batch';

  @override
  String get scanSaving => 'Adding…';

  @override
  String get scanDone => 'Done';

  @override
  String get scanTapComplete => 'Tap to complete product details';

  @override
  String get scanTapRetry => 'Error. Tap to retry.';

  @override
  String get scanWhere => 'Where would you like to add this product?';

  @override
  String get scanMultiHint => 'You can select several destinations at once.';

  @override
  String get scanNutritionMissingHint =>
      'Complete nutrition values were not found. After choosing a destination, you can complete the data from packaging photos.';

  @override
  String get scanDiaryDestination => 'Add to diary';

  @override
  String get scanDiaryDestinationHint => 'Choose an amount and meal type';

  @override
  String get scanCatalogueDestination => 'Add to product catalogue';

  @override
  String get scanCatalogueDestinationHint =>
      'Check the name, brand and nutrition';

  @override
  String get scanPantryDestination => 'Add to pantry';

  @override
  String get scanPantryDestinationHint => 'Save as 1 whole pack';

  @override
  String get scanNext => 'Next';

  @override
  String get catalogueNutritionMissing =>
      'Complete nutrition values could not be found online. Complete the data from packaging photos.';

  @override
  String get catalogueIncomplete =>
      'This product does not have nutrition values yet. Add it to the catalogue with label data to use it in the diary.';

  @override
  String get catalogueProductSearch => 'Search products...';

  @override
  String get catalogueNoMatch => 'No products match your search.';

  @override
  String get autocompleteCatalogue => 'app catalogue';

  @override
  String get autocompleteScanned => 'previously scanned';

  @override
  String get autocompleteHint =>
      'You can choose a suggestion or keep your own name.';

  @override
  String foodEntryPlanDate(String date) {
    return 'Your active plan does not cover the selected date ($date).';
  }

  @override
  String foodEntryKcalServing(String kcal) {
    return '$kcal kcal / serving';
  }

  @override
  String scanCameraError(String error) {
    return 'The camera could not be started. Check camera permission or enter the code manually.\n$error';
  }

  @override
  String scanBatchCameraError(String error) {
    return 'The camera could not be started. Check camera permission.\n$error';
  }

  @override
  String scanRetryError(String error) {
    return '$error Tap to try again.';
  }

  @override
  String scanRetrySavedError(String error) {
    return '$error Completed destinations will not be added again. Tap to retry.';
  }

  @override
  String scanAddedPoints(int points) {
    return 'Added to catalogue (+$points pt)';
  }

  @override
  String scanAddedCount(int count) {
    return 'Added $count products.';
  }

  @override
  String scanAddedPartial(int saved, int total) {
    return 'Added $saved of $total. Tap failed items to try again.';
  }

  @override
  String scanQueueCount(int count) {
    return 'Recognising products · $count waiting';
  }

  @override
  String scanDoneCount(int count) {
    return 'Done · $count products';
  }

  @override
  String scanAddAllCount(int count) {
    return 'Add all ($count)';
  }

  @override
  String scanCodeLabel(String code) {
    return 'Code: $code';
  }

  @override
  String scanDestinationsCount(int count) {
    return 'Add to $count destinations';
  }

  @override
  String scanPantryAddedName(String name) {
    return '$name added to pantry.';
  }

  @override
  String get diaryCustomWater => 'Custom amount';

  @override
  String get rewardProductSemantics =>
      'Reward: one Premium point for adding a new, unique product to the catalogue.';

  @override
  String get rewardProductTitle => 'Earn 1 Premium point';

  @override
  String get rewardProductBody =>
      'Scan a barcode or manually add a new, unique product to the catalogue.';

  @override
  String get rewardProductPoint => '+1 pt';

  @override
  String get productsMarketUnavailable =>
      'A verified price list is not available for this market.';

  @override
  String get home => 'Home';

  @override
  String get recipes => 'Recipes';

  @override
  String get shopping => 'Shopping';

  @override
  String get diary => 'Food diary';

  @override
  String get premium => 'Premium';

  @override
  String get profile => 'Profile';

  @override
  String get add => 'Add';

  @override
  String get newPlan => 'New plan';

  @override
  String get planMeals => 'Plan your meals';

  @override
  String get productDatabase => 'Food database';

  @override
  String get checkPrices => 'Check prices';

  @override
  String get promotions => 'Offers';

  @override
  String get currentOffers => 'Current offers';

  @override
  String get pantry => 'Pantry';

  @override
  String get whatYouHaveAtHome => 'What you have at home';

  @override
  String get planArchive => 'Archived plans';

  @override
  String get scanBarcode => 'Scan a barcode';

  @override
  String get batchScan => 'Scan multiple products';

  @override
  String get addRecipeWithAi => 'Add a recipe with AI';

  @override
  String get addMeal => 'Add a meal';

  @override
  String get addToPantry => 'Add to pantry';

  @override
  String get barcodeDestinations =>
      'Add to your food diary, food database or pantry';

  @override
  String get whatToAdd => 'What would you like to add?';

  @override
  String get scanProduct => 'Scan a product';

  @override
  String get batchDestinationHint =>
      'Choose where to save the whole batch and confirm once';

  @override
  String get aiRecipeSources => 'From a photo, text or link';

  @override
  String get recordCaloriesAndMacros => 'Record calories and macros';

  @override
  String get premiumTwoPoints => 'PREMIUM · 2 PTS';

  @override
  String recipeLoadError(String error) {
    return 'Could not load recipes: $error';
  }

  @override
  String recipeLoadMoreError(String error) {
    return 'Could not load more recipes: $error';
  }

  @override
  String get recipeImportInProgress => 'AI is adding your recipe';

  @override
  String get recipeAuthorRanking => 'Recipe creator leaderboard';

  @override
  String get recipeSearchHint => 'Recipe, creator or ingredient...';

  @override
  String get clearSearch => 'Clear search';

  @override
  String get recipeFavourites => 'Favourites';

  @override
  String get recipeMine => 'Mine';

  @override
  String get recipeNew => 'New';

  @override
  String get recipeCommunity => 'Community';

  @override
  String get moreFilters => 'More';

  @override
  String get loadingMore => 'Loading…';

  @override
  String get showMoreRecipes => 'Show more recipes';

  @override
  String get addRecipe => 'Add a recipe';

  @override
  String get withAi => 'With AI';

  @override
  String get takeRecipePhoto => 'Take a photo';

  @override
  String get recipePhotoHint => 'Of a recipe or a finished dish';

  @override
  String get pasteText => 'Paste text';

  @override
  String get pasteLink => 'Paste a link';

  @override
  String get addManually => 'Add manually';

  @override
  String get filters => 'Filters';

  @override
  String get clearFilters => 'Clear';

  @override
  String get sortRecipes => 'Sort by';

  @override
  String get sortAlphabetically => 'Alphabetical';

  @override
  String get sortCaloriesLow => 'Calories: lowest first';

  @override
  String get sortCaloriesHigh => 'Calories: highest first';

  @override
  String get sortQuickest => 'Quickest first';

  @override
  String get recipeDiet => 'Diet';

  @override
  String get allRecipes => 'All';

  @override
  String get recipeMealType => 'Meal type';

  @override
  String get filterBreakfast => 'Breakfast';

  @override
  String get filterLunch => 'Lunch';

  @override
  String get filterDinner => 'Dinner';

  @override
  String get filterSnacks => 'Snacks';

  @override
  String get filterDesserts => 'Desserts';

  @override
  String get recipeDifficulty => 'Difficulty';

  @override
  String get anyDifficulty => 'Any';

  @override
  String get filterEasy => 'Easy';

  @override
  String get filterMedium => 'Medium';

  @override
  String get filterHard => 'Hard';

  @override
  String get showResults => 'Show results';

  @override
  String recipeCardSummary(int minutes, int calories) {
    return '$minutes min • $calories kcal/serving';
  }

  @override
  String get noRecipes => 'No recipes found';

  @override
  String get noRecipesHint => 'Check the recipe, creator or ingredient name.';

  @override
  String get mealBreakfast => 'breakfast';

  @override
  String get mealLunch => 'lunch';

  @override
  String get mealDinner => 'dinner';

  @override
  String get mealSnack => 'snack';

  @override
  String get mealDessert => 'dessert';

  @override
  String get difficultyEasy => 'easy';

  @override
  String get difficultyMedium => 'medium';

  @override
  String get difficultyHard => 'hard';

  @override
  String get dietNoRestrictions => 'No restrictions';

  @override
  String get dietVegetarian => 'Vegetarian';

  @override
  String get dietVegan => 'Vegan';

  @override
  String get dietGlutenFree => 'Gluten-free';

  @override
  String get dietKeto => 'Keto';

  @override
  String get dietHighProtein => 'High-protein';

  @override
  String get dietNoRestrictionsDescription => 'Eat all the foods you enjoy';

  @override
  String get dietVegetarianDescription => 'Meals without meat or fish';

  @override
  String get dietVeganDescription => '100% plant-based meals';

  @override
  String get dietGlutenFreeDescription => 'Meals without gluten';

  @override
  String get dietKetoDescription => 'Low-carbohydrate meals';

  @override
  String get dietHighProteinDescription =>
      'For active lifestyles and building muscle';

  @override
  String get planStatusActive => 'active';

  @override
  String get planStatusDraft => 'draft';

  @override
  String get planStatusCompleted => 'completed';

  @override
  String get planStatusArchived => 'archived';

  @override
  String get authCaptchaRequired => 'Please confirm you are not a robot first.';

  @override
  String get authLoginFailed => 'Sign-in failed';

  @override
  String get authWelcomeBack => 'Welcome back!';

  @override
  String get authLoginPrompt => 'Sign in to your account';

  @override
  String get authEmail => 'Email';

  @override
  String get authEnterEmail => 'Enter your email address';

  @override
  String get authEnterValidEmail => 'Enter a valid email address';

  @override
  String get authPassword => 'Password';

  @override
  String get authEnterPassword => 'Enter your password';

  @override
  String get authPasswordMinSix =>
      'Your password must contain at least 6 characters';

  @override
  String get authSignIn => 'Sign in';

  @override
  String get authForgotPasswordQuestion => 'Forgot your password?';

  @override
  String get authOr => 'or';

  @override
  String get authContinueApple => 'Continue with Apple';

  @override
  String get authContinueGoogle => 'Continue with Google';

  @override
  String get authNoAccount => 'Don\'t have an account?';

  @override
  String get authRegister => 'Sign up';

  @override
  String authDocumentOpenFailed(String url) {
    return 'Could not open: $url';
  }

  @override
  String get authAcceptTermsRequired =>
      'Accept the terms to create an account.';

  @override
  String get authRegistrationFailed => 'Registration failed';

  @override
  String get authCreateAccount => 'Create an account';

  @override
  String get authJoinPlanner => 'Join Meal Planner and plan smarter';

  @override
  String get authDisplayName => 'Name / Username';

  @override
  String get authEnterName => 'Enter your name';

  @override
  String get authRepeatPassword => 'Repeat password';

  @override
  String get authConfirmPassword => 'Confirm your password';

  @override
  String get authPasswordsMismatch => 'The passwords do not match';

  @override
  String get authAcceptPrefix => 'I accept the ';

  @override
  String get authTerms => 'terms of use';

  @override
  String get authAnd => ' and ';

  @override
  String get authPrivacyPolicy => 'privacy policy';

  @override
  String get authAlreadyAccount => 'Already have an account?';

  @override
  String get authValidEmailRequired => 'Enter a valid email address.';

  @override
  String get authCodeSixDigits => 'The code must contain exactly 6 digits.';

  @override
  String get authNewPasswordMinEight =>
      'Your new password must contain at least 8 characters.';

  @override
  String get authPasswordChanged =>
      'Your password has been changed. Sign in with your new password.';

  @override
  String get authForgotPasswordTitle => 'Forgot password';

  @override
  String get authResetDescription =>
      'Enter your email address and we will send you a password reset code.';

  @override
  String get authEmailAddress => 'Email address';

  @override
  String get authSendCode => 'Send code';

  @override
  String authResetCodeSentTo(String email) {
    return 'If an account with the address $email exists, we have sent it a 6-digit code. Enter the code below along with your new password.';
  }

  @override
  String get authCode => 'Code';

  @override
  String get authNewPassword => 'New password';

  @override
  String get authChangePassword => 'Change password';

  @override
  String get authUseDifferentEmail => 'Use a different email';

  @override
  String get authNewCodeSent => 'A new code has been sent.';

  @override
  String get authCodeSendFailed => 'Could not send the code.';

  @override
  String get authVerifyEmailTitle => 'Verify your email';

  @override
  String authVerificationSentTo(String email) {
    return 'We have sent a 6-digit code to\n$email';
  }

  @override
  String get authVerify => 'Verify';

  @override
  String get authResendCode => 'Send code again';

  @override
  String get onboardingAllergenGluten => 'Gluten';

  @override
  String get onboardingAllergenLactose => 'Lactose';

  @override
  String get onboardingAllergenNuts => 'Nuts';

  @override
  String get onboardingAllergenEggs => 'Eggs';

  @override
  String get onboardingAllergenSoy => 'Soya';

  @override
  String get onboardingAllergenCelery => 'Celery';

  @override
  String get onboardingAllergenFish => 'Fish';

  @override
  String get onboardingAllergenShellfish => 'Shellfish';

  @override
  String get onboardingSelectStoreRequired => 'Choose your preferred shop!';

  @override
  String get onboardingPreferencesSaveFailed =>
      'Could not save your preferences';

  @override
  String get onboardingBack => 'Back';

  @override
  String get onboardingDone => 'Done!';

  @override
  String get onboardingNext => 'Next';

  @override
  String get onboardingStoreTitle => 'Where do you shop?';

  @override
  String get onboardingStoreDescription =>
      'Choose the shop you use most often. We will tailor your meal plan and products to its range.';

  @override
  String onboardingStoresLoadFailed(String error) {
    return 'Could not load shops:\n$error';
  }

  @override
  String get onboardingAllergensTitle => 'Do you have any allergies?';

  @override
  String get onboardingAllergensDescription =>
      'Choose the ingredients you cannot eat. Recipes containing these allergens will not be suggested.';

  @override
  String get onboardingDietTitle => 'Choose your diet';

  @override
  String get onboardingDietDescription =>
      'We will tailor recipe recommendations to the way you eat.';

  @override
  String get onboardingHouseholdTitle => 'How many people do you cook for?';

  @override
  String get onboardingHouseholdDescription =>
      'We will adjust ingredient quantities in recipes and portions on your shopping list automatically.';

  @override
  String get onboardingCookingForMyself => 'I only cook for myself';

  @override
  String onboardingHouseholdCount(int count) {
    return 'People in your household: $count';
  }

  @override
  String get onboardingProfileTitle => 'Your profile and goal';

  @override
  String get onboardingProfileDescription =>
      'Would you like to calculate your calorie needs and enter your weight, height and goal now? You can also do this later in your profile.';

  @override
  String get onboardingOpenCalorieCalculator => 'Open the calorie calculator';

  @override
  String get onboardingProfileOptional =>
      'This step is optional. Choose ‘Next’ to skip it.';

  @override
  String get onboardingPantryTitle => 'What is in your pantry?';

  @override
  String get onboardingPantryDescription =>
      'Add the products you already have at home to help you find recipes without extra shopping.';

  @override
  String get onboardingAddPantryProducts => 'Add products to your pantry';

  @override
  String get onboardingPantryOptional => 'You can skip this step.';

  @override
  String get onboardingPremiumOrPoints => 'PREMIUM • OR POINTS';

  @override
  String get onboardingAiTitle => 'Have a recipe? Add it in moments';

  @override
  String get onboardingAiDescription =>
      'In Recipes, choose ‘Add recipe’. AI will prepare the ingredients and steps from:';

  @override
  String get onboardingAiImport => 'Import a recipe with AI';

  @override
  String get onboardingAiPhoto => 'A photo';

  @override
  String get onboardingAiPhotoDescription =>
      'Photograph a written recipe or a finished dish.';

  @override
  String get onboardingAiText => 'Text';

  @override
  String get onboardingAiTextDescription =>
      'Paste a description or just enter the name of a dish.';

  @override
  String get onboardingAiLink => 'A link';

  @override
  String get onboardingAiLinkDescription =>
      'Paste a website address or share it from another app.';

  @override
  String get onboardingAiShareExample =>
      'For example, in TikTok choose ‘Share’ → Meal Planner Polska. Once your recipe is ready, you can ask AI to change it, for example to make it lactose-free.';

  @override
  String get onboardingAiPointCosts =>
      'Adding a recipe costs 2 points without a Premium subscription. Editing it with AI afterwards costs 1 point.';

  @override
  String get welcomeAllSet => 'You are all set!';

  @override
  String welcomePointsIntro(int points) {
    return 'Here are $points premium points to get you started — our thanks for creating an account and setting up the app.';
  }

  @override
  String get welcomeAiPointDescription =>
      'For 2 points, AI can turn a link or photo into a recipe for you.';

  @override
  String get welcomeTryNow => 'Try it now';

  @override
  String get welcomeScanFirstProduct => 'Scan your first product';

  @override
  String get welcomeAddRecipeLink => 'Add a recipe from a link';

  @override
  String get welcomeStart => 'Let\'s get started';

  @override
  String get priceCompareTitle => 'Price comparison';

  @override
  String get priceCompareSourcesTooltip => 'Price and brand sources';

  @override
  String get priceCompareRetry => 'Try again';

  @override
  String get priceCompareEmpty => 'No prices available to compare.';

  @override
  String get priceCompareIntro =>
      'We compare the cost of the whole shopping list. “~” means an estimated price. Check current prices and availability with your chosen shop.';

  @override
  String priceCompareSwitchSuccess(String storeName) {
    return 'Plan switched to $storeName';
  }

  @override
  String get priceCompareSwitchError => 'Could not switch the shop';

  @override
  String priceCompareLoadError(String error) {
    return 'Could not load the comparison: $error';
  }

  @override
  String get priceCompareCurrencyError =>
      'Prices in different currencies cannot be compared. Refresh the data and try again.';

  @override
  String get priceCompareCheapestEstimate => 'Lowest estimate';

  @override
  String get priceCompareCheapest => 'Cheapest';

  @override
  String priceCompareIncomplete(int count) {
    return 'Incomplete basket • prices missing for $count products';
  }

  @override
  String priceCompareProductCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count products',
      one: '1 product',
    );
    return '$_temp0';
  }

  @override
  String get priceCompareEstimatedPrices => 'estimated prices';

  @override
  String priceCompareSavings(String amount) {
    return 'difference up to $amount';
  }

  @override
  String get priceCompareExpandHint => 'tap to view the list';

  @override
  String priceCompareMissing(String names) {
    return 'Prices unavailable for: $names. The total only includes items with a price.';
  }

  @override
  String get priceCompareEstimate => 'estimated price';

  @override
  String get shoppingSubstituteFailed => 'Could not replace the product.';

  @override
  String shoppingSubstitutePack(String quantity, String unit) {
    return '$quantity $unit pack';
  }

  @override
  String get priceCompareUnpricedTotal => 'Total unavailable';

  @override
  String priceCompareMissingUnpriced(String names) {
    return 'Prices unavailable for: $names. The whole basket cannot be priced yet.';
  }

  @override
  String priceComparePackages(int count, String quantity, String unit) {
    return 'To buy: $count × $quantity $unit';
  }

  @override
  String priceCompareVerified(String date) {
    return 'price checked on $date';
  }

  @override
  String get priceCompareSwitchStore => 'Switch plan to this shop';

  @override
  String get priceCompareSourceTitle => 'Where do prices come from?';

  @override
  String get priceCompareSourceBody =>
      'The comparison uses product prices in the catalogue for your market. A price without a checked date is an estimate, not a confirmed shop offer. Each price shows its quantity and unit. “~” marks estimates. Confirm current prices and availability with the shop. Prices in PLN and GBP are never compared or converted.';

  @override
  String get priceCompareSourceClose => 'Got it';

  @override
  String get priceCompareUnitPack => 'pack';

  @override
  String get priceCompareUnitServing => 'serving';

  @override
  String get priceCompareUnitPiece => 'pcs';

  @override
  String get priceCompareUnitTeaspoon => 'tsp';

  @override
  String get priceCompareUnitCup => 'cup';

  @override
  String homeBatchCompleted(int count) {
    return 'Processed: $count products.';
  }

  @override
  String get homeShopFallback => 'Shop';

  @override
  String homeGreeting(String name) {
    return 'Hi, $name!';
  }

  @override
  String get homeUserFallback => 'there';

  @override
  String get homeCookingToday => 'What are we cooking today?';

  @override
  String get homeQuickActions => 'Quick actions';

  @override
  String get homePlanLoading => 'Loading your meal plan…';

  @override
  String get homePlanLoadError => 'Could not load your meal plan.';

  @override
  String get homeNextPlan => 'Your next meal plan';

  @override
  String get homeActivePlan => 'Your active meal plan';

  @override
  String get homeDetails => 'Details';

  @override
  String homePlanChip(int day, int month, int days) {
    return 'Plan $day/$month · $days days';
  }

  @override
  String get homeNutritionLoading => 'Loading calories and macros…';

  @override
  String get homeNutritionError => 'Could not load calories and macros.';

  @override
  String get homeEatenToday => 'Eaten today';

  @override
  String get homeProtein => 'Protein';

  @override
  String get homeFat => 'Fat';

  @override
  String get homeCarbsShort => 'Carbs';

  @override
  String get homeRetry => 'Try again';

  @override
  String get homeTipOfTheDay => 'TIP OF THE DAY';

  @override
  String get homeHydration => 'Hydration';

  @override
  String get homeDataLoading => 'Loading data…';

  @override
  String get homeDataError => 'Could not load the data';

  @override
  String homeWaterProgress(int amount, int goal, int percent) {
    return '$amount of $goal ml · $percent% of goal';
  }

  @override
  String get homeWeeklyContest => 'Weekly challenge';

  @override
  String get homeWeeklyContestHint =>
      'Add the most recipes this week and earn premium points — 3 for 1st place, 2 for 2nd and 1 for 3rd.';

  @override
  String homePlanStarts(String date) {
    return 'Plan starts on $date';
  }

  @override
  String homePlanDay(int day, int days) {
    return 'Day $day of $days';
  }

  @override
  String get homeViewPlan => 'View plan';

  @override
  String get homeNoPlan => 'No active meal plan';

  @override
  String get homeNoPlanHint =>
      'Generate a balanced meal plan, keep costs down and create a smart shopping list.';

  @override
  String get homeCreatePlan => 'Create a new meal plan';

  @override
  String get homeAiPointsTitle => 'You have points for an AI recipe import';

  @override
  String get homeAiPointsHint =>
      'Add a recipe from a photo, text or link — no subscription needed.';

  @override
  String get homeTryAction => 'Try it';

  @override
  String get homeBatchTitle => 'Scanning several products?';

  @override
  String get homeBatchHint =>
      'With Premium, scan the whole batch without closing the camera.';

  @override
  String get homeViewPremium => 'Explore Premium';

  @override
  String get homeAutoWeekTitle => 'Let next week plan itself';

  @override
  String get homeAutoWeekHint =>
      'Premium prepares a weekly meal plan and an optional shopping list.';

  @override
  String get homeCheckAction => 'Take a look';

  @override
  String get homeHideHint => 'Dismiss';

  @override
  String get planSelectStoreRequired =>
      'Choose a shop before generating your plan!';

  @override
  String get planStoreMarketError =>
      'Choose a shop available for your account\'s country. Refresh the shops and try again.';

  @override
  String get planKcalValidation =>
      'Enter between 800 and 6000 kcal per person per day.';

  @override
  String get planGenerateError => 'Could not generate the plan';

  @override
  String get planFreeLimitTitle => 'Free account limit';

  @override
  String get planUnderstood => 'Got it';

  @override
  String get planViewPremium => 'View Premium';

  @override
  String get planReadyTitle => 'Your plan is ready';

  @override
  String planReadyFor(int days, int people) {
    String _temp0 = intl.Intl.pluralLogic(
      people,
      locale: localeName,
      other: '$people people',
      one: '1 person',
    );
    return 'Your $days-day plan for $_temp0 is ready.';
  }

  @override
  String get planEstimatedBudget => 'Estimated minimum shopping cost';

  @override
  String get planShoppingLimitReached =>
      'Your plan is ready, but you have already used this week\'s free shopping list. Create another list next week or with Premium.';

  @override
  String get planStandardWeeklyLimit => 'Standard account: one new plan a week';

  @override
  String get planWeeklyLimitExplanation =>
      'Your limit resets on Monday. Deleting a plan does not reset it. Premium lets you create unlimited plans.';

  @override
  String get planExplorePremium => 'Explore Premium';

  @override
  String get planViewAction => 'View plan';

  @override
  String get planNewTitle => 'New meal plan';

  @override
  String get planChooseStore => 'Choose a shop';

  @override
  String get planPriceEstimateHint =>
      'The plan cost is an estimate. Check current product prices and availability with your chosen shop.';

  @override
  String planDurationTitle(int days) {
    return 'Plan duration: $days days';
  }

  @override
  String planDays(int days) {
    return '$days days';
  }

  @override
  String get planOneDay => '1 day';

  @override
  String planHouseholdTitle(int people) {
    String _temp0 = intl.Intl.pluralLogic(
      people,
      locale: localeName,
      other: '$people people',
      one: '1 person',
    );
    return 'Cooking for: $_temp0';
  }

  @override
  String get planHouseholdHint =>
      'From 1 to 8 people. Taken from your profile by default; changes only apply to this plan.';

  @override
  String get planMealTypes => 'Meal types';

  @override
  String get planDailyCalories => 'Daily calorie goal';

  @override
  String get planCaloriesField => 'Target kcal / day / person';

  @override
  String get planCaloriesExample => 'e.g. 2000';

  @override
  String get planCaloriesHint =>
      'Uses your calculator goal; defaults to 2000 kcal if none is saved.';

  @override
  String get planBudgetOptional => 'Maximum budget (optional)';

  @override
  String get planBudgetField => 'Maximum budget';

  @override
  String get planBudgetExample => 'e.g. 150.00';

  @override
  String get planIncludePantry => 'Include pantry';

  @override
  String get planPantryHint =>
      'Products you already have appear at the end of the list for £0. Any missing quantity is still added to your shopping.';

  @override
  String get planIngredientPreferences => 'Likes / Dislikes';

  @override
  String get planIngredientPreferencesHint =>
      'Premium · one tailored meal a day';

  @override
  String get planGenerating => 'Generating...';

  @override
  String get planGenerate => 'Generate plan!';

  @override
  String get planGeneratingTitle => 'Putting together your meal plan...';

  @override
  String get planGeneratingHint =>
      'We reuse ingredients across meals to reduce your shopping cost.';

  @override
  String get planActivated =>
      'Plan confirmed! Your shopping list has been generated.';

  @override
  String get planGenericError => 'Something went wrong';

  @override
  String planSwapTitle(String recipeName) {
    return 'Replace: $recipeName';
  }

  @override
  String get planSwapSearch => 'Find a dish';

  @override
  String get planSwapSearchHint => 'Enter a recipe name';

  @override
  String get planSwapLoadError => 'Could not load recipes. Please try again.';

  @override
  String get planSwapNoAlternatives => 'No other dishes in this category';

  @override
  String get planSwapNoSearchResults => 'No dishes found with this name';

  @override
  String get planSwapSuccess => 'Recipe replaced';

  @override
  String get planSwapError => 'Could not replace the recipe';

  @override
  String get planFinishedTitle => 'Plan finished';

  @override
  String get planArchivePremiumRequired =>
      'Archive previews are available with Premium.';

  @override
  String get planFinishedHint => 'This plan has finished.';

  @override
  String get planOpenArchive => 'Open archive';

  @override
  String get planCreateNew => 'Create a new plan';

  @override
  String get planViewTitle => 'Meal plan';

  @override
  String get planNotFound => 'No meal plan found. Generate a new plan.';

  @override
  String get planStoreFallback => 'Shop';

  @override
  String get planDeleteTitle => 'Delete plan';

  @override
  String get planDeleteQuestion =>
      'Are you sure you want to delete this meal plan? On a standard account, deleting a plan does not reset the limit of one new plan a week.';

  @override
  String get planCancel => 'Cancel';

  @override
  String get planDeleteError => 'Could not delete the plan';

  @override
  String get planDelete => 'Delete';

  @override
  String planDay(int day) {
    return 'Day $day';
  }

  @override
  String get planResumeArchive => 'Archive · resume plan';

  @override
  String get planChangeSettings => 'Change settings';

  @override
  String get planActivate => 'Confirm plan';

  @override
  String get planGoShopping => 'Go to shopping';

  @override
  String get manualRecipeDiscardTitle => 'Discard changes?';

  @override
  String get manualRecipeUnsaved =>
      'The recipe details you entered have not been saved yet.';

  @override
  String get manualRecipeStay => 'Stay';

  @override
  String get manualRecipeDiscard => 'Discard';

  @override
  String get manualRecipeNutritionRequired =>
      'This product is missing nutritional values. Choose another result or add the product to the database with the details from its label.';

  @override
  String get manualRecipeIngredientRequired => 'Add at least one ingredient';

  @override
  String get manualRecipeStepRequired => 'Add at least one preparation step';

  @override
  String get manualRecipeTitle => 'Add a recipe manually';

  @override
  String get manualRecipeName => 'Recipe name';

  @override
  String get manualRecipeNameRequired => 'Enter a name';

  @override
  String get manualRecipeDescription => 'Short description (optional)';

  @override
  String get manualRecipeMealType => 'Meal type';

  @override
  String get manualRecipePreparationMinutes => 'Preparation (min)';

  @override
  String get manualRecipeCookingMinutes => 'Cooking (min)';

  @override
  String get manualRecipeServings => 'Servings';

  @override
  String get manualRecipeIngredients => 'Ingredients';

  @override
  String get manualRecipeNoIngredients => 'No ingredients added';

  @override
  String get manualRecipeSteps => 'Preparation steps';

  @override
  String get manualRecipeAddStep => 'Add a step';

  @override
  String get manualRecipeStepHint => 'Describe this step...';

  @override
  String get manualRecipeSubmitToCatalogue => 'Submit to the shared catalogue';

  @override
  String get manualRecipePublicHint =>
      'Once approved by an administrator, it will be visible to everyone and count towards the weekly competition.';

  @override
  String get manualRecipeSave => 'Save recipe';

  @override
  String get manualRecipeChooseIngredient => 'Choose an ingredient';

  @override
  String get manualRecipeIngredientSearch =>
      'Search the catalogue and product database...';

  @override
  String get manualRecipeIngredientSearchHint =>
      'Enter at least 2 characters to find an ingredient.';

  @override
  String get manualRecipeIngredientNotFound =>
      'Product not found. First add it to the product database with the nutritional values from its label.';

  @override
  String get manualRecipeLabelRequired => 'Label details required';

  @override
  String get manualRecipeNutritionMissing =>
      'Nutritional values are incomplete';

  @override
  String get aiRecipePhotoLoadFailed => 'Could not load the photo';

  @override
  String get aiRecipeChooseGallery => 'Choose from gallery';

  @override
  String get aiRecipeServerUnavailable =>
      'AI import is not available on the server yet. Complete the backend deployment on Render.';

  @override
  String get aiRecipePremiumOrPointsTitle => 'You need Premium or points';

  @override
  String get aiRecipeCancel => 'Cancel';

  @override
  String get aiRecipeBuyPoints => 'Buy points';

  @override
  String get aiRecipeBackToApp => 'Back to the app';

  @override
  String get aiRecipeTitle => 'Add a recipe with AI';

  @override
  String get aiRecipePhoto => 'Photo';

  @override
  String get aiRecipeLink => 'Link';

  @override
  String get aiRecipeAccepting => 'Submitting your recipe...';

  @override
  String get aiRecipeAcceptingHint =>
      'You can get back to using the app in a moment.';

  @override
  String get aiRecipePreparing => 'Your recipe is being prepared';

  @override
  String get aiRecipeReady => 'Your recipe is ready';

  @override
  String get aiRecipeRecognitionFailed => 'Could not recognise the recipe';

  @override
  String get aiRecipeBackgroundHint =>
      'You can leave this screen. We will let you know the result in the app and, if push notifications are enabled, on your phone too.';

  @override
  String get aiRecipeFindInMine =>
      'You can also find it in the My recipes tab.';

  @override
  String get aiRecipeRetrySentence => 'Please try again.';

  @override
  String get aiRecipeOpen => 'Open recipe';

  @override
  String get aiRecipeEditOnePoint => 'Adjust with AI · 1 pt';

  @override
  String get aiRecipeAddAnother => 'Add another recipe';

  @override
  String get aiRecipePasteTextTitle => 'Paste your recipe text';

  @override
  String get aiRecipeTextDescription =>
      'Paste a recipe from your notes, a message or a website — AI will recognise its ingredients and steps. Or just enter a dish name (such as \"chicken soup\" or \"lasagne\") and AI will create a complete recipe from scratch.';

  @override
  String get aiRecipeTextHint =>
      'e.g. \"chicken soup\", or a full recipe with ingredients and steps...';

  @override
  String get aiRecipeRecognise => 'Recognise recipe';

  @override
  String get aiRecipePhotoTitle => 'Take a recipe photo';

  @override
  String get aiRecipePhotoDescription =>
      'Photograph a recipe card, a cookbook page or a finished dish — AI will then estimate a likely recipe.';

  @override
  String get aiRecipeTapAddPhoto => 'Tap to add a photo';

  @override
  String get aiRecipePasteLinkTitle => 'Paste a recipe link';

  @override
  String get aiRecipeLinkDescription =>
      'Food blog, TikTok, Instagram — AI will try to recognise the recipe from the page content. If the recipe is only spoken in a video and not included in its description, recognition may not work.';

  @override
  String get aiRecipePremiumFeature => 'Premium feature';

  @override
  String get aiRecipePremiumDescription =>
      'Add your own recipes with AI from text or a photo with an active Premium subscription — or for 2 premium points without a subscription.';

  @override
  String get aiRecipePremiumHint =>
      'Explore the other Premium features or buy a points pack.';

  @override
  String get shoppingStoresLoadFailed => 'Could not load the stores.';

  @override
  String get shoppingChooseStore => 'Choose a store for the new list';

  @override
  String get shoppingCreateFailed => 'Could not create the shopping list.';

  @override
  String get shoppingShareTitle => 'Share shopping list';

  @override
  String get shoppingShareHint =>
      'Enter the username of the person you want to share the list with. They need a Meal Planner Polska account and must accept the invitation before they can view the list.';

  @override
  String get shoppingUsername => 'Username';

  @override
  String get shoppingSendInvite => 'Send invitation';

  @override
  String shoppingInviteSent(String nickname) {
    return 'Invitation sent to $nickname';
  }

  @override
  String get shoppingMergeTitle => 'Merge shopping lists';

  @override
  String shoppingMergeHint(String storeName) {
    return 'Choose the $storeName lists you want to merge with the current list. The previous lists will be removed from Shopping, but your meal plans will stay unchanged.';
  }

  @override
  String shoppingListNumber(int number) {
    return 'List $number';
  }

  @override
  String shoppingListDate(int day, int month, int count) {
    return '$day/$month · $count items';
  }

  @override
  String get shoppingMerge => 'Merge';

  @override
  String get shoppingMergeSuccess => 'Lists merged';

  @override
  String get shoppingMergeFailed => 'Could not merge the lists';

  @override
  String get shoppingChooseSubstitute => 'Choose a substitute';

  @override
  String get shoppingNoSubstitutes => 'No available alternatives in this shop.';

  @override
  String get shoppingCatalogueAlternatives => 'Catalogue alternatives';

  @override
  String get shoppingStoreAlternatives => 'Selected shop offers';

  @override
  String get shoppingCatalogueAvailability =>
      'Check shop availability — estimated price.';

  @override
  String shoppingSubstituteFor(String name) {
    return 'For product: $name';
  }

  @override
  String get shoppingPriceUnknown => 'Price unavailable';

  @override
  String shoppingSubstituteChanged(String name) {
    return 'Replaced with: $name';
  }

  @override
  String get shoppingListTitle => 'Shopping list';

  @override
  String get shoppingCreateAndAdd => 'Create a list and add a product';

  @override
  String get shoppingAddProduct => 'Add a product to the list';

  @override
  String get shoppingInvites => 'Invitations';

  @override
  String get shoppingShare => 'Share';

  @override
  String get shoppingRefresh => 'Refresh';

  @override
  String get shoppingDeleteList => 'Delete list';

  @override
  String get shoppingMergeLists => 'Merge lists';

  @override
  String get shoppingCompare => 'Compare';

  @override
  String get shoppingExport => 'Export';

  @override
  String get shoppingInPantry => 'In your pantry';

  @override
  String get shoppingOther => 'Other';

  @override
  String shoppingPantryCount(int count, String amount) {
    return 'You already have $count items · $amount';
  }

  @override
  String shoppingBoughtCount(int checked, int total) {
    return '$checked of $total bought';
  }

  @override
  String shoppingDeleteTitle(int number) {
    return 'Delete list $number?';
  }

  @override
  String shoppingDeleteHint(String storeName) {
    return 'The shopping list for $storeName and all its items will be permanently deleted. Your meal plan will stay unchanged. Deleting a list does not reset the weekly limit on a standard account.';
  }

  @override
  String get shoppingDelete => 'Delete';

  @override
  String get shoppingDeleted => 'List deleted';

  @override
  String get shoppingDeleteFailed => 'Could not delete the list';

  @override
  String get shoppingHaveEverything => 'You have everything on the list';

  @override
  String get shoppingCompleteHint =>
      'Move the products you bought to your pantry so the app can suggest recipes using what you have at home.';

  @override
  String get shoppingMovePantry => 'Move to pantry';

  @override
  String get shoppingCompleteWithoutPantry => 'Finish without moving';

  @override
  String get shoppingCompleteFailed => 'Could not complete the list';

  @override
  String shoppingCompleteMoved(int count) {
    return 'Shopping complete. $count products were moved to your pantry.';
  }

  @override
  String get shoppingCompleteSuccess => 'Shopping complete.';

  @override
  String shoppingProgressCount(int checked, int total) {
    return '$checked of $total items';
  }

  @override
  String get shoppingEverythingBought => 'Everything bought';

  @override
  String shoppingUnknownRemaining(String amount) {
    return 'From ~$amount · some prices unavailable';
  }

  @override
  String shoppingRemaining(String amount) {
    return 'Left to pay: ~$amount';
  }

  @override
  String shoppingBasketTotal(String basket, String total) {
    return 'in basket: $basket of ~$total';
  }

  @override
  String get shoppingItemSaveFailed => 'Could not save the item.';

  @override
  String shoppingPackageBuy(int count, String quantity, String unit) {
    return 'Buy: $count × $quantity $unit';
  }

  @override
  String get shoppingSubstituteBadge => 'SUBSTITUTE';

  @override
  String shoppingPromotionBadge(int percent) {
    return 'OFFER -$percent%';
  }

  @override
  String get shoppingEmptyTitle => 'No active shopping list';

  @override
  String get shoppingEmptyHint =>
      'Tap +, choose a store and add your first product. You can also generate a list from a meal plan.';

  @override
  String get shoppingListInvites => 'List invitations';

  @override
  String shoppingEstimatedTotal(String amount) {
    return 'Estimated cost: $amount';
  }

  @override
  String get shoppingFriendReadOnly => 'Friend\'s list preview — read-only';

  @override
  String get priceCompareListSwitchStore => 'Switch list to this shop';

  @override
  String priceCompareListSwitchSuccess(String storeName) {
    return 'List switched to $storeName';
  }

  @override
  String get shoppingNoItems => 'No items on the list';

  @override
  String get productsTitle => 'Products';

  @override
  String get productsPriceSources => 'Price and brand sources';

  @override
  String get productsShopTab => 'Shop';

  @override
  String get productsCatalogueTab => 'Catalogue';

  @override
  String get productsMineTab => 'My products';

  @override
  String get productsScan => 'Scan barcode';

  @override
  String get productsBatchScan => 'Scan multiple products';

  @override
  String get productsBrandSearch => 'Search for a product or brand…';

  @override
  String get productsClear => 'Clear';

  @override
  String get productsRetry => 'Try again';

  @override
  String get productsNotFound => 'No products found.';

  @override
  String get productsShowMore => 'Show more';

  @override
  String get productsSearch => 'Search for a product...';

  @override
  String get productsNoShop => 'No shop selected';

  @override
  String get productsChooseShop =>
      'To browse products and prices, select a shop in your profile or from the list above.';

  @override
  String get productsError => 'Something went wrong';

  @override
  String get productsEmpty => 'No products';

  @override
  String get productsChangeSearch => 'Try a different search.';

  @override
  String get productsUnknown => 'Unknown product';

  @override
  String get productsUnavailable => 'unavailable';

  @override
  String get productsDeleteTitle => 'Delete product?';

  @override
  String get productsCancel => 'Cancel';

  @override
  String get productsDelete => 'Delete';

  @override
  String get productsAdd => 'Add product';

  @override
  String get productsNothingSubmitted =>
      'You haven\'t submitted any products yet.';

  @override
  String get productsSubmitHint =>
      'Tap “Add product” below to submit something\nmissing from the catalogue.';

  @override
  String get productsApproved => 'In catalogue';

  @override
  String get productsRejected => 'Rejected';

  @override
  String get productsPending => 'Awaiting approval';

  @override
  String get productsEdit => 'Edit';

  @override
  String get productsEstimatedPrice => 'estimated price';

  @override
  String get productsUnknownQuantity => '/ quantity unknown';

  @override
  String get diaryTitle => 'Calorie diary';

  @override
  String get diaryLoadError => 'Couldn\'t load your diary.';

  @override
  String get diaryPreviousDay => 'Previous day';

  @override
  String get diaryNextDay => 'Next day';

  @override
  String get diaryToday => 'Back to today';

  @override
  String get diaryRemainingKcal => 'kcal remaining';

  @override
  String get diaryActivity => 'Add activity';

  @override
  String get diaryActivityName => 'What did you do?';

  @override
  String get diaryActivityHint => 'e.g. running, cycling, gym';

  @override
  String get diaryBurnedCalories => 'Calories burned';

  @override
  String get diaryOptionalDuration => 'Duration (optional)';

  @override
  String get diaryActivityInvalid =>
      'Enter an activity name and calories burned.';

  @override
  String get diaryRecipeNoIngredients =>
      'This recipe has no ingredients to edit.';

  @override
  String get diaryUpdatedNutrition => 'Entry nutrition updated';

  @override
  String get diarySaveError => 'Couldn\'t save your changes';

  @override
  String get diaryEditAmount => 'Edit amount';

  @override
  String get diaryInvalidAmount => 'Enter a valid amount';

  @override
  String get diarySave => 'Save';

  @override
  String get diaryAmountUpdated => 'Amount and nutrition updated';

  @override
  String get diaryAmountSaveError => 'Couldn\'t save the amount';

  @override
  String get diaryLoadingWater => 'Loading hydration…';

  @override
  String get diaryWaterError => 'Couldn\'t load hydration.';

  @override
  String get diaryHydration => 'Hydration';

  @override
  String get diaryUndoGlass => 'Undo a glass';

  @override
  String get diaryWaterQuestion => 'How much did you drink?';

  @override
  String get diaryWaterHint => 'e.g. 300';

  @override
  String get diaryWaterInvalid => 'Enter the number of millilitres.';

  @override
  String get diaryGlass => 'Glass';

  @override
  String get diaryBottle => 'Bottle';

  @override
  String get diaryProtein => 'Protein';

  @override
  String get diaryCarbs => 'Carbs';

  @override
  String get diaryFat => 'Fat';

  @override
  String get diaryMacroTargets => 'Suggested split for your calorie goal';

  @override
  String get diaryNoMeals => 'No meals logged for this day.';

  @override
  String get diaryDeleteMeal => 'Delete meal?';

  @override
  String get diaryRemoveEntry => 'Remove from diary';

  @override
  String get amountPositive => 'Enter an amount greater than zero';

  @override
  String get amountClose => 'Close';

  @override
  String get amountQuick => 'Quick selection';

  @override
  String get amountQuickHint => 'Tap an option to select it straight away.';

  @override
  String get amountCustom => 'Custom amount';

  @override
  String get amountUnit => 'Unit';

  @override
  String get amountQuantity => 'Amount';

  @override
  String get amountChoose => 'Select amount';

  @override
  String get amountApproximate => 'approx. ';

  @override
  String get measurePack => 'pack';

  @override
  String get measureServing => 'serving';

  @override
  String get measurePiece => 'item';

  @override
  String get measureTeaspoon => 'teaspoon';

  @override
  String get measureGlass => 'glass';

  @override
  String get measureGrams => 'grams';

  @override
  String get measureMillilitres => 'millilitres';

  @override
  String get nutritionMissing => 'Nutrition unavailable';

  @override
  String get recipeNutritionEstimated =>
      'Approximate values: some ingredients were estimated. They may differ from the product label.';

  @override
  String get recipeNutritionPartial =>
      'Incomplete data. ≥ shows only the sum of known values, not the meal\'s full nutrition.';

  @override
  String get recipeNutritionNeedsDetails =>
      'This recipe has missing nutrition. Complete the ingredient details in the recipe or enter the meal\'s nutrition manually in your Diary.';

  @override
  String productsProcessed(int count) {
    return 'Processed: $count products.';
  }

  @override
  String productsLoadFailed(String error) {
    return 'Couldn\'t load products: $error';
  }

  @override
  String productsDeleteMessage(String name) {
    return '“$name” will be removed from your submissions. This cannot be undone.';
  }

  @override
  String productsShopBrand(String brand) {
    return 'Shop brand: $brand';
  }

  @override
  String productsBrand(String brand) {
    return 'Product brand: $brand';
  }

  @override
  String productsCheckedOn(String date) {
    return 'price checked $date';
  }

  @override
  String diaryTodayDate(String date) {
    return 'Today, $date';
  }

  @override
  String diaryActivityCalories(String calories) {
    return '+$calories from activity';
  }

  @override
  String diaryWaterProgress(String amount, String goal) {
    return '$amount of $goal ml';
  }

  @override
  String diaryDeleteMessage(String name) {
    return '“$name” will be removed from your diary.';
  }

  @override
  String diaryAmountTimes(String amount) {
    return 'Amount: $amount×';
  }

  @override
  String diaryPortionSize(String amount, String unit) {
    return '1 serving = $amount $unit';
  }

  @override
  String nutritionMacroLine(
    String kcal,
    String protein,
    String fat,
    String carbs,
  ) {
    return '$kcal kcal  •  P $protein g  •  F $fat g  •  C $carbs g';
  }

  @override
  String get productFormEdit => 'Edit product';

  @override
  String get productFormAdd => 'Add your product';

  @override
  String get productFormVisibility =>
      'You can use this product straight away. Other users will see it after an administrator approves it.';

  @override
  String get productFormManualAfterScan =>
      'You can still enter the details manually. The barcode has been kept.';

  @override
  String get productFormCatalogFilled =>
      'Found in the catalogue — details filled in automatically.';

  @override
  String get productFormScanFilled =>
      'Product found — name, brand and nutrition filled in.';

  @override
  String get productFormEditSaved =>
      'Saved. An administrator will review the changes again.';

  @override
  String get productFormAdded =>
      'Product added. You can use it now; others will see it once an administrator approves it.';

  @override
  String get productFormAlreadyExists =>
      'This product is already in the catalogue. You do not need to add it again.';

  @override
  String get productFormCloseExisting => 'Close — product already in catalogue';

  @override
  String get productFormName => 'Product name *';

  @override
  String get productFormNameHint => 'Enter a name or choose a suggestion';

  @override
  String get productFormNameRequired => 'Enter a product name';

  @override
  String get productFormBrandOptional => 'Brand (optional)';

  @override
  String get productFormBrand => 'Brand';

  @override
  String get productFormPrice => 'Price seen in the shop (optional)';

  @override
  String get productFormPriceError =>
      'Enter a valid price (over 0, up to 10,000).';

  @override
  String get productFormUnit => 'Unit';

  @override
  String get productFormPack => 'Whole pack size';

  @override
  String get productFormPackExample => 'e.g. 150';

  @override
  String get productFormPackHelp =>
      'Enter the net weight or volume of the whole pack, not a serving. If it is unknown, leave this blank — the pack option will not be shown.';

  @override
  String get productFormPackError =>
      'Enter a pack size over 0 and up to 100,000 g/ml, or leave it blank.';

  @override
  String get productFormNutritionHelp =>
      'Without complete nutrition, you can still use the product on a shopping list. Complete the nutrition before adding it to your food diary.';

  @override
  String get productFormCalories => 'Calories';

  @override
  String get productFormProtein => 'Protein';

  @override
  String get productFormFat => 'Fat';

  @override
  String get productFormCarbs => 'Carbs';

  @override
  String get productFormShops => 'Which shops sell it? (optional)';

  @override
  String get productFormShopsHelp =>
      'You can select several. It will appear in these shops only after approval.';

  @override
  String get productFormSaveChanges => 'Save changes';

  @override
  String get productFormSave => 'Add product';

  @override
  String get productFormNumberError => 'Enter a valid number.';

  @override
  String get productFormRequestFailed =>
      'Could not save the product. Your details have been kept — please try again.';

  @override
  String get productLabelTitle => 'Add missing product details';

  @override
  String get productLabelTakePhoto => 'Take a photo';

  @override
  String get productLabelGallery => 'Choose from gallery';

  @override
  String get productLabelBothPhotos =>
      'Add both photos: the front and the nutrition label.';

  @override
  String get productLabelNameError =>
      'Check the product name (2–300 characters).';

  @override
  String get productLabelReading => 'Reading the label…';

  @override
  String get productLabelRead => 'Read label';

  @override
  String get productLabelFront => 'Front of pack';

  @override
  String get productLabelNutrition => 'Nutrition label';

  @override
  String get productLabelReview => 'Check the details before saving';

  @override
  String get productLabelConfirm => 'Confirm and save';

  @override
  String get productLabelMissingNutrition =>
      'Enter kcal, protein, fat and carbs per 100 g/ml.';

  @override
  String get productLabelReadFailed =>
      'Could not read the label. Your photos have been kept — please try again.';

  @override
  String get productLabelPhotoFailed =>
      'Could not open the photo. Check camera or gallery access and try again.';

  @override
  String get productFormBrandError =>
      'The brand can have up to 200 characters.';

  @override
  String productFormScanned(String code) {
    return 'Scanned: $code (change)';
  }

  @override
  String productFormTypicalPrice(String minimum, String maximum) {
    return 'Typical price range: $minimum–$maximum PLN';
  }

  @override
  String productFormReward(int points) {
    return 'Product added • +$points Premium point';
  }

  @override
  String productFormBalance(int points) {
    return ' • balance: $points';
  }

  @override
  String productFormNutrition(String unit) {
    return 'Nutrition per 100 $unit (optional)';
  }

  @override
  String productLabelIntro(String code) {
    return 'Details are missing for barcode $code. Two clear photos can fill them in without typing everything.';
  }

  @override
  String productLabelPer100(String unit) {
    return 'Values per 100 $unit';
  }

  @override
  String productFormNumberRange(String maximum) {
    return 'Enter a number from 0 to $maximum.';
  }

  @override
  String get productFormChooseUnit =>
      'Choose grams or millilitres for the pack size.';

  @override
  String get productFormLookupFailed =>
      'Could not look up the product. The barcode has been kept — you can enter the details manually.';

  @override
  String get detailTikTokFailed => 'Could not open the TikTok profile.';

  @override
  String get detailAiUpdated => 'Your recipe has been updated with AI.';

  @override
  String get detailAiAction => 'Adjust recipe with AI · 1 point';

  @override
  String get detailRecipeAuthor => 'the recipe author';

  @override
  String get detailTime => 'Time';

  @override
  String get detailServings => 'Servings';

  @override
  String get detailNutrition => 'Nutrition';

  @override
  String get detailPerServing => 'per serving';

  @override
  String get detailChange => 'Change';

  @override
  String get detailLoading => 'Loading ingredients and method…';

  @override
  String get detailRetry => 'Try loading the details again';

  @override
  String get detailTemporary => 'Temporary variation';

  @override
  String get detailTemporaryHelp =>
      'The original recipe has not changed. Creating a shopping list will save this version in My recipes so the list uses the ingredients and amounts shown here. Saving recalculates the nutrition.';

  @override
  String get detailSaveVariant => 'Save variation to Mine';

  @override
  String get detailUndo => 'Undo changes';

  @override
  String get detailIngredient => 'Ingredient';

  @override
  String get detailPastaTitle => 'Tip: measure pasta without scales';

  @override
  String get detailPastaHelp =>
      'Hold dry pasta between two fingers in a circle roughly the diameter of a Polish 5 zł coin — about one serving (80–100 g) per person.';

  @override
  String get detailMethod => 'Method';

  @override
  String get detailAlsoAdd => 'You could also add';

  @override
  String get detailSeasoningHelp => 'optional seasonings for extra flavour';

  @override
  String get detailFiber => 'Fibre';

  @override
  String get variantTitle => 'Edit ingredients';

  @override
  String get variantHelp =>
      'These changes are temporary. The original recipe will stay unchanged.';

  @override
  String get variantAlreadyAdded => 'This product is already on the list.';

  @override
  String get variantRemove => 'Remove ingredient';

  @override
  String get variantApply => 'Apply temporarily';

  @override
  String variantQuantityError(int maximum) {
    return 'Enter an amount greater than zero, up to $maximum.';
  }

  @override
  String get aiEditTitle => 'Adjust recipe with AI';

  @override
  String get aiEditPromptLabel => 'What would you like to change or add?';

  @override
  String get aiEditPromptHint =>
      'e.g. replace chicken with tofu and update the method';

  @override
  String get aiEditBuyPoints => 'Buy points';

  @override
  String get aiEditSubmit => 'Update recipe · 1 point';

  @override
  String get detailFavoriteError => 'Could not update your favourites';

  @override
  String get detailRemoveFavorite => 'Remove from favourites';

  @override
  String get detailAddFavorite => 'Add to favourites';

  @override
  String get detailDeleteTitle => 'Delete recipe?';

  @override
  String get detailDeletePublicHelp =>
      'This recipe is public. Deleting it also removes it from shopping lists and plans that use it. This cannot be undone.';

  @override
  String get detailDeleteHelp => 'This cannot be undone.';

  @override
  String get detailDeleteFailed => 'Could not delete the recipe';

  @override
  String get detailDelete => 'Delete recipe';

  @override
  String get detailPublishTitle => 'Publish recipe?';

  @override
  String get detailPublishHelp =>
      'An administrator will review your recipe. Once approved, it will be visible to other users.';

  @override
  String get detailPublishSubmit => 'Publish';

  @override
  String get detailPublishSent =>
      'Recipe submitted — awaiting administrator approval.';

  @override
  String get detailPublishFailed => 'Could not publish the recipe.';

  @override
  String get detailPublish => 'Publish recipe';

  @override
  String get detailShopping => 'Shopping list for this dish';

  @override
  String get detailChooseShop => 'Choose a shop in your profile first';

  @override
  String get detailPhotoSent =>
      'Thank you! Your photo will appear once an administrator approves it.';

  @override
  String get detailPhotoReplaceHelp =>
      'This recipe already has a photo. If yours is approved, it will replace the current one.';

  @override
  String get detailPhotoSending => 'Sending…';

  @override
  String get detailPhotoReplace => 'Suggest another photo';

  @override
  String get detailPhotoAdd => 'Add photo';

  @override
  String get detailAiPhoto => 'Illustrative image generated by AI';

  @override
  String detailSavedVariant(String name) {
    return 'Saved to Mine as “$name”.';
  }

  @override
  String detailAddedBy(String name) {
    return 'Added by $name';
  }

  @override
  String variantAmount(String unit) {
    return 'Amount ($unit)';
  }

  @override
  String variantBrand(String brand) {
    return 'Brand: $brand';
  }

  @override
  String aiEditIntro(String name) {
    return 'Describe what to change in “$name”. For example, ask for a dairy-free version or add a particular ingredient.';
  }

  @override
  String aiEditCost(int points) {
    return 'A successful update costs 1 Premium point. Your balance: $points points.';
  }

  @override
  String detailExistingLists(int count, String word) {
    return 'You already have $count $word — add to an existing list or create a new one.';
  }

  @override
  String detailListItems(int count) {
    return '$count items';
  }

  @override
  String get variantSearchHint => 'Enter a product name';

  @override
  String get detailAddToList => 'Add to shopping list';

  @override
  String get detailCreateList => 'Create a new list';

  @override
  String get productsOnlineCatalogue =>
      'Online catalogue — local availability may vary';

  @override
  String get productsGenericFood => 'Generic food — check shop availability';

  @override
  String get productsNationalAverage => 'UK average, not a shop price';

  @override
  String get productsPriceUnavailable => 'Price unavailable';

  @override
  String get commentsLoadFailed => 'Could not load comments';

  @override
  String get commentsPhotoFailed => 'Could not load the photo';

  @override
  String get commentsCamera => 'Take a photo';

  @override
  String get commentsGallery => 'Choose from gallery';

  @override
  String get commentsDeleteTitle => 'Delete this comment?';

  @override
  String get commentsDeleteBody => 'This cannot be undone.';

  @override
  String get commentsCancel => 'Cancel';

  @override
  String get commentsDelete => 'Delete';

  @override
  String get commentsDeleteFailed => 'Could not delete the comment';

  @override
  String get commentsLikeFailed => 'Could not save your like';

  @override
  String get commentsJustNow => 'just now';

  @override
  String get commentsTitle => 'Comments and photos';

  @override
  String get commentsFirst => 'Be the first to comment on this recipe';

  @override
  String get commentsHint => 'Share a thought or a cooking tip…';

  @override
  String get commentsPhoto => 'Add photo';

  @override
  String get commentsAdd => 'Add';

  @override
  String get commentsDeleteTooltip => 'Delete comment';

  @override
  String get commentsModerateTooltip => 'Delete comment (moderation)';

  @override
  String get reportTitle => 'Report content';

  @override
  String get reportReason => 'Reason for reporting:';

  @override
  String get reportDetails => 'Additional details (optional)';

  @override
  String get reportSend => 'Report';

  @override
  String get reportThanks => 'Thank you. Our team will review your report.';

  @override
  String get reportFailed => 'Could not send your report. Please try again.';

  @override
  String get reportSpam => 'Spam or advertising';

  @override
  String get reportInappropriate => 'Inappropriate content';

  @override
  String get reportHarassment => 'Harassment or hate speech';

  @override
  String get reportMisinformation => 'False information';

  @override
  String get reportOther => 'Another reason';

  @override
  String get blockTitle => 'Block this user?';

  @override
  String get blockAction => 'Block';

  @override
  String get blockAuthor => 'Block author';

  @override
  String get blockFailed => 'Could not block the user.';

  @override
  String commentsMinutes(int count) {
    return '$count min ago';
  }

  @override
  String commentsHours(int count) {
    return '$count hr ago';
  }

  @override
  String commentsDays(int count) {
    return '$count days ago';
  }

  @override
  String commentsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count comments',
      one: '1 comment',
    );
    return '$_temp0';
  }

  @override
  String blockBody(String name) {
    return 'You will no longer see recipes or comments from \"$name\". You can unblock them at any time in Profile → Blocked users.';
  }

  @override
  String blockDone(String name) {
    return '\"$name\" has been blocked.';
  }

  @override
  String get profileTitle => 'Profile';

  @override
  String get profileNone => 'Not set';

  @override
  String get profileShop => 'Shop';

  @override
  String get profileUser => 'User';

  @override
  String get profileExpiryToday => 'Your subscription expires today';

  @override
  String get profileHealth => 'Health and goals';

  @override
  String get profileCommunity => 'Community';

  @override
  String get profileFriends => 'Friends';

  @override
  String get profileFriendsHint => 'Invitations, recipes and shopping lists';

  @override
  String get profileSubscription => 'Subscription';

  @override
  String get profileUpgrade => 'Get Premium';

  @override
  String get profileUpgradeHint =>
      'Automatic weekly plans, batch scanning and unlimited lists';

  @override
  String get profileCompare => 'Compare plans';

  @override
  String get profilePreferences => 'Preferences';

  @override
  String get profilePreferredShop => 'Preferred shop';

  @override
  String get profileDiet => 'Diet';

  @override
  String get profileHousehold => 'People in your household';

  @override
  String get profileLikes => 'Likes / Dislikes';

  @override
  String get profileArchive => 'Plan archive';

  @override
  String get profileArchiveHint => 'Premium · view and reuse';

  @override
  String get profileDarkMode => 'Dark mode';

  @override
  String get profilePrivacy => 'Account and privacy';

  @override
  String get profileAddUsername => 'Add a username';

  @override
  String get profileLogout => 'Sign out';

  @override
  String get profileBlocked => 'Blocked users';

  @override
  String get profileDelete => 'Delete account';

  @override
  String get profileAdmin => 'Administrator panel';

  @override
  String get profileChooseShop => 'Choose a shop';

  @override
  String get profileHealthTitle => 'Weight, height and calorie goal';

  @override
  String get profileHealthHint =>
      'Enter your details to calculate BMI and calorie needs';

  @override
  String get profileBmiLow => 'underweight';

  @override
  String get profileBmiNormal => 'healthy weight';

  @override
  String get profileBmiHigh => 'overweight';

  @override
  String get profileBmiObese => 'obesity';

  @override
  String get profileMeasurementDate => 'Measurement date';

  @override
  String get profileSelect => 'Select';

  @override
  String get profileWeightInvalid =>
      'Enter a valid weight between 0.1 and 400 kg.';

  @override
  String get profileWeightTitle => 'Weight tracking';

  @override
  String get profileWeightHint =>
      'Save a measurement for the selected day. Saving again updates the entry for that date.';

  @override
  String get profileWeightOptional => 'Weight (optional)';

  @override
  String get profileSaveMeasurement => 'Save measurement';

  @override
  String get profileStatistics => 'Statistics';

  @override
  String get profilePhotoFailed => 'Could not save the photo';

  @override
  String get profileAvatar => 'Choose an avatar';

  @override
  String get profileGallery => 'From gallery';

  @override
  String get profileAvatarOr => 'or choose an icon';

  @override
  String get profileFemale => 'Woman';

  @override
  String get profileMale => 'Man';

  @override
  String get profileNicknameTitle => 'Change nickname';

  @override
  String get profileNickname => 'Nickname';

  @override
  String get profileSave => 'Save';

  @override
  String get profileNicknameSaved => 'Nickname updated.';

  @override
  String get profileNicknameFailed => 'Could not change your nickname.';

  @override
  String get profileTikTokFailed => 'Could not open the TikTok profile.';

  @override
  String get profileTikTokAdd => 'Add TikTok';

  @override
  String get profileTikTokEdit => 'Edit TikTok';

  @override
  String get profileTikTokUsername => 'TikTok username';

  @override
  String get profileTikTokPlaceholder => '@yourname';

  @override
  String get profileTikTokHelp => 'You can also paste the full profile link.';

  @override
  String get profileTikTokInvalid =>
      'Use 2–24 characters: letters, numbers, full stops or underscores.';

  @override
  String get profileTikTokRemoved => 'TikTok username removed.';

  @override
  String get profileTikTokSaved => 'TikTok profile link added.';

  @override
  String get profileTikTokSaveFailed => 'Could not save your TikTok username.';

  @override
  String get profileDeleteTitle => 'Permanently delete your account?';

  @override
  String get profileNext => 'Continue';

  @override
  String get profileDeleteFinal => 'Final confirmation';

  @override
  String get profileDeleteFinalBody => 'Are you sure? This cannot be undone.';

  @override
  String get profileDeleteFailed =>
      'Could not delete your account. Please try again.';

  @override
  String get profileDietAny => 'No restrictions';

  @override
  String get profileDietVegetarian => 'Vegetarian';

  @override
  String get profileDietVegan => 'Vegan';

  @override
  String get profileDietKeto => 'Keto';

  @override
  String get profileDietLactose => 'Lactose-free';

  @override
  String get documentContact => 'Contact';

  @override
  String get documentEmailBody => 'Email us at:';

  @override
  String get documentCopy => 'Copy address';

  @override
  String get documentClose => 'Close';

  @override
  String get documentOpenFailed =>
      'Could not open the document. Please try again.';

  @override
  String get documentTerms => 'Terms of Use (EULA)';

  @override
  String get documentPrivacy => 'Privacy policy';

  @override
  String get documentDeletion => 'Account deletion information';

  @override
  String get documentHelp => 'Help';

  @override
  String get compareWeekly => 'Automatic weekly plan and list';

  @override
  String get compareArchive => 'Archive and reuse finished plans';

  @override
  String get compareLikes => 'Likes / Dislikes: one tailored meal a day';

  @override
  String get compareAi => 'AI recipe import (photo, text, link)';

  @override
  String get compareBatch => 'Batch scanning without closing the camera';

  @override
  String get comparePublish => 'Publish recipes in the shared catalogue';

  @override
  String get compareTikTok => 'TikTok link on your recipes';

  @override
  String get compareLists => 'Shopping lists from selected recipes';

  @override
  String get compareUnlimited => 'Unlimited';

  @override
  String get compareOneWeek => '1 / week';

  @override
  String get compareGenerate => 'Meal plan generation';

  @override
  String get compareJournal => 'Calorie and macro diary';

  @override
  String get compareCalculator => 'Calorie needs calculator';

  @override
  String get compareCatalogue => 'Recipe and product catalogue';

  @override
  String get comparePrices => 'Product price comparison';

  @override
  String profileExpiryDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days more days',
      one: '1 more day',
    );
    return 'Subscription active for $_temp0';
  }

  @override
  String profilePeople(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people',
      one: '1 person',
    );
    return '$_temp0';
  }

  @override
  String profileWeightSaved(String weight) {
    return 'Saved $weight kg.';
  }

  @override
  String profileDate(String date) {
    return 'Date: $date';
  }

  @override
  String get profileDeleteBody =>
      'This cannot be undone. You will lose all saved meal plans, shopping lists, pantry items, favourite recipes, comments and Premium points. If you have an active subscription, cancel it separately in App Store / Google Play settings — deleting your account does not cancel the subscription.';

  @override
  String premiumTrialBadge(int days) {
    return '$days DAYS FREE*';
  }

  @override
  String get premiumCheckTrial => 'See free trial';

  @override
  String premiumTrialEligibilityFootnote(String store) {
    return '* For eligible accounts. $store will show availability, the price after your trial and the renewal date before you confirm.';
  }

  @override
  String get premiumNotNow => 'Not now';

  @override
  String get premiumPurchaseError => 'There was a problem with your purchase.';

  @override
  String get premiumAppleOfferOpenFailed =>
      'The App Store offer could not be opened.';

  @override
  String premiumPaymentsUnavailable(String store) {
    return 'Purchases are unavailable on this device. Please check your $store account.';
  }

  @override
  String get premiumSubscriptionPricesUnavailable =>
      'Subscription prices could not be loaded. Please try again shortly.';

  @override
  String premiumPurchaseFailed(String error) {
    return 'Purchase failed: $error';
  }

  @override
  String get premiumUnknownError => 'unknown error';

  @override
  String get premiumActive => 'Premium is active.';

  @override
  String get premiumActivated => 'Premium is now active. Thank you.';

  @override
  String premiumPurchaseVerificationFailed(String error) {
    return 'Your purchase could not be verified: $error';
  }

  @override
  String premiumPointsAdded(int balance) {
    return 'Points added. Your balance is $balance.';
  }

  @override
  String premiumPurchaseStartFailed(String error) {
    return 'Your purchase could not be started: $error';
  }

  @override
  String get premiumRestoreEmpty =>
      'There are no previous purchases to restore.';

  @override
  String premiumQuickActionPoints(String subtitle, int points) {
    String _temp0 = intl.Intl.pluralLogic(
      points,
      locale: localeName,
      other: '$points points',
      one: '$points point',
    );
    return '$subtitle. Or use $_temp0 without a subscription.';
  }

  @override
  String get premiumAutomaticWeekTitle => 'Automatic weekly plan';

  @override
  String get premiumAutomaticWeekDescription =>
      'Get a meal plan and an optional shopping list on your chosen day.';

  @override
  String get premiumBatchTitle => 'Batch barcode scanning';

  @override
  String get premiumBatchDescription =>
      'Scan one product after another, then add the whole batch to your chosen destinations.';

  @override
  String get premiumUnlimitedPlansTitle => 'Unlimited meal plans';

  @override
  String get premiumUnlimitedPlansDescription =>
      'Create as many meal plans as you need, with no weekly limit.';

  @override
  String get premiumAiRecipesTitle => 'AI recipe import';

  @override
  String get premiumAiRecipesDescription =>
      'Add your own recipes from pasted text or a photo.';

  @override
  String get premiumFullDiaryTitle => 'Full Diary history';

  @override
  String get premiumFullDiaryDescription =>
      'View your full calorie history beyond the last 30 days.';

  @override
  String get premiumUnlimitedListsTitle => 'Unlimited shopping lists';

  @override
  String get premiumUnlimitedListsDescription =>
      'Create a new shopping list whenever you need one.';

  @override
  String get premiumProductName => 'Meal Planner Premium';

  @override
  String get premiumHeroDescription =>
      'Plan your week, scan your groceries and put together a shopping list in minutes.';

  @override
  String get premiumAutomaticWeekSubtitle =>
      'Your weekly plan and optional shopping list, ready each week';

  @override
  String get premiumAutomaticWeekRequired =>
      'Automatic weekly planning is available with Premium.';

  @override
  String get premiumAiActionTitle => 'Add a recipe with AI';

  @override
  String get premiumAiActionSubtitle =>
      'Start with a photo, text or link and let AI build the recipe';

  @override
  String get premiumBatchActionTitle => 'Scan several products in one go';

  @override
  String get premiumBatchActionSubtitle =>
      'Choose your destinations and confirm the whole batch';

  @override
  String premiumBatchCompleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count products processed.',
      one: '$count product processed.',
    );
    return '$_temp0';
  }

  @override
  String get premiumPublishActionTitle => 'Publish your recipes';

  @override
  String get premiumPublishActionSubtitle =>
      'Share your recipes with the community';

  @override
  String get premiumRecipeListsTitle => 'Shopping lists from recipes';

  @override
  String get premiumRecipeListsSubtitle => 'Unlimited (Standard: 1 per week)';

  @override
  String get premiumCookFromPantryTitle => 'Cook with what you have';

  @override
  String get premiumCookFromPantrySubtitle =>
      'Select the ingredients you have and find matching recipes';

  @override
  String get premiumPantryActionTitle => 'Your pantry';

  @override
  String get premiumPantryActionSubtitle =>
      'Keep track of the food you have at home';

  @override
  String premiumSubscriptionLegal(String store) {
    return 'Subscriptions renew automatically unless cancelled at least 24 hours before the current period ends. Payment is charged to your $store account when you confirm your purchase. Manage or cancel your subscription in your store account settings.';
  }

  @override
  String get premiumAlreadyActive => 'Your Premium subscription is active';

  @override
  String get premiumExpiresToday => 'Expires today';

  @override
  String premiumDaysRemaining(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Active for $days more days',
      one: 'Active for $days more day',
    );
    return '$_temp0';
  }

  @override
  String get premiumRetry => 'Try again';

  @override
  String get premiumWeekly => 'Weekly';

  @override
  String get premiumMonthly => 'Monthly';

  @override
  String premiumMonthlyTrial(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days free',
      one: '$days day free',
    );
    return '$_temp0';
  }

  @override
  String get premiumYearly => 'Yearly';

  @override
  String premiumYearlySaving(int percent) {
    return 'Save $percent%';
  }

  @override
  String premiumTrialDisclosureApple(int days) {
    return 'Eligible accounts can try Premium free for $days days. It then renews at the price shown above. You can cancel in your Apple account settings.';
  }

  @override
  String premiumTrialDisclosureGoogle(int days) {
    return 'Eligible accounts can try Premium free for $days days. It then renews at the price shown above. You can cancel in Google Play.';
  }

  @override
  String get premiumRestorePurchases => 'Restore purchases';

  @override
  String get premiumPointsTitle => 'Premium points';

  @override
  String premiumPointsBalance(int balance) {
    return 'Your balance: $balance';
  }

  @override
  String get premiumPointsExplanation =>
      'Import a recipe from a photo, text or link for 2 points. Edit a recipe with AI for 1 point. A subscription is optional.';

  @override
  String get premiumPointsPricesUnavailable =>
      'Point package prices could not be loaded.';

  @override
  String premiumPointsAmount(int points) {
    String _temp0 = intl.Intl.pluralLogic(
      points,
      locale: localeName,
      other: '$points points',
      one: '$points point',
    );
    return '$_temp0';
  }

  @override
  String premiumPromotionalPrice(String price) {
    return 'Offer price: $price';
  }

  @override
  String premiumPointsUses(int imports, int edits) {
    String _temp0 = intl.Intl.pluralLogic(
      imports,
      locale: localeName,
      other: '$imports AI imports',
      one: '$imports AI import',
    );
    String _temp1 = intl.Intl.pluralLogic(
      edits,
      locale: localeName,
      other: '$edits AI edits',
      one: '$edits AI edit',
    );
    return '$_temp0\nor $_temp1';
  }

  @override
  String get premiumBuyInApple => 'Buy in the App Store';

  @override
  String get premiumBuyInGoogle => 'Buy in Google Play';

  @override
  String premiumPriceAfterTrial(String price) {
    return 'Then $price per month';
  }

  @override
  String premiumPriceBeforeCode(String price) {
    return 'Price before offer code: $price';
  }

  @override
  String get premiumTryFree => 'Try for free';

  @override
  String get premiumBuy => 'Get Premium';

  @override
  String get premiumRedeemCode => 'Get offer code';

  @override
  String get premiumBuyDiscount => 'Buy at the offer price';

  @override
  String get premiumContextRecipeEyebrow => 'PREMIUM FOR RECIPES';

  @override
  String get premiumContextRecipeTitle => 'Turn an idea into a recipe';

  @override
  String get premiumContextRecipeDescription =>
      'Paste a link, add a photo or describe a dish. Get a recipe with ingredients, servings and clear steps.';

  @override
  String get premiumContextRecipeBenefitImport =>
      'A recipe from a link, photo or description';

  @override
  String get premiumContextRecipeBenefitSteps =>
      'Ingredients and steps put together for you';

  @override
  String get premiumContextRecipeBenefitEdit => 'Edit recipes with AI';

  @override
  String get premiumContextMealPlanEyebrow => 'PREMIUM FOR PLANNING';

  @override
  String get premiumContextMealPlanTitle => 'Plan as many weeks as you need';

  @override
  String get premiumContextMealPlanDescription =>
      'Create as many meal plans as you need and fit your meals around your day.';

  @override
  String get premiumContextMealPlanBenefitUnlimited => 'Unlimited meal plans';

  @override
  String get premiumContextMealPlanBenefitWeekly =>
      'An automatic plan for next week';

  @override
  String get premiumContextMealPlanBenefitSwap => 'Find and swap meals';

  @override
  String get premiumContextBarcodeEyebrow => 'PREMIUM FOR SCANNING';

  @override
  String get premiumContextBarcodeTitle => 'Scan your groceries in one go';

  @override
  String get premiumContextBarcodeDescription =>
      'Scan products one after another, then add the whole batch to your chosen destinations.';

  @override
  String get premiumContextBarcodeBenefitBatch => 'Batch barcode scanning';

  @override
  String get premiumContextBarcodeBenefitNutrition =>
      'Calories and macros for matched products';

  @override
  String get premiumContextBarcodeBenefitDestinations =>
      'Add the batch to your Diary, pantry or catalogue';

  @override
  String get premiumContextShoppingEyebrow => 'PREMIUM FOR SHOPPING';

  @override
  String get premiumContextShoppingTitle =>
      'Create as many shopping lists as you need';

  @override
  String get premiumContextShoppingDescription =>
      'Make a separate list for each plan or recipe. Merge lists for the same shop.';

  @override
  String get premiumContextShoppingBenefitLists => 'Unlimited shopping lists';

  @override
  String get premiumContextShoppingBenefitMerge =>
      'Merge lists for the same shop';

  @override
  String get premiumContextShoppingBenefitPantry =>
      'Food from your pantry adds no shopping cost';

  @override
  String get premiumContextPantryEyebrow => 'PREMIUM FOR YOUR PANTRY';

  @override
  String get premiumContextPantryTitle => 'Use the food you already have';

  @override
  String get premiumContextPantryDescription =>
      'Find recipes that use your pantry ingredients and buy only what you need.';

  @override
  String get premiumContextPantryBenefitMatch =>
      'Recipes that use your ingredients';

  @override
  String get premiumContextPantryBenefitMissing => 'Fewer missing ingredients';

  @override
  String get premiumContextPantryBenefitWaste => 'Less food waste';

  @override
  String get premiumContextJournalEyebrow => 'PREMIUM FOR YOUR DIARY';

  @override
  String get premiumContextJournalTitle => 'See your progress over time';

  @override
  String get premiumContextJournalDescription =>
      'Look back over a longer period to spot changes in calories, macros, hydration and weight.';

  @override
  String get premiumContextJournalBenefitHistory => 'Your full Diary history';

  @override
  String get premiumContextJournalBenefitCharts =>
      'Calorie, macro and hydration charts';

  @override
  String get premiumContextJournalBenefitWeight => 'Weight progress over time';

  @override
  String get premiumPackageSemantics => 'Package';

  @override
  String premiumDiscountSemantics(int percent) {
    return '$percent per cent discount';
  }

  @override
  String premiumDiscountRibbon(int percent) {
    return 'SAVE $percent%';
  }

  @override
  String get premiumSeePlans => 'See Premium plans';

  @override
  String get archiveTitle => 'Plan archive';

  @override
  String get archiveChooseStart => 'When should the plan start?';

  @override
  String get archiveChooseDate => 'Choose date';

  @override
  String get archiveResumeTitle => 'Resume plan';

  @override
  String archiveResumeBody(int days, String date) {
    return 'The same meals for $days days from $date. The original plan will stay in the archive. We will create a new shopping list. No AI generation or Premium points needed.';
  }

  @override
  String get archiveResume => 'Resume';

  @override
  String get archiveResumed => 'Your plan has been resumed.';

  @override
  String get archiveResumeFailed =>
      'Could not resume the plan. Please try again.';

  @override
  String archiveDuration(int days) {
    return '$days days';
  }

  @override
  String get archivePremiumHint =>
      'With Premium, completed plans stay in your archive. You can view and resume them without AI generation.';

  @override
  String get archiveSeePremium => 'See Premium';

  @override
  String get archiveCompleted => 'Completed plans';

  @override
  String get archiveHint =>
      'Use the same meals again from a new date. No AI generation or Premium points needed.';

  @override
  String get archiveEmpty =>
      'No completed plans yet. Your active plan will appear here after its last day.';

  @override
  String archivePlanTitle(int days) {
    return '$days-day plan';
  }

  @override
  String get archivePreview => 'Preview';

  @override
  String get archiveResuming => 'Resuming…';

  @override
  String get automationTitle => 'Automatic week';

  @override
  String get automationHeading => 'Your plan, ready before the week begins';

  @override
  String get automationHint =>
      'Each week, we will prepare a 7-day plan based on your goal, preferences and preferred shop.';

  @override
  String get automationGenerate => 'Generate automatically';

  @override
  String get automationPremiumHint => 'Only while Premium is active';

  @override
  String get automationWeekday => 'Day of the week';

  @override
  String get automationMonday => 'Monday';

  @override
  String get automationTuesday => 'Tuesday';

  @override
  String get automationWednesday => 'Wednesday';

  @override
  String get automationThursday => 'Thursday';

  @override
  String get automationFriday => 'Friday';

  @override
  String get automationSaturday => 'Saturday';

  @override
  String get automationSunday => 'Sunday';

  @override
  String get automationHour => 'Time';

  @override
  String get automationCreateList => 'Also create a shopping list';

  @override
  String get automationLastPlan => 'Last plan created';

  @override
  String get automationSave => 'Save settings';

  @override
  String get automationRun => 'Generate now';

  @override
  String get automationEnabled => 'Automatic week is on.';

  @override
  String get automationDisabled => 'Automatic week is off.';

  @override
  String get automationReady => 'Your plan is ready. Find it in Home.';

  @override
  String get errorSignIn => 'You need to sign in to do this.';

  @override
  String get errorTooManyRequests =>
      'Too many attempts. Please try again shortly.';

  @override
  String get errorUnavailable =>
      'The service is temporarily unavailable. Please try again shortly.';

  @override
  String get errorServerTimeout =>
      'The server did not respond in time. Please try again shortly.';

  @override
  String get errorServer =>
      'Something went wrong on our side. Please try again shortly.';

  @override
  String get errorOperationTimeout =>
      'This took too long. Please try again shortly.';

  @override
  String get errorConnection =>
      'Could not connect to the server. Check your internet connection and try again.';

  @override
  String get errorFormat =>
      'Could not read the data. Refresh the screen and try again.';

  @override
  String get automationRetry => 'Retry';

  @override
  String get ingredientPreferencesTitle => 'Ingredient preferences';

  @override
  String get ingredientPreferencesLimit =>
      'You can choose up to 50 ingredients in each group.';

  @override
  String get ingredientPreferencesSavedMessage =>
      'Ingredient preferences saved.';

  @override
  String get ingredientPreferencesUnsavedTitle => 'Unsaved preferences';

  @override
  String get ingredientPreferencesUnsavedBody =>
      'You have unsaved changes. Go back without saving?';

  @override
  String get ingredientPreferencesStay => 'Stay';

  @override
  String get ingredientPreferencesDiscard => 'Go back without saving';

  @override
  String get ingredientPreferencesEmpty => 'No ingredients selected yet.';

  @override
  String ingredientPreferencesRemove(String name) {
    return 'Remove $name';
  }

  @override
  String get ingredientPreferencesRetry => 'Try again';

  @override
  String get ingredientPreferencesHint =>
      'We will use your preferences in one meal a day when a matching recipe is available. Allergies and diet take priority.';

  @override
  String get ingredientPreferencesLike => 'Like';

  @override
  String get ingredientPreferencesDislike => 'Dislike';

  @override
  String get ingredientPreferencesAddLike => 'Add to: Like';

  @override
  String get ingredientPreferencesAddDislike => 'Add to: Dislike';

  @override
  String get ingredientPreferencesSearch => 'Search ingredients';

  @override
  String get ingredientPreferencesMoveHint =>
      'Selecting an ingredient in the other group moves it there.';

  @override
  String get ingredientPreferencesRetrySearch => 'Search again';

  @override
  String get ingredientPreferencesNoResults =>
      'No ingredients match this name.';

  @override
  String ingredientPreferencesSaveError(String error) {
    return 'Not saved: $error';
  }

  @override
  String get ingredientPreferencesSaving => 'Saving…';

  @override
  String get ingredientPreferencesSave => 'Save preferences';

  @override
  String get ingredientPreferencesSaved => 'Preferences saved';

  @override
  String get ingredientPreferencesLocked =>
      'Choose ingredients you like and dislike. Premium uses them in one meal a day when a matching recipe is available.';

  @override
  String get ingredientPreferencesPremium => 'View Premium';

  @override
  String get blockedUsersTitle => 'Blocked users';

  @override
  String get blockedUsersEmpty => 'You have not blocked anyone yet.';

  @override
  String get blockedUsersUnknown => 'User';

  @override
  String get blockedUsersUnblock => 'Unblock';

  @override
  String blockedUsersUnblocked(String name) {
    return 'Unblocked \"$name\". You can see their content again.';
  }

  @override
  String get calculatorTitle => 'Calorie calculator';

  @override
  String get calculatorIntro =>
      'Enter your details to calculate your daily calorie needs (the Mifflin–St Jeor formula, also used by Poland\'s NFZ calorie calculator).';

  @override
  String get calculatorWeight => 'Weight (kg)';

  @override
  String get calculatorHeight => 'Height (cm)';

  @override
  String get calculatorAge => 'Age (years)';

  @override
  String get calculatorSex => 'Sex';

  @override
  String get calculatorFemale => 'Female';

  @override
  String get calculatorMale => 'Male';

  @override
  String get calculatorActivity => 'Physical activity level';

  @override
  String get calculatorSedentary => 'Sedentary';

  @override
  String get calculatorSedentaryHint => 'Little or no exercise';

  @override
  String get calculatorLight => 'Lightly active';

  @override
  String get calculatorLightHint => 'Exercise 1–3 days a week';

  @override
  String get calculatorModerate => 'Moderately active';

  @override
  String get calculatorModerateHint => 'Exercise 3–5 days a week';

  @override
  String get calculatorActive => 'Active';

  @override
  String get calculatorActiveHint => 'Exercise 6–7 days a week';

  @override
  String get calculatorVeryActive => 'Very active';

  @override
  String get calculatorVeryActiveHint => 'Physical work and daily training';

  @override
  String get calculatorNumbersRequired =>
      'Enter numbers in all fields (weight, height and age).';

  @override
  String get calculatorCalculate => 'Calculate calorie needs';

  @override
  String get calculatorSaveFailed => 'Could not save your goal.';

  @override
  String calculatorGoalSaved(int kcal) {
    return 'Goal saved: $kcal kcal/day';
  }

  @override
  String get calculatorChooseGoal => 'Choose your goal';

  @override
  String get calculatorGoalHint =>
      'Tap a tile to select it, or fine-tune it with the slider below.';

  @override
  String get calculatorLoss => 'Weight loss';

  @override
  String get calculatorMaintenance => 'Maintain';

  @override
  String get calculatorGain => 'Weight gain';

  @override
  String calculatorCustomGoal(int kcal) {
    return 'Your target: $kcal kcal/day';
  }

  @override
  String get calculatorMacros => 'Estimated macronutrient split';

  @override
  String get calculatorProtein => 'Protein';

  @override
  String get calculatorFat => 'Fat';

  @override
  String get calculatorCarbs => 'Carbs';

  @override
  String get calculatorSaveGoal => 'Save as my goal';

  @override
  String get socialInviteTitle => 'Invite a friend';

  @override
  String get socialIdentifier => 'Username or email';

  @override
  String get socialSend => 'Send';

  @override
  String get socialInvitationSent => 'Invitation sent.';

  @override
  String get socialInvitationAccepted => 'Invitation accepted.';

  @override
  String get socialInvitationDeclined => 'Invitation declined.';

  @override
  String get socialInvitationCancelled => 'Invitation cancelled.';

  @override
  String get socialFriends => 'Friends';

  @override
  String get socialInvite => 'Invite';

  @override
  String get socialRetry => 'Try again';

  @override
  String get socialIncoming => 'Invitations for you';

  @override
  String get socialYourFriends => 'Your friends';

  @override
  String get socialNoFriends =>
      'You do not have any friends yet. Send your first invitation.';

  @override
  String get socialFriendSubtitle => 'Recipes and shopping list';

  @override
  String get socialOutgoing => 'Sent invitations';

  @override
  String get socialAwaitingResponse => 'Awaiting a response';

  @override
  String get socialDecline => 'Decline';

  @override
  String get socialAccept => 'Accept';

  @override
  String get socialNoFriendRecipes =>
      'This friend does not have any saved recipes yet.';

  @override
  String socialRecipeSummary(int minutes, String meal) {
    return '$minutes min • $meal';
  }

  @override
  String get socialNoFriendLists =>
      'This friend does not have an active shopping list right now.';

  @override
  String get socialShareAccepted =>
      'Accepted — the list will appear in your shared lists.';

  @override
  String get socialSharesTitle => 'Shopping list invitations';

  @override
  String get socialNoPendingShares => 'No pending invitations.';

  @override
  String socialSharedListInvitation(String name) {
    return '$name shared a shopping list with you';
  }

  @override
  String get socialSomeone => 'Someone';

  @override
  String get socialShareRespond => 'Tap to respond';

  @override
  String get socialShareAccept => 'Accept';

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String get notificationsLoadFailed => 'Could not load notifications';

  @override
  String get notificationsMarkAllFailed =>
      'Could not mark all notifications as read';

  @override
  String get notificationsPlanEnded => 'This plan has ended.';

  @override
  String get notificationsRecipeOpenFailed => 'Could not open the recipe';

  @override
  String get notificationsJustNow => 'just now';

  @override
  String notificationsMinutes(int count) {
    return '$count min ago';
  }

  @override
  String notificationsHours(int count) {
    return '$count hr ago';
  }

  @override
  String notificationsDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days ago',
      one: '1 day ago',
    );
    return '$_temp0';
  }

  @override
  String get notificationsMarkAll => 'Mark all as read';

  @override
  String get notificationsEmpty => 'No notifications';

  @override
  String get releasePromptTitle => 'An update is available';

  @override
  String get releasePromptRequired =>
      'This version is no longer supported. Update the app to continue.';

  @override
  String get releasePromptStoreError => 'Could not open the app store.';

  @override
  String get releasePromptChanges =>
      '• Improved Premium activation and purchase restoration.\n• Premium points are credited correctly after a connection interruption or payment retry.\n• Repeat scans and amount selection retain pack size and units.\n• Improved product suggestions and messages in Polish and English.';

  @override
  String detailPlanPortionHelp(int servings, int baseServings) {
    return 'Ingredients are scaled to $servings portions. Quantities written in the method refer to the original recipe ($baseServings portions).';
  }

  @override
  String get releasePromptApple => 'Open App Store';

  @override
  String get releasePromptGoogle => 'Open Google Play';

  @override
  String get releasePromptLater => 'Later';

  @override
  String get pantryAddProduct => 'Add product';

  @override
  String get pantryEmpty =>
      'Your pantry is empty. Add the products you have at home to quickly find out what you can cook.';

  @override
  String get pantryEnterAmount => 'Tap to enter an amount';

  @override
  String get pantryRemove => 'Remove from pantry';

  @override
  String get pantryScanBarcode => 'Scan a barcode';

  @override
  String get pantryScanMany => 'Scan multiple products';

  @override
  String get pantrySearchHint => 'Search for a product...';

  @override
  String get pantrySearchStart => 'Enter a product name.';

  @override
  String get pantrySearchEmpty => 'No results.';

  @override
  String pantrySaved(String name) {
    return 'Added \"$name\" to pantry.';
  }

  @override
  String get matchTitle => 'Cook from my pantry';

  @override
  String get matchPremium => 'Premium feature';

  @override
  String get matchPremiumBody =>
      'Matching recipes to what you have in your pantry is available with an active Premium subscription.';

  @override
  String get matchSeePremium => 'See Premium';

  @override
  String get matchSelectOne => 'Select at least one ingredient.';

  @override
  String get matchEmptyPantry =>
      'Your pantry is empty. Add the products you have at home to find matching recipes.';

  @override
  String get matchAddPantry => 'Add a product to pantry';

  @override
  String matchSelected(int selected, int total) {
    return 'Selected $selected of $total';
  }

  @override
  String get matchDeselect => 'Deselect all';

  @override
  String get matchSelectAll => 'Select all';

  @override
  String matchSearch(int count) {
    return 'Find recipes ($count)';
  }

  @override
  String get matchGenerate => 'Generate a new recipe with AI';

  @override
  String get matchResultsTitle => 'Matching recipes';

  @override
  String get matchResultsEmpty =>
      'No recipes in the catalogue match the selected ingredients. You can generate a new recipe with AI instead.';

  @override
  String get matchOtherAi => 'Nothing suitable? Generate with AI';

  @override
  String get matchReady => 'Ready to cook';

  @override
  String matchMissing(String ingredients) {
    return 'Missing: $ingredients';
  }

  @override
  String matchSelectPrompt(String ingredients) {
    return 'Generate a recipe for a dish using mainly these ingredients I have at home: $ingredients. You may add at most 2–3 commonly available ingredients, such as salt, spices or olive oil.';
  }

  @override
  String matchResultsPrompt(String ingredients) {
    return 'Generate a recipe for a dish using MAINLY these ingredients I have at home: $ingredients. You may add at most 2-3 extra commonly available ingredients (e.g. salt, spices, olive oil), if needed.';
  }

  @override
  String get leaderTitle => 'Recipe author ranking';

  @override
  String get leaderWeek => 'This week';

  @override
  String get leaderAll => 'All time';

  @override
  String get leaderEmptyWeek =>
      'No one has added an approved recipe\nthis week yet. Be the first!';

  @override
  String get leaderEmptyAll =>
      'No one has added an approved recipe\nto the shared catalogue yet.';

  @override
  String leaderCount(int count, String noun) {
    return '$count $noun';
  }

  @override
  String get leaderRecipeSingular => 'recipe';

  @override
  String get leaderRecipeFew => 'recipes';

  @override
  String get leaderRecipeMany => 'recipes';

  @override
  String get adGateTitle => 'Watch a short advert';

  @override
  String get adGateBody =>
      'To open the Diary, watch a short video advert to the end. This does not apply to Premium accounts — their Diary is always ad-free.';

  @override
  String get adGateFailed =>
      'Could not load the advert. Check your internet connection and try again.';

  @override
  String get adGateLoading => 'Loading advert...';

  @override
  String get adGateWatch => 'Watch advert';

  @override
  String get adGateLater => 'Not now';

  @override
  String get promosTitle => 'Promotions';

  @override
  String get promosAll => 'All';

  @override
  String get promosFailed => 'Could not load promotions.';

  @override
  String get promosLoyalty => 'Loyalty card required';

  @override
  String get promosEmpty => 'No active promotions at the moment.';

  @override
  String get statsTitle => 'Statistics';

  @override
  String get statsWeight => 'Weight change';

  @override
  String get statsWeightEmpty =>
      'Add at least one measurement in your profile.';

  @override
  String get statsAverageCalories => 'Average calories';

  @override
  String get statsHydration => 'Hydration';

  @override
  String get statsFavorite => 'Favourite meal';

  @override
  String get statsNoData => 'No data';

  @override
  String get statsDailyCalories => 'Daily calories';

  @override
  String get statsCaloriesEmpty => 'Add meals in the Diary to see the chart.';

  @override
  String get statsCalories => 'Calories';

  @override
  String get statsDailyMacros => 'Daily macros';

  @override
  String get statsMacrosEmpty => 'Macros will appear after you add meals.';

  @override
  String get statsProtein => 'Protein';

  @override
  String get statsFat => 'Fat';

  @override
  String get statsCarbs => 'Carbohydrates';

  @override
  String get statsDailyWater => 'Daily hydration';

  @override
  String get statsWaterEmpty => 'Log water in the Diary to see the chart.';

  @override
  String get statsWater => 'Water';

  @override
  String get statsRecentDays => 'Recently logged days';

  @override
  String get statsRecentEmpty => 'Logged meals and hydration will appear here.';

  @override
  String get statsWeekly => 'Insights from the last 7 days';

  @override
  String get statsPremiumTitle => 'Full report with Premium';

  @override
  String get statsPremiumBody =>
      'Unlock calorie, hydration and weight analysis with practical insights each week.';

  @override
  String get statsPremiumAction => 'View full report';

  @override
  String statsDailyMacroLine(
    String kcal,
    String protein,
    String fat,
    String carbs,
  ) {
    return '$kcal kcal  •  P $protein g  •  F $fat g  •  C $carbs g';
  }

  @override
  String statsWaterLine(int amount) {
    return 'Water: $amount ml';
  }

  @override
  String statsMaximum(String amount, String unit) {
    return 'Maximum: $amount $unit';
  }

  @override
  String insightRegularity(int count) {
    return 'Consistency: $count of 7 days';
  }

  @override
  String get insightEnough => 'You now have enough data to compare weeks.';

  @override
  String insightMoreDays(int count) {
    return 'Log $count more days for a more accurate report.';
  }

  @override
  String insightCalories(int count) {
    return 'Average $count kcal per day';
  }

  @override
  String get insightCaloriesDetail =>
      'Compare weekly averages rather than judging a single day.';

  @override
  String get insightWaterMissing => 'Hydration data is missing';

  @override
  String insightWaterAverage(int amount) {
    return 'Average $amount ml of water';
  }

  @override
  String get insightWaterEveryDay =>
      'Hydration was logged every day this week.';

  @override
  String insightWaterDays(int count) {
    return 'Hydration was logged on $count of 7 days.';
  }

  @override
  String get insightWeightStable => 'No significant weight change';

  @override
  String insightWeightChange(String amount) {
    return 'Weight change $amount kg';
  }

  @override
  String get insightWeightDetail =>
      'Comparison of the first and last measurements from the past 7 days.';

  @override
  String get cookingTipsTitle => 'Cooking tips';

  @override
  String get splashSubtitle => 'Plan meals wisely and save';

  @override
  String get onboardingStoresEmpty => 'No shops are available. Try again.';

  @override
  String get authCaptchaUnavailable =>
      'Could not load verification. Check your connection.';

  @override
  String get authCaptchaRetry => 'Retry';

  @override
  String get authCaptchaContinue => 'Continue anyway';

  @override
  String get authCaptchaRefresh => 'Refresh verification';

  @override
  String get adminProductsTitle => 'Submitted products';

  @override
  String get adminProductsEmpty => 'No products are awaiting review.';

  @override
  String get adminProductsRefresh => 'Refresh submissions';

  @override
  String get adminProductApproved => 'Product added to catalogue';

  @override
  String get adminProductRejected => 'Product rejected';

  @override
  String get adminNoNutrition => 'No nutritional information';

  @override
  String adminProductNutrition(
    String kcal,
    String protein,
    String fat,
    String carbs,
  ) {
    return 'Per 100 g: $kcal kcal · P $protein · F $fat · C $carbs';
  }

  @override
  String get adminReject => 'Reject';

  @override
  String get adminApprove => 'Approve';

  @override
  String get adminAllRecipesTitle => 'All user recipes';

  @override
  String get adminRecipesEmpty => 'No recipes have been added by users.';

  @override
  String get adminShowMore => 'Show more';

  @override
  String get adminPublic => 'Public';

  @override
  String get adminPending => 'Pending';

  @override
  String get adminRejected => 'Rejected';

  @override
  String get adminPrivate => 'Private';

  @override
  String get adminUnknownAuthor => 'Unknown author';

  @override
  String get adminDeleteRecipeTooltip => 'Delete recipe';

  @override
  String get adminDeleteRecipeTitle => 'Delete recipe?';

  @override
  String adminDeleteRecipeBody(String name) {
    return 'You will delete \"$name\", its comments and its links to shopping lists and meal plans used by other users. This cannot be undone.';
  }

  @override
  String get adminRecipeFallback => 'this recipe';

  @override
  String get adminUsersTitle => 'Users';

  @override
  String get adminUsersSearch => 'Search by email or name…';

  @override
  String get adminUsersOnlyBanned => 'Banned accounts only';

  @override
  String get adminUsersEmpty => 'No results.';

  @override
  String get adminUsersUnnamed => 'Unnamed';

  @override
  String adminUsersVersion(String version) {
    return 'Version: $version';
  }

  @override
  String adminUsersReason(String reason) {
    return 'Reason: $reason';
  }

  @override
  String adminUsersBanTitle(String name) {
    return 'Ban $name?';
  }

  @override
  String get adminUsersBanBody =>
      'This account will lose access to the app immediately, even if it is currently signed in. No data will be deleted, and the ban can be reversed.';

  @override
  String get adminUsersReasonLabel => 'Reason (visible to the user)';

  @override
  String get adminUsersBan => 'Ban';

  @override
  String get adminUsersUnban => 'Unban';

  @override
  String get adminUsersBanned => 'Account banned';

  @override
  String get adminUsersUnbanned => 'Account unbanned';

  @override
  String get adminCommentsTitle => 'Comments';

  @override
  String get adminCommentsSearch => 'Search comment text, author or recipe…';

  @override
  String get adminCommentsEmpty => 'No comments.';

  @override
  String adminCommentsRecipe(String name) {
    return 'on: $name';
  }

  @override
  String get adminCommentsPhotoOnly => '(photo only)';

  @override
  String get adminCommentsEmptyText => '(empty)';

  @override
  String get adminCommentsHasPhoto => 'includes a photo';

  @override
  String get adminCommentsDelete => 'Delete comment';

  @override
  String get adminCommentsDeleteTitle => 'Delete comment?';

  @override
  String get adminCommentsDeleteBody => 'This cannot be undone.';

  @override
  String get adminCommentsDeleted => 'Comment deleted';

  @override
  String get adminPhotosTitle => 'Photos awaiting review';

  @override
  String get adminPhotosEmpty => 'No photos are awaiting review.';

  @override
  String get adminPhotosApproved => 'Photo approved';

  @override
  String get adminPhotosRejected => 'Photo rejected';

  @override
  String get adminPhotosRecipe => 'Recipe';

  @override
  String get adminPhotosUnknownSubmitter => 'unknown';

  @override
  String adminPhotosSubmittedBy(String name) {
    return 'Submitted by: $name';
  }

  @override
  String get adminPhotosReplaceWarning =>
      'Please note: this recipe already has a photo — approving this one will replace it.';

  @override
  String get adminPhotosLoadError => 'Could not load the photo';

  @override
  String get adminPhotosApprove => 'Approve';

  @override
  String get adminMainTitle => 'Admin panel';

  @override
  String adminMainBroadcastSent(String count) {
    return 'Sent to $count users.';
  }

  @override
  String get adminMainReportsTitle => 'Content reports';

  @override
  String get adminMainReportsHelp =>
      'Recipes and comments reported by users as spam, harassment or other breaches of the terms.';

  @override
  String get adminMainReportsEmpty => 'No unresolved reports.';

  @override
  String get adminMainRecipeType => 'Recipe';

  @override
  String get adminMainCommentType => 'Comment';

  @override
  String adminMainReportDetails(String details) {
    return 'Details from reporter: $details';
  }

  @override
  String adminMainAuthor(String email) {
    return 'Author: $email';
  }

  @override
  String adminMainReporter(String email) {
    return 'Reported by: $email';
  }

  @override
  String get adminMainDismiss => 'Dismiss report';

  @override
  String get adminMainDeleteContent => 'Delete content';

  @override
  String get adminMainResolve => 'Mark as resolved';

  @override
  String get adminMainBroadcastTitle => 'Send a notification to everyone';

  @override
  String get adminMainBroadcastHelp =>
      'This goes to EVERY user’s in-app notifications — it cannot be undone. Check the text before sending.';

  @override
  String get adminMainBroadcastHint => 'Notification text...';

  @override
  String get adminMainBroadcastSend => 'Send to everyone';

  @override
  String get adminMainPromotionsLoadFailed =>
      'Could not load pending promotions.';

  @override
  String adminMainScanSummary(String found, String queued) {
    return 'Found $found; queued $queued for approval.';
  }

  @override
  String get adminMainScanPending =>
      'Scanning is continuing on the server. You can leave this panel; results will appear in the review queue.';

  @override
  String get adminMainPromotionApproved => 'Promotion approved';

  @override
  String get adminMainPromotionRejected => 'Promotion rejected';

  @override
  String get adminMainActionFailed => 'Could not complete the action';

  @override
  String get adminMainRecipesLoadFailed => 'Could not load pending recipes.';

  @override
  String get adminMainReportsLoadFailed => 'Could not load reports.';

  @override
  String get adminMainDeleteContentTitle => 'Delete the reported content?';

  @override
  String get adminMainDeleteContentHelp =>
      'The comment or recipe will be permanently deleted and the report closed. This cannot be undone.';

  @override
  String get adminMainContentDeleted => 'Content deleted; report closed';

  @override
  String get adminMainReportResolved => 'Report marked as resolved';

  @override
  String get adminMainReportDismissed => 'Report dismissed';

  @override
  String get adminMainRecipeApproved => 'Recipe approved';

  @override
  String get adminMainRecipeRejected => 'Recipe rejected';

  @override
  String get adminMainRecipesTitle => 'Recipes awaiting approval';

  @override
  String get adminMainRecipesHelp =>
      'Recipes submitted by Premium users to the shared public catalogue.';

  @override
  String get adminMainRecipesEmpty => 'No recipes are awaiting approval.';

  @override
  String adminMainRecipeMeta(
    String mealType,
    String servings,
    String difficulty,
  ) {
    return '$mealType • $servings servings • $difficulty';
  }

  @override
  String get adminMainRecipePreview =>
      'Tap to check ingredients, instructions, photo and macros';

  @override
  String get adminMainApprove => 'Approve';

  @override
  String get adminMainAiTitle => 'AI service status';

  @override
  String get adminMainAiHelp =>
      'Checks that the Gemini key works and that token/request limits have not been reached, for each model separately.';

  @override
  String get adminMainAiCheck => 'Check AI status';

  @override
  String get adminMainAiKeyMissing => 'The API key is not configured.';

  @override
  String get adminMainScanTitle => 'Scan promotional leaflets';

  @override
  String get adminMainScanHelp =>
      'AI searches online for the shop’s current leaflet and recognises its promotions. Results go to the approval queue below — nothing changes automatically.';

  @override
  String get adminMainUkScanUnavailable =>
      'UK promotion sources are being prepared. The Polish leaflet scanner does not create GBP promotions.';

  @override
  String adminMainScanShop(String store) {
    return 'Scan $store';
  }

  @override
  String adminMainScanningShop(String store) {
    return 'Scanning $store is continuing in the background. You can leave this panel.';
  }

  @override
  String get adminMainPendingTitle => 'Awaiting approval';

  @override
  String get adminMainPromotionsEmpty => 'No promotions are awaiting approval.';

  @override
  String get adminMainProductsNav => 'Products';

  @override
  String get adminMainUserRecipesNav => 'User recipes';

  @override
  String get campaignTitle => 'Campaigns';

  @override
  String get campaignRequired =>
      'Fill in the name, dates, shop offer configuration and recipient.';

  @override
  String get campaignConfirmGoogle => 'Confirm the Google Play offer';

  @override
  String get campaignConfirmApple => 'Confirm the App Store offer';

  @override
  String campaignConfirmPoints(String store) {
    return 'Enable only after setting a temporary price for this points pack in $store for all users. The in-app price comes directly from the store.';
  }

  @override
  String get campaignConfirmPremium =>
      'Enable only when the specified store offer is active, has exactly this discount and covers the right product. The app does not change the price itself.';

  @override
  String get campaignConfirm => 'Confirm';

  @override
  String get campaignDeleteTitle => 'Delete campaign?';

  @override
  String campaignDeleteBody(String name) {
    return 'Campaign “$name” will be removed from this panel. You must disable the store offer separately.';
  }

  @override
  String get campaignMarketGb => 'Market: United Kingdom • GBP • Europe/London';

  @override
  String get campaignMarketPl => 'Market: Poland • PLN • Europe/Warsaw';

  @override
  String get campaignHeading => 'Premium and points promotion';

  @override
  String get campaignHelp =>
      'Ribbons appear on the icons in the Premium panel. An iOS subscription opens an Apple offer code; Android selects a Google Play offer. For points, set a temporary product price for everyone in the relevant store.';

  @override
  String get campaignName => 'Campaign name';

  @override
  String get campaignStore => 'Store';

  @override
  String get campaignOffer => 'Offer';

  @override
  String get campaignSubscription => 'Premium subscription';

  @override
  String get campaignPoints => 'Premium points';

  @override
  String get campaignProduct => 'Product covered by offer';

  @override
  String get campaignDiscount => 'Discount';

  @override
  String get campaignAudience => 'Audience';

  @override
  String get campaignEveryone => 'Everyone';

  @override
  String get campaignOneUser => 'One user';

  @override
  String get campaignEmail => 'User email';

  @override
  String get campaignDates => 'Choose dates';

  @override
  String get campaignAppleUrl => 'Apple offer code link';

  @override
  String get campaignAppleUrlHelp =>
      'Link: apps.apple.com/redeem?ctx=offercodes…';

  @override
  String get campaignBasePlan => 'Google Play: base plan ID';

  @override
  String get campaignAndroidOffer => 'Google Play: offer ID';

  @override
  String campaignPointsHelp(String store) {
    return 'First schedule a temporary price reduction for this points pack in $store. The campaign displays a ribbon, but the price always comes directly from the store.';
  }

  @override
  String get campaignSaving => 'Saving…';

  @override
  String get campaignCreate => 'Create campaign (disabled)';

  @override
  String get campaignSaved => 'Saved campaigns';

  @override
  String get campaignEmpty => 'No campaigns.';

  @override
  String get campaignActive => 'Active';

  @override
  String get campaignDeleteTooltip => 'Delete campaign';

  @override
  String get adminMarketLabel => 'Catalogue market';

  @override
  String get adminMarketBusy => 'Wait for the current operation to finish.';

  @override
  String get adminMarketHelp =>
      'Changes the data view, not your account’s country.';

  @override
  String get adminMarketPl => 'Poland';

  @override
  String get adminMarketGb => 'United Kingdom';

  @override
  String get approvalRecipePending =>
      'This recipe is awaiting your approval for the shared catalogue';

  @override
  String get approvalRecipeApprove => 'Approve';

  @override
  String get approvalRecipeApproved => 'Recipe approved';

  @override
  String get approvalRecipeRejected => 'Recipe rejected';

  @override
  String get approvalRecipeFailed => 'Could not complete the action';

  @override
  String get shoppingAddQueryHint => 'Enter any item…';

  @override
  String get shoppingAddCustom => 'Add the item you entered';

  @override
  String get shoppingAddMatches =>
      'Matching products from the catalogue and previous scans';

  @override
  String get shoppingAddMinimumQuery =>
      'Enter at least 2 characters to search for a product.';

  @override
  String get shoppingAddNoResults => 'No product with this name was found.';

  @override
  String shoppingAddSuccess(String name) {
    return 'Added: $name';
  }

  @override
  String get shoppingAddCustomFailed => 'Could not add the item';

  @override
  String get shoppingAddProductFailed => 'Could not add the product';

  @override
  String get shoppingAddProductFallback => 'Product';

  @override
  String get shoppingAddCatalogSource => 'App catalogue';

  @override
  String get shoppingAddCacheSource => 'Previously scanned';

  @override
  String exportListHeading(String store) {
    return 'My shopping list: $store';
  }

  @override
  String exportListSubject(String store) {
    return 'Shopping list - $store';
  }

  @override
  String get exportListTitle => 'Export list';

  @override
  String get exportListCopy => 'Copy to clipboard';

  @override
  String get exportListCopied => 'Copied to clipboard!';

  @override
  String exportListOpenApp(String name) {
    return 'Open $name';
  }

  @override
  String get exportListAppMissing => 'This app is not installed.';

  @override
  String get exportListAppFailed => 'Could not open the app.';

  @override
  String get exportListComingSoon => 'Coming soon';

  @override
  String get diarySignInView => 'Sign in to view your diary.';

  @override
  String get diarySignInAdd => 'Sign in to add an entry.';

  @override
  String get authStoredSessionFailed =>
      'We could not restore your saved session. Please try signing in again.';

  @override
  String authGoogleNativeFailed(Object code) {
    return 'Could not sign in with Google ($code). Please try again.';
  }

  @override
  String get authGoogleTokenUnavailable =>
      'Could not obtain the Google identity token.';

  @override
  String get authAppleNativeFailed =>
      'Could not sign in with Apple. Please try again.';

  @override
  String get authAppleTokenUnavailable =>
      'Could not obtain the Apple identity token.';

  @override
  String get shoppingLimitTitle => 'More shopping? Go unlimited with Premium';

  @override
  String get shoppingLimitDescription =>
      'You have used your free shopping list this week. With Premium, create separate lists for recipes, shops and your next shop — whenever you need them.';

  @override
  String get shoppingLimitSeePremium => 'Explore Premium';

  @override
  String get shoppingLimitBack => 'Back to my shopping list';

  @override
  String get shoppingLimitShort =>
      'You have reached this week\'s list limit. Create more lists with Premium.';
}
