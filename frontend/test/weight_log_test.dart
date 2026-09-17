import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meal_planner/models/weight_log.dart';

void main() {
  test('odczytuje dzienny pomiar wagi z API', () {
    final entry = WeightLogEntry.fromJson({
      'id': 'weight-1',
      'date': '2026-09-14',
      'weight_kg': 72.4,
    });

    expect(entry.id, 'weight-1');
    expect(entry.date, DateTime(2026, 9, 14));
    expect(entry.weightKg, 72.4);
  });
}

