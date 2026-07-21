import 'dart:typed_data';

import '../entities/app_user.dart';

abstract class AuthRepository {
  Stream<AppUser?> authStateChanges();

  Stream<AppUser?> currentUserStream();

  Future<AppUser?> signIn({
    required String email,
    required String password,
  });

  Future<AppUser?> signInWithGoogle();

  Future<AppUser?> register({
    required String name,
    required String email,
    required String password,
  });

  Future<void> resetPassword({required String email});

  Future<AppUser?> getUserProfile(String uid);

  Future<AppUser> updateProfile({
    required AppUser user,
    required String name,
    required String email,
    required String photoUrl,
  });

  Future<AppUser> uploadProfilePhoto({
    required AppUser user,
    required Uint8List bytes,
    required String fileName,
  });

  Future<void> signOut();
}
