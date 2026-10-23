import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meal_planner/models/user.dart';
import 'package:smart_meal_planner/providers/auth_provider.dart';
import 'package:smart_meal_planner/services/auth_service.dart';

class _Service extends AuthService {
  int profileWrites = 0;
  int bonusCalls = 0;
  bool failAllergens = false;
  bool failBonus = false;
  bool failProfileRead = false;
  Completer<void>? pendingAllergens;
  List<String>? savedAllergens;
  User user = User.fromJson({
    'id': 'synthetic',
    'email': 'synthetic@example.invalid',
    'is_email_verified': false,
    'created_at': '2026-10-22T00:00:00',
  });
  @override
  Future<bool> attemptGoogleSilentLogin() async => false;
  @override
  Future<void> logout() async {}
  @override
  Future<User> getProfile() async {
    if (failProfileRead) throw StateError('synthetic offline');
    return user;
  }

  @override
  Future<User> updateProfile({
    String? displayName,
    String? tiktokUsername,
    String? preferredStoreId,
    Map<String, dynamic>? dietaryPreferences,
    int? householdSize,
    double? weightKg,
    double? heightCm,
    int? age,
    String? gender,
    String? activityLevel,
    int? dailyKcalGoal,
    String? avatar,
    String? avatarPhotoBase64,
  }) async {
    profileWrites++;
    user = User.fromJson({
      'id': 'synthetic',
      'email': 'synthetic@example.invalid',
      'is_email_verified': false,
      'preferred_store_id': preferredStoreId,
      'created_at': '2026-10-22T00:00:00',
    });
    return user;
  }

  @override
  Future<void> updateAllergens(List<String> ids) async {
    savedAllergens = List.of(ids);
    if (failAllergens) throw StateError('synthetic offline');
    await pendingAllergens?.future;
  }

  @override
  Future<int> claimOnboardingBonus({void Function(int)? onTotalPoints}) async {
    bonusCalls++;
    if (failBonus) throw StateError('synthetic offline');
    user = user.copyWith(premiumPoints: 6);
    onTotalPoints?.call(6);
    return 4;
  }
}

Future<bool> save(AuthProvider auth, [List<String> allergens = const []]) =>
    auth.saveOnboardingPreferences(
      storeId: 'store-1',
      allergenIds: allergens,
      diet: 'Bez ograniczeń',
      householdSize: 1,
    );

void main() {
  test('copying a points balance retains verification and avatar fields', () {
    final user = User.fromJson({
      'id': 'synthetic',
      'email': 'synthetic@example.invalid',
      'created_at': '2026-10-22T00:00:00',
      'is_email_verified': true,
      'avatar': 'chef',
      'avatar_photo_base64': 'synthetic-photo',
      'country_code': 'GB',
    });
    final updated = user.copyWith(premiumPoints: 6);
    expect(updated.isEmailVerified, isTrue);
    expect(updated.avatar, user.avatar);
    expect(updated.avatarPhotoBase64, user.avatarPhotoBase64);
    expect(updated.countryCode, 'GB');
  });
  late _Service service;
  late AuthProvider auth;
  setUp(() async {
    service = _Service();
    auth = AuthProvider(
      service: service,
      readToken: () async => null,
      unregisterPush: () async {},
    );
    await auth.initialization;
  });
  tearDown(() => auth.dispose());
  test(
    'confirmed bonus balance remains usable if the profile refresh is offline',
    () async {
      service.failProfileRead = true;
      expect(await save(auth), isTrue);
      expect(auth.lastBonusPoints, 4);
      expect(
        auth.currentUser?.premiumPoints,
        6,
        reason: 'use server balance, not a locally guessed increment',
      );
    },
  );
  test(
    'overlapping onboarding submits perform one save and one bonus claim',
    () async {
      service.pendingAllergens = Completer<void>();
      final first = save(auth);
      final second = save(auth);
      service.pendingAllergens!.complete();
      expect(await first, isTrue);
      expect(await second, isFalse);
      expect(service.profileWrites, 1);
      expect(service.bonusCalls, 1);
      expect(auth.isLoading, isFalse);
    },
  );
  test(
    'failed allergen save cannot mark onboarding complete by saving the store',
    () async {
      service.failAllergens = true;
      expect(await save(auth), isFalse);
      expect(service.profileWrites, 0);
      expect(service.bonusCalls, 0);
      expect(auth.isLoading, isFalse);
      expect(auth.errorMessage, isNotEmpty);
      service.failAllergens = false;
      expect(await save(auth), isTrue);
      expect(service.profileWrites, 1);
    },
  );
  test(
    'logout while saving allergens prevents subsequent writes and bonus',
    () async {
      service.pendingAllergens = Completer<void>();
      final operation = save(auth);
      await Future<void>.delayed(Duration.zero);
      await auth.logout();
      service.pendingAllergens!.complete();
      expect(await operation, isFalse);
      expect(service.profileWrites, 0);
      expect(service.bonusCalls, 0);
      expect(auth.currentUser, isNull);
      expect(auth.lastBonusPoints, 0);
    },
  );
  test('allergen choices are a snapshot of the submitted form', () async {
    final choices = ['laktoza'];
    final operation = save(auth, choices);
    choices
      ..clear()
      ..add('orzechy');
    expect(await operation, isTrue);
    expect(service.savedAllergens, ['laktoza']);
  });
  test(
    'an optional bonus failure does not block an otherwise saved onboarding',
    () async {
      service.failBonus = true;
      expect(await save(auth), isTrue);
      expect(auth.currentUser?.preferredStoreId, 'store-1');
      expect(auth.lastBonusPoints, 0);
      expect(auth.isLoading, isFalse);
    },
  );
}
