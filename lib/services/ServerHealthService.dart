import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:casa/controllers/NotificationController.dart';
import 'package:casa/screens/NotificationPage.dart';
import 'package:casa/utils/FancyNotification.dart' as fancy;
import 'package:casa/services/ConnectivityService.dart';
import 'package:get_storage/get_storage.dart';
import 'package:casa/utils/Constantes.dart';

class ServerHealthService {
  static final ServerHealthService _instance = ServerHealthService._internal();
  factory ServerHealthService() => _instance;
  
  final GetStorage _storage = GetStorage();
  final ConnectivityService _connectivityService = ConnectivityService();

  // URLs des serveurs
  final String _primaryUrl = "https://server.casanayo.com";
  final String _backupUrl = "http://91.99.168.226:8083/";
  
  // État des serveurs
  String _activeServerUrl = "https://server.casanayo.com";
  bool _isPrimaryDown = false;
  bool _isBackupDown = false;
  bool _isUsingBackup = false;
  bool _bothServersNotified = false; // Pour éviter spam si les deux sont down

  // Storage keys
  static const String _keyPrimaryDown = 'server_primary_down_state';
  static const String _keyBackupDown = 'server_backup_down_state';
  static const String _keyActiveUrl = 'server_active_url';
  static const String _keyUsingBackup = 'server_using_backup';
  static const String _keyBothNotified = 'server_both_notified';

  ServerHealthService._internal() {
    // Restaurer l'état précédent
    _isPrimaryDown = _storage.read(_keyPrimaryDown) ?? false;
    _isBackupDown = _storage.read(_keyBackupDown) ?? false;
    _activeServerUrl = _storage.read(_keyActiveUrl) ?? _primaryUrl;
    _isUsingBackup = _storage.read(_keyUsingBackup) ?? false;
    _bothServersNotified = _storage.read(_keyBothNotified) ?? false;
    
    // Restaurer l'URL active dans Constantes
    Constantes.setActiveServer(_activeServerUrl);
    
    print("🛡️ [ServerHealth] État restauré:");
    print("  Primary: ${_isPrimaryDown ? 'DOWN' : 'UP'}");
    print("  Backup: ${_isBackupDown ? 'DOWN' : 'UP'}");
    print("  Active: $_activeServerUrl");
    print("  Using Backup: $_isUsingBackup");
  }

  Timer? _timer;
  
  // Compteurs pour confirmation
  int _primaryFailCount = 0;
  int _primarySuccessCount = 0;
  int _backupFailCount = 0;
  int _backupSuccessCount = 0;

  // Seuils
  static const int _thresholdDown = 2; // 2 échecs pour confirmer DOWN
  static const int _thresholdUp = 2;   // 2 succès pour confirmer UP

  // Intervalles
  static const Duration _intervalNormal = Duration(minutes: 5);
  static const Duration _intervalFast = Duration(minutes: 5);

  // Public getters
  bool get isServerDown => _isPrimaryDown && _isBackupDown;
  String get activeServerUrl => _activeServerUrl;
  bool get isUsingBackup => _isUsingBackup;

  void startMonitoring(BuildContext context, NotificationController notificationCtrl) {
    stopMonitoring();
    print("🛡️ [ServerHealth] Démarrage surveillance dual-server...");
    _checkServerHealth(context, notificationCtrl);
  }

  void stopMonitoring() {
    _timer?.cancel();
    _timer = null;
  }

  void _scheduleNextCheck(Duration duration, BuildContext context, NotificationController notificationCtrl) {
    _timer?.cancel();
    _timer = Timer(duration, () {
      _checkServerHealth(context, notificationCtrl);
    });
  }

  Future<void> _checkServerHealth(BuildContext context, NotificationController notificationCtrl) async {
    // Vérification Internet
    final hasInternet = await _connectivityService.isConnected;
    
    if (!hasInternet) {
      print("📵 [ServerHealth] Pas d'Internet, skip");
      _scheduleNextCheck(_intervalNormal, context, notificationCtrl);
      return;
    }

    // Stratégie: Toujours vérifier le Primary en priorité
    final primaryStatus = await _pingServer(_primaryUrl);
    
    if (_isUsingBackup) {
      // On est sur le Backup, vérifier si Primary est revenu
      if (primaryStatus) {
        _handlePrimaryRestored(context, notificationCtrl);
      } else {
        // Primary toujours down, vérifier Backup
        final backupStatus = await _pingServer(_backupUrl);
        _handleBackupStatus(backupStatus, context, notificationCtrl);
      }
    } else {
      // On est sur le Primary
      if (primaryStatus) {
        _handlePrimaryUp(context, notificationCtrl);
      } else {
        _handlePrimaryDown(context, notificationCtrl);
      }
    }
    
    _scheduleNextCheck(_intervalNormal, context, notificationCtrl);
  }

  Future<bool> _pingServer(String url) async {
    try {
      final response = await http.get(Uri.parse(url)).timeout(Duration(seconds: 10));
      return response.statusCode < 500;
    } catch (e) {
      return false;
    }
  }

  void _handlePrimaryUp(BuildContext context, NotificationController notificationCtrl) {
    _primarySuccessCount++;
    _primaryFailCount = 0;

    if (_isPrimaryDown && _primarySuccessCount >= _thresholdUp) {
      // Primary était down, maintenant confirmé UP
      _isPrimaryDown = false;
      _primarySuccessCount = 0;
      _storage.write(_keyPrimaryDown, false);
      
      print("✅ [ServerHealth] Primary CONFIRMÉ UP");
      
      // Si les deux étaient down, notifier rétablissement
      if (_bothServersNotified) {
        _notifyServiceRestored(context, notificationCtrl);
        _bothServersNotified = false;
        _storage.write(_keyBothNotified, false);
      }
    }
  }

  Future<void> _handlePrimaryDown(BuildContext context, NotificationController notificationCtrl) async {
    _primaryFailCount++;
    _primarySuccessCount = 0;

    if (!_isPrimaryDown && _primaryFailCount >= _thresholdDown) {
      // Primary confirmé DOWN
      _isPrimaryDown = true;
      _primaryFailCount = 0;
      _storage.write(_keyPrimaryDown, true);
      
      print("🚨 [ServerHealth] Primary CONFIRMÉ DOWN");
      
      // Attendre 10 secondes puis tester Backup
      await Future.delayed(Duration(seconds: 10));
      
      final backupStatus = await _pingServer(_backupUrl);
      
      if (backupStatus) {
        // Backup UP! Basculer
        _switchToBackup(context, notificationCtrl);
      } else {
        // Backup aussi DOWN
        _isBackupDown = true;
        _storage.write(_keyBackupDown, true);
        _notifyBothServersDown(context, notificationCtrl);
      }
    }
  }

  void _handleBackupStatus(bool isUp, BuildContext context, NotificationController notificationCtrl) {
    if (isUp) {
      _backupSuccessCount++;
      _backupFailCount = 0;
      
      if (_isBackupDown && _backupSuccessCount >= _thresholdUp) {
        _isBackupDown = false;
        _backupSuccessCount = 0;
        _storage.write(_keyBackupDown, false);
        print("✅ [ServerHealth] Backup CONFIRMÉ UP");
      }
    } else {
      _backupFailCount++;
      _backupSuccessCount = 0;
      
      if (!_isBackupDown && _backupFailCount >= _thresholdDown) {
        _isBackupDown = true;
        _backupFailCount = 0;
        _storage.write(_keyBackupDown, true);
        print("🚨 [ServerHealth] Backup CONFIRMÉ DOWN");
        
        // Les deux sont down
        if (_isPrimaryDown) {
          _notifyBothServersDown(context, notificationCtrl);
        }
      }
    }
  }

  void _handlePrimaryRestored(BuildContext context, NotificationController notificationCtrl) {
    _primarySuccessCount++;
    
    if (_primarySuccessCount >= _thresholdUp) {
      // Primary confirmé UP, rebasculer silencieusement
      _isPrimaryDown = false;
      _primarySuccessCount = 0;
      _storage.write(_keyPrimaryDown, false);
      
      print("🔄 [ServerHealth] Retour au Primary (silencieux)");
      
      _isUsingBackup = false;
      _activeServerUrl = _primaryUrl;
      _storage.write(_keyUsingBackup, false);
      _storage.write(_keyActiveUrl, _primaryUrl);
      
      // Mettre à jour les constantes pour utiliser le serveur principal
      Constantes.setActiveServer(_primaryUrl);
      
      // Pas de notification pour le retour au primary
    }
  }

  void _switchToBackup(BuildContext context, NotificationController notificationCtrl) {
    _isUsingBackup = true;
    _activeServerUrl = _backupUrl;
    _isBackupDown = false;
    
    _storage.write(_keyUsingBackup, true);
    _storage.write(_keyActiveUrl, _backupUrl);
    _storage.write(_keyBackupDown, false);
    
    // Mettre à jour les constantes pour utiliser le serveur de secours
    Constantes.setActiveServer(_backupUrl);
    
    print("🔄 [ServerHealth] Basculement vers Backup (silencieux pour l'utilisateur)");
    
    // Notification simple de rétablissement (sans mentionner le backup)
    _notifyServiceRestored(context, notificationCtrl);
  }

  void _notifyBothServersDown(BuildContext context, NotificationController notificationCtrl) {
    if (_bothServersNotified) return; // Déjà notifié
    
    _bothServersNotified = true;
    _storage.write(_keyBothNotified, true);
    
    print("🚨 [ServerHealth] LES DEUX serveurs DOWN");
    
    final notif = NotificationItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: "Maintenance Technique",
      description: "Nous rencontrons un problème technique. Nous y travaillons pour le résoudre au plus vite.",
      timestamp: DateTime.now(),
      icon: Icons.electrical_services_rounded,
      iconColor: Colors.orange,
      isRead: false,
      category: "Système",
      type: NotificationType.system,
    );
    notificationCtrl.addNotification(notif);

    if (context.mounted) {
      fancy.FancyNotification.show(
        context, 
        "⚠️ Problème technique momentané.",
        type: fancy.NotificationType.warning,
        duration: 10,
      );
    }
  }

  void _notifyServiceRestored(BuildContext context, NotificationController notificationCtrl) {
    print("✅ [ServerHealth] Service rétabli");
    
    final notif = NotificationItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: "Service Rétabli",
      description: "La connexion est rétablie. Merci de votre patience.",
      timestamp: DateTime.now(),
      icon: Icons.check_circle_outline,
      iconColor: Colors.green,
      isRead: false,
      category: "Système",
      type: NotificationType.system,
    );
    notificationCtrl.addNotification(notif);

    if (context.mounted) {
      fancy.FancyNotification.show(
        context, 
        "✅ Service Rétabli",
        type: fancy.NotificationType.success,
        duration: 5,
      );
    }
  }
}
