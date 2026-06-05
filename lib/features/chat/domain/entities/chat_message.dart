import '../enums/chat_message_type.dart';

class ChatMessage {
  final String id;
  final String conversationId;
  final String senderId;
  final ChatMessageType type;
  final String? text;
  final String? mediaPath;
  final int? audioDurationMs;
  final DateTime createdAt;
  final bool isRead;

  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.type,
    this.text,
    this.mediaPath,
    this.audioDurationMs,
    required this.createdAt,
    this.isRead = false,
  });

  bool get isMine => senderId == ChatMessage.currentUserId;

  /// Utilisateur local (mock) — remplacé par l’API plus tard.
  static const String currentUserId = 'local-user';

  ChatMessage copyWith({bool? isRead}) {
    return ChatMessage(
      id: id,
      conversationId: conversationId,
      senderId: senderId,
      type: type,
      text: text,
      mediaPath: mediaPath,
      audioDurationMs: audioDurationMs,
      createdAt: createdAt,
      isRead: isRead ?? this.isRead,
    );
  }
}
