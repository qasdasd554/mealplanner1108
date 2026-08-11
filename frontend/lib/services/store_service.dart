import '../models/store.dart';
import '../models/product.dart';
import 'api_client.dart';
import '../config/api_config.dart';

class StoreService {
  final ApiClient _client = ApiClient();

  Future<List<Store>> getStores() async {
    final response = await _client.get(ApiConfig.stores);
    if (response is List) {
      return response.map((e) => Store.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  Future<Store> getStore(String storeId) async {
    final response = await _client.get('${ApiConfig.stores}$storeId');
    return Store.fromJson(response as Map<String, dynamic>);
  }

  Future<List<StoreDepartment>> getStoreDepartments(String storeId) async {
    final response = await _client.get('${ApiConfig.stores}$storeId/departments');
    if (response is List) {
      return response
          .map((e) => StoreDepartment.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<List<StoreProduct>> getStoreProducts(
    String storeId, {
    int skip = 0,
    int limit = 20,
    String? search,
    String? departmentId,
  }) async {
    var path = '${ApiConfig.stores}$storeId/products?skip=$skip&limit=$limit';
    if (search != null && search.isNotEmpty) {
      path += '&search=${Uri.encodeComponent(search)}';
    }
    if (departmentId != null && departmentId.isNotEmpty) {
      path += '&department_id=$departmentId';
    }

    final response = await _client.get(path);
    if (response is List) {
      return response
          .map((e) => StoreProduct.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }
}
