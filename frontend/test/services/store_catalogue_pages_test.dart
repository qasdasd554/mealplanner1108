import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:smart_meal_planner/services/api_client.dart';
import 'package:smart_meal_planner/services/store_service.dart';

class _Pages extends ApiClient {
  final paths = <Uri>[];
  _Pages() : super.forTesting(httpClient: http.Client());
  @override
  Future<dynamic> get(String path, {Duration? timeout}) async {
    final uri = Uri.parse(path);
    paths.add(uri);
    final skip = int.parse(uri.queryParameters['skip']!);
    return List.generate(
      skip == 0 ? 200 : 190,
      (i) => {
        'id': 'reference-${skip + i}',
        'store_id': 'shop',
        'product_id': 'food-${skip + i}',
        'price': null,
        'is_available': null,
        'currency_code': 'GBP',
        'catalogue_kind': 'generic_food',
        'availability_scope': 'generic_food_reference',
        'price_basis': 'unknown',
        'name_en': 'Food ${skip + i}',
        'product': {
          'id': 'food-${skip + i}',
          'name': 'Food ${skip + i}',
          'unit': 'g',
        },
      },
    );
  }
}

void main() {
  test(
    'all 390 shop foods are paged with opt-in and literal English search',
    () async {
      final client = _Pages();
      final rows = await StoreService(
        client: client,
      ).getAllStoreProducts('shop', search: 'Rice & oats');
      expect(rows, hasLength(390));
      expect(rows.every((row) => row.hasValidGenericReference), isTrue);
      expect(client.paths.map((p) => p.queryParameters['skip']), ['0', '200']);
      for (final path in client.paths) {
        expect(path.queryParameters['include_generic_foods'], 'true');
        expect(path.queryParameters['search'], 'Rice & oats');
        expect(path.queryParameters['limit'], '200');
      }
    },
  );
}
