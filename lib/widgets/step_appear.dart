import 'package:flutter/material.dart';

/// Apparition courte, jouée une fois à l’entrée de l’étape.
/// Le [State] est conservé tant que la clé d’étape ne change pas,
/// donc une frappe dans un champ ne relance pas l’animation.
class StepAppear extends StatefulWidget {
  final Widget child;

  const StepAppear({super.key, required this.child});

  @override
  State<StepAppear> createState() => _StepAppearState();
}

class _StepAppearState extends State<StepAppear> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  )..forward();

  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );

  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, 0.045),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: widget.child,
      ),
    );
  }
}
