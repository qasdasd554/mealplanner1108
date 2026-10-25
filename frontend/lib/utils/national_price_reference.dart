/// Copy only: a national quantity estimate is not a shop price or package.
String? nationalPriceReferenceLabel(
  Map<String, dynamic>? source, {
  required bool english,
  String prefix = '',
}) {
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
