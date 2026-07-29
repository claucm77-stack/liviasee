import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../viewmodels/dashboard_viewmodel.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../widgets/dashboard/user_status_badge.dart';
import '../../../core/constants/app_roles.dart';

class UsersViewScreen extends ConsumerWidget {
  const UsersViewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dashboardViewModelProvider);
    final vm = ref.read(dashboardViewModelProvider.notifier);
    final canEditUsers = AppRoles.canManageUsers(
      ref.watch(authViewModelProvider).user?.role,
    );

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                decoration: const InputDecoration(
                  labelText: 'Búsqueda global',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: vm.setGlobalSearchQuery,
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              tooltip: 'Exportar JSON',
              onPressed: () => _exportUsers(state.users),
              icon: const Icon(Icons.download_outlined),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String?>(
                initialValue: state.usersRoleFilter,
                decoration: const InputDecoration(
                  labelText: 'Rol',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: null, child: Text('Todos')),
                  DropdownMenuItem(
                    value: AppRoles.microempresario,
                    child: Text('Microempresario'),
                  ),
                  DropdownMenuItem(
                    value: AppRoles.docente,
                    child: Text('Docente'),
                  ),
                  DropdownMenuItem(
                    value: AppRoles.docenteAdmin,
                    child: Text('Docente admin'),
                  ),
                  DropdownMenuItem(
                    value: AppRoles.adminTi,
                    child: Text('Experto TI'),
                  ),
                ],
                onChanged: vm.setUsersRoleFilter,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: state.usersActiveFilter == null
                    ? 'todos'
                    : (state.usersActiveFilter! ? 'activos' : 'inactivos'),
                decoration: const InputDecoration(
                  labelText: 'Estado',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'todos', child: Text('Todos')),
                  DropdownMenuItem(value: 'activos', child: Text('Activos')),
                  DropdownMenuItem(
                    value: 'inactivos',
                    child: Text('Inactivos'),
                  ),
                ],
                onChanged: (value) {
                  if (value == 'todos') vm.setUsersActiveFilter(null);
                  if (value == 'activos') vm.setUsersActiveFilter(true);
                  if (value == 'inactivos') vm.setUsersActiveFilter(false);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _filteredUsers(state).isEmpty
              ? const Center(child: Text('No hay usuarios para mostrar'))
              : ListView.separated(
                  itemCount: _filteredUsers(state).length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final user = _filteredUsers(state)[index];
                    final isActive = user.isActive;

                    return ListTile(
                      leading: const Icon(Icons.person_outline),
                      title: Text(user.name.isEmpty ? user.email : user.name),
                      subtitle: Text('${user.email} • Rol: ${user.roleLabel}'),
                      trailing: Wrap(
                        spacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          UserStatusBadge(isActive: isActive),
                          if (canEditUsers)
                            IconButton(
                              tooltip: 'Editar usuario',
                              onPressed: () => _editUser(context, ref, user),
                              icon: const Icon(Icons.edit_outlined),
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

  List<dynamic> _filteredUsers(DashboardState state) {
    final q = state.globalSearchQuery.trim().toLowerCase();
    if (q.isEmpty) return state.users;
    return state.users.where((user) {
      return user.name.toLowerCase().contains(q) ||
          user.email.toLowerCase().contains(q) ||
          user.roleLabel.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _editUser(
    BuildContext context,
    WidgetRef ref,
    dynamic user,
  ) async {
    var selectedRole = user.role as String;
    var isActive = user.isActive as bool;
    final descriptionCtrl =
        TextEditingController(text: user.description as String);
    final result = await showDialog<(String, bool, String)>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(user.email),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: selectedRole,
                decoration: const InputDecoration(labelText: 'Rol'),
                items: const [
                  DropdownMenuItem(
                    value: AppRoles.microempresario,
                    child: Text('Microempresario'),
                  ),
                  DropdownMenuItem(
                    value: AppRoles.docente,
                    child: Text('Docente'),
                  ),
                  DropdownMenuItem(
                    value: AppRoles.docenteAdmin,
                    child: Text('Docente admin'),
                  ),
                  DropdownMenuItem(
                    value: AppRoles.adminTi,
                    child: Text('Experto TI'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => selectedRole = value);
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: isActive,
                title: const Text('Usuario activo'),
                onChanged: (value) => setState(() => isActive = value),
              ),
              TextField(
                controller: descriptionCtrl,
                minLines: 3,
                maxLines: 5,
                maxLength: 2000,
                decoration: const InputDecoration(
                  labelText: 'Descripción del docente',
                  hintText: 'Experiencia, especialidad y acompañamiento.',
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                context,
                (selectedRole, isActive, descriptionCtrl.text.trim()),
              ),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );

    if (result == null) {
      descriptionCtrl.dispose();
      return;
    }
    await ref.read(dashboardViewModelProvider.notifier).updateUser(
          user: user,
          role: result.$1,
          isActive: result.$2,
          description: result.$3,
        );
    descriptionCtrl.dispose();
  }

  Future<void> _exportUsers(List<dynamic> users) async {
    final payload = users.map((user) => user.toMap()).toList();
    await Share.share(
      const JsonEncoder.withIndent('  ').convert(payload),
      subject: 'Usuarios Liviase',
    );
  }
}
