/// Liens et textes de partage communs (site web, boutiques).
class CasanayoShareCopy {
  CasanayoShareCopy._();

  static const String website = 'https://casanayo.com/';
  static const String playStore =
      'https://play.google.com/store/apps/details?id=com.casa.casa.casa&pcampaignid=web_share';
  static const String appStore =
      'https://apps.apple.com/fr/app/casanayo/id6757759953?l=en-GB';

  static const String shareAppSubject = "Partagez l'application CasaNayo";

  static String appInvitationMessage() =>
      "Découvrez CasaNayo !\n\n"
      "Votre plateforme de référence pour trouver une propriété, réserver un hôtel ou solliciter des services professionnels de qualité.\n\n"
      "Site web :\n$website\n\n"
      "Téléchargez l'application :\n\n"
      "Android :\n$playStore\n\n"
      "iOS :\n$appStore\n\n"
      "CasaNayo, l'immobilier en toute simplicité !";

  /// Bloc liens (même structure que [appInvitationMessage], sans l'intro générale).
  static String listingShareFooter({
    int? listingId,
    String? kindLabel,
  }) {
    final buf = StringBuffer()
      ..writeln('Site web :')
      ..writeln(website)
      ..writeln('')
      ..writeln("Téléchargez l'application :")
      ..writeln('')
      ..writeln('Android :')
      ..writeln(playStore)
      ..writeln('')
      ..writeln('iOS :')
      ..writeln(appStore);
    if (listingId != null &&
        kindLabel != null &&
        kindLabel.trim().isNotEmpty) {
      buf.writeln('');
      buf.writeln(
          "Réf. ${kindLabel.trim()} n°$listingId — retrouvable dans l'app CasaNayo.");
    } else if (listingId != null) {
      buf.writeln('');
      buf.writeln(
          "Réf. annonce n°$listingId — retrouvable dans l'app CasaNayo.");
    }
    buf.writeln('');
    buf.write("CasaNayo, l'immobilier en toute simplicité !");
    return buf.toString();
  }
}
