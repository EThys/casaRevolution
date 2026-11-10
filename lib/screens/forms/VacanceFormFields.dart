import 'package:flutter/material.dart';

import 'package:casa/utils/listing_form_chrome.dart';

class VacanceFormFields extends StatefulWidget {
  final TextEditingController dateController;
  final TextEditingController heureController;
  final TextEditingController capacityController;
  final TextEditingController noteController;
  final TextEditingController offreController;
  final String? selectedPriceCombo;
  final Function(String?) onPriceComboChanged;

  final String? dateError;
  final String? timeError;
  final String? capacityError;
  final VoidCallback? onDateChanged;
  final VoidCallback? onTimeChanged;
  final VoidCallback? onCapacityChanged;

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
    this.onDateChanged,
    this.onTimeChanged,
    this.onCapacityChanged,
  }) : super(key: key);

  @override
  _VacanceFormFieldsState createState() => _VacanceFormFieldsState();
}

class _VacanceFormFieldsState extends State<VacanceFormFields> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ListingFormChrome.text(
                controller: widget.dateController,
                label: 'Date',
                hint: 'Choisir',
                icon: Icons.calendar_today_rounded,
                errorText: widget.dateError,
                required: true,
                readOnly: true,
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2030),
                  );
                  if (date != null) {
                    widget.dateController.text =
                        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                    widget.onDateChanged?.call();
                  }
                },
              ),
            ),
            const SizedBox(width: ListingFormChrome.gap),
            Expanded(
              child: ListingFormChrome.text(
                controller: widget.heureController,
                label: 'Heure',
                hint: 'Choisir',
                icon: Icons.access_time_rounded,
                errorText: widget.timeError,
                required: true,
                readOnly: true,
                onTap: () async {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.now(),
                  );
                  if (time != null) {
                    widget.heureController.text =
                        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
                    widget.onTimeChanged?.call();
                  }
                },
              ),
            ),
          ],
        ),
        ListingFormChrome.space,
        ListingFormChrome.text(
          controller: widget.capacityController,
          label: 'Capacité (personnes)',
          hint: 'Ex. 4',
          icon: Icons.groups_outlined,
          errorText: widget.capacityError,
          required: true,
          keyboardType: TextInputType.number,
          onChanged: (_) => widget.onCapacityChanged?.call(),
        ),
        ListingFormChrome.space,
        ListingFormChrome.text(
          controller: widget.noteController,
          label: 'Note',
          hint: 'Information importante',
          icon: Icons.notes_rounded,
        ),
        ListingFormChrome.space,
        ListingFormChrome.text(
          controller: widget.offreController,
          label: 'Offre spéciale',
          hint: 'Ex. -20 % le week-end',
          icon: Icons.local_offer_outlined,
        ),
        ListingFormChrome.space,
        ListingFormChrome.menu(
          label: 'Type de tarif',
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: widget.selectedPriceCombo,
              hint: Text('Choisir', style: TextStyle(fontSize: 15, color: Colors.grey.shade400)),
              isExpanded: true,
              dropdownColor: Colors.white,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF1A1D26)),
              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: ListingFormChrome.primary),
              items: ['Par Nuit', 'Par Semaine', 'Par Mois', 'Par Personne']
                  .map((item) => DropdownMenuItem(
                        value: item,
                        child: Text(item, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF1A1D26))),
                      ))
                  .toList(),
              onChanged: widget.onPriceComboChanged,
            ),
          ),
        ),
      ],
    );
  }
}
