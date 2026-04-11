import 'package:flutter/material.dart';

class FestiveFormFields extends StatefulWidget {
  final TextEditingController capacityController;
  final String? usageError;
  final String? capacityError;
  final String? initUsage;
  final bool isDecore;
  final bool pisteDanse;
  final Function(String?) onUsageChanged;
  final Function(bool) onDecoreChanged;
  final Function(bool) onPisteDanseChanged;
  final VoidCallback? onCapacityInteracted;
  final VoidCallback? onUsageInteracted;

  const FestiveFormFields({
    Key? key,
    required this.capacityController,
    this.usageError,
    this.capacityError,
    this.initUsage,
    required this.isDecore,
    required this.pisteDanse,
    required this.onUsageChanged,
    required this.onDecoreChanged,
    required this.onPisteDanseChanged,
    this.onCapacityInteracted,
    this.onUsageInteracted,
  }) : super(key: key);

  static const List<String> eventTypes = [
    'Mariage',
    'Conférence',
    'Anniversaire',
    'Concert',
    'Autre',
  ];

  @override
  State<FestiveFormFields> createState() => _FestiveFormFieldsState();
}

class _FestiveFormFieldsState extends State<FestiveFormFields> {
  final Color _primaryBlue = const Color(0xFF1976D2);
  final Color _borderColor = Colors.grey.shade300;
  final double _bodySize = 14.0;
  final double _smallSpace = 12.0;

  late Set<String> _selectedUsages;

  @override
  void initState() {
    super.initState();
    _selectedUsages = _parseInit(widget.initUsage);
  }

  @override
  void didUpdateWidget(FestiveFormFields oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initUsage != oldWidget.initUsage) {
      _selectedUsages = _parseInit(widget.initUsage);
    }
  }

  Set<String> _parseInit(String? raw) {
    if (raw == null || raw.trim().isEmpty) return {};
    return raw
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toSet();
  }

  void _emitUsage() {
    final list = _selectedUsages.toList()..sort();
    widget.onUsageChanged(list.join(', '));
  }

  void _toggleUsage(String type, bool selected) {
    setState(() {
      if (selected) {
        _selectedUsages.add(type);
      } else {
        _selectedUsages.remove(type);
      }
    });
    _emitUsage();
    widget.onUsageInteracted?.call();
  }

  @override
  Widget build(BuildContext context) {
    final usageHasError = widget.usageError != null && widget.usageError!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel("Types d'événement", usageHasError),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: FestiveFormFields.eventTypes.map((type) {
            final sel = _selectedUsages.contains(type);
            return FilterChip(
              label: Text(type, style: TextStyle(fontSize: 13, fontWeight: sel ? FontWeight.w600 : FontWeight.w500)),
              selected: sel,
              selectedColor: _primaryBlue.withOpacity(0.2),
              checkmarkColor: _primaryBlue,
              onSelected: (v) => _toggleUsage(type, v),
              side: BorderSide(
                color: usageHasError ? Colors.red : _borderColor,
                width: usageHasError ? 1.5 : 1,
              ),
            );
          }).toList(),
        ),
        if (usageHasError)
          Padding(
            padding: const EdgeInsets.only(left: 4.0, top: 6.0),
            child: Text(
              widget.usageError!,
              style: const TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.w500),
            ),
          ),
        SizedBox(height: _smallSpace),
        _buildLabel("Capacité (pers.)", widget.capacityError != null && widget.capacityError!.isNotEmpty),
        _buildModernFeatureInput(
          controller: widget.capacityController,
          label: '0',
          icon: Icons.groups_rounded,
          color: const Color(0xFF4B5563).withOpacity(0.1),
          iconColor: const Color(0xFF4B5563),
          errorText: widget.capacityError,
          onInteract: widget.onCapacityInteracted,
        ),
        SizedBox(height: _smallSpace),
        Row(
          children: [
            Expanded(
              child: _buildSwitchTile(
                'Décoration ?',
                widget.isDecore,
                widget.onDecoreChanged,
              ),
            ),
            SizedBox(width: _smallSpace),
            Expanded(
              child: _buildSwitchTile(
                'Piste de danse ?',
                widget.pisteDanse,
                widget.onPisteDanseChanged,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLabel(String label, bool hasError) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: hasError ? Colors.red : const Color(0xFF1A1D26),
            ),
          ),
          const Text(
            ' *',
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildModernFeatureInput({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required Color color,
    required Color iconColor,
    String? errorText,
    VoidCallback? onInteract,
  }) {
    final bool hasError = errorText != null && errorText.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 50,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hasError ? Colors.red : _borderColor,
              width: hasError ? 1.5 : 1.0,
            ),
          ),
          child: TextField(
            controller: controller,
            style: TextStyle(fontSize: _bodySize, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: label,
              hintStyle: TextStyle(fontSize: _bodySize, color: Colors.grey, fontWeight: FontWeight.normal),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              isDense: true,
            ),
            keyboardType: TextInputType.number,
            onTap: () => onInteract?.call(),
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(left: 8.0, top: 4.0),
            child: Text(
              errorText,
              style: const TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.w500),
            ),
          ),
      ],
    );
  }

  Widget _buildSwitchTile(String title, bool value, Function(bool) onChanged) {
    return Container(
      decoration: BoxDecoration(
        color: value ? _primaryBlue.withOpacity(0.1) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: value ? _primaryBlue.withOpacity(0.3) : _borderColor,
        ),
      ),
      child: SwitchListTile(
        title: Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: value ? FontWeight.w600 : FontWeight.normal,
            color: value ? _primaryBlue : Colors.grey.shade700,
          ),
        ),
        value: value,
        onChanged: onChanged,
        activeColor: _primaryBlue,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        visualDensity: VisualDensity.compact,
        dense: true,
      ),
    );
  }
}
