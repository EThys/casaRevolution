import 'package:flutter/material.dart';

/// Champs spécifiques à la création d’hôtel (aligné dashboard `hotels/new`).
class HotelFormFields extends StatelessWidget {
  final String? hotelTypeLabel;
  final bool propertyTypeReady;
  final bool isAvailable;
  final bool listingActive;
  final ValueChanged<bool> onIsAvailableChanged;
  final ValueChanged<bool> onListingActiveChanged;

  const HotelFormFields({
    Key? key,
    required this.hotelTypeLabel,
    required this.propertyTypeReady,
    required this.isAvailable,
    required this.listingActive,
    required this.onIsAvailableChanged,
    required this.onListingActiveChanged,
  }) : super(key: key);

  static const Color _primary = Color(0xFF1976D2);
  static const Color _primarySoft = Color(0xFF64B5F6);

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoCard(
          context,
          icon: Icons.apartment_rounded,
          title: 'Type de bien',
          value: propertyTypeReady && (hotelTypeLabel != null && hotelTypeLabel!.isNotEmpty)
              ? hotelTypeLabel!
              : 'Chargement du type…',
          muted: !propertyTypeReady,
        ),
        const SizedBox(height: 20),
        _switchCard(
          context: context,
          title: 'Visible / disponible',
          subtitle: 'Les voyageurs voient que l’établissement est ouvert',
          value: isAvailable,
          onChanged: onIsAvailableChanged,
        ),
        const SizedBox(height: 12),
        _switchCard(
          context: context,
          title: 'Annonce active',
          subtitle: 'Publication en ligne sur le catalogue',
          value: listingActive,
          onChanged: onListingActiveChanged,
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline_rounded, size: 18, color: _primary.withOpacity(0.8)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Les tarifs des chambres se gèrent après la création, depuis « Mes hôtels ».',
                style: t.bodySmall?.copyWith(color: Colors.grey.shade700, height: 1.35, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _infoCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
    bool muted = false,
  }) {
    final t = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_primary.withOpacity(0.16), _primarySoft.withOpacity(0.14)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: _primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: t.labelLarge?.copyWith(color: Colors.grey.shade700, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: t.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: muted ? Colors.grey.shade600 : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _switchCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final t = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        title: Text(
          title,
          style: t.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          subtitle,
          style: t.bodySmall?.copyWith(color: Colors.grey.shade600, height: 1.25),
        ),
        value: value,
        activeColor: _primary,
        onChanged: onChanged,
      ),
    );
  }
}
