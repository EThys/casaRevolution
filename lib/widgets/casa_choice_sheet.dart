import 'package:flutter/material.dart';

const Color _casaBlue = Color(0xFF1976D2);

class CasaChoice<T> {
  final T value;
  final String title;
  final String? subtitle;

  const CasaChoice({
    required this.value,
    required this.title,
    this.subtitle,
  });
}

Future<T?> showCasaChoiceSheet<T>({
  required BuildContext context,
  required String title,
  required List<CasaChoice<T>> options,
  T? selected,
  IconData icon = Icons.check_rounded,
}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.white,
    useRootNavigator: true,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheetContext) {
      return _CasaChoiceSheet<T>(
        title: title,
        options: options,
        selected: selected,
        icon: icon,
      );
    },
  );
}

class _CasaChoiceSheet<T> extends StatefulWidget {
  final String title;
  final List<CasaChoice<T>> options;
  final T? selected;
  final IconData icon;

  const _CasaChoiceSheet({
    required this.title,
    required this.options,
    required this.selected,
    required this.icon,
  });

  @override
  State<_CasaChoiceSheet<T>> createState() => _CasaChoiceSheetState<T>();
}

class _CasaChoiceSheetState<T> extends State<_CasaChoiceSheet<T>> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final visible = query.isEmpty
        ? widget.options
        : widget.options.where((option) {
            final haystack = '${option.title} ${option.subtitle ?? ''}'.toLowerCase();
            return haystack.contains(query);
          }).toList();
    final showSearch = widget.options.length > 6;

    return Theme(
      data: Theme.of(context).copyWith(
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.white,
        canvasColor: Colors.white,
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.72,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: Color(0xFF1A1D26),
                      ),
                    ),
                  ),
                ),
                if (showSearch)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                    child: TextField(
                      onChanged: (value) => setState(() => _query = value),
                      style: const TextStyle(
                        color: Color(0xFF1A1D26),
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Rechercher',
                        hintStyle: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontWeight: FontWeight.w500,
                        ),
                        prefixIcon: const Icon(Icons.search_rounded, color: _casaBlue),
                        filled: true,
                        fillColor: const Color(0xFFF3F6FA),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(999),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                Flexible(
                  child: visible.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.fromLTRB(20, 24, 20, 28),
                          child: Text(
                            'Aucun résultat',
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                          itemCount: visible.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final option = visible[index];
                            final selected = option.value == widget.selected;
                            return InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () => Navigator.of(context).pop(option.value),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: selected ? const Color(0xFFE8F1FB) : Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: selected ? _casaBlue : const Color(0xFFE6E8EC),
                                    width: selected ? 1.5 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: selected ? _casaBlue : const Color(0xFFF3F6FA),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        widget.icon,
                                        size: 18,
                                        color: selected ? Colors.white : _casaBlue,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            option.title,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                              color: selected ? _casaBlue : const Color(0xFF1A1D26),
                                            ),
                                          ),
                                          if ((option.subtitle ?? '').trim().isNotEmpty) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              option.subtitle!.trim(),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 13,
                                                height: 1.3,
                                                color: Color(0xFF64748B),
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Container(
                                      width: 26,
                                      height: 26,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: selected ? _casaBlue : Colors.white,
                                        border: Border.all(
                                          color: selected ? _casaBlue : const Color(0xFFD0D5DD),
                                          width: 1.5,
                                        ),
                                      ),
                                      child: selected
                                          ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                                          : null,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

List<CasaChoice<T>> casaChoicesFromLabels<T>(
  List<T> items,
  String Function(T) displayText,
) {
  return items.map((item) {
    final raw = displayText(item).trim();
    final split = raw.indexOf(' · ');
    if (split < 0) return CasaChoice<T>(value: item, title: raw);
    return CasaChoice<T>(
      value: item,
      title: raw.substring(0, split).trim(),
      subtitle: raw.substring(split + 3).trim(),
    );
  }).toList();
}
