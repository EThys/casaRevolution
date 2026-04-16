import 'package:flutter/foundation.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

import '../config/onesignal_config.dart';

// --- Documentation (flux login + backend) ------------------------------------
//
// 1) **Avant** le POST `/login`, l’app lit l’état local du SDK OneSignal.
//
// 2) **En-tête HTTP** (si l’ID existe) :
//    `X-OneSignal-Subscription-Id: <subscription_id>`
//    → identifie l’**abonnement push sur cet appareil** (une installation = un subscription).
//    Le backend peut stocker `(userId, subscription_id)` pour cibler ce téléphone via l’API REST
//    OneSignal (`include_subscription_ids` / équivalent selon version API).
//
// 3) **Après** réponse login OK, l’app appelle `OneSignal.login(userId)` (voir [onesignal_service.dart]).
//    → OneSignal associe le **même user OneSignal** à ton **identifiant métier** (*external id*).
//    Le backend peut envoyer des notifications à **tous les appareils** de l’utilisateur en ciblant
//    `external_id` = ton `userId`, sans passer par la subscription d’un seul device.
//
// 4) **Résumé** : en-tête HTTP = subscription sur **cet appareil** ; `OneSignal.login(userId)` côté SDK
//    définit l’**external_id** chez OneSignal (ciblage utilisateur sans en-tête HTTP dédié côté ton API).
// ----------------------------------------------------------------------------

String _truncateForLog(String? s, {int head = 16}) {
  if (s == null || s.isEmpty) return '(vide)';
  if (s.length <= head + 4) return s;
  return '${s.substring(0, head)}… (longueur ${s.length})';
}

/// En-têtes HTTP optionnels pour le login : subscription push de **cet appareil**.
Map<String, String> buildOneSignalAuthHeaders() {
  if (kIsWeb) return {};
  try {
    final id = OneSignal.User.pushSubscription.id;
    if (id == null || id.trim().isEmpty) return {};
    return {'X-OneSignal-Subscription-Id': id.trim()};
  } catch (_) {
    return {};
  }
}

/// Logs détaillés **uniquement en debug** : à appeler juste avant `postDataForAuth` (login).
Future<void> logOneSignalStateBeforeLoginDebug() async {
  if (!kDebugMode) return;

  debugPrint('');
  debugPrint('[OneSignal][login] ━━━ Diagnostic AVANT requête login ━━━');
  if (kIsWeb) {
    debugPrint('[OneSignal][login] Web → pas de push natif, aucun en-tête OneSignal.');
    debugPrint('[OneSignal][login] ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('');
    return;
  }
  if (kOneSignalAppId.isEmpty) {
    debugPrint('[OneSignal][login] ONESIGNAL_APP_ID vide → SDK non initialisé.');
    debugPrint('[OneSignal][login] ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('');
    return;
  }

  try {
    final sub = OneSignal.User.pushSubscription;
    final headers = buildOneSignalAuthHeaders();

    debugPrint('[OneSignal][login] pushSubscription.id');
    debugPrint('    → envoyé au backend dans le header: X-OneSignal-Subscription-Id');
    debugPrint('    → valeur: ${sub.id ?? "(null ou pas encore synchronisé)"}');
    debugPrint('[OneSignal][login] pushSubscription.optedIn (recevoir des push): ${sub.optedIn}');
    debugPrint('[OneSignal][login] push token (FCM/APNs, tronqué): ${_truncateForLog(sub.token, head: 10)}');

    String? onesignalUserId;
    String? externalId;
    try {
      onesignalUserId = await OneSignal.User.getOnesignalId();
    } catch (e) {
      debugPrint('[OneSignal][login] getOnesignalId() erreur: $e');
    }
    try {
      externalId = await OneSignal.User.getExternalId();
    } catch (e) {
      debugPrint('[OneSignal][login] getExternalId() erreur: $e');
    }

    debugPrint('[OneSignal][login] getOnesignalId() (utilisateur OneSignal côté cloud): ${_truncateForLog(onesignalUserId, head: 24)}');
    debugPrint('[OneSignal][login] getExternalId() AVANT OneSignal.login (souvent vide): ${_truncateForLog(externalId, head: 16)}');

    debugPrint('[OneSignal][login] Map réelle fusionnée dans les headers HTTP du POST login:');
    debugPrint('    $headers');
    if (headers.isEmpty) {
      debugPrint('[OneSignal][login] ⚠ Aucun en-tête : subscription id pas encore dispo (permissions, délai SDK, etc.).');
    }
  } catch (e, st) {
    debugPrint('[OneSignal][login] Erreur lecture état: $e');
    debugPrint('$st');
  }
  debugPrint('[OneSignal][login] ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  debugPrint('');
}

/// Logs **après** `OneSignal.login(userId)` — petit délai pour laisser le bridge natif mettre à jour.
Future<void> logOneSignalStateAfterLoginDebug(String appUserId) async {
  if (!kDebugMode) return;

  debugPrint('');
  debugPrint('[OneSignal][login] ━━━ Diagnostic APRÈS OneSignal.login("$appUserId") ━━━');
  if (kIsWeb || kOneSignalAppId.isEmpty) {
    debugPrint('[OneSignal][login] (ignoré plateforme / App ID)');
    debugPrint('[OneSignal][login] ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('');
    return;
  }

  try {
    String? externalId;
    try {
      externalId = await OneSignal.User.getExternalId();
    } catch (e) {
      debugPrint('[OneSignal][login] getExternalId() erreur: $e');
    }
    debugPrint('[OneSignal][login] getExternalId() APRÈS login (doit matcher userId app): ${_truncateForLog(externalId, head: 24)}');
    debugPrint('[OneSignal][login] Le backend peut cibler les push par external_id = "$appUserId" (API OneSignal).');
    final subId = OneSignal.User.pushSubscription.id;
    debugPrint('[OneSignal][login] pushSubscription.id (toujours le même device): ${subId ?? "(vide)"}');
  } catch (e) {
    debugPrint('[OneSignal][login] Erreur: $e');
  }
  debugPrint('[OneSignal][login] ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  debugPrint('');
}
