import 'package:flutter/material.dart';

import 'package:casa/utils/listing_form_chrome.dart';

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
    return ListingFormChrome.text(
      controller: capacityController,
      label: 'Capacité (personnes)',
      hint: 'Ex. 150',
      icon: Icons.groups_outlined,
      errorText: capacityError,
      required: true,
      keyboardType: TextInputType.number,
      onTap: onCapacityInteracted,
    );
  }
}
