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
  /// **Avant** réservation, publication, sollicitation : identité certifiée uniquement (pas l’abonnement).
  static Future<bool> ensureCertifiedForSensitiveAccess({
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

    if (user.isCertified != true) {
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
    }

    return true;
  }

  static Future<void> checkCertifiedThenProceed({
    required BuildContext context,
    required VoidCallback onProceed,
  }) async {
    final ok = await ensureCertifiedForSensitiveAccess(context: context);
    if (ok && context.mounted) onProceed();
  }

  /// **Au submit uniquement** : abonnement payant (la certification est déjà exigée à l’accès).
  static Future<bool> ensurePremiumForSubmit({
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

    if (auth.user.isCertified != true) {
      FancyNotification.show(
        context,
        'Terminez d’abord la vérification d’identité avant de valider.',
        type: NotificationType.info,
      );
      return false;
    }

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

  /// Délègue à [ensurePremiumForSubmit] (compatibilité).
  static Future<bool> ensureCertifiedPremiumForSubmit({
    required BuildContext context,
  }) =>
      ensurePremiumForSubmit(context: context);

  /// Garde à l’entrée : **certification** seulement.
  static Future<void> checkCertifiedPremiumForSensitiveAction({
    required BuildContext context,
    required VoidCallback onProceed,
  }) {
    return checkCertifiedThenProceed(context: context, onProceed: onProceed);
  }

  /// Avant réservation / visite : **certification** seulement.
  static Future<void> checkPremiumForPropertyReservation({
    required BuildContext context,
    required VoidCallback onProceed,
  }) {
    return checkCertifiedThenProceed(context: context, onProceed: onProceed);
  }

  /// Avant écran de création (FAB) : **certification** seulement.
  static Future<void> checkSubscriptionAndProceed({
    required BuildContext context,
    required VoidCallback onProceed,
  }) {
    return checkCertifiedThenProceed(context: context, onProceed: onProceed);
  }
}
