import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/app_roles.dart';
import '../../domain/entities/content.dart';
import '../../domain/repositories/content_repository.dart';
import '../../services/firestore_service.dart';
import '../../services/laravel_api_service.dart';
import '../models/content_model.dart';

class ContentRepositoryImpl implements ContentRepository {
  ContentRepositoryImpl(
    this._firestoreService, {
    LaravelApiService? laravelApiService,
  }) : _laravelApiService = laravelApiService ?? LaravelApiService();

  final FirestoreService _firestoreService;
  final LaravelApiService _laravelApiService;

  @override
  Future<void> createContent({
    required Content content,
    required String currentUserId,
    required String currentUserRole,
  }) async {
    _validateCreatePermission(
      currentUserId: currentUserId,
      currentUserRole: currentUserRole,
      content: content,
    );

    final model = ContentModel.fromEntity(content);
    await _saveToLaravelAndCache(model);
  }

  @override
  Future<void> updateContent({
    required Content content,
    required String currentUserId,
    required String currentUserRole,
  }) async {
    final existing = await getContentById(content.id);
    if (existing == null) {
      throw Exception('Contenido no encontrado.');
    }

    _validateUpdatePermission(
      currentUserId: currentUserId,
      currentUserRole: currentUserRole,
      existingContent: existing,
    );

    final model = ContentModel.fromEntity(content);
    await _saveToLaravelAndCache(model);
  }

  @override
  Future<void> deleteContent({
    required String contentId,
    required String currentUserId,
    required String currentUserRole,
  }) async {
    final existing = await getContentById(contentId);
    if (existing == null) {
      throw Exception('Contenido no encontrado.');
    }

    _validateDeletePermission(
      currentUserId: currentUserId,
      currentUserRole: currentUserRole,
      existingContent: existing,
    );

    await _laravelApiService.deleteMobileData('contents', contentId);
    await _firestoreService.deleteContent(contentId);
  }

  @override
  Future<Content?> getContentById(String contentId) async {
    if (_laravelApiService.isAuthenticated) {
      try {
        final rows = await _laravelApiService.fetchMobileData('contents');
        for (final row in rows) {
          if ((row['id'] ?? '').toString() == contentId) {
            return ContentModel.fromMap(contentId, row);
          }
        }
      } catch (_) {
        // Use the local Firestore cache only if Laravel is unavailable.
      }
    }
    final map = await _firestoreService.getContentById(contentId);
    if (map != null) return ContentModel.fromMap(contentId, map);
    return null;
  }

  @override
  Stream<List<Content>> watchContents({
    required String currentUserRole,
    String? categoria,
    int limit = 10,
  }) {
    return Stream.multi((controller) {
      StreamSubscription<List<QueryDocumentSnapshot<Map<String, dynamic>>>>?
          firestoreSub;
      Timer? apiTimer;
      var laravelLoaded = false;

      Future<void> loadFromFirestore() async {
        final onlyActive = AppRoles.isMicroempresario(currentUserRole);
        final source = _firestoreService.watchContents(
          onlyActive: onlyActive,
          categoria: categoria,
          limit: limit,
        );

        firestoreSub = source.listen(
          (docs) {
            if (!laravelLoaded) {
              controller.add(
                docs
                    .map((doc) => ContentModel.fromMap(doc.id, doc.data()))
                    .toList(),
              );
            }
          },
          onError: (Object error, StackTrace stackTrace) {
            if (laravelLoaded) return;
            if (error is FirebaseException &&
                error.code == 'permission-denied') {
              controller.add(<Content>[]);
              return;
            }
            controller.addError(error, stackTrace);
          },
        );
      }

      Future<void> loadLaravel() async {
        try {
          final apiContents = await _fetchApiContents(
            limit: limit,
            categoria: categoria,
          );

          if (controller.isClosed) return;
          laravelLoaded = true;
          controller.add(apiContents);
        } catch (_) {
          // Si la API publicada no responde, se conserva Firestore como respaldo.
        }
      }

      () async {
        await loadLaravel();
        if (!controller.isClosed) await loadFromFirestore();
      }();
      apiTimer =
          Timer.periodic(const Duration(seconds: 5), (_) => loadLaravel());

      controller.onCancel = () async {
        apiTimer?.cancel();
        await firestoreSub?.cancel();
      };
    });
  }

  @override
  Future<List<Content>> fetchContentsPage({
    required String currentUserRole,
    String? categoria,
    required int limit,
    DateTime? startAfterDate,
  }) async {
    final canUseLaravelFirstPage =
        (categoria == null || categoria.isEmpty) && startAfterDate == null;

    if (canUseLaravelFirstPage) {
      try {
        final apiContents = await _fetchApiContents(limit: limit);

        if (apiContents.isNotEmpty) {
          return apiContents;
        }
      } catch (_) {
        // fallback a Firestore
      }
    }

    final onlyActive = AppRoles.isMicroempresario(currentUserRole);
    try {
      final docs = await _firestoreService.fetchContentsPage(
        onlyActive: onlyActive,
        categoria: categoria,
        limit: limit,
        startAfterDate: startAfterDate,
      );
      return docs
          .map((doc) => ContentModel.fromMap(doc.id, doc.data()))
          .toList();
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        return [];
      }
      rethrow;
    }
  }

  Future<List<Content>> _fetchApiContents({
    required int limit,
    String? categoria,
  }) async {
    final perPage = categoria == null || categoria.isEmpty ? limit : 100;
    final rows = _laravelApiService.isAuthenticated
        ? await _laravelApiService.fetchMobileData('contents')
        : await _laravelApiService.fetchContents(perPage: perPage);
    final contents = rows
        .map(
      (row) => ContentModel.fromMap(
        (row['id'] ?? '').toString(),
        row,
      ),
    )
        .where((content) {
      if (categoria == null || categoria.isEmpty) return true;
      return content.categoria == categoria;
    }).toList();

    if (contents.length <= limit) return contents;
    return contents.take(limit).toList();
  }

  Future<void> _saveToLaravelAndCache(ContentModel model) async {
    if (!_laravelApiService.isAuthenticated) {
      throw StateError('La sesión con Laravel no está disponible.');
    }
    final saved = await _laravelApiService.saveMobileData(
      'contents',
      model.toMap(),
    );
    final id = (saved['id'] ?? model.id).toString();
    await _firestoreService.setContent(
      id: id,
      data: ContentModel.fromMap(id, saved).toMap(),
    );
  }

  @override
  Future<void> toggleFavorite({
    required String contentId,
    required String userId,
  }) async {
    try {
      final content = await getContentById(contentId);
      if (content == null) throw Exception('Contenido no encontrado.');

      if (content.favoritos.contains(userId)) {
        await _firestoreService.removeUserFromArrayField(
          contentId: contentId,
          field: 'favoritos',
          userId: userId,
        );
      } else {
        await _firestoreService.addUserToArrayField(
          contentId: contentId,
          field: 'favoritos',
          userId: userId,
        );
      }
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') return;
      rethrow;
    }
  }

  @override
  Future<void> markAsViewed({
    required String contentId,
    required String userId,
  }) async {
    try {
      await _firestoreService.addUserToArrayField(
        contentId: contentId,
        field: 'vistos',
        userId: userId,
      );
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') return;
      rethrow;
    }
  }

  void _validateCreatePermission({
    required String currentUserId,
    required String currentUserRole,
    required Content content,
  }) {
    if (AppRoles.isDocenteAdmin(currentUserRole)) return;

    if (AppRoles.isDocente(currentUserRole) &&
        content.autorId == currentUserId) {
      return;
    }

    throw Exception('No tienes permisos para crear este contenido.');
  }

  void _validateUpdatePermission({
    required String currentUserId,
    required String currentUserRole,
    required Content existingContent,
  }) {
    if (AppRoles.isDocenteAdmin(currentUserRole)) return;

    if (AppRoles.isDocente(currentUserRole) &&
        existingContent.autorId == currentUserId) {
      return;
    }

    throw Exception('No tienes permisos para editar este contenido.');
  }

  void _validateDeletePermission({
    required String currentUserId,
    required String currentUserRole,
    required Content existingContent,
  }) {
    if (AppRoles.isDocenteAdmin(currentUserRole)) return;

    if (AppRoles.isDocente(currentUserRole) &&
        existingContent.autorId == currentUserId) {
      return;
    }

    throw Exception('No tienes permisos para eliminar este contenido.');
  }
}
