import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/entities/chat_conversation.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/repositories/chat_repository.dart';

class ChatRoomController extends ChangeNotifier {
  ChatRoomController(this._repository, this.conversationId);

  final ChatRepository _repository;
  final String conversationId;

  StreamSubscription<List<ChatMessage>>? _sub;
  ChatConversation? conversation;
  List<ChatMessage> messages = [];
  bool isLoading = true;
  bool isSending = false;
  String? error;

  Future<void> init() async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      conversation = await _repository.getConversation(conversationId);
      messages = await _repository.getMessages(conversationId);
      await _repository.markAsRead(conversationId);
      _sub?.cancel();
      _sub = _repository.watchMessages(conversationId).listen((list) {
        messages = list;
        notifyListeners();
      });
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> sendText(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || isSending) return;
    isSending = true;
    notifyListeners();
    try {
      await _repository.sendText(conversationId, trimmed);
    } catch (e) {
      error = e.toString();
    } finally {
      isSending = false;
      notifyListeners();
    }
  }

  Future<void> sendImage(String path) async {
    if (isSending) return;
    isSending = true;
    notifyListeners();
    try {
      await _repository.sendImage(conversationId, path);
    } catch (e) {
      error = e.toString();
    } finally {
      isSending = false;
      notifyListeners();
    }
  }

  Future<void> sendAudio(String path, int durationMs) async {
    if (isSending) return;
    isSending = true;
    notifyListeners();
    try {
      await _repository.sendAudio(conversationId, path, durationMs);
    } catch (e) {
      error = e.toString();
    } finally {
      isSending = false;
      notifyListeners();
    }
  }

  String get peerName => conversation?.peer.displayName ?? 'Contact';

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
