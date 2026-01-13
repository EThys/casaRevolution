import 'package:casa/screens/FavoritesPage.dart';
import 'package:casa/screens/HomePage.dart';
import 'package:casa/screens/ProfilePage.dart';
import 'package:casa/screens/PropertySearchPage.dart';
import 'package:casa/models/ServiceModel.dart';
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:provider/provider.dart';
import '../controllers/AuthentificationCtrl.dart';
import '../utils/FancyNotification.dart';
import '../utils/StockageKeys.dart';
import '../utils/Routes.dart';
import '../utils/AppColors.dart';
import 'package:casa/screens/auth/IdentityVerificationPage.dart';

class BottomNavBar extends StatefulWidget {
  const BottomNavBar({Key? key}) : super(key: key);

  @override
  State<BottomNavBar> createState() => _BottomNavBarState();
}

class _BottomNavBarState extends State<BottomNavBar> with WidgetsBindingObserver {
  int _currentIndex = 0;
  final GetStorage _stockage = GetStorage();
  final PageStorageBucket _bucket = PageStorageBucket();
  bool _isKeyboardVisible = false;

  late final List<Widget> _screens = [
    HomePage(),
    PropertySearchPage(),
    FavoritesPage(),
    ProfilePage()
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      final authCtr = context.read<AuthentificationCtrl>();
      final idUser = 1; //authCtr.user;
      final storage = GetStorage();
      print("User ID: $idUser");
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    // Vérifier si le clavier est visible
    final bottomInset = WidgetsBinding.instance.window.viewInsets.bottom;
    final newValue = bottomInset > 0;

    if (newValue != _isKeyboardVisible) {
      setState(() {
        _isKeyboardVisible = newValue;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageStorage(
        child: _screens[_currentIndex],
        bucket: _bucket,
      ),
      floatingActionButton: Visibility(
        visible: !_isKeyboardVisible && _shouldShowFab(),
        child: Container(
          width: 60,
          height: 60,
          child: FloatingActionButton(
            heroTag: "bottom_nav_bar_fab",
            backgroundColor: Colors.transparent,
            elevation: 0,
            highlightElevation: 0,
            splashColor: Colors.transparent,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF1976D2),
                    Color(0xFF2196F3),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFF1976D2).withOpacity(0.4),
                    spreadRadius: 1,
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(
                Icons.add,
                color: Colors.white,
                size: 26,
              ),
            ),
            onPressed: _handleFabPress,
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowColor(context),
              blurRadius: 10,
              spreadRadius: 2,
              offset: Offset(0, -2),
            )
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          child: BottomAppBar(
            shape: CircularNotchedRectangle(),
            notchMargin: 6, // Réduit de 8 à 6 pour un creux plus petit
            color: AppColors.surfaceColor(context),
            child: Container(
              height: 70, // Réduit de 85 à 70 (suffisant avec les ajustements)
              padding: EdgeInsets.zero, // Supprimé tout padding horizontal
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildNavItem(
                    icon: Icons.home_rounded,
                    label: 'Accueil',
                    index: 0,
                  ),
                  _buildNavItem(
                    icon: Icons.search_rounded,
                    label: 'Recherche',
                    index: 1,
                  ),
                  SizedBox(width: 36), // Espace réduit pour le FAB (40 → 36)
                  _buildNavItem(
                    icon: Icons.favorite_rounded,
                    label: 'Favoris',
                    index: 2,
                  ),
                  _buildNavItem(
                    icon: Icons.person_rounded,
                    label: 'Profil',
                    index: 3,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool _shouldShowFab() {
    var token = _stockage.read(StockageKeys.tokenKey);
    if (token == null) return true; // Montrer pour permettre la connexion

    // Lire les comptes depuis 'user_accounts' (Liste)
    List<dynamic>? userAccounts = _stockage.read('user_accounts');
    
    if (userAccounts == null || userAccounts.isEmpty) {
      return false;
    }

    // Vérifier si au moins un compte permet de publier (ID 2 ou 3)
    bool canPublish = userAccounts.any((acc) {
      var typeAcc = acc['typeAccount'];
      var id = typeAcc is Map 
          ? (typeAcc['typeAccountId'] ?? typeAcc['TypeAccountId'])
          : (acc['typeAccountId'] ?? acc['TypeAccountId']);
      return id == 2 || id == 3;
    });

    return canPublish;
  }

  void _handleFabPress() {
    var token = _stockage.read(StockageKeys.tokenKey);
    if (token == null) {
      SnackbarForCasa.info(
        context,
        "Vous devez avoir un compte et être connecté pour publier une annonce",
        onTap: () => Navigator.pushNamed(context, Routes.loginRoute),
      );
      // Redirection directe vers la page de connexion
      Navigator.pushNamed(context, Routes.loginRoute);
      return;
    }

    List<dynamic>? userAccounts = _stockage.read('user_accounts');
    if (userAccounts == null || userAccounts.isEmpty) {
      SnackbarForCasa.info(context, "Aucun compte associé trouvé.");
      return;
    }

    Set<int> typeIds = userAccounts.map<int>((acc) {
      var typeAcc = acc['typeAccount'];
      return typeAcc is Map 
          ? (typeAcc['typeAccountId'] ?? typeAcc['TypeAccountId'] ?? 0)
          : (acc['typeAccountId'] ?? acc['TypeAccountId'] ?? 0);
    }).toSet();

    bool isOwner = typeIds.contains(2);
    bool isProvider = typeIds.contains(3);
    bool isClient = typeIds.contains(1);

    if (isOwner && isProvider) {
      _showCreationChoice();
    } else if (isClient && isProvider) {
      _checkCertificationAndNavigate(Routes.createServicePostRoute);
    } else if (isOwner) {
      _checkCertificationAndNavigate(Routes.createPropertyRoute);
    } else if (isProvider) {
      _checkCertificationAndNavigate(Routes.createServicePostRoute);
    } else if (isClient) {
      SnackbarForCasa.info(context, "Les comptes locataires ne peuvent pas publier d'annonces.");
    } else {
      SnackbarForCasa.info(context, "Type de compte non reconnu.");
    }
  }

  void _checkCertificationAndNavigate(String route) {
    final authCtrl = context.read<AuthentificationCtrl>();
    if (authCtrl.user.isCertified != true) {
      Navigator.push(
        context, 
        MaterialPageRoute(builder: (context) => IdentityVerificationPage())
      ).then((result) {
        if (result == true) {
           Navigator.pushNamed(context, route);
        }
      });
      return;
    }
    Navigator.pushNamed(context, route);
  }

  void _showCreationChoice() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surfaceColor(context),
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: 24),
            Text(
              "Que souhaitez-vous publier ?",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textColor(context),
              ),
            ),
            SizedBox(height: 24),
            _buildChoiceItem(
              icon: Icons.home_work_rounded,
              title: "Une propriété",
              subtitle: "Louer ou vendre un bien immobilier",
              color: AppColors.primaryBlue,
              onTap: () {
                Navigator.pop(context);
                _checkCertificationAndNavigate(Routes.createPropertyRoute);
              },
            ),
            SizedBox(height: 16),
            _buildChoiceItem(
              icon: Icons.handyman_rounded,
              title: "Un service",
              subtitle: "Proposer vos compétences professionnelles",
              color: Color(0xFF2E7D32),
              onTap: () {
                Navigator.pop(context);
                _checkCertificationAndNavigate(Routes.createServicePostRoute);
              },
            ),
            SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildChoiceItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.withOpacity(0.2)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textColor(context),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
  }) {
    final isActive = _currentIndex == index;
    final isDark = AppColors.isDarkMode(context);
    return Expanded(
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 0), // Supprimé la marge
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => setState(() => _currentIndex = index),
            splashColor: AppColors.primaryBlue.withOpacity(0.1),
            highlightColor: Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 6), // Supprimé padding horizontal
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Icône plus compacte
                  Container(
                    padding: EdgeInsets.all(4), // Réduit de 6 à 4
                    decoration: BoxDecoration(
                      color: isActive 
                          ? (isDark ? AppColors.primaryBlue.withOpacity(0.2) : AppColors.lightBlue)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      icon,
                      size: 20, // Réduit de 22 à 20
                      color: isActive 
                          ? AppColors.primaryBlue 
                          : (isDark ? Colors.white54 : const Color(0xFF95A5A6)),
                    ),
                  ),
                  SizedBox(height: 2), // Réduit de 3 à 2
                  // Label ultra compact
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 2), // Petit padding pour éviter le bord
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 9, // Réduit de 9.5 à 9
                        fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                        color: isActive 
                            ? AppColors.primaryBlue 
                            : (isDark ? Colors.white54 : const Color(0xFF95A5A6)),
                        height: 1.0,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}