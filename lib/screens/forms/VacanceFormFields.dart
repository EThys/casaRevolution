import 'package:flutter/material.dart';

class VacanceFormFields extends StatefulWidget {
  final TextEditingController dateController;
  final TextEditingController heureController;
  final TextEditingController capacityController;
  final TextEditingController noteController;
  final TextEditingController offreController;
  final String? selectedPriceCombo;
  final Function(String?) onPriceComboChanged;
  
  // Validation errors
  final String? dateError;
  final String? timeError;
  final String? capacityError;
  final VoidCallback? onCapacityInteracted;

  const VacanceFormFields({
    Key? key,
    required this.dateController,
    required this.heureController,
    required this.capacityController,
    required this.noteController,
    required this.offreController,
    required this.selectedPriceCombo,
    required this.onPriceComboChanged,
    this.dateError,
    this.timeError,
    this.capacityError,
    this.onCapacityInteracted,
  }) : super(key: key);

  @override
  _VacanceFormFieldsState createState() => _VacanceFormFieldsState();
}

class _VacanceFormFieldsState extends State<VacanceFormFields> {
  final Color _primaryColor = const Color(0xFF1E3A8A); 
  final Color _borderColor = const Color(0xFFE9ECEF);
  final double _smallSpace = 8.0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Date et Heure
        Row(
          children: [
            Expanded(
              child: _buildModernFeatureInput(
                controller: widget.dateController,
                label: 'Date',
                icon: Icons.calendar_today,
                color: const Color(0xFFEAB308).withOpacity(0.1),
                iconColor: const Color(0xFFEAB308),
                errorText: widget.dateError,
                readOnly: true,
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2030),
                  );
                  if (date != null) {
                    widget.dateController.text = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
                  }
                }
              ),
            ),
            SizedBox(width: _smallSpace),
            Expanded(
              child: _buildModernFeatureInput(
                controller: widget.heureController,
                label: 'Heure',
                icon: Icons.access_time,
                color: const Color(0xFFEAB308).withOpacity(0.1),
                iconColor: const Color(0xFFEAB308),
                errorText: widget.timeError,
                readOnly: true,
                onTap: () async {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.now(),
                  );
                  if (time != null) {
                    widget.heureController.text = "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";
                  }
                }
              ),
            ),
          ],
        ),
        SizedBox(height: _smallSpace),
        
        GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: _smallSpace,
            mainAxisSpacing: _smallSpace,
            childAspectRatio: 3.2,
            children: [
               _buildModernFeatureInput(
                  controller: widget.capacityController,
                  label: 'Capacité',
                  icon: Icons.people_outline,
                  color: const Color(0xFFEC4899).withOpacity(0.1),
                  iconColor: const Color(0xFFEC4899),
                  errorText: widget.capacityError,
                  onFieldTap: widget.onCapacityInteracted,
               ),
            ]
        ),
        SizedBox(height: _smallSpace),
        
        // Note
        _buildModernTextField(
          controller: widget.noteController,
          label: 'Note',
          hint: 'Information importante...',
          icon: Icons.note,
        ),
        SizedBox(height: _smallSpace),

        // Offre
        _buildModernTextField(
          controller: widget.offreController,
          label: 'Offre spéciale',
          hint: 'Ex: -20% pour le weekend...',
          icon: Icons.local_offer,
        ),
        SizedBox(height: _smallSpace),
        
        // PriceCombo
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _borderColor),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: widget.selectedPriceCombo,
              hint: const Text('Type de tarif', style: TextStyle(fontSize: 14)),
              isExpanded: true,
              items: ['Par Nuit', 'Par Semaine', 'Par Mois', 'Par Personne']
                  .map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: widget.onPriceComboChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor),
      ),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
            hintText: hint,
            labelText: label,
            prefixIcon: Icon(icon, color: _primaryColor),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
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
    VoidCallback? onFieldTap,
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
      child: Stack(
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
                        onTap: () {
                          onFieldTap?.call();
                          onTap?.call();
                        },
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
        ],
      ),
    );
  }
}
