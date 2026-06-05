import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../chat_routes.dart';
import '../../domain/enums/call_type.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../domain/services/call_service.dart';
import '../controllers/chat_room_controller.dart';
import '../widgets/chat_input_bar.dart';
import '../widgets/message_bubble.dart';

class ChatRoomPage extends StatefulWidget {
  const ChatRoomPage({super.key, required this.conversationId});

  final String conversationId;

  @override
  State<ChatRoomPage> createState() => _ChatRoomPageState();
}

class _ChatRoomPageState extends State<ChatRoomPage> {
  static const _primary = Color(0xFF1976D2);
  late final ChatRoomController _ctrl;
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _ctrl = ChatRoomController(
      context.read<ChatRepository>(),
      widget.conversationId,
    );
    _ctrl.init();
    _ctrl.addListener(_scrollToBottom);
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

  Future<void> _startCall(CallType type) async {
    final callService = context.read<CallService>();
    final session = await callService.startOutgoingCall(
      conversationId: widget.conversationId,
      peerName: _ctrl.peerName,
      type: type,
    );
    if (!mounted) return;
    await ChatRoutes.openCall(context, session);
  }

  @override
  void dispose() {
    _ctrl.removeListener(_scrollToBottom);
    _ctrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFF3F4),
      appBar: AppBar(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        title: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _ctrl.peerName,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                if (_ctrl.conversation != null)
                  Text(
                    _ctrl.conversation!.subtitle,
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
              ],
            );
          },
        ),
        actions: [
          IconButton(
            tooltip: 'Appel audio',
            onPressed: () => _startCall(CallType.audio),
            icon: const Icon(Icons.call_rounded),
          ),
          IconButton(
            tooltip: 'Appel vidéo',
            onPressed: () => _startCall(CallType.video),
            icon: const Icon(Icons.videocam_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: Colors.amber.shade50,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(
              'Mode démo — les messages sont stockés localement. L’API sera branchée plus tard.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Colors.amber.shade900),
            ),
          ),
          Expanded(
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (context, _) {
                if (_ctrl.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                return ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  itemCount: _ctrl.messages.length,
                  itemBuilder: (context, index) {
                    return MessageBubble(message: _ctrl.messages[index]);
                  },
                );
              },
            ),
          ),
          ChatInputBar(
            enabled: !_ctrl.isSending,
            onSendText: _ctrl.sendText,
            onSendImage: _ctrl.sendImage,
            onSendAudio: _ctrl.sendAudio,
          ),
        ],
      ),
    );
  }
}
