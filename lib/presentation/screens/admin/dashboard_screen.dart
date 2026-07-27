import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_roles.dart';
import '../../../domain/entities/content.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/dashboard_viewmodel.dart';
import '../../widgets/dashboard/metric_card.dart';
import 'business_management_screen.dart';
import 'categories_management_screen.dart';
import 'content_management_screen.dart';
import 'entities_management_screen.dart';
import 'logs_screen.dart';
import 'users_view_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dashboardViewModelProvider);
    final vm = ref.read(dashboardViewModelProvider.notifier);
    final role = ref.watch(authViewModelProvider).user?.role;
    final isSystemAdmin = AppRoles.canManageSystem(role);
    final tabs = <Tab>[
      const Tab(text: 'Resumen'),
      const Tab(text: 'Usuarios'),
      const Tab(text: 'Contenidos'),
      if (isSystemAdmin) const Tab(text: 'Categorías'),
      if (isSystemAdmin) const Tab(text: 'Entidades'),
      const Tab(text: 'Negocios'),
      const Tab(text: 'Logs'),
    ];
    final views = <Widget>[
      _SummaryTab(state: state),
      const Padding(
        padding: EdgeInsets.all(12.0),
        child: UsersViewScreen(),
      ),
      const Padding(
        padding: EdgeInsets.all(12.0),
        child: ContentManagementScreen(),
      ),
      if (isSystemAdmin)
        const Padding(
          padding: EdgeInsets.all(12.0),
          child: CategoriesManagementScreen(),
        ),
      if (isSystemAdmin)
        const Padding(
          padding: EdgeInsets.all(12.0),
          child: EntitiesManagementScreen(),
        ),
      const Padding(
        padding: EdgeInsets.all(12.0),
        child: BusinessManagementScreen(),
      ),
      const Padding(
        padding: EdgeInsets.all(12.0),
        child: LogsScreen(),
      ),
    ];

    if (!state.isAdmin && !state.isLoading) {
      return const Scaffold(
        body: Center(
          child: Text('No tienes permisos para acceder a este dashboard'),
        ),
      );
    }

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Dashboard de gestión'),
          leading: IconButton(
            tooltip: 'Volver',
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/');
              }
            },
            icon: const Icon(Icons.arrow_back),
          ),
          actions: [
            IconButton(
              tooltip: 'Inicio',
              onPressed: () => context.go('/'),
              icon: const Icon(Icons.home_outlined),
            ),
            IconButton(
              tooltip: 'Cerrar sesión',
              onPressed: () async {
                await ref.read(authViewModelProvider.notifier).signOut();
                if (context.mounted) context.go('/');
              },
              icon: const Icon(Icons.logout),
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabs: tabs,
          ),
        ),
        body: RefreshIndicator(
          onRefresh: vm.refreshAll,
          child: state.isLoading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(children: views),
        ),
      ),
    );
  }
}

class _SummaryTab extends StatelessWidget {
  const _SummaryTab({required this.state});

  final DashboardState state;

  @override
  Widget build(BuildContext context) {
    final metrics = state.metrics;
    final roleCounts = <String, int>{
      for (final role in AppRoles.all)
        role: state.users
            .where((user) => AppRoles.normalize(user.role) == role)
            .length,
    };
    final totalRoleUsers = roleCounts.values.fold<int>(0, (a, b) => a + b);
    final recentLogs = [...state.logs]
      ..sort((a, b) => b.fecha.compareTo(a.fecha));
    final modules = <String, int>{};
    for (final log in state.logs) {
      modules.update(log.modulo.isEmpty ? 'general' : log.modulo, (v) => v + 1,
          ifAbsent: () => 1);
    }
    final moduleRows = modules.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topContents = [...state.contents]
      ..sort((a, b) => b.vistos.length.compareTo(a.vistos.length));
    final topBusinesses = [...state.businesses]
      ..sort((a, b) => b.favoritos.length.compareTo(a.favoritos.length));
    final activeContentsPercent =
        _percent(metrics.activeContents, metrics.totalContents);
    final activeMicrobusinessPercent =
        _percent(metrics.activeMicrobusinesses, metrics.totalMicrobusinesses);
    final eventCount = state.contents
        .where((content) => content.tipo == ContentType.evento)
        .length;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
      children: [
        _DashboardHero(
          users: metrics.totalUsers,
          contents: metrics.totalContents,
          microbusinesses: metrics.totalMicrobusinesses,
          events: eventCount,
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.65,
          children: [
            MetricCard(
              title: 'Usuarios',
              value: metrics.totalUsers.toString(),
              icon: Icons.people,
              color: const Color(0xFF4C8D93),
            ),
            MetricCard(
              title: 'Contenidos',
              value: metrics.totalContents.toString(),
              icon: Icons.menu_book,
              color: const Color(0xFF193760),
            ),
            MetricCard(
              title: 'Micronegocios',
              value: metrics.totalMicrobusinesses.toString(),
              icon: Icons.store,
              color: const Color(0xFF3C747A),
            ),
            MetricCard(
              title: 'Logs cargados',
              value: state.logs.length.toString(),
              icon: Icons.history,
              color: const Color(0xFFFFCA55),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _HealthPanel(
          title: 'Salud de la plataforma',
          items: [
            _HealthItem(
              label: 'Contenidos activos',
              value: activeContentsPercent,
              detail:
                  '${metrics.activeContents} activos / ${metrics.inactiveContents} inactivos',
              color: const Color(0xFF4C8D93),
            ),
            _HealthItem(
              label: 'Micronegocios visibles',
              value: activeMicrobusinessPercent,
              detail:
                  '${metrics.activeMicrobusinesses} activos / ${metrics.inactiveMicrobusinesses} inactivos',
              color: const Color(0xFFFFCA55),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _RolesPanel(
          total: totalRoleUsers,
          roleCounts: roleCounts,
        ),
        const SizedBox(height: 12),
        _ActivityPanel(
          moduleRows: moduleRows.take(4).toList(),
          recentLogs: recentLogs.take(5).toList(),
        ),
        const SizedBox(height: 12),
        _TopUsagePanel(
          topContents: topContents.take(4).toList(),
          topBusinesses: topBusinesses.take(4).toList(),
        ),
      ],
    );
  }

  double _percent(int active, int total) {
    if (total <= 0) return 0;
    return (active / total).clamp(0, 1);
  }
}

class _TopUsagePanel extends StatelessWidget {
  const _TopUsagePanel({
    required this.topContents,
    required this.topBusinesses,
  });

  final List<dynamic> topContents;
  final List<dynamic> topBusinesses;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Uso destacado',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Text('Contenidos más vistos',
                style: Theme.of(context).textTheme.labelLarge),
            if (topContents.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Text('Sin tracking de vistas todavía.'),
              )
            else
              ...topContents.map(
                (content) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.visibility_outlined),
                  title: Text(content.titulo),
                  trailing: Text('${content.vistos.length}'),
                ),
              ),
            const Divider(height: 24),
            Text('Negocios más consultados',
                style: Theme.of(context).textTheme.labelLarge),
            if (topBusinesses.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Text('Sin consultas registradas todavía.'),
              )
            else
              ...topBusinesses.map(
                (business) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.storefront_outlined),
                  title: Text(business.nombre),
                  subtitle: Text(business.categoria),
                  trailing: Text('${business.favoritos.length} fav.'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DashboardHero extends StatelessWidget {
  const _DashboardHero({
    required this.users,
    required this.contents,
    required this.microbusinesses,
    required this.events,
  });

  final int users;
  final int contents;
  final int microbusinesses;
  final int events;

  @override
  Widget build(BuildContext context) {
    final hasContent = contents > 0;
    final hasDirectory = microbusinesses > 0;
    final headline = hasContent && hasDirectory
        ? 'Ecosistema en operación'
        : 'Configura los datos principales';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF4C8D93),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            headline,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Usuarios, contenidos, micronegocios y trazabilidad en una sola vista para tomar decisiones rápidas.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.9),
                ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _HeroBadge(label: 'Usuarios', value: users),
              _HeroBadge(label: 'Contenidos', value: contents),
              _HeroBadge(label: 'Negocios', value: microbusinesses),
              _HeroBadge(label: 'Eventos', value: events),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroBadge extends StatelessWidget {
  const _HeroBadge({
    required this.label,
    required this.value,
  });

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Text(
        '$value $label',
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
      ),
    );
  }
}

class _HealthPanel extends StatelessWidget {
  const _HealthPanel({
    required this.title,
    required this.items,
  });

  final String title;
  final List<_HealthItem> items;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 14),
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.label,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        Text(
                          '${(item.value * 100).round()}%',
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    color: item.color,
                                  ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    LinearProgressIndicator(
                      value: item.value,
                      minHeight: 9,
                      borderRadius: BorderRadius.circular(8),
                      color: item.color,
                      backgroundColor: item.color.withValues(alpha: 0.14),
                    ),
                    const SizedBox(height: 5),
                    Text(item.detail),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HealthItem {
  const _HealthItem({
    required this.label,
    required this.value,
    required this.detail,
    required this.color,
  });

  final String label;
  final double value;
  final String detail;
  final Color color;
}

class _RolesPanel extends StatelessWidget {
  const _RolesPanel({
    required this.total,
    required this.roleCounts,
  });

  final int total;
  final Map<String, int> roleCounts;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Usuarios por rol',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            if (total == 0)
              const SizedBox(
                height: 80,
                child: Center(child: Text('Sin usuarios sincronizados')),
              )
            else
              ...roleCounts.entries.map(
                (entry) => _RoleDistributionRow(
                  label: AppRoles.label(entry.key),
                  count: entry.value,
                  total: total,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RoleDistributionRow extends StatelessWidget {
  const _RoleDistributionRow({
    required this.label,
    required this.count,
    required this.total,
  });

  final String label;
  final int count;
  final int total;

  @override
  Widget build(BuildContext context) {
    final value = total == 0 ? 0.0 : count / total;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label)),
              Text(
                count.toString(),
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: value,
            minHeight: 8,
            borderRadius: BorderRadius.circular(8),
            color: const Color(0xFF193760),
            backgroundColor: const Color(0xFFE6E4E4),
          ),
        ],
      ),
    );
  }
}

class _ActivityPanel extends StatelessWidget {
  const _ActivityPanel({
    required this.moduleRows,
    required this.recentLogs,
  });

  final List<MapEntry<String, int>> moduleRows;
  final List<dynamic> recentLogs;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Actividad reciente',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            if (moduleRows.isNotEmpty) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: moduleRows
                    .map(
                      (entry) => Chip(
                        label: Text('${entry.key}: ${entry.value}'),
                        backgroundColor: const Color(0xFFE6E4E4),
                        side: BorderSide.none,
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 12),
            ],
            if (recentLogs.isEmpty)
              const SizedBox(
                height: 80,
                child: Center(child: Text('Sin actividad registrada')),
              )
            else
              ...recentLogs.map(
                (log) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.history,
                    color: Color(0xFF4C8D93),
                  ),
                  title: Text(
                    log.accion,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text('${log.modulo} · ${_formatDate(log.fecha)}'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day/$month ${hour}h$minute';
  }
}
