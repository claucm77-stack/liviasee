import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import '../../core/constants/app_roles.dart';
import '../../data/models/app_user_model.dart';
import '../../data/models/dashboard_metrics_model.dart';
import '../../data/models/log_model.dart';
import '../../domain/entities/content.dart';
import '../../domain/entities/microbusiness.dart';
import 'auth_viewmodel.dart';

class DashboardState {
  final bool isLoading;
  final bool isAdmin;
  final String? error;
  final DashboardMetricsModel metrics;
  final List<AppUserModel> users;
  final List<Content> contents;
  final List<Microbusiness> businesses;
  final List<LogModel> logs;
  final String? usersRoleFilter;
  final bool? usersActiveFilter;
  final String? contentsCategoryFilter;
  final String? businessesCategoryFilter;
  final String globalSearchQuery;
  final String? logsModuloFilter;

  const DashboardState({
    this.isLoading = true,
    this.isAdmin = false,
    this.error,
    this.metrics = const DashboardMetricsModel.empty(),
    this.users = const [],
    this.contents = const [],
    this.businesses = const [],
    this.logs = const [],
    this.usersRoleFilter,
    this.usersActiveFilter,
    this.contentsCategoryFilter,
    this.businessesCategoryFilter,
    this.globalSearchQuery = '',
    this.logsModuloFilter,
  });

  DashboardState copyWith({
    bool? isLoading,
    bool? isAdmin,
    String? error,
    bool clearError = false,
    DashboardMetricsModel? metrics,
    List<AppUserModel>? users,
    List<Content>? contents,
    List<Microbusiness>? businesses,
    List<LogModel>? logs,
    String? usersRoleFilter,
    bool? usersActiveFilter,
    bool clearUsersActiveFilter = false,
    String? contentsCategoryFilter,
    bool clearContentsCategoryFilter = false,
    String? businessesCategoryFilter,
    bool clearBusinessesCategoryFilter = false,
    String? globalSearchQuery,
    String? logsModuloFilter,
  }) {
    return DashboardState(
      isLoading: isLoading ?? this.isLoading,
      isAdmin: isAdmin ?? this.isAdmin,
      error: clearError ? null : (error ?? this.error),
      metrics: metrics ?? this.metrics,
      users: users ?? this.users,
      contents: contents ?? this.contents,
      businesses: businesses ?? this.businesses,
      logs: logs ?? this.logs,
      usersRoleFilter: usersRoleFilter ?? this.usersRoleFilter,
      usersActiveFilter: clearUsersActiveFilter
          ? null
          : (usersActiveFilter ?? this.usersActiveFilter),
      contentsCategoryFilter: clearContentsCategoryFilter
          ? null
          : (contentsCategoryFilter ?? this.contentsCategoryFilter),
      businessesCategoryFilter: clearBusinessesCategoryFilter
          ? null
          : (businessesCategoryFilter ?? this.businessesCategoryFilter),
      globalSearchQuery: globalSearchQuery ?? this.globalSearchQuery,
      logsModuloFilter: logsModuloFilter ?? this.logsModuloFilter,
    );
  }
}

class DashboardViewModel extends StateNotifier<DashboardState> {
  DashboardViewModel(this._ref) : super(const DashboardState()) {
    _bootstrap();
  }

  final Ref _ref;

  StreamSubscription? _metricsSub;
  StreamSubscription? _usersSub;
  StreamSubscription? _contentsSub;
  StreamSubscription? _businessesSub;
  StreamSubscription? _logsSub;

  Future<void> _bootstrap() async {
    final user = _ref.read(authViewModelProvider).user;
    final isAdmin = AppRoles.canManageAcademic(user?.role);

    if (!isAdmin) {
      state = state.copyWith(
        isLoading: false,
        isAdmin: false,
        error: 'Acceso restringido para coordinadores y administradores.',
      );
      return;
    }

    state = state.copyWith(isAdmin: true, isLoading: true, clearError: true);

    _metricsSub = _ref.read(dashboardRepositoryProvider).watchMetrics().listen(
      (metrics) {
        state = state.copyWith(metrics: metrics, isLoading: false);
      },
      onError: (e) {
        state = state.copyWith(
          isLoading: false,
          error: e.toString(),
        );
      },
    );

    _subscribeUsers();
    _subscribeContents();
    _subscribeBusinesses();
    _subscribeLogs();

    try {
      await addLog(
        accion: 'Ingreso a dashboard de gestión',
        modulo: 'dashboard',
        detalle: 'El administrador abrió el panel de control.',
      );
    } catch (_) {
      // El dashboard no debe fallar si Firestore bloquea escritura de logs.
    }
  }

  void _subscribeContents() {
    _contentsSub?.cancel();
    _contentsSub = _ref
        .read(dashboardRepositoryProvider)
        .watchContents(categoria: state.contentsCategoryFilter)
        .listen(
      (contents) {
        state = state.copyWith(contents: contents);
      },
      onError: (e) {
        state = state.copyWith(error: e.toString());
      },
    );
  }

  void _subscribeBusinesses() {
    _businessesSub?.cancel();
    _businessesSub = _ref
        .read(dashboardRepositoryProvider)
        .watchMicrobusinesses(categoria: state.businessesCategoryFilter)
        .listen(
      (businesses) {
        state = state.copyWith(businesses: businesses);
      },
      onError: (e) {
        state = state.copyWith(error: e.toString());
      },
    );
  }

  void _subscribeUsers() {
    _usersSub?.cancel();
    _usersSub = _ref
        .read(dashboardRepositoryProvider)
        .watchUsers(
          role: state.usersRoleFilter,
          isActive: state.usersActiveFilter,
        )
        .listen(
      (users) {
        state = state.copyWith(users: users);
      },
      onError: (e) {
        state = state.copyWith(error: e.toString());
      },
    );
  }

  void _subscribeLogs() {
    _logsSub?.cancel();
    _logsSub = _ref
        .read(logRepositoryProvider)
        .watchLogs(
          modulo: state.logsModuloFilter,
          limit: 100,
        )
        .listen(
      (logs) {
        state = state.copyWith(logs: logs);
      },
      onError: (e) {
        state = state.copyWith(error: e.toString());
      },
    );
  }

  Future<void> addLog({
    required String accion,
    required String modulo,
    String detalle = '',
  }) async {
    final user = _ref.read(authViewModelProvider).user;
    if (user == null) return;

    await _ref.read(logRepositoryProvider).addLog(
          usuarioId: user.uid,
          accion: accion,
          modulo: modulo,
          origen: 'mobile',
          detalle: detalle,
        );
  }

  Future<void> refreshAll() async {
    _subscribeUsers();
    _subscribeContents();
    _subscribeBusinesses();
    _subscribeLogs();
  }

  void setUsersRoleFilter(String? role) {
    state = state.copyWith(usersRoleFilter: role);
    _subscribeUsers();
  }

  void setUsersActiveFilter(bool? active) {
    state = state.copyWith(
      usersActiveFilter: active,
      clearUsersActiveFilter: active == null,
    );
    _subscribeUsers();
  }

  void setLogsModuloFilter(String? modulo) {
    state = state.copyWith(logsModuloFilter: modulo);
    _subscribeLogs();
  }

  void setContentsCategoryFilter(String? categoria) {
    state = state.copyWith(
      contentsCategoryFilter: categoria,
      clearContentsCategoryFilter: categoria == null,
    );
    _subscribeContents();
  }

  void setBusinessesCategoryFilter(String? categoria) {
    state = state.copyWith(
      businessesCategoryFilter: categoria,
      clearBusinessesCategoryFilter: categoria == null,
    );
    _subscribeBusinesses();
  }

  void setGlobalSearchQuery(String query) {
    state = state.copyWith(globalSearchQuery: query);
  }

  Future<void> updateUser({
    required AppUserModel user,
    required String role,
    required bool isActive,
    required String description,
  }) async {
    await _ref.read(dashboardRepositoryProvider).updateUser(
          uid: user.uid,
          role: role,
          isActive: isActive,
          description: description,
        );
    _subscribeUsers();
    await addLog(
      accion: 'Actualizar usuario',
      modulo: 'usuarios',
      detalle:
          '${user.email} -> rol ${AppRoles.label(role)}, estado ${isActive ? 'activo' : 'inactivo'}',
    );
  }

  Future<void> updateContentStatus(Content content, bool isActive) async {
    await _ref.read(dashboardRepositoryProvider).updateContentStatus(
          contentId: content.id,
          isActive: isActive,
        );
    await addLog(
      accion: 'Actualizar contenido',
      modulo: 'contenidos',
      detalle: '${content.titulo} -> ${isActive ? 'activo' : 'inactivo'}',
    );
  }

  Future<void> deleteContent(Content content) async {
    await _ref.read(dashboardRepositoryProvider).deleteContent(content.id);
    await addLog(
      accion: 'Eliminar contenido',
      modulo: 'contenidos',
      detalle: content.titulo,
    );
  }

  Future<void> updateBusinessStatus(
    Microbusiness business,
    bool isActive,
  ) async {
    await _ref.read(dashboardRepositoryProvider).updateMicrobusinessStatus(
          businessId: business.id,
          isActive: isActive,
        );
    await addLog(
      accion: 'Actualizar micronegocio',
      modulo: 'micronegocios',
      detalle: '${business.nombre} -> ${isActive ? 'activo' : 'inactivo'}',
    );
  }

  Future<void> deleteBusiness(Microbusiness business) async {
    await _ref.read(dashboardRepositoryProvider).deleteMicrobusiness(
          business.id,
        );
    await addLog(
      accion: 'Eliminar micronegocio',
      modulo: 'micronegocios',
      detalle: business.nombre,
    );
  }

  @override
  void dispose() {
    _metricsSub?.cancel();
    _usersSub?.cancel();
    _contentsSub?.cancel();
    _businessesSub?.cancel();
    _logsSub?.cancel();
    super.dispose();
  }
}

final dashboardViewModelProvider =
    StateNotifierProvider<DashboardViewModel, DashboardState>((ref) {
  return DashboardViewModel(ref);
});
