import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class FancyNotification {
  static void show(
      BuildContext context,
      String message, {
        bool isError = true,
        int duration = 4,
        NotificationType type = NotificationType.error,
        VoidCallback? onTap,
        String? actionLabel,
        String? title,
      }) {
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;
    
    // Play system sound for feedback
    SystemSound.play(SystemSoundType.click);

    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 80,
        left: 24,
        right: 24,
        child: Material(
          color: Colors.transparent,
          child: PremiumNotification(
            message: message,
            title: title,
            type: type,
            onTap: onTap,
            actionLabel: actionLabel,
            onDismiss: () => overlayEntry.remove(),
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);

    if (duration > 0) {
      Future.delayed(Duration(seconds: duration), overlayEntry.remove);
    }
  }
}

enum NotificationType {
  success,
  error,
  warning,
  info,
  premium
}

class PremiumNotification extends StatefulWidget {
  final String message;
  final String? title;
  final NotificationType type;
  final VoidCallback? onTap;
  final String? actionLabel;
  final VoidCallback onDismiss;

  const PremiumNotification({
    required this.message,
    this.title,
    required this.type,
    this.onTap,
    this.actionLabel,
    required this.onDismiss,
    Key? key,
  }) : super(key: key);

  @override
  _PremiumNotificationState createState() => _PremiumNotificationState();
}

class _PremiumNotificationState extends State<PremiumNotification>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    ));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _getBackgroundColor() {
    switch (widget.type) {
      case NotificationType.success:
        return const Color(0xFF10B981).withOpacity(0.95);
      case NotificationType.error:
        return const Color(0xFFEF4444).withOpacity(0.95);
      case NotificationType.warning:
        return const Color(0xFFF59E0B).withOpacity(0.95);
      case NotificationType.info:
        return const Color(0xFF3B82F6).withOpacity(0.95);
      case NotificationType.premium:
        return const Color(0xFF8B5CF6).withOpacity(0.95);
    }
  }

  Color _getIconColor() {
    switch (widget.type) {
      case NotificationType.success:
        return Colors.white;
      case NotificationType.error:
        return Colors.white;
      case NotificationType.warning:
        return Colors.white;
      case NotificationType.info:
        return Colors.white;
      case NotificationType.premium:
        return Colors.white;
    }
  }

  IconData _getIcon() {
    switch (widget.type) {
      case NotificationType.success:
        return Icons.check_circle_rounded;
      case NotificationType.error:
        return Icons.error_rounded;
      case NotificationType.warning:
        return Icons.warning_rounded;
      case NotificationType.info:
        return Icons.info_rounded;
      case NotificationType.premium:
        return Icons.workspace_premium_rounded;
    }
  }

  String _getTitle() {
    if (widget.title != null) return widget.title!;
    switch (widget.type) {
      case NotificationType.success:
        return 'Succès';
      case NotificationType.error:
        return 'Erreur';
      case NotificationType.warning:
        return 'Attention';
      case NotificationType.info:
        return 'Information';
      case NotificationType.premium:
        return 'Premium';
    }
  }

  void _handleDismiss() {
    _controller.reverse().then((_) {
      widget.onDismiss();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: widget.onTap,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: _getBackgroundColor(),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 32,
                      offset: const Offset(0, 12),
                      spreadRadius: -8,
                    ),
                    BoxShadow(
                      color: _getBackgroundColor().withOpacity(0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      _getBackgroundColor(),
                      _getBackgroundColor().withOpacity(0.9),
                    ],
                  ),
                ),
                child: Stack(
                  children: [
                    // Effet de brillance
                    Positioned(
                      top: -20,
                      right: -20,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Icone avec effet de halo
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.white.withOpacity(0.3),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Icon(
                              _getIcon(),
                              color: _getIconColor(),
                              size: 24,
                            ),
                          ),

                          const SizedBox(width: 16),

                          // Contenu
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _getTitle(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.3,
                                  ),
                                ),

                                const SizedBox(height: 4),

                                Text(
                                  widget.message,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    height: 1.4,
                                    letterSpacing: -0.2,
                                  ),
                                ),

                                if (widget.actionLabel != null && widget.onTap != null) ...[
                                  const SizedBox(height: 12),

                                  GestureDetector(
                                    onTap: widget.onTap,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Colors.white.withOpacity(0.3),
                                        ),
                                      ),
                                      child: Text(
                                        widget.actionLabel!,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),

                          const SizedBox(width: 12),

                          // Bouton de fermeture
                          GestureDetector(
                            onTap: _handleDismiss,
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withOpacity(0.2),
                              ),
                              child: Icon(
                                Icons.close_rounded,
                                color: Colors.white.withOpacity(0.8),
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Barre de progression (optionnelle)
                    if (widget.type != NotificationType.premium)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: LinearProgressIndicator(
                          backgroundColor: Colors.transparent,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white.withOpacity(0.3),
                          ),
                          minHeight: 2,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Classe utilitaire pour des notifications rapides
class SnackbarForCasa {
  static void success(BuildContext context, String message, {VoidCallback? onTap}) {
    FancyNotification.show(
      context,
      message,
      type: NotificationType.success,
      onTap: onTap,
    );
  }

  static void error(BuildContext context, String message, {VoidCallback? onTap}) {
    FancyNotification.show(
      context,
      message,
      type: NotificationType.error,
      onTap: onTap,
    );
  }

  static void warning(BuildContext context, String message, {VoidCallback? onTap}) {
    FancyNotification.show(
      context,
      message,
      type: NotificationType.warning,
      onTap: onTap,
    );
  }

  static void info(BuildContext context, String message, {VoidCallback? onTap}) {
    FancyNotification.show(
      context,
      message,
      type: NotificationType.info,
      onTap: onTap,
    );
  }

  static void premium(BuildContext context, String message, {VoidCallback? onTap}) {
    FancyNotification.show(
      context,
      message,
      type: NotificationType.premium,
      onTap: onTap,
    );
  }

  static void action(
      BuildContext context,
      String message, {
        required VoidCallback onTap,
        required String actionLabel,
        NotificationType type = NotificationType.info,
      }) {
    FancyNotification.show(
      context,
      message,
      type: type,
      onTap: onTap,
      actionLabel: actionLabel,
      duration: 6,
    );
  }
}

// Exemple d'utilisation dans un widget
class NotificationExample extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications Premium'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.grey[900],
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildNotificationButton(
              context,
              'Succès',
                  () => SnackbarForCasa.success(
                context,
                'Votre profil a été mis à jour avec succès',
              ),
            ),
            _buildNotificationButton(
              context,
              'Erreur',
                  () => SnackbarForCasa.error(
                context,
                'Échec de la connexion au serveur',
              ),
            ),
            _buildNotificationButton(
              context,
              'Avertissement',
                  () => SnackbarForCasa.warning(
                context,
                'Votre stock est presque épuisé',
              ),
            ),
            _buildNotificationButton(
              context,
              'Information',
                  () => SnackbarForCasa.info(
                context,
                'Nouvelle mise à jour disponible',
              ),
            ),
            _buildNotificationButton(
              context,
              'Premium',
                  () => SnackbarForCasa.premium(
                context,
                'Fonctionnalité premium débloquée',
              ),
            ),
            _buildNotificationButton(
              context,
              'Avec Action',
                  () => SnackbarForCasa.action(
                context,
                'Voulez-vous sauvegarder vos modifications ?',
                onTap: () {
                  SnackbarForCasa.success(context, 'Modifications sauvegardées');
                },
                actionLabel: 'Sauvegarder',
                type: NotificationType.info,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationButton(
      BuildContext context,
      String label,
      VoidCallback onPressed,
      ) {
    return Container(
      margin: const EdgeInsets.all(8),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.grey[800],
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 4,
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}