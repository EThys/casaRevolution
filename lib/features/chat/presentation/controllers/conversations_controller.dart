import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/entities/chat_conversation.dart';
import '../../domain/repositories/chat_repository.dart';

class ConversationsController extends ChangeNotifier {
  ConversationsController(this._repository);

  final ChatRepository _repository;
  StreamSubscription<List<ChatConversation>>? _sub;

  List<ChatConversation> conversations = [];
  bool isLoading = true;
  String? error;

  Future<void> init() async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      conversations = await _repository.getConversations();
      _sub?.cancel();
      _sub = _repository.watchConversations().listen((list) {
        conversations = list;
        notifyListeners();
      });
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
