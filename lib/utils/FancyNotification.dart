import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

/// Bannière type iOS : coin supérieur, carte légère, icône sémantique, fermeture en croix.
class FancyNotification {
  FancyNotification._();

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
    final NotificationType resolvedType =
        isError ? type : NotificationType.success;

    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => _CasaToastOverlay(
        message: message,
        title: title,
        type: resolvedType,
        onTap: onTap,
        actionLabel: actionLabel,
        autoDismissSeconds: duration,
        onRemove: () {
          if (overlayEntry.mounted) overlayEntry.remove();
        },
      ),
    );

    overlay.insert(overlayEntry);
  }
}

enum NotificationType {
  success,
  error,
  warning,
  info,
  premium,
}

class _ToastStyle {
  const _ToastStyle({
    required this.background,
    required this.onBackground,
    required this.muted,
    required this.icon,
    required this.iconColor,
    required this.accentBar,
  });

  final Color background;
  final Color onBackground;
  final Color muted;
  final IconData icon;
  final Color iconColor;
  final Color accentBar;
}

class _CasaToastOverlay extends StatefulWidget {
  const _CasaToastOverlay({
    required this.message,
    this.title,
    required this.type,
    this.onTap,
    this.actionLabel,
    required this.autoDismissSeconds,
    required this.onRemove,
  });

  final String message;
  final String? title;
  final NotificationType type;
  final VoidCallback? onTap;
  final String? actionLabel;
  final int autoDismissSeconds;
  final VoidCallback onRemove;

  @override
  State<_CasaToastOverlay> createState() => _CasaToastOverlayState();
}

class _CasaToastOverlayState extends State<_CasaToastOverlay>
    with SingleTickerProviderStateMixin {
  static const Color _appleLabel = Color(0xFF1C1C1E);
  static const Color _appleSecondary = Color(0xFF636366);

  late AnimationController _controller;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  _ToastStyle _styleFor(NotificationType t) {
    switch (t) {
      case NotificationType.success:
        return const _ToastStyle(
          background: Color(0xFFF2F2F7),
          onBackground: _appleLabel,
          muted: _appleSecondary,
          icon: Icons.check_circle_rounded,
          iconColor: Color(0xFF34C759),
          accentBar: Color(0xFF34C759),
        );
      case NotificationType.error:
        return const _ToastStyle(
          background: Color(0xFFFFF2F2),
          onBackground: _appleLabel,
          muted: Color(0xFF8E1F1F),
          icon: Icons.error_rounded,
          iconColor: Color(0xFFFF3B30),
          accentBar: Color(0xFFFF3B30),
        );
      case NotificationType.warning:
        return const _ToastStyle(
          background: Color(0xFFFFF9E8),
          onBackground: _appleLabel,
          muted: Color(0xFF8A6A00),
          icon: Icons.warning_amber_rounded,
          iconColor: Color(0xFFFF9500),
          accentBar: Color(0xFFFF9500),
        );
      case NotificationType.info:
        return const _ToastStyle(
          background: Color(0xFFF2F7FF),
          onBackground: _appleLabel,
          muted: Color(0xFF1A4A8C),
          icon: Icons.info_rounded,
          iconColor: Color(0xFF007AFF),
          accentBar: Color(0xFF007AFF),
        );
      case NotificationType.premium:
        return const _ToastStyle(
          background: Color(0xFFF8F2FF),
          onBackground: _appleLabel,
          muted: Color(0xFF5E3A8C),
          icon: Icons.star_rounded,
          iconColor: Color(0xFFAF52DE),
          accentBar: Color(0xFFAF52DE),
        );
    }
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
      reverseDuration: const Duration(milliseconds: 240),
    );

    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _slide = Tween<Offset>(
      begin: const Offset(0, -0.35),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _controller.forward();

    if (widget.autoDismissSeconds > 0) {
      Future<void>.delayed(Duration(seconds: widget.autoDismissSeconds), () {
        if (mounted) _dismiss();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    if (!mounted) return;
    await _controller.reverse();
    if (mounted) widget.onRemove();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    final style = _styleFor(widget.type);

    final toast = SlideTransition(
      position: _slide,
      child: FadeTransition(
        opacity: _fade,
        child: Material(
          color: Colors.transparent,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                  spreadRadius: -6,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(width: 4, color: style.accentBar),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: style.background.withOpacity(0.88),
                            border: Border(
                              top: BorderSide(color: Colors.white.withOpacity(0.55), width: 0.75),
                              right: BorderSide(color: Colors.white.withOpacity(0.45), width: 0.75),
                              bottom: BorderSide(color: Colors.white.withOpacity(0.45), width: 0.75),
                            ),
                          ),
                          padding: const EdgeInsets.fromLTRB(14, 14, 42, 14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: style.iconColor.withOpacity(0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(style.icon, color: style.iconColor, size: 24),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: GestureDetector(
                                  onTap: widget.onTap,
                                  behavior: HitTestBehavior.translucent,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (widget.title != null &&
                                          widget.title!.trim().isNotEmpty) ...[
                                        Text(
                                          widget.title!.trim(),
                                          style: TextStyle(
                                            color: style.onBackground,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: -0.3,
                                            height: 1.2,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                      ],
                                      Text(
                                        widget.message,
                                        style: TextStyle(
                                          color: style.onBackground.withOpacity(0.92),
                                          fontSize: 14,
                                          fontWeight: FontWeight.w400,
                                          height: 1.35,
                                          letterSpacing: -0.15,
                                        ),
                                      ),
                                      if (widget.actionLabel != null &&
                                          widget.actionLabel!.isNotEmpty &&
                                          widget.onTap != null) ...[
                                        const SizedBox(height: 10),
                                        GestureDetector(
                                          onTap: widget.onTap,
                                          child: Text(
                                            widget.actionLabel!,
                                            style: TextStyle(
                                              color: style.muted,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              decoration: TextDecoration.underline,
                                              decorationColor: style.muted.withOpacity(0.6),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
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
    );

    return Positioned(
      left: 0,
      right: 0,
      top: 0,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, top + 8, 16, 0),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            toast,
            Positioned(
              top: 6,
              right: 10,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _dismiss,
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: style.muted.withOpacity(0.85),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Raccourcis vers [FancyNotification].
class SnackbarForCasa {
  SnackbarForCasa._();

  static void success(BuildContext context, String message, {VoidCallback? onTap}) {
    FancyNotification.show(
      context,
      message,
      type: NotificationType.success,
      isError: false,
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
      isError: false,
      onTap: onTap,
    );
  }

  static void premium(BuildContext context, String message, {VoidCallback? onTap}) {
    FancyNotification.show(
      context,
      message,
      type: NotificationType.premium,
      isError: false,
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
      isError: false,
      onTap: onTap,
      actionLabel: actionLabel,
      duration: 6,
    );
  }
}
