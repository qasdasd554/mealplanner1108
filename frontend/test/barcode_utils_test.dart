import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meal_planner/utils/barcode_utils.dart';

void main() {
  test('zostawia zwykły EAN-13 bez zmian', () {
    expect(normalizeScannedBarcode('5449000000996'), '5449000000996');
  });

  test('usuwa identyfikator AIM zwracany przez skaner na żywo', () {
    expect(normalizeScannedBarcode(']E0 5449-0000-0099-6'), '5449000000996');
  });

  test('odrzuca tekst, który nie jest kodem GTIN', () {
    expect(normalizeScannedBarcode('12345'), isNull);
  });

  test('odrzuca kod z błędną cyfrą kontrolną', () {
    expect(normalizeScannedBarcode('5449000000997'), isNull);
  });

  test('potwierdza kod dopiero w drugiej kolejnej klatce', () {
    final confirmation = BarcodeScanConfirmation();
    final now = DateTime(2026, 9, 25, 12);
    expect(confirmation.confirm('5449000000996', now), isFalse);
    expect(
      confirmation.confirm(
        '5449000000996',
        now.add(const Duration(milliseconds: 120)),
      ),
      isTrue,
    );
  });
}
