import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Composant de base pour créer des modals modernes style Google Material 3
class ModernModal extends StatelessWidget {
  final Widget child;
  final String? title;
  final String? subtitle;
  final IconData? icon;
  final Color? iconColor;
  final double? height;
  final bool showCloseButton;
  final VoidCallback? onClose;
  final EdgeInsets? padding;
  final Color? backgroundColor;

  const ModernModal({
    Key? key,
    required this.child,
    this.title,
    this.subtitle,
    this.icon,
    this.iconColor,
    this.height,
    this.showCloseButton = true,
    this.onClose,
    this.padding,
    this.backgroundColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final modalWidth = MediaQuery.of(context).size.width > 600
        ? 600.0
        : MediaQuery.of(context).size.width * 0.95;
    
    final modalHeight = height ?? MediaQuery.of(context).size.height * 0.85;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: MediaQuery.of(context).size.width > 600 ? 20 : 10,
        vertical: 20,
      ),
      child: Container(
        width: modalWidth,
        constraints: BoxConstraints(
          maxHeight: modalHeight,
          maxWidth: modalWidth,
        ),
        decoration: BoxDecoration(
          color: backgroundColor ?? Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 30,
              offset: Offset(0, 10),
              spreadRadius: 0,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header moderne
            if (title != null || subtitle != null || icon != null)
              Container(
                padding: EdgeInsets.fromLTRB(32, 32, 16, subtitle != null ? 16 : 24),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.grey.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (icon != null) ...[
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: (iconColor ?? Colors.blue).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          icon,
                          color: iconColor ?? Colors.blue,
                          size: 24,
                        ),
                      ),
                      SizedBox(width: 16),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (title != null)
                            Text(
                              title!,
                              style: GoogleFonts.inter(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: Colors.grey[900],
                                letterSpacing: -0.5,
                              ),
                            ),
                          if (subtitle != null) ...[
                            SizedBox(height: 4),
                            Text(
                              subtitle!,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (showCloseButton)
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: onClose ?? () => Navigator.of(context).pop(),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.grey.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.close_rounded,
                              size: 20,
                              color: Colors.grey[700],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: padding ?? EdgeInsets.all(32),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

