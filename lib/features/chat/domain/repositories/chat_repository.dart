import '../entities/chat_conversation.dart';
import '../entities/chat_message.dart';
import '../enums/chat_message_type.dart';

/// Contrat d’accès aux conversations (implémentation API plus tard).
abstract class ChatRepository {
  Stream<List<ChatConversation>> watchConversations();

  Future<List<ChatConversation>> getConversations();

  Future<ChatConversation?> getConversation(String conversationId);

  Stream<List<ChatMessage>> watchMessages(String conversationId);

  Future<List<ChatMessage>> getMessages(String conversationId);

  Future<ChatMessage> sendText(String conversationId, String text);

  Future<ChatMessage> sendImage(String conversationId, String filePath);

  Future<ChatMessage> sendAudio(
    String conversationId,
    String filePath,
    int durationMs,
  );

  Future<void> markAsRead(String conversationId);

  /// Préparé pour l’API : accès réservation + abonnement.
  Future<bool> canAccessConversation(String conversationId);
}
