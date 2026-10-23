import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

tz.Location _campaignZone(String countryCode) {
  final zoneName = switch (countryCode) {
    'GB' => 'Europe/London',
    'PL' => 'Europe/Warsaw',
    _ => throw ArgumentError.value(countryCode, 'countryCode'),
  };
  if (!tz.timeZoneDatabase.isInitialized) tzdata.initializeTimeZones();
  return tz.getLocation(zoneName);
}

/// Date-only display in the campaign's market, never the admin phone's zone.
/// An exclusive midnight end belongs to the preceding calendar day, even on
/// a 23/25-hour day. Legacy partial-day end times retain their own date.
DateTime campaignCalendarDay(
  DateTime instant,
  String countryCode, {
  bool exclusiveEnd = false,
}) {
  final zone = _campaignZone(countryCode);
  final local = tz.TZDateTime.from(instant.toUtc(), zone);
  final atMidnight =
      local.hour == 0 &&
      local.minute == 0 &&
      local.second == 0 &&
      local.millisecond == 0 &&
      local.microsecond == 0;
  final day = tz.TZDateTime(
    zone,
    local.year,
    local.month,
    local.day - (exclusiveEnd && atMidnight ? 1 : 0),
  );
  return DateTime(day.year, day.month, day.day);
}

/// Calendar boundaries belong to the selected market, not the admin's phone.
/// End dates are exclusive midnight of the following calendar day (DST-safe).
DateTime campaignBoundaryUtc(
  DateTime day,
  String countryCode, {
  bool followingDay = false,
}) {
  final zone = _campaignZone(countryCode);
  return tz.TZDateTime(
    zone,
    day.year,
    day.month,
    day.day + (followingDay ? 1 : 0),
  ).toUtc();
}
