import 'dart:async';

import '../../data/models/log_model.dart';
import '../../domain/repositories/log_repository.dart';
import '../../services/laravel_api_service.dart';

class LogRepositoryImpl implements LogRepository {
  LogRepositoryImpl(this._laravelApiService);

  final LaravelApiService _laravelApiService;

  @override
  Future<void> addLog({
    required String usuarioId,
    required String accion,
    required String modulo,
    String origen = 'mobile',
    String detalle = '',
  }) async {
    await _laravelApiService.saveMobileData('logs', {
      'usuarioId': usuarioId,
      'accion': accion,
      'modulo': modulo,
      'origen': origen,
      'detalle': detalle,
    });
  }

  @override
  Stream<List<LogModel>> watchLogs({
    String? modulo,
    int limit = 100,
  }) {
    return Stream.multi((controller) {
      Timer? timer;
      Future<void> load() async {
        if (controller.isClosed) return;
        if (!_laravelApiService.isAuthenticated) {
          controller.add(<LogModel>[]);
          return;
        }
        try {
          final suffix = modulo == null || modulo.isEmpty
              ? 'logs?limit=$limit'
              : 'logs?limit=$limit&module=${Uri.encodeQueryComponent(modulo)}';
          final rows = await _laravelApiService.fetchMobileData(suffix);
          if (!controller.isClosed) {
            controller.add(rows.map(LogModel.fromMap).toList());
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
}
