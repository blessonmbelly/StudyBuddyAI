class AuthUser {
  final String id;
  final String email;
  final String? fullName;
  final bool isActive;
  final DateTime? createdAt;

  const AuthUser({
    required this.id,
    required this.email,
    this.fullName,
    this.isActive = true,
    this.createdAt,
  });

  String get displayName {
    if (fullName != null && fullName!.trim().isNotEmpty) {
      return fullName!.trim().replaceAll(RegExp(r'\s+'), ' ');
    }
    if (email.contains('@')) {
      final handle = email.split('@').first;
      final parts = handle.split(RegExp(r'[._\-\s]')).where((p) => p.isNotEmpty);
      if (parts.isNotEmpty) {
        return parts.map((p) => p[0].toUpperCase() + p.substring(1)).join(' ');
      }
    }
    return 'Student';
  }

  String get avatarInitial {
    if (fullName != null && fullName!.trim().isNotEmpty) {
      return fullName!.trim()[0].toUpperCase();
    }
    if (email.isNotEmpty) {
      return email[0].toUpperCase();
    }
    return 'S';
  }

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      fullName: json['full_name'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  AuthUser copyWith({
    String? id,
    String? email,
    String? fullName,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return AuthUser(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'is_active': isActive,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}

