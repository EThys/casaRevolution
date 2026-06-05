import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/mock/mock_call_service.dart';
import 'data/mock/mock_chat_repository.dart';
import 'domain/repositories/chat_repository.dart';
import 'domain/services/call_service.dart';

/// Fournit les dépendances chat (mock aujourd’hui, API demain).
class ChatScope extends StatelessWidget {
  const ChatScope({
    super.key,
    required this.child,
    this.repository,
    this.callService,
  });

  final Widget child;
  final ChatRepository? repository;
  final CallService? callService;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ChatRepository>(
          create: (_) => repository ?? MockChatRepository.instance,
        ),
        Provider<CallService>(
          create: (_) => callService ?? MockCallService.instance,
        ),
      ],
      child: child,
    );
  }
}
