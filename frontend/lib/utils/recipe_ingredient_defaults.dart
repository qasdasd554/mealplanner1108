double defaultRecipeIngredientQuantity(String unit) {
  return {'opak', 'szt', 'kg', 'l'}.contains(unit) ? 1 : 100;
}
