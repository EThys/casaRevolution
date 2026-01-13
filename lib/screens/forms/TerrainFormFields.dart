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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        /*
        const SizedBox(height: 16),
        const Text(
          "Type de transaction",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        // Removed validation redundancy
        */
        const SizedBox(height: 16),
        const Text(
          "Superficie (ex: 500m², 20x25)",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const SizedBox(height: 8),
        TextFormField(
          controller: widget.surfaceController,
          decoration: InputDecoration(
            hintText: "Entrez la superficie ou les dimensions",
            filled: true,
            fillColor: Colors.grey[100],
            errorText: widget.surfaceError,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'La superficie est requise';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
