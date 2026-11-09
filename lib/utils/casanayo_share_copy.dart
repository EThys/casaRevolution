/// Liens et textes de partage communs (site web, boutiques).
class CasanayoShareCopy {
  CasanayoShareCopy._();

  static const String website = 'https://casanayo.com/';
  static const String playStore =
      'https://play.google.com/store/apps/details?id=com.casa.casa.casa&pcampaignid=web_share';
  static const String appStore =
      'https://apps.apple.com/fr/app/casanayo/id6757759953?l=en-GB';

  static const String shareAppSubject = "Partagez l'application CasaNayo";

  static const int _idSalt = 45821;

  /// Même masque que le site : le numéro interne ne paraît pas dans le lien.
  static String encodeListingId(int id) => (id + _idSalt).toRadixString(36).toUpperCase();

  static int? decodeListingId(String token) {
    final raw = token.trim();
    if (raw.isEmpty) return null;
    if (RegExp(r'^\d+$').hasMatch(raw)) {
      final numeric = int.tryParse(raw);
      if (numeric == null || numeric <= 0) return null;
      return numeric;
    }
    final parsed = int.tryParse(raw.toLowerCase(), radix: 36);
    if (parsed == null) return null;
    final id = parsed - _idSalt;
    if (id <= 0) return null;
    return id;
  }

  /// Lien unique : l'app s'ouvre sur la fiche, sinon la page web envoie vers la boutique.
  static String propertyOpenLink(int id, {String kind = 'property'}) {
    final safeKind = kind.trim().isEmpty ? 'property' : kind.trim();
    final token = encodeListingId(id);
    return 'https://casanayo.com/open/property/$token?kind=$safeKind';
  }

  static String serviceOpenLink(int id) =>
      'https://casanayo.com/open/service/${encodeListingId(id)}';

  static String joinPlace(List<String?> parts) {
    final seen = <String>{};
    final lines = <String>[];
    for (final part in parts) {
      final text = part?.trim() ?? '';
      if (text.isEmpty) continue;
      final key = text.toLowerCase();
      if (seen.contains(key)) continue;
      seen.add(key);
      lines.add(text);
    }
    return lines.join(', ');
  }

  static String kindForPropertyType(int? typeId) {
    switch (typeId) {
      case 4:
        return 'bureau';
      case 5:
        return 'hotel';
      case 7:
        return 'funeraire';
      case 8:
        return 'festive';
      case 9:
        return 'terrain';
      case 6:
      case 10:
      case 11:
        return 'vacance';
      default:
        return 'property';
    }
  }

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
    String? openUrl,
  }) {
    if (openUrl != null && openUrl.trim().isNotEmpty) {
      return '${openUrl.trim()}\n\n'
          "Retrouvez plus de détails dans l'application CasaNayo.";
    }
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
