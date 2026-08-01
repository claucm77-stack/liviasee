import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_roles.dart';
import '../../../domain/entities/content.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/content_viewmodel.dart';

class ContentListScreen extends ConsumerStatefulWidget {
  const ContentListScreen({super.key, this.initialCategory});

  final String? initialCategory;

  @override
  ConsumerState<ContentListScreen> createState() => _ContentListScreenState();
}

class _ContentListScreenState extends ConsumerState<ContentListScreen> {
  String _query = '';

  @override
  void initState() {
    super.initState();
    Future.microtask(_syncCategory);
  }

  @override
  void didUpdateWidget(covariant ContentListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialCategory != widget.initialCategory) {
      Future.microtask(_syncCategory);
    }
  }

  Future<void> _syncCategory() async {
    final selected = ref.read(contentViewModelProvider).selectedCategory;
    if (selected == widget.initialCategory) return;
    await ref
        .read(contentViewModelProvider.notifier)
        .setCategory(widget.initialCategory);
  }

  static const _contentGroups = [
    _ContentGroup(
      title: 'Conferencia en vivo',
      detailWhenEmpty: 'Sin contenidos',
      imageUrl:
          'https://images.unsplash.com/photo-1515187029135-18ee286d815b?auto=format&fit=crop&w=300&q=80',
      icon: Icons.live_tv_outlined,
    ),
    _ContentGroup(
      title: 'Repositorio en video',
      detailWhenEmpty: 'Sin contenidos',
      imageUrl:
          'https://images.unsplash.com/photo-1522202176988-66273c2fd55f?auto=format&fit=crop&w=300&q=80',
      icon: Icons.play_circle_outline,
    ),
    _ContentGroup(
      title: 'Artículos Relacionados',
      detailWhenEmpty: 'Sin contenidos',
      imageUrl:
          'https://images.unsplash.com/photo-1507842217343-583bb7270b66?auto=format&fit=crop&w=300&q=80',
      icon: Icons.article_outlined,
    ),
    _ContentGroup(
      title: 'Cronograma Actividades',
      detailWhenEmpty: 'Sin contenidos',
      imageUrl:
          'https://images.unsplash.com/photo-1517048676732-d65bc937f952?auto=format&fit=crop&w=300&q=80',
      icon: Icons.event_note_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(contentViewModelProvider);
    final authState = ref.watch(authViewModelProvider);
    final currentUserId = authState.user?.uid ?? '';
    final q = _query.trim().toLowerCase();
    final selectedCategory =
        (widget.initialCategory ?? '').trim().toLowerCase();
    final filteredContents = state.contents.where((item) {
      if (!item.hasUsableDestination) return false;
      if (selectedCategory.isNotEmpty &&
          item.categoria.trim().toLowerCase() != selectedCategory) {
        return false;
      }
      if (q.isEmpty) return true;
      return item.titulo.toLowerCase().contains(q) ||
          item.descripcion.toLowerCase().contains(q) ||
          item.categoria.toLowerCase().contains(q);
    }).toList();
    final popular = _popularArticlesFrom(filteredContents);
    final latestContents = filteredContents.take(6).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        toolbarHeight: 86,
        leadingWidth: 90,
        leading: IconButton(
          tooltip: 'Volver',
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Color(0xFF9C9C9C),
            size: 48,
          ),
          onPressed: () => _goBack(context, authState.user?.role),
        ),
        title: Text(
          'Todos los contenidos',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: const Color(0xFF7A7A7A),
                fontWeight: FontWeight.w900,
                fontSize: 19,
              ),
        ),
        centerTitle: false,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await ref.read(contentViewModelProvider.notifier).loadInitial();
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(28, 36, 28, 28),
            children: [
              TextField(
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  hintText: 'Artículo o autor',
                  prefixIcon: const Icon(
                    Icons.search,
                    color: Color(0xFF8F969A),
                    size: 32,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(7),
                    borderSide:
                        const BorderSide(color: Color(0xFF4C8D93), width: 2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(7),
                    borderSide:
                        const BorderSide(color: Color(0xFF4C8D93), width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              if (state.isLoading && state.contents.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(bottom: 22),
                  child: LinearProgressIndicator(
                    color: Color(0xFF4C8D93),
                    minHeight: 3,
                  ),
                ),
              ..._contentGroups.map((group) {
                final groupItems = _itemsForGroup(group, filteredContents);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ContentGroupCard(
                    group: group,
                    count: groupItems.length,
                    imageUrl: _firstContentImage(groupItems) ?? group.imageUrl,
                    onTap: () => _showGroup(
                      context,
                      group,
                      groupItems,
                      currentUserId,
                    ),
                  ),
                );
              }),
              if (latestContents.isNotEmpty) ...[
                const SizedBox(height: 32),
                Text(
                  'Últimos contenidos',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: const Color(0xFF7A7A7A),
                        fontWeight: FontWeight.w900,
                        fontSize: 19,
                      ),
                ),
                const SizedBox(height: 20),
                ...latestContents.map(
                  (content) => Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: _PopularContentTile(
                      item: content,
                      isFavorite: content.isFavoriteFor(currentUserId),
                      onOpen: () => _openContent(context, content),
                      onToggleInterest: () async {
                        if (currentUserId.isEmpty) return;
                        await ref
                            .read(contentViewModelProvider.notifier)
                            .toggleFavorite(content.id);
                      },
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 32),
              Text(
                'Artículos Populares',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: const Color(0xFF7A7A7A),
                      fontWeight: FontWeight.w900,
                      fontSize: 19,
                    ),
              ),
              const SizedBox(height: 20),
              if (state.error != null && state.contents.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    'No se pudieron cargar los contenidos publicados.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF8A8A8A),
                        ),
                  ),
                ),
              if (popular.isEmpty && q.isNotEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 18),
                  child: Center(child: Text('Sin coincidencias.')),
                )
              else if (popular.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 18),
                  child: Center(
                    child: Text('No hay artículos publicados.'),
                  ),
                )
              else
                ...popular.map(
                  (article) => Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: _PopularContentTile(
                      item: article,
                      isFavorite: article.isFavoriteFor(currentUserId),
                      onOpen: () => _openContent(context, article),
                      onToggleInterest: () async {
                        if (currentUserId.isEmpty) return;
                        await ref
                            .read(contentViewModelProvider.notifier)
                            .toggleFavorite(article.id);
                      },
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<Content> _popularArticlesFrom(List<Content> contents) {
    final articles = contents.where((item) {
      return item.tipo == ContentType.texto ||
          item.tipo == ContentType.pdf ||
          item.categoria.toLowerCase().contains('art');
    }).toList();
    if (articles.isNotEmpty) {
      return articles.take(6).toList();
    }
    return contents.take(6).toList();
  }

  List<Content> _itemsForGroup(_ContentGroup group, List<Content> contents) {
    final title = group.title.toLowerCase();
    final filtered = contents.where((item) {
      final category = item.categoria.toLowerCase();
      if (title.contains('conferencia')) {
        return category.contains('conferencia') ||
            category.contains('vivo') ||
            category.contains('evento en vivo');
      }
      if (title.contains('video')) {
        return item.tipo == ContentType.video;
      }
      if (title.contains('art')) {
        return item.tipo == ContentType.texto ||
            item.tipo == ContentType.pdf ||
            category.contains('art');
      }
      if (title.contains('cronograma')) {
        return item.tipo == ContentType.evento ||
            category.contains('actividad') ||
            category.contains('cronograma') ||
            category.contains('evento');
      }
      return false;
    }).toList();

    if (title.contains('video')) {
      filtered.removeWhere(
          (item) => item.categoria.toLowerCase().contains('conferencia'));
    }
    return filtered;
  }

  String? _firstContentImage(List<Content> contents) {
    for (final item in contents) {
      final image = item.imagen.trim();
      if (image.isNotEmpty) return image;
    }
    return null;
  }

  void _showGroup(
    BuildContext context,
    _ContentGroup group,
    List<Content> contents,
    String currentUserId,
  ) {
    final pageContext = context;
    showModalBottomSheet<void>(
      context: pageContext,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 6, 24, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  group.title,
                  style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                        color: const Color(0xFF5F666A),
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                      ),
                ),
                const SizedBox(height: 16),
                if (contents.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    child: Text(
                      'No hay contenidos disponibles en esta sección.',
                      style:
                          Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(
                                color: const Color(0xFF6F7579),
                              ),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: contents.length,
                      separatorBuilder: (_, __) => const Divider(height: 22),
                      itemBuilder: (context, index) {
                        final item = contents[index];
                        return _PopularContentTile(
                          item: item,
                          isFavorite: item.isFavoriteFor(currentUserId),
                          onOpen: () {
                            Navigator.of(sheetContext).pop();
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) _openContent(pageContext, item);
                            });
                          },
                          onToggleInterest: () async {
                            if (currentUserId.isEmpty) return;
                            await ref
                                .read(contentViewModelProvider.notifier)
                                .toggleFavorite(item.id);
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _goBack(BuildContext context, String? role) {
    if (context.canPop()) {
      context.pop();
      return;
    }

    final normalized = AppRoles.normalize(role);
    if (normalized == AppRoles.adminTi) {
      context.go('/admin');
    } else if (normalized == AppRoles.docenteAdmin) {
      context.go('/admin-dashboard');
    } else if (normalized == AppRoles.docente) {
      context.go('/educator');
    } else {
      context.go('/entrepreneur');
    }
  }

  Future<void> _openContent(BuildContext context, Content item) async {
    final uri = item.externalUri;
    if ((item.tipo == ContentType.video || item.tipo == ContentType.pdf) &&
        uri != null) {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        return;
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No fue posible abrir el enlace. Se mostrará la información disponible.',
            ),
          ),
        );
      }
    }

    if (!context.mounted) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.titulo,
                    style: Theme.of(context).textTheme.titleLarge),
                if (item.imagen.trim().isNotEmpty) ...[
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.network(
                      item.imagen,
                      width: double.infinity,
                      height: 220,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                if (item.autorNombre.trim().isNotEmpty) ...[
                  Text(
                    'Autor: ${item.autorNombre}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (item.tipo == ContentType.evento) ...[
                  _EventDetails(metadata: item.metadata),
                  const SizedBox(height: 12),
                ],
                if (item.hasReadableDetails)
                  Text(item.contenido.trim().isEmpty
                      ? item.descripcion
                      : item.contenido)
                else
                  const Text(
                    'Este contenido no tiene información o un enlace disponible. Comunícalo al administrador.',
                  ),
                if (uri != null &&
                    item.tipo != ContentType.video &&
                    item.tipo != ContentType.pdf) ...[
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: () async {
                      await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                    },
                    icon: const Icon(Icons.open_in_new),
                    label: Text(item.tipo == ContentType.evento
                        ? 'Abrir inscripción'
                        : 'Abrir enlace'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EventDetails extends StatelessWidget {
  const _EventDetails({required this.metadata});

  final Map<String, dynamic> metadata;

  @override
  Widget build(BuildContext context) {
    final rows = <(IconData, String)>[
      if (_text('starts_at').isNotEmpty)
        (Icons.schedule_outlined, 'Inicio: ${_text('starts_at')}'),
      if (_text('ends_at').isNotEmpty)
        (Icons.schedule, 'Fin: ${_text('ends_at')}'),
      if (_text('location').isNotEmpty)
        (Icons.location_on_outlined, _text('location')),
      if (_text('modality').isNotEmpty)
        (Icons.groups_outlined, 'Modalidad: ${_text('modality')}'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: rows
          .map(
            (row) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(row.$1, size: 19, color: const Color(0xFF4C8D93)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(row.$2)),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  String _text(String key) => (metadata[key] ?? '').toString().trim();
}

class _ContentGroupCard extends StatelessWidget {
  const _ContentGroupCard({
    required this.group,
    required this.count,
    required this.imageUrl,
    required this.onTap,
  });

  final _ContentGroup group;
  final int count;
  final String imageUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final detail = count > 0 ? '($count Resultados)' : group.detailWhenEmpty;

    return Material(
      color: const Color(0xFFE6E4E4),
      borderRadius: BorderRadius.circular(15),
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: 0.25),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: onTap,
        child: SizedBox(
          height: 76,
          child: Row(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(12),
                ),
                child: Image.network(
                  imageUrl,
                  width: 84,
                  height: 76,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 84,
                    height: 76,
                    color: const Color(0xFFD4D4D4),
                    child: Icon(group.icon, color: const Color(0xFF777777)),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: const Color(0xFF7B7B7B),
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                          ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.black,
                            fontSize: 12,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _PopularContentTile extends StatelessWidget {
  const _PopularContentTile({
    required this.item,
    required this.isFavorite,
    required this.onOpen,
    required this.onToggleInterest,
  });

  final Content item;
  final bool isFavorite;
  final VoidCallback onOpen;
  final VoidCallback onToggleInterest;

  @override
  Widget build(BuildContext context) {
    final author = item.autorNombre.trim().isNotEmpty
        ? item.autorNombre
        : (item.autorId.trim().isNotEmpty
            ? item.autorId
            : 'Autor no informado');

    return Row(
      children: [
        IconButton(
          tooltip: isFavorite ? 'Quitar favorito' : 'Guardar contenido',
          onPressed: onToggleInterest,
          icon: Icon(
            isFavorite ? Icons.bookmark : Icons.bookmark_border,
            color: const Color(0xFF9D9D9D),
            size: 34,
          ),
        ),
        const SizedBox(width: 2),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: item.imagen.trim().isEmpty
              ? Container(
                  width: 58,
                  height: 52,
                  color: const Color(0xFFE6E4E4),
                  child: const Icon(
                    Icons.image_outlined,
                    color: Color(0xFF8A8A8A),
                  ),
                )
              : Image.network(
                  item.imagen,
                  width: 58,
                  height: 52,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 58,
                    height: 52,
                    color: const Color(0xFFE6E4E4),
                    child: const Icon(
                      Icons.broken_image_outlined,
                      color: Color(0xFF8A8A8A),
                    ),
                  ),
                ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: InkWell(
            onTap: onOpen,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.titulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.black,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                ),
                const SizedBox(height: 3),
                Text(
                  author,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF7A7A7A),
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          _sourceFrom(item.categoria),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.right,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.black,
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
        ),
      ],
    );
  }

  String _sourceFrom(String category) {
    return category.trim();
  }
}

class _ContentGroup {
  const _ContentGroup({
    required this.title,
    required this.detailWhenEmpty,
    required this.imageUrl,
    required this.icon,
  });

  final String title;
  final String detailWhenEmpty;
  final String imageUrl;
  final IconData icon;
}
