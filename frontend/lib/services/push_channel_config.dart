import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'account_market.dart';

/// Keep the original channel ID: changing language must not reset user settings.
AndroidNotificationChannel pushChannelForCountry(String? countryCode) =>
    normalizeAccountCountry(countryCode) == 'GB'
        ? const AndroidNotificationChannel(
          'meal_planner_default',
          'Notifications',
          description: 'Comments, competitions and app updates',
          importance: Importance.high,
        )
        : const AndroidNotificationChannel(
          'meal_planner_default',
          'Powiadomienia',
          description: 'Komentarze, konkursy i informacje z aplikacji',
          importance: Importance.high,
        );
