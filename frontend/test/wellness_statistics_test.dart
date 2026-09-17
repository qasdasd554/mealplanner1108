import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meal_planner/models/wellness_statistics.dart';

void main() {
  test('czyta statystyki dzienne, wagę i ulubiony posiłek', () {
    final statistics = WellnessStatistics.fromJson({
      'days': [
        {
          'date': '2026-09-15',
          'calories': 1850,
          'protein': 102.5,
          'fat': 60,
          'carbs': 210,
          'water_ml': 2000,
        }
      ],
      'weights': [
        {'id': 'weight-1', 'date': '2026-09-15', 'weight_kg': 79.4}
      ],
      'favorite_meal': 'Owsianka',
      'average_calories': 1850,
      'average_protein': 102.5,
      'average_fat': 60,
      'average_carbs': 210,
      'average_water_ml': 2000,
    });

    expect(statistics.days.single.calories, 1850);
    expect(statistics.weights.single.weightKg, 79.4);
    expect(statistics.favoriteMeal, 'Owsianka');
    expect(statistics.averageWaterMl, 2000);
  });

  test('scala stare duplikaty pomiarów z tego samego dnia', () {
    final statistics = WellnessStatistics.fromJson({
      'days': const [],
      'weights': [
        {'id': 'starszy', 'date': '2026-09-15', 'weight_kg': 80},
        {'id': 'nowszy', 'date': '2026-09-15', 'weight_kg': 79.4},
      ],
    });

    expect(statistics.weights, hasLength(1));
    expect(statistics.weights.single.id, 'nowszy');
    expect(statistics.weights.single.weightKg, 79.4);
  });
}
