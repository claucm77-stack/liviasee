import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../domain/entities/content.dart';
import '../../viewmodels/dashboard_viewmodel.dart';

class ContentManagementScreen extends ConsumerWidget {
  const ContentManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dashboardViewModelProvider);
    final vm = ref.read(dashboardViewModelProvider.notifier);
    final categories = state.contents
        .map((content) => content.categoria)
        .where((category) => category.trim().isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    final contents = _filteredContents(state);

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String?>(
                initialValue: state.contentsCategoryFilter,
                decoration: const InputDecoration(
                  labelText: 'Categoría',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Todas')),
                  ...categories.map(
                    (category) => DropdownMenuItem(
                      value: category,
                      child: Text(category),
                    ),
                  ),
                ],
                onChanged: vm.setContentsCategoryFilter,
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              tooltip: 'Exportar CSV',
              onPressed: () => _exportCsv(contents),
              icon: const Icon(Icons.download_outlined),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: contents.isEmpty
              ? const Center(child: Text('No hay contenidos para mostrar'))
              : ListView.separated(
                  itemCount: contents.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final content = contents[index];
                    return ListTile(
                      leading: Icon(_iconFor(content.tipo)),
                      title: Text(content.titulo),
                      subtitle: Text(
                        '${content.categoria} • ${content.vistos.length} vistas',
                      ),
                      trailing: Wrap(
                        spacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Switch(
                            value: content.isActivo,
                            onChanged: (value) =>
                                vm.updateContentStatus(content, value),
                          ),
                          IconButton(
                            tooltip: 'Eliminar',
                            onPressed: () => _confirmDelete(
                              context,
                              vm,
                              content,
                            ),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  List<Content> _filteredContents(DashboardState state) {
    final q = state.globalSearchQuery.trim().toLowerCase();
    if (q.isEmpty) return state.contents;
    return state.contents.where((content) {
      return content.titulo.toLowerCase().contains(q) ||
          content.descripcion.toLowerCase().contains(q) ||
          content.categoria.toLowerCase().contains(q);
    }).toList();
  }

  IconData _iconFor(ContentType type) {
    switch (type) {
      case ContentType.video:
        return Icons.play_circle_outline;
      case ContentType.pdf:
        return Icons.picture_as_pdf_outlined;
      case ContentType.evento:
        return Icons.event_note_outlined;
      case ContentType.texto:
        return Icons.article_outlined;
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    DashboardViewModel vm,
    Content content,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar contenido'),
        content: Text('Se eliminará ${content.titulo}.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed == true) await vm.deleteContent(content);
  }

  Future<void> _exportCsv(List<Content> contents) async {
    final rows = [
      'id,titulo,categoria,estado,vistas',
      ...contents.map(
        (item) =>
            '${_csv(item.id)},${_csv(item.titulo)},${_csv(item.categoria)},${item.estado.name},${item.vistos.length}',
      ),
    ];
    await Share.share(rows.join('\n'), subject: 'Contenidos Liviase CSV');
  }

  String _csv(String value) => jsonEncode(value);
}
