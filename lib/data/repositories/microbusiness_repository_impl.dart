import 'dart:async';
import 'dart:math';

import '../../core/constants/app_roles.dart';
import '../../domain/entities/microbusiness.dart';
import '../../domain/repositories/microbusiness_repository.dart';
import '../../services/firestore_service.dart';
import '../../services/laravel_api_service.dart';
import '../models/microbusiness_model.dart';

class MicrobusinessRepositoryImpl implements MicrobusinessRepository {
  MicrobusinessRepositoryImpl(
    this._firestoreService, {
    required LaravelApiService laravelApiService,
  }) : _laravelApiService = laravelApiService;

  final FirestoreService _firestoreService;
  final LaravelApiService _laravelApiService;

  @override
  Future<void> createMicrobusiness({
    required Microbusiness business,
    required String currentUserId,
    required String currentUserRole,
  }) async {
    _validateCreatePermission(
      currentUserId: currentUserId,
      currentUserRole: currentUserRole,
      business: business,
    );

    final model = MicrobusinessModel.fromEntity(business);
    await _saveToLaravelAndCache(model);
  }

  @override
  Future<void> updateMicrobusiness({
    required Microbusiness business,
    required String currentUserId,
    required String currentUserRole,
  }) async {
    final existing = await getMicrobusinessById(business.id);
    if (existing == null) {
      throw Exception('Micronegocio no encontrado.');
    }

    _validateUpdatePermission(
      currentUserId: currentUserId,
      currentUserRole: currentUserRole,
      existingBusiness: existing,
    );

    final model = MicrobusinessModel.fromEntity(business);
    await _saveToLaravelAndCache(model);
  }

  @override
  Future<void> deleteMicrobusiness({
    required String businessId,
    required String currentUserId,
    required String currentUserRole,
  }) async {
    final existing = await getMicrobusinessById(businessId);
    if (existing == null) {
      throw Exception('Micronegocio no encontrado.');
    }

    _validateDeletePermission(
      currentUserId: currentUserId,
      currentUserRole: currentUserRole,
      existingBusiness: existing,
    );

    await _laravelApiService.deleteMobileData('microbusinesses', businessId);
    await _firestoreService.deleteMicrobusiness(businessId);
  }

  @override
  Future<Microbusiness?> getMicrobusinessById(String businessId) async {
    if (_laravelApiService.isAuthenticated) {
      final rows = await _laravelApiService.fetchMobileData('microbusinesses');
      for (final row in rows) {
        if ((row['id'] ?? '').toString() == businessId) {
          return MicrobusinessModel.fromMap(businessId, row);
        }
      }
      return null;
    }

    final map = await _firestoreService.getMicrobusinessById(businessId);
    return map == null ? null : MicrobusinessModel.fromMap(businessId, map);
  }

  @override
  Stream<List<Microbusiness>> watchMicrobusinesses({
    required String currentUserRole,
    String? categoria,
    String? searchText,
  }) {
    return Stream.multi((controller) {
      Timer? apiTimer;
      Future<void> loadLaravel() async {
        if (controller.isClosed) return;
        if (!_laravelApiService.isAuthenticated) {
          controller.add(<Microbusiness>[]);
          return;
        }
        try {
          final rows =
              await _laravelApiService.fetchMobileData('microbusinesses');
          if (controller.isClosed) return;
          controller.add(_applyFilters(
            rows
                .map((row) => MicrobusinessModel.fromMap(
                    (row['id'] ?? '').toString(), row))
                .toList(),
            categoria: categoria,
            searchText: searchText,
          ));
        } catch (_) {}
      }

      loadLaravel();
      apiTimer =
          Timer.periodic(const Duration(seconds: 5), (_) => loadLaravel());
      controller.onCancel = () {
        apiTimer?.cancel();
      };
    });
  }

  Future<void> _saveToLaravelAndCache(MicrobusinessModel model) async {
    if (!_laravelApiService.isAuthenticated) {
      throw StateError('La sesión con Laravel no está disponible.');
    }
    final saved = await _laravelApiService.saveMobileData('microbusinesses', {
      'id': model.id,
      ...model.toMap(),
    });
    final id = (saved['id'] ?? model.id).toString();
    await _firestoreService.setMicrobusiness(
      id: id,
      data: MicrobusinessModel.fromMap(id, saved).toMap(),
    );
  }

  @override
  Future<void> toggleFavorite({
    required String businessId,
    required String userId,
  }) async {
    final business = await getMicrobusinessById(businessId);
    if (business == null) throw Exception('Micronegocio no encontrado.');

    final saved = await _laravelApiService.saveMobileData(
      'microbusinesses/${Uri.encodeComponent(businessId)}/favorite',
      const {},
    );
    await _firestoreService.setMicrobusiness(
      id: businessId,
      data: MicrobusinessModel.fromMap(businessId, saved).toMap(),
    );
  }

  @override
  Future<Microbusiness> rateBusiness({
    required String businessId,
    required double rating,
  }) async {
    if (rating < 1 || rating > 5) {
      throw Exception('La calificación debe estar entre 1 y 5.');
    }

    final business = await getMicrobusinessById(businessId);
    if (business == null) throw Exception('Micronegocio no encontrado.');

    final saved = await _laravelApiService.saveMobileData(
      'microbusinesses/${Uri.encodeComponent(businessId)}/rate',
      {'rating': rating},
    );
    return MicrobusinessModel.fromMap(businessId, saved);
  }

  @override
  Future<List<Microbusiness>> fetchNearby({
    required String currentUserRole,
    required double userLat,
    required double userLng,
    double maxDistanceKm = 10,
    String? categoria,
    String? searchText,
  }) async {
    if (!_laravelApiService.isAuthenticated) return const [];
    final rows = await _laravelApiService.fetchMobileData('microbusinesses');
    final all = rows
        .map((row) => MicrobusinessModel.fromMap(
              (row['id'] ?? '').toString(),
              row,
            ))
        .where((business) =>
            AppRoles.isDocenteAdmin(currentUserRole) ||
            AppRoles.isAdminTi(currentUserRole) ||
            business.isActivo)
        .toList();

    final searched = _applyFilters(
      all,
      categoria: categoria,
      searchText: searchText,
    );

    final nearby = searched.where((business) {
      final d = _distanceKm(
        userLat,
        userLng,
        business.latitud,
        business.longitud,
      );
      return d <= maxDistanceKm;
    }).toList();

    nearby.sort((a, b) {
      final da = _distanceKm(userLat, userLng, a.latitud, a.longitud);
      final db = _distanceKm(userLat, userLng, b.latitud, b.longitud);
      return da.compareTo(db);
    });

    return nearby;
  }

  List<Microbusiness> _applyFilters(
    List<Microbusiness> all, {
    String? categoria,
    String? searchText,
  }) {
    final selectedCategory = (categoria ?? '').trim().toLowerCase();
    final q = (searchText ?? '').trim().toLowerCase();
    return all.where((business) {
      final matchesCategory = selectedCategory.isEmpty ||
          business.categoria.trim().toLowerCase() == selectedCategory;
      final matchesSearch =
          q.isEmpty || business.nombre.toLowerCase().contains(q);
      return matchesCategory && matchesSearch;
    }).toList();
  }

  void _validateCreatePermission({
    required String currentUserId,
    required String currentUserRole,
    required Microbusiness business,
  }) {
    if (AppRoles.isDocenteAdmin(currentUserRole) ||
        AppRoles.isAdminTi(currentUserRole)) {
      return;
    }

    if ((AppRoles.isMicroempresario(currentUserRole) ||
            AppRoles.isDocente(currentUserRole)) &&
        business.propietarioId == currentUserId) {
      return;
    }

    throw Exception('No tienes permisos para crear este micronegocio.');
  }

  void _validateUpdatePermission({
    required String currentUserId,
    required String currentUserRole,
    required Microbusiness existingBusiness,
  }) {
    if (AppRoles.isDocenteAdmin(currentUserRole) ||
        AppRoles.isAdminTi(currentUserRole)) {
      return;
    }

    if ((AppRoles.isMicroempresario(currentUserRole) ||
            AppRoles.isDocente(currentUserRole)) &&
        existingBusiness.propietarioId == currentUserId) {
      return;
    }

    throw Exception('No tienes permisos para editar este micronegocio.');
  }

  void _validateDeletePermission({
    required String currentUserId,
    required String currentUserRole,
    required Microbusiness existingBusiness,
  }) {
    if (AppRoles.isDocenteAdmin(currentUserRole) ||
        AppRoles.isAdminTi(currentUserRole)) {
      return;
    }

    if (AppRoles.isMicroempresario(currentUserRole) &&
        existingBusiness.propietarioId == currentUserId) {
      return;
    }

    throw Exception('No tienes permisos para eliminar este micronegocio.');
  }

  double _distanceKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const r = 6371.0;
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return r * c;
  }

  double _toRadians(double value) => value * pi / 180;
}
