import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// Formulaire création de chambre (`POST …/private/property/hotels/chambre`).
class HotelRoomFormFields extends StatelessWidget {
  final TextEditingController titleController;
  final TextEditingController descriptionController;
  final TextEditingController numberPieceController;
  final TextEditingController priceController;
  final TextEditingController priceHeureController;
  final int deviseId;
  final ValueChanged<int> onDeviseChanged;
  final bool isAvailable;
  final bool listingActive;
  final ValueChanged<bool> onIsAvailableChanged;
  final ValueChanged<bool> onListingActiveChanged;
  final String? titleError;

  const HotelRoomFormFields({
    Key? key,
    required this.titleController,
    required this.descriptionController,
    required this.numberPieceController,
    required this.priceController,
    required this.priceHeureController,
    required this.deviseId,
    required this.onDeviseChanged,
    required this.isAvailable,
    required this.listingActive,
    required this.onIsAvailableChanged,
    required this.onListingActiveChanged,
    this.titleError,
  }) : super(key: key);

  static const Color _primary = Color(0xFF1976D2);
  static const Color _primarySoft = Color(0xFF64B5F6);

  @override
  Widget build(BuildContext context) {
    final hasTitleError = titleError != null && titleError!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _compactField(
          context: context,
          controller: titleController,
          label: 'Titre de la chambre *',
          icon: FontAwesomeIcons.bed,
          iconColor: _primary,
          error: hasTitleError,
        ),
        if (hasTitleError)
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 4),
            child: Text(titleError!, style: const TextStyle(color: Colors.red, fontSize: 11)),
          ),
        const SizedBox(height: 12),
        _multilineField(
          context: context,
          controller: descriptionController,
          label: 'Description',
          hint: 'Surface, vue, lits, services…',
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _compactField(
                context: context,
                controller: numberPieceController,
                label: 'Nb. pièces',
                icon: FontAwesomeIcons.doorOpen,
                iconColor: _primary,
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _deviseDropdown(context),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _compactField(
          context: context,
          controller: priceController,
          label: 'Prix',
          icon: FontAwesomeIcons.moneyBill1,
          iconColor: _primary,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        const SizedBox(height: 12),
        _compactField(
          context: context,
          controller: priceHeureController,
          label: 'Tarif horaire (texte)',
          hint: 'ex. 25 \$ / h',
          icon: FontAwesomeIcons.clock,
          iconColor: _primary,
        ),
        const SizedBox(height: 16),
        _switchRow(context, 'Chambre disponible', isAvailable, onIsAvailableChanged),
        const SizedBox(height: 8),
        _switchRow(context, 'Annonce active', listingActive, onListingActiveChanged),
      ],
    );
  }

  Widget _deviseDropdown(BuildContext context) {
    final base = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (_primarySoft).withOpacity(0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.currency_exchange_rounded, size: 16, color: _primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                isExpanded: true,
                value: deviseId == 1 ? 1 : 2,
                itemHeight: 48,
                items: [
                  DropdownMenuItem(
                    value: 1,
                    child: Text('FC', style: base.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  ),
                  DropdownMenuItem(
                    value: 2,
                    child: Text('\$', style: base.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) onDeviseChanged(v);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _switchRow(BuildContext context, String title, bool value, ValueChanged<bool> onChanged) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: SwitchListTile(
        dense: true,
        title: Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        value: value,
        activeColor: _primary,
        onChanged: onChanged,
      ),
    );
  }

  Widget _compactField({
    required BuildContext context,
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required Color iconColor,
    String? hint,
    TextInputType? keyboardType,
    bool error = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: error ? Colors.red : Colors.grey.shade300, width: error ? 1.5 : 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.only(left: 6),
            decoration: BoxDecoration(
              color: (_primarySoft).withOpacity(0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: error ? Colors.red : Colors.grey.shade600,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                TextField(
                  controller: controller,
                  keyboardType: keyboardType,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    hintText: hint,
                    hintStyle: TextStyle(color: Colors.grey.shade300),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _multilineField({
    required BuildContext context,
    required TextEditingController controller,
    required String label,
    String? hint,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w700,
                ),
          ),
          TextField(
            controller: controller,
            maxLines: 3,
            style: Theme.of(context).textTheme.bodyMedium,
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey.shade300),
            ),
          ),
        ],
      ),
    );
  }
}
