import 'package:flutter/foundation.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

import '../config/onesignal_config.dart';

/// Initializes OneSignal push (Android / iOS only). No-op if [kOneSignalAppId] is empty.
///
/// ### Personnalisation côté utilisateur (téléphone)
/// Chaque OS gère sonnerie / vibration / affichage dans **Réglages → Notifications → CasaNayo**.
/// - **Android**: la personnalisation est **par canal** (notification channel) si l’app en déclare.
/// - **iOS**: la personnalisation est **par application** (sons/bannières selon iOS).
///
/// ### Sonneries personnalisées (marque CasaNayo) 2nnnnn
/// - **Android**: ce projet crée un canal avec l’ID **`casanayo_default`** (voir `MainActivity.kt`).
///   Pour un son custom, ajouter un fichier audio dans `android/app/src/main/res/raw/` et
///   le référencer dans le canal (code déjà prêt à activer dans `MainActivity.kt`).
///   Côté OneSignal, envoyer les pushes sur ce canal via `android_channel_id: "casanayo_default"`.
/// - **iOS**: ajouter le son dans le bundle iOS (≤ 30s) et le référencer côté payload (`ios_sound`).
Future<void> initOneSignal() async {
  if (kIsWeb) return;
  if (defaultTargetPlatform != TargetPlatform.android &&
      defaultTargetPlatform != TargetPlatform.iOS) {
    return;
  }

  if (kOneSignalAppId.isEmpty) {
    if (kDebugMode) {
      debugPrint(
        'OneSignal: skipped (set ONESIGNAL_APP_ID via --dart-define or lib/config/onesignal_config.dart)',
      );
    }
    return;
  }

  if (kDebugMode) {
    OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
  }

  OneSignal.initialize(kOneSignalAppId);

  // IMPORTANT:
  // Ne pas demander la permission ici, sinon Android/iOS peut afficher le prompt
  // avant même que l'UI soit visible (délai perçu à l'ouverture).
}

/// À appeler **après** l'ouverture de l'app (post-frame) pour demander la permission
/// quand l'utilisateur voit déjà l'écran.
Future<void> requestOneSignalNotificationPermissionAfterLaunch() async {
  if (kIsWeb) return;
  if (defaultTargetPlatform != TargetPlatform.android &&
      defaultTargetPlatform != TargetPlatform.iOS) {
    return;
  }
  if (kOneSignalAppId.isEmpty) return;
  try {
    await OneSignal.Notifications.requestPermission(true);
  } catch (_) {}
}

/// Lie l’utilisateur applicatif à OneSignal (**external id**). À appeler après login réussi.
/// Le backend peut cibler les envois par `external_id` = cet identifiant.
void oneSignalLoginWithAppUserId(String userId) {
  if (kIsWeb) return;
  if (defaultTargetPlatform != TargetPlatform.android &&
      defaultTargetPlatform != TargetPlatform.iOS) {
    return;
  }
  if (kOneSignalAppId.isEmpty) return;
  final id = userId.trim();
  if (id.isEmpty) return;
  try {
    OneSignal.login(id);
    if (kDebugMode) {
      debugPrint('[OneSignal][login] OneSignal.login("$id") appelé → external_id côté OneSignal.');
    }
  } catch (e) {
    if (kDebugMode) {
      debugPrint('OneSignal.login: $e');
    }
  }
}

/// Dissocie le device du compte OneSignal à la déconnexion.
void oneSignalLogout() {
  if (kIsWeb) return;
  if (defaultTargetPlatform != TargetPlatform.android &&
      defaultTargetPlatform != TargetPlatform.iOS) {
    return;
  }
  if (kOneSignalAppId.isEmpty) return;
  try {
    OneSignal.logout();
  } catch (e) {
    if (kDebugMode) {
      debugPrint('OneSignal.logout: $e');
    }
  }
}
