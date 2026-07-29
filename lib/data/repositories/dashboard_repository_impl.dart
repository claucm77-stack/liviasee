import 'dart:async';

import '../../data/models/app_user_model.dart';
import '../../data/models/dashboard_metrics_model.dart';
import '../../data/models/content_model.dart';
import '../../data/models/microbusiness_model.dart';
import '../../domain/entities/content.dart';
import '../../domain/entities/microbusiness.dart';
import '../../domain/repositories/dashboard_repository.dart';
import '../../services/laravel_api_service.dart';

class DashboardRepositoryImpl implements DashboardRepository {
  DashboardRepositoryImpl({required LaravelApiService laravelApiService})
      : _laravelApiService = laravelApiService;

  final LaravelApiService _laravelApiService;

  @override
  Stream<DashboardMetricsModel> watchMetrics() {
    return Stream.multi((controller) {
      Timer? timer;
      Future<void> load() async {
        if (controller.isClosed) return;
        if (!_laravelApiService.isAuthenticated) {
          controller.add(const DashboardMetricsModel.empty());
          return;
        }
        try {
          final results = await Future.wait([
            _laravelApiService.fetchMobileData('users'),
            _laravelApiService.fetchMobileData('contents'),
            _laravelApiService.fetchMobileData('microbusinesses'),
          ]);
          final contents = results[1];
          final businesses = results[2];
          if (!controller.isClosed) {
            controller.add(DashboardMetricsModel(
              totalUsers: results[0].length,
              totalContents: contents.length,
              totalMicrobusinesses: businesses.length,
              activeContents:
                  contents.where((row) => row['estado'] == 'activo').length,
              inactiveContents:
                  contents.where((row) => row['estado'] != 'activo').length,
              activeMicrobusinesses:
                  businesses.where((row) => row['estado'] == 'activo').length,
              inactiveMicrobusinesses:
                  businesses.where((row) => row['estado'] != 'activo').length,
            ));
          }
        } catch (error, stackTrace) {
          if (!controller.isClosed) controller.addError(error, stackTrace);
        }
      }

      load();
      timer = Timer.periodic(const Duration(seconds: 5), (_) => load());
      controller.onCancel = () => timer?.cancel();
    });
  }

  @override
  Stream<List<AppUserModel>> watchUsers({
    String? role,
    bool? isActive,
  }) {
    return Stream.multi((controller) {
      Timer? timer;
      Future<void> load() async {
        if (controller.isClosed) return;
        if (!_laravelApiService.isAuthenticated) {
          controller.add(<AppUserModel>[]);
          return;
        }
        try {
          final rows = await _laravelApiService.fetchMobileData('users');
          final users = rows.map(AppUserModel.fromMap).where((user) {
            final matchesRole =
                role == null || role.isEmpty || user.role == role;
            final matchesActive = isActive == null || user.isActive == isActive;
            return matchesRole && matchesActive;
          }).toList();
          if (!controller.isClosed) controller.add(users);
        } catch (error, stackTrace) {
          if (!controller.isClosed) controller.addError(error, stackTrace);
        }
      }

      load();
      timer = Timer.periodic(const Duration(seconds: 5), (_) => load());
      controller.onCancel = () => timer?.cancel();
    });
  }

  @override
  Stream<List<Content>> watchContents({String? categoria}) {
    return Stream.multi((controller) {
      Timer? timer;
      Future<void> load() async {
        if (controller.isClosed) return;
        if (!_laravelApiService.isAuthenticated) {
          controller.add(<Content>[]);
          return;
        }
        try {
          final rows = await _laravelApiService.fetchMobileData('contents');
          final contents = rows
              .map((row) => ContentModel.fromMap(
                    (row['id'] ?? '').toString(),
                    row,
                  ))
              .where((content) =>
                  categoria == null ||
                  categoria.isEmpty ||
                  content.categoria == categoria)
              .toList();
          if (!controller.isClosed) controller.add(contents);
        } catch (error, stackTrace) {
          if (!controller.isClosed) controller.addError(error, stackTrace);
        }
      }

      load();
      timer = Timer.periodic(const Duration(seconds: 5), (_) => load());
      controller.onCancel = () => timer?.cancel();
    });
  }

  @override
  Stream<List<Microbusiness>> watchMicrobusinesses({String? categoria}) {
    return Stream.multi((controller) {
      Timer? timer;
      Future<void> load() async {
        if (controller.isClosed) return;
        if (!_laravelApiService.isAuthenticated) {
          controller.add(<Microbusiness>[]);
          return;
        }
        try {
          final rows =
              await _laravelApiService.fetchMobileData('microbusinesses');
          final businesses = rows
              .map((row) => MicrobusinessModel.fromMap(
                    (row['id'] ?? '').toString(),
                    row,
                  ))
              .where((business) =>
                  categoria == null ||
                  categoria.isEmpty ||
                  business.categoria == categoria)
              .toList();
          if (!controller.isClosed) controller.add(businesses);
        } catch (error, stackTrace) {
          if (!controller.isClosed) controller.addError(error, stackTrace);
        }
      }

      load();
      timer = Timer.periodic(const Duration(seconds: 5), (_) => load());
      controller.onCancel = () => timer?.cancel();
    });
  }

  @override
  Future<void> updateUser({
    required String uid,
    required String role,
    required bool isActive,
    required String description,
  }) async {
    await _laravelApiService.saveMobileData('users/$uid', {
      'role': role,
      'isActive': isActive,
      'description': description,
    });
  }

  @override
  Future<void> updateContentStatus({
    required String contentId,
    required bool isActive,
  }) async {
    final rows = await _laravelApiService.fetchMobileData('contents');
    final row =
        rows.firstWhere((item) => (item['id'] ?? '').toString() == contentId);
    await _laravelApiService.saveMobileData(
        'contents', {...row, 'estado': isActive ? 'activo' : 'inactivo'});
  }

  @override
  Future<void> deleteContent(String contentId) async {
    await _laravelApiService.deleteMobileData('contents', contentId);
  }

  @override
  Future<void> updateMicrobusinessStatus({
    required String businessId,
    required bool isActive,
  }) async {
    final rows = await _laravelApiService.fetchMobileData('microbusinesses');
    final row =
        rows.firstWhere((item) => (item['id'] ?? '').toString() == businessId);
    await _laravelApiService.saveMobileData('microbusinesses',
        {...row, 'estado': isActive ? 'activo' : 'inactivo'});
  }

  @override
  Future<void> deleteMicrobusiness(String businessId) async {
    await _laravelApiService.deleteMobileData('microbusinesses', businessId);
  }
}
