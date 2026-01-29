import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:flutter/services.dart';
import '../screens/NotificationPage.dart'; // Pour NotificationItem et NotificationType
import '../utils/StompService.dart';
import '../utils/FancyNotification.dart' as fn;
import '../Apps/MonApllication.dart';
import '../utils/Routes.dart';
import '../utils/StockageKeys.dart';
import '../utils/ModernModal.dart';
import '../utils/NotificationBanner.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';

class NotificationController with ChangeNotifier {
  static final NotificationController _instance = NotificationController._internal();
  factory NotificationController() => _instance;
  
  final GetStorage _storage = GetStorage();
  String _storageKey = 'user_notifications'; // Default key
  String? _currentUserId;
  
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _hasVibrator = false;
  
  // Pour éviter les doublons
  String? _lastNotificationFingerprint;
  DateTime? _lastNotificationTime;
  
  List<NotificationItem> _notifications = [];
  List<NotificationItem> get notifications => _notifications;
  
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  NotificationController._internal() {
    // Tenter de charger pour l'utilisateur courant s'il existe
    final user = _storage.read(StockageKeys.userKey);
    if (user != null && user['userId'] != null) {
      _currentUserId = user['userId'].toString();
      _storageKey = 'user_notifications_$_currentUserId';
    }
    _checkVibrator();
    _loadNotifications();
    _initStompListener();
    
    // Tenter de se connecter automatiquement si on a déjà un token
    final token = _storage.read(StockageKeys.tokenKey);
    if (token != null) {
      print("🔌 [NotificationController] Auto-connexion WebSocket au démarrage...");
      StompService().connect(token);
    }
  }

  Future<void> _checkVibrator() async {
    _hasVibrator = await Vibration.hasVibrator() ?? false;
  }

  Future<void> _playNotificationSound() async {
    try {
      print("🎵 [NotificationController] Tentative de lecture du son: sounds/notification.wav");
      await _audioPlayer.stop(); // Arrêter toute lecture en cours pour permettre la répétition
      await _audioPlayer.setVolume(1.0);
      await _audioPlayer.play(AssetSource('sounds/notification.wav'), mode: PlayerMode.lowLatency);
    } catch (e) {
      print("⚠️ [NotificationController] Erreur lecture son: $e");
    }
  }

  Future<void> _triggerVibration() async {
    try {
      if (_hasVibrator) {
        print("📳 [NotificationController] Vibration personnalisée lancée");
        Vibration.vibrate(pattern: [0, 500, 100, 500], amplitude: 255);
      } else {
        print("📳 [NotificationController] Fallback vibration HapticFeedback");
        HapticFeedback.heavyImpact();
        await Future.delayed(Duration(milliseconds: 100));
        HapticFeedback.heavyImpact();
      }
    } catch (e) {
      print("⚠️ [NotificationController] Erreur vibration: $e");
      HapticFeedback.vibrate();
    }
  }

  void _initStompListener() {
    StompService().messages.listen((data) {
      print("🔔 [NotificationController] Message reçu via WebSocket: $data");
      
      // Protection contre les doublons (2 secondes de fenêtre)
      final String title = data['title']?.toString() ?? 'Notification';
      final String body = (data['message'] ?? data['body'] ?? '').toString();
      final String fingerprint = "$title-$body";
      
      final now = DateTime.now();
      if (_lastNotificationFingerprint == fingerprint && 
          _lastNotificationTime != null && 
          now.difference(_lastNotificationTime!).inSeconds < 2) {
        print("🚫 [NotificationController] Doublon ignoré: $fingerprint");
        return;
      }
      
      _lastNotificationFingerprint = fingerprint;
      _lastNotificationTime = now;

      // Filtrage : Ne pas jouer de son ni afficher de bannière si c'est une auto-confirmation (ex: l'hôte qui valide)
      // En général, ces messages commencent par "Vous avez" ou "Succès"
      final bool isAutoConfirmation = body.toLowerCase().startsWith("vous avez") || 
                                     title.toLowerCase().contains("succès");

      if (!isAutoConfirmation) {
        // Feedback sonore et haptique amélioré pour le destinataire réel
        _playNotificationSound();
        _triggerVibration();
      }

      String category = data['category']?.toString() ?? 'Système';
      final NotificationType itemType = _parseType(data['type']);
      
      // Forcer le tag "Demandes" pour les réservations
      if (itemType == NotificationType.appointment) {
        category = 'Demandes';
      }

      final newItem = NotificationItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        description: body,
        timestamp: now,
        icon: _getIconForType(itemType),
        iconColor: _getColorForType(itemType),
        isRead: false,
        category: category,
        type: itemType,
        data: data,
      );

      addNotification(newItem);

      // Afficher une notification visuelle si possible
      final context = MonApplication.navigatorKey.currentContext;
      if (context != null) {
        String displayTitle = newItem.title;
        if (newItem.type == NotificationType.message) displayTitle = "📧 Nouveau Message";
        if (newItem.type == NotificationType.appointment) displayTitle = "📅 Réservation";
        if (newItem.type == NotificationType.payment) displayTitle = "💰 Paiement";

        // Afficher la bannière seulement si ce n'est pas une auto-confirmation
        if (!isAutoConfirmation) {
          NotificationBanner.show(
            title: "Nouvelle notification",
            message: newItem.description,
            icon: _getIconForType(newItem.type),
            color: _getColorForType(newItem.type),
            onTap: () {
              _handleNotificationNavigation(data, notificationId: newItem.id);
            },
          );
        }
      }
      print("📢 [NotificationController] Notification affichée: ${newItem.title}");
    });
  }

  void _handleNotificationNavigation(Map<String, dynamic> data, {String? notificationId}) {
    if (notificationId != null) {
      markAsRead(notificationId);
    }

    final propertyId = data['propertyId'] ?? data['property_id'];
    if (propertyId != null) {
      print("🚀 [NotificationController] Navigation vers la propriété $propertyId");
      MonApplication.navigatorKey.currentState?.pushNamed(
        Routes.detailPageRoute, 
        arguments: {'propertyId': propertyId}
      );
    } else {
      MonApplication.navigatorKey.currentState?.pushNamed(Routes.notificationPageRoute);
    }
  }

  fn.NotificationType _getFancyNotificationType(NotificationType modelType) {
    switch (modelType) {
      case NotificationType.warning:
        return fn.NotificationType.warning;
      case NotificationType.security:
        return fn.NotificationType.error;
      case NotificationType.promotion:
        return fn.NotificationType.premium;
      case NotificationType.message:
      case NotificationType.appointment:
      case NotificationType.serviceRequest:
      case NotificationType.serviceResponse:
      case NotificationType.serviceAccepted:
      case NotificationType.serviceCompleted:
        return fn.NotificationType.info;
      default:
        return fn.NotificationType.info;
    }
  }

  // Suppression de l'ancienne méthode erronée

  NotificationType _parseType(String? type) {
    if (type == null) return NotificationType.system;
    final t = type.toLowerCase();
    
    if (t.contains('message') || t.contains('chat')) return NotificationType.message;
    if (t.contains('appoint') || t.contains('rdv')) return NotificationType.appointment;
    if (t.contains('pay') || t.contains('argent')) return NotificationType.payment;
    if (t.contains('secu') || t.contains('alert')) return NotificationType.security;
    if (t.contains('promo') || t.contains('offre')) return NotificationType.promotion;
    if (t.contains('request') || t.contains('demande')) return NotificationType.serviceRequest;
    if (t.contains('response') || t.contains('reponse')) return NotificationType.serviceResponse;
    if (t.contains('accept')) return NotificationType.serviceAccepted;
    if (t.contains('complete') || t.contains('fini')) return NotificationType.serviceCompleted;
    if (t.contains('warn') || t.contains('attention')) return NotificationType.warning;
    if (t.contains('reserva') || t.contains('validation')) return NotificationType.appointment; // Mapper réservation sur rendez-vous pour l'icône
    
    return NotificationType.system;
  }

  Color _getColorForType(NotificationType type) {
    switch (type) {
      case NotificationType.warning: return Colors.orange;
      case NotificationType.security: return Colors.red;
      case NotificationType.promotion: return Colors.purple;
      case NotificationType.message: return Colors.blue;
      default: return Color(0xFF2196F3);
    }
  }

  void loadForUser(String userId) {
    _currentUserId = userId;
    _storageKey = 'user_notifications_$userId';
    _loadNotifications();
    
    // Connect Stomp if token available
    final token = _storage.read(StockageKeys.tokenKey);
    if (token != null) {
      print("🔌 [NotificationController] Token trouvé, démarrage de StompService...");
      StompService().connect(token);
    } else {
      print("⚠️ [NotificationController] Aucun token found dans le stockage (${StockageKeys.tokenKey}), StompService ne peut pas se connecter.");
    }
  }

  void clearForLogout() {
    _currentUserId = null;
    _notifications = [];
    notifyListeners();
  }

  void _loadNotifications() {
    // Si aucun utilisateur n'est identifié, on ne charge rien ou une liste vide
    if (_currentUserId == null) {
      // Tenter de récupérer depuis le stockage si pas déjà fait
       final user = _storage.read(StockageKeys.userKey);
       if (user != null && user['userId'] != null) {
          _currentUserId = user['userId'].toString();
          _storageKey = 'user_notifications_$_currentUserId';
       }
    }

    final List<dynamic>? storedList = _storage.read(_storageKey);
    if (storedList != null) {
      _notifications = storedList.map((item) => _fromJson(item)).toList();
      // Trier par date (plus récent en premier)
      _notifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    } else {
      _notifications = [];
    }
    notifyListeners();
  }

  void _saveNotifications() {
    if (_currentUserId == null) return; // Ne pas sauvegarder si pas d'user
    final List<Map<String, dynamic>> listToStore = 
        _notifications.map((item) => _toJson(item)).toList();
    _storage.write(_storageKey, listToStore);
  }

  void addNotification(NotificationItem item) {
    _notifications.insert(0, item); // Ajouter au début
    _saveNotifications();
    notifyListeners();
  }

  void markAsRead(String id) {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1) {
      _notifications[index].isRead = true;
      _saveNotifications();
      notifyListeners();
    }
  }

  void markAllAsRead() {
    for (var n in _notifications) {
      n.isRead = true;
    }
    _saveNotifications();
    notifyListeners();
  }

  void deleteNotification(String id) {
    _notifications.removeWhere((n) => n.id == id);
    _saveNotifications();
    notifyListeners();
  }

  // Helpers de sérialisation
  Map<String, dynamic> _toJson(NotificationItem item) {
    return {
      'id': item.id,
      'title': item.title,
      'description': item.description,
      'timestamp': item.timestamp.toIso8601String(),
      'iconCode': item.icon.codePoint,
      'iconFontFamily': item.icon.fontFamily,
      'iconColorValue': item.iconColor.value,
      'isRead': item.isRead,
      'category': item.category,
      'typeIndex': item.type.index,
      'data': item.data,
    };
  }

  NotificationItem _fromJson(Map<String, dynamic> json) {
    // Fallback pour ancien format avec 'time' string ou sans timestamp
    DateTime ts;
    if (json['timestamp'] != null) {
      ts = DateTime.parse(json['timestamp']);
    } else {
      ts = DateTime.now(); // Défaut
    }

    return NotificationItem(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      timestamp: ts,
      icon: _getIconForType(NotificationType.values[json['typeIndex'] ?? 5]),
      iconColor: Color(json['iconColorValue']),
      isRead: json['isRead'],
      category: json['category'],
      type: NotificationType.values[json['typeIndex'] ?? 5],
      data: json['data'],
    );
  }

  IconData _getIconForType(NotificationType type) {
    switch (type) {
      case NotificationType.message:
        return Icons.message_rounded;
      case NotificationType.appointment:
        return Icons.event_rounded;
      case NotificationType.payment:
        return Icons.payment_rounded;
      case NotificationType.security:
        return Icons.security_rounded;
      case NotificationType.promotion:
        return Icons.local_offer_rounded;
      case NotificationType.serviceRequest:
        return Icons.build_circle_rounded;
      case NotificationType.serviceResponse:
        return Icons.reply_rounded;
      case NotificationType.serviceAccepted:
        return Icons.check_circle_rounded;
      case NotificationType.serviceCompleted:
        return Icons.task_alt_rounded;
      case NotificationType.warning:
        return Icons.warning_rounded;
      case NotificationType.system:
      default:
        return Icons.notifications_rounded;
    }
  }
}
