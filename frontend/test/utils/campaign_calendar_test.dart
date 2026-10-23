import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meal_planner/utils/campaign_calendar.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

void main() {
  for (final country in ['PL', 'GB']) {
    for (final day in [
      DateTime(2026, 1, 14),
      DateTime(2026, 7, 1),
      DateTime(2026, 3, 29),
      DateTime(2026, 10, 25),
    ]) {
      test('$country calendar display round-trips inclusive day $day', () {
        expect(
          campaignCalendarDay(campaignBoundaryUtc(day, country), country),
          day,
        );
        expect(
          campaignCalendarDay(
            campaignBoundaryUtc(day, country, followingDay: true),
            country,
            exclusiveEnd: true,
          ),
          day,
        );
      });
    }
  }
  test('legacy partial-day end is not moved to the previous day', () {
    expect(
      campaignCalendarDay(
        DateTime.utc(2026, 7, 10, 18),
        'GB',
        exclusiveEnd: true,
      ),
      DateTime(2026, 7, 10),
    );
  });
  test('campaign dates use the selected market, not the admin phone', () {
    final day = DateTime(2026, 10, 21);
    expect(campaignBoundaryUtc(day, 'GB'), DateTime.utc(2026, 10, 20, 23));
    expect(campaignBoundaryUtc(day, 'PL'), DateTime.utc(2026, 10, 20, 22));
  });
  for (final country in ['PL', 'GB']) {
    for (final entry in [(3, 29, 23), (10, 25, 25)]) {
      test('$country keeps the whole calendar day across DST $entry', () {
        final day = DateTime(2026, entry.$1, entry.$2);
        final start = campaignBoundaryUtc(day, country);
        final end = campaignBoundaryUtc(day, country, followingDay: true);
        expect(end.difference(start).inHours, entry.$3);
      });
    }
  }
  test('does not reset the existing notification timezone', () {
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Europe/Warsaw'));
    campaignBoundaryUtc(DateTime(2026, 10, 21), 'GB');
    expect(tz.local.name, 'Europe/Warsaw');
  });
  test('unsupported markets are rejected', () {
    expect(
      () => campaignBoundaryUtc(DateTime(2026), 'US'),
      throwsArgumentError,
    );
  });
}
