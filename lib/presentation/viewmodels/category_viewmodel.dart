import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import '../../domain/entities/app_category.dart';

const defaultContentCategories = [
  AppCategory(
    id: 'content_publicidad_mercadeo',
    nombre: 'Publicidad y Mercadeo',
    scope: AppCategoryScope.contenidos,
    descripcion:
        'Actualízate en estrategias para promocionar y visibilizar tu negocio.',
    imageUrl:
        'https://images.unsplash.com/photo-1534536281715-e28d76689b4d?auto=format&fit=crop&w=900&q=80',
    orden: 1,
  ),
  AppCategory(
    id: 'content_derecho',
    nombre: 'Derecho',
    scope: AppCategoryScope.contenidos,
    descripcion: 'Conoce lo necesario para proteger tu marca y tu negocio.',
    imageUrl:
        'https://images.unsplash.com/photo-1521587760476-6c12a4b040da?auto=format&fit=crop&w=900&q=80',
    orden: 2,
  ),
  AppCategory(
    id: 'content_contabilidad',
    nombre: 'Contabilidad',
    scope: AppCategoryScope.contenidos,
    descripcion: 'Aprende a gestionar los asuntos tributarios de tu negocio.',
    imageUrl:
        'https://images.unsplash.com/photo-1554224155-6726b3ff858f?auto=format&fit=crop&w=900&q=80',
    orden: 3,
  ),
];

const defaultMicrobusinessCategories = [
  AppCategory(
    id: 'micro_alimentos',
    nombre: 'Alimentos',
    scope: AppCategoryScope.micronegocios,
    orden: 1,
  ),
  AppCategory(
    id: 'micro_artesanias',
    nombre: 'Artesanías',
    scope: AppCategoryScope.micronegocios,
    orden: 2,
  ),
  AppCategory(
    id: 'micro_tecnologia',
    nombre: 'Tecnología',
    scope: AppCategoryScope.micronegocios,
    orden: 3,
  ),
  AppCategory(
    id: 'micro_moda',
    nombre: 'Moda',
    scope: AppCategoryScope.micronegocios,
    orden: 4,
  ),
  AppCategory(
    id: 'micro_servicios',
    nombre: 'Servicios',
    scope: AppCategoryScope.micronegocios,
    orden: 5,
  ),
  AppCategory(
    id: 'micro_hogar',
    nombre: 'Hogar',
    scope: AppCategoryScope.micronegocios,
    orden: 6,
  ),
];

class CategoryAdminState {
  const CategoryAdminState({
    this.isSubmitting = false,
    this.error,
    this.successMessage,
  });

  final bool isSubmitting;
  final String? error;
  final String? successMessage;

  CategoryAdminState copyWith({
    bool? isSubmitting,
    String? error,
    String? successMessage,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return CategoryAdminState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: clearError ? null : (error ?? this.error),
      successMessage:
          clearSuccess ? null : (successMessage ?? this.successMessage),
    );
  }
}

class CategoryAdminViewModel extends StateNotifier<CategoryAdminState> {
  CategoryAdminViewModel(this._ref) : super(const CategoryAdminState());

  final Ref _ref;

  Future<void> saveCategory(AppCategory category) async {
    state = state.copyWith(
      isSubmitting: true,
      clearError: true,
      clearSuccess: true,
    );

    try {
      await _ref.read(categoryRepositoryProvider).saveCategory(category);
      _refreshCategoryLists();
      state = state.copyWith(
        isSubmitting: false,
        successMessage: 'Categoría guardada.',
      );
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        error: e.toString(),
      );
    }
  }

  Future<void> deleteCategory(String categoryId) async {
    state = state.copyWith(
      isSubmitting: true,
      clearError: true,
      clearSuccess: true,
    );

    try {
      await _ref.read(categoryRepositoryProvider).deleteCategory(categoryId);
      _refreshCategoryLists();
      state = state.copyWith(
        isSubmitting: false,
        successMessage: 'Categoría eliminada.',
      );
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        error: e.toString(),
      );
    }
  }

  Future<void> seedDefaults(String scope) async {
    final defaults = scope == AppCategoryScope.micronegocios
        ? defaultMicrobusinessCategories
        : defaultContentCategories;
    for (final category in defaults) {
      await saveCategory(category);
    }
  }

  void clearMessages() {
    state = state.copyWith(clearError: true, clearSuccess: true);
  }

  void _refreshCategoryLists() {
    _ref.invalidate(contentCategoriesProvider);
    _ref.invalidate(activeContentCategoriesProvider);
    _ref.invalidate(microbusinessCategoriesProvider);
    _ref.invalidate(activeMicrobusinessCategoriesProvider);
  }
}

final categoryAdminViewModelProvider =
    StateNotifierProvider<CategoryAdminViewModel, CategoryAdminState>((ref) {
  return CategoryAdminViewModel(ref);
});

final contentCategoriesProvider = StreamProvider<List<AppCategory>>((ref) {
  return ref
      .watch(categoryRepositoryProvider)
      .watchCategories(scope: AppCategoryScope.contenidos);
});

final activeContentCategoriesProvider =
    StreamProvider<List<AppCategory>>((ref) {
  return ref.watch(categoryRepositoryProvider).watchCategories(
        scope: AppCategoryScope.contenidos,
        onlyActive: true,
      );
});

final microbusinessCategoriesProvider =
    StreamProvider<List<AppCategory>>((ref) {
  return ref
      .watch(categoryRepositoryProvider)
      .watchCategories(scope: AppCategoryScope.micronegocios);
});

final activeMicrobusinessCategoriesProvider =
    StreamProvider<List<AppCategory>>((ref) {
  return ref.watch(categoryRepositoryProvider).watchCategories(
        scope: AppCategoryScope.micronegocios,
        onlyActive: true,
      );
});
