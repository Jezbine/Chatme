class UserProfile {
  final String id;
  final String phoneNumber;
  final String? email;
  final String? displayName;
  final String? avatarUrl;
  final String? bio;
  final String? fcmToken;
  final bool isOnline;
  final DateTime? lastSeen;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? emailConfirmedAt;

  UserProfile({
    required this.id,
    required this.phoneNumber,
    this.email,
    this.displayName,
    this.avatarUrl,
    this.bio,
    this.fcmToken,
    this.isOnline = false,
    this.lastSeen,
    this.createdAt,
    this.updatedAt,
    this.emailConfirmedAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        id: json['id'] as String,
        phoneNumber: (json['phone_number'] as String?) ?? '',
        email: json['email'] as String?,
        displayName: json['display_name'] as String?,
        avatarUrl: json['avatar_url'] as String?,
        bio: json['bio'] as String?,
        fcmToken: json['fcm_token'] as String?,
        isOnline: (json['is_online'] as bool?) ?? false,
        lastSeen: json['last_seen'] == null
            ? null
            : DateTime.parse(json['last_seen'] as String),
        createdAt: json['created_at'] == null
            ? null
            : DateTime.parse(json['created_at'] as String),
        updatedAt: json['updated_at'] == null
            ? null
            : DateTime.parse(json['updated_at'] as String),
        emailConfirmedAt: json['email_confirmed_at'] == null
            ? null
            : DateTime.parse(json['email_confirmed_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'phone_number': phoneNumber,
        'email': email,
        'display_name': displayName,
        'avatar_url': avatarUrl,
        'bio': bio,
        'fcm_token': fcmToken,
        'is_online': isOnline,
        'last_seen': lastSeen?.toIso8601String(),
      };

  UserProfile copyWith({
    String? id,
    String? phoneNumber,
    String? email,
    String? displayName,
    String? avatarUrl,
    String? bio,
    String? fcmToken,
    bool? isOnline,
    DateTime? lastSeen,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? emailConfirmedAt,
  }) =>
      UserProfile(
        id: id ?? this.id,
        phoneNumber: phoneNumber ?? this.phoneNumber,
        email: email ?? this.email,
        displayName: displayName ?? this.displayName,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        bio: bio ?? this.bio,
        fcmToken: fcmToken ?? this.fcmToken,
        isOnline: isOnline ?? this.isOnline,
        lastSeen: lastSeen ?? this.lastSeen,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        emailConfirmedAt: emailConfirmedAt ?? this.emailConfirmedAt,
      );

  String get initials {
    final name = (displayName != null && displayName!.trim().isNotEmpty)
        ? displayName!.trim()
        : (phoneNumber.isNotEmpty
            ? phoneNumber.replaceAll('+', '').trim()
            : (email?.split('@').first ?? ''));
    final parts = name.split(RegExp(r'\s+'));
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    if (name.isNotEmpty) {
      return name.length >= 2
          ? name.substring(0, 2).toUpperCase()
          : name[0].toUpperCase();
    }
    return '?';
  }

  String get displayNameOrPhone =>
      (displayName != null && displayName!.trim().isNotEmpty)
          ? displayName!
          : (phoneNumber.isNotEmpty ? phoneNumber : (email ?? 'Utilisateur'));
}
