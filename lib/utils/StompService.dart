import 'dart:async';
import 'dart:convert';

import 'package:casa/utils/casa_payment_log.dart';
import 'package:casa/utils/Constantes.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart'
    show StompBadStateException, StompClient, StompConfig, StompFrame;

class StompService {
  static final StompService _instance = StompService._internal();
  factory StompService() => _instance;
  StompService._internal();

  /// File Spring pour les notifs utilisateur — filtre Logcat : `CasaPay` ou `QUEUE`.
  static const String userNotificationsDestination = '/user/queue/notifications';

  static int _queueMessageIndex = 0;

  StompClient? _stompClient;
  String? _currentToken;
  final _onMessageController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get messages => _onMessageController.stream;

  bool get IsConnected => _stompClient?.connected ?? false;

  /// Pour les logs : état sans exposer le token.
  void logDiagnostics() {
    CasaPaymentLog.log(
      'STOMP',
      'diagnostic: connected=${_stompClient?.connected} client=${_stompClient != null} '
      'tokenLen=${_currentToken?.length ?? 0} subscription=$userNotificationsDestination',
    );
  }

  void connect(String token) {
    // Si on est déjà connecté avec LE MÊME token, on ne fait rien
    if (_stompClient != null && _stompClient!.connected && _currentToken == token) {
      print("🔌 [StompService] Déjà connecté avec ce token, skip.");
      return;
    }

    // Si on est connecté avec un token DIFFÉRENT, on force la déconnexion d'abord
    if (_stompClient != null && _currentToken != token) {
      print("🔌 [StompService] Changement de token détecté, reconnexion forcée...");
      disconnect();
    }

    // Client laissé dans un état incohérent (ex. après deactivate) : nettoyer
    if (_stompClient != null && !_stompClient!.isActive) {
      print("🔌 [StompService] Client STOMP inactif, nettoyage avant reconnexion...");
      disconnect();
    }

    // **Critique** : ne pas créer un 2ᵉ StompClient tant que le 1ᵉʳ n’a pas fini.
    // Sinon le `onConnect` du vieux client peut s’exécuter après remplacement de
    // `_stompClient` → `subscribe()` part sur le mauvais handler / socket déjà fermée
    // → StompBadStateException dans _transmit.
    if (_stompClient != null &&
        !_stompClient!.connected &&
        _currentToken == token &&
        _stompClient!.isActive) {
      print("🔌 [StompService] Connexion STOMP déjà en cours pour ce token, skip.");
      return;
    }

    _currentToken = token;

    final wsUrl = Constantes.webSocketUrl;

    print("🔌 [StompService] Connexion STOMP → $wsUrl (queue ${userNotificationsDestination})");
    CasaPaymentLog.log(
      'STOMP',
      'connect() tokenLen=${token.length} connected=${_stompClient?.connected ?? false}',
    );

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
        reconnectDelay: const Duration(seconds: 5),
        heartbeatIncoming: const Duration(seconds: 30),
        heartbeatOutgoing: const Duration(seconds: 30),
      ),
    );

    _stompClient!.activate();
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
    print("📡 [StompService] Souscription à $userNotificationsDestination...");
    CasaPaymentLog.log(
      'STOMP/QUEUE',
      'ABONNEMENT souscrit à la queue $userNotificationsDestination (logs chaque message ci‑dessous)',
    );
    try {
      _stompClient!.subscribe(
        destination: userNotificationsDestination,
        callback: (frame) {
          if (frame.body != null) {
            _queueMessageIndex++;
            final n = _queueMessageIndex;
            final len = frame.body!.length;
            // Ligne très visible sur téléphone (Logcat : filtre CasaPay ou QUEUE)
            print(
              '🔔 [CasaPay][QUEUE][$userNotificationsDestination] MESSAGE #$n — $len caractères',
            );
            CasaPaymentLog.log(
              'STOMP/QUEUE',
              '>>> MESSAGE #$n destination=$userNotificationsDestination bodyLength=$len',
            );
            if (frame.headers.isNotEmpty) {
              CasaPaymentLog.logJson('STOMP/QUEUE', 'headers STOMP #$n', frame.headers);
            }
            try {
              final decoded = jsonDecode(frame.body!);
              CasaPaymentLog.logJson(
                'STOMP/QUEUE',
                '$userNotificationsDestination — JSON décodé (#$n)',
                decoded,
              );
              if (decoded is Map) {
                _onMessageController.add(Map<String, dynamic>.from(decoded as Map));
              } else {
                CasaPaymentLog.log('STOMP', '⚠️ enveloppe non-Map, wrap __raw (${decoded.runtimeType})');
                _onMessageController.add(<String, dynamic>{'__raw': decoded});
              }
            } catch (e) {
              print("❌ [StompService] Erreur décodage message: $e");
              CasaPaymentLog.log('STOMP', 'corps non JSON: ${frame.body!.substring(0, frame.body!.length > 200 ? 200 : frame.body!.length)}…');
            }
          }
        },
      );
    } on StompBadStateException catch (e) {
      print(
        "⚠️ [StompService] SUBSCRIBE ignoré (socket / client obsolète — souvent double connect()): $e",
      );
      CasaPaymentLog.log('STOMP', 'subscribe StompBadStateException: $e');
    }
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