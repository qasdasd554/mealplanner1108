import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meal_planner/models/user.dart';

User _user({required DateTime? expiresAt, bool serverAccess = true}) {
  return User(
    id: 'user-1',
    email: 'premium@example.com',
    householdSize: 1,
    isPremium: true,
    hasPremiumAccessFromServer: serverAccess,
    premiumExpiresAt: expiresAt,
    createdAt: DateTime.now().subtract(const Duration(days: 30)),
  );
}

void main() {
  test('profil odczytuje zweryfikowaną nazwę TikTok', () {
    final user = User.fromJson({
      'id': 'user-1',
      'email': 'user@example.com',
      'display_name': 'Adam',
      'tiktok_username': 'meal.planner',
      'household_size': 1,
      'created_at': '2026-10-07T08:00:00Z',
    });

    expect(user.tiktokUsername, 'meal.planner');
  });

  test('wygasła data ma pierwszeństwo przed starą odpowiedzią serwera', () {
    final user = _user(
      expiresAt: DateTime.now().subtract(const Duration(seconds: 1)),
    );

    expect(user.hasPremiumAccess, isFalse);
  });

  test('przyszła data i dostęp z serwera pozostawiają Premium', () {
    final user = _user(expiresAt: DateTime.now().add(const Duration(days: 1)));

    expect(user.hasPremiumAccess, isTrue);
  });
}
