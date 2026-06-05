import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:showcaseview/showcaseview.dart';

class TutorialController extends ChangeNotifier {
  bool _isTutorialInProgress = false;
  bool get isTutorialInProgress => _isTutorialInProgress;

  void setTutorialInProgress(bool value) {
    if (_isTutorialInProgress != value) {
      _isTutorialInProgress = value;
      notifyListeners();
    }
  }

  /// Ferme l’overlay Showcase pour éviter les GlobalKey dupliquées
  /// quand une autre route est poussée par-dessus [BottomNavBar].
  void dismissActiveShowcase(BuildContext context) {
    setTutorialInProgress(false);
    try {
      ShowCaseWidget.of(context).dismiss();
    } catch (_) {
      // Pas sous un ShowCaseWidget (route externe, etc.)
    }
  }

  final GetStorage _storage = GetStorage();
  
  // Storage keys
  static const String keyHomeTutorial = 'show_home_tutorial';
  static const String keyAddTutorial = 'show_add_tutorial';
  static const String keyProfileTutorial = 'show_profile_tutorial';
  static const String keyBottomNavTutorial = 'show_bottom_nav_tutorial';
  static const String keySearchPageTutorial = 'show_search_page_tutorial';
  static const String keyFavoritesPageTutorial = 'show_favorites_page_tutorial';

  // GlobalKeys for Showcase
  GlobalKey searchKey = GlobalKey();
  GlobalKey quickServiceKey = GlobalKey();
  GlobalKey fabAddButtonKey = GlobalKey();
  GlobalKey navAddButtonKey = GlobalKey();
  GlobalKey favoritesKey = GlobalKey();
  GlobalKey profileKey = GlobalKey();
  
  // New GlobalKeys
  GlobalKey drawerKey = GlobalKey();
  GlobalKey notificationKey = GlobalKey();
  GlobalKey homeMenuKey = GlobalKey();
  GlobalKey searchMenuKey = GlobalKey();
  GlobalKey favoritesMenuKey = GlobalKey();
  GlobalKey profileMenuKey = GlobalKey();
  
  // See All Keys for HomePage
  GlobalKey seeAllCategoryKey = GlobalKey();
  GlobalKey seeAllLocationsKey = GlobalKey();
  GlobalKey seeAllSalesKey = GlobalKey();
  GlobalKey seeAllCleaningKey = GlobalKey();
  GlobalKey seeAllMovingKey = GlobalKey();
  GlobalKey seeAllOtherServicesKey = GlobalKey();

  // Page Specific Keys
  GlobalKey searchFieldKey = GlobalKey();
  GlobalKey filterButtonKey = GlobalKey();
  GlobalKey viewToggleKey = GlobalKey();
  GlobalKey refreshFavoritesKey = GlobalKey();

  // Re-initialiser les clés pour éviter les conflits lors de la navigation
  // entre plusieurs instances d'une même page (ex: BottomNavBar poussée plusieurs fois)
  /// Clé Showcase du bouton publier réellement présente dans l’arbre (selon la plateforme).
  GlobalKey addButtonKeyForCurrentPlatform() {
    return defaultTargetPlatform == TargetPlatform.iOS
        ? navAddButtonKey
        : fabAddButtonKey;
  }

  void initializeKeys() {
    searchKey = GlobalKey();
    quickServiceKey = GlobalKey();
    fabAddButtonKey = GlobalKey();
    navAddButtonKey = GlobalKey();
    favoritesKey = GlobalKey();
    profileKey = GlobalKey();
    drawerKey = GlobalKey();
    notificationKey = GlobalKey();
    homeMenuKey = GlobalKey();
    searchMenuKey = GlobalKey();
    favoritesMenuKey = GlobalKey();
    profileMenuKey = GlobalKey();
    seeAllCategoryKey = GlobalKey();
    seeAllLocationsKey = GlobalKey();
    seeAllSalesKey = GlobalKey();
    seeAllCleaningKey = GlobalKey();
    seeAllMovingKey = GlobalKey();
    seeAllOtherServicesKey = GlobalKey();
    searchFieldKey = GlobalKey();
    filterButtonKey = GlobalKey();
    viewToggleKey = GlobalKey();
    refreshFavoritesKey = GlobalKey();
    print("🔑 [TutorialController] Clés ré-initialisées pour une nouvelle instance");
  }

  TutorialController();

  bool shouldShowHomeTutorial() {
    return _storage.read(keyHomeTutorial) ?? true;
  }

  void completeHomeTutorial() {
    _storage.write(keyHomeTutorial, false);
  }

  bool shouldShowAddTutorial() {
    return _storage.read(keyAddTutorial) ?? true;
  }

  void completeAddTutorial() {
    _storage.write(keyAddTutorial, false);
  }

  void startHomeTutorial(BuildContext context, {List<GlobalKey>? customKeys}) {
    if (shouldShowHomeTutorial()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // IMPORTANT: Ne passer que les clés qui ont réellement un widget Showcase
        // dans l'arbre courant. Des clés sans widget bloquent le ShowCaseWidget.
        final keysToShow = customKeys ?? [addButtonKeyForCurrentPlatform()];
        ShowCaseWidget.of(context).startShowCase(keysToShow);
      });
    }
  }

  bool shouldShowBottomNavTutorial() {
    return _storage.read(keyBottomNavTutorial) ?? true;
  }

  void completeBottomNavTutorial() {
    _storage.write(keyBottomNavTutorial, false);
  }

  void startBottomNavTutorial(BuildContext context) {
    if (shouldShowBottomNavTutorial()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ShowCaseWidget.of(context).startShowCase([
          homeMenuKey,
          searchMenuKey,
          favoritesMenuKey,
          profileMenuKey
        ]);
        completeBottomNavTutorial();
      });
    }
  }

  bool shouldShowSearchPageTutorial() {
    return _storage.read(keySearchPageTutorial) ?? true;
  }

  void completeSearchPageTutorial() {
    _storage.write(keySearchPageTutorial, false);
  }

  void startSearchTutorial(BuildContext context) {
    if (shouldShowSearchPageTutorial()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ShowCaseWidget.of(context).startShowCase([
          searchFieldKey,
          filterButtonKey
        ]);
        completeSearchPageTutorial();
      });
    }
  }

  bool shouldShowFavoritesPageTutorial() {
    return _storage.read(keyFavoritesPageTutorial) ?? true;
  }

  void completeFavoritesPageTutorial() {
    _storage.write(keyFavoritesPageTutorial, false);
  }

  void startFavoritesTutorial(BuildContext context) {
    if (shouldShowFavoritesPageTutorial()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ShowCaseWidget.of(context).startShowCase([
          viewToggleKey,
          refreshFavoritesKey
        ]);
        completeFavoritesPageTutorial();
      });
    }
  }

  void startAddTutorial(BuildContext context) {
    if (shouldShowAddTutorial()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ShowCaseWidget.of(context).startShowCase([addButtonKeyForCurrentPlatform()]);
        completeAddTutorial();
      });
    }
  }

  bool shouldShowProfileTutorial() {
    return _storage.read(keyProfileTutorial) ?? true;
  }

  void completeProfileTutorial() {
    _storage.write(keyProfileTutorial, false);
  }

  void startProfileTutorial(BuildContext context) {
    if (shouldShowProfileTutorial()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ShowCaseWidget.of(context).startShowCase([profileKey]);
        completeProfileTutorial();
      });
    }
  }
  
  void resetTutorials() {
    _storage.write(keyHomeTutorial, true);
    _storage.write(keyAddTutorial, true);
    _storage.write(keyProfileTutorial, true);
  }
}
