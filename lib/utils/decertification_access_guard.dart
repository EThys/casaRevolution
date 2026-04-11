import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:provider/provider.dart';

import 'package:casa/Apps/MonApllication.dart';
import '../controllers/AuthentificationCtrl.dart';
import '../screens/auth/DecertificationInfoPage.dart';
import 'StockageKeys.dart';

/// Garde réservée au cas **déjà certifié puis décertifié** (`was_certified` + `isCertified != true`).
/// Les comptes jamais certifiés ne sont pas concernés par ce flux « extrême ».
class DecertificationAccessGuard {
  DecertificationAccessGuard._();

  static bool isInactiveDecertifiedAccount(AuthentificationCtrl auth) {
    if (!auth.isLoggedIn) return false;
    if (auth.user.isCertified == true) return false;
    final uid = auth.user.userId?.toString() ?? '';
    if (uid.isEmpty) return false;
    final was =
        GetStorage().read<bool>('${StockageKeys.wasCertifiedKey}_$uid') ?? false;
    return was;
  }

  /// Retourne `true` si une redirection a été faite (fermer la page courante + ouvrir [DecertificationInfoPage]).
  static Future<bool> redirectIfInactiveDecertified(BuildContext context) async {
    if (!context.mounted) return false;
    AuthentificationCtrl auth;
    try {
      auth = context.read<AuthentificationCtrl>();
    } catch (_) {
      return false;
    }
    if (!isInactiveDecertifiedAccount(auth)) return false;

    final uid = auth.user.userId?.toString() ?? '';
    final reason = GetStorage()
        .read<String>('${StockageKeys.decertificationReasonKey}_$uid');

    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
    }

    await Future<void>.delayed(Duration.zero);

    final rootNav = MonApplication.navigatorKey.currentState;
    if (rootNav != null && rootNav.mounted) {
      await rootNav.push<void>(
        MaterialPageRoute<void>(
          builder: (context) => DecertificationInfoPage(reason: reason),
        ),
      );
    }
    return true;
  }
}
