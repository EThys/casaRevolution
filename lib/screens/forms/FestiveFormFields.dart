import 'package:flutter/material.dart';

import 'package:casa/utils/listing_form_chrome.dart';

class FestiveFormFields extends StatefulWidget {
  final TextEditingController capacityController;
  final String? usageError;
  final String? capacityError;
  final String? initUsage;
  final bool isDecore;
  final bool pisteDanse;
  final Function(String?) onUsageChanged;
  final Function(bool) onDecoreChanged;
  final Function(bool) onPisteDanseChanged;
  final VoidCallback? onCapacityInteracted;
  final VoidCallback? onUsageInteracted;

  const FestiveFormFields({
    Key? key,
    required this.capacityController,
    this.usageError,
    this.capacityError,
    this.initUsage,
    required this.isDecore,
    required this.pisteDanse,
    required this.onUsageChanged,
    required this.onDecoreChanged,
    required this.onPisteDanseChanged,
    this.onCapacityInteracted,
    this.onUsageInteracted,
  }) : super(key: key);

  static const List<String> eventTypes = [
    'Mariage',
    'Conférence',
    'Anniversaire',
    'Concert',
    'Autre',
  ];

  @override
  State<FestiveFormFields> createState() => _FestiveFormFieldsState();
}

class _FestiveFormFieldsState extends State<FestiveFormFields> {
  late Set<String> _selectedUsages;

  @override
  void initState() {
    super.initState();
    _selectedUsages = _parseInit(widget.initUsage);
  }

  @override
  void didUpdateWidget(FestiveFormFields oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initUsage != oldWidget.initUsage) {
      _selectedUsages = _parseInit(widget.initUsage);
    }
  }

  Set<String> _parseInit(String? raw) {
    if (raw == null || raw.trim().isEmpty) return {};
    return raw.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toSet();
  }

  void _toggleUsage(String type, bool selected) {
    setState(() {
      if (selected) {
        _selectedUsages.add(type);
      } else {
        _selectedUsages.remove(type);
      }
    });
    final list = _selectedUsages.toList()..sort();
    widget.onUsageChanged(list.isEmpty ? null : list.join(', '));
    widget.onUsageInteracted?.call();
  }

  Future<void> _openEventSheet() async {
    const blue = ListingFormChrome.primary;
    final search = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            final query = search.text.trim().toLowerCase();
            final visible = FestiveFormFields.eventTypes
                .where((type) => query.isEmpty || type.toLowerCase().contains(query))
                .toList();
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
              child: Container(
                height: MediaQuery.of(ctx).size.height * 0.72,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE6E8EC),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              "Types d'événement",
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.3, color: Color(0xFF1A1D26)),
                            ),
                          ),
                          Text(
                            '${_selectedUsages.length}',
                            style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                      child: TextField(
                        controller: search,
                        style: const TextStyle(color: Color(0xFF1A1D26), fontWeight: FontWeight.w600),
                        onChanged: (_) => setModal(() {}),
                        decoration: InputDecoration(
                          hintText: 'Rechercher',
                          prefixIcon: const Icon(Icons.search_rounded, color: blue),
                          filled: true,
                          fillColor: const Color(0xFFF3F3F3),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(999),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                        itemCount: visible.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 4),
                        itemBuilder: (_, index) {
                          final type = visible[index];
                          final on = _selectedUsages.contains(type);
                          return InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              _toggleUsage(type, !on);
                              setModal(() {});
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      type,
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1A1D26)),
                                    ),
                                  ),
                                  Container(
                                    width: 26,
                                    height: 26,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: on ? blue : Colors.white,
                                      border: Border.all(color: on ? blue : const Color(0xFFD0D5DD), width: 1.5),
                                    ),
                                    child: on ? const Icon(Icons.check_rounded, size: 16, color: Colors.white) : null,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                        child: SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: blue,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                            ),
                            child: const Text('Terminé', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    search.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final usageHasError = widget.usageError != null && widget.usageError!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListingFormChrome.label("Types d'événement", required: true, hasError: usageHasError),
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: _openEventSheet,
            child: Container(
              constraints: const BoxConstraints(minHeight: 56),
              padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: usageHasError ? ListingFormChrome.error : ListingFormChrome.border,
                  width: usageHasError ? 1.5 : 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Icon(Icons.celebration_outlined, size: 18, color: ListingFormChrome.primary),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _selectedUsages.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              'Ajouter des types d’événement',
                              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 15),
                            ),
                          )
                        : Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: (_selectedUsages.toList()..sort()).map((type) {
                              return Container(
                                padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
                                decoration: BoxDecoration(
                                  color: ListingFormChrome.primary,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      type,
                                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                                    ),
                                    const SizedBox(width: 2),
                                    GestureDetector(
                                      onTap: () => _toggleUsage(type, false),
                                      child: const Icon(Icons.close_rounded, size: 16, color: Colors.white),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: usageHasError ? ListingFormChrome.error : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        ListingFormChrome.errorLine(usageHasError ? widget.usageError : null),
        ListingFormChrome.space,
        ListingFormChrome.text(
          controller: widget.capacityController,
          label: 'Capacité (personnes)',
          hint: 'Ex. 150',
          icon: Icons.groups_outlined,
          errorText: widget.capacityError,
          required: true,
          keyboardType: TextInputType.number,
          onTap: widget.onCapacityInteracted,
        ),
        ListingFormChrome.space,
        ListingFormChrome.toggle(
          title: 'Décoration',
          value: widget.isDecore,
          onChanged: widget.onDecoreChanged,
        ),
        ListingFormChrome.space,
        ListingFormChrome.toggle(
          title: 'Piste de danse',
          value: widget.pisteDanse,
          onChanged: widget.onPisteDanseChanged,
        ),
      ],
    );
  }
}
