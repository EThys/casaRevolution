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
  final Color _indigoColor = const Color(0xFF4F46E5);
  final Color _borderColor = Colors.grey.shade300;
  final double _bodySize = 14.0;
  final double _smallSpace = 12.0;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Grid for Usage and Capacity
        GridView.count(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: _smallSpace,
          mainAxisSpacing: _smallSpace,
          childAspectRatio: 3.2,
          children: [
            _buildDropdown(
              value: widget.initUsage,
              items: ['Mariage', 'Conférence', 'Anniversaire', 'Concert', 'Autre'],
              label: 'Type d\'événement',
              onChanged: widget.onUsageChanged,
              errorText: widget.usageError,
            ),
            _buildModernFeatureInput(
              controller: widget.capacityController,
              label: 'Capacité (pers.)',
              icon: Icons.groups_rounded,
              color: Color(0xFF4B5563).withOpacity(0.1),
              iconColor: Color(0xFF4B5563),
              errorText: widget.capacityError,
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

  Widget _buildDropdown({
    required String? value,
    required List<String> items,
    required String label,
    required Function(String?) onChanged,
    String? errorText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: errorText != null ? Colors.red.shade300 : _borderColor,
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
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(left: 8.0, top: 4.0),
            child: Text(
              errorText,
              style: TextStyle(color: Colors.red, fontSize: 11),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: errorText != null ? Colors.red.shade300 : _borderColor,
              ),
            ),
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: label,
                hintStyle: TextStyle(fontSize: _bodySize, color: Colors.grey),
                prefixIcon: Icon(icon, color: iconColor, size: 20),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              keyboardType: TextInputType.number,
            ),
          ),
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(left: 8.0, top: 4.0),
            child: Text(
              errorText,
              style: TextStyle(color: Colors.red, fontSize: 11),
            ),
          ),
      ],
    );
  }

  Widget _buildSwitchTile(String title, bool value, Function(bool) onChanged) {
    return Container(
      decoration: BoxDecoration(
        color: value ? _indigoColor.withOpacity(0.1) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: value ? _indigoColor.withOpacity(0.3) : _borderColor,
        ),
      ),
      child: SwitchListTile(
        title: Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: value ? FontWeight.w600 : FontWeight.normal,
            color: value ? _indigoColor : Colors.grey.shade700,
          ),
        ),
        value: value,
        onChanged: onChanged,
        activeColor: _indigoColor,
        contentPadding: EdgeInsets.symmetric(horizontal: 8),
        visualDensity: VisualDensity.compact,
        dense: true,
      ),
    );
  }
}
