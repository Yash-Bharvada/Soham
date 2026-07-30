class Profile {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final String role;
  final String? avatarUrl;
  final String? fcmToken;
  final DateTime createdAt;

  const Profile({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    required this.role,
    this.avatarUrl,
    this.fcmToken,
    required this.createdAt,
  });

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        email: json['email'] as String? ?? '',
        phone: json['phone'] as String?,
        role: json['role'] as String? ?? 'tenant',
        avatarUrl: json['avatar_url'] as String?,
        fcmToken: json['fcm_token'] as String?,
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
            DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'role': role,
        'avatar_url': avatarUrl,
        'fcm_token': fcmToken,
        'created_at': createdAt.toIso8601String(),
      };

  bool get isOwner => role == 'owner';

  /// Returns initials from name (e.g. "Arjun Mehta" → "AM")
  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  Profile copyWith({
    String? name,
    String? phone,
    String? avatarUrl,
    String? fcmToken,
  }) =>
      Profile(
        id: id,
        name: name ?? this.name,
        email: email,
        phone: phone ?? this.phone,
        role: role,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        fcmToken: fcmToken ?? this.fcmToken,
        createdAt: createdAt,
      );
}
