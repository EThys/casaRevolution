import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:casa/screens/BottomNavBar.dart';

class OnboardingScreen extends StatefulWidget {
  @override
  _OnboardingScreenState createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  int _selectedIndex = 0;
  Timer? _timer;
  late PageController _pageController;
  
  // Contrôleurs d'animation
  late AnimationController _backgroundAnimationController;
  late AnimationController _textAnimationController;
  late AnimationController _logoAnimationController;
  late AnimationController _buttonAnimationController;
  
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _logoRotationAnimation;
  late Animation<Offset> _textSlideAnimation;

  // Images et textes pour chaque page
  final List<Map<String, String>> _pages = [
    {
      'image': 'assets/images/ville.jpg',
      'text':
          'Trouvez votre maison idéale à louer parmi des milliers de propriétés en République Démocratique du Congo. Découvrez des biens adaptés à vos besoins.'
    },
    {
      'image': 'assets/images/kin.jpg',
      'text':
          'Besoin d\'un plombier, d\'un peintre ou d\'un service de déménagement ? Trouvez tous les professionnels du secteur immobilier en quelques clics sur CasaNayo.'
    },
    {
      'image': 'assets/images/lingwala.jpg',
      'text':
          'De la recherche de logement aux services de réparation, CasaNayo regroupe tout ce dont vous avez besoin pour votre bien immobilier en un seul endroit.'
    },
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    
    // Initialisation des contrôleurs d'animation
    _backgroundAnimationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 800),
    );
    
    _textAnimationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 600),
    );
    
    _logoAnimationController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 2),
    )..repeat();
    
    _buttonAnimationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1500),
    );

    // Animations
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _textAnimationController,
        curve: Curves.easeOut,
      ),
    );
    
    _slideAnimation = Tween<double>(begin: 50.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _textAnimationController,
        curve: Curves.easeOutCubic,
      ),
    );
    
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _buttonAnimationController,
        curve: Curves.elasticOut,
      ),
    );
    
    _logoRotationAnimation = Tween<double>(begin: 0, end: 2 * math.pi).animate(
      CurvedAnimation(
        parent: _logoAnimationController,
        curve: Curves.linear,
      ),
    );
    
    _textSlideAnimation = Tween<Offset>(
      begin: Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _textAnimationController,
        curve: Curves.easeOutCubic,
      ),
    );

    // Démarrage des animations
    _backgroundAnimationController.forward();
    _textAnimationController.forward();
    _buttonAnimationController.forward();

    // Changement automatique toutes les 5 secondes
    _timer = Timer.periodic(Duration(seconds: 5), (timer) {
      if (mounted && _pageController.hasClients) {
        final nextIndex = (_selectedIndex + 1) % _pages.length;
        _pageController.animateToPage(
          nextIndex,
          duration: Duration(milliseconds: 800),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    _backgroundAnimationController.dispose();
    _textAnimationController.dispose();
    _logoAnimationController.dispose();
    _buttonAnimationController.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    setState(() {
      _selectedIndex = page;
    });
    _textAnimationController.reset();
    _textAnimationController.forward();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Color(0xFF1976D2);
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      body: Stack(
        children: [
          // Images de fond avec effet parallaxe
          _buildParallaxBackground(),

          // Superposition bleue animée
          AnimatedBuilder(
            animation: _backgroundAnimationController,
            builder: (context, child) {
              return Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.topRight,
                      radius: 1.5,
                      colors: [
                        primaryColor.withOpacity(0.6 + (_selectedIndex * 0.1)),
                        primaryColor.withOpacity(0.4 + (_selectedIndex * 0.1)),
                        primaryColor.withOpacity(0.5),
                      ],
                      stops: [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
              );
            },
          ),

          // Gradient noir depuis le bas
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: screenHeight * 0.45,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withOpacity(0.95),
                    Colors.black.withOpacity(0.85),
                    Colors.black.withOpacity(0.7),
                    Colors.black.withOpacity(0.4),
                    Colors.transparent,
                  ],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  stops: [0.0, 0.3, 0.6, 0.85, 1.0],
                ),
              ),
            ),
          ),

          // Effet de particules animées en arrière-plan
          _buildAnimatedParticles(),

          // Header avec logo animé
          _buildAnimatedHeader(primaryColor),

          // Contenu principal avec animations
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(left: 20, right: 20, bottom: 50),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Texte avec animations sophistiquées
                    _buildAnimatedText(),
                    SizedBox(height: 48),

                    // Indicateurs et bouton avec animations
                    _buildAnimatedControls(primaryColor),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParallaxBackground() {
    return PageView.builder(
      controller: _pageController,
      itemCount: _pages.length,
      onPageChanged: _onPageChanged,
      physics: BouncingScrollPhysics(),
      itemBuilder: (context, index) {
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: _selectedIndex == index ? 1.0 : 0.0),
          duration: Duration(milliseconds: 800),
          curve: Curves.easeInOut,
          builder: (context, value, child) {
            return Transform.scale(
              scale: 1.0 + (value * 0.1),
              child: Opacity(
                opacity: _selectedIndex == index ? 1.0 : 0.0,
                child: Image.asset(
                  _pages[index]['image']!,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAnimatedParticles() {
    return Positioned.fill(
      child: CustomPaint(
        painter: ParticlesPainter(
          animation: _logoAnimationController,
          particleCount: 30,
        ),
      ),
    );
  }

  Widget _buildAnimatedHeader(Color primaryColor) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Row(
            children: [
              // Logo avec rotation subtile
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: Duration(milliseconds: 1000),
                curve: Curves.elasticOut,
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: Transform.rotate(
                      angle: value * 0.1,
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 20,
                              offset: Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Image.asset(
                            'assets/images/logoCasa.png',
                            width: 40,
                            height: 40,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(
                                Icons.home_rounded,
                                color: Colors.white,
                                size: 28,
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              SizedBox(width: 16),
              // Texte CasaNayo avec animation
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: Duration(milliseconds: 800),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, 20 * (1 - value)),
                      child: Text(
                        'CasaNayo',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                          shadows: [
                            Shadow(
                              color: Colors.black.withOpacity(0.5),
                              blurRadius: 15,
                              offset: Offset(0, 4),
                            ),
                            Shadow(
                              color: primaryColor.withOpacity(0.5),
                              blurRadius: 20,
                              offset: Offset(0, 0),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedText() {
    return SlideTransition(
      position: _textSlideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Indicateur de page stylisé
            Row(
              children: List.generate(_pages.length, (index) {
                return AnimatedContainer(
                  duration: Duration(milliseconds: 400),
                  curve: Curves.easeInOutCubic,
                  margin: EdgeInsets.only(right: index < _pages.length - 1 ? 8 : 0),
                  width: _selectedIndex == index ? 32 : 8,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _selectedIndex == index
                        ? Colors.white
                        : Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: _selectedIndex == index
                        ? [
                            BoxShadow(
                              color: Colors.white.withOpacity(0.5),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
                  ),
                );
              }),
            ),
            SizedBox(height: 32),

            // Texte avec animation de typewriter
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: Duration(milliseconds: 1200),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                final text = _pages[_selectedIndex]['text']!;
                final visibleLength = (text.length * value).floor();
                return Text(
                  text.substring(0, visibleLength.clamp(0, text.length)),
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    height: 1.5,
                    letterSpacing: 0.2,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 10,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedControls(Color primaryColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Indicateurs personnalisés améliorés
        Row(
          children: List.generate(_pages.length, (index) {
            return GestureDetector(
              onTap: () {
                _pageController.animateToPage(
                  index,
                  duration: Duration(milliseconds: 600),
                  curve: Curves.easeInOutCubic,
                );
              },
              child: AnimatedContainer(
                duration: Duration(milliseconds: 400),
                curve: Curves.easeInOutCubic,
                margin: EdgeInsets.only(right: index < _pages.length - 1 ? 12 : 0),
                width: _selectedIndex == index ? 48 : 32,
                height: 4,
                decoration: BoxDecoration(
                  color: _selectedIndex == index
                      ? Colors.white
                      : Colors.white.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: _selectedIndex == index
                      ? [
                          BoxShadow(
                            color: Colors.white.withOpacity(0.6),
                            blurRadius: 12,
                            spreadRadius: 3,
                          ),
                        ]
                      : null,
                ),
              ),
            );
          }),
        ),

        // Bouton "Allons-y!" avec animations premium
        ScaleTransition(
          scale: _scaleAnimation,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () {
              _timer?.cancel();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => BottomNavBar(),
                ),
              );
            },
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: Duration(milliseconds: 800),
              curve: Curves.elasticOut,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: Container(
                    height: 64,
                    width: 160,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(32),
                      gradient: LinearGradient(
                        colors: [
                          Colors.white,
                          Colors.white.withOpacity(0.95),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withOpacity(0.4),
                          blurRadius: 20,
                          spreadRadius: 2,
                          offset: Offset(0, 8),
                        ),
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 15,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        // Effet de brillance animé
                        AnimatedBuilder(
                          animation: _logoAnimationController,
                          builder: (context, child) {
                            return Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(32),
                                  gradient: LinearGradient(
                                    begin: Alignment(-1.0 + (_logoAnimationController.value * 2), -1.0),
                                    end: Alignment(1.0 - (_logoAnimationController.value * 2), 1.0),
                                    colors: [
                                      Colors.transparent,
                                      Colors.white.withOpacity(0.3),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        // Texte du bouton
                        Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Allons-y!',
                                style: GoogleFonts.inter(
                                  color: primaryColor,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(
                                Icons.arrow_forward_rounded,
                                color: primaryColor,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

// Painter pour les particules animées
class ParticlesPainter extends CustomPainter {
  final Animation<double> animation;
  final int particleCount;

  ParticlesPainter({
    required this.animation,
    required this.particleCount,
  }) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.fill;

    final random = math.Random(42);
    
    for (int i = 0; i < particleCount; i++) {
      final progress = (animation.value + (i / particleCount)) % 1.0;
      final x = size.width * (0.2 + random.nextDouble() * 0.6);
      final y = size.height * (0.3 + progress * 0.4);
      final radius = 2.0 + random.nextDouble() * 3.0;
      final opacity = (math.sin(progress * math.pi * 2) * 0.5 + 0.5) * 0.3;
      
      canvas.drawCircle(
        Offset(x, y),
        radius,
        paint..color = Colors.white.withOpacity(opacity),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
