import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:casa/controllers/PropertyCtrl.dart';
import 'package:casa/screens/AllPropertiesPage.dart';
import 'package:casa/screens/PromoBanner.dart';
import 'package:casa/screens/auth/LoginScreen.dart';
import 'package:casa/utils/Constantes.dart';
import 'package:casa/utils/FavoriteEartIcon.dart';
import 'package:casa/utils/StockageKeys.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../models/PropertyModel.dart';
import '../utils/Routes.dart';
import 'CategoryPropertiesPage.dart';
import 'NotificationPage.dart'; // Pour des icônes plus variées

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>  {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final Color primaryColor = Color(0xFF1976D2);
  final Color accentColor = Color(0xFF64B5F6);
  final Color darkBlue = Color(0xFF0D47A1);

  bool _isLoading =true;
  bool _hasError=false;
  final GetStorage storage = GetStorage();

  @override
  void initState() {
    super.initState();
    // Attendre que le widget soit complètement construit
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Utiliser Provider pour accéder au contrôleur
      final propertyCtrl = Provider.of<PropertyController>(context, listen: false);
      propertyCtrl.getAllProperty().then((_) {
        print("Données chargées: ${propertyCtrl.properties.length} propriétés");
      });
    });
  }



  @override
  Widget build(BuildContext context) {
    var propertyCtrl = context.watch<PropertyController>();
    var properties = propertyCtrl.properties;

    final rentalProperties = properties.where((p) => p.transactionType == 'location').toList();
    final saleProperties = properties.where((p) => p.transactionType == 'vente').toList();
   // final images = properties.where((p) => p.transactionType == 'vente').toList();

    print("ICIIIIIIIIIIIIIIIIIIIIIIIIIII${properties}");
    print("Données chargées: ${properties}");

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.grey[50],
      drawer: _buildDrawer(),
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section Hero
            _buildHeroSection(),
            SizedBox(height: 13,),
            _buildCategorySection(),

            // Section Locations
            _buildSectionHeader(
              title: "Maisons en Location",
              subtitle: "Découvrez nos meilleures offres",
              onSeeAll: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AllPropertiesPage(
                      initialProperties: rentalProperties,
                      isForRent: true,
                    ),
                  ),
                );
              },
            ),
            _buildPropertyCarousel(
              isForRent: true,
              properties: rentalProperties,
              isLoading: propertyCtrl.loading
            ),
            SizedBox(height: 20,),
            PromoBanner(),
            _buildSectionHeader(
              title: "Maisons en Vente",
              subtitle: "Investissez dans votre avenir",
              onSeeAll: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AllPropertiesPage(
                      initialProperties: saleProperties,
                      isForRent: false,
                    ),
                  ),
                );
              },
            ),
            _buildPropertyCarousel(
              isForRent: false,
              properties: saleProperties,
                isLoading: propertyCtrl.loading
            ),

            SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      automaticallyImplyLeading: false,
      titleSpacing: 0,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              darkBlue.withOpacity(0.98),
              primaryColor.withOpacity(0.95),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: [0.0, 0.8],
          ),
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 20,
              offset: Offset(0, 8),
              spreadRadius: 1,
            ),
          ],
        ),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      leading: Container(
        margin: EdgeInsets.only(left: 16, top: 8, bottom: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.white.withOpacity(0.2),
              Colors.white.withOpacity(0.1),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: IconButton(
          icon: Icon(Icons.menu_rounded, color: Colors.white, size: 24),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          splashRadius: 20,
          padding: EdgeInsets.zero,
        ),
      ),
      title: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                shape: BoxShape.circle,
              ),
              child: Image.asset(
                "assets/images/yinzo.png",
                height: 20,
                width: 20,
              ),
            ),
            SizedBox(width: 10),
            Text(
              "Casa",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 0.5,
                shadows: [
                  Shadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      centerTitle: true,
      actions: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              margin: EdgeInsets.only(right: 16, top: 8, bottom: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.2),
                    Colors.white.withOpacity(0.1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                icon: Icon(
                  Icons.notifications_outlined,
                  color: Colors.white,
                  size: 22,
                ),
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) =>  NotificationsPage()));
                },
                splashRadius: 20,
                padding: EdgeInsets.zero,
              ),
            ),
            Positioned(
              right: 12,
              top: 10,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.redAccent.withOpacity(0.6),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ],
                  border: Border.all(
                    color: Colors.white,
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: Text(
                    "3",
                    style: TextStyle(
                      fontSize: 9,
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Petit widget pour icônes stylées
  Widget _buildCircleIcon(IconData icon, {VoidCallback? onTap}) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: 24),
        onPressed: onTap,
        splashRadius: 26,
      ),
    );
  }


  void _confirmLogout() {
    showDialog(
      context: context,
      barrierDismissible: false, // Empêche la fermeture en cliquant à l'extérieur
      builder: (context) => AlertDialog(
        title: const Text('Déconnexion'),
        content: const Text('Voulez-vous vraiment vous déconnecter ?'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          // Bouton Annuler
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).primaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            child: const Text('Annuler'),
          ),

          // Bouton Déconnexion
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context); // Ferme la boîte de dialogue

              // Affiche un indicateur de chargement
              final scaffold = ScaffoldMessenger.of(context);
              scaffold.showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                      const SizedBox(width: 16),
                      const Text('Déconnexion en cours...'),
                    ],
                  ),
                  duration: const Duration(seconds: 2),
                ),
              );

              try {
                // 1. Suppression du token
                await storage.erase();
                // await storage.erase(); // Option: Tout supprimer
                if (!mounted) return;
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) =>  LoginScreen()),
                      (Route<dynamic> route) => false,
                );

                // 4. Confirmation visuelle
                scaffold.showSnackBar(
                  const SnackBar(
                    content: Text('Déconnexion réussie'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 2),
                  ),
                );

              } catch (e) {
                if (!mounted) return;
                scaffold.showSnackBar(
                  SnackBar(
                    content: Text('Erreur lors de la déconnexion: ${e.toString()}'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.0),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            child: const Text('Déconnexion'),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    final stockage = GetStorage();
    final token = stockage.read(StockageKeys.tokenKey);
    final user = stockage.read(StockageKeys.userKey);
    bool isLoggedIn = token != null;

    // État local pour suivre la route sélectionnée
    String selectedRoute = ModalRoute.of(context)?.settings.name ?? Routes.bottomPageRoute;

    return SizedBox(
      width: 295,
      child: Drawer(
        elevation: 20,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(
            right: Radius.circular(10),
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.horizontal(
              right: Radius.circular(24),
            ),
            boxShadow: [
              BoxShadow(
                color: darkBlue.withOpacity(0.15),
                blurRadius: 30,
                spreadRadius: 5,
                offset: Offset(5, 0),
              ),
            ],
          ),
          child: Column(
            children: [
              // Header avec dégradé amélioré
              Container(
                height: 215,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [darkBlue, primaryColor],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    stops: [0.0, 0.8],
                  ),
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(1),
                    bottomRight: Radius.circular(1),
                  ),
                ),
                child: Stack(
                  children: [
                    // Effets de fond décoratifs
                    Positioned(
                      top: -20,
                      right: -20,
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -30,
                      left: -30,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.08),
                        ),
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 50, 24, 20),
                      child: Column(
                        children: [
                          // Avatar avec animation au tap
                          GestureDetector(
                            onTap: () {
                              // Animation de l'avatar
                              _animateAvatar();
                            },
                            child: AnimatedContainer(
                              duration: Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                              padding: EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [Colors.white, Colors.grey[200]!],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.white.withOpacity(0.4),
                                    blurRadius: 15,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: CircleAvatar(
                                radius: 40,
                                backgroundColor: Colors.white,
                                child: Icon(
                                  Icons.person,
                                  size: 42,
                                  color: primaryColor,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: 20),

                          // Texte d'accueil avec animation
                          AnimatedSwitcher(
                            duration: Duration(milliseconds: 300),
                            child: Text(
                              isLoggedIn ? "Bonjour 👋 ${user?['username']}" : "Bienvenue 👋 Utilisateur",
                              key: ValueKey(isLoggedIn),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 4,
                                    offset: Offset(0, 1),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Liste des items avec effet de défilement fluide
              Expanded(
                child: SingleChildScrollView(
                  physics: BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      SizedBox(height: 16),

                      // Section principale
                      _buildDrawerSection(
                        title: "PRINCIPAL",
                        items: [
                          _buildDrawerItem(
                            icon: Icons.home_rounded,
                            title: 'Accueil',
                            routeName: Routes.bottomPageRoute,
                            isSelected: selectedRoute == Routes.bottomPageRoute,
                            onTap: () => _handleNavigation(Routes.bottomPageRoute),
                          ),
                          _buildDrawerItem(
                            icon: Icons.favorite_rounded,
                            title: 'Favoris',
                            isSelected: selectedRoute == '/favorites',
                            onTap: () => _handleNavigation('/favorites'),
                          ),
                          _buildDrawerItem(
                            icon: Icons.calendar_today_rounded,
                            title: 'Mes Réservations',
                            routeName: Routes.bookingHistoryPageRoute,
                            isSelected: selectedRoute == Routes.bookingHistoryPageRoute,
                            onTap: () => _handleNavigation(Routes.bookingHistoryPageRoute),
                          ),
                          _buildDrawerItem(
                            icon: Icons.dashboard_rounded,
                            title: 'Ma gestion',
                            routeName: Routes.commissionnaireDashboardPageRoute,
                            isSelected: selectedRoute == Routes.commissionnaireDashboardPageRoute,
                            onTap: () => _handleNavigation(Routes.commissionnaireDashboardPageRoute),
                          ),
                        ],
                      ),

                      // Section social
                      _buildDrawerSection(
                        title: "SOCIAL",
                        items: [
                          _buildDrawerItem(
                            icon: Icons.people_alt_rounded,
                            title: 'Parrainer',
                            isSelected: selectedRoute == '/referral',
                            onTap: () => _handleNavigation('/referral'),
                          ),
                          _buildDrawerItem(
                            icon: Icons.share_rounded,
                            title: 'Partager l\'app',
                            isSelected: selectedRoute == '/share',
                            onTap: () => _handleNavigation('/share'),
                          ),
                        ],
                      ),

                      // Section support
                      _buildDrawerSection(
                        title: "SUPPORT",
                        items: [
                          _buildDrawerItem(
                            icon: Icons.settings_rounded,
                            title: 'Paramètres',
                            isSelected: selectedRoute == '/settings',
                            onTap: () => _handleNavigation('/settings'),
                          ),
                          _buildDrawerItem(
                            icon: Icons.help_outline_rounded,
                            title: 'Aide & Support',
                            isSelected: selectedRoute == '/help',
                            onTap: () => _handleNavigation('/help'),
                          ),
                          _buildDrawerItem(
                            icon: Icons.info_outline_rounded,
                            title: 'À propos',
                            isSelected: selectedRoute == '/about',
                            onTap: () => _handleNavigation('/about'),
                          ),
                        ],
                      ),

                      // Section compte
                      if (isLoggedIn)
                        _buildDrawerSection(
                          title: "COMPTE",
                          items: [
                            _buildDrawerItem(
                              icon: Icons.logout_rounded,
                              title: 'Déconnexion',
                              isSelected: false,
                              isDestructive: true,
                              onTap: _confirmLogout,
                            ),
                          ],
                        ),

                      SizedBox(height: 20),

                      // Version avec design moderne
                      Container(
                        margin: EdgeInsets.symmetric(horizontal: 24),
                        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.grey[200]!,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.verified_user_rounded,
                              size: 14,
                              color: primaryColor,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Version 1.0.0',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

// Méthode pour gérer la navigation
  void _handleNavigation(String routeName) {
    Navigator.pop(context); // Ferme le drawer

    if (routeName == Routes.bottomPageRoute ||
        routeName == Routes.commissionnaireDashboardPageRoute ||
        routeName == Routes.bookingHistoryPageRoute) {
      // Navigation normale pour les routes existantes
      Navigator.pushNamed(context, routeName);
    } else {
      // Pour les routes non implémentées, afficher un message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fonctionnalité en cours de développement'),
          backgroundColor: primaryColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

// Animation de l'avatar
  void _animateAvatar() {
    // Vous pouvez ajouter une animation ici si nécessaire
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Modifier le profil'),
        duration: Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

// Widget pour créer une section du drawer
  Widget _buildDrawerSection({
    required String title,
    required List<Widget> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
          child: Text(
            title,
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
        ),
        Column(children: items),
        SizedBox(height: 8),
      ],
    );
  }

// Widget pour un item du drawer avec animations
  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    String? routeName,
    required bool isSelected,
    bool isDestructive = false,
    required VoidCallback onTap,
  }) {
    final color = isDestructive
        ? Colors.red
        : (isSelected ? primaryColor : Colors.grey[700]);

    final bgColor = isSelected ? primaryColor.withOpacity(0.1) : Colors.transparent;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: isSelected ? Border.all(
            color: primaryColor.withOpacity(0.3),
            width: 1,
          ) : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            splashColor: isDestructive
                ? Colors.red.withOpacity(0.1)
                : primaryColor.withOpacity(0.1),
            highlightColor: isDestructive
                ? Colors.red.withOpacity(0.05)
                : primaryColor.withOpacity(0.05),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: Duration(milliseconds: 300),
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isSelected ? primaryColor.withOpacity(0.15) : Colors.grey[100],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      color: color,
                      size: 20,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        color: color,
                        fontSize: 15,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                  if (isSelected)
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: primaryColor,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }



  String _selectedRoute = Routes.bottomPageRoute;

  // Widget _buildDrawerItem({
  //   required IconData icon,
  //   required String title,
  //   String? routeName,
  //   VoidCallback? onTap,
  // }) {
  //   final isSelected = routeName != null && _selectedRoute == routeName;
  //   return ListTile(
  //     leading: Container(
  //       padding: const EdgeInsets.all(8),
  //       decoration: BoxDecoration(
  //         color: isSelected ? primaryColor.withOpacity(0.1) : Colors.transparent,
  //         shape: BoxShape.circle,
  //       ),
  //       child: Icon(
  //         icon,
  //         color: isSelected ? primaryColor : Colors.grey[700],
  //         size: 22,
  //       ),
  //     ),
  //     title: Text(
  //       title,
  //       style: TextStyle(
  //         color: isSelected ? primaryColor : Colors.grey[800],
  //         fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
  //       ),
  //     ),
  //     selected: isSelected,
  //     selectedTileColor: primaryColor.withOpacity(0.1),
  //     onTap: () {
  //       if (onTap != null) {
  //         onTap();
  //       } else if (routeName != null) {
  //         setState(() {
  //           _selectedRoute = routeName;
  //         });
  //         Navigator.pushNamed(context, routeName);
  //       }
  //       // Si ni onTap ni routeName, rien ne se passe (pas de bug)
  //     },
  //     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  //     contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
  //   );
  // }







  Widget _buildHeroSection() {
    // Liste des traductions avec la langue et le texte
    final List<Map<String, String>> translations = [
      {'lang': 'Français', 'text': 'Trouvez votre\nmaison idéale'},
      {'lang': 'Lingala', 'text': 'Luka ndaku nayo\nya malamu'},
      {'lang': 'Kikongo', 'text': 'Sosa nzo na nge\nya mfunu'},
      {'lang': 'Swahili', 'text': 'Tafuta nyumba\nyako bora'},
      {'lang': 'Tshiluba', 'text': 'Sakaja nzu\nna wuwa'},
      {'lang': 'English', 'text': 'Find your\ndream home'},
    ];

    // Contrôleur pour le carrousel de texte
    final PageController _textController = PageController();
    int _currentLangIndex = 0;

    // Animation automatique du carrousel
    void _startAutoScroll() {
      Future.delayed(Duration(seconds: 3), () {
        if (_textController.hasClients) {
          _currentLangIndex = (_currentLangIndex + 1) % translations.length;
          _textController.animateToPage(
            _currentLangIndex,
            duration: Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );
          _startAutoScroll();
        }
      });
    }

    // Démarrer l'animation au premier build
    WidgetsBinding.instance.addPostFrameCallback((_) => _startAutoScroll());

    return Padding(
      padding: const EdgeInsets.only(top: 20.0),
      child: Center(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: 240,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              colors: [primaryColor, accentColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: [0.1, 0.9],
            ),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withOpacity(0.2),
                spreadRadius: 2,
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                right: -20,
                bottom: -20,
                child: Opacity(
                  opacity: 0.8,
                  child: Icon(
                    FontAwesomeIcons.buildingCircleCheck,
                    size: 180,
                    color: Colors.white.withOpacity(0.15),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(28.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Conteneur pour le carrousel de texte
                    SizedBox(
                      height: 80, // Hauteur fixe pour éviter le saut de contenu
                      child: PageView.builder(
                        controller: _textController,
                        itemCount: translations.length,
                        physics: NeverScrollableScrollPhysics(), // Désactive le scroll manuel
                        itemBuilder: (context, index) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                translations[index]['text']!,
                                style: TextStyle(
                                  fontSize: 25,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  height: 1.2,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    Text(
                      'Plus de 10,000 propriétés exclusives',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.95),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Spacer(),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 12,
                              offset: Offset(0, 4))
                        ],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: primaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                          padding: EdgeInsets.symmetric(
                              horizontal: 24, vertical: 14),
                          elevation: 0,
                        ),
                        icon: Icon(Icons.search_rounded, size: 22),
                        label: Text(
                          'Explorer maintenant',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  Widget _buildCategorySection() {
    final categories = [
      {
        'image': 'assets/images/studio.png',
        'label': 'Studio',
        'value': 'Studios'
      },
      {
        'image': 'assets/images/apart.png', // Chemin local
        'label': 'Apparts',
        'value': 'Apparts'
      },
      {
        'image': 'assets/images/maisons.png',
        'label': 'Maisons',
        'value': 'Maisons'
      },
      {
        'image': 'assets/images/office.png',
        'label': 'Bureaux',
        'value': 'Bureaux'
      },
      {
        'image': 'assets/images/hotel.png',
        'label': 'Hotels',
        'value': 'Hotels'
      },
      {
        'image': 'assets/images/plage.png',
        'label': 'Vacances',
        'value': 'Vacances'
      },

    ];

    return Container(
      height: 140,
      margin: EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Catégories',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
          ),
          SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 20),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                return Container(
                  width: 90,
                  margin: EdgeInsets.only(right: 8),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () async {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CategoryPropertiesPage(
                              category: categories[index]['value'] as String,
                            ),
                          ),
                        );
                      },
                      splashColor: primaryColor.withOpacity(0.1),
                      highlightColor: primaryColor.withOpacity(0.05),
                      child: Padding(
                        padding: EdgeInsets.all(8),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Image.asset(
                                  categories[index]['image'] as String,
                                  width: 40,
                                  height: 40,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                            SizedBox(height: 10),
                            Text(
                              categories[index]['label'] as String,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[700],
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
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
        ],
      ),
    );
  }


  // Widget _buildCategorySection() {
  //   final categories = [
  //     {'icon': FontAwesomeIcons.building, 'label': 'Apparts', 'value': 'Apparts'},
  //     {'icon': FontAwesomeIcons.house, 'label': 'Maisons', 'value': 'Maisons'},
  //     {'icon': FontAwesomeIcons.houseChimney, 'label': 'Villas', 'value': 'Villas'},
  //     {'icon': FontAwesomeIcons.buildingColumns, 'label': 'Bureaux', 'value': 'Bureaux'},
  //     {'icon': FontAwesomeIcons.umbrellaBeach, 'label': 'Vacances', 'value': 'Vacances'},
  //     {'icon': FontAwesomeIcons.city, 'label': 'Résidences', 'value': 'Résidences'},
  //     {'icon': FontAwesomeIcons.hotel, 'label': 'Hôtels', 'value': 'Hôtels'},
  //   ];
  //
  //   return Container(
  //     height: 140,
  //     margin: EdgeInsets.only(bottom: 10),
  //     child: Column(
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       children: [
  //         Padding(
  //           padding: EdgeInsets.symmetric(horizontal: 24),
  //           child: Text(
  //             'Catégories',
  //             style: TextStyle(
  //               fontSize: 18,
  //               fontWeight: FontWeight.bold,
  //               color: Colors.grey[800],
  //             ),
  //           ),
  //         ),
  //         SizedBox(height: 12),
  //         Expanded(
  //           child: ListView.builder(
  //             scrollDirection: Axis.horizontal,
  //             padding: EdgeInsets.symmetric(horizontal: 20),
  //             itemCount: categories.length,
  //             itemBuilder: (context, index) {
  //               return Container(
  //                 width: 90,
  //                 margin: EdgeInsets.only(right: 8),
  //                 child: Material(
  //                   color: Colors.transparent,
  //                   child: InkWell(
  //                     borderRadius: BorderRadius.circular(18),
  //                     onTap: () async {
  //                       Navigator.push(
  //                         context,
  //                         MaterialPageRoute(
  //                           builder: (context) => CategoryPropertiesPage(
  //                             category: categories[index]['value'] as String,
  //                           ),
  //                         ),
  //                       );
  //                     },
  //                     splashColor: primaryColor.withOpacity(0.1),
  //                     highlightColor: primaryColor.withOpacity(0.05),
  //                     child: Padding(
  //                       padding: EdgeInsets.all(8),
  //                       child: Column(
  //                         mainAxisAlignment: MainAxisAlignment.center,
  //                         children: [
  //                           Container(
  //                             width: 56,
  //                             height: 56,
  //                             decoration: BoxDecoration(
  //                               color: primaryColor.withOpacity(0.1),
  //                               borderRadius: BorderRadius.circular(16),
  //                             ),
  //                             child: Icon(
  //                               categories[index]['icon'] as IconData,
  //                               size: 24,
  //                               color: primaryColor,
  //                             ),
  //                           ),
  //                           SizedBox(height: 10),
  //                           Text(
  //                             categories[index]['label'] as String,
  //                             style: TextStyle(
  //                               fontSize: 12,
  //                               fontWeight: FontWeight.w600,
  //                               color: Colors.grey[700],
  //                             ),
  //                             textAlign: TextAlign.center,
  //                             maxLines: 2,
  //                           ),
  //                         ],
  //                       ),
  //                     ),
  //                   ),
  //                 ),
  //               );
  //             },
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
    required VoidCallback onSeeAll,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: darkBlue,
                ),
              ),
              InkWell(
                onTap: onSeeAll,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'voir',
                        style: TextStyle(
                          color: primaryColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                        color: primaryColor,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildShimmerLoading() {
    return Container(
      height: 320,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.only(left: 24, right: 8),
        itemCount: 3, // Nombre d'éléments shimmer à afficher
        itemBuilder: (context, index) {
          return Container(
            width: 260,
            margin: EdgeInsets.only(right: 16),
            child: Shimmer.fromColors(
              baseColor: Colors.grey[300]!,
              highlightColor: Colors.grey[100]!,
              period: Duration(milliseconds: 1500),
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  // Placeholder pour l'image
                  Container(
                  height: 160,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  // Placeholder pour les détails
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          height: 20,
                          color: Colors.white,
                        ),
                        SizedBox(height: 10),
                        Container(
                          width: 150,
                          height: 15,
                          color: Colors.white,
                        ),
                        SizedBox(height: 20),
                        Container(
                          height: 40,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Container(width: 60, height: 15, color: Colors.white),
                              Container(width: 60, height: 15, color: Colors.white),
                              Container(width: 60, height: 15, color: Colors.white),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  )
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPropertyCarousel({
    required List<PropertyModel> properties,
    required bool isForRent,
    required bool isLoading,
  }) {

    if (isLoading) {
      return _buildShimmerLoading();
    }

    if (properties.isEmpty) {
      return Container(
        height: 180,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off, size: 48, color: Colors.grey[400]),
              SizedBox(height: 16),
              Text(
                'Aucune propriété disponible',
                style: GoogleFonts.inter(
                  color: Colors.grey[600],
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Essayez de modifier vos critères',
                style: GoogleFonts.inter(
                  color: Colors.grey[400],
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      height: 380,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: 24),
        itemCount: min(5, properties.length),
        itemBuilder: (context, index) {
          final property = properties[index];
          final firstImagePath = property.images?.isNotEmpty ?? false
              ? property.images!.first.path
              : null;

          final priceText = isForRent
              ? '${property.price?.toStringAsFixed(0) ?? '0'}\$/mois'
              : '${property.price?.toStringAsFixed(0) ?? '0'}\$';

          return Container(
            width: 280,
            margin: EdgeInsets.only(right: 20, bottom: 10, top: 10),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      Routes.detailPageRoute,
                      arguments: property,
                    );
                  },
                  child: AnimatedContainer(
                    duration: Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          spreadRadius: 0,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        // Image de fond avec effet de parallaxe
                        Positioned.fill(
                          child: Hero(
                            tag: 'property-image-${property.PropertyId}',
                            child: AnimatedSwitcher(
                              duration: Duration(milliseconds: 500),
                              child: firstImagePath != null
                                  ? CachedNetworkImage(
                                imageUrl: "${Constantes.URL_IMAGES}${firstImagePath}",
                                fit: BoxFit.cover,
                                key: ValueKey(firstImagePath),
                              )
                                  : Container(
                                color: Colors.grey[200],
                                child: Center(
                                  child: Icon(
                                    Icons.photo_outlined,
                                    size: 48,
                                    color: Colors.grey[400],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Gradient overlay moderne
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.9),
                              ],
                              stops: [0.4, 1],
                            ),
                          ),
                        ),

                        // Contenu principal
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              // Titre avec effet de surbrillance au hover
                              MouseRegion(
                                cursor: SystemMouseCursors.click,
                                child: AnimatedContainer(
                                  duration: Duration(milliseconds: 200),
                                  padding: EdgeInsets.symmetric(vertical: 4),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        primaryColor.withOpacity(0.2),
                                        Colors.transparent,
                                      ],
                                      stops: [0, 0.5],
                                    ),
                                  ),
                                  child: Text(
                                    property.title ?? 'Sans titre',
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                      height: 1.3,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),

                              SizedBox(height: 8),

                              // Adresse avec animation subtile
                              AnimatedOpacity(
                                opacity: 0.9,
                                duration: Duration(milliseconds: 300),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.location_on_outlined,
                                      size: 16,
                                      color: Colors.white.withOpacity(0.8),
                                    ),
                                    SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        '${property.commune ?? ''}, ${property.city ?? ''}',
                                        style: GoogleFonts.inter(
                                          color: Colors.white.withOpacity(0.8),
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              SizedBox(height: 20),

                              // Prix - Design moderne avec effet de profondeur
                              Transform.translate(
                                offset: Offset(0, 0),
                                child: AnimatedContainer(
                                  duration: Duration(milliseconds: 300),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 18,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        primaryColor.withOpacity(0.95),
                                        primaryColor.withOpacity(0.8),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.3),
                                        blurRadius: 12,
                                        offset: Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        priceText,
                                        style: GoogleFonts.inter(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              SizedBox(height: 16),

                              // Caractéristiques - Design minimaliste
                              Container(
                                height: 50,
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.4),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: EdgeInsets.symmetric(horizontal: 12),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: [
                                    _buildModernFeatureItem(
                                      icon: FontAwesomeIcons.bed,
                                      value: '${property.bedrooms ?? 0}',
                                    ),
                                    _buildModernFeatureItem(
                                      icon: FontAwesomeIcons.bath,
                                      value: '${property.bathroom ?? 0}',
                                    ),
                                    _buildModernFeatureItem(
                                      icon: FontAwesomeIcons.rulerCombined,
                                      value: '${property.surface?.toStringAsFixed(0) ?? '0'}',
                                    ),
                                    _buildModernFeatureItem(
                                      icon: Icons.zoom_out_map,
                                      value: '${property.rooms ?? 0}',
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Badge type + bouton favoris
                        Positioned(
                          top: 16,
                          left: 16,
                          right: 16,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Badge type avec animation
                              AnimatedContainer(
                                duration: Duration(milliseconds: 300),
                                padding: EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: isForRent
                                      ? Colors.blueAccent.withOpacity(0.9)
                                      : Colors.greenAccent.withOpacity(0.9),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 8,
                                      spreadRadius: 0,
                                    ),
                                  ],
                                ),
                                child: Text(
                                  isForRent ? 'À LOUER' : 'À VENDRE',
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),

                              // Remplacement du InkWell par FavoriteHeartIcon
                              FavoriteHeartIcon(
                                propertyId: property.PropertyId.toString(),
                                size: 30,
                                splashRadius: 5,
                                activeColor: primaryColor,
                                inactiveColor: primaryColor,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildModernFeatureItem({required IconData icon, required String value}) {
    return Tooltip(
      message: icon == FontAwesomeIcons.bed
          ? 'Chambres'
          : icon == FontAwesomeIcons.bath
          ? 'Salles de bain'
          : icon == FontAwesomeIcons.rulerCombined
          ? 'Surface (m²)'
          : 'Pièces',
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: Colors.white.withOpacity(0.9)),
          SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }


  String _getFeatureLabel(IconData icon, String value) {
    if (icon == FontAwesomeIcons.bed) return '$value Chambre${int.parse(value) > 1 ? 's' : ''}';
    if (icon == FontAwesomeIcons.bath) return '$value Salle${int.parse(value) > 1 ? 's' : ''} de bain';
    if (icon == FontAwesomeIcons.rulerCombined) return '$value mètres carrés';
    if (icon == Icons.zoom_out_map) return '$value Pièce${int.parse(value) > 1 ? 's' : ''}';
    return '';
  }

  Widget _buildFeatureChip({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Icon(
          icon,
          size: 18,
          color: Colors.white,
        ),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 10,
          ),
        ),
      ],
    );
  }

}