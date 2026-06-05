import 'package:flutter/material.dart';

import 'chat_scope.dart';
import 'domain/enums/call_type.dart';
import 'domain/entities/call_session.dart';
import 'presentation/pages/audio_call_page.dart';
import 'presentation/pages/chat_room_page.dart';
import 'presentation/pages/video_call_page.dart';

class ChatRoutes {
  ChatRoutes._();

  static Future<void> openRoom(BuildContext context, String conversationId) {
    return Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScope(
          child: ChatRoomPage(conversationId: conversationId),
        ),
      ),
    );
  }

  static Future<void> openCall(
    BuildContext context,
    CallSession session,
  ) {
    final page = session.type == CallType.video
        ? VideoCallPage(session: session)
        : AudioCallPage(session: session);
    return Navigator.push<void>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ChatScope(child: page),
      ),
    );
  }
}
