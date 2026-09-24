class FriendEntry {
  final String connectionId;
  final String userId;
  final String displayName;
  final String? avatar;
  final String? avatarPhotoBase64;
  final String status;
  final String? direction;
  final DateTime createdAt;

  const FriendEntry({
    required this.connectionId,
    required this.userId,
    required this.displayName,
    this.avatar,
    this.avatarPhotoBase64,
    required this.status,
    this.direction,
    required this.createdAt,
  });

  factory FriendEntry.fromJson(Map<String, dynamic> json) => FriendEntry(
    connectionId: json['connection_id'] as String,
    userId: json['user_id'] as String,
    displayName: json['display_name'] as String? ?? 'Użytkownik',
    avatar: json['avatar'] as String?,
    avatarPhotoBase64: json['avatar_photo_base64'] as String?,
    status: json['status'] as String? ?? 'pending',
    direction: json['direction'] as String?,
    createdAt: DateTime.parse(json['created_at'] as String),
  );
}
