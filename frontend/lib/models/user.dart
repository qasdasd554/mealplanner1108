class User {
  final String id;
  final String email;
  final String? displayName;
  final String? preferredStoreId;
  final Map<String, dynamic>? dietaryPreferences;
  final int householdSize;
  final double? weightKg;
  final double? heightCm;
  final int? age;
  final String? gender;
  final String? activityLevel;
  final int? dailyKcalGoal;
  final bool isEmailVerified;
  final String role;
  final bool isPremium;
  final DateTime? premiumExpiresAt;
  final String? premiumProductId;
  final DateTime createdAt;

  User({
    required this.id,
    required this.email,
    this.displayName,
    this.preferredStoreId,
    this.dietaryPreferences,
    required this.householdSize,
    this.weightKg,
    this.heightCm,
    this.age,
    this.gender,
    this.activityLevel,
    this.dailyKcalGoal,
    this.isEmailVerified = false,
    this.role = 'user',
    this.isPremium = false,
    this.premiumExpiresAt,
    this.premiumProductId,
    required this.createdAt,
  });

  /// Czy to konto ma uprawnienia administratora (np. usuwanie cudzych
  /// komentarzy) — czyta się wygodniej niż porównywanie stringów wprost
  /// w miejscach użycia.
  bool get isAdmin => role == 'admin';

  /// Czy konto ma dostęp do funkcji premium — admini mają go zawsze
  /// (zgodnie z zasadą "admin ma pełne uprawnienia do wszystkiego"),
  /// niezależnie od flagi isPremium. Używaj TEGO gettera przy sprawdzaniu
  /// dostępu do funkcji premium w UI, nie samego isPremium.
  bool get hasPremiumAccess => isPremium || isAdmin;

  /// Liczba dni pozostałych do wygaśnięcia subskrypcji Premium — null,
  /// jeśli konto nie ma ustawionej daty wygaśnięcia (np. konto
  /// administratora, które ma dostęp premium bez subskrypcji).
  int? get premiumDaysRemaining {
    if (premiumExpiresAt == null) return null;
    final diffHours = premiumExpiresAt!.difference(DateTime.now()).inHours;
    if (diffHours <= 0) return 0;
    return (diffHours / 24).ceil();
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      email: json['email'] as String,
      displayName: json['display_name'] as String?,
      preferredStoreId: json['preferred_store_id'] as String?,
      dietaryPreferences: json['dietary_preferences'] as Map<String, dynamic>?,
      householdSize: json['household_size'] as int? ?? 1,
      weightKg: (json['weight_kg'] as num?)?.toDouble(),
      heightCm: (json['height_cm'] as num?)?.toDouble(),
      age: json['age'] as int?,
      gender: json['gender'] as String?,
      activityLevel: json['activity_level'] as String?,
      dailyKcalGoal: json['daily_kcal_goal'] as int?,
      isEmailVerified: json['is_email_verified'] as bool? ?? false,
      role: json['role'] as String? ?? 'user',
      isPremium: json['is_premium'] as bool? ?? false,
      premiumExpiresAt: json['premium_expires_at'] != null
          ? DateTime.tryParse(json['premium_expires_at'] as String)
          : null,
      premiumProductId: json['premium_product_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  User copyWith({
    String? id,
    String? email,
    String? displayName,
    String? preferredStoreId,
    Map<String, dynamic>? dietaryPreferences,
    int? householdSize,
    double? weightKg,
    double? heightCm,
    int? age,
    String? gender,
    String? activityLevel,
    int? dailyKcalGoal,
    String? role,
    bool? isPremium,
    DateTime? premiumExpiresAt,
    String? premiumProductId,
    DateTime? createdAt,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      preferredStoreId: preferredStoreId ?? this.preferredStoreId,
      dietaryPreferences: dietaryPreferences ?? this.dietaryPreferences,
      householdSize: householdSize ?? this.householdSize,
      weightKg: weightKg ?? this.weightKg,
      heightCm: heightCm ?? this.heightCm,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      activityLevel: activityLevel ?? this.activityLevel,
      dailyKcalGoal: dailyKcalGoal ?? this.dailyKcalGoal,
      role: role ?? this.role,
      isPremium: isPremium ?? this.isPremium,
      premiumExpiresAt: premiumExpiresAt ?? this.premiumExpiresAt,
      premiumProductId: premiumProductId ?? this.premiumProductId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class AuthToken {
  final String accessToken;
  final String tokenType;

  AuthToken({
    required this.accessToken,
    required this.tokenType,
  });

  factory AuthToken.fromJson(Map<String, dynamic> json) {
    final token = json['access_token'] as String?;
    if (token == null) {
      throw const FormatException('Odpowiedź serwera nie zawiera access_token');
    }
    return AuthToken(
      accessToken: token,
      tokenType: json['token_type'] as String? ?? 'bearer',
    );
  }
}
