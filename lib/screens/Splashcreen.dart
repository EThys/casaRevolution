import 'dart:math';
import 'package:casa/screens/OnboardingPage.dart';
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/Routes.dart';
import '../utils/StockageKeys.dart';

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
  late Animation<double> _rotationAnimation;
  late Animation<double> _particlesAnimation;

  final Color primaryColor = const Color(0xFF2196F3); // Ton bleu principal
  final Color accentColor = const Color(0xFF64B5F6);  // Ton bleu clair
  final Color secondaryColor = const Color(0xFF1976D2); // Bleu plus foncé

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 2000), // Accéléré pour un lancement plus fluide
    );

    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: 1.0), weight: 40),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.0), weight: 60),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutQuart));

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack), // Moins élastique, plus pro
    );

    _haloAnimation = Tween<double>(begin: 0.0, end: 80.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutExpo),
    );

    _translateYAnimation = Tween<double>(begin: 40.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _rotationAnimation = Tween<double>(begin: 0.0, end: 2 * pi).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _particlesAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutQuart),
    );

    _controller.forward();

    _controller.addStatusListener((status) async {
      if (status == AnimationStatus.completed) {
        final stockage = GetStorage();
        bool isFirstLaunch = stockage.read(StockageKeys.firstLaunchKey) ?? true;

        if (isFirstLaunch) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => OnboardingScreen()),
          );
          await stockage.write(StockageKeys.firstLaunchKey, false);
        } else {
          Navigator.pushReplacementNamed(context, Routes.bottomPageRoute);
        }
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildFloatingParticles() {
    return AnimatedBuilder(
      animation: _particlesAnimation,
      builder: (context, child) {
        return Stack(
          children: List.generate(8, (index) {
            final angle = 2 * pi * index / 8;
            final radius = 120.0 * _particlesAnimation.value;
            final dx = cos(angle) * radius;
            final dy = sin(angle) * radius;

            return Positioned(
              left: MediaQuery.of(context).size.width / 2 + dx - 4,
              top: MediaQuery.of(context).size.height / 2 + dy - 4,
              child: Transform.scale(
                scale: _particlesAnimation.value,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.6 * _particlesAnimation.value),
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withOpacity(0.3 * _particlesAnimation.value),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildAnimatedBackground() {
    return AnimatedBuilder(
      animation: _rotationAnimation,
      builder: (context, child) {
        return Transform.rotate(
          angle: _rotationAnimation.value * 0.1,
          child: Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.0, -0.4),
                radius: 1.4,
                colors: [
                  accentColor.withOpacity(0.3),
                  primaryColor.withOpacity(0.8),
                  secondaryColor,
                ],
                stops: [0.1, 0.6, 1.0],
              ),
            ),
          ),
        );
      },
    );
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
              // Arrière-plan animé
              Positioned.fill(child: _buildAnimatedBackground()),

              // Halo lumineux principal
              Center(
                child: Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Colors.white.withOpacity(0.2),
                        Colors.transparent,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withOpacity(0.5),
                        blurRadius: _haloAnimation.value,
                        spreadRadius: _haloAnimation.value * 0.3,
                      ),
                    ],
                  ),
                ),
              ),

              // Particules flottantes
              _buildFloatingParticles(),

              // Contenu principal
              Center(
                child: Transform.translate(
                  offset: Offset(0, _translateYAnimation.value),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Logo avec effet de profondeur
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          // Ombre portée
                          Transform.scale(
                            scale: _scaleAnimation.value * 1.1,
                            child: Container(
                              width: 140,
                              height: 140,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withOpacity(0.1),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 20,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Logo principal
                          ScaleTransition(
                            scale: _scaleAnimation,
                            child: Opacity(
                              opacity: _opacityAnimation.value,
                              child: Container(
                                padding: EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Colors.white.withOpacity(0.15),
                                      Colors.white.withOpacity(0.05),
                                    ],
                                  ),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.2),
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.white.withOpacity(0.1),
                                      blurRadius: 10,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: Image.asset(
                                  'assets/images/logoCasa.png',
                                  width: 100,
                                  height: 100,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 40),

                      // Nom de l'app avec effet moderne
                      FadeTransition(
                        opacity: _opacityAnimation,
                        child: Column(
                          children: [
                            Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: 'C',
                                    style: GoogleFonts.montserrat(
                                      fontSize: 52,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: -1,
                                    ),
                                  ),
                                  TextSpan(
                                    text: 'ASA',
                                    style: GoogleFonts.montserrat(
                                      fontSize: 42,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 3,
                                      color: Colors.white.withOpacity(0.95),
                                    ),
                                  ),
                                  TextSpan(
                                    text: 'N',
                                    style: GoogleFonts.montserrat(
                                      fontSize: 52,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: -1,
                                    ),
                                  ),
                                  TextSpan(
                                    text: 'AYO',
                                    style: GoogleFonts.montserrat(
                                      fontSize: 42,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 3,
                                      color: Colors.white.withOpacity(0.95),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 8),
                            Container(
                              height: 3,
                              width: 80,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.white.withOpacity(0.8),
                                    Colors.white.withOpacity(0.3),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 20),

                      // Slogan avec typographie améliorée
                      FadeTransition(
                        opacity: _opacityAnimation,
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 40),
                          child: Text(
                            'Simple. Utile. Fiable.',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              height: 1.5,
                              color: Colors.white.withOpacity(0.9),
                              fontWeight: FontWeight.w500, // Légèrement plus épais pour l'impact
                              letterSpacing: 2.0, // Espacement augmenté pour le style épuré
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),

                      SizedBox(height: 50),

                      // Indicateur de progression moderne
                      FadeTransition(
                        opacity: _opacityAnimation,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Cercle de fond
                            Container(
                              width: 70,
                              height: 70,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withOpacity(0.08),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.15),
                                  width: 1,
                                ),
                              ),
                            ),

                            // Progress bar animée
                            SizedBox(
                              width: 70,
                              height: 70,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white.withOpacity(0.8),
                                ),
                                backgroundColor: Colors.transparent,
                                value: _controller.value,
                              ),
                            ),

                            // Point central
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                                boxShadow: [
                                  BoxShadow(
                                    color: accentColor,
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                          ],
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