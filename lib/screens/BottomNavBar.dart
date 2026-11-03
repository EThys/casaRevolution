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
import '../utils/SubscriptionHelper.dart';
import '../utils/decertification_access_guard.dart';
import '../controllers/provider/FavoriteProvider.dart';
import 'package:showcaseview/showcaseview.dart';
import '../controllers/TutorialController.dart';

class BottomNavBar extends StatefulWidget {
  final bool shouldRefresh;
  const BottomNavBar({Key? key, this.shouldRefresh = false}) : super(key: key);

  @override
  State<BottomNavBar> createState() => _BottomNavBarState();
}

class _BottomNavBarState extends State<BottomNavBar> with WidgetsBindingObserver {
  int _currentIndex = 0;
  final GetStorage _stockage = GetStorage();
  final PageStorageBucket _bucket = PageStorageBucket();
  bool _isKeyboardVisible = false;
  bool _didTriggerTutorial = false;
  // Une fois le tuto terminé, on démonte complètement le ShowCaseWidget
  // pour supprimer ses overlays invisibles qui bloquent les interactions.
  bool _tutorialDone = false;
  /// Dernière mise en arrière-plan réelle (écran éteint / autre app) pour forcer un refresh au retour.
  DateTime? _lastPausedAt;

  late final List<Widget> _screens = [
    HomePage(shouldRefresh: widget.shouldRefresh),
    PropertySearchPage(),
    FavoritesPage(),
    ProfilePage()
  ];

  @override
  void initState() {
    super.initState();
    // Utiliser l'instance partagée (Provider) pour éviter un décalage de clés Showcase.
    final tutorialCtrl = context.read<TutorialController>();
    tutorialCtrl.initializeKeys();
    _tutorialDone = !tutorialCtrl.shouldShowHomeTutorial();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      if (mounted) {
        final authCtr = context.read<AuthentificationCtrl>();
        final idUser = authCtr.user.userId;

        if (idUser != null) {
          print("📡 [BottomNavBar] User ID: $idUser. Initialisation silencieuse des favoris...");
          // Chargement global et silencieux des favoris pour synchroniser les cœurs sur toutes les pages
          context.read<FavoriteProvider>().initialize(idUser.toString());
        } else {
          print("📡 [BottomNavBar] Utilisateur non connecté, pas de sync favoris.");
        }
      }
    });
    // Décertification côté serveur sans notification push : recharger le membre puis alerter.
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncMemberAndDecertAlert(forceRefresh: true));
  }

  Future<void> _syncMemberAndDecertAlert({required bool forceRefresh}) async {
    if (!mounted) return;
    final auth = context.read<AuthentificationCtrl>();
    if (!auth.isLoggedIn || auth.token.isEmpty) return;
    await auth.refreshMemberFromServer(force: forceRefresh);
    if (!mounted) return;
    await DecertificationAccessGuard.presentDecertificationAlertIfNeeded(auth);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused) {
      _lastPausedAt = DateTime.now();
      return;
    }
    if (state == AppLifecycleState.resumed && mounted) {
      final auth = context.read<AuthentificationCtrl>();
      if (auth.token.isEmpty) return;
      // Après verrouillage ou plusieurs minutes en arrière-plan : contourner le throttle 25s du refresh membre.
      final away = _lastPausedAt != null &&
          DateTime.now().difference(_lastPausedAt!) > const Duration(seconds: 3);
      _lastPausedAt = null;
      _syncMemberAndDecertAlert(forceRefresh: away);
    }
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

  // Construit le Scaffold principal
  Widget _buildScaffold(BuildContext context) {
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
    return Scaffold(
          body: PageStorage(
            child: _screens[_currentIndex],
            bucket: _bucket,
          ),
      // Android: FAB flottant classique
      floatingActionButton: (!isIOS && !_isKeyboardVisible && _shouldShowFab())
          ? Container(
        width: 60,
        height: 60,
        child: FloatingActionButton(
          heroTag: null, // Désactivé pour éviter les erreurs de doublons dans le subtree
          backgroundColor: Colors.transparent,
          elevation: 0,
          highlightElevation: 0,
          splashColor: Colors.transparent,
          child: _addButtonContent(),
          onPressed: _handleFabPress,
        ),
      )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceColor(context),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowColor(context),
              blurRadius: 10,
              spreadRadius: 2,
              offset: Offset(0, -2),
            )
          ],
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: SafeArea(
          child: Container(
            height: isIOS ? 65 : 70, // Ajustement hauteur selon OS
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildNavItem(icon: Icons.home_rounded, label: 'Accueil', index: 0),
                _buildNavItem(icon: Icons.search_rounded, label: 'Recherche', index: 1),

                // Centre: Espace pour FAB Android OU Bouton intégré pour iOS
                if (isIOS)
                  _buildAddButton()
                else
                  SizedBox(width: 40), // Espace réservé pour le FAB Android

                _buildNavItem(icon: Icons.favorite_rounded, label: 'Favoris', index: 2),
                _buildNavItem(icon: Icons.person_rounded, label: 'Profil', index: 3),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _scheduleHomeTutorial(BuildContext showcaseContext, TutorialController tutorialCtrl) {
    if (_didTriggerTutorial || _tutorialDone || !tutorialCtrl.shouldShowHomeTutorial()) return;
    _didTriggerTutorial = true;
    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted || _tutorialDone || _currentIndex != 0) return;
      final keys = <GlobalKey>[
        tutorialCtrl.drawerKey,
        tutorialCtrl.notificationKey,
        tutorialCtrl.seeAllLocationsKey,
        tutorialCtrl.seeAllSalesKey,
        tutorialCtrl.seeAllCleaningKey,
        tutorialCtrl.seeAllMovingKey,
        tutorialCtrl.seeAllOtherServicesKey,
        tutorialCtrl.addButtonKeyForCurrentPlatform(),
      ].where((key) => key.currentContext != null).toList();
      if (keys.isEmpty) return;
      ShowCaseWidget.of(showcaseContext).startShowCase(keys);
    });
  }

  void _finishHomeTutorial(TutorialController tutorialCtrl) {
    tutorialCtrl.setTutorialInProgress(false);
    tutorialCtrl.completeHomeTutorial();
    // Nouvelle clé : détruit le ShowCaseWidget et ses overlays, qui sinon
    // restent au-dessus de l'accueil et empêchent le défilement.
    if (mounted) setState(() => _tutorialDone = true);
  }

  @override
  Widget build(BuildContext context) {
    // Pas de ShowCaseWidget : son overlay plein écran reste au-dessus des routes
    // (accueil, réservations) et avale le défilement.
    return _buildScaffold(context);
  }

  // Contenu graphique du bouton Publier (sans Showcase)
  Widget _addButtonContent({double size = 56}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFF1976D2), Color(0xFF2196F3)],
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
      child: Icon(Icons.add, color: Colors.white, size: 26),
    );
  }

  Widget _buildAddButton() {
    final button = GestureDetector(
      onTap: _handleFabPress,
      child: Container(
        width: 50,
        height: 50,
        margin: EdgeInsets.symmetric(horizontal: 8),
        child: _addButtonContent(size: 50),
      ),
    );
    return button;
  }

  bool _shouldShowFab() {
    // On affiche toujours le bouton, la logique de restriction (Client vs Owner) 
    // se fera au clic dans _handleFabPress pour donner un feedback à l'utilisateur
    return true;
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
    SubscriptionHelper.checkSubscriptionAndProceed(
      context: context,
      onProceed: () => Navigator.pushNamed(context, route),
    );
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
            // UX: pas d’ombre/ripple visible au tap sur la nav (style "pro").
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            hoverColor: Colors.transparent,
            overlayColor: const WidgetStatePropertyAll<Color>(Colors.transparent),
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