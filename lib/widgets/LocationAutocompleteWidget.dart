import 'package:flutter/material.dart';

class LocationAutocompleteWidget extends StatefulWidget {
  final String? label;
  final String hint;
  final IconData icon;
  final String? initialValue;
  final List<String> suggestions;
  final ValueChanged<String?> onChanged;

  const LocationAutocompleteWidget({
    Key? key,
    this.label,
    required this.hint,
    required this.icon,
    required this.suggestions,
    required this.onChanged,
    this.initialValue,
  }) : super(key: key);

  @override
  _LocationAutocompleteWidgetState createState() => _LocationAutocompleteWidgetState();
}

class _LocationAutocompleteWidgetState extends State<LocationAutocompleteWidget> {
  late TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue ?? '');
  }
  
  @override
  void didUpdateWidget(covariant LocationAutocompleteWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue != oldWidget.initialValue) {
      if (widget.initialValue == null) {
        _controller.clear();
      } else if (widget.initialValue != _controller.text) {
        _controller.text = widget.initialValue!;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8, left: 4),
            child: Text(
              widget.label!,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1D26),
                letterSpacing: 0.3,
              ),
            ),
          ),
        Autocomplete<String>(
          initialValue: TextEditingValue(text: _controller.text),
          optionsBuilder: (TextEditingValue textEditingValue) {
            if (textEditingValue.text.isEmpty) {
              return widget.suggestions;
            }
            return widget.suggestions.where(
              (option) => option.toLowerCase().contains(textEditingValue.text.toLowerCase()),
            );
          },
          onSelected: (String selection) {
            setState(() {
              _controller.text = selection;
            });
            widget.onChanged(selection);
            // FocusScope.of(context).unfocus(); // Removed to keep keyboard/UI stable
          },
          fieldViewBuilder: (context, focusController, focusNode, onFieldSubmitted) {
            return TextField(
              controller: focusController,
              focusNode: focusNode,
              onChanged: (val) {
                // IMPORTANT: Only trigger onChanged if value actually changes to avoid rebuild loops
                if (_controller.text != val) {
                  _controller.text = val;
                  widget.onChanged(val.isEmpty ? null : val);
                }
              },
              style: const TextStyle(
                fontSize: 15, 
                color: Color(0xFF1A1D26),
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: widget.hint,
                hintStyle: TextStyle(color: Colors.grey[400], fontWeight: FontWeight.w400),
                filled: true,
                fillColor: const Color(0xFFF8F9FB),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey.withOpacity(0.1)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFF2855AE), width: 1.5),
                ),
                suffixIcon: focusController.text.isNotEmpty 
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18, color: Colors.grey),
                      onPressed: () {
                        focusController.clear();
                        _controller.clear();
                        widget.onChanged(null);
                      },
                    )
                  : const Icon(Icons.arrow_drop_down_rounded, color: Colors.grey),
              ),
              onSubmitted: (_) {
                widget.onChanged(focusController.text);
                onFieldSubmitted();
              },
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            return _AutocompleteOptions(
              onSelected: onSelected,
              options: options,
              maxHeight: 200,
            );
          },
        ),
      ],
    );
  }
}

class _AutocompleteOptions extends StatelessWidget {
  final AutocompleteOnSelected<String> onSelected;
  final Iterable<String> options;
  final double maxHeight;

  const _AutocompleteOptions({
    required this.onSelected,
    required this.options,
    this.maxHeight = 200,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
        shadowColor: Colors.black.withOpacity(0.1),
        child: Container(
          width: MediaQuery.of(context).size.width - 48,
          constraints: BoxConstraints(
            maxHeight: maxHeight,
          ),
          child: ListView.separated(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            itemCount: options.length,
            separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey[100]),
            itemBuilder: (BuildContext context, int index) {
              final String option = options.elementAt(index);
              return ListTile(
                title: Text(
                  option,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF1A1D26),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onTap: () => onSelected(option),
                visualDensity: VisualDensity.compact,
              );
            },
          ),
        ),
      ),
    );
  }
}

