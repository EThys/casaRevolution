import 'package:flutter/material.dart';

class TerrainFormFields extends StatefulWidget {
  final TextEditingController surfaceController;
  final String? surfaceError;

  const TerrainFormFields({
    Key? key,
    required this.surfaceController,
    this.surfaceError,
  }) : super(key: key);

  @override
  _TerrainFormFieldsState createState() => _TerrainFormFieldsState();
}

class _TerrainFormFieldsState extends State<TerrainFormFields> {
  @override
  Widget build(BuildContext context) {
    final bool hasError = widget.surfaceError != null && widget.surfaceError!.isNotEmpty;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(bottom: 8, left: 4),
          child: Row(
            children: [
              Text(
                "Superficie (ex: 500m², 20x25)",
                style: TextStyle(
                  fontSize: 14,
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
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hasError ? Colors.red : Colors.grey.shade300,
              width: hasError ? 1.5 : 1.0,
            ),
          ),
          child: TextField(
            controller: widget.surfaceController,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: "Entrez la superficie ou les dimensions",
              hintStyle: TextStyle(fontSize: 14, color: Colors.grey[400], fontWeight: FontWeight.normal),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              isDense: true,
            ),
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(left: 8.0, top: 4.0),
            child: Text(
              widget.surfaceError!,
              style: const TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.w500),
            ),
          ),
        const SizedBox(height: 16),
      ],
    );
  }
}
