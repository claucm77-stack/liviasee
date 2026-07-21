import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_roles.dart';
import '../../../core/utils/maps_url.dart';
import '../../../domain/entities/microbusiness.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/category_viewmodel.dart';
import '../../viewmodels/microbusiness_viewmodel.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/microbusiness/microbusiness_card.dart';
import '../../widgets/microbusiness/microbusiness_filter_bar.dart';
import '../../widgets/microbusiness/microbusiness_state_views.dart';

class MicrobusinessListScreen extends ConsumerWidget {
  const MicrobusinessListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(microbusinessViewModelProvider);
    final vm = ref.read(microbusinessViewModelProvider.notifier);
    final authState = ref.watch(authViewModelProvider);
    final currentUid = authState.user?.uid ?? '';
    final categories =
        ref.watch(activeMicrobusinessCategoriesProvider).maybeWhen(
              data: (items) => items.isEmpty
                  ? defaultMicrobusinessCategories
                      .map((category) => category.nombre)
                      .toList()
                  : items.map((category) => category.nombre).toList(),
              orElse: () => defaultMicrobusinessCategories
                  .map((category) => category.nombre)
                  .toList(),
            );

    return AppScaffold(
      title: 'Micronegocios',
      showBack: true,
      actions: [
        IconButton(
          tooltip: 'Inicio',
          onPressed: () => context.go(_homeByRole(authState.user?.role)),
          icon: const Icon(Icons.home_outlined),
        ),
      ],
      floatingActionButton: _canCreate(authState.user?.role)
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/micronegocios/form'),
              icon: const Icon(Icons.add_business),
              label: const Text('Crear'),
            )
          : null,
      child: Column(
        children: [
          MicrobusinessFilterBar(
            categories: categories,
            selectedCategory: state.selectedCategory,
            initialSearch: state.searchQuery,
            onCategoryChanged: (v) => vm.setCategory(v),
            onSearchChanged: (v) => vm.setSearchQuery(v),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _buildBody(
              context: context,
              state: state,
              onRetry: vm.loadInitial,
              currentUid: currentUid,
              onToggleFavorite: vm.toggleFavorite,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody({
    required BuildContext context,
    required MicrobusinessState state,
    required Future<void> Function() onRetry,
    required String currentUid,
    required Future<void> Function(String businessId) onToggleFavorite,
  }) {
    if (state.isLoading) return const MicrobusinessLoadingView();

    if (state.error != null) {
      return MicrobusinessErrorView(
        message: state.error!,
        onRetry: onRetry,
      );
    }

    if (state.businesses.isEmpty) return const MicrobusinessEmptyView();

    return RefreshIndicator(
      onRefresh: onRetry,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: state.businesses.length,
        itemBuilder: (context, index) {
          final business = state.businesses[index];
          return MicrobusinessCard(
            business: business,
            onTap: () => context.push('/micronegocios/detail/${business.id}'),
            onHowToGet: () => _openExternalMaps(business),
            onToggleFavorite: () => onToggleFavorite(business.id),
            isFavorite: business.isFavoriteFor(currentUid),
          );
        },
      ),
    );
  }

  bool _canCreate(String? role) => AppRoles.canCreateBusiness(role);

  Future<void> _openExternalMaps(Microbusiness business) async {
    await openMapsUri(mapsDirectionsUri(business));
  }

  String _homeByRole(String? role) {
    final normalized = AppRoles.normalize(role);
    if (normalized == AppRoles.adminTi) return '/admin';
    if (normalized == AppRoles.docenteAdmin) return '/admin-dashboard';
    if (normalized == AppRoles.docente) return '/educator';
    return '/entrepreneur';
  }
}
