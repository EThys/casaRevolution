import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ModernCustomDialog extends StatefulWidget {
  final String title;
  final String message;
  final String confirmText;
  final String cancelText;
  final Future<void> Function() onConfirm;
  final VoidCallback? onCancel;
  final bool isDanger;
  final IconData? icon;

  const ModernCustomDialog({
    Key? key,
    required this.title,
    required this.message,
    required this.confirmText,
    this.cancelText = "Annuler",
    required this.onConfirm,
    this.onCancel,
    this.isDanger = false,
    this.icon,
  }) : super(key: key);

  static void show(BuildContext context, {
    required String title,
    required String message,
    required String confirmText,
    String cancelText = "Annuler",
    required Future<void> Function() onConfirm,
    VoidCallback? onCancel,
    bool isDanger = false,
    IconData? icon,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent closing during operation
      barrierColor: Colors.black.withOpacity(0.4),
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
        child: ModernCustomDialog(
          title: title,
          message: message,
          confirmText: confirmText,
          cancelText: cancelText,
          onConfirm: onConfirm,
          onCancel: onCancel,
          isDanger: isDanger,
          icon: icon,
        ),
      ),
    );
  }

  @override
  State<ModernCustomDialog> createState() => _ModernCustomDialogState();
}

class _ModernCustomDialogState extends State<ModernCustomDialog> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    // Couleurs basées sur widget.isDanger
    final Color headerColor = widget.isDanger ? Color(0xFFFFEBEE) : Color(0xFFE3F2FD);
    final Color primaryColor = widget.isDanger ? Color(0xFFD32F2F) : Color(0xFF1976D2);
    
    return PopScope(
      canPop: !_isLoading, // Blocker le retour arrière pendant le chargement
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header avec icône
              Container(
                padding: EdgeInsets.symmetric(vertical: 24),
                decoration: BoxDecoration(
                  color: headerColor,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Center(
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        )
                      ],
                    ),
                    child: Icon(
                      widget.icon ?? (widget.isDanger ? Icons.warning_amber_rounded : Icons.check_circle_outline_rounded),
                      color: primaryColor,
                      size: 36,
                    ),
                  ),
                ),
              ),
              
              // Corps du dialogue
              Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  children: [
                    // Titre
                    Text(
                      widget.title,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1D26),
                      ),
                    ),
                    SizedBox(height: 16),
                    
                    // Message
                    Text(
                      widget.message,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Color(0xFF7F8C8D),
                        height: 1.5,
                      ),
                    ),
                    SizedBox(height: 32),
                    
                    // Bouton de confirmation (Principal)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : () async {
                          setState(() => _isLoading = true);
                          try {
                            await widget.onConfirm();
                          } finally {
                            if (mounted) {
                              setState(() => _isLoading = false);
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 16),
                          elevation: 0,
                          disabledBackgroundColor: primaryColor.withOpacity(0.6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: AnimatedSwitcher(
                          duration: Duration(milliseconds: 200),
                          child: _isLoading 
                            ? SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Text(
                                widget.confirmText.toUpperCase(),
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                        ),
                      ),
                    ),
                    
                    if (!_isLoading) ...[
                      SizedBox(height: 12),
                      // Bouton d'annulation (Secondaire)
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: widget.onCancel ?? () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            widget.cancelText.toUpperCase(),
                            style: GoogleFonts.inter(
                              color: Color(0xFF7F8C8D),
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
