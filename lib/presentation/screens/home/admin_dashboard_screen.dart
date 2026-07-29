import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../widgets/role_home.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const RoleHomeScreen(
      title: 'Panel TI',
      greeting: 'Hola Experto TI',
      description:
          'Supervisa usuarios, integraciones, seguridad y disponibilidad operativa de Livi@se.',
      icon: Icons.admin_panel_settings_outlined,
      actions: [
        RoleHomeAction(
          label: 'Métricas y usuarios',
          description: 'Indicadores, roles, actividad y trazabilidad',
          icon: Icons.analytics_outlined,
          route: '/admin-dashboard',
          color: AppColors.accent,
        ),
        RoleHomeAction(
          label: 'Micronegocios',
          description: 'Directorio, estados y ubicación de registros',
          icon: Icons.storefront,
          route: '/micronegocios',
        ),
        RoleHomeAction(
          label: 'Cronograma',
          description: 'Actividades, contenidos y agenda publicada',
          icon: Icons.event_note_outlined,
          route: '/contenidos',
          color: AppColors.secondary,
        ),
        RoleHomeAction(
          label: 'Alertas',
          description: 'Crea y modifica noticias y avisos oficiales',
          icon: Icons.notifications_active_outlined,
          route: '/noticias',
          color: AppColors.warning,
        ),
        RoleHomeAction(
          label: 'Categorías',
          description: 'Áreas de contenidos y tipos de micronegocios',
          icon: Icons.category_outlined,
          route: '/admin/categorias',
          color: AppColors.primaryDark,
        ),
        RoleHomeAction(
          label: 'Entidades',
          description: 'Gestiona entidades, enlaces y documentos PDF',
          icon: Icons.apartment_outlined,
          route: '/admin/entidades',
          color: AppColors.primaryDark,
        ),
        RoleHomeAction(
          label: 'Foros y docentes',
          description: 'Asigna consultas a docentes y revisa respuestas',
          icon: Icons.forum_outlined,
          route: '/foros',
          color: AppColors.secondary,
        ),
        RoleHomeAction(
          label: 'Soporte TI',
          description: 'Seguridad, integraciones e incidentes',
          icon: Icons.health_and_safety_outlined,
          route: '/soporte-ti',
          color: AppColors.warning,
        ),
        RoleHomeAction(
          label: 'Perfil',
          description: 'Datos de cuenta y contacto',
          icon: Icons.person_outline,
          route: '/perfil',
        ),
      ],
    );
  }
}
