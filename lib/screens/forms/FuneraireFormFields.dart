import 'package:flutter/material.dart';

class FuneraireFormFields extends StatelessWidget {
  final TextEditingController capacityController;
  final String? capacityError;

  const FuneraireFormFields({
    Key? key,
    required this.capacityController,
    this.capacityError,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 8.0,
          mainAxisSpacing: 8.0,
          childAspectRatio: 3.2,
          children: [
            _buildModernFeatureInput(
              controller: capacityController,
              label: 'Capacité (pers.)',
              icon: Icons.groups_rounded,
              color: const Color(0xFF4B5563).withOpacity(0.1),
              iconColor: const Color(0xFF4B5563),
              errorText: capacityError,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildModernFeatureInput({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    Color? color,
    Color? iconColor,
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
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
