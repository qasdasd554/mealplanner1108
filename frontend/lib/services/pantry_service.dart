import '../models/product.dart';
import 'api_client.dart';
import '../config/api_config.dart';

/// Pojedynczy produkt zapisany w spiżarni użytkownika.
class PantryItem {
  final String id;
  final Product product;
  final double? quantity;
  final String? unit;

  PantryItem({required this.id, required this.product, this.quantity, this.unit});

  factory PantryItem.fromJson(Map<String, dynamic> json) {
    return PantryItem(
      id: json['id'] as String,
      product: Product.fromJson(json['product'] as Map<String, dynamic>),
      quantity: (json['quantity'] as num?)?.toDouble(),
      unit: json['unit'] as String?,
    );
  }
}

/// Spiżarnia — trwała lista produktów, które użytkownik faktycznie ma w
/// domu, niezależna od żadnego konkretnego planu posiłków. Używana m.in.
/// jako źródło dla "Co ugotować z tego, co mam".
class PantryService {
  final ApiClient _client = ApiClient();

  Future<List<PantryItem>> getPantry() async {
    final response = await _client.get(ApiConfig.pantry);
    return (response as List).map((e) => PantryItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<PantryItem>> addItems(List<String> productIds) async {
    final response = await _client.post(ApiConfig.pantry, body: {'product_ids': productIds});
    return (response as List).map((e) => PantryItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> deleteItem(String itemId) async {
    await _client.delete('${ApiConfig.pantry}$itemId');
  }
}
