import 'package:flutter/material.dart';
import 'dart:ui';
import '../Apps/MonApllication.dart';

class NotificationBanner extends StatefulWidget {
  final String title;
  final String message;
  final VoidCallback? onTap;
  final IconData? icon;
  final Color? color;

  const NotificationBanner({
    Key? key,
    required this.title,
    required this.message,
    this.onTap,
    this.icon,
    this.color,
  }) : super(key: key);

  static void show({
    required String title,
    required String message,
    VoidCallback? onTap,
    IconData? icon,
    Color? color,
  }) {
    // Ne pas utiliser Overlay.of(navigatorKey.currentContext) : le contexte du
    // Navigator n’a pas d’Overlay **ancêtre** (l’Overlay est un **enfant** du Navigator).
    // → "No Overlay widget found". Utiliser l’Overlay exposé par NavigatorState.
    final nav = MonApplication.navigatorKey.currentState;
    final overlayState = nav?.overlay;
    if (overlayState == null) return;

    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) => _NotificationBannerWidget(
        title: title,
        message: message,
        onTap: () {
          entry.remove();
          if (onTap != null) onTap();
        },
        onDismiss: () => entry.remove(),
        icon: icon,
        color: color,
      ),
    );

    overlayState.insert(entry);
  }

  @override
  _NotificationBannerState createState() => _NotificationBannerState();
}

class _NotificationBannerState extends State<NotificationBanner> {
  @override
  Widget build(BuildContext context) {
    return Container(); // Utility class
  }
}

class _NotificationBannerWidget extends StatefulWidget {
  final String title;
  final String message;
  final VoidCallback onTap;
  final VoidCallback onDismiss;
  final IconData? icon;
  final Color? color;

  const _NotificationBannerWidget({
    required this.title,
    required this.message,
    required this.onTap,
    required this.onDismiss,
    this.icon,
    this.color,
  });

  @override
  __NotificationBannerWidgetState createState() => __NotificationBannerWidgetState();
}

class __NotificationBannerWidgetState extends State<_NotificationBannerWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0, -1.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    ));

    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    ));

    _controller.forward();

    // Auto dismiss after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        _dismiss();
      }
    });
  }

  void _dismiss() {
    _controller.reverse().then((_) => widget.onDismiss());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print("✨ [NotificationBanner] Affichage de la bannière: ${widget.title}");
    final themeColor = widget.color ?? const Color(0xFF2A5C99);
    
    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      left: 12,
      right: 12,
      child: SlideTransition(
        position: _offsetAnimation,
        child: FadeTransition(
          opacity: _opacityAnimation,
          child: Material(
            color: Colors.transparent,
            elevation: 8,
            shadowColor: Colors.black45,
            child: GestureDetector(
              onTap: widget.onTap,
              onVerticalDragUpdate: (details) {
                if (details.primaryDelta! < -10) {
                  _dismiss();
                }
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white, // Fond solide pour plus de lisibilité comme le offline banner
                    borderRadius: BorderRadius.circular(12),
                    border: Border(
                      left: BorderSide(color: themeColor, width: 6), // Trait de couleur sur le côté
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: themeColor.withOpacity(0.05),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          widget.icon ?? Icons.notifications_active_rounded,
                          color: themeColor,
                          size: 24,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "🔔 ${widget.title}",
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                  color: themeColor,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                widget.message,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[800],
                                  height: 1.2,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: Colors.grey[600],
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
