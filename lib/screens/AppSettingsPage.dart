import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

import '../config/onesignal_config.dart';
import '../utils/FancyNotification.dart';
import '../utils/StockageKeys.dart';

class AppSettingsPage extends StatefulWidget {
  const AppSettingsPage({super.key});

  @override
  State<AppSettingsPage> createState() => _AppSettingsPageState();
}

class _AppSettingsPageState extends State<AppSettingsPage> with WidgetsBindingObserver {
  static const _primary = Color(0xFF1976D2);

  final GetStorage _box = GetStorage();
  bool _loading = true;
  bool _notifications = false;
  bool _camera = false;
  bool _microphone = false;
  bool _photos = false;

  bool get _native =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final notifications = await _notificationsEnabled();
    if (!_native) {
      if (!mounted) return;
      setState(() {
        _notifications = notifications;
        _loading = false;
      });
      return;
    }
    final camera = await Permission.camera.isGranted;
    final microphone = await Permission.microphone.isGranted;
    final photos = await _photosGranted();
    if (!mounted) return;
    setState(() {
      _notifications = notifications;
      _camera = camera;
      _microphone = microphone;
      _photos = photos;
      _loading = false;
    });
  }

  Future<bool> _photosGranted() async {
    if (Platform.isIOS) {
      final status = await Permission.photos.status;
      return status.isGranted || status.isLimited;
    }
    if (await Permission.storage.isGranted) return true;
    final photos = await Permission.photos.status;
    return photos.isGranted || photos.isLimited;
  }

  Future<bool> _notificationsEnabled() async {
    final stored = _box.read(StockageKeys.notificationsEnabledKey);
    if (stored == false) return false;
    if (!_native || kOneSignalAppId.isEmpty) {
      if (_native) return (await Permission.notification.status).isGranted;
      return stored == true;
    }
    try {
      final opted = OneSignal.User.pushSubscription.optedIn;
      if (opted == false) return false;
      if (opted == true) return true;
    } catch (_) {}
    return (await Permission.notification.status).isGranted || stored == true;
  }

  Future<void> _setNotifications(bool enabled) async {
    await _box.write(StockageKeys.notificationsEnabledKey, enabled);
    if (!enabled) {
      if (_native && kOneSignalAppId.isNotEmpty) {
        try {
          OneSignal.User.pushSubscription.optOut();
        } catch (_) {}
      }
      if (mounted) setState(() => _notifications = false);
      return;
    }

    if (_native) {
      final status = await Permission.notification.request();
      if (status.isPermanentlyDenied || status.isRestricted) {
        _tellSettings('Les notifications sont bloquées dans les réglages du téléphone.');
        await openAppSettings();
      }
      if (kOneSignalAppId.isNotEmpty) {
        try {
          await OneSignal.Notifications.requestPermission(true);
          OneSignal.User.pushSubscription.optIn();
        } catch (_) {}
      }
    }
    await _refresh();
  }

  Future<void> _setOsPermission({
    required bool enabled,
    required Permission permission,
    required String blockedMessage,
    required String revokeMessage,
  }) async {
    if (!enabled) {
      _tellSettings(revokeMessage);
      await openAppSettings();
      return;
    }
    final status = await permission.request();
    if (status.isPermanentlyDenied || status.isRestricted) {
      _tellSettings(blockedMessage);
      await openAppSettings();
    }
    await _refresh();
  }

  Future<void> _setPhotos(bool enabled) async {
    final permission = Platform.isIOS ? Permission.photos : Permission.storage;
    await _setOsPermission(
      enabled: enabled,
      permission: permission,
      blockedMessage: 'L’accès aux photos est bloqué dans les réglages du téléphone.',
      revokeMessage: 'Pour retirer l’accès aux photos, désactivez-le dans les réglages du téléphone.',
    );
  }

  void _tellSettings(String message) {
    if (!mounted) return;
    FancyNotification.show(
      context,
      message,
      isError: true,
      type: NotificationType.info,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF111827),
        title: const Text(
          'Paramètres',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              children: [
                const Text(
                  'Choisissez ce que CasaNayo peut utiliser sur cet appareil.',
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 14, height: 1.4),
                ),
                const SizedBox(height: 16),
                _card([
                  _toggle(
                    icon: Icons.notifications_rounded,
                    title: 'Notifications',
                    subtitle: 'Messages, réservations et actualités CasaNayo.',
                    value: _notifications,
                    onChanged: _setNotifications,
                  ),
                ]),
                if (_native) ...[
                  const SizedBox(height: 14),
                  _card([
                    _toggle(
                      icon: Icons.photo_camera_rounded,
                      title: 'Caméra',
                      subtitle: 'Photo de profil, pièces et annonces.',
                      value: _camera,
                      onChanged: (value) => _setOsPermission(
                        enabled: value,
                        permission: Permission.camera,
                        blockedMessage: 'La caméra est bloquée dans les réglages du téléphone.',
                        revokeMessage: 'Pour retirer l’accès à la caméra, désactivez-le dans les réglages du téléphone.',
                      ),
                    ),
                    _divider(),
                    _toggle(
                      icon: Icons.mic_rounded,
                      title: 'Microphone',
                      subtitle: 'Messages vocaux dans les conversations.',
                      value: _microphone,
                      onChanged: (value) => _setOsPermission(
                        enabled: value,
                        permission: Permission.microphone,
                        blockedMessage: 'Le microphone est bloqué dans les réglages du téléphone.',
                        revokeMessage: 'Pour retirer l’accès au microphone, désactivez-le dans les réglages du téléphone.',
                      ),
                    ),
                    _divider(),
                    _toggle(
                      icon: Icons.photo_library_rounded,
                      title: 'Photos',
                      subtitle: 'Choisir une image dans la galerie.',
                      value: _photos,
                      onChanged: _setPhotos,
                    ),
                  ]),
                ],
              ],
            ),
    );
  }

  Widget _card(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _divider() {
    return const Divider(height: 1, indent: 68, endIndent: 16, color: Color(0xFFE2E8F0));
  }

  Widget _toggle({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile.adaptive(
      contentPadding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      secondary: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: _primary.withOpacity(0.10),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: _primary, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(subtitle, style: const TextStyle(fontSize: 13, height: 1.3, color: Color(0xFF64748B))),
      ),
      value: value,
      activeColor: _primary,
      onChanged: onChanged,
    );
  }
}
