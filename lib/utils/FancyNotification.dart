import 'package:flutter/material.dart';

class FancyNotification {
  static void show(
      BuildContext context,
      String message, {
        bool isError = true,
        int duration = 3,
      }) {
    final overlay = Overlay.of(context);
    final overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        bottom: 125, // Afficher en bas de l'écran
        left: 20,
        right: 20,
        child: Center( // Centrer horizontalement
          child: Material(
            color: Colors.transparent,
            child: AnimatedNotification(
              message: message,
              isError: isError,
            ),
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);
    Future.delayed(Duration(seconds: duration), overlayEntry.remove);
  }
}

class AnimatedNotification extends StatefulWidget {
  final String message;
  final bool isError;

  const AnimatedNotification({
    required this.message,
    required this.isError,
    Key? key,
  }) : super(key: key);

  @override
  _AnimatedNotificationState createState() => _AnimatedNotificationState();
}

class _AnimatedNotificationState extends State<AnimatedNotification>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    // Animation pour faire monter la notification du bas
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1), // Commence en bas (hors écran)
      end: Offset.zero, // Fin à sa position normale
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    ));

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeIn,
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.9, // Largeur maximale de 90%
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          decoration: BoxDecoration(
            color: widget.isError
                ? const Color(0xFFFEEFEF)
                : const Color(0xFFE8F5E9),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: widget.isError
                  ? const Color(0xFFF44336).withOpacity(0.3)
                  : const Color(0xFF4CAF50).withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min, // Pour que la Row ne prenne que la place nécessaire
            children: [
              Icon(
                widget.isError ? Icons.error_outline : Icons.check_circle,
                color: widget.isError
                    ? const Color(0xFFF44336)
                    : const Color(0xFF4CAF50),
                size: 28,
              ),
              const SizedBox(width: 12),
              Flexible( // Permet au texte de s'adapter à la largeur disponible
                child: Text(
                  widget.message,
                  style: TextStyle(
                    color: widget.isError
                        ? const Color(0xFFD32F2F)
                        : const Color(0xFF2E7D32),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                color: Colors.grey[600],
                onPressed: () {
                  _controller.reverse().then((_) {
                    // Retirer l'overlay
                    Overlay.of(context)?.dispose();
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}