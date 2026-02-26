import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ModernModal {
  static Future<dynamic> showSuccess({
    required BuildContext context,
    required String title,
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
    String? secondaryLabel,
    VoidCallback? onSecondary,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => SuccessModal(
        title: title,
        message: message,
        actionLabel: actionLabel,
        onAction: onAction,
        secondaryLabel: secondaryLabel,
        onSecondary: onSecondary,
      ),
    );
  }

  static Future<dynamic> showConfirm({
    required BuildContext context,
    required String title,
    required String message,
    String actionLabel = "Confirmer",
    required VoidCallback onConfirm,
    String secondaryLabel = "Annuler",
    VoidCallback? onCancel,
    bool isDestructive = false,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => ConfirmModal(
        title: title,
        message: message,
        actionLabel: actionLabel,
        onConfirm: onConfirm,
        secondaryLabel: secondaryLabel,
        onCancel: onCancel,
        isDestructive: isDestructive,
      ),
    );
  }

  static Future<dynamic> showError({
    required BuildContext context,
    required String title,
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => ErrorModal(
        title: title,
        message: message,
        actionLabel: actionLabel,
        onAction: onAction,
      ),
    );
  }
}

class SuccessModal extends StatelessWidget {
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  const SuccessModal({
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.secondaryLabel,
    this.onSecondary,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return _BaseModal(
      title: title,
      message: message,
      icon: Icons.check_circle_rounded,
      iconColor: const Color(0xFF10B981),
      actionLabel: actionLabel,
      onAction: onAction,
      secondaryLabel: secondaryLabel,
      onSecondary: onSecondary,
    );
  }
}

class ConfirmModal extends StatelessWidget {
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onConfirm;
  final String secondaryLabel;
  final VoidCallback? onCancel;
  final bool isDestructive;

  const ConfirmModal({
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onConfirm,
    required this.secondaryLabel,
    this.onCancel,
    this.isDestructive = false,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return _BaseModal(
      title: title,
      message: message,
      icon: isDestructive ? Icons.warning_amber_rounded : Icons.help_outline_rounded,
      iconColor: isDestructive ? const Color(0xFFEF4444) : const Color(0xFF3B82F6),
      actionLabel: actionLabel,
      onAction: onConfirm,
      secondaryLabel: secondaryLabel,
      onSecondary: onCancel,
      isDestructive: isDestructive,
    );
  }
}

class ErrorModal extends StatelessWidget {
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const ErrorModal({
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return _BaseModal(
      title: title,
      message: message,
      icon: Icons.error_outline_rounded,
      iconColor: const Color(0xFFEF4444),
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }
}

class _BaseModal extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  final Color iconColor;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final bool isDestructive;

  const _BaseModal({
    required this.title,
    required this.message,
    required this.icon,
    required this.iconColor,
    this.actionLabel,
    this.onAction,
    this.secondaryLabel,
    this.onSecondary,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 64,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 16,
                color: Colors.grey[600],
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            if (actionLabel != null)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    if (onAction != null) onAction!();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDestructive ? const Color(0xFFEF4444) : iconColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    actionLabel!,
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            if (secondaryLabel != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    if (onSecondary != null) onSecondary!();
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(color: Colors.grey[300]!),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    secondaryLabel!,
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: Colors.grey[800],
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                "Fermer",
                style: GoogleFonts.outfit(
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
