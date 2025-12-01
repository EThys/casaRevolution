import 'dart:async';
import 'package:flutter/material.dart';

class PromoBanner extends StatefulWidget {
  @override
  _PromoBannerState createState() => _PromoBannerState();
}

class _PromoBannerState extends State<PromoBanner> with SingleTickerProviderStateMixin {
  final List<PromoItem> _promoItems = [
    PromoItem(
      image: 'assets/images/post1.png',
      title: 'Offre Spéciale Avril 2025!',
      subtitle: 'Réduction de 15% sur votre première location',
      promoCode: 'ETHBERG2025',
      color: Color(0xFF1976D2),
      icon: Icons.local_offer_rounded,
    ),
    PromoItem(
      image: 'assets/images/two.jpg',
      title: 'Nouveaux Biens Exclusifs!',
      subtitle: 'Découvrez nos dernières propriétés premium',
      promoCode: 'PREMIUM25',
      color: Color(0xFF2196F3),
      icon: Icons.star_rounded,
    ),
    PromoItem(
      image: 'assets/images/post6.png',
      title: 'Financement Facilité',
      subtitle: 'Solutions de paiement flexibles disponibles',
      promoCode: 'FLEXPAY',
      color: Color(0xFF1976D2),
      icon: Icons.attach_money_rounded,
    ),
  ];

  late PageController _pageController;
  int _currentPage = 0;
  late Timer _timer;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentPage, viewportFraction: 0.85);

    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 600),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _startAutoPlay();
    _animationController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _timer.cancel();
    _animationController.dispose();
    super.dispose();
  }

  void _startAutoPlay() {
    _timer = Timer.periodic(Duration(seconds: 6), (Timer timer) {
      if (_pageController.hasClients) {
        if (_currentPage < _promoItems.length - 1) {
          _currentPage++;
        } else {
          _currentPage = 0;
        }

        _animationController.reset();
        _pageController.animateToPage(
          _currentPage,
          duration: Duration(milliseconds: 800),
          curve: Curves.easeInOutCubic,
        ).then((_) {
          _animationController.forward();
        });
      }
    });
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentPage = index;
    });
    _animationController.reset();
    _animationController.forward();
  }

  void _onPromoTap() {
    final currentPromo = _promoItems[_currentPage];
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Code promo: ${currentPromo.promoCode}'),
        backgroundColor: currentPromo.color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      height: 240,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // En-tête de section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Color(0xFF1976D2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  'Offres du moment',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[800],
                  ),
                ),
                Spacer(),
                Text(
                  '${_currentPage + 1}/${_promoItems.length}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 8),

          // Carrousel principal avec hauteur fixe
          Container(
            height: 160, // Hauteur fixe pour le carrousel
            child: PageView.builder(
              controller: _pageController,
              itemCount: _promoItems.length,
              onPageChanged: _onPageChanged,
              physics: BouncingScrollPhysics(),
              itemBuilder: (context, index) {
                final promo = _promoItems[index];
                final isActive = index == _currentPage;

                return AnimatedBuilder(
                  animation: _pageController,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: isActive ? 1.0 : 0.92,
                      child: Opacity(
                        opacity: isActive ? 1.0 : 0.7,
                        child: child,
                      ),
                    );
                  },
                  child: GestureDetector(
                    onTap: _onPromoTap,
                    child: Container(
                      margin: EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: promo.color.withOpacity(0.2),
                            blurRadius: 15,
                            spreadRadius: 1,
                            offset: Offset(0, 5),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Stack(
                          children: [
                            // Image de fond avec overlay
                            Positioned.fill(
                              child: Image.asset(
                                promo.image,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: Colors.grey[200],
                                    child: Icon(Icons.home_work_rounded,
                                        color: Colors.grey[400], size: 40),
                                  );
                                },
                              ),
                            ),

                            // Overlay gradient plus léger
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Colors.black.withOpacity(0.7),
                                  ],
                                  stops: [0.3, 1.0],
                                ),
                              ),
                            ),

                            // Contenu avec padding réduit
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  // Titre avec taille réduite
                                  FadeTransition(
                                    opacity: _fadeAnimation,
                                    child: Text(
                                      promo.title,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 14, // Taille réduite
                                        fontWeight: FontWeight.w700,
                                        height: 1.2,
                                      ),
                                      maxLines: 1, // Une seule ligne
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),

                                  SizedBox(height: 6),

                                  // Sous-titre avec taille réduite
                                  FadeTransition(
                                    opacity: _fadeAnimation,
                                    child: Text(
                                      promo.subtitle,
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.9),
                                        fontSize: 12, // Taille réduite
                                        fontWeight: FontWeight.w500,
                                        height: 1.3,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),

                                  SizedBox(height: 10),

                                  // Code promo plus compact
                                  if (promo.promoCode.isNotEmpty)
                                    FadeTransition(
                                      opacity: _fadeAnimation,
                                      child: Container(
                                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: promo.color.withOpacity(0.9),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.local_offer_rounded,
                                                color: Colors.white, size: 14),
                                            SizedBox(width: 6),
                                            Text(
                                              promo.promoCode,
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),

                            // Badge promotion en haut
                            Positioned(
                              top: 12,
                              left: 12,
                              child: Container(
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.9),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'PROMO',
                                  style: TextStyle(
                                    color: promo.color,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          SizedBox(height: 12),

          // Indicateurs simplifiés
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _promoItems.length,
                  (index) {
                return AnimatedContainer(
                  duration: Duration(milliseconds: 300),
                  width: _currentPage == index ? 20 : 6,
                  height: 6,
                  margin: EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: _currentPage == index
                        ? Color(0xFF1976D2)
                        : Colors.grey[300]!,
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class PromoItem {
  final String image;
  final String title;
  final String subtitle;
  final String promoCode;
  final Color color;
  final IconData icon;

  PromoItem({
    required this.image,
    required this.title,
    required this.subtitle,
    required this.promoCode,
    required this.color,
    required this.icon,
  });
}