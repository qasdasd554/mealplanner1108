import '../models/product.dart';
import 'quantity_formatter.dart';

String storePriceVerificationLabel(StoreProduct product) {
  return priceVerificationLabel(product.lastVerified);
}

String priceVerificationLabel(DateTime? verified) {
  if (verified == null) return 'cena orientacyjna';
  return 'cena sprawdzona '
      '${verified.day.toString().padLeft(2, '0')}.'
      '${verified.month.toString().padLeft(2, '0')}.'
      '${verified.year}';
}

String storePriceQuantityLabel(Product? product) {
  if (product == null ||
      !product.defaultQuantity.isFinite ||
      product.defaultQuantity <= 0 ||
      product.unit.trim().isEmpty) {
    return '/ jednostka nieokreślona';
  }
  return '/ ${formatQuantity(product.defaultQuantity, product.unit)} '
      '${formatUnitLabel(product.unit)}';
}
