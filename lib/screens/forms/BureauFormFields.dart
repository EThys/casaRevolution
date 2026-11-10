import 'package:flutter/material.dart';

import 'package:casa/utils/listing_form_chrome.dart';

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
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListingFormChrome.text(
          controller: widget.areaController,
          label: 'Surface (m²)',
          hint: 'Ex. 80',
          icon: Icons.square_foot_rounded,
          errorText: widget.areaError,
          required: true,
          keyboardType: TextInputType.number,
        ),
        ListingFormChrome.space,
        ListingFormChrome.text(
          controller: widget.numberPieceController,
          label: 'Nombre de pièces',
          hint: 'Ex. 4',
          icon: Icons.meeting_room_outlined,
          errorText: widget.numberPieceError,
          required: true,
          keyboardType: TextInputType.number,
        ),
        ListingFormChrome.space,
        ListingFormChrome.text(
          controller: widget.roomMeetController,
          label: 'Salles de réunion',
          hint: 'Ex. 1',
          icon: Icons.groups_outlined,
          errorText: widget.roomMeetError,
          keyboardType: TextInputType.number,
        ),
        ListingFormChrome.space,
        ListingFormChrome.toggle(
          title: 'Étage',
          value: widget.hasFloor,
          onChanged: widget.onFloorChanged,
        ),
        ListingFormChrome.space,
        ListingFormChrome.toggle(
          title: 'Meublé',
          value: widget.isEquip,
          onChanged: widget.onEquipChanged,
        ),
      ],
    );
  }
}
