import 'dart:convert';
import 'dart:typed_data';

import '../config/api_config.dart';
import 'api_client.dart';

typedef ReceiptLine = ({String name, double? quantity, String unit});
typedef ReceiptPreview = ({String? token, List<ReceiptLine> items});
typedef ReceiptSelection = ({int index, double quantity, String unit});
typedef ReceiptSave = ({int savedCount, int skippedCount, bool alreadySaved});

class PantryReceiptService {
  final ApiClient _client = ApiClient();
  static const maxPhotoBytes = 8 * 1024 * 1024;
  int get sessionGeneration => _client.sessionGeneration;

  Future<ReceiptPreview> scan(Uint8List bytes) async {
    final data =
        await _client.post(
              '${ApiConfig.pantry}receipt/scan',
              body: {'photo': base64Encode(bytes)},
              timeout: const Duration(seconds: 95),
            )
            as Map<String, dynamic>;
    return (
      token: data['token'] as String?,
      items:
          (data['items'] as List)
              .map<ReceiptLine>(
                (row) => (
                  name: row['name'] as String,
                  quantity: (row['quantity'] as num?)?.toDouble(),
                  unit: row['unit'] as String,
                ),
              )
              .toList(),
    );
  }

  Future<ReceiptSave> save(String token, List<ReceiptSelection> items) async {
    final data =
        await _client.post(
              '${ApiConfig.pantry}receipt/save',
              body: {
                'token': token,
                'items': [
                  for (final item in items)
                    {
                      'index': item.index,
                      'quantity': item.quantity,
                      'unit': item.unit,
                    },
                ],
              },
            )
            as Map<String, dynamic>;
    return (
      savedCount: data['saved_count'] as int,
      skippedCount: data['skipped_count'] as int,
      alreadySaved: data['already_saved'] as bool,
    );
  }
}
