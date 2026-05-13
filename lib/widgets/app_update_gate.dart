import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/app_update_service.dart';

/// Affiche le bottomsheet « mise à jour » (design Casanayo).
/// À appeler depuis [HomePage] quand l’accueil est affiché — pas au cold start / splash.
class AppUpdatePrompt {
  AppUpdatePrompt._();

  /// **true** = démo UI uniquement (pas de Remote Config / pas de comparaison de version).
  /// **false** = Remote Config + logique [AppUpdateService.check] (production).
  static const bool kUiPreviewOnly = false;

  /// Une fois par instance de page d’accueil (évite doublons si initState se relance).
  static Future<void> maybeShowOnHome(BuildContext context) async {
    if (!context.mounted) return;

    try {
      late final AppUpdateDecision decision;
      late final String storeUrl;

      if (kUiPreviewOnly) {
        decision = AppUpdateDecision(
          shouldShow: true,
          force: false,
          message:
              "Nouvelle version disponible. Pour une meilleure expérience, merci de mettre à jour l'application.",
          storeUrl:
              'https://play.google.com/store/apps/details?id=com.casa.casa.casa',
          latest: Version(1, 0, 18),
          min: Version(1, 0, 17),
          current: Version(1, 0, 17),
        );
        storeUrl = decision.storeUrl.trim().isNotEmpty
            ? decision.storeUrl.trim()
            : 'https://play.google.com/store/apps/details?id=com.casa.casa.casa';
      } else {
        await AppUpdateService.warmup();
        decision = await AppUpdateService.check();
        if (!decision.shouldShow) {
          if (kDebugMode) {
            debugPrint(
              '[AppUpdatePrompt] Bottomsheet non affiché (shouldShow=false). '
              'Voir logs [AppUpdateService] ci-dessus.',
            );
          }
          return;
        }
        if (!context.mounted) return;

        final pkg = await PackageInfo.fromPlatform();
        final packageName = pkg.packageName;
        final su = decision.storeUrl.trim();
        if (su.isNotEmpty) {
          storeUrl = su;
        } else if (Platform.isIOS) {
          // Définir `store_url_ios` dans Firebase pour le lien direct vers l’app.
          storeUrl = 'https://apps.apple.com';
        } else {
          storeUrl =
              'https://play.google.com/store/apps/details?id=$packageName';
        }
      }

      if (!context.mounted) return;
      await showAppUpdateBottomSheet(
        context,
        decision: decision,
        storeUrl: storeUrl,
      );
    } catch (e, st) {
      // Jamais bloquer l’accueil si Remote Config ou package_info échoue.
      if (kDebugMode) {
        debugPrint('[AppUpdatePrompt] Ignoré (erreur): $e');
        debugPrint('$st');
      }
    }
  }
}

Future<void> showAppUpdateBottomSheet(
  BuildContext context, {
  required AppUpdateDecision decision,
  required String storeUrl,
}) async {
  final url = storeUrl;

  await showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withOpacity(0.45),
    enableDrag: !decision.force,
    isDismissible: !decision.force,
    builder: (sheetContext) {
      final primary = const Color(0xFF2A5C99);
      final force = decision.force;
      final badgeBg =
          force ? const Color(0xFFFFEBEE) : const Color(0xFFE3F2FD);
      final badgeFg =
          force ? const Color(0xFFC62828) : const Color(0xFF1565C0);
      final badgeText = force ? 'Obligatoire' : 'Recommandée';

      final currentStr = decision.current.toString();
      final latestStr = decision.latest?.toString();

      return SafeArea(
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.only(
            left: 14,
            right: 14,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 14,
          ),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: PopScope(
              canPop: !force,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 560),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.18),
                      blurRadius: 30,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 16, 12, 10),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: primary.withOpacity(0.10),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              Icons.system_update_rounded,
                              color: primary,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Mise à jour disponible',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.2,
                                    color: Color(0xFF111827),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: badgeBg,
                                        borderRadius:
                                            BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        badgeText,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          color: badgeFg,
                                        ),
                                      ),
                                    ),
                                    if (latestStr != null &&
                                        latestStr.trim().isNotEmpty)
                                      Text(
                                        'Votre version $currentStr • Nouvelle $latestStr',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF6B7280),
                                        ),
                                      )
                                    else
                                      Text(
                                        'Votre version $currentStr',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF6B7280),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (!force)
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () =>
                                    Navigator.of(sheetContext).pop(),
                                borderRadius: BorderRadius.circular(999),
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF3F4F6),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: const Icon(
                                    Icons.close_rounded,
                                    size: 20,
                                    color: Color(0xFF6B7280),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 4, 18, 0),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          decision.message,
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.35,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF374151),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                      child: Row(
                        children: [
                          if (!force)
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () async {
                                  await AppUpdateService.snooze();
                                  if (sheetContext.mounted) {
                                    Navigator.of(sheetContext).pop();
                                  }
                                },
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 14),
                                  foregroundColor: const Color(0xFF111827),
                                  side: const BorderSide(
                                      color: Color(0xFFE5E7EB)),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: const Text(
                                  'Plus tard',
                                  style:
                                      TextStyle(fontWeight: FontWeight.w800),
                                ),
                              ),
                            ),
                          if (!force) const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton(
                              onPressed: () async {
                                try {
                                  final uri = Uri.tryParse(url);
                                  if (uri != null && uri.hasAuthority) {
                                    final opened = await launchUrl(
                                      uri,
                                      mode: LaunchMode.externalApplication,
                                    );
                                    if (!opened && kDebugMode) {
                                      debugPrint(
                                        '[AppUpdatePrompt] launchUrl a échoué: $url',
                                      );
                                    }
                                  }
                                } catch (e) {
                                  if (kDebugMode) {
                                    debugPrint('[AppUpdatePrompt] launchUrl: $e');
                                  }
                                }
                                if (!force && sheetContext.mounted) {
                                  Navigator.of(sheetContext).pop();
                                }
                              },
                              style: FilledButton.styleFrom(
                                backgroundColor: primary,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: const Text(
                                'Mettre à jour',
                                style: TextStyle(fontWeight: FontWeight.w900),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// Enveloppe vide : la logique d’update est déclenchée depuis [HomePage].
class AppUpdateGate extends StatelessWidget {
  const AppUpdateGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}
