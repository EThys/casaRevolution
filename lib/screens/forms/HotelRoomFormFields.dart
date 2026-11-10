import 'package:casa/utils/hotel_room_price.dart';
import 'package:casa/utils/listing_form_chrome.dart';
import 'package:casa/widgets/casa_choice_sheet.dart';
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

class _TarifOption {
  final String key;
  final String label;

  const _TarifOption(this.key, this.label);
}

class _HotelRoomFormFieldsState extends State<HotelRoomFormFields> {
  static const Color _primary = Color(0xFF1976D2);
  static const Color _primarySoft = Color(0xFF64B5F6);
  static const List<_TarifOption> _periods = [
    _TarifOption('nuit', 'Par nuit'),
    _TarifOption('heure', 'Par heure'),
    _TarifOption('jour', 'Par jour'),
    _TarifOption('séjour', 'Par séjour'),
    _TarifOption('semaine', 'Par semaine'),
    _TarifOption('mois', 'Par mois'),
  ];

  final TextEditingController _labelController = TextEditingController();
  String _selectedKey = 'nuit';

  _TarifOption get _selected =>
      _periods.firstWhere((option) => option.key == _selectedKey, orElse: () => _periods.first);

  @override
  void initState() {
    super.initState();
    _hydrateLabel();
    _labelController.addListener(_syncPriceHeure);
    _syncPriceHeure();
  }

  @override
  void dispose() {
    _labelController.removeListener(_syncPriceHeure);
    _labelController.dispose();
    super.dispose();
  }

  void _hydrateLabel() {
    final raw = widget.priceHeureController.text.trim();
    if (raw.isEmpty) return;
    final detected = hotelStayPeriodLabel(raw).toLowerCase();
    for (final option in _periods) {
      if (detected == option.label.toLowerCase()) {
        _selectedKey = option.key;
        break;
      }
    }
    var label = raw;
    for (final option in _periods) {
      label = label.replaceAll(RegExp(RegExp.escape(option.label), caseSensitive: false), '');
      label = label.replaceAll(RegExp('/\\s*${RegExp.escape(option.key)}', caseSensitive: false), '');
    }
    _labelController.text = label.replaceAll('·', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  void _syncPriceHeure() {
    final label = _labelController.text.trim();
    final period = _selected.label.toLowerCase();
    final next = label.isEmpty ? period : '$label · $period';
    if (widget.priceHeureController.text == next) return;
    widget.priceHeureController.text = next;
  }

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
        ListingFormChrome.priceDeviseRow(
          controller: widget.priceController,
          priceLabel: 'Prix',
          priceHint: 'ex. 50',
          priceRequired: false,
          deviseValue: widget.deviseId == 1 ? 'FC' : 'USD',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
          onDeviseTap: () async {
            final picked = await showCasaChoiceSheet<int>(
              context: context,
              title: 'Devise',
              icon: Icons.payments_rounded,
              selected: widget.deviseId,
              options: const [
                CasaChoice(value: 2, title: 'USD', subtitle: r'$'),
                CasaChoice(value: 1, title: 'FC', subtitle: 'CDF'),
              ],
            );
            if (picked != null) widget.onDeviseChanged(picked);
          },
        ),
        const SizedBox(height: 16),
        _sectionLabel(context, 'Tarif'),
        const SizedBox(height: 8),
        _tarifDropdown(context),
        const SizedBox(height: 12),
        _sectionLabel(context, 'Libellé du tarif'),
        const SizedBox(height: 8),
        _tarifLabelRow(context),
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

  Widget _tarifDropdown(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedKey,
          isExpanded: true,
          borderRadius: BorderRadius.circular(12),
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: _primary),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1A1D26),
              ),
          items: [
            for (final option in _periods)
              DropdownMenuItem<String>(
                value: option.key,
                child: Text(option.label),
              ),
          ],
          onChanged: (value) {
            if (value == null) return;
            setState(() => _selectedKey = value);
            _syncPriceHeure();
          },
        ),
      ),
    );
  }

  Widget _tarifLabelRow(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: _tarifZone(
            context,
            caption: 'Libellé',
            child: TextField(
              controller: _labelController,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              decoration: InputDecoration(
                border: InputBorder.none,
                isCollapsed: true,
                isDense: true,
                contentPadding: EdgeInsets.zero,
                hintText: 'ex. Petit-déjeuner inclus',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.w600, fontSize: 14),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: _tarifZone(
            context,
            caption: 'Tarif',
            automatic: true,
            child: Text(
              _selected.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800, color: _primary, fontSize: 15),
            ),
          ),
        ),
      ],
    );
  }

  Widget _tarifZone(
    BuildContext context, {
    required String caption,
    required Widget child,
    bool automatic = false,
  }) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: automatic ? _primary.withOpacity(0.08) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: automatic ? _primary.withOpacity(0.35) : Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            caption,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w700,
                ),
          ),
          Expanded(child: Align(alignment: Alignment.centerLeft, child: child)),
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
