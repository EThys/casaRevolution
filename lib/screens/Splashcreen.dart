import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/Routes.dart';

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _haloAnimation;
  late Animation<double> _translateYAnimation;

  final Color primaryColor = const Color(0xFF1976D2); // Ton bleu principal
  final Color accentColor = const Color(0xFF64B5F6);  // Ton bleu clair

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 2800),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    _haloAnimation = Tween<double>(begin: 0.0, end: 60.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutExpo),
    );

    _translateYAnimation = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _controller.forward();

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Navigator.pushNamed(context, Routes.onbordingRoute);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: primaryColor,
          body: Stack(
            children: [
              // Dégradé radial en arrière-plan
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(0.0, -0.6),
                      radius: 1.2,
                      colors: [
                        accentColor.withOpacity(0.2),
                        primaryColor,
                      ],
                    ),
                  ),
                ),
              ),

              // Halo lumineux central
              Center(
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withOpacity(0.4),
                        blurRadius: _haloAnimation.value,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                ),
              ),

              // Contenu principal animé
              Center(
                child: Transform.translate(
                  offset: Offset(0, _translateYAnimation.value),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Logo
                      ScaleTransition(
                        scale: _scaleAnimation,
                        child: Opacity(
                          opacity: _opacityAnimation.value,
                          child: Container(
                            padding: EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.05),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.1),
                                width: 1,
                              ),
                            ),
                            child: Image.asset(
                              'assets/images/yinzo.png',
                              width: 110,
                              height: 110,
                            ),
                          ),
                        ),
                      ),

                      SizedBox(height: 36),

                      // Nom de l'app modernisé
                      FadeTransition(
                        opacity: _opacityAnimation,
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: 'Y',
                                style: GoogleFonts.montserrat(
                                  fontSize: 50,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              TextSpan(
                                text: 'INZO',
                                style: GoogleFonts.montserrat(
                                  fontSize: 38,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 1.5,
                                  color: Colors.white.withOpacity(0.95),
                                ),
                              ),
                            ],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),

                      SizedBox(height: 16),

                      // Slogan
                      FadeTransition(
                        opacity: _opacityAnimation,
                        child: Text(
                          'Trouvez la maison qui vous ressemble',
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            color: Colors.white.withOpacity(0.85),
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                      ),

                      SizedBox(height: 40),

                      // Petite progress bar animée comme un bouton
                      FadeTransition(
                        opacity: _opacityAnimation,
                        child: Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.1),
                          ),
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white),
                            value: _controller.value,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
