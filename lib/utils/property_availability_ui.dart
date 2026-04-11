/// Affichage / logique commune : bien vendu ou disponible pour une visite.
///
/// Règle métier : **`sold` uniquement** — `sold == true` → libellé selon [transactionType] :
/// opération de **vente** → « Vendu », **location** → « Non disponible » ; `sold == false` ou `null`
/// → disponible (vert). [available] est ignoré ici.
/// [listingAllowed] == false : annonce retirée du catalogue (« Retiré »).
class PropertyAvailabilityUi {
  PropertyAvailabilityUi._();

  /// True si l’annonce est une vente (aligné API / formulaires : `vente`, etc.).
  static bool transactionIsSale(String? transactionType) {
    final t = (transactionType ?? '').toLowerCase().trim();
    if (t.isEmpty) return false;
    return t.contains('vente');
  }

  /// True si l’annonce est une location (aligné : `location`, `louer`, etc.).
  static bool transactionIsRent(String? transactionType) {
    final t = (transactionType ?? '').toLowerCase().trim();
    if (t.isEmpty) return false;
    return t.contains('location') ||
        t.contains('louer') ||
        t.contains('loyer') ||
        t.contains('rent');
  }

  /// Bloque la réservation / visite (bouton désactivé).
  static bool blocksSchedulingVisit({
    bool? sold,
    bool? available,
    bool listingAllowed = true,
  }) {
    if (!listingAllowed) return true;
    if (sold == true) return true;
    return false;
  }

  /// Texte lorsque [sold] est true : **vente** → « Vendu », **location** → « Non disponible ».
  /// Si le type est ambigu ou absent, on privilégie « Non disponible » (ne pas afficher « Vendu » à tort).
  static String? soldBadgeLabel({bool? sold, String? transactionType}) {
    if (sold != true) return null;
    final sale = transactionIsSale(transactionType);
    final rent = transactionIsRent(transactionType);
    if (sale && !rent) return 'Vendu';
    if (rent) return 'Non disponible';
    if (sale) return 'Vendu';
    return 'Non disponible';
  }

  /// Libellé pour pastille liste : uniquement selon [sold] (et retrait catalogue).
  static String? listingStatusLabel({
    bool? sold,
    bool? available,
    String? transactionType,
    bool listingAllowed = true,
  }) {
    if (!listingAllowed) return 'Retiré';
    return soldBadgeLabel(sold: sold, transactionType: transactionType);
  }

  static bool isListingAvailableForVisit({
    bool? sold,
    bool? available,
    bool listingAllowed = true,
  }) {
    return !blocksSchedulingVisit(
      sold: sold,
      available: available,
      listingAllowed: listingAllowed,
    );
  }
}
