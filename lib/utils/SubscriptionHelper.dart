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
  /// Visites / réservations biens **et** sollicitations de service : identité certifiée → abonnement
  /// premium (comme la publication via le menu création).
  ///
  /// Si certification et premium manquent : d’abord [IdentityVerificationPage], puis à validation
  /// effective [PaymentSubscriptionPage].
  static Future<void> checkCertifiedPremiumForSensitiveAction({
    required BuildContext context,
    required VoidCallback onProceed,
  }) async {
    final auth = Provider.of<AuthentificationCtrl>(context, listen: false);

    if (!auth.isLoggedIn) {
      FancyNotification.show(
        context,
        'Connectez-vous pour continuer.',
        type: NotificationType.info,
      );
      return;
    }

    final user = auth.user;

    // --- Certification (même logique que [_checkCertificationAndNavigate] dans BottomNavBar) ---
    if (user.isCertified != true) {
      final userId = user.userId?.toString() ?? '';
      final storage = GetStorage();
      final wasCertified =
          storage.read<bool>('${StockageKeys.wasCertifiedKey}_$userId') ?? false;
      final reason =
          storage.read<String>('${StockageKeys.decertificationReasonKey}_$userId');

      if (wasCertified) {
        if (!context.mounted) return;
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (context) => DecertificationInfoPage(reason: reason),
          ),
        );
        return;
      }

      final verified = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (context) => const IdentityVerificationPage(),
        ),
      );
      if (!context.mounted) return;
      if (verified != true) return;

      await auth.refreshMemberFromServer(force: true);
      if (!context.mounted) return;
      if (auth.user.isCertified != true) {
        FancyNotification.show(
          context,
          'Votre identité doit être validée avant de poursuivre. Vous serez informé une fois l’analyse terminée.',
          type: NotificationType.info,
        );
        return;
      }
    }

    // --- Premium ---
    if (auth.user.isPremium == true) {
      onProceed();
      return;
    }

    if (!context.mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => PaymentSubscriptionPage(
          onSuccess: () {
            Navigator.of(context).pop();
            SnackbarForCasa.success(
              context,
              'Paiement réussi ! Vous pouvez maintenant continuer.',
            );
            onProceed();
          },
        ),
      ),
    );
  }

  /// Alias pour réservations / visites (même garde que les sollicitations).
  static Future<void> checkPremiumForPropertyReservation({
    required BuildContext context,
    required VoidCallback onProceed,
  }) {
    return checkCertifiedPremiumForSensitiveAction(
      context: context,
      onProceed: onProceed,
    );
  }

  /// Utilisé par le flux « publier une offre » depuis la barre de navigation.
  static Future<void> checkSubscriptionAndProceed({
    required BuildContext context,
    required VoidCallback onProceed,
  }) {
    return checkCertifiedPremiumForSensitiveAction(
      context: context,
      onProceed: onProceed,
    );
  }
}
