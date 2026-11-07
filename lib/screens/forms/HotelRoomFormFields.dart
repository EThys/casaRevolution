import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// Formulaire création de chambre (`POST …/private/property/hotels/chambre`).
class HotelRoomFormFields extends StatefulWidget {
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

  @override
  State<HotelRoomFormFields> createState() => _HotelRoomFormFieldsState();
}

class _HotelRoomFormFieldsState extends State<HotelRoomFormFields> {
  static const Color _primary = Color(0xFF1976D2);
  static const Color _primarySoft = Color(0xFF64B5F6);

  String get _symbol => widget.deviseId == 1 ? 'FC' : r'$';

  int get _pieces {
    final value = int.tryParse(widget.numberPieceController.text.trim());
    if (value == null || value < 1) return 1;
    return value;
  }

  void _setPieces(int value) {
    final next = value.clamp(1, 30);
    widget.numberPieceController.text = '$next';
    setState(() {});
  }

  void _applyTarif(String period) {
    final amount = widget.priceController.text.trim();
    widget.priceHeureController.text =
        amount.isEmpty ? period : '$amount $_symbol $period';
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final hasTitleError = widget.titleError != null && widget.titleError!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _compactField(
          context: context,
          controller: widget.titleController,
          label: 'Titre de la chambre *',
          icon: FontAwesomeIcons.bed,
          iconColor: _primary,
          error: hasTitleError,
        ),
        if (hasTitleError)
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 4),
            child: Text(widget.titleError!, style: const TextStyle(color: Colors.red, fontSize: 11)),
          ),
        const SizedBox(height: 12),
        _multilineField(
          context: context,
          controller: widget.descriptionController,
          label: 'Description',
          hint: 'Surface, vue, lits, services…',
        ),
        const SizedBox(height: 16),
        _sectionLabel(context, 'Nombre de pièces'),
        const SizedBox(height: 8),
        _pieceStepper(context),
        const SizedBox(height: 16),
        _sectionLabel(context, 'Devise'),
        const SizedBox(height: 8),
        _deviseChoice(context),
        const SizedBox(height: 16),
        _sectionLabel(context, 'Prix'),
        const SizedBox(height: 8),
        _compactField(
          context: context,
          controller: widget.priceController,
          label: 'Montant',
          hint: 'ex. 50',
          icon: FontAwesomeIcons.moneyBill1,
          iconColor: _primary,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          suffix: _symbol,
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
        ),
        const SizedBox(height: 16),
        _sectionLabel(context, 'Tarif'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _tarifChip('nuit', '/ nuit'),
            _tarifChip('heure', '/ heure'),
            _tarifChip('jour', '/ jour'),
            _tarifChip('séjour', '/ séjour'),
          ],
        ),
        const SizedBox(height: 8),
        _compactField(
          context: context,
          controller: widget.priceHeureController,
          label: 'Libellé du tarif',
          hint: 'ex. 50 \$ / nuit',
          icon: FontAwesomeIcons.clock,
          iconColor: _primary,
        ),
        const SizedBox(height: 16),
        _switchRow(context, 'Chambre disponible', widget.isAvailable, widget.onIsAvailableChanged),
        const SizedBox(height: 8),
        _switchRow(context, 'Annonce active', widget.listingActive, widget.onListingActiveChanged),
      ],
    );
  }

  Widget _sectionLabel(BuildContext context, String text) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: const Color(0xFF1A1D26),
            fontWeight: FontWeight.w800,
          ),
    );
  }

  Widget _pieceStepper(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          _stepButton(Icons.remove_rounded, () => _setPieces(_pieces - 1)),
          Expanded(
            child: TextField(
              controller: widget.numberPieceController,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => setState(() {}),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                hintText: '1',
              ),
            ),
          ),
          _stepButton(Icons.add_rounded, () => _setPieces(_pieces + 1)),
        ],
      ),
    );
  }

  Widget _stepButton(IconData icon, VoidCallback onTap) {
    return Material(
      color: _primary.withOpacity(0.10),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: _primary),
        ),
      ),
    );
  }

  Widget _deviseChoice(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _deviseTile(context, id: 2, title: 'USD', subtitle: r'$')),
        const SizedBox(width: 10),
        Expanded(child: _deviseTile(context, id: 1, title: 'FC', subtitle: 'CDF')),
      ],
    );
  }

  Widget _deviseTile(BuildContext context, {required int id, required String title, required String subtitle}) {
    final selected = widget.deviseId == id;
    return Material(
      color: selected ? _primary : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => widget.onDeviseChanged(id),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? _primary : Colors.grey.shade300),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: selected ? Colors.white : const Color(0xFF1A1D26),
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white.withOpacity(0.9) : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tarifChip(String key, String label) {
    final selected = widget.priceHeureController.text.contains(label);
    return ChoiceChip(
      label: Text(key[0].toUpperCase() + key.substring(1)),
      selected: selected,
      selectedColor: _primary.withOpacity(0.16),
      labelStyle: TextStyle(
        fontWeight: FontWeight.w800,
        color: selected ? _primary : const Color(0xFF1A1D26),
      ),
      side: BorderSide(color: selected ? _primary : Colors.grey.shade300),
      onSelected: (_) => _applyTarif(label),
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
    String? suffix,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
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
              color: _primarySoft.withOpacity(0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
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
                    inputFormatters: inputFormatters,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      hintText: hint,
                      hintStyle: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (suffix != null)
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Text(
                suffix,
                style: const TextStyle(fontWeight: FontWeight.w900, color: _primary, fontSize: 16),
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
              hintStyle: TextStyle(color: Colors.grey.shade400),
            ),
          ),
        ],
      ),
    );
  }
}
