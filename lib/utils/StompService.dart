import 'dart:async';
import 'dart:convert';
import 'package:casa/utils/Constantes.dart';
import 'package:casa/utils/Endpoints.dart';
import   'package:stomp_dart_client/stomp_dart_client.dart';

class StompService {
  static final StompService _instance = StompService._internal();
  factory StompService() => _instance;
  StompService._internal();

  StompClient? _stompClient;
  final _onMessageController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get messages => _onMessageController.stream;

  bool get IsConnected => _stompClient?.connected ?? false;

  void connect(String token) {
    if (_stompClient != null && _stompClient!.connected) return;

    // 1. Nettoyage radical de l'URL de base
    String rawBase = Constantes.activeServer.trim();
    String host = rawBase.replaceFirst(RegExp(r'https?://'), '').replaceAll(RegExp(r'/.*$'), '');
    String protocol = rawBase.startsWith('https') ? 'wss' : 'ws';
    
    // 2. Construction de l'URL WebSocket forcée vers le chemin versionné v1
    String wsUrl = "$protocol://$host/api/${Endpoints.version}/websocket";

    print("🔌 [StompService] Tentative de connexion WebSocket à: $wsUrl");

    _stompClient = StompClient(
      config: StompConfig(
        url: wsUrl,
        onConnect: _onConnect,
        onWebSocketError: (error) => print("❌ [StompService] WebSocket Error: $error"),
        stompConnectHeaders: {
          'Authorization': 'Bearer $token',
        },
        webSocketConnectHeaders: {
          'Authorization': 'Bearer $token',
        },
        onStompError: (frame) => print("❌ [StompService] STOMP Error: ${frame.body}"),
        onDisconnect: (frame) => print("🔌 [StompService] Déconnecté"),
        onWebSocketDone: () => print("🔌 [StompService] WebSocket fermé (Done)"),
      ),
    );

    // Désactivé temporairement pour éviter les boucles d'erreurs pendant les tests du backend
    // _stompClient!.activate(); AWAAAAAA
  }

  void _onConnect(StompFrame frame) {
    print("✅ [StompService] Connecté au serveur STOMP");
    
    // Souscription aux notifications globales (Commenté pour éviter les doublons si le backend envoie aux deux)
    /*
    _stompClient!.subscribe(
      destination: '/topic/notifications',
      callback: (frame) {
        if (frame.body != null) {
          _onMessageController.add(jsonDecode(frame.body!));
        }
      },
    );
    */

    // Souscription aux notifications privées
    _stompClient!.subscribe(
      destination: '/user/queue/notifications',
      callback: (frame) {
        if (frame.body != null) {
          print("📥 [StompService] Message privé reçu: ${frame.body}");
          _onMessageController.add(jsonDecode(frame.body!));
        }
      },
    );
  }

  void disconnect() {
    _stompClient?.deactivate();
    _stompClient = null;
    print("🔌 [StompService] Service désactivé");
  }

  void dispose() {
    _onMessageController.close();
  }
}