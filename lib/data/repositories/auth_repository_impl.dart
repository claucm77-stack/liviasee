import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../core/constants/app_roles.dart';
import '../../services/firebase_auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/laravel_api_service.dart' hide User;
import '../models/app_user_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  final FirebaseAuthService _authService;
  final FirestoreService _firestoreService;
  final LaravelApiService _laravelApiService;

  AuthRepositoryImpl(
    this._authService,
    this._firestoreService,
    this._laravelApiService,
  );

  Future<AuthResponse> _syncLaravelSession() async {
    final token = await _authService.getIdToken();
    if (token == null || token.isEmpty) {
      throw StateError('Firebase no entregó un token de sesión válido.');
    }
    return _laravelApiService.exchangeFirebaseToken(token);
  }

  Future<AppUserModel> _authoritativeUser(User firebaseUser) async {
    final session = await _syncLaravelSession();
    AppUser? cachedProfile;
    try {
      cachedProfile = await getUserProfile(firebaseUser.uid);
    } on FirebaseException {
      // Laravel remains authoritative when the Firestore cache is unavailable.
    }

    return AppUserModel(
      uid: firebaseUser.uid,
      name: session.user.name.isNotEmpty
          ? session.user.name
          : cachedProfile?.name ?? firebaseUser.displayName ?? '',
      email: session.user.email.isNotEmpty
          ? session.user.email
          : firebaseUser.email ?? '',
      role: session.user.role,
      photoUrl: session.user.photoUrl.isNotEmpty
          ? session.user.photoUrl
          : (cachedProfile?.photoUrl.isNotEmpty ?? false)
              ? cachedProfile!.photoUrl
              : firebaseUser.photoURL ?? '',
      createdAt: session.user.createdAt ?? cachedProfile?.createdAt,
      isActive: session.user.isActive,
      hasMicrobusiness: session.user.hasMicrobusiness,
      description: session.user.description,
    );
  }

  @override
  Stream<AppUser?> authStateChanges() {
    return _authService.authStateChanges().asyncMap((firebaseUser) async {
      if (firebaseUser == null) return null;
      return _authoritativeUser(firebaseUser);
    });
  }

  @override
  Stream<AppUser?> currentUserStream() {
    return _authService.authStateChanges().asyncMap((firebaseUser) async {
      if (firebaseUser == null) return null;
      return _authoritativeUser(firebaseUser);
    });
  }

  @override
  Future<AppUser?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final credential =
          await _authService.signIn(email: email, password: password);
      final user = credential.user;
      if (user == null) return null;

      return _authoritativeUser(user);
    } on FirebaseAuthException catch (e) {
      throw Exception(_mapFirebaseAuthError(e));
    }
  }

  @override
  Future<AppUser?> signInWithGoogle() async {
    try {
      final credential = await _authService.signInWithGoogle();
      final user = credential.user;
      if (user == null) return null;

      try {
        final profile = await getUserProfile(user.uid);
        if (profile != null) return _authoritativeUser(user);
      } on FirebaseException {
        // Continue and create the basic profile from the Google account.
      }

      final newUser = AppUserModel(
        uid: user.uid,
        name: user.displayName ?? '',
        email: user.email ?? '',
        role: AppRoles.microempresario,
        photoUrl: user.photoURL ?? '',
        createdAt: DateTime.now(),
        isActive: true,
        hasMicrobusiness: false,
        description: '',
      );

      await _firestoreService.setUserProfile(
        uid: user.uid,
        data: newUser.toMap(),
      );

      return _authoritativeUser(user);
    } on FirebaseAuthException catch (e) {
      throw Exception(_mapFirebaseAuthError(e));
    }
  }

  @override
  Future<AppUser?> register({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final credential =
          await _authService.register(email: email, password: password);
      final user = credential.user;
      if (user == null) return null;

      final newUser = AppUserModel(
        uid: user.uid,
        name: name,
        email: email,
        role: AppRoles.microempresario,
        createdAt: DateTime.now(),
      );

      await _firestoreService.setUserProfile(
        uid: user.uid,
        data: newUser.toMap(),
      );

      return _authoritativeUser(user);
    } on FirebaseAuthException catch (e) {
      throw Exception(_mapFirebaseAuthError(e));
    }
  }

  @override
  Future<void> resetPassword({required String email}) async {
    try {
      await _authService.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw Exception(_mapFirebaseAuthError(e));
    }
  }

  @override
  Future<AppUser?> getUserProfile(String uid) async {
    final data = await _firestoreService.getUserProfile(uid);
    if (data == null) return null;
    return AppUserModel.fromMap(data);
  }

  @override
  Future<AppUser> updateProfile({
    required AppUser user,
    required String name,
    required String email,
    required String photoUrl,
    required String description,
  }) async {
    final saved = await _laravelApiService.saveMobileData('profile', {
      'name': name,
      'photoUrl': photoUrl,
      'description': description,
    });
    final updated = AppUserModel(
      uid: user.uid,
      name: (saved['name'] ?? name).toString(),
      email: user.email,
      role: user.role,
      photoUrl: (saved['photoUrl'] ?? photoUrl).toString(),
      createdAt: user.createdAt,
      hasMicrobusiness: user.hasMicrobusiness,
      description: (saved['description'] ?? description).toString(),
    );

    try {
      await _firestoreService.setUserProfile(
        uid: user.uid,
        data: updated.toMap(),
      );
    } on FirebaseException {
      // Laravel already persisted the profile; Firestore is only a cache.
    }

    return updated;
  }

  @override
  Future<AppUser> uploadProfilePhoto({
    required AppUser user,
    required Uint8List bytes,
    required String fileName,
  }) async {
    final saved = await _laravelApiService.uploadProfilePhoto(
      bytes: bytes,
      fileName: fileName,
    );
    final photoUrl = (saved['photoUrl'] ?? '').toString();
    if (photoUrl.isEmpty) {
      throw StateError('Laravel no devolvió la imagen de perfil.');
    }

    return user.copyWith(photoUrl: photoUrl);
  }

  @override
  Future<void> signOut() async {
    if (_laravelApiService.isAuthenticated) {
      await _laravelApiService.logout();
    }
    await _authService.signOut();
  }

  String _mapFirebaseAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No existe una cuenta con ese correo.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Correo o contraseña incorrectos.';
      case 'email-already-in-use':
        return 'Este correo ya está registrado.';
      case 'weak-password':
        return 'La contraseña es demasiado débil.';
      case 'invalid-email':
        return 'El formato del correo no es válido.';
      case 'network-request-failed':
        return 'Sin conexión a internet. Intenta nuevamente.';
      case 'too-many-requests':
        return 'Demasiados intentos. Intenta más tarde.';
      case 'google-sign-in-cancelled':
      case 'popup-closed-by-user':
        return 'Inicio de sesión con Google cancelado.';
      case 'popup-blocked':
        return 'El navegador bloqueó la ventana de Google. Habilita las ventanas emergentes e intenta nuevamente.';
      case 'unauthorized-domain':
        return 'Este dominio no está autorizado para iniciar con Google.';
      case 'operation-not-allowed':
        return 'El acceso con Google no está habilitado en Firebase.';
      default:
        return 'Ocurrió un error de autenticación. Intenta nuevamente.';
    }
  }
}
