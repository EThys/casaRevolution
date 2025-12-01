import 'package:casa/screens/FavoritesPage.dart';
import 'package:casa/screens/HomePage.dart';
import 'package:casa/screens/ProfilePage.dart';
import 'package:casa/screens/PropertySearchPage.dart';
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:provider/provider.dart';
import '../controllers/AuthentificationCtrl.dart';
import '../utils/FancyNotification.dart';
import '../utils/StockageKeys.dart';
import '../utils/Routes.dart';

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
        visible: !_isKeyboardVisible,
        child: Container(
          width: 60, // Réduit de 70 à 60
          height: 60, // Réduit de 70 à 60
          child: FloatingActionButton(
            backgroundColor: Colors.transparent,
            elevation: 0,
            highlightElevation: 0,
            splashColor: Colors.transparent,
            child: Container(
              width: 56, // Réduit de 60 à 56
              height: 56, // Réduit de 60 à 56
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
                size: 26, // Réduit de 28 à 26
              ),
            ),
            onPressed: () {
              var token = _stockage.read(StockageKeys.tokenKey);
              var typeAccount = _stockage.read(StockageKeys.userKey)?['TypeAccountId'];

              if (token != null) {
                if (typeAccount != 2) {
                  Navigator.pushNamed(context, Routes.createPropertyRoute);
                } else {
                  SnackbarForCasa.info(
                    context,
                    "La publication d'annonces est réservée aux bailleurs et commissionnaires",
                  );
                }
              } else {
                SnackbarForCasa.info(
                  context,
                  "Vous devez avoir un compte et être connecté pour publier une annonce",
                  onTap: () {
                    Navigator.pushNamed(context, Routes.loginRoute);
                  },
                );
              }
            },
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
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
            color: Colors.white,
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

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
  }) {
    final isActive = _currentIndex == index;
    return Expanded(
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 0), // Supprimé la marge
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => setState(() => _currentIndex = index),
            splashColor: Color(0xFF2196F3).withOpacity(0.1),
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
                      color: isActive ? Color(0xFFE3F2FD) : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      icon,
                      size: 20, // Réduit de 22 à 20
                      color: isActive ? Color(0xFF2196F3) : Color(0xFF95A5A6),
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
                        color: isActive ? Color(0xFF2196F3) : Color(0xFF95A5A6),
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