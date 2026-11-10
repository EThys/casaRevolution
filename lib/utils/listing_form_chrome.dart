import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Forme et espacement communs des formulaires de publication.
class ListingFormChrome {
  ListingFormChrome._();

  static const double gap = 16;
  static const double radius = 14;
  static const double controlHeight = 56;
  static const Color primary = Color(0xFF1976D2);
  static const Color border = Color(0xFFE6E8EC);
  static const Color labelColor = Color(0xFF1A1D26);
  static const Color error = Color(0xFFD32F2F);

  static const SizedBox space = SizedBox(height: gap);

  static Widget label(String text, {bool required = false, bool hasError = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 2),
      child: Text.rich(
        TextSpan(
          text: text,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: hasError ? error : labelColor,
          ),
          children: [
            if (required)
              const TextSpan(
                text: ' *',
                style: TextStyle(color: error, fontWeight: FontWeight.w700),
              ),
          ],
        ),
      ),
    );
  }

  static Widget errorLine(String? message) {
    if (message == null || message.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(left: 2, top: 6),
      child: Text(
        message,
        style: const TextStyle(color: error, fontSize: 12, fontWeight: FontWeight.w500, height: 1.3),
      ),
    );
  }

  static BoxDecoration shell({bool hasError = false}) {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: hasError ? error : border, width: hasError ? 1.5 : 1),
    );
  }

  static Widget text({
    required TextEditingController controller,
    required String label,
    String? hint,
    IconData? icon,
    String? errorText,
    bool required = false,
    TextInputType keyboardType = TextInputType.text,
    bool readOnly = false,
    VoidCallback? onTap,
    ValueChanged<String>? onChanged,
    int maxLines = 1,
  }) {
    final hasError = errorText != null && errorText.isNotEmpty;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(radius),
      borderSide: BorderSide(color: hasError ? error : ListingFormChrome.border, width: hasError ? 1.5 : 1),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListingFormChrome.label(label, required: required, hasError: hasError),
        TextField(
          controller: controller,
          readOnly: readOnly,
          onTap: onTap,
          onChanged: onChanged,
          keyboardType: keyboardType,
          maxLines: maxLines,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF1A1D26)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(fontSize: 15, color: Colors.grey.shade400, fontWeight: FontWeight.w400),
            prefixIcon: icon == null ? null : Icon(icon, size: 20, color: hasError ? error : primary),
            filled: true,
            fillColor: Colors.white,
            isDense: maxLines == 1,
            constraints: maxLines == 1 ? const BoxConstraints(minHeight: controlHeight, maxHeight: controlHeight) : null,
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: maxLines == 1 ? 0 : 16),
            border: border,
            enabledBorder: border,
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(radius),
              borderSide: BorderSide(color: hasError ? error : primary, width: 1.5),
            ),
          ),
        ),
        errorLine(hasError ? errorText : null),
      ],
    );
  }

  static Widget toggle({
    required String title,
    String? subtitle,
    required bool value,
    required Function(bool) onChanged,
  }) {
    final box = Container(
      height: subtitle == null ? controlHeight : null,
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: subtitle == null ? 0 : 6),
      decoration: shell(),
      child: Row(
        children: [
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: labelColor)),
                if (subtitle != null)
                  Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.3)),
              ],
            ),
          ),
          Switch(
            value: value,
            activeColor: primary,
            onChanged: (next) => onChanged(next),
          ),
        ],
      ),
    );
    return box;
  }

  /// Prix et devise : deux colonnes de même largeur, champs de 56 px.
  static Widget priceDeviseRow({
    required TextEditingController controller,
    required String priceLabel,
    required String priceHint,
    required String deviseValue,
    required VoidCallback onDeviseTap,
    String? priceError,
    bool priceRequired = true,
    TextInputType keyboardType = TextInputType.number,
    ValueChanged<String>? onPriceChanged,
    String? Function(String?)? validator,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return FormField<String>(
      initialValue: controller.text,
      validator: validator,
      builder: (state) {
        final message = (priceError != null && priceError.isNotEmpty) ? priceError : state.errorText;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _equalSlot(
                label: priceLabel,
                required: priceRequired,
                errorText: message,
                child: TextField(
                  controller: controller,
                  keyboardType: keyboardType,
                  inputFormatters: inputFormatters,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: labelColor),
                  onChanged: (value) {
                    state.didChange(value);
                    onPriceChanged?.call(value);
                  },
                  decoration: InputDecoration(
                    isCollapsed: true,
                    border: InputBorder.none,
                    hintText: priceHint,
                    hintStyle: TextStyle(
                      fontSize: 15,
                      color: Colors.grey.shade400,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _equalSlot(
                label: 'Devise',
                onTap: onDeviseTap,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        deviseValue,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: labelColor),
                      ),
                    ),
                    const Icon(Icons.keyboard_arrow_down_rounded, color: primary),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  static Widget _equalSlot({
    required String label,
    required Widget child,
    VoidCallback? onTap,
    bool required = false,
    String? errorText,
  }) {
    final hasError = errorText != null && errorText.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 22,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text.rich(
              TextSpan(
                text: label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: hasError ? error : labelColor,
                ),
                children: [
                  if (required)
                    const TextSpan(
                      text: ' *',
                      style: TextStyle(color: error, fontWeight: FontWeight.w700),
                    ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: controlHeight,
          width: double.infinity,
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(radius),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(radius),
              child: Ink(
                decoration: shell(hasError: hasError),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Align(alignment: Alignment.centerLeft, child: child),
                ),
              ),
            ),
          ),
        ),
        errorLine(hasError ? errorText : null),
      ],
    );
  }

  static Widget menu({
    required String label,
    required Widget child,
    bool required = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListingFormChrome.label(label, required: required),
        Container(
          height: controlHeight,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.centerLeft,
          decoration: shell(),
          child: child,
        ),
      ],
    );
  }
}
