import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/providers.dart';
import '../../../data/models/teacher_chat_message_model.dart';
import '../../viewmodels/auth_viewmodel.dart';

class TeacherChatScreen extends ConsumerStatefulWidget {
  const TeacherChatScreen({
    super.key,
    required this.teacherId,
    required this.teacherName,
    required this.teacherArea,
    required this.teacherImageUrl,
  });

  final String teacherId;
  final String teacherName;
  final String teacherArea;
  final String teacherImageUrl;

  @override
  ConsumerState<TeacherChatScreen> createState() => _TeacherChatScreenState();
}

class _TeacherChatScreenState extends ConsumerState<TeacherChatScreen> {
  final _messageCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _isSending = false;
  String? _conversationKey;
  Stream<List<TeacherChatMessageModel>>? _messagesStream;

  @override
  void dispose() {
    _messageCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _messageCtrl.text.trim();
    if (text.isEmpty || _isSending) return;

    final user = ref.read(authViewModelProvider).user;
    if (user == null) {
      context.go('/login');
      return;
    }

    setState(() => _isSending = true);
    try {
      await ref.read(laravelApiServiceProvider).sendTeacherMessage(
            teacherId: widget.teacherId,
            teacherName: widget.teacherName,
            teacherArea: widget.teacherArea,
            text: text,
          );
      _messageCtrl.clear();
      _scrollToBottom();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo enviar el mensaje: $error')),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authViewModelProvider).user;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Inicia sesión para abrir el chat.')),
      );
    }

    final key = '${user.uid}_${widget.teacherId}';
    if (_conversationKey != key) {
      _conversationKey = key;
      _messagesStream =
          ref.read(laravelApiServiceProvider).watchTeacherMessages(
                teacherId: widget.teacherId,
                teacherName: widget.teacherName,
                teacherArea: widget.teacherArea,
              );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: IconButton(
          tooltip: 'Volver',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/docentes');
            }
          },
          icon: const Icon(Icons.arrow_back, color: Color(0xFF789CA5)),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            ClipOval(
              child: Image.network(
                widget.teacherImageUrl,
                width: 40,
                height: 40,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const CircleAvatar(
                  backgroundColor: Color(0xFFE6E4E4),
                  child: Icon(Icons.person, color: Color(0xFF4C8D93)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.teacherName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: const Color(0xFF2C3A3A),
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  Text(
                    widget.teacherArea,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF7A7A7A),
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<TeacherChatMessageModel>>(
              stream: _messagesStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return const _EmptyChatState(
                    icon: Icons.cloud_off_outlined,
                    title: 'No se pudo cargar el chat',
                    message:
                        'Revisa tu conexión con el servidor e intenta nuevamente.',
                  );
                }

                final messages = snapshot.data ?? const [];
                if (messages.isEmpty) {
                  return _EmptyChatState(
                    icon: Icons.chat_bubble_outline,
                    title: 'Escribe tu primer mensaje',
                    message:
                        'Tu conversación con ${widget.teacherName} quedará guardada y se actualizará en tiempo real.',
                  );
                }

                _scrollToBottom();
                return ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMe = message.senderId == user.uid;
                    return _MessageBubble(message: message, isMe: isMe);
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageCtrl,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      decoration: const InputDecoration(
                        hintText: 'Escribe un mensaje',
                        prefixIcon: Icon(Icons.chat_outlined),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton.filled(
                    tooltip: 'Enviar',
                    onPressed: _isSending ? null : _sendMessage,
                    icon: _isSending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isMe,
  });

  final TeacherChatMessageModel message;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 310),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFF4C8D93) : const Color(0xFFE6E4E4),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isMe ? Colors.white : const Color(0xFF2C3A3A),
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatTime(message.sentAt),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: isMe
                        ? Colors.white.withValues(alpha: 0.78)
                        : const Color(0xFF7A7A7A),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class _EmptyChatState extends StatelessWidget {
  const _EmptyChatState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 54, color: const Color(0xFF4C8D93)),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
