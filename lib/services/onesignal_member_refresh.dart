import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:provider/provider.dart';

import 'package:casa/Apps/MonApllication.dart';
import '../config/onesignal_config.dart';
import '../controllers/AuthentificationCtrl.dart';
import '../utils/decertification_access_guard.dart';

bool _memberRefreshHooksAttached = false;

bool _truthy(dynamic v) {
  if (v == null) return false;
  if (v is bool) return v;
  if (v is num) return v != 0;
  final s = v.toString().trim().toLowerCase();
  return s == '1' || s == 'true' || s == 'yes';
}

/// Indique si les données de la notif concernent profil, paiement ou décertification.
///
/// Côté tableau OneSignal / API, envoyer des **Additional Data** par exemple :
/// - `refresh_member` : `true`
/// - ou `type` : `subscription_payment`, `decertification`, `premium`, etc.
///
/// En secours, analyse du titre / corps (mots-clés FR/EN).
bool notificationImpliesMemberRefresh(OSNotification notification) {
  final maps = <Map<String, dynamic>>[];

  final add = (dynamic raw) {
    if (raw is Map) {
      maps.add(Map<String, dynamic>.from(raw as Map));
    }
  };

  add(notification.additionalData);
  add(notification.rawPayload);

  for (final m in maps) {
    final merged = Map<String, dynamic>.from(m);
    final custom = merged['custom'];
    if (custom is Map) {
      merged.addAll(Map<String, dynamic>.from(custom as Map));
    }
    final a = merged['a']; // payload plat Android parfois sous "a"
    if (a is Map) {
      merged.addAll(Map<String, dynamic>.from(a as Map));
    }

    if (_truthy(merged['refresh_member']) || _truthy(merged['member_refresh'])) {
      return true;
    }
    final typeStr =
        '${merged['type'] ?? merged['category'] ?? merged['event'] ?? ''}'
            .toLowerCase();
    if (typeStr.contains('payment') ||
        typeStr.contains('premium') ||
        typeStr.contains('subscription') ||
        typeStr.contains('abonnement') ||
        typeStr.contains('decertif') ||
        typeStr.contains('certif') ||
        typeStr.contains('identity') ||
        typeStr.contains('verification')) {
      return true;
    }
  }

  final haystack =
      '${notification.title ?? ''} ${notification.body ?? ''}'.toLowerCase();
  if (haystack.contains('paiement') ||
      haystack.contains('payment') ||
      haystack.contains('abonnement') ||
      haystack.contains('premium') ||
      haystack.contains('décertification') ||
      haystack.contains('decertification') ||
      haystack.contains('certification')) {
    return true;
  }
  return false;
}

/// Recharge le membre (premium, certified…) puis applique l’alerte décertification si besoin.
///
/// Réessaie brièvement si le navigateur n’est pas encore monté (cold start après tap sur une notif).
Future<void> refreshMemberAfterPushNotification({required bool force}) async {
  BuildContext? ctx;
  for (var attempt = 0; attempt < 15; attempt++) {
    if (attempt > 0) {
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }
    ctx = MonApplication.navigatorKey.currentContext;
    if (ctx != null && ctx.mounted) break;
  }
  if (ctx == null || !ctx.mounted) return;

  AuthentificationCtrl auth;
  try {
    auth = Provider.of<AuthentificationCtrl>(ctx, listen: false);
  } catch (_) {
    return;
  }
  if (!auth.isLoggedIn || auth.token.isEmpty) return;

  await auth.refreshMemberFromServer(force: force);

  final ctx2 = MonApplication.navigatorKey.currentContext;
  if (ctx2 == null || !ctx2.mounted) return;
  try {
    auth = Provider.of<AuthentificationCtrl>(ctx2, listen: false);
  } catch (_) {
    return;
  }
  await DecertificationAccessGuard.presentDecertificationAlertIfNeeded(auth);
}

/// À appeler une fois après [OneSignal.initialize] : ouverture de notif + notif au premier plan.
void attachOneSignalMemberRefreshHooks() {
  if (kIsWeb) return;
  if (defaultTargetPlatform != TargetPlatform.android &&
      defaultTargetPlatform != TargetPlatform.iOS) {
    return;
  }
  if (kOneSignalAppId.isEmpty) return;
  if (_memberRefreshHooksAttached) return;
  _memberRefreshHooksAttached = true;

  OneSignal.Notifications.addClickListener((OSNotificationClickEvent event) {
    // Écran verrouillé ou app en arrière-plan : au tap, resync immédiat (paiement / décertification).
    Future<void>.delayed(Duration.zero, () {
      refreshMemberAfterPushNotification(force: true);
    });
  });

  OneSignal.Notifications.addForegroundWillDisplayListener(
    (OSNotificationWillDisplayEvent event) {
      if (!notificationImpliesMemberRefresh(event.notification)) return;
      Future<void>.delayed(const Duration(milliseconds: 500), () {
        refreshMemberAfterPushNotification(force: true);
      });
    },
  );
}
