import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_roles.dart';
import '../../../core/di/providers.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../widgets/app_scaffold.dart';

class ForumScreen extends ConsumerStatefulWidget {
  const ForumScreen({super.key});

  @override
  ConsumerState<ForumScreen> createState() => _ForumScreenState();
}

class _ForumScreenState extends ConsumerState<ForumScreen> {
  late Stream<List<Map<String, dynamic>>> _topicsStream;

  @override
  void initState() {
    super.initState();
    _topicsStream = ref.read(laravelApiServiceProvider).watchForumTopics();
  }

  Future<void> _showQuestionDialog() async {
    List<Map<String, dynamic>> teachers;
    try {
      teachers = await ref.read(laravelApiServiceProvider).fetchTeachers();
    } catch (error) {
      if (!mounted) return;
      _showError('No se pudo cargar el listado de docentes: $error');
      return;
    }
    if (!mounted) return;
    if (teachers.isEmpty) {
      _showError(
        'No hay docentes activos. Crea o activa un usuario docente en Laravel antes de abrir el foro.',
      );
      return;
    }

    final titleCtrl = TextEditingController();
    final categoryCtrl = TextEditingController(text: 'General');
    var selectedTeacherId = (teachers.first['uid'] ?? '').toString();
    final result = await showDialog<(String, String, String)>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Nuevo foro'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Pregunta o tema',
                    prefixIcon: Icon(Icons.help_outline),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: categoryCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Categoría',
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedTeacherId,
                  decoration: const InputDecoration(
                    labelText: 'Docente asociado',
                    prefixIcon: Icon(Icons.school_outlined),
                  ),
                  items: teachers
                      .map(
                        (teacher) => DropdownMenuItem(
                          value: (teacher['uid'] ?? '').toString(),
                          child:
                              Text((teacher['name'] ?? 'Docente').toString()),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setDialogState(() => selectedTeacherId = value);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              onPressed: () {
                if (titleCtrl.text.trim().isEmpty ||
                    selectedTeacherId.isEmpty) {
                  return;
                }
                Navigator.pop(
                  context,
                  (
                    titleCtrl.text.trim(),
                    categoryCtrl.text.trim().isEmpty
                        ? 'General'
                        : categoryCtrl.text.trim(),
                    selectedTeacherId,
                  ),
                );
              },
              icon: const Icon(Icons.send_outlined),
              label: const Text('Publicar'),
            ),
          ],
        ),
      ),
    );
    titleCtrl.dispose();
    categoryCtrl.dispose();
    if (result == null) return;

    try {
      await ref.read(laravelApiServiceProvider).createForumTopic(
            title: result.$1,
            category: result.$2,
            teacherId: result.$3,
          );
      if (!mounted) return;
      setState(() {
        _topicsStream = ref.read(laravelApiServiceProvider).watchForumTopics();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foro creado y asociado al docente.')),
      );
    } catch (error) {
      if (mounted) _showError('No se pudo crear el foro: $error');
    }
  }

  Future<void> _showReplyDialog(String topicId) async {
    final ctrl = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Responder foro'),
        content: TextField(
          controller: ctrl,
          minLines: 3,
          maxLines: 6,
          decoration: const InputDecoration(
            labelText: 'Respuesta',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('Responder'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (text == null || text.isEmpty) return;

    try {
      await ref.read(laravelApiServiceProvider).replyForumTopic(
            topicId: topicId,
            text: text,
          );
      if (!mounted) return;
      setState(() {
        _topicsStream = ref.read(laravelApiServiceProvider).watchForumTopics();
      });
    } catch (error) {
      if (mounted) _showError('No se pudo guardar la respuesta: $error');
    }
  }

  void _contactTeacher(Map<String, dynamic> data) {
    final teacherId = (data['teacherId'] ?? '').toString();
    if (teacherId.isEmpty) return;
    context.push(
      Uri(
        path: '/docentes/chat',
        queryParameters: {
          'id': teacherId,
          'name': (data['teacherName'] ?? 'Docente').toString(),
          'area': 'Docente asociado al foro',
          'image': (data['teacherImage'] ?? '').toString(),
        },
      ).toString(),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authViewModelProvider).user;
    final canCreate = AppRoles.canUseForums(user?.role);

    return AppScaffold(
      title: 'Foros temáticos',
      showBack: true,
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              onPressed: _showQuestionDialog,
              icon: const Icon(Icons.add_comment_outlined),
              label: const Text('Abrir foro'),
            )
          : null,
      child: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _topicsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(
              child: Text('No se pudieron cargar los foros desde Laravel.'),
            );
          }
          final topics = snapshot.data ?? const [];
          return ListView.separated(
            itemCount: topics.isEmpty ? 2 : topics.length + 1,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              if (index == 0) {
                return SectionHeader(
                  title: AppRoles.isAdminTi(user?.role)
                      ? 'Gestión de foros y docentes'
                      : 'Consulta a docentes expertos',
                  subtitle: AppRoles.isAdminTi(user?.role)
                      ? 'Crea un foro y selecciona el docente responsable.'
                      : 'Abre un tema asociado a un docente y revisa sus respuestas.',
                  icon: Icons.forum_outlined,
                );
              }
              if (topics.isEmpty) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(18),
                    child: Text('Aún no hay foros publicados.'),
                  ),
                );
              }
              final topic = topics[index - 1];
              final assignedToUser =
                  (topic['teacherId'] ?? '').toString() == user?.uid;
              final canAnswer = AppRoles.isAdminTi(user?.role) ||
                  AppRoles.isDocenteAdmin(user?.role) ||
                  (AppRoles.isDocente(user?.role) && assignedToUser);
              return _ForumTopicCard(
                data: topic,
                canAnswer: canAnswer,
                onReply: () => _showReplyDialog((topic['id'] ?? '').toString()),
                onContactTeacher: () => _contactTeacher(topic),
              );
            },
          );
        },
      ),
    );
  }
}

class _ForumTopicCard extends StatelessWidget {
  const _ForumTopicCard({
    required this.data,
    required this.canAnswer,
    required this.onReply,
    required this.onContactTeacher,
  });

  final Map<String, dynamic> data;
  final bool canAnswer;
  final VoidCallback onReply;
  final VoidCallback onContactTeacher;

  @override
  Widget build(BuildContext context) {
    final replies = (data['replies'] as List?)
            ?.whereType<Map>()
            .map((row) =>
                row.map((key, value) => MapEntry(key.toString(), value)))
            .toList() ??
        const <Map<String, dynamic>>[];
    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.forum_outlined),
        title: Text((data['title'] ?? '').toString()),
        subtitle: Text(
          '${data['category'] ?? 'General'} • ${data['status'] ?? 'Pendiente'}\nDocente: ${data['teacherName'] ?? 'Sin asignar'}',
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        children: [
          if (replies.isEmpty)
            const Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: Text('Sin respuestas todavía.'),
              ),
            )
          else
            ...replies.map(
              (reply) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.school_outlined),
                title: Text((reply['teacherName'] ?? 'Docente').toString()),
                subtitle: Text((reply['text'] ?? '').toString()),
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (canAnswer)
                  FilledButton.icon(
                    onPressed: onReply,
                    icon: const Icon(Icons.rate_review_outlined),
                    label: const Text('Responder'),
                  ),
                OutlinedButton.icon(
                  onPressed: onContactTeacher,
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text('Contactar docente'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
