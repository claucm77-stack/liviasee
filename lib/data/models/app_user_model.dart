import '../../domain/entities/app_user.dart';
import '../../core/constants/app_roles.dart';

class AppUserModel extends AppUser {
  const AppUserModel({
    required super.uid,
    required super.name,
    required super.email,
    required super.role,
    super.photoUrl,
    super.createdAt,
    super.isActive,
    super.hasMicrobusiness,
  });

  factory AppUserModel.fromFirebase({
    required String uid,
    required String? email,
  }) {
    return AppUserModel(
      uid: uid,
      name: '',
      email: email ?? '',
      role: AppRoles.microempresario,
      photoUrl: '',
      createdAt: null,
      isActive: true,
      hasMicrobusiness: false,
    );
  }

  factory AppUserModel.fromMap(Map<String, dynamic> map) {
    return AppUserModel(
      uid: (map['uid'] ?? '') as String,
      name: (map['nombre'] ?? map['name'] ?? '') as String,
      email: (map['email'] ?? '') as String,
      role: AppRoles.normalize(
        (map['rol'] ?? map['role'] ?? AppRoles.microempresario).toString(),
      ),
      photoUrl: (map['photoUrl'] ?? map['foto'] ?? '') as String,
      createdAt: _parseDate(map['createdAt']),
      isActive: (map['isActive'] ?? map['is_active'] ?? true) == true,
      hasMicrobusiness:
          (map['hasMicrobusiness'] ?? map['has_microbusiness'] ?? false) ==
              true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'nombre': name,
      'email': email,
      'rol': AppRoles.normalize(role),
      'role': AppRoles.normalize(role),
      'photoUrl': photoUrl,
      'createdAt': createdAt?.toIso8601String(),
      'isActive': isActive,
      'hasMicrobusiness': hasMicrobusiness,
    };
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
