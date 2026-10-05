import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meal_planner/utils/calendar_day.dart';

void main() {
  test('godziny tego samego dnia są traktowane jako ten sam dzień', () {
    expect(
      isSameCalendarDay(
        DateTime(2026, 10, 5, 0, 1),
        DateTime(2026, 10, 5, 23, 59),
      ),
      isTrue,
    );
  });

  test('powrót od piątku do poniedziałku wykrywa zmianę dnia', () {
    expect(
      isSameCalendarDay(DateTime(2026, 10, 2), DateTime(2026, 10, 5)),
      isFalse,
    );
  });
}
