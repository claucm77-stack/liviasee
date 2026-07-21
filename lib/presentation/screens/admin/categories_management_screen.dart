import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/app_category.dart';
import '../../viewmodels/category_viewmodel.dart';

class CategoriesManagementScreen extends ConsumerWidget {
  const CategoriesManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adminState = ref.watch(categoryAdminViewModelProvider);
    final adminVm = ref.read(categoryAdminViewModelProvider.notifier);

    ref.listen<CategoryAdminState>(categoryAdminViewModelProvider, (
      previous,
      next,
    ) {
      final message = next.error ?? next.successMessage;
      if (message == null || message == previous?.error) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      adminVm.clearMessages();
    });

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _CategorySection(
          title: 'Categorías de contenidos, cronograma y eventos',
          subtitle:
              'Estas categorías alimentan las tarjetas iniciales como Publicidad y Mercadeo, Derecho o Contabilidad.',
          scope: AppCategoryScope.contenidos,
          categoriesAsync: ref.watch(contentCategoriesProvider),
          isSubmitting: adminState.isSubmitting,
        ),
        const SizedBox(height: 14),
        _CategorySection(
          title: 'Categorías de micronegocios',
          subtitle:
              'Estas opciones se usan en el directorio y formulario de creación de micronegocios.',
          scope: AppCategoryScope.micronegocios,
          categoriesAsync: ref.watch(microbusinessCategoriesProvider),
          isSubmitting: adminState.isSubmitting,
        ),
      ],
    );
  }
}

class _CategorySection extends ConsumerWidget {
  const _CategorySection({
    required this.title,
    required this.subtitle,
    required this.scope,
    required this.categoriesAsync,
    required this.isSubmitting,
  });

  final String title;
  final String subtitle;
  final String scope;
  final AsyncValue<List<AppCategory>> categoriesAsync;
  final bool isSubmitting;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vm = ref.read(categoryAdminViewModelProvider.notifier);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(subtitle),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: 'Crear categoría',
                  onPressed: isSubmitting
                      ? null
                      : () => _showCategoryForm(context, ref, scope: scope),
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: isSubmitting ? null : () => vm.seedDefaults(scope),
                icon: const Icon(Icons.auto_awesome_outlined),
                label: const Text('Cargar categorías base'),
              ),
            ),
            const Divider(height: 24),
            categoriesAsync.when(
              data: (categories) {
                if (categories.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text('Aún no hay categorías creadas.'),
                    ),
                  );
                }

                return Column(
                  children: categories
                      .map(
                        (category) => _CategoryTile(
                          category: category,
                          onEdit: () => _showCategoryForm(
                            context,
                            ref,
                            scope: scope,
                            category: category,
                          ),
                          onDelete: isSubmitting
                              ? null
                              : () => _confirmDelete(context, ref, category),
                        ),
                      )
                      .toList(),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Text('No se pudieron cargar: $error'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    AppCategory category,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar categoría'),
        content: Text('¿Eliminar "${category.nombre}"?'),
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

    if (confirmed == true) {
      await ref
          .read(categoryAdminViewModelProvider.notifier)
          .deleteCategory(category.id);
    }
  }

  Future<void> _showCategoryForm(
    BuildContext context,
    WidgetRef ref, {
    required String scope,
    AppCategory? category,
  }) async {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: category?.nombre ?? '');
    final descriptionCtrl =
        TextEditingController(text: category?.descripcion ?? '');
    final imageCtrl = TextEditingController(text: category?.imageUrl ?? '');
    final orderCtrl =
        TextEditingController(text: (category?.orden ?? 0).toString());
    var isActive = category?.isActive ?? true;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  18,
                  8,
                  18,
                  MediaQuery.of(context).viewInsets.bottom + 18,
                ),
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          category == null
                              ? 'Nueva categoría'
                              : 'Editar categoría',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: nameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Nombre',
                            prefixIcon: Icon(Icons.category_outlined),
                          ),
                          validator: _required,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: descriptionCtrl,
                          minLines: 2,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            labelText: 'Descripción',
                            prefixIcon: Icon(Icons.notes_outlined),
                          ),
                        ),
                        if (scope == AppCategoryScope.contenidos) ...[
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: imageCtrl,
                            keyboardType: TextInputType.url,
                            decoration: const InputDecoration(
                              labelText: 'URL de imagen',
                              prefixIcon: Icon(Icons.image_outlined),
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: orderCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Orden',
                            prefixIcon: Icon(Icons.sort_outlined),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Categoría activa'),
                          value: isActive,
                          onChanged: (value) =>
                              setModalState(() => isActive = value),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: () async {
                            if (!formKey.currentState!.validate()) return;
                            final id = category?.id ??
                                '${scope}_${DateTime.now().millisecondsSinceEpoch}';
                            final newCategory = AppCategory(
                              id: id,
                              nombre: nameCtrl.text.trim(),
                              scope: scope,
                              descripcion: descriptionCtrl.text.trim(),
                              imageUrl: imageCtrl.text.trim(),
                              orden: int.tryParse(orderCtrl.text.trim()) ?? 0,
                              isActive: isActive,
                              createdAt: category?.createdAt ?? DateTime.now(),
                            );

                            await ref
                                .read(categoryAdminViewModelProvider.notifier)
                                .saveCategory(newCategory);
                            if (context.mounted) Navigator.pop(context);
                          },
                          icon: const Icon(Icons.save_outlined),
                          label: const Text('Guardar'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    nameCtrl.dispose();
    descriptionCtrl.dispose();
    imageCtrl.dispose();
    orderCtrl.dispose();
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Campo obligatorio.' : null;
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.onEdit,
    required this.onDelete,
  });

  final AppCategory category;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: ClipOval(
        child: SizedBox.square(
          dimension: 40,
          child: category.imageUrl.trim().isEmpty
              ? _categoryFallback(category)
              : Image.network(
                  category.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _categoryFallback(category),
                ),
        ),
      ),
      title: Text(category.nombre),
      subtitle: Text(
        [
          if (category.descripcion.isNotEmpty) category.descripcion,
          'Orden ${category.orden}',
          category.isActive ? 'Activa' : 'Inactiva',
        ].join(' · '),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Wrap(
        spacing: 4,
        children: [
          IconButton(
            tooltip: 'Editar',
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'Eliminar',
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
  }

  Widget _categoryFallback(AppCategory category) {
    return ColoredBox(
      color:
          category.isActive ? const Color(0xFF4C8D93) : const Color(0xFFE6E4E4),
      child: Icon(
        category.scope == AppCategoryScope.contenidos
            ? Icons.menu_book_outlined
            : Icons.storefront_outlined,
        color: category.isActive ? Colors.white : const Color(0xFF555555),
      ),
    );
  }
}
