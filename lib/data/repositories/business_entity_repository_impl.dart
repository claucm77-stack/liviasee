import 'dart:async';

import '../../domain/entities/business_entity.dart';
import '../../domain/repositories/business_entity_repository.dart';
import '../../services/firestore_service.dart';
import '../../services/laravel_api_service.dart';
import '../models/business_entity_model.dart';

class BusinessEntityRepositoryImpl implements BusinessEntityRepository {
  BusinessEntityRepositoryImpl(
    this._firestoreService, {
    required LaravelApiService laravelApiService,
  }) : _laravelApiService = laravelApiService;

  final FirestoreService _firestoreService;
  final LaravelApiService _laravelApiService;

  @override
  Stream<List<BusinessEntity>> watchEntities() {
    return Stream.multi((controller) {
      Timer? apiTimer;
      Future<void> loadLaravel() async {
        if (!_laravelApiService.isAuthenticated || controller.isClosed) return;
        try {
          final rows = await _laravelApiService.fetchMobileData('entities');
          if (!controller.isClosed) {
            controller.add(rows
                .map((row) => BusinessEntityModel.fromMap(
                    (row['id'] ?? '').toString(), row))
                .toList());
          }
        } catch (_) {}
      }

      loadLaravel();
      apiTimer =
          Timer.periodic(const Duration(seconds: 5), (_) => loadLaravel());
      final sub = _firestoreService.watchBusinessEntities().listen(
            (docs) => controller.add(docs
                .map((doc) => BusinessEntityModel.fromMap(doc.id, doc.data()))
                .toList()),
            onError: controller.addError,
          );
      controller.onCancel = () async {
        apiTimer?.cancel();
        await sub.cancel();
      };
    });
  }

  @override
  Future<void> saveEntity(BusinessEntity entity) async {
    final model = BusinessEntityModel.fromEntity(entity);
    if (!_laravelApiService.isAuthenticated) {
      throw StateError('La sesión con Laravel no está disponible.');
    }
    final saved = await _laravelApiService.saveMobileData('entities', {
      'id': model.id,
      ...model.toMap(),
    });
    final id = (saved['id'] ?? model.id).toString();
    await _firestoreService.setBusinessEntity(
      id: id,
      data: BusinessEntityModel.fromMap(id, saved).toMap(),
    );
  }

  @override
  Future<void> deleteEntity(String entityId) async {
    await _laravelApiService.deleteMobileData('entities', entityId);
    await _firestoreService.deleteBusinessEntity(entityId);
  }
}
