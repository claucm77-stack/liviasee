import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../domain/entities/microbusiness.dart';
import '../../viewmodels/dashboard_viewmodel.dart';

class BusinessManagementScreen extends ConsumerWidget {
  const BusinessManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dashboardViewModelProvider);
    final vm = ref.read(dashboardViewModelProvider.notifier);
    final categories = state.businesses
        .map((business) => business.categoria)
        .where((category) => category.trim().isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    final businesses = _filteredBusinesses(state);

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String?>(
                initialValue: state.businessesCategoryFilter,
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
                onChanged: vm.setBusinessesCategoryFilter,
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              tooltip: 'Exportar JSON',
              onPressed: () => _exportJson(businesses),
              icon: const Icon(Icons.download_outlined),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: businesses.isEmpty
              ? const Center(child: Text('No hay micronegocios para mostrar'))
              : ListView.separated(
                  itemCount: businesses.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final business = businesses[index];
                    return ListTile(
                      leading: const Icon(Icons.storefront_outlined),
                      title: Text(business.nombre),
                      subtitle: Text(
                        '${business.categoria} • ${(business.ratingPromedio ?? 0).toStringAsFixed(1)} ★ '
                        '(${business.totalCalificaciones ?? 0} calificaciones) • '
                        '${business.favoritos.length} favoritos',
                      ),
                      trailing: Wrap(
                        spacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Switch(
                            value: business.isActivo,
                            onChanged: (value) =>
                                vm.updateBusinessStatus(business, value),
                          ),
                          IconButton(
                            tooltip: 'Eliminar',
                            onPressed: () => _confirmDelete(
                              context,
                              vm,
                              business,
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

  List<Microbusiness> _filteredBusinesses(DashboardState state) {
    final q = state.globalSearchQuery.trim().toLowerCase();
    if (q.isEmpty) return state.businesses;
    return state.businesses.where((business) {
      return business.nombre.toLowerCase().contains(q) ||
          business.descripcion.toLowerCase().contains(q) ||
          business.categoria.toLowerCase().contains(q) ||
          business.direccion.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _confirmDelete(
    BuildContext context,
    DashboardViewModel vm,
    Microbusiness business,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar micronegocio'),
        content: Text('Se eliminará ${business.nombre}.'),
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
    if (confirmed == true) await vm.deleteBusiness(business);
  }

  Future<void> _exportJson(List<Microbusiness> businesses) async {
    final payload = businesses
        .map(
          (item) => {
            'id': item.id,
            'nombre': item.nombre,
            'categoria': item.categoria,
            'direccion': item.direccion,
            'estado': item.estado.name,
            'favoritos': item.favoritos.length,
            'ratingPromedio': item.ratingPromedio,
          },
        )
        .toList();
    await Share.share(
      const JsonEncoder.withIndent('  ').convert(payload),
      subject: 'Micronegocios Liviase',
    );
  }
}
