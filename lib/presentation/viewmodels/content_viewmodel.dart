import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_roles.dart';
import '../../core/di/providers.dart';
import '../../domain/entities/content.dart';
import 'auth_viewmodel.dart';

class ContentState {
  final bool isLoading;
  final bool isLoadingMore;
  final List<Content> contents;
  final String? selectedCategory;
  final String? error;
  final bool hasMore;
  final DateTime? lastDate;

  const ContentState({
    this.isLoading = false,
    this.isLoadingMore = false,
    this.contents = const [],
    this.selectedCategory,
    this.error,
    this.hasMore = true,
    this.lastDate,
  });

  bool get isEmpty => !isLoading && contents.isEmpty && error == null;

  ContentState copyWith({
    bool? isLoading,
    bool? isLoadingMore,
    List<Content>? contents,
    String? selectedCategory,
    bool clearSelectedCategory = false,
    String? error,
    bool clearError = false,
    bool? hasMore,
    DateTime? lastDate,
    bool clearLastDate = false,
  }) {
    return ContentState(
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      contents: contents ?? this.contents,
      selectedCategory: clearSelectedCategory
          ? null
          : (selectedCategory ?? this.selectedCategory),
      error: clearError ? null : (error ?? this.error),
      hasMore: hasMore ?? this.hasMore,
      lastDate: clearLastDate ? null : (lastDate ?? this.lastDate),
    );
  }
}

class ContentViewModel extends StateNotifier<ContentState> {
  ContentViewModel(this._ref) : super(const ContentState()) {
    loadInitial();
  }

  final Ref _ref;
  StreamSubscription<List<Content>>? _contentsSub;
  int _loadGeneration = 0;

  String? get _userId => _ref.read(authViewModelProvider).user?.uid;
  String get _userRole =>
      _ref.read(authViewModelProvider).user?.role ?? AppRoles.microempresario;

  Future<void> loadInitial() async {
    final generation = ++_loadGeneration;
    final category = state.selectedCategory;
    state = state.copyWith(
      isLoading: true,
      isLoadingMore: false,
      contents: const <Content>[],
      clearError: true,
      clearLastDate: true,
      hasMore: true,
    );

    await _contentsSub?.cancel();
    if (generation != _loadGeneration ||
        !_sameCategory(state.selectedCategory, category)) {
      return;
    }
    _contentsSub = _ref
        .read(contentRepositoryProvider)
        .watchContents(
          currentUserRole: _userRole,
          categoria: category,
          limit: 10,
        )
        .listen(
      (contents) {
        if (generation != _loadGeneration ||
            !_sameCategory(state.selectedCategory, category)) {
          return;
        }
        DateTime? last;
        if (contents.isNotEmpty) {
          last = contents.last.fechaCreacion;
        }

        state = state.copyWith(
          isLoading: false,
          contents: contents,
          hasMore: contents.length >= 10,
          lastDate: last,
          clearError: true,
        );
      },
      onError: (Object e) {
        if (generation != _loadGeneration ||
            !_sameCategory(state.selectedCategory, category)) {
          return;
        }
        state = state.copyWith(
          isLoading: false,
          error: e.toString(),
        );
      },
    );
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;

    final generation = _loadGeneration;
    final category = state.selectedCategory;
    state = state.copyWith(isLoadingMore: true, clearError: true);

    try {
      final next = await _ref.read(contentRepositoryProvider).fetchContentsPage(
            currentUserRole: _userRole,
            categoria: category,
            limit: 10,
            startAfterDate: state.lastDate,
          );

      if (generation != _loadGeneration ||
          !_sameCategory(state.selectedCategory, category)) {
        return;
      }

      if (next.isEmpty) {
        state = state.copyWith(
          isLoadingMore: false,
          hasMore: false,
        );
        return;
      }

      final merged = [...state.contents];
      for (final item in next) {
        if (!merged.any((e) => e.id == item.id)) {
          merged.add(item);
        }
      }

      state = state.copyWith(
        isLoadingMore: false,
        contents: merged,
        hasMore: next.length >= 10,
        lastDate: merged.last.fechaCreacion,
      );
    } catch (e) {
      if (generation != _loadGeneration ||
          !_sameCategory(state.selectedCategory, category)) {
        return;
      }
      state = state.copyWith(
        isLoadingMore: false,
        error: e.toString(),
      );
    }
  }

  Future<void> setCategory(String? category) async {
    final normalizedCategory = category?.trim();
    final selected = normalizedCategory == null || normalizedCategory.isEmpty
        ? null
        : normalizedCategory;
    if (_sameCategory(state.selectedCategory, selected) &&
        _contentsSub != null) {
      return;
    }
    state = state.copyWith(
      selectedCategory: selected,
      clearSelectedCategory: selected == null,
      contents: const <Content>[],
      isLoading: true,
      isLoadingMore: false,
      clearError: true,
      clearLastDate: true,
      hasMore: true,
    );
    await loadInitial();
  }

  bool _sameCategory(String? first, String? second) {
    return (first ?? '').trim().toLowerCase() ==
        (second ?? '').trim().toLowerCase();
  }

  Future<void> createContent(Content content) async {
    final uid = _userId;
    if (uid == null) {
      state = state.copyWith(error: 'Usuario no autenticado.');
      return;
    }

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await _ref.read(contentRepositoryProvider).createContent(
            content: content,
            currentUserId: uid,
            currentUserRole: _userRole,
          );
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> updateContent(Content content) async {
    final uid = _userId;
    if (uid == null) {
      state = state.copyWith(error: 'Usuario no autenticado.');
      return;
    }

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await _ref.read(contentRepositoryProvider).updateContent(
            content: content,
            currentUserId: uid,
            currentUserRole: _userRole,
          );
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> deleteContent(String contentId) async {
    final uid = _userId;
    if (uid == null) {
      state = state.copyWith(error: 'Usuario no autenticado.');
      return;
    }

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await _ref.read(contentRepositoryProvider).deleteContent(
            contentId: contentId,
            currentUserId: uid,
            currentUserRole: _userRole,
          );
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> toggleFavorite(String contentId) async {
    final uid = _userId;
    if (uid == null) {
      state = state.copyWith(error: 'Usuario no autenticado.');
      return;
    }

    try {
      await _ref.read(contentRepositoryProvider).toggleFavorite(
            contentId: contentId,
            userId: uid,
          );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> markAsViewed(String contentId) async {
    final uid = _userId;
    if (uid == null) return;

    try {
      await _ref.read(contentRepositoryProvider).markAsViewed(
            contentId: contentId,
            userId: uid,
          );
    } catch (_) {}
  }

  @override
  void dispose() {
    _loadGeneration++;
    _contentsSub?.cancel();
    super.dispose();
  }
}

final contentViewModelProvider =
    StateNotifierProvider<ContentViewModel, ContentState>((ref) {
  return ContentViewModel(ref);
});
