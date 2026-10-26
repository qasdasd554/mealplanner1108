/// Copy only: a national quantity estimate is not a shop price or package.
String? nationalPriceReferenceLabel(
  Map<String, dynamic>? source, {
  required bool english,
  String prefix = '',
}) {
  if (source?['provider'] == 'uk_catalogue_estimate' &&
      source?['basis'] == 'required_quantity_not_shop_price' &&
      source?['confirms_store_stock'] == false &&
      source?['confirms_package'] == false) {
    return prefix +
        (english
            ? 'Catalogue estimate, needed amount — not a live shop price'
            : 'Szacunek katalogowy, potrzebna ilość — nie bieżąca cena sklepu');
  }
  final period = source?['period']?.toString() ?? '';
  if (source?['provider'] != 'ons_national_average' ||
      source?['basis'] != 'required_quantity_not_shop_price' ||
      !RegExp(r'^\d{4}-(0[1-9]|1[0-2])$').hasMatch(period)) {
    return null;
  }
  return prefix +
      (english
          ? 'ONS UK average ($period), needed amount — not a shop price'
          : 'Średnia UK ONS ($period), potrzebna ilość — nie cena sklepu');
}
