import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/providers.dart';
import '../../../data/models/business_conversation_model.dart';
import '../../../data/models/teacher_chat_message_model.dart';
import '../../viewmodels/auth_viewmodel.dart';

class BusinessInboxScreen extends ConsumerWidget {
  const BusinessInboxScreen({super.key, this.businessId});

  final String? businessId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mensajes de micronegocios')),
      body: FutureBuilder<List<BusinessConversationModel>>(
        future:
            ref.read(laravelApiServiceProvider).fetchBusinessConversations(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(
                child: Text('No fue posible cargar los mensajes.'));
          }
          final conversations = (snapshot.data ?? const [])
              .where(
                  (item) => businessId == null || item.businessId == businessId)
              .toList();
          if (conversations.isEmpty) {
            return const Center(
                child: Text('No tienes conversaciones de micronegocios.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: conversations.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, index) {
              final item = conversations[index];
              final counterpart =
                  item.isOwner ? item.customerName : item.businessName;
              return ListTile(
                leading: CircleAvatar(
                  child: Text(
                      counterpart.isEmpty ? '?' : counterpart[0].toUpperCase()),
                ),
                title: Text(counterpart),
                subtitle: Text(
                  item.lastMessage.isEmpty
                      ? item.businessName
                      : item.lastMessage,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: item.unreadCount > 0
                    ? Badge(label: Text('${item.unreadCount}'))
                    : const Icon(Icons.chevron_right),
                onTap: () => context.push(Uri(
                  path: '/micronegocios/chat/${item.businessId}',
                  queryParameters: {
                    'name': item.businessName,
                    if (item.isOwner) 'customer': item.customerId,
                    if (item.isOwner) 'customerName': item.customerName,
                  },
                ).toString()),
              );
            },
          );
        },
      ),
    );
  }
}

class BusinessChatScreen extends ConsumerStatefulWidget {
  const BusinessChatScreen({
    super.key,
    required this.businessId,
    required this.businessName,
    this.customerId,
    this.customerName,
  });

  final String businessId;
  final String businessName;
  final String? customerId;
  final String? customerName;

  @override
  ConsumerState<BusinessChatScreen> createState() => _BusinessChatScreenState();
}

class _BusinessChatScreenState extends ConsumerState<BusinessChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  late final Stream<List<TeacherChatMessageModel>> _messages;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _messages = ref.read(laravelApiServiceProvider).watchBusinessMessages(
          businessId: widget.businessId,
          customerId: widget.customerId,
        );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ref.read(laravelApiServiceProvider).sendBusinessMessage(
            businessId: widget.businessId,
            customerId: widget.customerId,
            text: text,
          );
      _messageController.clear();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo enviar el mensaje: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(authViewModelProvider).user?.uid ?? '';
    final title = widget.customerName?.isNotEmpty == true
        ? widget.customerName!
        : widget.businessName;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<TeacherChatMessageModel>>(
              stream: _messages,
              builder: (context, snapshot) {
                if (!snapshot.hasData && !snapshot.hasError) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Center(
                      child: Text('No fue posible cargar el chat.'));
                }
                final messages = snapshot.data ?? const [];
                if (messages.isEmpty) {
                  return const Center(
                      child: Text('Escribe el primer mensaje.'));
                }
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final mine = message.senderId == userId;
                    return Align(
                      alignment:
                          mine ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 310),
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: mine
                              ? const Color(0xFF4C8D93)
                              : const Color(0xFFE9EEEE),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(message.senderName,
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color:
                                        mine ? Colors.white : Colors.black87)),
                            const SizedBox(height: 4),
                            Text(message.text,
                                style: TextStyle(
                                    color:
                                        mine ? Colors.white : Colors.black87)),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      maxLines: 4,
                      minLines: 1,
                      onSubmitted: (_) => _send(),
                      decoration:
                          const InputDecoration(hintText: 'Escribe un mensaje'),
                    ),
                  ),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
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
