import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:provider/provider.dart';

import '../controllers/AuthentificationCtrl.dart';
import '../screens/PaymentSubscriptionPage.dart';
import '../screens/auth/DecertificationInfoPage.dart';
import '../screens/auth/IdentityVerificationPage.dart';
import 'FancyNotification.dart';
import 'StockageKeys.dart';

class SubscriptionHelper {
  /// Connexion uniquement (navigation, formulaires, parcours jusqu’au submit).
  static Future<bool> ensureLoggedIn({
    required BuildContext context,
  }) async {
    final auth = Provider.of<AuthentificationCtrl>(context, listen: false);

    if (!auth.isLoggedIn) {
      FancyNotification.show(
        context,
        'Connectez-vous pour continuer.',
        type: NotificationType.info,
      );
      return false;
    }

    return true;
  }

  static Future<void> checkLoggedInThenProceed({
    required BuildContext context,
    required VoidCallback onProceed,
  }) async {
    final ok = await ensureLoggedIn(context: context);
    if (ok && context.mounted) onProceed();
  }

  /// Vérification d’identité (décertification, KYC) — appelée **juste avant** l’abonnement au submit.
  static Future<bool> ensureIdentityVerified({
    required BuildContext context,
  }) async {
    final auth = Provider.of<AuthentificationCtrl>(context, listen: false);

    if (!auth.isLoggedIn) {
      FancyNotification.show(
        context,
        'Connectez-vous pour continuer.',
        type: NotificationType.info,
      );
      return false;
    }

    final user = auth.user;

    if (user.isCertified == true) return true;

    final userId = user.userId?.toString() ?? '';
    final storage = GetStorage();
    final wasCertified =
        storage.read<bool>('${StockageKeys.wasCertifiedKey}_$userId') ?? false;
    final reason =
        storage.read<String>('${StockageKeys.decertificationReasonKey}_$userId');

    if (wasCertified) {
      if (!context.mounted) return false;
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (context) => DecertificationInfoPage(reason: reason),
        ),
      );
      return false;
    }

    final verified = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (context) => const IdentityVerificationPage(),
      ),
    );
    if (!context.mounted) return false;
    if (verified != true) return false;

    await auth.refreshMemberFromServer(force: true);
    if (!context.mounted) return false;
    if (auth.user.isCertified != true) {
      FancyNotification.show(
        context,
        'Votre identité doit être validée avant de poursuivre. Vous serez informé une fois l’analyse terminée.',
        type: NotificationType.info,
      );
      return false;
    }

    return true;
  }

  /// **Au submit** : identité d’abord, puis abonnement (ordre UX).
  static Future<bool> ensurePremiumForSubmit({
    required BuildContext context,
  }) async {
    if (!await ensureLoggedIn(context: context)) return false;
    if (!context.mounted) return false;

    if (!await ensureIdentityVerified(context: context)) return false;
    if (!context.mounted) return false;

    final auth = Provider.of<AuthentificationCtrl>(context, listen: false);
    if (auth.user.isPremium == true) return true;

    if (!context.mounted) return false;

    final paid = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        fullscreenDialog: true,
        builder: (subContext) => PaymentSubscriptionPage(
          onSuccess: () {},
        ),
      ),
    );

    if (paid == true && context.mounted) {
      SnackbarForCasa.success(
        context,
        'Paiement réussi ! Vous pouvez maintenant continuer.',
      );
    }

    return paid == true;
  }

  /// Délègue à [ensurePremiumForSubmit] (identité puis abonnement).
  static Future<bool> ensureCertifiedPremiumForSubmit({
    required BuildContext context,
  }) =>
      ensurePremiumForSubmit(context: context);

  /// Entrée parcours sensible : connexion seulement (plus de KYC au début).
  @Deprecated('Utiliser ensureLoggedIn ou checkLoggedInThenProceed')
  static Future<bool> ensureCertifiedForSensitiveAccess({
    required BuildContext context,
  }) =>
      ensureLoggedIn(context: context);

  @Deprecated('Utiliser checkLoggedInThenProceed')
  static Future<void> checkCertifiedThenProceed({
    required BuildContext context,
    required VoidCallback onProceed,
  }) =>
      checkLoggedInThenProceed(context: context, onProceed: onProceed);

  /// Garde à l’entrée : connexion seulement.
  static Future<void> checkCertifiedPremiumForSensitiveAction({
    required BuildContext context,
    required VoidCallback onProceed,
  }) {
    return checkLoggedInThenProceed(context: context, onProceed: onProceed);
  }

  /// Avant réservation / visite : connexion seulement ; identité + abonnement au submit.
  static Future<void> checkPremiumForPropertyReservation({
    required BuildContext context,
    required VoidCallback onProceed,
  }) {
    return checkLoggedInThenProceed(context: context, onProceed: onProceed);
  }

  /// Avant écran de création (FAB) : connexion seulement.
  static Future<void> checkSubscriptionAndProceed({
    required BuildContext context,
    required VoidCallback onProceed,
  }) {
    return checkLoggedInThenProceed(context: context, onProceed: onProceed);
  }
}
