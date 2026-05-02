import 'package:flutter/material.dart';

import '../utils/property_availability_ui.dart';

/// Pastille liste : vert « Disponible » si [sold] est false ou null ; rouge si [sold] == true ou retrait.
/// [available] est conservé pour compatibilité d’appel ; la logique suit uniquement [sold] via [PropertyAvailabilityUi].
class PropertyListingStatusChip extends StatelessWidget {
  final bool? sold;
  final String? transactionType;
  final bool? available;
  final bool listingAllowed;
  final bool compact;
  /// Sur photo sombre (ex. carte accueil) : texte un peu plus grand + léger contour blanc pour la lisibilité.
  final bool onDarkBackground;

  static const Color _success = Color(0xFF00B894);
  static const Color _error = Color(0xFFD63031);

  const PropertyListingStatusChip({
    Key? key,
    required this.sold,
    this.transactionType,
    this.available,
    this.listingAllowed = true,
    this.compact = false,
    this.onDarkBackground = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final canVisit = PropertyAvailabilityUi.isListingAvailableForVisit(
      sold: sold,
      available: available,
      listingAllowed: listingAllowed,
    );
    final statusLabel = PropertyAvailabilityUi.listingStatusLabel(
      sold: sold,
      available: available,
      transactionType: transactionType,
      listingAllowed: listingAllowed,
    );
    final rawChipText = statusLabel ?? 'Disponible';
    final chipText = (rawChipText.toLowerCase().trim() == 'non disponible')
        ? 'Non dispo…'
        : rawChipText;

    final double fontSize = onDarkBackground
        ? (compact ? 10 : 11)
        : (compact ? 9 : 10);
    final hPad = onDarkBackground ? (compact ? 8.0 : 10.0) : (compact ? 6.0 : 8.0);
    final vPad = onDarkBackground ? (compact ? 4.0 : 5.0) : (compact ? 3.0 : 4.0);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
      decoration: BoxDecoration(
        color: canVisit ? _success.withOpacity(0.95) : _error.withOpacity(0.95),
        borderRadius: BorderRadius.circular(compact ? 8 : 12),
        border: onDarkBackground
            ? Border.all(color: Colors.white.withOpacity(0.5), width: 1)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(onDarkBackground ? 0.35 : 0.2),
            blurRadius: onDarkBackground ? 6 : 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Text(
        chipText,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        softWrap: false,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: fontSize,
          letterSpacing: onDarkBackground ? 0.2 : 0,
          shadows: onDarkBackground
              ? [
                  Shadow(
                    color: Colors.black.withOpacity(0.45),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
      ),
    );
  }
}

/// Pastille négative uniquement lorsque [sold] == true ([available] non utilisé).
class PropertySoldBadge extends StatelessWidget {
  final bool? sold;
  final String? transactionType;
  final bool? available;
  final bool listingAllowed;

  const PropertySoldBadge({
    Key? key,
    required this.sold,
    this.transactionType,
    this.available,
    this.listingAllowed = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!listingAllowed) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black87.withOpacity(0.88),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'Retiré',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 11,
          ),
        ),
      );
    }
    final String? label = PropertyAvailabilityUi.soldBadgeLabel(
      sold: sold,
      transactionType: transactionType,
    );
    if (label == null) return const SizedBox.shrink();

    final isVendu = label == 'Vendu';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isVendu
            ? Colors.red.shade700.withOpacity(0.92)
            : Colors.black87.withOpacity(0.88),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}
