import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_roles.dart';
import '../../../core/di/providers.dart';
import '../../viewmodels/auth_viewmodel.dart';

class TeachersScreen extends ConsumerStatefulWidget {
  const TeachersScreen({super.key});

  @override
  ConsumerState<TeachersScreen> createState() => _TeachersScreenState();
}

class _TeachersScreenState extends ConsumerState<TeachersScreen> {
  String _query = '';
  late Future<List<_Teacher>> _teachersFuture;

  @override
  void initState() {
    super.initState();
    _teachersFuture = _loadTeachers();
  }

  Future<List<_Teacher>> _loadTeachers() async {
    final rows = await ref.read(laravelApiServiceProvider).fetchTeachers();
    return rows.map(_Teacher.fromMap).toList();
  }

  void _refresh() {
    setState(() => _teachersFuture = _loadTeachers());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        toolbarHeight: 92,
        leadingWidth: 56,
        leading: IconButton(
          tooltip: 'Cerrar',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
          icon: const Icon(
            Icons.arrow_back,
            size: 34,
            color: Color(0xFF789CA5),
          ),
        ),
        title: Text(
          'Docentes',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: const Color(0xFF7A7A7A),
                fontWeight: FontWeight.w800,
              ),
        ),
        centerTitle: false,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1),
        ),
      ),
      body: FutureBuilder<List<_Teacher>>(
        future: _teachersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _TeacherDirectoryState(
              icon: Icons.cloud_off_outlined,
              title: 'No se pudieron cargar los docentes',
              message: 'Revisa la conexión con Laravel e intenta nuevamente.',
              onRetry: _refresh,
            );
          }

          final q = _query.trim().toLowerCase();
          final filtered = (snapshot.data ?? const <_Teacher>[])
              .where((teacher) =>
                  q.isEmpty ||
                  teacher.name.toLowerCase().contains(q) ||
                  teacher.area.toLowerCase().contains(q))
              .toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(14, 34, 14, 24),
            children: [
              TextField(
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  hintText: 'Nombre del docente',
                  prefixIcon: const Icon(Icons.search, size: 30),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        const BorderSide(color: Color(0xFF4C8D93), width: 2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        const BorderSide(color: Color(0xFF4C8D93), width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 34),
              if (filtered.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 72),
                  child: _TeacherDirectoryState(
                    icon: Icons.school_outlined,
                    title: 'No hay docentes disponibles',
                    message:
                        'Los docentes activos creados en Laravel aparecerán aquí.',
                  ),
                )
              else
                ...filtered.map(
                  (teacher) => Padding(
                    padding: const EdgeInsets.only(bottom: 30),
                    child: _TeacherTile(
                      teacher: teacher,
                      onMessage: () => _openChat(context, teacher),
                      onRate: () => _rateTeacher(teacher),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  void _openChat(BuildContext context, _Teacher teacher) {
    final params = {
      'id': teacher.id,
      'name': teacher.name,
      'area': teacher.area,
      'image': teacher.imageUrl,
    };
    context
        .push(Uri(path: '/docentes/chat', queryParameters: params).toString());
  }

  Future<void> _rateTeacher(_Teacher teacher) async {
    final user = ref.read(authViewModelProvider).user;
    if (user == null || !AppRoles.isMicroempresario(user.role)) return;

    final rating = await showDialog<double>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('Calificar a ${teacher.name}'),
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
    await ref.read(firestoreServiceProvider).rateTeacher(
          teacherId: teacher.id,
          userId: user.uid,
          rating: rating,
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Gracias por calificar a ${teacher.name}.')),
    );
  }
}

class _TeacherTile extends ConsumerWidget {
  const _TeacherTile({
    required this.teacher,
    required this.onMessage,
    required this.onRate,
  });

  final _Teacher teacher;
  final VoidCallback onMessage;
  final VoidCallback onRate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authViewModelProvider).user;
    final canRate = AppRoles.isMicroempresario(user?.role);
    return Row(
      children: [
        ClipOval(
          child: Image.network(
            teacher.imageUrl,
            width: 76,
            height: 76,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              width: 76,
              height: 76,
              color: AppColors.surfaceAlt,
              child: const Icon(Icons.person, color: AppColors.primary),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                teacher.name,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Colors.black,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
              ),
              Text(
                teacher.area,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.black,
                      fontSize: 16,
                      height: 1.2,
                    ),
              ),
              StreamBuilder(
                stream: ref
                    .watch(firestoreServiceProvider)
                    .watchTeacherRatings(teacher.id),
                builder: (context, snapshot) {
                  final docs = snapshot.data ?? const [];
                  final ratings = docs
                      .map((doc) => (doc.data()['rating'] as num?)?.toDouble())
                      .whereType<double>()
                      .toList();
                  final avg = ratings.isEmpty
                      ? 0.0
                      : ratings.reduce((a, b) => a + b) / ratings.length;
                  return Text(
                    ratings.isEmpty
                        ? 'Sin calificaciones'
                        : '${avg.toStringAsFixed(1)} (${ratings.length})',
                    style: Theme.of(context).textTheme.labelMedium,
                  );
                },
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Mensaje',
          onPressed: onMessage,
          icon: const Icon(
            Icons.chat_bubble,
            color: Color(0xFF4C8290),
            size: 34,
          ),
        ),
        if (canRate)
          IconButton(
            tooltip: 'Calificar docente',
            onPressed: onRate,
            icon: const Icon(
              Icons.star_rate,
              color: Color(0xFFFFCA55),
              size: 32,
            ),
          ),
      ],
    );
  }
}

class _Teacher {
  const _Teacher({
    required this.id,
    required this.name,
    required this.area,
    required this.imageUrl,
  });

  final String id;
  final String name;
  final String area;
  final String imageUrl;

  factory _Teacher.fromMap(Map<String, dynamic> map) {
    return _Teacher(
      id: (map['uid'] ?? '').toString(),
      name: (map['name'] ?? '').toString(),
      area: (map['roleLabel'] ?? 'Docente').toString(),
      imageUrl: (map['photoUrl'] ?? '').toString(),
    );
  }
}

class _TeacherDirectoryState extends StatelessWidget {
  const _TeacherDirectoryState({
    required this.icon,
    required this.title,
    required this.message,
    this.onRetry,
  });

  final IconData icon;
  final String title;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: AppColors.primary),
            const SizedBox(height: 14),
            Text(title, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 18),
              FilledButton(onPressed: onRetry, child: const Text('Reintentar')),
            ],
          ],
        ),
      ),
    );
  }
}
