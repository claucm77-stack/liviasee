import 'package:equatable/equatable.dart';

import '../../core/constants/app_roles.dart';

class AppUser extends Equatable {
  final String uid;
  final String name;
  final String email;
  final String role;
  final String photoUrl;
  final DateTime? createdAt;
  final bool isActive;
  final bool hasMicrobusiness;

  const AppUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    this.photoUrl = '',
    this.createdAt,
    this.isActive = true,
    this.hasMicrobusiness = false,
  });

  bool get isAdmin => AppRoles.isAdminTi(role);
  bool get isEducator => AppRoles.isDocente(role);
  bool get isUser => AppRoles.isMicroempresario(role);
  bool get isEntrepreneur => AppRoles.isMicroempresario(role);
  bool get isMicroempresario => AppRoles.isMicroempresario(role);
  bool get isDocente => AppRoles.isDocente(role);
  bool get isDocenteAdmin => AppRoles.isDocenteAdmin(role);
  bool get isAdminTi => AppRoles.isAdminTi(role);
  String get normalizedRole => AppRoles.normalize(role);
  String get roleLabel => AppRoles.label(role);

  AppUser copyWith({
    String? uid,
    String? name,
    String? email,
    String? role,
    String? photoUrl,
    DateTime? createdAt,
    bool? isActive,
    bool? hasMicrobusiness,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      photoUrl: photoUrl ?? this.photoUrl,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
      hasMicrobusiness: hasMicrobusiness ?? this.hasMicrobusiness,
    );
  }

  @override
  List<Object?> get props =>
      [uid, name, email, role, photoUrl, createdAt, isActive, hasMicrobusiness];
}
