import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class BureauFormFields extends StatefulWidget {
  final TextEditingController areaController;
  final TextEditingController roomMeetController;
  final TextEditingController numberPieceController;
  final String? areaError;
  final String? roomMeetError;
  final String? numberPieceError;
  final bool isEquip;
  final bool hasFloor;
  final Function(bool) onEquipChanged;
  final Function(bool) onFloorChanged;

  const BureauFormFields({
    Key? key,
    required this.areaController,
    required this.roomMeetController,
    required this.numberPieceController,
    this.areaError,
    this.roomMeetError,
    this.numberPieceError,
    required this.isEquip,
    required this.hasFloor,
    required this.onEquipChanged,
    required this.onFloorChanged,
  }) : super(key: key);

  @override
  _BureauFormFieldsState createState() => _BureauFormFieldsState();
}

class _BureauFormFieldsState extends State<BureauFormFields> {
  // Styles reused from CreatePropertyPostPage/TerrainFormFields (approximate)
  final Color _primaryColor = const Color(0xFF1E3A8A); // CasaNayo Blue
  
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        /*
        const SizedBox(height: 16),
        const Text(
          "Type de transaction",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        // Transaction Type removed as it's redundant with Step 0
        */
        const SizedBox(height: 16),
        
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 3.2,
          children: [
            _buildModernFeatureInput(
              controller: widget.areaController,
              label: 'Surface (m²)',
              icon: FontAwesomeIcons.rulerCombined,
              color: const Color(0xFF0891B2).withOpacity(0.1),
              iconColor: const Color(0xFF0891B2),
              errorText: widget.areaError,
            ),
            _buildSwitchTile(
              'Étage ?', 
              widget.hasFloor, 
              widget.onFloorChanged
            ),
            _buildModernFeatureInput(
              controller: widget.roomMeetController,
              label: 'Salles réunion',
              icon: FontAwesomeIcons.handshake,
              color: const Color(0xFF6B46C1).withOpacity(0.1),
              iconColor: const Color(0xFF6B46C1),
              errorText: widget.roomMeetError,
            ),
            _buildModernFeatureInput(
              controller: widget.numberPieceController,
              label: 'Nbr. Pièces',
              icon: FontAwesomeIcons.doorOpen,
              color: const Color(0xFFEA580C).withOpacity(0.1),
              iconColor: const Color(0xFFEA580C),
              errorText: widget.numberPieceError,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildSwitchTile('Meublé ?', widget.isEquip, widget.onEquipChanged),
      ],
    );
  }

  Widget _buildModernFeatureInput({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    Color? color,
    Color? iconColor,
    bool readOnly = false,
    VoidCallback? onTap,
    String? suffix,
    String? errorText,
  }) {
    final hasError = errorText != null && errorText.isNotEmpty;
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasError ? Colors.red : Colors.grey.shade300,
          width: hasError ? 1.5 : 1.0,
        ),
      ),
      child: Stack( // Used Stack to potentially position error message
        children: [
           Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(left: 4),
                decoration: BoxDecoration(
                  color: color ?? Colors.blue.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 16, color: iconColor ?? Colors.blue),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 10,
                        color: hasError ? Colors.red : Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(
                      height: 24,
                      child: TextField(
                        controller: controller,
                        readOnly: onTap != null || readOnly,
                        onTap: onTap,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                          isDense: true,
                          hintText: '0',
                          hintStyle: TextStyle(color: Colors.grey[300]),
                          suffixText: suffix,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Icon(Icons.arrow_drop_down, color: Colors.grey),
                ),
            ],
          ),
          /* If needed, can add error text below, but for compact grid it might break layout. 
             Border color + label color change is often enough for compact forms. */
        ],
      ),
    );
  }

  Widget _buildSwitchTile(String title, bool value, Function(bool) onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: SwitchListTile(
        title: Text(
          title, 
          style: const TextStyle(
            fontWeight: FontWeight.w600, 
            fontSize: 12, // adjusted to fit grid
            color: Colors.black87
          )
        ),
        value: value,
        onChanged: onChanged,
        activeColor: _primaryColor,
        contentPadding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        dense: true,
      ),
    );
  }
}
