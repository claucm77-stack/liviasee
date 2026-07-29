import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_roles.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/category_viewmodel.dart';

class RoleHomeAction {
  const RoleHomeAction({
    required this.label,
    required this.description,
    required this.icon,
    required this.route,
    this.color = AppColors.primary,
  });

  final String label;
  final String description;
  final IconData icon;
  final String route;
  final Color color;
}

class RoleHomeScreen extends ConsumerWidget {
  const RoleHomeScreen({
    super.key,
    required this.title,
    required this.greeting,
    required this.description,
    required this.icon,
    required this.actions,
  });

  final String title;
  final String greeting;
  final String description;
  final IconData icon;
  final List<RoleHomeAction> actions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authViewModelProvider);
    final role = authState.user?.role;
    final showSupport =
        AppRoles.isMicroempresario(role) || AppRoles.isDocente(role);
    final rawName = authState.user?.name.trim().isNotEmpty == true
        ? authState.user!.name.trim()
        : (authState.user?.email.split('@').first ?? '');
    final firstName = rawName.split(' ').first;
    final categoryCards = ref.watch(activeContentCategoriesProvider).maybeWhen(
          data: (categories) {
            if (categories.isEmpty) return const <_LearningCardData>[];
            return categories
                .map(
                  (category) => _LearningCardData(
                    title: category.nombre.toUpperCase(),
                    subtitle: category.descripcion.isEmpty
                        ? 'Consulta contenidos y actividades de esta área.'
                        : category.descripcion,
                    imageUrl: category.imageUrl.isEmpty
                        ? _fallbackLearningImage
                        : category.imageUrl,
                    categoryName: category.nombre,
                  ),
                )
                .toList();
          },
          orElse: () => const <_LearningCardData>[],
        );

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _FigmaHeader(
                onShortcutTap: (route) => context.go(route),
                onSignOut: () async {
                  await ref.read(authViewModelProvider.notifier).signOut();
                  if (context.mounted) {
                    context.go('/');
                  }
                },
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 28, 28, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      firstName.isEmpty ? greeting : 'Hola $firstName',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: const Color(0xFF555555),
                                fontWeight: FontWeight.w700,
                              ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: const Color(0xFF5F5F5F),
                          ),
                    ),
                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 198,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  scrollDirection: Axis.horizontal,
                  itemCount: actions.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 22),
                  itemBuilder: (context, index) {
                    final action = actions[index];
                    return _YellowActionCard(
                      action: action,
                      onTap: () => context.go(action.route),
                    );
                  },
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 28)),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              sliver: SliverList.separated(
                itemCount: categoryCards.length,
                separatorBuilder: (_, __) => const SizedBox(height: 26),
                itemBuilder: (context, index) {
                  final card = categoryCards[index];
                  return _LearningCard(
                    card: card,
                    onTap: () {
                      context.go(
                        Uri(
                          path: '/contenidos',
                          queryParameters: {'category': card.categoryName},
                        ).toString(),
                      );
                    },
                  );
                },
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
            const SliverToBoxAdapter(child: _FigmaFooter()),
          ],
        ),
      ),
      bottomNavigationBar: _FigmaBottomNav(
        onHome: () => context.go('/'),
        onSearch: () => context.go('/micronegocios'),
        onLibrary: () => context.go('/contenidos'),
        onSupport: () => context.go('/soporte-ti'),
        onProfile: () => context.go('/perfil'),
        showSupport: showSupport,
      ),
    );
  }
}

class _FigmaHeader extends StatelessWidget {
  const _FigmaHeader({
    required this.onShortcutTap,
    required this.onSignOut,
  });

  final ValueChanged<String> onShortcutTap;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300,
      width: double.infinity,
      color: const Color(0xFF4C8D93),
      child: Stack(
        children: [
          Positioned(
            top: 12,
            left: 14,
            child: IconButton(
              tooltip: 'Volver',
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                }
              },
              icon: const Icon(
                Icons.arrow_back,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
          Positioned(
            top: 12,
            right: 14,
            child: IconButton(
              tooltip: 'Cerrar sesión',
              onPressed: onSignOut,
              icon: const Icon(
                Icons.logout,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
          Column(
            children: [
              const SizedBox(height: 54),
              Text(
                'Livi@se',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 40,
                      letterSpacing: 0,
                    ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 0, 28, 38),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _RoleShortcut(
                      label: 'EMPRESARIO',
                      icon: Icons.storefront,
                      onTap: () => onShortcutTap('/micronegocios'),
                    ),
                    _RoleShortcut(
                      label: 'DOCENTES',
                      icon: Icons.co_present_outlined,
                      onTap: () => onShortcutTap('/docentes'),
                    ),
                    _RoleShortcut(
                      label: 'ENTIDADES',
                      icon: Icons.apartment_outlined,
                      onTap: () => onShortcutTap('/entidades'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoleShortcut extends StatelessWidget {
  const _RoleShortcut({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(40),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF3C747A),
            ),
            child: Icon(icon, color: Colors.white, size: 36),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }
}

class _YellowActionCard extends StatelessWidget {
  const _YellowActionCard({
    required this.action,
    required this.onTap,
  });

  final RoleHomeAction action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 254,
      child: Material(
        color: const Color(0xFFFFCA55),
        borderRadius: BorderRadius.circular(22),
        elevation: 4,
        shadowColor: Colors.black.withValues(alpha: 0.24),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.all(26),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  action.label.toUpperCase(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontSize: 18,
                        height: 0.95,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const Spacer(),
                Align(
                  alignment: Alignment.bottomRight,
                  child: Icon(action.icon, color: Colors.white, size: 54),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LearningCardData {
  const _LearningCardData({
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.categoryName,
  });

  final String title;
  final String subtitle;
  final String imageUrl;
  final String categoryName;
}

const _fallbackLearningImage =
    'https://images.unsplash.com/photo-1534536281715-e28d76689b4d?auto=format&fit=crop&w=900&q=80';

class _LearningCard extends StatelessWidget {
  const _LearningCard({
    required this.card,
    required this.onTap,
  });

  final _LearningCardData card;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.08,
      child: Material(
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                card.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: const Color(0xFF1F2937),
                  child: const Icon(
                    Icons.image_not_supported_outlined,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.05),
                      Colors.black.withValues(alpha: 0.72),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 18,
                right: 18,
                bottom: 22,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card.title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            height: 0.95,
                          ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      card.subtitle,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FigmaFooter extends StatelessWidget {
  const _FigmaFooter();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF193760),
      padding: const EdgeInsets.fromLTRB(28, 26, 28, 28),
      child: Column(
        children: [
          const _FooterLine(icon: Icons.phone, text: 'Sede Bogotá: 4322671'),
          const SizedBox(height: 22),
          const Wrap(
            spacing: 18,
            runSpacing: 14,
            alignment: WrapAlignment.center,
            children: [
              _SocialIcon(
                asset:
                    'assets/images/institutional/social_facebook_20260604.png',
                url: 'https://www.facebook.com/USanMartinOficial',
                label: 'Facebook',
              ),
              _SocialIcon(
                asset:
                    'assets/images/institutional/social_instagram_20260604.png',
                url: 'https://www.instagram.com/usanmartinoficial/',
                label: 'Instagram',
              ),
              _SocialIcon(
                asset: 'assets/images/institutional/social_x_20260604.png',
                url: 'https://x.com/USanMartinCO',
                label: 'X',
              ),
              _SocialIcon(
                asset:
                    'assets/images/institutional/social_youtube_20260604.png',
                url: 'https://www.youtube.com/@USanMartinOficial',
                label: 'YouTube',
              ),
              _SocialIcon(
                asset:
                    'assets/images/institutional/social_linkedin_20260604.png',
                url:
                    'https://www.linkedin.com/school/fundaci%C3%B3n-universitaria-san-mart%C3%ADn',
                label: 'LinkedIn',
              ),
            ],
          ),
          const SizedBox(height: 24),
          InkWell(
            onTap: () => launchUrl(
              Uri.parse('https://sanmartin.edu.co/'),
              mode: LaunchMode.externalApplication,
            ),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Image.asset(
                'assets/images/logo.png',
                width: 250,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SocialIcon extends StatelessWidget {
  const _SocialIcon({
    required this.asset,
    required this.url,
    required this.label,
  });

  final String asset;
  final String url;
  final String label;

  Future<void> _open() async {
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: _open,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Image.asset(
            asset,
            width: 34,
            height: 34,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}

class _FooterLine extends StatelessWidget {
  const _FooterLine({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white, size: 18),
        const SizedBox(width: 10),
        Text(
          text,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
        ),
      ],
    );
  }
}

class _FigmaBottomNav extends StatelessWidget {
  const _FigmaBottomNav({
    required this.onHome,
    required this.onSearch,
    required this.onLibrary,
    required this.onSupport,
    required this.onProfile,
    required this.showSupport,
  });

  final VoidCallback onHome;
  final VoidCallback onSearch;
  final VoidCallback onLibrary;
  final VoidCallback onSupport;
  final VoidCallback onProfile;
  final bool showSupport;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        height: 72,
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(
              tooltip: 'Inicio',
              onPressed: onHome,
              icon: const Icon(Icons.home_outlined, size: 34),
            ),
            IconButton(
              tooltip: 'Buscar',
              onPressed: onSearch,
              icon: const Icon(Icons.search, size: 34),
            ),
            IconButton(
              tooltip: 'Repositorio',
              onPressed: onLibrary,
              icon: const Icon(Icons.view_column_outlined, size: 34),
            ),
            if (showSupport)
              IconButton(
                tooltip: 'Soporte TI',
                onPressed: onSupport,
                icon: const Icon(Icons.support_agent_outlined, size: 34),
              ),
            IconButton(
              tooltip: 'Perfil',
              onPressed: onProfile,
              icon: const Icon(Icons.person_outline, size: 34),
            ),
          ],
        ),
      ),
    );
  }
}
