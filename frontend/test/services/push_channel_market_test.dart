import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meal_planner/models/user.dart';
import 'package:smart_meal_planner/providers/auth_provider.dart';
import 'package:smart_meal_planner/services/auth_service.dart';
import 'package:smart_meal_planner/services/push_channel_config.dart';

User profile(String country, {bool verified = true}) => User.fromJson({
  'id': 'synthetic-${country.toLowerCase()}',
  'email': 'push@example.invalid',
  'country_code': country,
  'is_email_verified': verified,
  'created_at': '2026-10-24T00:00:00Z',
});

class _Auth extends AuthService {
  final Future<User> Function() fetch;
  _Auth(this.fetch);
  @override
  Future<User> getProfile() => fetch();
  @override
  Future<void> logout() async {}
}

void main() {
  for (final country in ['GB', 'UK', ' gb ']) {
    test('$country channel name and description are English', () {
      final channel = pushChannelForCountry(country);
      expect(channel.name, 'Notifications');
      expect(channel.description, 'Comments, competitions and app updates');
      expect(channel.id, 'meal_planner_default');
      expect(channel.importance, Importance.high);
    });
  }
  for (final country in [null, 'PL', 'DE']) {
    test('$country preserves original Polish channel and settings', () {
      final channel = pushChannelForCountry(country);
      expect(channel.name, 'Powiadomienia');
      expect(
        channel.description,
        'Komentarze, konkursy i informacje z aplikacji',
      );
      expect(channel.id, 'meal_planner_default');
      expect(channel.importance, Importance.high);
      expect(channel.playSound, isTrue);
      expect(channel.enableVibration, isTrue);
    });
  }
  for (final country in ['PL', 'GB']) {
    test(
      'push registration receives the persisted $country account market',
      () async {
        final countries = <String>[];
        final provider = AuthProvider(
          service: _Auth(() async => profile(country)),
          readToken: () async => 'synthetic-token',
          unregisterPush: () async {},
          registerPush: (country) async => countries.add(country),
        );
        addTearDown(provider.dispose);
        await provider.initialization;
        expect(countries, [country]);
      },
    );
  }
  test('unverified account does not request notification permission', () async {
    final countries = <String>[];
    final provider = AuthProvider(
      service: _Auth(() async => profile('GB', verified: false)),
      readToken: () async => 'synthetic-token',
      unregisterPush: () async {},
      registerPush: (country) async => countries.add(country),
    );
    addTearDown(provider.dispose);
    await provider.initialization;
    expect(countries, isEmpty);
  });
  test(
    'late profile after logout cannot relabel notification channel',
    () async {
      final countries = <String>[];
      final pending = Completer<User>();
      final provider = AuthProvider(
        service: _Auth(() => pending.future),
        readToken: () async => 'synthetic-token',
        unregisterPush: () async {},
        registerPush: (country) async => countries.add(country),
      );
      addTearDown(provider.dispose);
      await Future<void>.delayed(Duration.zero);
      await provider.logout();
      pending.complete(profile('GB'));
      await provider.initialization;
      expect(countries, isEmpty);
    },
  );
}
