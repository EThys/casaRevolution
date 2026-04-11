import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:flutter/services.dart';
import '../screens/NotificationPage.dart'; // Pour NotificationItem et NotificationType
import '../utils/casa_payment_log.dart';
import '../utils/StompService.dart';
import '../utils/FancyNotification.dart' as fn;
import '../Apps/MonApllication.dart';
import '../utils/Routes.dart';
import '../utils/StockageKeys.dart';
import '../utils/ModernModal.dart';
import '../utils/NotificationBanner.dart';
import '../utils/realtime_refresh_hub.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import 'package:provider/provider.dart';
import 'AuthentificationCtrl.dart';

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

  /// Les messages arrivent sur `/user/queue/notifications` : le serveur (Spring) les a déjà
  /// routés vers la session du bon utilisateur. Filtrer ici sur `targetUserId` / `userId`
  /// dans le JSON provoquait des **faux négatifs** (ces champs désignent souvent un acteur
  /// métier — hôte, auteur — et non le destinataire réel du push).
  bool _shouldAcceptNotificationForCurrentUser(Map<String, dynamic> data) {
    return true;
  }

  void _emitRealtimeRefreshHints(
    NotificationType type,
    String category,
    String title,
    String body,
  ) {
    final blob =
        '${title.toLowerCase()} ${body.toLowerCase()} ${category.toLowerCase()}';
    if (type == NotificationType.appointment ||
        blob.contains('réservation') ||
        blob.contains('reservation') ||
        blob.contains('visite') ||
        blob.contains('booking')) {
      RealtimeRefreshHub.instance.emit(RealtimeRefreshHub.reservations);
    }
    if (type == NotificationType.serviceRequest ||
        type == NotificationType.serviceResponse ||
        type == NotificationType.serviceAccepted ||
        type == NotificationType.serviceCompleted ||
        blob.contains('sollicit') ||
        blob.contains('solicit') ||
        blob.contains('prestation') ||
        blob.contains('demande de service')) {
      RealtimeRefreshHub.instance.emit(RealtimeRefreshHub.serviceSolicitations);
    }
    if (type == NotificationType.payment ||
        blob.contains('paiement') ||
        blob.contains('payment') ||
        blob.contains('abonnement') ||
        blob.contains('subscription')) {
      RealtimeRefreshHub.instance.emit(RealtimeRefreshHub.payments);
    }
  }

  /// Chaque appareil = une session WebSocket + ce listener (état local).
  /// Le backend doit envoyer la même notif à **chaque** session du compte (ex. Spring `/user/queue/...`).
  /// Ici : pas de changement de format JSON — on lit `data['user']` pour certif / premium.
  void _initStompListener() {
    StompService().messages.listen((data) {
      CasaPaymentLog.logJson(
        'NotifCtrl/STOMP',
        'notification WebSocket complète (titre/message/user)',
        data,
      );
      CasaPaymentLog.log(
        'NotifCtrl/STOMP',
        'clés=${data.keys.toList()} user.isPremium=${data['user'] is Map ? (data['user'] as Map)['isPremium'] ?? (data['user'] as Map)['is_premium'] : 'n/a'}',
      );

      // Protection contre les doublons (2 secondes de fenêtre)
      String title = data['title']?.toString() ?? 'Notification';
      String body = (data['message'] ?? data['body'] ?? '').toString();

      print("🔔 [NotificationController] Détails: Title='$title', Body='$body', Type='${data['type']}'");
      
      // --- VÉRIFICATION DE SÉCURITÉ / ROUTAGE ---
      if (!_shouldAcceptNotificationForCurrentUser(data)) {
        return;
      }
      
      // --- INTERCEPTER ET DÉCORER LES NOTIFICATIONS DE CERTIFICATION ---
      final userData = data['user'];
      if (userData != null && userData is Map) {
         final dynamic isCertifiedRaw = userData['is_certified'] ?? userData['isCertified'] ?? userData['certified'];
         if (isCertifiedRaw != null) {
            final bool isCertified = isCertifiedRaw == true || isCertifiedRaw == 1 || isCertifiedRaw.toString().toLowerCase() == 'true';
            
            // Si pas de titre/message explicite, on en génère un beau
            if (title == 'Notification' || title.isEmpty) {
              title = isCertified ? "Compte Certifié" : "Compte Décertifié";
            }
            if (body.isEmpty) {
              body = isCertified 
                ? "Félicitations ! Votre compte est désormais certifié. Vous pouvez maintenant publier des annonces." 
                : "Attention : Votre compte n'est plus certifié. Certaines fonctionnalités sont limitées.";
            }
            // Forcer le type si c'est un changement de certification pour l'icône/couleur
            if (data['type'] == null) {
              data['type'] = isCertified ? 'success' : 'warning';
            }
         }
      }
      // ------------------------------------------------------------------

      // Déduplication : préférer un id serveur pour ne pas fusionner deux vraies notifs identiques.
      final String dedupeKey = [
        data['notificationId'],
        data['id'],
        data['reservationId'],
        data['sollicitationId'],
        data['solicitationId'],
      ].map((e) => e?.toString() ?? '').firstWhere((s) => s.isNotEmpty, orElse: () => '');
      final String fingerprint =
          dedupeKey.isNotEmpty ? 'id:$dedupeKey' : '$title|$body';

      final now = DateTime.now();
      if (_lastNotificationFingerprint == fingerprint &&
          _lastNotificationTime != null &&
          now.difference(_lastNotificationTime!).inSeconds < 2) {
        print("🚫 [NotificationController] Doublon ignoré: $fingerprint");
        return;
      }

      _lastNotificationFingerprint = fingerprint;
      _lastNotificationTime = now;

      String category = data['category']?.toString() ?? 'Système';
      final NotificationType itemType = _parseType(data['type']);

      // Réservations / visites : toujours bannière + son (ne pas traiter comme auto-confirmation).
      final blobEarly = '${title.toLowerCase()} ${body.toLowerCase()}';
      final titleLowerEarly = title.toLowerCase();
      final isReservationRelated = itemType == NotificationType.appointment ||
          data['reservationId'] != null ||
          data['reservation'] != null ||
          blobEarly.contains('réservation') ||
          blobEarly.contains('reservation') ||
          blobEarly.contains('visite') ||
          blobEarly.contains('rendez-vous') ||
          blobEarly.contains('booking');

      // Certification / décertification (ex. titre « CasaNayo certification », push compte) : bannière + son.
      final isCertificationRelated = (titleLowerEarly.contains('casanayo') &&
              titleLowerEarly.contains('certif')) ||
          titleLowerEarly.contains('certification') ||
          blobEarly.contains('compte certifié') ||
          blobEarly.contains('compte decertif') ||
          blobEarly.contains('compte décertifié') ||
          blobEarly.contains('décertif') ||
          blobEarly.contains('decertif') ||
          blobEarly.contains('decertification') ||
          blobEarly.contains('décertification') ||
          (blobEarly.contains('certifi') &&
              (blobEarly.contains('compte') || blobEarly.contains('identité')));

      // Auto-confirmation : actions que l’utilisateur vient de faire lui-même (ex. paiement) — pas résas ni certif.
      final bool isAutoConfirmation = !isReservationRelated &&
          !isCertificationRelated &&
          (body.toLowerCase().startsWith("vous avez") ||
              (title.toLowerCase().contains("succès") &&
                  !body.toLowerCase().contains("votre réservation")));

      if (isAutoConfirmation) {
        print("ℹ️ [NotificationController] Auto-confirmation détectée, feedback discret.");
      }

      if (!isAutoConfirmation) {
        // Feedback sonore et haptique amélioré pour le destinataire réel
        _playNotificationSound();
        _triggerVibration();
      }

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
      _emitRealtimeRefreshHints(itemType, category, title, body);

      // --- GESTION EN TEMPS RÉEL DE LA CERTIFICATION ---
      // Si la notification contient des infos sur l'utilisateur et son statut de certification
      try {
        final userData = data['user'];
        if (userData != null && userData is Map) {
          final dynamic isCertifiedRaw = userData['is_certified'] ?? userData['isCertified'] ?? userData['certified'];
          if (isCertifiedRaw != null) {
            final bool isCertified = isCertifiedRaw == true || isCertifiedRaw == 1 || isCertifiedRaw.toString().toLowerCase() == 'true';
            
            print("👤 [NotificationController] Changement de certification détecté via WebSocket: $isCertified");
            
            final context = MonApplication.navigatorKey.currentContext;
            if (context != null) {
              // Utiliser Provider pour mettre à jour AuthentificationCtrl
              try {
                final authCtrl = Provider.of<AuthentificationCtrl>(context, listen: false);
                authCtrl.updateCertificationStatus(isCertified);
              } catch (e) {
                print("⚠️ [NotificationController] Impossible de trouver AuthentificationCtrl via Provider: $e");
              }
            }
          }

          final dynamic isPremiumRaw =
              userData['isPremium'] ?? userData['is_premium'] ?? userData['premium'];
          if (isPremiumRaw != null) {
            final bool isPremium = isPremiumRaw == true ||
                isPremiumRaw == 1 ||
                isPremiumRaw.toString().toLowerCase() == 'true';
            print("👤 [NotificationController] Changement premium via WebSocket: $isPremium");
            final context = MonApplication.navigatorKey.currentContext;
            if (context != null) {
              try {
                final authCtrl = Provider.of<AuthentificationCtrl>(context, listen: false);
                authCtrl.updatePremiumStatus(isPremium);
              } catch (e) {
                print("⚠️ [NotificationController] updatePremiumStatus: $e");
              }
            }
          }
        }
      } catch (e) {
        print("⚠️ [NotificationController] Erreur lors du traitement de la certification temps réel: $e");
      }
      // --------------------------------------------------

      // Afficher une notification visuelle si possible
      final context = MonApplication.navigatorKey.currentContext;
      if (context != null) {
        final isDecertificationTone = blobEarly.contains('décertif') ||
            blobEarly.contains('decertif') ||
            blobEarly.contains('suspend') ||
            blobEarly.contains('plus certifié') ||
            blobEarly.contains("n'est plus certifié") ||
            blobEarly.contains('nest plus certifie');

        String bannerTitle = 'Nouvelle notification';
        if (isCertificationRelated) {
          bannerTitle = isDecertificationTone
              ? '⚠️ Certification CasaNayo'
              : '✅ Certification CasaNayo';
        } else if (newItem.type == NotificationType.message) {
          bannerTitle = '📧 Nouveau message';
        } else if (newItem.type == NotificationType.appointment || isReservationRelated) {
          bannerTitle = '📅 Réservation';
        } else if (newItem.type == NotificationType.payment) {
          bannerTitle = '💰 Paiement';
        } else if (newItem.type == NotificationType.security) {
          bannerTitle = '🔒 Sécurité';
        } else if (newItem.type == NotificationType.warning) {
          bannerTitle = '⚠️ Alerte';
        }

        final bannerBody = newItem.description.trim().isNotEmpty
            ? newItem.description
            : newItem.title;

        // Afficher la bannière seulement si ce n'est pas une auto-confirmation
        if (!isAutoConfirmation) {
          final IconData bannerIcon = isReservationRelated
              ? Icons.event_rounded
              : isCertificationRelated
                  ? (isDecertificationTone
                      ? Icons.gpp_maybe_rounded
                      : Icons.verified_user_rounded)
                  : _getIconForType(newItem.type);
          final Color bannerColor = isReservationRelated
              ? const Color(0xFF00897B)
              : isCertificationRelated
                  ? (isDecertificationTone
                      ? const Color(0xFFE65100)
                      : const Color(0xFF1565C0))
                  : _getColorForType(newItem.type);
          NotificationBanner.show(
            title: bannerTitle,
            message: bannerBody,
            icon: bannerIcon,
            color: bannerColor,
            onTap: () {
              _handleNotificationNavigation(data, notificationId: newItem.id);
            },
          );
        }
      }
      print("📢 [NotificationController] Notification affichée: ${newItem.title}");
    });
  }

  /// Même logique que la bannière STOMP ; [titleFallback] / [messageFallback] pour la liste notifications.
  void navigateFromNotificationPayload(
    Map<String, dynamic> data, {
    String? titleFallback,
    String? messageFallback,
    /// Évite d’empiler une nouvelle [NotificationsPage] quand on tape un item déjà dans la liste.
    bool openedFromInAppNotificationList = false,
  }) {
    final merged = Map<String, dynamic>.from(data);
    if (titleFallback != null &&
        titleFallback.isNotEmpty &&
        (merged['title'] == null || merged['title'].toString().isEmpty)) {
      merged['title'] = titleFallback;
    }
    if (messageFallback != null &&
        messageFallback.isNotEmpty &&
        (merged['message'] == null || merged['message'].toString().isEmpty) &&
        (merged['body'] == null || merged['body'].toString().isEmpty)) {
      merged['message'] = messageFallback;
    }

    final nav = MonApplication.navigatorKey.currentState;

    final propertyId = merged['propertyId'] ?? merged['property_id'];
    if (propertyId != null) {
      print("🚀 [NotificationController] Navigation vers la propriété $propertyId");
      nav?.pushNamed(
          Routes.detailPageRoute,
          arguments: {'propertyId': propertyId}
      );
      return;
    }

    final payTag = merged['tag']?.toString().toUpperCase() ?? '';
    if (payTag == 'SUBSCRIPTION') {
      final highlightId = merged['paymentId'] ??
          merged['payment_id'] ??
          merged['id'];
      print(
        '🚀 [NotificationController] Paiement abonnement confirmé → historique (highlight=$highlightId)',
      );
      nav?.pushNamed(
        Routes.paymentHistoryRoute,
        arguments: <String, dynamic>{
          if (highlightId != null) 'highlightPaymentId': highlightId,
        },
      );
      return;
    }

    final titleLower = merged['title']?.toString().toLowerCase() ?? '';
    final bodyLower = (merged['message'] ?? merged['body'])?.toString().toLowerCase() ?? '';
    final blob = '$titleLower $bodyLower';

    final looksServiceHost = (titleLower.contains('reçu') && titleLower.contains('intervention')) ||
        (titleLower.contains('demande') &&
            titleLower.contains('intervention') &&
            titleLower.contains('reçu')) ||
        (bodyLower.contains('votre service') &&
            (bodyLower.contains('client') || bodyLower.contains('intéress'))) ||
        (bodyLower.contains('souhaite') &&
            (bodyLower.contains('interven') || bodyLower.contains('intervenir')));

    var looksServiceClient = (titleLower.contains('accept') ||
            titleLower.contains('valid') ||
            titleLower.contains('refus')) &&
        (blob.contains('sollicit') ||
            blob.contains('demande') ||
            blob.contains('intervention') ||
            blob.contains('prestataire'));
    if (titleLower.contains('rendez-vous') &&
        (titleLower.contains('valid') || titleLower.contains('confirm'))) {
      looksServiceClient = false;
    }

    if (looksServiceHost) {
      print('🚀 [NotificationController] MyServices — onglet Demandes reçues (prestataire)');
      nav?.pushNamed(Routes.myServicesRoute, arguments: <String, dynamic>{'tab': 2});
      return;
    }
    if (looksServiceClient) {
      print('🚀 [NotificationController] MyServices — onglet Mes demandes (client)');
      nav?.pushNamed(Routes.myServicesRoute, arguments: <String, dynamic>{'tab': 1});
      return;
    }

    final tag = merged['tag']?.toString().toUpperCase() ?? '';
    final isDemandes = tag == 'DEMANDES' ||
        merged['reservationId'] != null ||
        titleLower.contains('réservation') ||
        titleLower.contains('reservation') ||
        titleLower.contains('rendez-vous') ||
        titleLower.contains('visite');

    /// Côté **hôte** (client a réservé / demande visite) → onglet « Réservations reçues ».
    /// Côté **client** (« votre … ») → « Mes réservations » (défaut).
    bool looksBookingHostSide() {
      final blob = '$titleLower $bodyLower';
      final votreGuest = (titleLower.contains('votre') ||
              bodyLower.contains('votre réservation') ||
              bodyLower.contains('votre demande') ||
              bodyLower.contains('votre visite') ||
              bodyLower.contains('votre rendez-vous')) &&
          (blob.contains('visite') ||
              blob.contains('réservation') ||
              blob.contains('reservation') ||
              blob.contains('rendez-vous'));
      if (votreGuest) return false;

      if (blob.contains('accueillir') &&
          (blob.contains('client') || blob.contains('visiteur'))) return true;
      if (blob.contains('prêt') && blob.contains('accueillir')) return true;
      if (titleLower.contains('nouvelle') &&
          (titleLower.contains('réservation') || titleLower.contains('reservation'))) {
        return true;
      }
      if (titleLower.contains('réservation reçue') ||
          titleLower.contains('reservation reçue') ||
          titleLower.contains('reservation recue')) {
        return true;
      }
      if (bodyLower.contains('souhaite') &&
          (bodyLower.contains('visiter') || bodyLower.contains('visite'))) {
        return true;
      }
      if (bodyLower.contains('demande') &&
          bodyLower.contains('visite') &&
          !bodyLower.contains('votre demande')) {
        return true;
      }
      return false;
    }

    if (isDemandes) {
      final hostTab = looksBookingHostSide();
      print(
        "🚀 [NotificationController] Navigation réservations — ${hostTab ? 'Réservations reçues' : 'Mes réservations'}",
      );
      nav?.pushNamed(
        Routes.bookingHistoryPageRoute,
        arguments: <String, dynamic>{'initialHostView': hostTab},
      );
      return;
    }

    if (openedFromInAppNotificationList) {
      print(
        '🚀 [NotificationController] Pas de navigation (liste notifications, cible générique).',
      );
      return;
    }
    nav?.pushNamed(Routes.notificationPageRoute);
  }

  void _handleNotificationNavigation(Map<String, dynamic> data, {String? notificationId}) {
    if (notificationId != null) {
      markAsRead(notificationId);
    }
    navigateFromNotificationPayload(data);
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
    if (t.contains('success') || t.contains('certif')) return NotificationType.serviceAccepted;
    if (t.contains('reserva') || t.contains('validation')) return NotificationType.appointment; 

    return NotificationType.system;
  }

  Color _getColorForType(NotificationType type) {
    switch (type) {
      case NotificationType.warning:
        return Colors.orange;
      case NotificationType.security:
        return Colors.red;
      case NotificationType.promotion:
        return Colors.purple;
      case NotificationType.message:
        return Colors.blue;
      case NotificationType.payment:
        return Color(0xFF2E7D32);
      case NotificationType.appointment:
        return Color(0xFF00897B);
      default:
        return Color(0xFF2196F3);
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
    final uid = _currentUserId ??
        _storage.read(StockageKeys.userKey)?['userId']?.toString();
    if (uid != null && uid.isNotEmpty) {
      _storage.remove('user_notifications_$uid');
    }
    _storage.remove('user_notifications');
    _currentUserId = null;
    _storageKey = 'user_notifications';
    _notifications = [];
    _lastNotificationFingerprint = null;
    _lastNotificationTime = null;
    StompService().disconnect();
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