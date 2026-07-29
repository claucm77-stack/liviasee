import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/constants/app_roles.dart';
import '../core/di/providers.dart';
import '../presentation/screens/auth/forgot_password_screen.dart';
import '../presentation/screens/auth/login_screen.dart';
import '../presentation/screens/auth/register_screen.dart';
import '../presentation/viewmodels/auth_viewmodel.dart';
import '../presentation/screens/content/content_list_screen.dart';
import '../presentation/screens/community/forum_screen.dart';
import '../presentation/screens/entities/entities_screen.dart';
import '../presentation/screens/admin/categories_management_screen.dart';
import '../presentation/screens/admin/dashboard_screen.dart';
import '../presentation/screens/admin/entities_management_screen.dart';
import '../presentation/screens/home/admin_dashboard_screen.dart';
import '../presentation/screens/home/educator_dashboard_screen.dart';
import '../presentation/screens/home/user_dashboard_screen.dart';
import '../presentation/screens/home/entrepreneur_dashboard_screen.dart';
import '../presentation/screens/microbusiness/microbusiness_detail_screen.dart';
import '../presentation/screens/microbusiness/microbusiness_form_screen.dart';
import '../presentation/screens/microbusiness/microbusiness_list_screen.dart';
import '../presentation/screens/microbusiness/microbusiness_map_screen.dart';
import '../presentation/screens/news/news_alerts_screen.dart';
import '../presentation/screens/profile/profile_screen.dart';
import '../presentation/screens/splash/splash_screen.dart';
import '../presentation/screens/support/tech_support_screen.dart';
import '../presentation/screens/teachers/teacher_chat_screen.dart';
import '../presentation/screens/teachers/teachers_screen.dart';

class _RouterAuthRefresh extends ChangeNotifier {
  _RouterAuthRefresh(Stream<dynamic> stream) {
    _sub = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final authRefresh = _RouterAuthRefresh(
    ref.watch(authRepositoryProvider).authStateChanges(),
  );
  ref.onDispose(authRefresh.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: authRefresh,
    redirect: (context, state) {
      final authAsync = ref.read(authStateStreamProvider);
      final user = authAsync.valueOrNull;
      final location = state.matchedLocation;

      const publicRoutes = ['/', '/login', '/register', '/forgot-password'];
      final isPublic = publicRoutes.contains(location);

      if (user == null) {
        if (isPublic) return null;
        return '/login';
      }

      final currentUser = ref.read(authViewModelProvider).user ?? user;
      final role = AppRoles.normalize(currentUser.role);
      final requiresMicrobusiness =
          AppRoles.isMicroempresario(role) && !currentUser.hasMicrobusiness;
      if (requiresMicrobusiness && location != '/micronegocios/form') {
        return '/micronegocios/form?onboarding=1';
      }

      if (location == '/') {
        return _homeByRole(currentUser.role);
      }

      if (location == '/login' || location == '/register') {
        return _homeByRole(user.role);
      }

      if (location == '/admin' && !AppRoles.canManageSystem(role)) {
        return _homeByRole(user.role);
      }
      if (location == '/admin/entidades' && !AppRoles.canManageSystem(role)) {
        return _homeByRole(user.role);
      }
      if (location == '/admin/categorias' && !AppRoles.canManageSystem(role)) {
        return _homeByRole(user.role);
      }
      if (location == '/admin-dashboard' && !AppRoles.canManageAcademic(role)) {
        return _homeByRole(user.role);
      }
      if (location == '/soporte-ti' && !AppRoles.canManageSystem(role)) {
        return _homeByRole(user.role);
      }
      if (location == '/educator' && !AppRoles.isDocente(role)) {
        return _homeByRole(user.role);
      }
      if (location == '/user' && !AppRoles.isMicroempresario(role)) {
        return _homeByRole(user.role);
      }

      if (location == '/contenidos' && !AppRoles.canViewContent(role)) {
        return _homeByRole(user.role);
      }

      if (location == '/micronegocios' && !AppRoles.canViewDirectory(role)) {
        return _homeByRole(user.role);
      }

      if (location == '/foros' && !AppRoles.canUseForums(role)) {
        return _homeByRole(user.role);
      }

      if (location == '/docentes' && !AppRoles.canViewContent(role)) {
        return _homeByRole(user.role);
      }

      if (location == '/docentes/chat' && !AppRoles.canUseForums(role)) {
        return _homeByRole(user.role);
      }

      if (location == '/entidades' && !AppRoles.canViewContent(role)) {
        return _homeByRole(user.role);
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/admin',
        builder: (context, state) => const AdminDashboardScreen(),
      ),
      GoRoute(
        path: '/admin/entidades',
        builder: (context, state) => const _AdminEntitiesPage(),
      ),
      GoRoute(
        path: '/admin/categorias',
        builder: (context, state) => const _AdminCategoriesPage(),
      ),
      GoRoute(
        path: '/admin-dashboard',
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/educator',
        builder: (context, state) => const EducatorDashboardScreen(),
      ),
      GoRoute(
        path: '/user',
        builder: (context, state) => const UserDashboardScreen(),
      ),
      GoRoute(
        path: '/entrepreneur',
        builder: (context, state) => const EntrepreneurDashboardScreen(),
      ),
      GoRoute(
        path: '/contenidos',
        builder: (context, state) => const ContentListScreen(),
      ),
      GoRoute(
        path: '/foros',
        builder: (context, state) => const ForumScreen(),
      ),
      GoRoute(
        path: '/docentes',
        builder: (context, state) => const TeachersScreen(),
      ),
      GoRoute(
        path: '/docentes/chat',
        builder: (context, state) => TeacherChatScreen(
          teacherId: state.uri.queryParameters['id'] ?? 'docente',
          teacherName: state.uri.queryParameters['name'] ?? 'Docente',
          teacherArea: state.uri.queryParameters['area'] ?? 'Asesoría',
          teacherImageUrl: state.uri.queryParameters['image'] ?? '',
        ),
      ),
      GoRoute(
        path: '/entidades',
        builder: (context, state) => const EntitiesScreen(),
      ),
      GoRoute(
        path: '/noticias',
        builder: (context, state) => const NewsAlertsScreen(),
      ),
      GoRoute(
        path: '/soporte-ti',
        builder: (context, state) => const TechSupportScreen(),
      ),
      GoRoute(
        path: '/micronegocios',
        builder: (context, state) => const MicrobusinessListScreen(),
      ),
      GoRoute(
        path: '/micronegocios/form',
        builder: (context, state) => MicrobusinessFormScreen(
          onboardingRequired: state.uri.queryParameters['onboarding'] == '1',
        ),
      ),
      GoRoute(
        path: '/micronegocios/form/:id',
        builder: (context, state) => MicrobusinessFormScreen(
          businessId: state.pathParameters['id'],
        ),
      ),
      GoRoute(
        path: '/micronegocios/detail/:id',
        builder: (context, state) => MicrobusinessDetailScreen(
          businessId: state.pathParameters['id'] ?? '',
        ),
      ),
      GoRoute(
        path: '/micronegocios/map',
        builder: (context, state) => MicrobusinessMapScreen(
          focusId: state.uri.queryParameters['focusId'],
        ),
      ),
      GoRoute(
        path: '/perfil',
        builder: (context, state) => const ProfileScreen(),
      ),
    ],
  );
});

String _homeByRole(String role) {
  switch (AppRoles.normalize(role)) {
    case AppRoles.adminTi:
      return '/admin';
    case AppRoles.docenteAdmin:
      return '/admin-dashboard';
    case AppRoles.docente:
      return '/educator';
    case AppRoles.microempresario:
      return '/entrepreneur';
    default:
      return '/entrepreneur';
  }
}

class _AdminEntitiesPage extends StatelessWidget {
  const _AdminEntitiesPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de entidades'),
        leading: IconButton(
          tooltip: 'Volver',
          onPressed: () => context.go('/admin'),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: const Padding(
        padding: EdgeInsets.all(12),
        child: EntitiesManagementScreen(),
      ),
    );
  }
}

class _AdminCategoriesPage extends StatelessWidget {
  const _AdminCategoriesPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de categorías'),
        leading: IconButton(
          tooltip: 'Volver',
          onPressed: () => context.go('/admin'),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: const Padding(
        padding: EdgeInsets.all(12),
        child: CategoriesManagementScreen(),
      ),
    );
  }
}
