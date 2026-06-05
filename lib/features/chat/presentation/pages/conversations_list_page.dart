import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../chat_routes.dart';
import '../../domain/entities/chat_conversation.dart';
import '../../domain/repositories/chat_repository.dart';
import '../controllers/conversations_controller.dart';

class ConversationsListPage extends StatefulWidget {
  const ConversationsListPage({super.key});

  @override
  State<ConversationsListPage> createState() => _ConversationsListPageState();
}

class _ConversationsListPageState extends State<ConversationsListPage> {
  static const _primary = Color(0xFF1976D2);
  static const _darkBlue = Color(0xFF0D47A1);

  late final ConversationsController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = ConversationsController(context.read<ChatRepository>());
    _ctrl.init();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F9),
      appBar: AppBar(
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_primary, _darkBlue],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: Text(
          'Messages',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Démo',
                  style: TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
            ),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          if (_ctrl.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_ctrl.error != null) {
            return Center(child: Text(_ctrl.error!));
          }
          if (_ctrl.conversations.isEmpty) {
            return const Center(
              child: Text('Aucune conversation pour le moment.'),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: _ctrl.conversations.length,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              indent: 72,
              color: Colors.grey.shade200,
            ),
            itemBuilder: (context, index) {
              final c = _ctrl.conversations[index];
              return _ConversationTile(
                conversation: c,
                onTap: () => ChatRoutes.openRoom(context, c.id),
              );
            },
          );
        },
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.conversation,
    required this.onTap,
  });

  final ChatConversation conversation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final time = conversation.lastMessageAt;
    final timeStr = time != null
        ? DateFormat('dd/MM HH:mm').format(time)
        : '';

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: const Color(0xFF1976D2).withOpacity(0.15),
        child: Text(
          conversation.peer.displayName.isNotEmpty
              ? conversation.peer.displayName[0].toUpperCase()
              : '?',
          style: const TextStyle(
            color: Color(0xFF1976D2),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(
        conversation.title,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        '${conversation.subtitle}\n${conversation.lastMessagePreview ?? ''}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(timeStr, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          if (conversation.unreadCount > 0) ...[
            const SizedBox(height: 6),
            CircleAvatar(
              radius: 10,
              backgroundColor: const Color(0xFF1976D2),
              child: Text(
                '${conversation.unreadCount}',
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
            ),
          ],
        ],
      ),
      isThreeLine: true,
    );
  }
}
