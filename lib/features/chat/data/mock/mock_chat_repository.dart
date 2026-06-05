import 'dart:async';

import '../../domain/entities/chat_conversation.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/chat_participant.dart';
import '../../domain/enums/chat_message_type.dart';
import '../../domain/repositories/chat_repository.dart';
import 'package:uuid/uuid.dart';

/// Données locales jusqu’à branchement API / Stream / Agora.
class MockChatRepository implements ChatRepository {
  MockChatRepository._();
  static final MockChatRepository instance = MockChatRepository._();

  final _uuid = const Uuid();
  final _conversationsCtrl = StreamController<List<ChatConversation>>.broadcast();
  final Map<String, StreamController<List<ChatMessage>>> _messageStreams = {};

  late final List<ChatConversation> _conversations;
  final Map<String, List<ChatMessage>> _messages = {};

  bool _initialized = false;

  void _ensureInit() {
    if (_initialized) return;
    _initialized = true;

    _conversations = [
      ChatConversation(
        id: 'conv-1',
        reservationId: 'res-1001',
        title: 'Appartement Gombe',
        subtitle: 'Réservation validée · Visite',
        peer: const ChatParticipant(
          id: 'peer-1',
          displayName: 'Jean Kabila',
        ),
        lastMessagePreview: 'À quelle heure pour la visite ?',
        lastMessageAt: DateTime.now().subtract(const Duration(hours: 2)),
        unreadCount: 2,
      ),
      ChatConversation(
        id: 'conv-2',
        reservationId: 'res-1002',
        title: 'Service plomberie',
        subtitle: 'Réservation validée · Intervention',
        peer: const ChatParticipant(
          id: 'peer-2',
          displayName: 'Plombier Pro Kin',
        ),
        lastMessagePreview: 'J’arrive dans 20 minutes.',
        lastMessageAt: DateTime.now().subtract(const Duration(days: 1)),
        unreadCount: 0,
      ),
    ];

    _messages['conv-1'] = [
      ChatMessage(
        id: 'm1',
        conversationId: 'conv-1',
        senderId: 'peer-1',
        type: ChatMessageType.text,
        text: 'Bonjour, la visite est toujours prévue ?',
        createdAt: DateTime.now().subtract(const Duration(hours: 3)),
      ),
      ChatMessage(
        id: 'm2',
        conversationId: 'conv-1',
        senderId: ChatMessage.currentUserId,
        type: ChatMessageType.text,
        text: 'Oui, je serai disponible demain.',
        createdAt: DateTime.now().subtract(const Duration(hours: 2, minutes: 45)),
      ),
      ChatMessage(
        id: 'm3',
        conversationId: 'conv-1',
        senderId: 'peer-1',
        type: ChatMessageType.text,
        text: 'À quelle heure pour la visite ?',
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
    ];

    _messages['conv-2'] = [
      ChatMessage(
        id: 'm4',
        conversationId: 'conv-2',
        senderId: 'peer-2',
        type: ChatMessageType.text,
        text: 'Bonjour, fuite réparée demain matin.',
        createdAt: DateTime.now().subtract(const Duration(days: 1, hours: 1)),
      ),
      ChatMessage(
        id: 'm5',
        conversationId: 'conv-2',
        senderId: ChatMessage.currentUserId,
        type: ChatMessageType.text,
        text: 'Parfait, merci.',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
      ChatMessage(
        id: 'm6',
        conversationId: 'conv-2',
        senderId: 'peer-2',
        type: ChatMessageType.text,
        text: 'J’arrive dans 20 minutes.',
        createdAt: DateTime.now().subtract(const Duration(hours: 20)),
      ),
    ];

    _emitConversations();
  }

  void _emitConversations() {
    if (!_conversationsCtrl.isClosed) {
      _conversationsCtrl.add(List.unmodifiable(_conversations));
    }
  }

  void _emitMessages(String conversationId) {
    final ctrl = _messageStreams[conversationId];
    if (ctrl != null && !ctrl.isClosed) {
      ctrl.add(List.unmodifiable(_messages[conversationId] ?? []));
    }
  }

  int _indexOfConversation(String id) =>
      _conversations.indexWhere((c) => c.id == id);

  void _updateConversationPreview(String conversationId, ChatMessage msg) {
    final i = _indexOfConversation(conversationId);
    if (i < 0) return;
    String preview;
    switch (msg.type) {
      case ChatMessageType.image:
        preview = '📷 Photo';
        break;
      case ChatMessageType.audio:
        preview = '🎤 Message vocal';
        break;
      case ChatMessageType.system:
        preview = msg.text ?? '';
        break;
      case ChatMessageType.text:
        preview = msg.text ?? '';
    }
    _conversations[i] = _conversations[i].copyWith(
      lastMessagePreview: preview,
      lastMessageAt: msg.createdAt,
    );
    _emitConversations();
  }

  @override
  Stream<List<ChatConversation>> watchConversations() {
    _ensureInit();
    return _conversationsCtrl.stream;
  }

  @override
  Future<List<ChatConversation>> getConversations() async {
    _ensureInit();
    return List.unmodifiable(_conversations);
  }

  @override
  Future<ChatConversation?> getConversation(String conversationId) async {
    _ensureInit();
    try {
      return _conversations.firstWhere((c) => c.id == conversationId);
    } catch (_) {
      return null;
    }
  }

  @override
  Stream<List<ChatMessage>> watchMessages(String conversationId) {
    _ensureInit();
    _messageStreams.putIfAbsent(
      conversationId,
      () => StreamController<List<ChatMessage>>.broadcast(),
    );
    _emitMessages(conversationId);
    return _messageStreams[conversationId]!.stream;
  }

  @override
  Future<List<ChatMessage>> getMessages(String conversationId) async {
    _ensureInit();
    return List.unmodifiable(_messages[conversationId] ?? []);
  }

  @override
  Future<ChatMessage> sendText(String conversationId, String text) async {
    _ensureInit();
    final msg = ChatMessage(
      id: _uuid.v4(),
      conversationId: conversationId,
      senderId: ChatMessage.currentUserId,
      type: ChatMessageType.text,
      text: text.trim(),
      createdAt: DateTime.now(),
    );
    _messages.putIfAbsent(conversationId, () => []).add(msg);
    _updateConversationPreview(conversationId, msg);
    _emitMessages(conversationId);
    return msg;
  }

  @override
  Future<ChatMessage> sendImage(String conversationId, String filePath) async {
    _ensureInit();
    final msg = ChatMessage(
      id: _uuid.v4(),
      conversationId: conversationId,
      senderId: ChatMessage.currentUserId,
      type: ChatMessageType.image,
      mediaPath: filePath,
      createdAt: DateTime.now(),
    );
    _messages.putIfAbsent(conversationId, () => []).add(msg);
    _updateConversationPreview(conversationId, msg);
    _emitMessages(conversationId);
    return msg;
  }

  @override
  Future<ChatMessage> sendAudio(
    String conversationId,
    String filePath,
    int durationMs,
  ) async {
    _ensureInit();
    final msg = ChatMessage(
      id: _uuid.v4(),
      conversationId: conversationId,
      senderId: ChatMessage.currentUserId,
      type: ChatMessageType.audio,
      mediaPath: filePath,
      audioDurationMs: durationMs,
      createdAt: DateTime.now(),
    );
    _messages.putIfAbsent(conversationId, () => []).add(msg);
    _updateConversationPreview(conversationId, msg);
    _emitMessages(conversationId);
    return msg;
  }

  @override
  Future<void> markAsRead(String conversationId) async {
    _ensureInit();
    final i = _indexOfConversation(conversationId);
    if (i >= 0) {
      _conversations[i] = _conversations[i].copyWith(unreadCount: 0);
      _emitConversations();
    }
  }

  @override
  Future<bool> canAccessConversation(String conversationId) async {
    _ensureInit();
    return _conversations.any((c) => c.id == conversationId && c.canChat);
  }
}
