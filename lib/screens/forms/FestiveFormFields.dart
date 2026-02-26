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
  }) : super(key: key);

  @override
  _FestiveFormFieldsState createState() => _FestiveFormFieldsState();
}

class _FestiveFormFieldsState extends State<FestiveFormFields> {
  // Styles
  final Color _primaryBlue = const Color(0xFF1976D2);
  final Color _borderColor = Colors.grey.shade300;
  final double _bodySize = 14.0;
  final double _smallSpace = 12.0;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Usage and Capacity with labels
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel("Type d'événement", widget.usageError != null),
                  _buildDropdown(
                    value: widget.initUsage,
                    items: ['Mariage', 'Conférence', 'Anniversaire', 'Concert', 'Autre'],
                    label: "Sélectionnez",
                    onChanged: widget.onUsageChanged,
                    errorText: widget.usageError,
                  ),
                ],
              ),
            ),
            SizedBox(width: _smallSpace),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel("Capacité (pers.)", widget.capacityError != null),
                  _buildModernFeatureInput(
                    controller: widget.capacityController,
                    label: '0',
                    icon: Icons.groups_rounded,
                    color: Color(0xFF4B5563).withOpacity(0.1),
                    iconColor: Color(0xFF4B5563),
                    errorText: widget.capacityError,
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: _smallSpace),
        
        // Toggles
        Row(
          children: [
            Expanded(
              child: _buildSwitchTile(
                'Décoration ?', 
                widget.isDecore, 
                widget.onDecoreChanged
              ),
            ),
            SizedBox(width: _smallSpace),
            Expanded(
              child: _buildSwitchTile(
                'Piste de danse ?', 
                widget.pisteDanse, 
                widget.onPisteDanseChanged
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

  Widget _buildDropdown({
    required String? value,
    required List<String> items,
    required String label,
    required Function(String?) onChanged,
    String? errorText,
  }) {
    final bool hasError = errorText != null && errorText.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 50,
          padding: EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hasError ? Colors.red : _borderColor,
              width: hasError ? 1.5 : 1.0,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              hint: Text(label, style: TextStyle(fontSize: _bodySize, color: Colors.grey)),
              isExpanded: true,
              items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(left: 8.0, top: 4.0),
            child: Text(
              errorText,
              style: TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.w500),
            ),
          ),
      ],
    );
  }

  Widget _buildModernFeatureInput({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required Color color,
    required Color iconColor,
    String? errorText,
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
        contentPadding: EdgeInsets.symmetric(horizontal: 8),
        visualDensity: VisualDensity.compact,
        dense: true,
      ),
    );
  }
}
