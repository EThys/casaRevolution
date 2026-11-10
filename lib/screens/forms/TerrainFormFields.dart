import 'package:flutter/material.dart';

import 'package:casa/utils/listing_form_chrome.dart';

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
    return ListingFormChrome.text(
      controller: widget.surfaceController,
      label: 'Superficie',
      hint: 'Ex. 500 ou 20x25',
      icon: Icons.square_foot_rounded,
      errorText: widget.surfaceError,
      required: true,
    );
  }
}
