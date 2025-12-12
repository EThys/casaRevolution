import 'dart:math';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:casa/controllers/PropertyCtrl.dart';
import 'package:casa/controllers/ServiceController.dart';
import 'package:casa/screens/AllPropertiesPage.dart';
import 'package:casa/screens/PromoBanner.dart';
import 'package:casa/screens/auth/LoginScreen.dart';
import 'package:casa/utils/Constantes.dart';
import 'package:casa/utils/FancyNotification.dart';
import 'package:casa/utils/FavoriteEartIcon.dart';
import 'package:casa/utils/StockageKeys.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:shimmer/shimmer.dart';

import '../models/PropertyModel.dart';
import '../models/ServiceModel.dart';
import '../utils/Routes.dart';
import '../utils/database/FavoriteDatabaseHelper.dart';
import '../utils/database/ReservationDatabaseHelper.dart';
import 'CategoryPropertiesPage.dart';
import 'AllServiceCategoriesPage.dart';
import 'NotificationPage.dart';
import '../utils/DraftHelper.dart';
import '../utils/static_services_data.dart';
import 'ServiceDetailPage.dart';
import 'ServiceCategoryPage.dart';
import 'QuickServiceRequestModal.dart';
import 'QuickServiceRequestPage.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final RefreshController _refreshController = RefreshController();
  bool _isManualRefresh = false;

  final Color primaryColor = Color(0xFF1976D2);
  final Color accentColor = Color(0xFF64B5F6);
  final Color darkBlue = Color(0xFF0D47A1);
  final GetStorage storage = GetStorage();

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  void _loadInitialData() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final propertyCtrl = Provider.of<PropertyController>(context, listen: false);
      final serviceCtrl = Provider.of<ServiceController>(context, listen: false);
      
      propertyCtrl.getAllProperty().then((_) {
        _logHomePageLoaded(propertyCtrl.properties.length);
      });
      
      // Charger tous les services
      serviceCtrl.fetchServices();
    });
  }

  void _logHomePageLoaded(int propertyCount) {
    print("🏠 Page accueil chargée: $propertyCount propriétés");
  }

  void _logPropertyView(PropertyModel property, bool isForRent) {
    print("👀 Propriété vue: ${property.propertyId} - ${isForRent ? 'Location' : 'Vente'}");
  }

  void _logCategoryTap(String category) {
    print("📁 Catégorie tapée: $category");
  }

  void _logUserLogout() {
    print("🚪 Déconnexion utilisateur");
  }

  @override
  Widget build(BuildContext context) {
    var propertyCtrl = context.watch<PropertyController>();
    var serviceCtrl = context.watch<ServiceController>();
    var properties = propertyCtrl.properties;
    var services = serviceCtrl.services;

    final rentalProperties = properties.where((p) => p.transactionType == 'location').toList();
    final saleProperties = properties.where((p) => p.transactionType == 'vente').toList();
    
    // Utiliser les données statiques pour majordome et demenagement
    final staticServices = StaticServicesData.getStaticServices();
    final majordhommeServices = staticServices.where((s) => s.serviceType == ServiceType.majordhomme).toList();
    final demenagementServices = staticServices.where((s) => s.serviceType == ServiceType.demenagement).toList();
    
    // Autres services (excluant majordhomme et demenagement)
    final otherServices = services.where((s) => 
      s.serviceType != ServiceType.majordhomme && 
      s.serviceType != ServiceType.demenagement
    ).toList();
    
    // Grouper les autres services par type
    final Map<ServiceType, List<ServiceModel>> servicesByType = {};
    for (var service in otherServices) {
      if (service.serviceType != null) {
        servicesByType.putIfAbsent(service.serviceType!, () => []).add(service);
      }
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.grey[50],
      drawer: _buildDrawer(),
      appBar: _buildAppBar(),
      body: SmartRefresher(
        controller: _refreshController,
        enablePullDown: true,
        enablePullUp: false,
        header: ClassicHeader(
          height: 60,
          releaseText: 'Relâchez pour actualiser',
          refreshingText: 'Mise à jour...',
          completeText: 'Actualisation terminée',
          failedText: 'Échec de l\'actualisation',
          idleText: 'Tirez pour actualiser',
          textStyle: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          refreshingIcon: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
            ),
          ),
        ),
        onRefresh: () async {
          await _handlePullToRefresh(propertyCtrl);
        },
        child: SingleChildScrollView(
          physics: NeverScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ============================================
              // ZONE 1 : HERO & NAVIGATION RAPIDE
              // ============================================
              _buildHeroSection(),
              SizedBox(height: 24),

              _buildCategorySection(),
              SizedBox(height: 15),
              
              if (propertyCtrl.syncing && !_isManualRefresh)
                Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: _buildMinimalSyncIndicator(),
                ),

              if (_isManualRefresh && propertyCtrl.syncing)
                Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: _buildMinimalSyncIndicator(),
                ),

              // ============================================
              // ZONE 2 : PROPRIÉTÉS (Contenu principal)
              // ============================================
              // PromoBanner avant propriétés (séparateur visuel)
              PromoBanner(),
              SizedBox(height: 32),
              
              // Section Locations (priorité car plus recherchée)
              _buildSectionHeader(
                title: "Maisons en Location",
                subtitle: "Découvrez nos meilleures offres",
                onSeeAll: () {
                  _logCategoryTap('locations_see_all');
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
              SizedBox(height: 16),
              _buildPropertyCarousel(
                isForRent: true,
                properties: rentalProperties,
                isLoading: propertyCtrl.loading,
              ),
              SizedBox(height: 32),
              
              // Section Ventes
              _buildSectionHeader(
                title: "Maisons en Vente",
                subtitle: "Investissez dans votre avenir",
                onSeeAll: () {
                  _logCategoryTap('ventes_see_all');
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
              SizedBox(height: 16),
              _buildPropertyCarousel(
                isForRent: false,
                properties: saleProperties,
                isLoading: propertyCtrl.loading,
              ),
              SizedBox(height: 32),
              
              // ============================================
              // ZONE 3 : SERVICES PRINCIPAUX
              // ============================================
              // PromoBanner avant services (transition visuelle)
              PromoBanner(),
              SizedBox(height: 32),
              
              // Section Services Majordome (service populaire)
              _buildSectionHeader(
                title: "Femme de Ménage",
                subtitle: "Nettoyage professionnel à domicile",
                onSeeAll: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ServiceCategoryPage(
                        serviceType: ServiceType.majordhomme,
                        services: majordhommeServices,
                      ),
                    ),
                  );
                },
              ),
              SizedBox(height: 16),
              _buildServiceCarousel(
                services: majordhommeServices,
                isLoading: false,
                serviceType: ServiceType.majordhomme,
              ),
              SizedBox(height: 32),
              
              // Section Services de Déménagement
              _buildSectionHeader(
                title: "Déménagement",
                subtitle: "Déménagez en toute sérénité",
                onSeeAll: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ServiceCategoryPage(
                        serviceType: ServiceType.demenagement,
                        services: demenagementServices,
                      ),
                    ),
                  );
                },
              ),
              SizedBox(height: 16),
              _buildServiceCarousel(
                services: demenagementServices,
                isLoading: false,
                serviceType: ServiceType.demenagement,
              ),
              SizedBox(height: 32),
              
              // ============================================
              // ZONE 4 : AUTRES SERVICES (Complémentaire)
              // ============================================
              _buildSectionHeader(
                title: "Autres Services",
                subtitle: "Découvrez tous nos professionnels",
                onSeeAll: () { 
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AllServiceCategoriesPage(),
                    ),
                  );
                },
              ),
              SizedBox(height: 16),
              _buildOtherServicesGrid(
                servicesByType: servicesByType,
                isLoading: serviceCtrl.loading,
              ),
              SizedBox(height: 32),
              
              // ============================================
              // ZONE 5 : CALL-TO-ACTION FINAL
              // ============================================
              // PromoBanner final (engagement en fin de parcours)
              PromoBanner(),
              SizedBox(height: 32),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: "home_page_fab", // Tag unique pour éviter les conflits Hero
        onPressed: () {
          _showQuickServiceRequest();
        },
        backgroundColor: primaryColor,
        elevation: 4,
        child: Icon(
          Icons.add_task_rounded,
          color: Colors.white,
          size: 28,
        ),
        tooltip: 'Demander un service',
      ),
    );
  }

  Widget _buildMinimalSyncIndicator() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      padding: EdgeInsets.all(8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
            ),
          ),
          SizedBox(width: 8),
          Text(
            'Chargement...',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handlePullToRefresh(PropertyController propertyCtrl) async {
    setState(() {
      _isManualRefresh = true;
    });

    try {
      await propertyCtrl.refreshProperties();
      _refreshController.refreshCompleted();
      //SnackbarForCasa.success(context, "Liste actualisée");
    } catch (e) {
      print("❌ Erreur refresh: $e");
      _refreshController.refreshFailed();
      SnackbarForCasa.error(context, "Erreur de connexion");
    } finally {
      setState(() {
        _isManualRefresh = false;
      });
    }
  }

  void _showMinimalRefreshSuccess() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Liste actualisée'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: Duration(seconds: 1),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        margin: EdgeInsets.all(16),
      ),
    );
  }

  void _showMinimalRefreshError() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Erreur de connexion'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: Duration(seconds: 2),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        margin: EdgeInsets.all(16),
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
          onPressed: () {
            _scaffoldKey.currentState?.openDrawer();
          },
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
                'assets/images/logoCasa.png',
                height: 20,
                width: 20,
              ),
            ),
            SizedBox(width: 10),
            Text(
              "CasaNayo",
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
                  Navigator.pushNamed(context, Routes.notificationPageRoute);
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

  Future<void> _clearLocalAuthData() async {
    try {
      print("🔒 Début de la déconnexion...");

      // 1. Liste de toutes les clés à supprimer
      final List<String> keysToRemove = [
        StockageKeys.tokenKey,
        StockageKeys.refreshTokenKey,
        StockageKeys.userKey,
        StockageKeys.userPreferenceKey,
        StockageKeys.profileKey,
        'user_image_path',
        'profile_image_path',
        'card_front_path',
        'card_back_path',
        'published_properties_count',
        'referrals_count',
        'user_data'
      ];

      // 2. Supprimer chaque clé individuellement avec gestion d'erreur
      for (final key in keysToRemove) {
        try {
          await storage.remove(key);
          print("✅ Clé supprimée: $key");
        } catch (e) {
          print("⚠️ Impossible de supprimer la clé $key: $e");
          // Continuer même si une clé échoue
        }
      }

      // 3. Vider les bases de données
      try {
        await FavoriteDatabaseHelper.instance.clearAllFavorites();
        print("✅ Favoris supprimés");
      } catch (e) {
        print("⚠️ Erreur lors de la suppression des favoris: $e");
      }

      try {
        await ReservationDatabaseHelper.instance.clearAllReservations();
        print("✅ Réservations supprimées");
      } catch (e) {
        print("⚠️ Erreur lors de la suppression des réservations: $e");
      }

      // 4. Supprimer TOUS les brouillons lors de la déconnexion
      try {
        await DraftHelper.clearAllDrafts();
        print("✅ Tous les brouillons supprimés");
      } catch (e) {
        print("⚠️ Erreur lors de la suppression des brouillons: $e");
      }

      // 5. Forcer l'écriture des changements
      await storage.write('logout_timestamp', DateTime.now().millisecondsSinceEpoch);

      print("✅ Déconnexion réussie - Toutes les données ont été nettoyées");

    } catch (e) {
      print("❌ Erreur critique lors de la déconnexion: $e");

      try {
        await storage.remove(StockageKeys.tokenKey);
        await storage.remove(StockageKeys.userKey);
        print("✅ Clés essentielles supprimées malgré l'erreur");
      } catch (criticalError) {
        print("❌❌ Échec critique de la déconnexion: $criticalError");
        throw criticalError; // Relancer seulement l'erreur critique
      }
    }
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Déconnexion'),
        content: const Text('Voulez-vous vraiment vous déconnecter ?'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).primaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => _performLogout(),
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

  Future<void> _performLogout() async {
    // Fermer la dialog d'abord
    Navigator.pop(context);

    try {
      // 1. Nettoyer les données
      await _clearLocalAuthData();

      // 2. Attendre un cycle de frame pour éviter les conflits
      await Future.delayed(Duration(milliseconds: 100));

      // 3. Recharger la page pour mettre à jour l'interface
      if (mounted) {
        setState(() {
          // Le setState va déclencher un rebuild et faire disparaître les éléments nécessitant une connexion
        });
      }

      // 4. Naviguer vers la page d'accueil après un court délai pour voir le changement
      await Future.delayed(Duration(milliseconds: 300));
      
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          Routes.bottomPageRoute,
          (route) => false,
        );
      }

    } catch (e) {
      print("❌ Erreur lors de la déconnexion: $e");

      // Même en cas d'erreur, recharger la page
      if (mounted) {
        setState(() {});
        
        // Naviguer vers la page d'accueil
        Navigator.pushNamedAndRemoveUntil(
          context,
          Routes.bottomPageRoute,
          (route) => false,
        );
      }
    }
  }

  Widget _buildDrawer() {
    final stockage = GetStorage();
    final token = stockage.read(StockageKeys.tokenKey);
    final user = stockage.read(StockageKeys.userKey);
    final profile = stockage.read(StockageKeys.profileKey);
    bool isLoggedIn = token != null;

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
                          GestureDetector(
                            onTap: () {
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
                          SizedBox(height: 8),
                          AnimatedSwitcher(
                            duration: Duration(milliseconds: 300),
                            child: isLoggedIn
                                ? Container(
                              constraints: BoxConstraints(
                                maxWidth: 200, // Limite la largeur maximale
                              ),
                              child: Text(
                                _getDisplayName(profile, user),
                                key: ValueKey('user'),
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
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                              ),
                            )
                                : Column(
                              key: ValueKey('welcome'),
                              children: [
                                Text(
                                  'Bienvenue 👋',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
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
                                SizedBox(height: 4),
                                Container(
                                  constraints: BoxConstraints(
                                    maxWidth: 200, // Limite la largeur maximale
                                  ),
                                  child: Text(
                                    'Connectez-vous pour accéder à toutes les fonctionnalités',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.9),
                                      fontSize: 11, // Réduit la taille de police
                                      fontWeight: FontWeight.normal,
                                      height: 1.3,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
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
              // ... le reste du code reste inchangé
              Expanded(
                child: SingleChildScrollView(
                  physics: BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      SizedBox(height: 16),

                      // SECTION PRINCIPAL
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
                            routeName: Routes.favoriteRoute,
                            isSelected:  selectedRoute == Routes.favoriteRoute,
                            onTap: () => _handleNavigation(Routes.favoriteRoute),
                          ),
                          _buildDrawerItem(
                            icon: Icons.add_task_rounded,
                            title: 'Demander un service',
                            routeName: Routes.quickServiceRequestRoute,
                            isSelected: selectedRoute == Routes.quickServiceRequestRoute,
                            onTap: () => _handleNavigation(Routes.quickServiceRequestRoute),
                          ),
                          if (isLoggedIn) ...[
                            _buildDrawerItem(
                              icon: Icons.request_quote_rounded,
                              title: 'Mes demandes',
                              routeName: Routes.myServiceRequestsRoute,
                              isSelected: selectedRoute == Routes.myServiceRequestsRoute,
                              onTap: () => _handleNavigation(Routes.myServiceRequestsRoute),
                            ),
                            _buildDrawerItem(
                              icon: Icons.construction_rounded,
                              title: 'Demander intervention',
                              routeName: Routes.requestInterventionRoute,
                              isSelected: selectedRoute == Routes.requestInterventionRoute,
                              onTap: () {
                                // Note: Cette route nécessite un ServiceModel en argument
                                // Pour l'instant, on affiche juste un message
                                Navigator.pop(context);
                                SnackbarForCasa.info(
                                  context,
                                  "Sélectionnez un service pour demander une intervention",
                                );
                              },
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
                            _buildDrawerItem(
                              icon: Icons.apartment_rounded,
                              title: 'Mes propriétés',
                              routeName: Routes.myPropertiesRoute,
                              isSelected: selectedRoute == Routes.myPropertiesRoute,
                              onTap: () => _handleNavigation(Routes.myPropertiesRoute),
                            ),
                          ],
                        ],
                      ),

                      // SECTION SOCIAL
                      _buildDrawerSection(
                        title: "SOCIAL",
                        items: [
                          if(isLoggedIn)
                            _buildDrawerItem(
                              icon: Icons.people_alt_rounded,
                              title: 'Parrainer',
                              routeName: Routes.ParrainagePageRoute,
                              isSelected: selectedRoute == Routes.ParrainagePageRoute,
                              onTap: () => _handleNavigation(Routes.ParrainagePageRoute),
                            ),
                          _buildDrawerItem(
                            icon: Icons.share_rounded,
                            title: 'Partager l\'app',
                            isSelected: selectedRoute == '/share',
                            onTap: () => _handleNavigation('/share'),
                          ),
                        ],
                      ),

                      // SECTION SUPPORT
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

                      // SECTION COMPTE (seulement si connecté)
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

                      // BOUTONS CONNEXION/INSCRIPTION (seulement si NON connecté)
                      if (!isLoggedIn) ...[
                        SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            children: [
                              // Bouton Se connecter
                              Container(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    Navigator.pushNamed(context, Routes.loginRoute);
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryColor,
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 2,
                                    shadowColor: primaryColor.withOpacity(0.3),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.login_rounded, size: 20),
                                      SizedBox(width: 8),
                                      Text(
                                        'Se connecter',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              SizedBox(height: 12),
                              // Bouton S'inscrire
                              Container(
                                width: double.infinity,
                                child: OutlinedButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    Navigator.pushNamed(context, Routes.registerRoute);
                                  },
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: primaryColor,
                                    side: BorderSide(color: primaryColor, width: 1.5),
                                    padding: EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    backgroundColor: Colors.transparent,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.person_add_rounded, size: 20),
                                      SizedBox(width: 8),
                                      Text(
                                        'Créer un compte',
                                        style: TextStyle(
                                          fontSize: 15,
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
                        SizedBox(height: 16),
                      ],

                      SizedBox(height: 20),
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


  String _getDisplayName(dynamic profile, dynamic user) {
    // Priorité aux données du profil, puis user
    if (profile != null && profile is Map) {
      final fullname = profile['fullname']?.toString();
      if (fullname != null && fullname.isNotEmpty && fullname != 'null') {
        return fullname;
      }
    }
    if (user != null && user is Map) {
      final username = user['username']?.toString();
      if (username != null && username.isNotEmpty && username != 'null') {
        return username;
      }
      final email = user['email']?.toString();
      if (email != null && email.isNotEmpty) {
        return email.split('@').first;
      }
    }
    return 'Utilisateur';
  }

  void _handleNavigation(String routeName) {
    Navigator.pop(context);

    if (routeName == Routes.bottomPageRoute ||
        routeName == Routes.commissionnaireDashboardPageRoute ||
        routeName == Routes.favoriteRoute ||
        routeName == Routes.myPropertiesRoute ||
        routeName == Routes.bookingHistoryPageRoute ||
        routeName == Routes.quickServiceRequestRoute ||
        routeName == Routes.myServiceRequestsRoute ||
        routeName == Routes.notificationPageRoute) {
      Navigator.pushNamed(context, routeName);
    } else {
      SnackbarForCasa.info(
        context,
        "Fonctionnalité en cours de développement",
      );
    }
  }

  void _showQuickServiceRequest() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => QuickServiceRequestModal(),
    );
  }

  void _animateAvatar() {
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

  Widget _buildHeroSection() {
    final List<Map<String, String>> translations = [
      {'lang': 'Français', 'text': 'Trouvez votre\nmaison idéale'},
      {'lang': 'Lingala', 'text': 'Luka ndaku nayo\nya malamu'},
      {'lang': 'Kikongo', 'text': 'Sosa nzo na nge\nya mfunu'},
      {'lang': 'Swahili', 'text': 'Tafuta nyumba\nyako bora'},
      {'lang': 'Tshiluba', 'text': 'Sakaja nzu\nna wuwa'},
      {'lang': 'English', 'text': 'Find your\ndream home'},
    ];

    final PageController _textController = PageController();
    int _currentLangIndex = 0;

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
                    SizedBox(
                      height: 80,
                      child: PageView.builder(
                        controller: _textController,
                        itemCount: translations.length,
                        physics: NeverScrollableScrollPhysics(),
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
        'label': 'Studios',
        'value': 'Studio',
      },
      {
        'image': 'assets/images/apart.png',
        'label': 'Apparts',
        'value': 'Apparts',
      },
      {
        'image': 'assets/images/maison.png',
        'label': 'Maisons',
        'value': 'Maisons',
      },
      {
        'image': 'assets/images/office.png',
        'label': 'Bureaux',
        'value': 'Bureau',
      },
      {
        'image': 'assets/images/hotel.png',
        'label': 'Hotels',
        'value': 'Hotels',
      },
      {
        'image': 'assets/images/plage.png',
        'label': 'Vacances',
        'value': 'Vacances',
      },
      {
        'image': 'assets/images/Terrain.png',
        'label': 'Terrain',
        'value': 'Terrain',
      },
      {
        'image': 'assets/images/fete.png',
        'label': 'Salle de fête',
        'value': 'Salle de fête',
      },
      {
        'image': 'assets/images/funebre.png',
        'label': 'Salle funéraires',
        'value': 'Salle funéraires',
      },
      {
        'image': 'assets/images/Entrepot.png',
        'label': 'Entrepôt',
        'value': 'Entrepôt',
      },
    ];

    return Container(
      margin: EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Explorer par type',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[900],
                    letterSpacing: -0.2,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AllServiceCategoriesPage(),
                      ),
                    );
                  },
                  child: Text(
                    'Voir tout',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: primaryColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 5),
          Container(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 12),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final category = categories[index];
                return Container(
                  width: 80,
                  margin: EdgeInsets.symmetric(horizontal: 4),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        _logCategoryTap(category['value'] as String);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CategoryPropertiesPage(
                              category: category['value'] as String,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        padding: EdgeInsets.all(8),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Container simple et épuré pour l'image
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.grey[200]!,
                                  width: 1,
                                ),
                              ),
                              child: Padding(
                                padding: EdgeInsets.all(10),
                                child: Image.asset(
                                  category['image'] as String,
                                  fit: BoxFit.contain,
                                  filterQuality: FilterQuality.high,
                                ),
                              ),
                            ),
                            SizedBox(height: 8),
                            // Label sobre
                            Text(
                              category['label'] as String,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[700],
                                height: 1.1,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
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
                        'voir tout',
                        style: TextStyle(
                          color: primaryColor,
                          fontSize: 12,
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
        itemCount: 3,
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
                    Container(
                      height: 160,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                      ),
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

  Widget _buildServiceCarousel({
    required List<ServiceModel> services,
    required bool isLoading,
    required ServiceType serviceType,
  }) {
    if (isLoading) {
      return Container(
        height: 380,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: 24),
          itemCount: 3,
          itemBuilder: (context, index) {
            return Container(
              width: 280,
              margin: EdgeInsets.only(right: 20),
              child: Shimmer.fromColors(
                baseColor: Colors.grey[300]!,
                highlightColor: Colors.grey[100]!,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    color: Colors.white,
                  ),
                  height: 380,
                ),
              ),
            );
          },
        ),
      );
    }

    if (services.isEmpty) {
      return Container(
        height: 200,
        margin: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                serviceType.icon,
                size: 48,
                color: Colors.grey[400],
              ),
              SizedBox(height: 12),
              Text(
                'Aucun service disponible pour le moment',
                style: GoogleFonts.inter(
                  color: Colors.grey[600],
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
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
        itemCount: min(5, services.length),
        itemBuilder: (context, index) {
          final service = services[index];

          final firstImage = service.images?.isNotEmpty ?? false
              ? service.images!.first
              : null;
          final imageUrl = firstImage;

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
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ServiceDetailPage(service: service),
                      ),
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
                        Positioned.fill(
                          child: Hero(
                            tag: 'service-image-${service.serviceId}',
                            child: AnimatedSwitcher(
                              duration: Duration(milliseconds: 500),
                              child: imageUrl != null && imageUrl.isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: imageUrl,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      height: double.infinity,
                                      key: ValueKey(imageUrl),
                                      placeholder: (context, url) => Container(
                                        width: double.infinity,
                                        height: double.infinity,
                                        color: Colors.grey[200],
                                        child: Center(
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                                          ),
                                        ),
                                      ),
                                      errorWidget: (context, url, error) => Container(
                                        width: double.infinity,
                                        height: double.infinity,
                                        color: Colors.grey[200],
                                        child: Center(
                                          child: Icon(
                                            serviceType.icon,
                                            size: 48,
                                            color: Colors.grey[400],
                                          ),
                                        ),
                                      ),
                                    )
                                  : Container(
                                      width: double.infinity,
                                      height: double.infinity,
                                      color: Colors.grey[200],
                                      child: Center(
                                        child: Icon(
                                          serviceType.icon,
                                          size: 48,
                                          color: Colors.grey[400],
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                        ),
                        // Bouton favoris
                        Positioned(
                          top: 12,
                          right: 12,
                          child: FavoriteHeartIcon(
                            propertyId: 'service_${service.serviceId}',
                            size: 24,
                            splashRadius: 20,
                            activeColor: Colors.red,
                            inactiveColor: Colors.white,
                          ),
                        ),
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
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: primaryColor.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      serviceType.icon,
                                      size: 20,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 12),
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
                                    service.title ?? 'Service sans titre',
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
                                        service.address ?? 'Adresse non disponible',
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
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: primaryColor.withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _getPriceRange(service),
                                        style: GoogleFonts.inter(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: -0.5,
                                        ),
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
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _getPriceUnitShort(String unit) {
    switch (unit.toLowerCase()) {
      case 'par heure':
        return 'h';
      case 'par jour':
        return 'jour';
      case 'par nuit':
        return 'nuit';
      case 'par semaine':
        return 'sem.';
      case 'par mois':
        return 'mois';
      case 'par intervention':
        return 'interv.';
      case 'par projet':
        return 'projet';
      case 'par transport':
        return 'transport';
      case 'par déménagement':
        return 'démén.';
      case 'par visite':
        return 'visite';
      default:
        return unit;
    }
  }

  String _getPriceRange(ServiceModel service) {
    if (service.price == null) return 'Prix sur demande';

    final double basePrice = service.price!;
    // Calculer une plage de prix (±20%)
    final double minPrice = (basePrice * 0.8);
    final double maxPrice = (basePrice * 1.2);

    if (minPrice.round() == maxPrice.round()) {
      return '${_formatServicePrice(basePrice)} \$';
    }

    return '${_formatServicePrice(minPrice)} - ${_formatServicePrice(maxPrice)} \$';
  }

  String _formatServicePrice(num price) {
    if (price >= 1000000) {
      return '${(price / 1000000).toStringAsFixed(1)}M';
    } else if (price >= 1000) {
      return (price / 1000).toStringAsFixed(0) + 'K';
    }
    return price.toStringAsFixed(0);
  }

  Widget _buildOtherServicesGrid({
    required Map<ServiceType, List<ServiceModel>> servicesByType,
    required bool isLoading,
  }) {
    // Utiliser les données statiques
    final staticServices = StaticServicesData.getStaticServices();
    
    // Grouper par type de service
    final Map<ServiceType, List<ServiceModel>> groupedServices = {};
    for (var service in staticServices) {
      if (service.serviceType != null) {
        groupedServices.putIfAbsent(service.serviceType!, () => []).add(service);
      }
    }

    // Liste des types de services à afficher (priorité)
    final List<ServiceType> priorityServiceTypes = [
      ServiceType.plomberie,
      ServiceType.electricite,
      ServiceType.peinture,
      ServiceType.carrelage,
      ServiceType.climatisation,
      ServiceType.reparation,
      ServiceType.nettoyage,
      ServiceType.transport,
      ServiceType.renovation,
      ServiceType.installation,
      ServiceType.serrurerie,
      ServiceType.vitrerie,
    ];

    // Filtrer et trier les services par priorité
    final List<ServiceType> availableServiceTypes = priorityServiceTypes
        .where((type) => groupedServices.containsKey(type) && groupedServices[type]!.isNotEmpty)
        .take(6) // Limiter à 6 services pour la grille 2x3
        .toList();

    if (isLoading || availableServiceTypes.isEmpty) {
      return Container(
        height: 200,
        margin: EdgeInsets.symmetric(horizontal: 24),
        child: GridView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.85,
          ),
          itemCount: 6,
          itemBuilder: (context, index) {
            return Shimmer.fromColors(
              baseColor: Colors.grey[300]!,
              highlightColor: Colors.grey[100]!,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            );
          },
        ),
      );
    }

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 24),
      child: GridView.builder(
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          // Un ratio plus petit pour donner plus de hauteur et éviter l'overflow
          childAspectRatio: 0.72,
        ),
        itemCount: availableServiceTypes.length,
        itemBuilder: (context, index) {
          final serviceType = availableServiceTypes[index];
          final serviceList = groupedServices[serviceType]!;
          final serviceCount = serviceList.length;
          final firstService = serviceList.first;

          // Récupérer l'image de fond depuis le premier service
          final backgroundImageUrl = firstService.images != null && 
                                     firstService.images!.isNotEmpty
              ? firstService.images!.first
              : null;

          return Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ServiceCategoryPage(
                      serviceType: serviceType,
                      services: serviceList,
                    ),
                  ),
                );
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  height: double.infinity,
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 12,
                        spreadRadius: 0,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Image de fond
                      backgroundImageUrl != null
                          ? CachedNetworkImage(
                              imageUrl: backgroundImageUrl,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      primaryColor.withOpacity(0.3),
                                      primaryColor.withOpacity(0.1),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                                child: Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white.withOpacity(0.7),
                                    ),
                                  ),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      primaryColor.withOpacity(0.3),
                                      primaryColor.withOpacity(0.1),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                )
                              ),
                            )
                          : Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    primaryColor.withOpacity(0.3),
                                    primaryColor.withOpacity(0.1),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                            ),
                      
                      // Contenu superposé
                      Container(
                        padding: EdgeInsets.all(12),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.25),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.5),
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 8,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),

                            // Texte et badge en bas
                            Column(
                              children: [
                                Text(
                                  serviceType.displayName,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    height: 1.2,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black.withOpacity(0.5),
                                        offset: Offset(0, 1),
                                        blurRadius: 3,
                                      ),
                                    ],
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(height: 6),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.25),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.5),
                                      width: 1,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 4,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    '$serviceCount service${serviceCount > 1 ? 's' : ''}',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black.withOpacity(0.3),
                                          offset: Offset(0, 1),
                                          blurRadius: 2,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
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
    );
  }

  Widget _buildEmptyState() {
    return Container(
      height: 320,
      margin: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Illustration principale
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                color: Color(0xFF1976D2).withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.home_work_outlined,
                size: 70,
                color: Color(0xFF1976D2).withOpacity(0.6),
              ),
            ),

            SizedBox(height: 28),

            // Titre principal
            Text(
              'Aucune propriété disponible',
              style: GoogleFonts.inter(
                color: Colors.grey[800],
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
              textAlign: TextAlign.center,
            ),

            SizedBox(height: 12),

            // Description adaptée pour l'accueil
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Notre catalogue de propriétés est actuellement vide.\nNous ajoutons régulièrement de nouvelles annonces - revenez bientôt !',
                style: GoogleFonts.inter(
                  color: Colors.grey[600],
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            SizedBox(height: 28),

            // Bouton d'action principal
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFF1976D2).withOpacity(0.2),
                    blurRadius: 15,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: () {
                  // Rafraîchir les propriétés
                  final propertyCtrl = Provider.of<PropertyController>(context, listen: false);
                  propertyCtrl.getAllProperty();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF1976D2),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.refresh_rounded, size: 20),
                    SizedBox(width: 10),
                    Text(
                      'Actualiser la page',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 20),

            // Information complémentaire
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.grey[200]!,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 18,
                    color: Color(0xFF1976D2),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Nouvelles propriétés ajoutées quotidiennement',
                    style: GoogleFonts.inter(
                      color: Colors.grey[600],
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
        height: 280,
        margin: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Illustration moderne avec effet de cercle
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF1976D2).withOpacity(0.1),
                      Color(0xFF2196F3).withOpacity(0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xFF1976D2).withOpacity(0.1),
                      blurRadius: 15,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.home_work_outlined,
                  size: 50,
                  color: Color(0xFF1976D2).withOpacity(0.7),
                ),
              ),

              SizedBox(height: 24),

              // Titre principal avec meilleure hiérarchie
              Text(
                'Aucune propriété disponible',
                style: GoogleFonts.inter(
                  color: Colors.grey[800],
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
                textAlign: TextAlign.center,
              ),

              SizedBox(height: 12),

              // Message secondaire plus engageant
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Notre catalogue se met à jour régulièrement.',
                  style: GoogleFonts.inter(
                    color: Colors.grey[600],
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
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

          final firstImage = property.propertyImage?.isNotEmpty ?? false
              ? property.propertyImage!.first
              : null;
          final imageUrl = firstImage != null
              ? "${firstImage.path ?? firstImage.path}"
              : null;

          final priceText = isForRent
              ? '${property.price?.toStringAsFixed(0) ?? '0'}\$/mois'
              : '${property.price?.toStringAsFixed(0) ?? '0'}\$';

          return Container(
            width: 280,
            height: 380, // Hauteur fixe pour que l'image remplisse toute la carte
            margin: EdgeInsets.only(right: 20, bottom: 10, top: 10),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: () {
                    _logPropertyView(property, isForRent);
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
                      fit: StackFit.expand, // S'assurer que le Stack prend toute la place
                      children: [
                        Positioned.fill(
                          child: Hero(
                            tag: 'property-image-${property.propertyId}',
                            child: AnimatedSwitcher(
                              duration: Duration(milliseconds: 500),
                              child: imageUrl != null
                                  ? CachedNetworkImage(
                                imageUrl: imageUrl,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                                key: ValueKey(imageUrl),
                                placeholder: (context, url) => Container(
                                  width: double.infinity,
                                  height: double.infinity,
                                  color: Colors.grey[200],
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                                    ),
                                  ),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  width: double.infinity,
                                  height: double.infinity,
                                  color: Colors.grey[200],
                                  child: Center(
                                    child: Icon(
                                      Icons.photo_outlined,
                                      size: 48,
                                      color: Colors.grey[400],
                                    ),
                                  ),
                                ),
                              )
                                  : Container(
                                width: double.infinity,
                                height: double.infinity,
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
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
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
                                        property.address ?? 'Adresse non disponible',
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
                        Positioned(
                          top: 16,
                          left: 16,
                          right: 16,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
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
                              // Bouton favoris
                              if (property.propertyId != null)
                                FavoriteHeartIcon(
                                  propertyId: property.propertyId.toString(),
                                  size: 24,
                                  splashRadius: 20,
                                  activeColor: Colors.red,
                                  inactiveColor: Colors.white,
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
}