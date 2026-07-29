import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_roles.dart';
import '../../../core/di/providers.dart';
import '../../../data/models/alert_model.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../widgets/app_scaffold.dart';

class NewsAlertsScreen extends ConsumerStatefulWidget {
  const NewsAlertsScreen({super.key});

  @override
  ConsumerState<NewsAlertsScreen> createState() => _NewsAlertsScreenState();
}

class _NewsAlertsScreenState extends ConsumerState<NewsAlertsScreen> {
  var _alerts = <AlertModel>[];
  var _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final rows =
          await ref.read(laravelApiServiceProvider).fetchMobileData('alerts');
      final alerts = rows.map(AlertModel.fromMap).toList()
        ..sort((a, b) {
          final order = a.sortOrder.compareTo(b.sortOrder);
          return order != 0 ? order : a.source.compareTo(b.source);
        });
      if (!mounted) return;
      setState(() {
        _alerts = alerts;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'No fue posible cargar las alertas.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authViewModelProvider).user;
    final canRate = AppRoles.isMicroempresario(user?.role);
    final canManage = AppRoles.canManageSystem(user?.role);

    return AppScaffold(
      title: 'Noticias y alertas',
      showBack: true,
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () => _editAlert(),
              icon: const Icon(Icons.add_alert_outlined),
              label: const Text('Nueva alerta'),
            )
          : null,
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SectionHeader(
              title: 'Fuentes oficiales',
              subtitle:
                  'Información de entidades para seguimiento académico y empresarial.',
              icon: Icons.campaign_outlined,
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_error != null)
              _MessageCard(message: _error!, icon: Icons.cloud_off_outlined)
            else if (_alerts.isEmpty)
              const _MessageCard(
                message: 'No hay alertas disponibles.',
                icon: Icons.notifications_off_outlined,
              )
            else
              ..._alerts.map(
                (alert) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Card(
                    child: ListTile(
                      leading: Icon(
                        alert.isActive
                            ? Icons.campaign_outlined
                            : Icons.notifications_off_outlined,
                      ),
                      title: Text(alert.source),
                      subtitle: _EventRatingSubtitle(
                        eventId: 'alert-${alert.id}',
                        text:
                            '${alert.title}\n${alert.description}${canManage && !alert.isActive ? '\nInactiva' : ''}',
                      ),
                      isThreeLine: true,
                      onTap: alert.linkUrl.isEmpty
                          ? null
                          : () => _openLink(alert.linkUrl),
                      trailing: canManage
                          ? PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'edit') _editAlert(alert);
                                if (value == 'delete') _deleteAlert(alert);
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Text('Editar'),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Eliminar'),
                                ),
                              ],
                            )
                          : canRate
                              ? IconButton(
                                  tooltip: 'Calificar alerta',
                                  onPressed: () =>
                                      _rateEvent('alert-${alert.id}'),
                                  icon: const Icon(
                                    Icons.star_rate,
                                    color: Color(0xFFFFCA55),
                                  ),
                                )
                              : const Icon(
                                  Icons.notifications_active_outlined,
                                ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _editAlert([AlertModel? alert]) async {
    final source = TextEditingController(text: alert?.source);
    final title = TextEditingController(text: alert?.title);
    final description = TextEditingController(text: alert?.description);
    final link = TextEditingController(text: alert?.linkUrl);
    final order = TextEditingController(text: '${alert?.sortOrder ?? 0}');
    var isActive = alert?.isActive ?? true;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(alert == null ? 'Nueva alerta' : 'Editar alerta'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: source,
                  decoration: const InputDecoration(labelText: 'Fuente'),
                ),
                TextField(
                  controller: title,
                  decoration: const InputDecoration(labelText: 'Título'),
                ),
                TextField(
                  controller: description,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Descripción'),
                ),
                TextField(
                  controller: link,
                  keyboardType: TextInputType.url,
                  decoration:
                      const InputDecoration(labelText: 'Enlace opcional'),
                ),
                TextField(
                  controller: order,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Orden'),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Visible en la app'),
                  value: isActive,
                  onChanged: (value) => setDialogState(() => isActive = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                if (source.text.trim().isEmpty || title.text.trim().isEmpty) {
                  return;
                }
                await ref.read(laravelApiServiceProvider).saveMobileData(
                      'alerts',
                      AlertModel(
                        id: alert?.id ?? '',
                        source: source.text.trim(),
                        title: title.text.trim(),
                        description: description.text.trim(),
                        linkUrl: link.text.trim(),
                        sortOrder: int.tryParse(order.text) ?? 0,
                        isActive: isActive,
                      ).toMap(),
                    );
                if (context.mounted) Navigator.pop(context, true);
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    source.dispose();
    title.dispose();
    description.dispose();
    link.dispose();
    order.dispose();
    if (saved == true) await _load();
  }

  Future<void> _deleteAlert(AlertModel alert) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar alerta'),
        content: Text('Se eliminará “${alert.title}”.'),
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
    if (confirmed != true) return;
    await ref
        .read(laravelApiServiceProvider)
        .deleteMobileData('alerts', alert.id);
    await _load();
  }

  Future<void> _openLink(String value) async {
    final uri = Uri.tryParse(value);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _rateEvent(String eventId) async {
    final user = ref.read(authViewModelProvider).user;
    if (user == null) return;
    final rating = await showDialog<double>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Calificar alerta'),
        children: [
          for (var value = 5; value >= 1; value--)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, value.toDouble()),
              child: Row(
                children: [
                  for (var i = 0; i < value; i++)
                    const Icon(Icons.star, color: Color(0xFFFFCA55)),
                  const SizedBox(width: 8),
                  Text('$value'),
                ],
              ),
            ),
        ],
      ),
    );
    if (rating == null) return;
    await ref.read(firestoreServiceProvider).rateEvent(
          eventId: eventId,
          userId: user.uid,
          rating: rating,
        );
  }
}

class _EventRatingSubtitle extends ConsumerWidget {
  const _EventRatingSubtitle({required this.eventId, required this.text});

  final String eventId;
  final String text;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder(
      stream: ref.watch(firestoreServiceProvider).watchEventRatings(eventId),
      builder: (context, snapshot) {
        final docs = snapshot.data ?? const [];
        final ratings = docs
            .map((doc) => (doc.data()['rating'] as num?)?.toDouble())
            .whereType<double>()
            .toList();
        final avg = ratings.isEmpty
            ? null
            : ratings.reduce((a, b) => a + b) / ratings.length;
        final ratingText = avg == null
            ? 'Sin calificaciones'
            : 'Calificación: ${avg.toStringAsFixed(1)} (${ratings.length})';
        return Text('$text\n$ratingText');
      },
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.message, required this.icon});

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(icon, size: 36),
            const SizedBox(height: 10),
            Text(message),
          ],
        ),
      ),
    );
  }
}
