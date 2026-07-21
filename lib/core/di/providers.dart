import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/content_repository.dart';
import '../../domain/repositories/business_entity_repository.dart';
import '../../domain/repositories/category_repository.dart';
import '../../domain/repositories/microbusiness_repository.dart';
import '../../services/firebase_auth_service.dart';
import '../../services/firestore_service.dart';
import '../../data/repositories/content_repository_impl.dart';
import '../../data/repositories/business_entity_repository_impl.dart';
import '../../data/repositories/category_repository_impl.dart';
import '../../data/repositories/dashboard_repository_impl.dart';
import '../../data/repositories/log_repository_impl.dart';
import '../../data/repositories/microbusiness_repository_impl.dart';
import '../../domain/repositories/dashboard_repository.dart';
import '../../domain/repositories/log_repository.dart';
import '../../services/laravel_api_service.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

final firebaseFirestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final firebaseAuthServiceProvider = Provider<FirebaseAuthService>((ref) {
  return FirebaseAuthService(ref.watch(firebaseAuthProvider));
});

final firestoreServiceProvider = Provider<FirestoreService>((ref) {
  return FirestoreService(ref.watch(firebaseFirestoreProvider));
});

final laravelApiServiceProvider = Provider<LaravelApiService>((ref) {
  final service = LaravelApiService();
  ref.onDispose(service.dispose);
  return service;
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    ref.watch(firebaseAuthServiceProvider),
    ref.watch(firestoreServiceProvider),
    ref.watch(laravelApiServiceProvider),
  );
});

final authStateStreamProvider = StreamProvider<AppUser?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges();
});

final contentRepositoryProvider = Provider<ContentRepository>((ref) {
  return ContentRepositoryImpl(
    ref.watch(firestoreServiceProvider),
    laravelApiService: ref.watch(laravelApiServiceProvider),
  );
});

final businessEntityRepositoryProvider =
    Provider<BusinessEntityRepository>((ref) {
  return BusinessEntityRepositoryImpl(
    ref.watch(firestoreServiceProvider),
    laravelApiService: ref.watch(laravelApiServiceProvider),
  );
});

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return CategoryRepositoryImpl(ref.watch(laravelApiServiceProvider));
});

final microbusinessRepositoryProvider =
    Provider<MicrobusinessRepository>((ref) {
  return MicrobusinessRepositoryImpl(
    ref.watch(firestoreServiceProvider),
    laravelApiService: ref.watch(laravelApiServiceProvider),
  );
});

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepositoryImpl(
    laravelApiService: ref.watch(laravelApiServiceProvider),
  );
});

final logRepositoryProvider = Provider<LogRepository>((ref) {
  return LogRepositoryImpl(ref.watch(laravelApiServiceProvider));
});

final microbusinessFieldDefinitionsProvider =
    FutureProvider<List<MicrobusinessFieldDefinition>>((ref) {
  return ref.watch(laravelApiServiceProvider).fetchMicrobusinessFields();
});
