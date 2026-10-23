double defaultRecipeIngredientQuantity(String unit) {
  return {'opak', 'szt', 'kg', 'l'}.contains(unit) ? 1 : 100;
}

/// Mirrors the authoritative API is_ingredient_quantity_reasonable rule.
double maxRecipeIngredientQuantity(String unit) =>
    {'opak', 'szt'}.contains(unit) ? 50 : 20000;

bool validRecipeIngredientQuantity(double value, String unit) =>
    value.isFinite && value > 0 && value <= maxRecipeIngredientQuantity(unit);
