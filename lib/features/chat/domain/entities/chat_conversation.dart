import 'chat_participant.dart';

class ChatConversation {
  final String id;
  final String reservationId;
  final String title;
  final String subtitle;
  final ChatParticipant peer;
  final String? lastMessagePreview;
  final DateTime? lastMessageAt;
  final int unreadCount;
  final bool canChat;
  final bool canCall;

  const ChatConversation({
    required this.id,
    required this.reservationId,
    required this.title,
    required this.subtitle,
    required this.peer,
    this.lastMessagePreview,
    this.lastMessageAt,
    this.unreadCount = 0,
    this.canChat = true,
    this.canCall = true,
  });

  ChatConversation copyWith({
    String? lastMessagePreview,
    DateTime? lastMessageAt,
    int? unreadCount,
  }) {
    return ChatConversation(
      id: id,
      reservationId: reservationId,
      title: title,
      subtitle: subtitle,
      peer: peer,
      lastMessagePreview: lastMessagePreview ?? this.lastMessagePreview,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      unreadCount: unreadCount ?? this.unreadCount,
      canChat: canChat,
      canCall: canCall,
    );
  }
}
