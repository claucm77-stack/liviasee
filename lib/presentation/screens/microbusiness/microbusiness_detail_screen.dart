import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/app_roles.dart';
import '../../../core/utils/maps_url.dart';
import '../../../domain/entities/microbusiness.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/microbusiness_viewmodel.dart';
import '../../widgets/app_scaffold.dart';

class MicrobusinessDetailScreen extends ConsumerWidget {
  const MicrobusinessDetailScreen({super.key, required this.businessId});

  final String businessId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(microbusinessViewModelProvider);
    final authState = ref.watch(authViewModelProvider);
    final business = _findBusiness(state.businesses, businessId);

    if (business == null) {
      return const AppScaffold(
        title: 'Micronegocio',
        child: Center(child: Text('Micronegocio no encontrado.')),
      );
    }

    final canEdit = AppRoles.canEditBusiness(
      role: authState.user?.role,
      currentUserId: authState.user?.uid,
      ownerId: business.propietarioId,
    );

    return AppScaffold(
      title: business.nombre,
      showBack: true,
      actions: [
        IconButton(
          tooltip: 'Inicio',
          onPressed: () => context.go(_homeByRole(authState.user?.role)),
          icon: const Icon(Icons.home_outlined),
        ),
      ],
      floatingActionButton: canEdit
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/micronegocios/form/$businessId'),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Editar'),
            )
          : null,
      child: ListView(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: business.imagen.isEmpty
                  ? Container(
                      color: Colors.grey.shade200,
                      child: const Icon(Icons.store, size: 64),
                    )
                  : Image.network(
                      business.imagen,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.broken_image_outlined),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            business.nombre,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(label: Text(business.categoria)),
              Chip(
                label: Text(business.estado.name),
                avatar: Icon(
                  business.isActivo ? Icons.check_circle : Icons.pause_circle,
                  size: 18,
                ),
              ),
              if (business.ratingPromedio != null)
                Chip(
                  avatar: const Icon(Icons.star, size: 18),
                  label: Text(
                    '${business.ratingPromedio!.toStringAsFixed(1)} (${business.totalCalificaciones ?? 0})',
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(business.descripcion),
          const SizedBox(height: 16),
          _InfoTile(
            icon: Icons.place_outlined,
            title: 'Dirección',
            value: business.direccion,
          ),
          _InfoTile(
            icon: Icons.schedule_outlined,
            title: 'Horario',
            value: business.horario,
          ),
          _InfoTile(
            icon: Icons.phone_outlined,
            title: 'Contacto',
            value: business.contacto,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _openExternalMaps(business),
              icon: const Icon(Icons.directions_outlined),
              label: const Text('Cómo llegar'),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _shareBusiness(business),
                  icon: const Icon(Icons.share_outlined),
                  label: const Text('Compartir'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showRatingDialog(context, ref, business),
                  icon: const Icon(Icons.star_outline),
                  label: const Text('Calificar'),
                ),
              ),
            ],
          ),
          if (canEdit) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _confirmDelete(context, ref, business),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Eliminar'),
            ),
          ],
        ],
      ),
    );
  }

  Microbusiness? _findBusiness(List<Microbusiness> businesses, String id) {
    for (final business in businesses) {
      if (business.id == id) return business;
    }
    return null;
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
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

    if (confirmed != true || !context.mounted) return;
    await ref
        .read(microbusinessViewModelProvider.notifier)
        .deleteBusiness(business.id);
    if (context.mounted) context.go('/micronegocios');
  }

  Future<void> _openExternalMaps(Microbusiness business) async {
    await openMapsUri(mapsDirectionsUri(business));
  }

  Future<void> _shareBusiness(Microbusiness business) async {
    final mapUrl = mapsSearchUri(business).toString();
    await Share.share(
      '${business.nombre}\n${business.descripcion}\nDirección: ${business.direccion}\nCómo llegar: $mapUrl',
      subject: business.nombre,
    );
  }

  Future<void> _showRatingDialog(
    BuildContext context,
    WidgetRef ref,
    Microbusiness business,
  ) async {
    final selected = await showDialog<double>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Calificar micronegocio'),
        children: [
          for (var rating = 5; rating >= 1; rating--)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, rating.toDouble()),
              child: Row(
                children: [
                  for (var i = 0; i < rating; i++)
                    const Icon(Icons.star, color: Colors.amber, size: 20),
                  const SizedBox(width: 8),
                  Text('$rating'),
                ],
              ),
            ),
        ],
      ),
    );

    if (selected == null || !context.mounted) return;
    await ref
        .read(microbusinessViewModelProvider.notifier)
        .rateBusiness(business.id, selected);

    if (!context.mounted) return;
    final error = ref.read(microbusinessViewModelProvider).error;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error ?? 'Gracias por calificar ${business.nombre}.',
        ),
      ),
    );
  }

  String _homeByRole(String? role) {
    final normalized = AppRoles.normalize(role);
    if (normalized == AppRoles.adminTi) return '/admin';
    if (normalized == AppRoles.docenteAdmin) return '/admin-dashboard';
    if (normalized == AppRoles.docente) return '/educator';
    return '/entrepreneur';
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(value.isEmpty ? 'Sin información' : value),
    );
  }
}
