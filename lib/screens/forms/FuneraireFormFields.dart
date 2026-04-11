import 'package:flutter/material.dart';

class FuneraireFormFields extends StatelessWidget {
  final TextEditingController capacityController;
  final String? capacityError;
  final VoidCallback? onCapacityInteracted;

  const FuneraireFormFields({
    Key? key,
    required this.capacityController,
    this.capacityError,
    this.onCapacityInteracted,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bool hasError = capacityError != null && capacityError!.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel("Capacité (pers.)", hasError),
        _buildModernFeatureInput(
          controller: capacityController,
          label: '0',
          icon: Icons.groups_rounded,
          color: const Color(0xFF4B5563).withOpacity(0.1),
          iconColor: const Color(0xFF4B5563),
          errorText: capacityError,
          onInteract: onCapacityInteracted,
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
    Color? color,
    Color? iconColor,
    String? errorText,
    VoidCallback? onInteract,
  }) {
    final hasError = errorText != null && errorText.isNotEmpty;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 50,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hasError ? Colors.red : Colors.grey.shade300,
              width: hasError ? 1.5 : 1.0,
            ),
          ),
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            onTap: () => onInteract?.call(),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            decoration: InputDecoration(
              hintText: label,
              hintStyle: TextStyle(fontSize: 14, color: Colors.grey[400], fontWeight: FontWeight.normal),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              isDense: true,
            ),
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
}
