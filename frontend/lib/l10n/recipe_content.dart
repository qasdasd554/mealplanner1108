import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';
import '../models/recipe.dart';
import '../models/product.dart';
import '../models/ingredient_preferences.dart';
import '../models/barcode_lookup_result.dart';
import 'market_locale.dart';
import 'system_content_data.dart';

Map<String, dynamic>? _matchingText(
  Recipe recipe,
  String locale, {
  bool details = false,
}) {
  if (!locale.startsWith('en') || recipe.createdByUserId != null) return null;
  final entry = systemRecipeText[recipe.id];
  if (entry == null) return null;
  final source = entry['source'] as Map<String, dynamic>;
  if (recipe.name != source['name'] ||
      recipe.description != source['description'])
    return null;
  if (details &&
      (!listEquals(
            recipe.instructions,
            (source['instructions'] as List).cast<String>(),
          ) ||
          !listEquals(
            recipe.suggestedSeasonings,
            (source['suggested_seasonings'] as List).cast<String>(),
          )))
    return null;
  return entry['en_GB'] as Map<String, dynamic>;
}

/// Display-only adapters. Canonical names, photo keys and save payloads stay
/// untouched. Source identity/text guards exclude authored and edited content.
extension RecipeContentDisplay on Recipe {
  String nameForLanguage(String locale) =>
      _matchingText(this, locale)?['name'] as String? ?? name;
  String? descriptionForLanguage(String locale) =>
      _matchingText(this, locale)?['description'] as String? ?? description;
  List<String> instructionsForLanguage(String locale) =>
      (_matchingText(this, locale, details: true)?['instructions'] as List?)
          ?.cast<String>() ??
      instructions;
  List<String> seasoningsForLanguage(String locale) =>
      (_matchingText(this, locale, details: true)?['suggested_seasonings']
              as List?)
          ?.cast<String>() ??
      suggestedSeasonings;

  String displayName(BuildContext context) =>
      nameForLanguage(context.strings.localeName);
  String? displayDescription(BuildContext context) =>
      descriptionForLanguage(context.strings.localeName);
  List<String> displayInstructions(BuildContext context) =>
      instructionsForLanguage(context.strings.localeName);
  List<String> displaySeasonings(BuildContext context) =>
      seasoningsForLanguage(context.strings.localeName);
}

String? ingredientNameForLanguage(String id, String? name, String locale) {
  if (!locale.startsWith('en')) return name;
  final entry = systemIngredientText[id];
  return entry != null && entry['source'] == name ? entry['en_GB'] : name;
}

extension RecipeIngredientContentDisplay on RecipeIngredient {
  String? displayName(BuildContext context) => ingredientNameForLanguage(
    productId,
    productName ?? product?.name,
    context.strings.localeName,
  );
}

extension SystemProductContentDisplay on Product {
  String displayName(BuildContext context) =>
      ingredientNameForLanguage(id, name, context.strings.localeName) ?? name;
}

extension IngredientChoiceContentDisplay on IngredientChoice {
  String displayName(BuildContext context) =>
      ingredientNameForLanguage(id, name, context.strings.localeName) ?? name;
}

extension LookupContentDisplay on BarcodeLookupResult {
  String? displayName(BuildContext context) => ingredientNameForLanguage(
    existingProductId ?? '',
    name,
    context.strings.localeName,
  );
}
