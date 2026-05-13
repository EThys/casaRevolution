import 'dart:io' show Platform;

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:get_storage/get_storage.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pub_semver/pub_semver.dart';

class AppUpdateDecision {
  const AppUpdateDecision({
    required this.shouldShow,
    required this.force,
    required this.message,
    required this.storeUrl,
    required this.latest,
    required this.min,
    required this.current,
  });

  final bool shouldShow;
  final bool force;
  final String message;
  final String storeUrl;
  final Version? latest;
  final Version? min;
  final Version current;
}

/// Mises à jour pilotées par Firebase Remote Config.
///
/// **À publier dans Firebase (même projet que `google-services.json` / iOS plist)** :
/// String: `latest_version_android`, `min_version_android`, `store_url_android`,
/// `latest_version_ios`, `min_version_ios`, `store_url_ios`, `update_message`
/// Bool: `force_update`
///
/// Versions au format `MAJOR.MINOR.PATCH` (alignées sur `pubspec.yaml`, partie avant `+`).
/// En release, `minimumFetchInterval` limite la fréquence des fetch réseau (pas l’affichage après MAJ installée).
class AppUpdateService {
  AppUpdateService._();

  static const String _kSnoozeKey = 'update_prompt_snooze_until';

  // Remote Config keys
  static const String kLatestAndroid = 'latest_version_android';
  static const String kLatestIos = 'latest_version_ios';
  static const String kMinAndroid = 'min_version_android';
  static const String kMinIos = 'min_version_ios';
  static const String kMessage = 'update_message';
  static const String kForce = 'force_update';
  static const String kStoreUrlAndroid = 'store_url_android';
  static const String kStoreUrlIos = 'store_url_ios';

  static Future<void> warmup() async {
    try {
      final rc = FirebaseRemoteConfig.instance;
      await rc.setDefaults(<String, Object>{
        kLatestAndroid: '0.0.0',
        kLatestIos: '0.0.0',
        kMinAndroid: '0.0.0',
        kMinIos: '0.0.0',
        kMessage: 'Une mise à jour est disponible. Merci de mettre à jour pour continuer.',
        kForce: false,
        kStoreUrlAndroid: '',
        kStoreUrlIos: '',
      });
      await rc.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 12),
          minimumFetchInterval: kDebugMode ? Duration.zero : const Duration(hours: 6),
        ),
      );
      final activated = await rc.fetchAndActivate();
      if (kDebugMode) {
        print('📡 [AppUpdateService] Remote Config fetchAndActivate → $activated');
        print('📡 [AppUpdateService] lastFetchStatus → ${rc.lastFetchStatus}');
        print('📡 [AppUpdateService] lastFetchTime → ${rc.lastFetchTime}');
        final plat = Platform.isIOS ? 'ios' : 'android';
        print(
          '📡 [AppUpdateService] RC brut ($plat): latest=${rc.getString(Platform.isIOS ? kLatestIos : kLatestAndroid)} '
          'min=${rc.getString(Platform.isIOS ? kMinIos : kMinAndroid)} '
          'force=${rc.getBool(kForce)}',
        );
      }
    } catch (e, st) {
      if (kDebugMode) {
        print('⚠️ [AppUpdateService] Remote Config warmup error: $e');
        print('⚠️ [AppUpdateService] $st');
      }
    }
  }

  static Version _safeVersion(String? raw) {
    final s = (raw ?? '').trim();
    if (s.isEmpty) return Version(0, 0, 0);
    try {
      return Version.parse(s);
    } catch (_) {
      // Try to coerce "1.0" -> "1.0.0"
      final parts = s.split('.');
      if (parts.length == 2) {
        return Version.parse('${parts[0]}.${parts[1]}.0');
      }
      return Version(0, 0, 0);
    }
  }

  static Future<AppUpdateDecision> check() async {
    final info = await PackageInfo.fromPlatform();
    final current = _safeVersion(info.version);

    final rc = FirebaseRemoteConfig.instance;
    final latestStr = Platform.isIOS ? rc.getString(kLatestIos) : rc.getString(kLatestAndroid);
    final minStr = Platform.isIOS ? rc.getString(kMinIos) : rc.getString(kMinAndroid);
    final storeUrl = Platform.isIOS ? rc.getString(kStoreUrlIos) : rc.getString(kStoreUrlAndroid);

    final latest = _safeVersion(latestStr);
    final min = _safeVersion(minStr);
    final message = rc.getString(kMessage).trim().isEmpty
        ? 'Une mise à jour est disponible.'
        : rc.getString(kMessage).trim();
    final forceFlag = rc.getBool(kForce);

    final needForce = current < min;
    final shouldSuggest = current < latest;

    // Snooze only for non-forced updates
    final storage = GetStorage();
    final snoozeUntil = storage.read<int>(_kSnoozeKey) ?? 0;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final isSnoozed = snoozeUntil > nowMs;

    final shouldShow = needForce || (shouldSuggest && !isSnoozed);
    final force = needForce || (forceFlag && shouldSuggest);

    if (kDebugMode) {
      print(
        '📲 [AppUpdateService] Update check | plateforme=${Platform.isIOS ? "iOS" : "Android"} | '
        'installée=$current | RC latest=$latest | RC min=$min',
      );
      print(
        '📲 [AppUpdateService] needForce=$needForce shouldSuggest=$shouldSuggest '
        'forceFlag=$forceFlag isSnoozed=$isSnoozed (snoozeUntil=$snoozeUntil now=$nowMs) → shouldShow=$shouldShow force=$force',
      );
      if (latest == Version(0, 0, 0) && min == Version(0, 0, 0)) {
        print(
          '⚠️ [AppUpdateService] latest et min sont à 0.0.0 : paramètres RC absents ou fetch échoué. '
          'Vérifie Firebase Console > Remote Config (clés publiées + même projet que google-services).',
        );
      }
    }

    return AppUpdateDecision(
      shouldShow: shouldShow,
      force: force,
      message: message,
      storeUrl: storeUrl,
      latest: latest == Version(0, 0, 0) ? null : latest,
      min: min == Version(0, 0, 0) ? null : min,
      current: current,
    );
  }

  static Future<void> snooze({Duration duration = const Duration(hours: 24)}) async {
    final storage = GetStorage();
    final until = DateTime.now().add(duration).millisecondsSinceEpoch;
    await storage.write(_kSnoozeKey, until);
  }

  static Future<void> clearSnooze() async {
    await GetStorage().remove(_kSnoozeKey);
  }
}

