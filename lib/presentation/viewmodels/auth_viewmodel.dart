import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import '../../domain/entities/app_user.dart';

class AuthState {
  final bool isLoading;
  final String? errorMessage;
  final String? successMessage;
  final AppUser? user;

  const AuthState({
    this.isLoading = false,
    this.errorMessage,
    this.successMessage,
    this.user,
  });

  AuthState copyWith({
    bool? isLoading,
    String? errorMessage,
    String? successMessage,
    AppUser? user,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage:
          clearSuccess ? null : (successMessage ?? this.successMessage),
      user: user ?? this.user,
    );
  }
}

class AuthViewModel extends StateNotifier<AuthState> {
  AuthViewModel(this._ref) : super(const AuthState()) {
    _authSub =
        _ref.read(authRepositoryProvider).currentUserStream().listen((user) {
      state = state.copyWith(user: user);
    });
  }

  final Ref _ref;
  StreamSubscription<AppUser?>? _authSub;

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    final emailError = _validateEmail(email);
    final passError = _validatePassword(password);

    if (emailError != null) {
      state = state.copyWith(errorMessage: emailError, clearSuccess: true);
      return;
    }
    if (passError != null) {
      state = state.copyWith(errorMessage: passError, clearSuccess: true);
      return;
    }

    state =
        state.copyWith(isLoading: true, clearError: true, clearSuccess: true);

    try {
      final user = await _ref
          .read(authRepositoryProvider)
          .signIn(email: email.trim(), password: password.trim());

      state = state.copyWith(
        isLoading: false,
        user: user,
        successMessage: 'Inicio de sesión exitoso.',
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _prettyError(e),
        clearSuccess: true,
      );
    }
  }

  Future<void> signInWithGoogle() async {
    state =
        state.copyWith(isLoading: true, clearError: true, clearSuccess: true);

    try {
      final user = await _ref.read(authRepositoryProvider).signInWithGoogle();

      state = state.copyWith(
        isLoading: false,
        user: user,
        successMessage: 'Inicio de sesión con Google exitoso.',
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _prettyError(e),
        clearSuccess: true,
      );
    }
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final nameError = _validateName(name);
    final emailError = _validateEmail(email);
    final passError = _validatePassword(password);

    if (nameError != null) {
      state = state.copyWith(errorMessage: nameError, clearSuccess: true);
      return;
    }
    if (emailError != null) {
      state = state.copyWith(errorMessage: emailError, clearSuccess: true);
      return;
    }
    if (passError != null) {
      state = state.copyWith(errorMessage: passError, clearSuccess: true);
      return;
    }

    state =
        state.copyWith(isLoading: true, clearError: true, clearSuccess: true);

    try {
      final user = await _ref.read(authRepositoryProvider).register(
            name: name.trim(),
            email: email.trim(),
            password: password.trim(),
          );

      state = state.copyWith(
        isLoading: false,
        user: user,
        successMessage: 'Cuenta creada correctamente.',
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _prettyError(e),
        clearSuccess: true,
      );
    }
  }

  Future<void> resetPassword({required String email}) async {
    final emailError = _validateEmail(email);
    if (emailError != null) {
      state = state.copyWith(errorMessage: emailError, clearSuccess: true);
      return;
    }

    state =
        state.copyWith(isLoading: true, clearError: true, clearSuccess: true);

    try {
      await _ref
          .read(authRepositoryProvider)
          .resetPassword(email: email.trim());
      state = state.copyWith(
        isLoading: false,
        successMessage: 'Te enviamos un enlace para restablecer tu contraseña.',
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _prettyError(e),
        clearSuccess: true,
      );
    }
  }

  Future<void> updateProfile({
    required String name,
    required String email,
    required String photoUrl,
  }) async {
    final current = state.user;
    if (current == null) {
      state = state.copyWith(errorMessage: 'Usuario no autenticado.');
      return;
    }

    final nameError = _validateName(name);
    final emailError = _validateEmail(email);

    if (nameError != null) {
      state = state.copyWith(errorMessage: nameError, clearSuccess: true);
      return;
    }
    if (emailError != null) {
      state = state.copyWith(errorMessage: emailError, clearSuccess: true);
      return;
    }

    state =
        state.copyWith(isLoading: true, clearError: true, clearSuccess: true);

    try {
      final updated = await _ref.read(authRepositoryProvider).updateProfile(
            user: current,
            name: name.trim(),
            email: email.trim(),
            photoUrl: photoUrl.trim(),
          );

      state = state.copyWith(
        isLoading: false,
        user: updated,
        successMessage: 'Perfil actualizado.',
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _prettyError(e),
        clearSuccess: true,
      );
    }
  }

  Future<String?> uploadProfilePhoto({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final current = state.user;
    if (current == null) {
      state = state.copyWith(errorMessage: 'Usuario no autenticado.');
      return null;
    }

    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearSuccess: true,
    );
    try {
      final updated =
          await _ref.read(authRepositoryProvider).uploadProfilePhoto(
                user: current,
                bytes: bytes,
                fileName: fileName,
              );
      state = state.copyWith(
        isLoading: false,
        user: updated,
        successMessage: 'Foto de perfil actualizada.',
        clearError: true,
      );
      return updated.photoUrl;
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _prettyError(error),
        clearSuccess: true,
      );
      return null;
    }
  }

  Future<void> signOut() async {
    state =
        state.copyWith(isLoading: true, clearError: true, clearSuccess: true);
    try {
      await _ref.read(authRepositoryProvider).signOut();
      state = state.copyWith(
        isLoading: false,
        user: null,
        successMessage: 'Sesión cerrada.',
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        user: null,
        errorMessage: _prettyError(e),
        clearSuccess: true,
      );
    }
  }

  void clearMessages() {
    state = state.copyWith(clearError: true, clearSuccess: true);
  }

  String? _validateName(String value) {
    if (value.trim().isEmpty) {
      return 'El nombre es obligatorio.';
    }
    if (value.trim().length < 2) {
      return 'El nombre debe tener al menos 2 caracteres.';
    }
    return null;
  }

  String? _validateEmail(String value) {
    final email = value.trim();
    if (email.isEmpty) return 'El correo es obligatorio.';
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    if (!emailRegex.hasMatch(email)) return 'Ingresa un correo válido.';
    return null;
  }

  String? _validatePassword(String value) {
    if (value.trim().isEmpty) {
      return 'La contraseña es obligatoria.';
    }
    if (value.trim().length < 6) {
      return 'La contraseña debe tener al menos 6 caracteres.';
    }
    return null;
  }

  String _prettyError(Object e) {
    final raw = e.toString();
    if (raw.startsWith('Exception: ')) {
      return raw.replaceFirst('Exception: ', '');
    }
    return raw;
  }
}

final authViewModelProvider =
    StateNotifierProvider<AuthViewModel, AuthState>((ref) {
  return AuthViewModel(ref);
});
