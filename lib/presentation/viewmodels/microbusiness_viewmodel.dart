import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/constants/app_roles.dart';
import '../../core/di/providers.dart';
import '../../domain/entities/microbusiness.dart';
import 'auth_viewmodel.dart';

class MicrobusinessState {
  final bool isLoading;
  final bool isSubmitting;
  final List<Microbusiness> allBusinesses;
  final List<Microbusiness> businesses;
  final List<Microbusiness> nearbyBusinesses;
  final String? selectedCategory;
  final String searchQuery;
  final String? error;
  final Position? userPosition;
  final bool locationDenied;

  const MicrobusinessState({
    this.isLoading = false,
    this.isSubmitting = false,
    this.allBusinesses = const [],
    this.businesses = const [],
    this.nearbyBusinesses = const [],
    this.selectedCategory,
    this.searchQuery = '',
    this.error,
    this.userPosition,
    this.locationDenied = false,
  });

  bool get isEmpty => !isLoading && businesses.isEmpty && error == null;

  MicrobusinessState copyWith({
    bool? isLoading,
    bool? isSubmitting,
    List<Microbusiness>? allBusinesses,
    List<Microbusiness>? businesses,
    List<Microbusiness>? nearbyBusinesses,
    String? selectedCategory,
    bool clearSelectedCategory = false,
    String? searchQuery,
    String? error,
    bool clearError = false,
    Position? userPosition,
    bool clearUserPosition = false,
    bool? locationDenied,
  }) {
    return MicrobusinessState(
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      allBusinesses: allBusinesses ?? this.allBusinesses,
      businesses: businesses ?? this.businesses,
      nearbyBusinesses: nearbyBusinesses ?? this.nearbyBusinesses,
      selectedCategory: clearSelectedCategory
          ? null
          : (selectedCategory ?? this.selectedCategory),
      searchQuery: searchQuery ?? this.searchQuery,
      error: clearError ? null : (error ?? this.error),
      userPosition:
          clearUserPosition ? null : (userPosition ?? this.userPosition),
      locationDenied: locationDenied ?? this.locationDenied,
    );
  }
}

class MicrobusinessViewModel extends StateNotifier<MicrobusinessState> {
  MicrobusinessViewModel(this._ref) : super(const MicrobusinessState()) {
    loadInitial();
  }

  final Ref _ref;
  StreamSubscription<List<Microbusiness>>? _sub;

  String? get _userId => _ref.read(authViewModelProvider).user?.uid;
  String get _userRole =>
      _ref.read(authViewModelProvider).user?.role ?? AppRoles.microempresario;

  Future<void> loadInitial() async {
    state = state.copyWith(isLoading: true, clearError: true);

    await _sub?.cancel();
    _sub = _ref
        .read(microbusinessRepositoryProvider)
        .watchMicrobusinesses(
          currentUserRole: _userRole,
        )
        .listen(
      (items) {
        state = state.copyWith(
          isLoading: false,
          allBusinesses: items,
          businesses: _applyVisibleFilters(
            items,
            category: state.selectedCategory,
            searchText: state.searchQuery,
          ),
          clearError: true,
        );
      },
      onError: (Object e) {
        state = state.copyWith(isLoading: false, error: e.toString());
      },
    );
  }

  Future<void> setCategory(String? category) async {
    state = state.copyWith(
      selectedCategory: category,
      clearSelectedCategory: category == null,
      businesses: _applyVisibleFilters(
        state.allBusinesses,
        category: category,
        searchText: state.searchQuery,
      ),
      nearbyBusinesses: const [],
      clearError: true,
    );
  }

  Future<void> setSearchQuery(String query) async {
    state = state.copyWith(
      searchQuery: query,
      businesses: _applyVisibleFilters(
        state.allBusinesses,
        category: state.selectedCategory,
        searchText: query,
      ),
      clearError: true,
    );
  }

  List<Microbusiness> _applyVisibleFilters(
    List<Microbusiness> items, {
    String? category,
    String? searchText,
  }) {
    final selectedCategory = (category ?? '').trim().toLowerCase();
    final query = (searchText ?? '').trim().toLowerCase();

    return items.where((business) {
      final matchesCategory = selectedCategory.isEmpty ||
          business.categoria.trim().toLowerCase() == selectedCategory;
      final matchesSearch =
          query.isEmpty || business.nombre.toLowerCase().contains(query);
      return matchesCategory && matchesSearch;
    }).toList();
  }

  Future<void> createBusiness(Microbusiness business) async {
    final uid = _userId;
    if (uid == null) {
      state = state.copyWith(error: 'Usuario no autenticado.');
      return;
    }

    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      await _ref.read(microbusinessRepositoryProvider).createMicrobusiness(
            business: business,
            currentUserId: uid,
            currentUserRole: _userRole,
          );
      state = state.copyWith(isSubmitting: false);
    } catch (e) {
      state = state.copyWith(isSubmitting: false, error: e.toString());
    }
  }

  Future<void> updateBusiness(Microbusiness business) async {
    final uid = _userId;
    if (uid == null) {
      state = state.copyWith(error: 'Usuario no autenticado.');
      return;
    }

    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      await _ref.read(microbusinessRepositoryProvider).updateMicrobusiness(
            business: business,
            currentUserId: uid,
            currentUserRole: _userRole,
          );
      state = state.copyWith(isSubmitting: false);
    } catch (e) {
      state = state.copyWith(isSubmitting: false, error: e.toString());
    }
  }

  Future<void> deleteBusiness(String businessId) async {
    final uid = _userId;
    if (uid == null) {
      state = state.copyWith(error: 'Usuario no autenticado.');
      return;
    }

    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      await _ref.read(microbusinessRepositoryProvider).deleteMicrobusiness(
            businessId: businessId,
            currentUserId: uid,
            currentUserRole: _userRole,
          );
      state = state.copyWith(isSubmitting: false);
    } catch (e) {
      state = state.copyWith(isSubmitting: false, error: e.toString());
    }
  }

  Future<void> toggleFavorite(String businessId) async {
    final uid = _userId;
    if (uid == null) return;

    try {
      await _ref.read(microbusinessRepositoryProvider).toggleFavorite(
            businessId: businessId,
            userId: uid,
          );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> rateBusiness(String businessId, double rating) async {
    state = state.copyWith(clearError: true);
    try {
      final updated =
          await _ref.read(microbusinessRepositoryProvider).rateBusiness(
                businessId: businessId,
                rating: rating,
              );
      List<Microbusiness> replace(List<Microbusiness> items) => items
          .map((business) => business.id == updated.id ? updated : business)
          .toList();
      final allBusinesses = replace(state.allBusinesses);
      state = state.copyWith(
        allBusinesses: allBusinesses,
        businesses: _applyVisibleFilters(
          allBusinesses,
          category: state.selectedCategory,
          searchText: state.searchQuery,
        ),
        nearbyBusinesses: replace(state.nearbyBusinesses),
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> loadNearby({double maxDistanceKm = 10}) async {
    final pos = await _ensureLocationAndGet();
    if (pos == null) return;

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final nearby =
          await _ref.read(microbusinessRepositoryProvider).fetchNearby(
                currentUserRole: _userRole,
                userLat: pos.latitude,
                userLng: pos.longitude,
                maxDistanceKm: maxDistanceKm,
                categoria: state.selectedCategory,
                searchText: state.searchQuery,
              );
      state = state.copyWith(
        isLoading: false,
        nearbyBusinesses: nearby,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<Position?> _ensureLocationAndGet() async {
    final isEnabled = await Geolocator.isLocationServiceEnabled();
    if (!isEnabled) {
      state = state.copyWith(
        error: 'El servicio de ubicación está desactivado.',
        locationDenied: true,
      );
      return null;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      state = state.copyWith(
        error: 'Permiso de ubicación denegado.',
        locationDenied: true,
      );
      return null;
    }

    final position = await Geolocator.getCurrentPosition();
    state = state.copyWith(
      userPosition: position,
      locationDenied: false,
      clearError: true,
    );
    return position;
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final microbusinessViewModelProvider =
    StateNotifierProvider<MicrobusinessViewModel, MicrobusinessState>((ref) {
  return MicrobusinessViewModel(ref);
});
