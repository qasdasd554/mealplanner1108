class User {
  final String id;
  final String email;
  final String? displayName;
  final String? preferredStoreId;
  final Map<String, dynamic>? dietaryPreferences;
  final int householdSize;
  final DateTime createdAt;

  User({
    required this.id,
    required this.email,
    this.displayName,
    this.preferredStoreId,
    this.dietaryPreferences,
    required this.householdSize,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      email: json['email'] as String,
      displayName: json['display_name'] as String?,
      preferredStoreId: json['preferred_store_id'] as String?,
      dietaryPreferences: json['dietary_preferences'] as Map<String, dynamic>?,
      householdSize: json['household_size'] as int? ?? 1,
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
    DateTime? createdAt,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      preferredStoreId: preferredStoreId ?? this.preferredStoreId,
      dietaryPreferences: dietaryPreferences ?? this.dietaryPreferences,
      householdSize: householdSize ?? this.householdSize,
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
