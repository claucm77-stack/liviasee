import 'dart:async';

import '../../domain/entities/app_category.dart';
import '../../domain/repositories/category_repository.dart';
import '../../services/laravel_api_service.dart';
import '../models/app_category_model.dart';

class CategoryRepositoryImpl implements CategoryRepository {
  CategoryRepositoryImpl(this._laravelApiService);

  final LaravelApiService _laravelApiService;

  @override
  Stream<List<AppCategory>> watchCategories({
    required String scope,
    bool onlyActive = false,
  }) {
    return Stream.multi((controller) {
      Timer? apiTimer;

      Future<void> loadLaravelCategories() async {
        if (controller.isClosed) return;
        try {
          final rows = _laravelApiService.isAuthenticated
              ? await _laravelApiService.fetchMobileData('categories')
              : await _laravelApiService.fetchContentCategories();
          if (controller.isClosed) return;
          final scopedRows = rows.where((row) {
            final rowScope =
                (row['scope'] ?? AppCategoryScope.contenidos).toString();
            final active = row['isActive'] != false;
            return rowScope == scope && (!onlyActive || active);
          }).toList();
          controller.add(scopedRows
              .map((row) =>
                  AppCategoryModel.fromMap((row['id'] ?? '').toString(), row))
              .toList());
        } catch (error, stackTrace) {
          if (!controller.isClosed) controller.addError(error, stackTrace);
        }
      }

      loadLaravelCategories();
      apiTimer = Timer.periodic(
        const Duration(seconds: 5),
        (_) => loadLaravelCategories(),
      );
      controller.onCancel = () {
        apiTimer?.cancel();
      };
    });
  }

  @override
  Future<void> saveCategory(AppCategory category) {
    final model = AppCategoryModel.fromEntity(category);
    return _saveCategory(model);
  }

  Future<void> _saveCategory(AppCategoryModel model) async {
    if (!_laravelApiService.isAuthenticated) {
      throw StateError('La sesión con Laravel no está disponible.');
    }
    await _laravelApiService.saveMobileData(
      'categories',
      model.toMap()..['id'] = model.id,
    );
  }

  @override
  Future<void> deleteCategory(String categoryId) {
    return _deleteCategory(categoryId);
  }

  Future<void> _deleteCategory(String categoryId) async {
    if (!_laravelApiService.isAuthenticated) {
      throw StateError('La sesión con Laravel no está disponible.');
    }
    await _laravelApiService.deleteMobileData('categories', categoryId);
  }
}
