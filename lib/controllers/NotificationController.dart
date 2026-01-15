import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import '../screens/NotificationPage.dart'; // Pour NotificationItem et NotificationType

class NotificationController with ChangeNotifier {
  final GetStorage _storage = GetStorage();
  String _storageKey = 'user_notifications'; // Default key
  String? _currentUserId;
  
  List<NotificationItem> _notifications = [];
  List<NotificationItem> get notifications => _notifications;
  
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  NotificationController() {
    // Tenter de charger pour l'utilisateur courant s'il existe
    final user = _storage.read('user_key'); // StockageKeys.userKey
    if (user != null && user['id'] != null) {
      _currentUserId = user['id'].toString();
      _storageKey = 'user_notifications_$_currentUserId';
    }
    _loadNotifications();
  }

  void loadForUser(String userId) {
    _currentUserId = userId;
    _storageKey = 'user_notifications_$userId';
    _loadNotifications();
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
       final user = _storage.read('user_key');
       if (user != null && user['id'] != null) {
          _currentUserId = user['id'].toString();
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
