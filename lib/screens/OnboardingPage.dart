import 'package:casa/screens/BottomNavBar.dart';
import 'package:casa/utils/Routes.dart';
import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:flutter/animation.dart';

class OnboardingScreen extends StatefulWidget {
  @override
  _OnboardingScreenState createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<Color?> _colorAnimation;



  final List<OnboardingPage> _pages = [
    OnboardingPage(
      title: "Découvrez votre futur chez-vous",
      description: "Des milliers de propriétés qui n'attendent que vous !",
      imagePath: "assets/happy_home.svg",
      color: Color(0xFF2196F3), // Bleu clair
      secondaryColor: Color(0xFF64B5F6),
    ),
    OnboardingPage(
      title: "Des propriétés sûres et vérifiées",
      description: "Avec Casanayo, chaque bien est inspecté et validé pour votre tranquillité d'esprit.",
      imagePath: "assets/images/humaaans.png",
      color: Color(0xFFFF9800), // Orange énergique
      secondaryColor: Color(0xFFFFC107),
    ),

    OnboardingPage(
      title: "Gagnez des commissions sur les locations",
      description: "Parrainez des propriétaires et touchez une récompense à chaque mise en location réussie de leurs biens.",
      imagePath: "assets/happy_safe.svg",
      color: Color(0xFF2196F3), // Bleu clair
      secondaryColor: Color(0xFF64B5F6),
    ),

  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 800),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.elasticOut,
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    _colorAnimation = ColorTween(
      begin: _pages[0].color.withOpacity(0.1),
      end: _pages[0].color.withOpacity(0.1),
    ).animate(_animationController);

    _animationController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
      _colorAnimation = ColorTween(
        begin: _colorAnimation.value ?? _pages[0].color.withOpacity(0.1), // Null check
        end: _pages[page].color.withOpacity(0.1),
      ).animate(
        CurvedAnimation(
          parent: _animationController,
          curve: Curves.easeInOut,
        ),
      );
      _animationController.reset();
      _animationController.forward();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Stack(
            children: [
              // Fond animé avec dégradé
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      _pages[_currentPage].secondaryColor.withOpacity(0.1),
                      Colors.white,
                    ],
                  ),
                ),
              ),

              // Bulles décoratives animées
              Positioned(
                top: -50,
                right: -30,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _pages[_currentPage].color.withOpacity(0.1),
                    ),
                  ),
                ),
              ),

              Positioned(
                bottom: 100,
                left: -50,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _pages[_currentPage].secondaryColor.withOpacity(0.1),
                    ),
                  ),
                ),
              ),

              // Contenu principal
              Column(
                children: [
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: _pages.length,
                      onPageChanged: _onPageChanged,
                      itemBuilder: (context, index) {
                        return FadeTransition(
                          opacity: _fadeAnimation,
                          child: ScaleTransition(
                            scale: _scaleAnimation,
                            child: HappyOnboardingPage(page: _pages[index]),
                          ),
                        );
                      },
                    ),
                  ),

                  // Indicateur de page joyeux
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: SmoothPageIndicator(
                      controller: _pageController,
                      count: _pages.length,
                      effect: WormEffect(
                        activeDotColor: _pages[_currentPage].color,
                        dotColor: _pages[_currentPage].color.withOpacity(0.2),
                        dotHeight: 10,
                        dotWidth: 10,
                        spacing: 12,
                        type: WormType.thinUnderground,
                      ),
                    ),
                  ),

                  // Bouton de navigation dynamique
                  Padding(
                    padding: EdgeInsets.only(bottom: 40, left: 24, right: 24),
                    child: AnimatedSwitcher(
                      duration: Duration(milliseconds: 400),
                      transitionBuilder: (child, animation) {
                        return ScaleTransition(
                          scale: animation,
                          child: child,
                        );
                      },
                      child: _currentPage == _pages.length - 1
                          ? ElevatedButton(
                        key: ValueKey('start_button'),
                        onPressed: () {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(builder: (context) => BottomNavBar()),
                                (route) => false,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _pages[_currentPage].color,
                          foregroundColor: Colors.white,
                          shape: StadiumBorder(),
                          padding: EdgeInsets.symmetric(
                              horizontal: 48, vertical: 16),
                          elevation: 8,
                          shadowColor: _pages[_currentPage].color.withOpacity(0.4),
                          animationDuration: Duration(milliseconds: 300),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "Commencer l'aventure",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      )
                          : Row(
                        key: ValueKey('nav_buttons'),
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: () {
                              _pageController.animateToPage(
                                _pages.length - 1,
                                duration: Duration(milliseconds: 500),
                                curve: Curves.easeInOut,
                              );
                            },
                            child: Text(
                              "Passer",
                              style: TextStyle(
                                color: _pages[_currentPage].color,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          FloatingActionButton(
                            onPressed: () {
                              _pageController.nextPage(
                                duration: Duration(milliseconds: 500),
                                curve: Curves.easeInOut,
                              );
                            },
                            backgroundColor: _pages[_currentPage].color,
                            child: Icon(Icons.arrow_forward_rounded,
                                color: Colors.white),
                            elevation: 5,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class HappyOnboardingPage extends StatelessWidget {
  final OnboardingPage page;

  const HappyOnboardingPage({required this.page});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Illustration avec effet de rebond
          Expanded(
            flex: 3,
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Image.asset(
                page.imagePath,
                fit: BoxFit.contain,
              ),
            ),
          ),

          // Contenu texte avec entrée en fondu
          Expanded(
            flex: 2,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  page.title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: page.color,
                    height: 1.3,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: Offset(1, 1),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    page.description,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[700],
                      height: 1.5,
                    ),
                  ),
                ),
                SizedBox(height: 24),
                // Élément décoratif
                Container(
                  width: 50,
                  height: 4,
                  decoration: BoxDecoration(
                    color: page.secondaryColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class OnboardingPage {
  final String title;
  final String description;
  final String imagePath;
  final Color color;
  final Color secondaryColor;

  OnboardingPage({
    required this.title,
    required this.description,
    required this.imagePath,
    required this.color,
    required this.secondaryColor,
  });
}