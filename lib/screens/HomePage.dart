import 'dart:io';
import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:casa/controllers/PropertyCtrl.dart';
import 'package:casa/controllers/ServiceController.dart';
import 'package:casa/controllers/AuthentificationCtrl.dart';
import 'package:casa/screens/AllPropertiesPage.dart';
import 'package:casa/screens/PropertySearchPage.dart';
import 'package:casa/screens/PromoBanner.dart';
import 'package:casa/screens/auth/LoginScreen.dart';
import 'package:casa/utils/Constantes.dart';
import 'package:casa/utils/FancyNotification.dart';
import 'package:share_plus/share_plus.dart';
import 'package:casa/utils/FavoriteEartIcon.dart';
import 'package:casa/utils/StockageKeys.dart';
import 'package:casa/utils/casanayo_share_copy.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get_storage/get_storage.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:shimmer/shimmer.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:casa/controllers/TutorialController.dart';

import '../models/PropertyModel.dart';
import '../models/ServiceModel.dart';
import '../models/PrestationModel.dart';
import '../controllers/AgenceController.dart';
import '../services/onesignal_service.dart';
import '../utils/requetes.dart' show HttpResponse, deleteData, getData;
import '../utils/Endpoints.dart';
import '../utils/Routes.dart';
import '../utils/property_detail_navigation.dart';
import '../utils/database/FavoriteDatabaseHelper.dart';
import '../utils/database/ReservationDatabaseHelper.dart';
import '../utils/database/ServiceCategoryDatabaseHelper.dart';
import '../utils/database/PrestationDatabaseHelper.dart';
import 'CategoryPropertiesPage.dart';
import 'AllServiceCategoriesPage.dart';
import 'NotificationPage.dart';
import 'TerrainPropertiesPage.dart';
import '../utils/DraftHelper.dart';
import '../utils/static_services_data.dart';
import 'ServiceDetailPage.dart';
import 'ServiceCategoryPage.dart';
import 'QuickServiceRequestModal.dart';
import 'QuickServiceRequestPage.dart';
import 'MyAgencyPage.dart';
import 'package:casa/services/ServerHealthService.dart';
import 'package:casa/controllers/NotificationController.dart';
import 'package:casa/controllers/TypeAccountController.dart';
import 'package:casa/widgets/property_sold_badge.dart';
import '../utils/PulseBadge.dart';
import '../widgets/OfflineBanner.dart';
import '../widgets/app_update_gate.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'ProfilePage.dart'; // Added for background update

class HomePage extends StatefulWidget {
  final bool shouldRefresh;

  HomePage({this.shouldRefresh = false});

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

  // Données pour les prestations
  List<PrestationModel> majordhommeServices = [];
  List<PrestationModel> demenagementServices = [];
  Map<ServiceType, List<PrestationModel>> otherServicesByType = {};
  bool isLoadingPrestations =
      true; // Commencer à true pour voir le shimmer tout de suite

  // Mapping nom compte -> ID
  Map<String, int> accountNameToIdMap = {};

  // Auto-scroll for categories and sections
  final ScrollController _categoryScrollController = ScrollController();
  final ScrollController _rentalsScrollController = ScrollController();
  final ScrollController _salesScrollController = ScrollController();
  final ScrollController _hotelsScrollController = ScrollController();
  final ScrollController _majordhommeScrollController = ScrollController();
  final ScrollController _demenagementScrollController = ScrollController();

  // Évite de relancer en boucle l’enrichissement chambres sur la home.
  final Set<int> _requestedHotelRoomEnrich = <int>{};

  bool _homeUpdatePromptScheduled = false;

  /// Version package (pubspec) pour le pied du drawer.
  bool _packageInfoLoaded = false;
  String _appVersion = '';

  Timer? _categoryTimer;
  Timer? _rentalsTimer;
  Timer? _salesTimer;
  Timer? _hotelsTimer;
  Timer? _majordhommeTimer;
  Timer? _demenagementTimer;

  @override
  void initState() {
    super.initState();
    _loadInitialData();

    // Demander la permission de notifications **après** l'ouverture (pas au cold start).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(const Duration(milliseconds: 900), () {
        requestOneSignalNotificationPermissionAfterLaunch();
      });
    });

    // Mise à jour : afficher sur l’accueil (pas au splash) pour éviter que la navigation ferme le sheet.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_homeUpdatePromptScheduled) return;
      _homeUpdatePromptScheduled = true;
      await Future<void>.delayed(const Duration(milliseconds: 650));
      if (!mounted) return;
      await AppUpdatePrompt.maybeShowOnHome(context);
    });

    // Démarrer la surveillance du serveur après le build initial
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notifCtrl =
          Provider.of<NotificationController>(context, listen: false);
      final authCtrl =
          Provider.of<AuthentificationCtrl>(context, listen: false);

      // Charger les notifications spécifiques à l'utilisateur
      if (authCtrl.isLoggedIn && authCtrl.user.userId != null) {
        notifCtrl.loadForUser(authCtrl.user.userId.toString());
      }

      ServerHealthService().startMonitoring(context, notifCtrl);
    });

    if (widget.shouldRefresh) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _refreshController.requestRefresh();
      });
    }

    _startAutoScrolls();
    _loadPackageInfo();
  }

  @override
  void dispose() {
    _categoryTimer?.cancel();
    _rentalsTimer?.cancel();
    _salesTimer?.cancel();
    _hotelsTimer?.cancel();
    _majordhommeTimer?.cancel();
    _demenagementTimer?.cancel();

    _categoryScrollController.dispose();
    _rentalsScrollController.dispose();
    _salesScrollController.dispose();
    _hotelsScrollController.dispose();
    _majordhommeScrollController.dispose();
    _demenagementScrollController.dispose();

    ServerHealthService().stopMonitoring();
    super.dispose();
  }

  Future<void> _loadPackageInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() {
        _appVersion = info.version;
        _packageInfoLoaded = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _appVersion = '—';
        _packageInfoLoaded = true;
      });
    }
  }

  void _loadInitialData() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final propertyCtrl =
          Provider.of<PropertyController>(context, listen: false);
      final serviceCtrl =
          Provider.of<ServiceController>(context, listen: false);

      propertyCtrl.getAllProperty().then((_) {
        _logHomePageLoaded(propertyCtrl.properties.length);
        // Charger les catégories spéciales APRÈS les propriétés urgentes
        propertyCtrl.syncAllSpecialCategories();
      });

      // Charger les types de propriété dynamiquement
      propertyCtrl.fetchAndSyncPropertyTypes();

      // Charger tous les services
      // Charger tous les services
      serviceCtrl.fetchServices();
      // Charger le mapping des comptes services
      serviceCtrl.fetchServiceAccounts();

      // Charger les prestations depuis l'API
      _loadPrestationsFromAPI();

      // Vérifier en arrière-plan si le gérant a une agence
      final authCtrl =
          Provider.of<AuthentificationCtrl>(context, listen: false);
      final userAccounts = storage.read('user_accounts');

      // Charger toutes les agences pour la section Vacances
      final agenceCtrl = Provider.of<AgenceController>(context, listen: false);
      agenceCtrl.fetchAgences();

      if (authCtrl.isLoggedIn && userAccounts != null && userAccounts is List) {
        bool isManager = userAccounts.any((acc) {
          var typeAcc = acc['typeAccount'];
          var id = typeAcc is Map
              ? (typeAcc['typeAccountId'] ?? typeAcc['TypeAccountId'])
              : (acc['typeAccountId'] ?? acc['TypeAccountId']);
          return id == 2; // 2 = Gérant/Owner
        });

        if (isManager && authCtrl.user.userId != null) {
          authCtrl.checkUserAgency(authCtrl.user.userId!);
        }
      }

      // [OPTIMIZATION] Charger les types de comptes en arrière-plan et les cacher en SQL
      // Cela permet à la page Register de charger instantanément sans réseau
      Provider.of<TypeAccountController>(context, listen: false)
          .fetchAndCacheAccountTypes();

      // [OPTIMIZATION] Mettre à jour le compteur de publications en arrière-plan
      // Utile pour avoir l'info prête quand on ouvre la page Profil
      if (authCtrl.isLoggedIn) {
        Future.delayed(Duration(seconds: 3), () {
          ProfilePage.updatePublicationCount(context);
        });
      }
    });
  }

  // Charger les comptes depuis l'API et mapper les noms aux IDs
  // Aussi charger et stocker les catégories de services dans SQLite
  // Charger le mapping des comptes de manière optimisée
  Future<void> _loadAccountMapping() async {
    try {
      // 1. CHARGEMENT DEPUIS LE CACHE (Instantané)
      final categoryDB = ServiceCategoryDatabaseHelper.instance;
      final cachedCategories = await categoryDB.getAllCategories();

      if (cachedCategories.isNotEmpty) {
        print("📦 [HomePage] Mapping chargé depuis le cache local");
        _updateMappingFromList(cachedCategories, isCache: true);
      }

      // 2. MISE À JOUR API (En arrière-plan si on a déjà des données)
      if (accountNameToIdMap.isNotEmpty) {
        _fetchAccountMappingFromAPI(); // On ne l'attend pas ici pour ne pas bloquer
      } else {
        await _fetchAccountMappingFromAPI(); // On l'attend si on n'a rien
      }
    } catch (e) {
      print("❌ [HomePage] Erreur chargement mapping: $e");
    }
  }

  // Effectuer la requête API pour le mapping
  Future<void> _fetchAccountMappingFromAPI() async {
    try {
      final url = Endpoints.accounts;
      final token = storage.read<String>(StockageKeys.tokenKey);
      var response = await getData(url, token: token);

      if (response != null && response is Map<String, dynamic>) {
        final accounts = response['accounts'] as List<dynamic>?;
        if (accounts != null && accounts.isNotEmpty) {
          _updateMappingFromList(accounts, isCache: false);
          print("[HomePage] Mapping mis à jour via API");
        }
      }
    } catch (e) {
      print("[HomePage] Échec mise à jour API mapping: $e");
    }
  }

  // Mettre à jour le dictionnaire interne depuis une liste (Cache ou API)
  void _updateMappingFromList(List<dynamic> list, {required bool isCache}) {
    final List<Map<String, dynamic>> categoriesToCache = [];

    // Mapping des icônes et couleurs
    final iconMap = {
      'plombier': 'plumbing_rounded',
      'electricien': 'electrical_services_rounded',
      'salubrité': 'cleaning_services_rounded',
      'peintre': 'format_paint_rounded',
      'carrelleur': 'square_foot_rounded',
      'menusier': 'carpenter_rounded',
      'frigoriste': 'ac_unit_rounded',
      'ajusteur': 'build_rounded',
      'architect': 'architecture_rounded',
      'chauffeur': 'drive_eta_rounded',
      'maçon': 'construction_rounded',
      'majordome': 'cleaning_services_rounded',
      'demenagement': 'local_shipping_rounded',
    };

    final colorMap = {
      'plombier': 0xFF2196F3,
      'electricien': 0xFFFFEB3B,
      'salubrité': 0xFF4CAF50,
      'peintre': 0xFFFF5722,
      'carrelleur': 0xFF9C27B0,
      'menusier': 0xFF8D6E63,
      'frigoriste': 0xFF00BCD4,
      'ajusteur': 0xFF4CAF50,
      'architect': 0xFFFF9800,
      'chauffeur': 0xFFF44336,
      'maçon': 0xFF795548,
      'majordome': 0xFF607D8B,
      'demenagement': 0xFF3F51B5,
    };

    for (var acc in list) {
      final accountName = (isCache ? acc['accountName'] : acc['name'])
          ?.toString()
          .toLowerCase();
      final accountId = isCache ? acc['accountId'] : acc['id'];

      if (accountName != null && accountId != null) {
        accountNameToIdMap[accountName] = accountId;

        if (!isCache) {
          final typeAccount = acc['typeAccount'];
          final typeAccountId = typeAccount?['typeAccountId'];

          if (typeAccountId == 3) {
            final displayName =
                accountName[0].toUpperCase() + accountName.substring(1);
            final serviceType = _mapAccountNameToServiceType(accountName);
            if (serviceType != null) {
              categoriesToCache.add({
                'name': displayName,
                'value': serviceType.value,
                'accountName': accountName,
                'accountId': accountId,
                'iconName': iconMap[accountName] ?? 'build_rounded',
                'colorValue': colorMap[accountName] ?? primaryColor.value,
              });
            }
          }
        }
      }
    }

    if (!isCache && categoriesToCache.isNotEmpty) {
      ServiceCategoryDatabaseHelper.instance
          .insertOrUpdateCategories(categoriesToCache);
    }
  }

  // Charger les prestations avec stratégie Cache-First puis API Parallèle
  Future<void> _loadPrestationsFromAPI() async {
    if (mounted) {
      setState(() => isLoadingPrestations = true);
    }

    try {
      // 1. Charger d'abord le mapping depuis le CACHE (très rapide)
      await _loadAccountMapping();

      final serviceCtrl =
          Provider.of<ServiceController>(context, listen: false);
      final dbHelper = PrestationDatabaseHelper.instance;

      // 2. CHARGEMENT INITIAL DEPUIS LE CACHE SQL
      final cachedPrestations = await dbHelper.getAllPrestations();
      if (cachedPrestations.isNotEmpty) {
        print(
            "📦 [HomePage] Chargement express de ${cachedPrestations.length} prestations du cache");
        _processPrestations(cachedPrestations);
        if (mounted) setState(() {});
      }

      // 3. RÉCUPÉRATION API (Optimisé)
      // Note: On utilise uniquement /api/prestations car /api/prestations/service/{id} n'existe pas
      final allList = await serviceCtrl.fetchAllPrestations();

      if (mounted) {
        setState(() {
          // Traiter TOUTES les prestations (filtrage local par serviceId)
          _processPrestations(allList);

          isLoadingPrestations = false;
        });

        // Compter les résultats par catégorie pour les logs
        final majordomeId = accountNameToIdMap['majordome'] ??
            accountNameToIdMap['majordhomme'];
        final demenagementId = accountNameToIdMap['demenagement'];
        final majCount =
            allList.where((p) => p.serviceId == majordomeId).length;
        final demCount =
            allList.where((p) => p.serviceId == demenagementId).length;

        print(
            "[HomePage] Données API intégrées (Total: ${allList.length}, Ménage: $majCount, Déménag: $demCount)");
      }
    } catch (e) {
      print(" [HomePage] Erreur lors du chargement des prestations: $e");
      if (mounted) setState(() => isLoadingPrestations = false);
    }
  }

  // Méthode utilitaire pour traiter et grouper les prestations
  void _processPrestations(List<PrestationModel> allPrestations) {
    // 1. Filtrer les majordomes et déménagements (gérés séparément)
    final majordomeId =
        accountNameToIdMap['majordome'] ?? accountNameToIdMap['majordhomme'];
    final demenagementId = accountNameToIdMap['demenagement'];

    // TOUJOURS mettre à jour depuis les données API (pas seulement si vide)
    // Ceci garantit que les données obsolètes en mémoire sont écrasées
    if (majordomeId != null) {
      final apiMajordhomme = allPrestations
          .where((p) => p.serviceId == majordomeId)
          .toList()
        ..sort((a, b) => (b.id ?? 0).compareTo(a.id ?? 0));
      // Ne mettre à jour que si on a des données de l'API OU si on veut vider
      if (apiMajordhomme.isNotEmpty || majordhommeServices.isNotEmpty) {
        majordhommeServices = apiMajordhomme;
        print(
            "🔄 [HomePage] Ménage mis à jour: ${apiMajordhomme.length} prestations");
      }
    }
    if (demenagementId != null) {
      final apiDemenagement = allPrestations
          .where((p) => p.serviceId == demenagementId)
          .toList()
        ..sort((a, b) => (b.id ?? 0).compareTo(a.id ?? 0));
      if (apiDemenagement.isNotEmpty || demenagementServices.isNotEmpty) {
        demenagementServices = apiDemenagement;
        print(
            "🔄 [HomePage] Déménagement mis à jour: ${apiDemenagement.length} prestations");
      }
    }

    // 2. Grouper les autres
    otherServicesByType.clear();
    for (var prestation in allPrestations) {
      if (prestation.serviceId != null &&
          prestation.serviceId != majordomeId &&
          prestation.serviceId != demenagementId) {
        // Trouver le nom du compte
        String? accountName;
        accountNameToIdMap.forEach((name, id) {
          if (id == prestation.serviceId) accountName = name;
        });

        if (accountName != null) {
          final serviceType = _mapAccountNameToServiceType(accountName!);
          if (serviceType != null) {
            otherServicesByType
                .putIfAbsent(serviceType, () => [])
                .add(prestation);
          }
        }
      }
    }

    // 3. Trier
    otherServicesByType.forEach((type, services) {
      services.sort((a, b) => (b.id ?? 0).compareTo(a.id ?? 0));
    });
  }

  // Obtenir l'icône pour un type de service
  IconData _getServiceTypeIcon(ServiceType serviceType) {
    switch (serviceType) {
      case ServiceType.plomberie:
        return Icons.plumbing_rounded;
      case ServiceType.electricite:
        return Icons.electrical_services_rounded;
      case ServiceType.peinture:
        return Icons.format_paint_rounded;
      case ServiceType.coiffure:
        return Icons.content_cut_rounded;
      case ServiceType.climatisation:
        return Icons.ac_unit_rounded;
      case ServiceType.reparation:
        return Icons.build_rounded;
      case ServiceType.nettoyage:
        return Icons.cleaning_services_rounded;
      case ServiceType.transport:
        return Icons.drive_eta_rounded;
      case ServiceType.renovation:
        return Icons.construction_rounded;
      case ServiceType.installation:
        return Icons.install_mobile_rounded;
      case ServiceType.serrurerie:
        return Icons.vpn_key_rounded;
      case ServiceType.vitrerie:
        return Icons.window_rounded;
      case ServiceType.majordhomme:
        return Icons.cleaning_services_rounded;
      case ServiceType.demenagement:
        return Icons.local_shipping_rounded;
      default:
        return Icons.build_rounded;
    }
  }

  // Mapper le nom du compte vers ServiceType
  ServiceType? _mapAccountNameToServiceType(String accountName) {
    final normalizedName = accountName.toLowerCase().trim();
    final map = {
      'majordome': ServiceType.majordhomme,
      'majordhomme': ServiceType.majordhomme,
      'plombier': ServiceType.plomberie,
      'plombiers': ServiceType.plomberie,
      'plomberie': ServiceType.plomberie,
      'electricien': ServiceType.electricite,
      'electriciens': ServiceType.electricite,
      'electricite': ServiceType.electricite,
      'électricité': ServiceType.electricite,
      'salubrité': ServiceType.nettoyage,
      'salubrites': ServiceType.nettoyage,
      'nettoyage': ServiceType.nettoyage,
      'peintre': ServiceType.peinture,
      'peintres': ServiceType.peinture,
      'peinture': ServiceType.peinture,
      'coiffure': ServiceType.coiffure,
      'coiffeur': ServiceType.coiffure,
      'carreleur': ServiceType.coiffure,
      'carrelleur': ServiceType.coiffure,
      'carreleurs': ServiceType.coiffure,
      'carrelage': ServiceType.coiffure,
      'menuisier': ServiceType.reparation,
      'menusier': ServiceType.reparation,
      'menuisiers': ServiceType.reparation,
      'reparation': ServiceType.reparation,
      'réparation': ServiceType.reparation,
      'frigoriste': ServiceType.climatisation,
      'frigoristes': ServiceType.climatisation,
      'climatisation': ServiceType.climatisation,
      'ajusteur': ServiceType.reparation,
      'ajusteurs': ServiceType.reparation,
      'architecte': ServiceType.renovation,
      'architect': ServiceType.renovation,
      'architectes': ServiceType.renovation,
      'maçon': ServiceType.renovation,
      'macon': ServiceType.renovation,
      'renovation': ServiceType.renovation,
      'rénovation': ServiceType.renovation,
      'chauffeur': ServiceType.transport,
      'chauffeurs': ServiceType.transport,
      'transport': ServiceType.transport,
      'demenagement': ServiceType.demenagement,
      'demenagements': ServiceType.demenagement,
    };
    return map[normalizedName];
  }

  void _logHomePageLoaded(int propertyCount) {
    print("🏠 Page accueil chargée: $propertyCount propriétés");
  }

  void _logPropertyView(PropertyModel property, bool isForRent) {
    print(
        "👀 Propriété vue: ${property.propertyId} - ${isForRent ? 'Location' : 'Vente'}");
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
    var properties = propertyCtrl.allProperties;
    var services = serviceCtrl.services;

    // Types de propriétés à afficher : Studio (1), Apparts (2), Maisons (3), Bureaux (4)
    // Utiliser les types depuis l'API si disponibles, sinon fallback sur les IDs
    final List<int> allowedTypeIds = [];

    if (propertyCtrl.propertyTypes.isNotEmpty) {
      // Mapper les noms depuis l'API vers les IDs
      for (var type in propertyCtrl.propertyTypes) {
        final name = (type['name'] ?? '').toString().toLowerCase();
        final typeId = type['propertyTypeId'];
        if (typeId != null) {
          if (name.contains('studio') ||
              name.contains('appart') ||
              name.contains('maison') ||
              name.contains('bureau') ||
              name.contains('fête') ||
              name.contains('fete') ||
              name.contains('funéraire') ||
              name.contains('funeraire') ||
              name.contains('terrain') ||
              name.contains('hotel') ||
              name.contains('hôtel')) {
            allowedTypeIds.add(typeId as int);
          }
        }
      }
    }

    // Fallback si l'API n'a pas encore chargé les types
    if (allowedTypeIds.isEmpty) {
      allowedTypeIds.addAll([
        1,
        2,
        3,
        4,
        5,
        7,
        8,
        9
      ]); // Studio, Apparts, Maisons, Bureaux, Hotels, Funéraire, Fêtes, Terrain
    }

    final rentalProperties = properties.where((p) {
      final tt = p.transactionType?.toLowerCase() ?? '';
      return tt.contains('location') &&
          allowedTypeIds.contains(p.propertyTypeId);
    }).toList()
      ..sort((a, b) => (b.propertyId ?? 0).compareTo(a.propertyId ?? 0));

    final saleProperties = properties.where((p) {
      final tt = p.transactionType?.toLowerCase() ?? '';
      return tt.contains('vente') && allowedTypeIds.contains(p.propertyTypeId);
    }).toList()
      ..sort((a, b) => (b.propertyId ?? 0).compareTo(a.propertyId ?? 0));

    // Hôtels (section dédiée sur la home)
    final hotelProperties = properties
        .where((p) =>
            (p.propertyTypeId ?? 0) == 5 &&
            allowedTypeIds.contains(p.propertyTypeId))
        .toList()
      ..sort((a, b) => (b.propertyId ?? 0).compareTo(a.propertyId ?? 0));

    // Utiliser uniquement les prestations chargées depuis l'API (pas de fallback statique)
    final currentMajordhommeServices = majordhommeServices;
    final currentDemenagementServices = demenagementServices;
    final currentOtherServicesByType = otherServicesByType;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.grey[50],
      drawer: _buildDrawer(),
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          // --- START PREMIUM BACKGROUND ---
          Positioned.fill(
            child: Container(
              color: const Color(0xFFF8F9FF), // Ultra-clean premium base
            ),
          ),

          // Mesh Gradient Blobs - Level: "DE OUF"
          // Top Right: Deep Blue
          Positioned(
            top: -100,
            right: -80,
            child: Container(
              width: 450,
              height: 450,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    primaryColor.withOpacity(0.12),
                    primaryColor.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),

          // Mid Left: Indigo/Purple accent for depth
          Positioned(
            top: 250,
            left: -120,
            child: Container(
              width: 500,
              height: 500,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF3F51B5).withOpacity(0.08), // Indigo
                    const Color(0xFF3F51B5).withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),

          // Bottom Center: Soft Cyan/Sky Blue
          Positioned(
            bottom: 100,
            left: 50,
            child: Container(
              width: 600,
              height: 600,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF00BCD4).withOpacity(0.06), // Cyan
                    const Color(0xFF00BCD4).withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),

          // Bottom Right: Primary Blue base
          Positioned(
            bottom: -150,
            right: -100,
            child: Container(
              width: 550,
              height: 550,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    primaryColor.withOpacity(0.1),
                    primaryColor.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),

          // GLASS EFFECT: Backdrop Blur to blend all blobs into a mesh
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 90, sigmaY: 90),
              child: Container(color: Colors.transparent),
            ),
          ),

          // Texture Overlay (Grain/Abstract) on top of the mesh
          Positioned.fill(
            child: Opacity(
              opacity: 0.04,
              child: Image.asset(
                "assets/images/abstract.jpg",
                fit: BoxFit.cover,
                colorBlendMode: BlendMode
                    .overlay, // "Overlay" makes it blend with the colors
              ),
            ),
          ),
          // --- END PREMIUM BACKGROUND ---
          SmartRefresher(
            controller: _refreshController,
            enablePullDown: true,
            enablePullUp: false,
            header: WaterDropMaterialHeader(
              backgroundColor: primaryColor,
              color: Colors.white,
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
                      child: _buildMinimalSyncIndicator(
                          message: "Mise à jour des données..."),
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
                    title: "Biens en Location",
                    subtitle: "Découvrez nos meilleures offres",
                    showcaseKey:
                        Provider.of<TutorialController>(context, listen: false)
                            .seeAllLocationsKey,
                    showcaseDescription:
                        "Touchez ici pour parcourir toutes les offres de location.",
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
                    heroPrefix: 'rental',
                    scrollController: _rentalsScrollController,
                  ),
                  SizedBox(height: 32),

                  // Section Ventes
                  _buildSectionHeader(
                    title: "Biens en Vente",
                    subtitle: "Investissez dans votre avenir",
                    showcaseKey:
                        Provider.of<TutorialController>(context, listen: false)
                            .seeAllSalesKey,
                    showcaseDescription:
                        "Touchez ici pour voir toutes les opportunités d’achat.",
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
                    heroPrefix: 'sale',
                    scrollController: _salesScrollController,
                  ),
                  SizedBox(height: 32),

                  // Section Hôtels
                  _buildSectionHeader(
                    title: "Hôtels",
                    subtitle: "Trouvez une chambre rapidement",
                    onSeeAll: () {
                      _logCategoryTap('hotels_see_all');
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AllPropertiesPage(
                            initialProperties: hotelProperties,
                            isForRent: true,
                          ),
                        ),
                      );
                    },
                  ),
                  SizedBox(height: 16),
                  _buildPropertyCarousel(
                    isForRent: true,
                    properties: hotelProperties,
                    isLoading: propertyCtrl.loading,
                    heroPrefix: 'hotel',
                    scrollController: _hotelsScrollController,
                  ),
                  SizedBox(height: 32),

                  // ============================================
                  // NOUVELLES SECTIONS SPÉCIALISÉES (Consolidées pour réduire la longueur)
                  // ============================================
                  // _buildSpecializedPropertiesSection(propertyCtrl), // Supprimé pour UX plus propre, voir catégories en haut

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
                    showcaseKey:
                        Provider.of<TutorialController>(context, listen: false)
                            .seeAllCleaningKey,
                    showcaseDescription:
                        "Touchez ici pour découvrir tous nos pros du ménage.",
                    onSeeAll: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ServiceCategoryPage(
                            serviceType: ServiceType.majordhomme,
                            services: currentMajordhommeServices,
                          ),
                        ),
                      );
                    },
                  ),
                  SizedBox(height: 16),
                  _buildServiceCarousel(
                    services: currentMajordhommeServices,
                    isLoading: isLoadingPrestations,
                    serviceType: ServiceType.majordhomme,
                    scrollController: _majordhommeScrollController,
                  ),
                  SizedBox(height: 32),

                  // Section Services de Déménagement
                  _buildSectionHeader(
                    title: "Déménagement",
                    subtitle: "Déménagez en toute sérénité",
                    showcaseKey:
                        Provider.of<TutorialController>(context, listen: false)
                            .seeAllMovingKey,
                    showcaseDescription:
                        "Touchez ici pour voir toutes les équipes de déménagement.",
                    onSeeAll: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ServiceCategoryPage(
                            serviceType: ServiceType.demenagement,
                            services: currentDemenagementServices,
                          ),
                        ),
                      );
                    },
                  ),
                  SizedBox(height: 16),
                  _buildServiceCarousel(
                    services: currentDemenagementServices,
                    isLoading: isLoadingPrestations,
                    serviceType: ServiceType.demenagement,
                    scrollController: _demenagementScrollController,
                  ),
                  SizedBox(height: 32),

                  // ============================================
                  // ZONE 4 : AUTRES SERVICES (Complémentaire)
                  // ============================================
                  _buildSectionHeader(
                    title: "Autres Services",
                    subtitle: "Découvrez tous nos professionnels",
                    showcaseKey:
                        Provider.of<TutorialController>(context, listen: false)
                            .seeAllOtherServicesKey,
                    showcaseDescription:
                        "Touchez ici pour explorer toutes les catégories de services.",
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
                    servicesByType: currentOtherServicesByType,
                    isLoading: isLoadingPrestations || serviceCtrl.loading,
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
          OfflineBanner(),
        ],
      ),
      // floatingActionButton: FloatingActionButton(
      //   heroTag: "home_page_fab", // Tag unique pour éviter les conflits Hero
      //   onPressed: () {
      //     _showQuickServiceRequest();
      //   },
      //   backgroundColor: primaryColor,
      //   elevation: 4,
      //   child: Icon(
      //     Icons.add_task_rounded,
      //     color: Colors.white,
      //     size: 28,
      //   ),
      //   tooltip: 'Demander un service',
      // ),
    );
  }

  Widget _buildMinimalSyncIndicator({String? message}) {
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
            message ?? 'Chargement...',
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
      // Refresh properties and special categories SEQUENTIALLY to avoid race conditions
      // syncAllSpecialCategories will merge its results into propertyCtrl.properties
      await propertyCtrl.refreshProperties();
      await propertyCtrl
          .syncAllSpecialCategories(); // Charger bureaux, festives, funeraires

      // Refresh prestations (services)
      await _loadPrestationsFromAPI();

      _refreshController.refreshCompleted();
      //SnackbarForCasa.success(context, "Liste actualisée");
    } catch (e) {
      print("❌ Erreur refresh: $e");
      _refreshController.refreshFailed();
      SnackbarForCasa.error(
        context,
        "Actualisation impossible pour le moment. Vérifiez la connexion et tirez à nouveau pour réessayer.",
      );
    } finally {
      if (mounted) {
        setState(() {
          _isManualRefresh = false;
        });
      }
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
    SnackbarForCasa.error(
      context,
      "Connexion instable. Réessayez dans un instant.",
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
        child: Showcase(
          key:
              Provider.of<TutorialController>(context, listen: false).drawerKey,
          title: 'Menu principal',
          description:
              'Retrouvez ici vos annonces, vos services et vos paramètres.',
          child: IconButton(
            icon: Icon(Icons.menu_rounded, color: Colors.white, size: 24),
            onPressed: () {
              _scaffoldKey.currentState?.openDrawer();
            },
            splashRadius: 20,
            padding: EdgeInsets.zero,
          ),
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
        Showcase(
          key: Provider.of<TutorialController>(context, listen: false)
              .notificationKey,
          title: 'Notifications',
          description:
              'Consultez vos alertes, messages et confirmations de réservation.',
          child: Stack(
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
                child: Consumer<NotificationController>(
                  builder: (context, notifCtrl, child) {
                    final count = notifCtrl.unreadCount;
                    // Afficher le badge même si 0 ou non ? Le user dit "fais clignoter le nombres" et "indique les nonbres de ceux pas encore lit"
                    // Usuellement on cache si 0. Mais "il ya 2 notificatoons mais aussi iindique les nonbres"
                    if (count == 0) return SizedBox.shrink();

                    Widget badge = Container(
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
                          count > 9 ? '9+' : count.toString(),
                          style: TextStyle(
                            fontSize: 9,
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                          ),
                        ),
                      ),
                    );

                    // Clignoter si notifications non lues
                    if (count > 0) {
                      return PulseBadge(child: badge);
                    }

                    return badge;
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String get safeUsername {
    final userData = storage.read(StockageKeys.userKey);
    final profileData = storage.read(StockageKeys.profileKey);

    // PRIORITÉ 1: fullName
    final fullName = profileData?['fullname']?.toString() ??
        profileData?['fullName']?.toString() ??
        userData?['fullname']?.toString() ??
        userData?['fullName']?.toString();

    if (fullName != null && fullName.isNotEmpty) {
      return fullName;
    }

    // PRIORITÉ 2: username
    return userData?['username']?.toString() ??
        profileData?['username']?.toString() ??
        'Bio'; // Or Visiteur
  }

  Widget _buildDrawer() {
    final stockage = GetStorage();
    final token = stockage.read(StockageKeys.tokenKey);
    final user = stockage.read(StockageKeys.userKey);
    final profile = stockage.read(StockageKeys.profileKey);

    // Retrieve authCtrl and userAccounts for use in drawer
    final authCtrl = Provider.of<AuthentificationCtrl>(context, listen: false);
    final userAccounts = stockage.read('user_accounts');

    bool isLoggedIn = token != null;

    String selectedRoute =
        ModalRoute.of(context)?.settings.name ?? Routes.bottomPageRoute;

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
                height: 230,
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
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Photo de profil (sans possibilité de modification)
                          AnimatedContainer(
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
                            child: Consumer<AuthentificationCtrl>(
                              builder: (context, auth, child) {
                                // Re-lire les données du drawer pour attraper les mises à jour de stockage
                                final profileData =
                                    stockage.read(StockageKeys.profileKey);
                                String? imageUrl;
                                if (profileData != null && profileData is Map) {
                                  imageUrl = profileData['image']?.toString() ??
                                      profileData['images']?.toString();
                                }

                                final hasValidUrl = imageUrl != null &&
                                    imageUrl.isNotEmpty &&
                                    !imageUrl.startsWith('/');

                                return CircleAvatar(
                                  radius: 40,
                                  backgroundColor: Colors.white,
                                  backgroundImage: () {
                                    // 1. Priorité au fichier local (Garanti Offline & Instantané)
                                    final localPath =
                                        stockage.read('user_image_path');
                                    if (localPath != null &&
                                        File(localPath).existsSync()) {
                                      return FileImage(File(localPath))
                                          as ImageProvider;
                                    }

                                    // 2. Sinon, image réseau avec cache
                                    if (hasValidUrl) {
                                      return CachedNetworkImageProvider(
                                          imageUrl!);
                                    }

                                    return null;
                                  }(),
                                  child: (() {
                                    final localPath =
                                        stockage.read('user_image_path');
                                    if (localPath != null &&
                                        File(localPath).existsSync())
                                      return null;
                                    if (hasValidUrl) return null;
                                    return Icon(
                                      Icons.person,
                                      size: 42,
                                      color: primaryColor,
                                    );
                                  })(),
                                );
                              },
                            ),
                          ),
                          SizedBox(height: 12),
                          // Texte "Bienvenue"
                          Text(
                            'Bienvenue',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          SizedBox(height: 4),
                          // Nom d'utilisateur
                          AnimatedSwitcher(
                            duration: Duration(milliseconds: 300),
                            child: isLoggedIn
                                ? Text(
                                    (safeUsername ?? 'Utilisateur'),
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
                                  )
                                : Column(
                                    key: ValueKey('welcome'),
                                    children: [
                                      Container(
                                        constraints: BoxConstraints(
                                          maxWidth:
                                              200, // Limite la largeur maximale
                                        ),
                                        child: Text(
                                          'Connectez-vous pour accéder à toutes les fonctionnalités',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color:
                                                Colors.white.withOpacity(0.9),
                                            fontSize:
                                                11, // Réduit la taille de police
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
                  physics: const ClampingScrollPhysics(),
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
                            onTap: () =>
                                _handleNavigation(Routes.bottomPageRoute),
                          ),
                          // _buildDrawerItem(
                          //   icon: Icons.add_task_rounded,
                          //   title: 'Demander un service',
                          //   routeName: Routes.quickServiceRequestRoute,
                          //   isSelected: selectedRoute == Routes.quickServiceRequestRoute,
                          //   onTap: () => _handleNavigation(Routes.quickServiceRequestRoute),
                          // ),
                          if (isLoggedIn) ...[
                            // _buildDrawerItem(
                            //   icon: Icons.construction_rounded,
                            //   title: 'Demander intervention',
                            //   routeName: Routes.requestInterventionRoute,
                            //   isSelected: selectedRoute == Routes.requestInterventionRoute,
                            //   onTap: () {
                            //     // Note: Cette route nécessite un ServiceModel en argument
                            //     // Pour l'instant, on affiche juste un message
                            //     Navigator.pop(context);
                            //     SnackbarForCasa.info(
                            //       context,
                            //       "Sélectionnez un service pour demander une intervention",
                            //     );
                            //   },
                            // ),

                            // "Mes Réservations" - Visible pour tous (si loggé)
                            _buildDrawerItem(
                              icon: Icons.calendar_today_rounded,
                              title: 'Mes Réservations',
                              routeName: Routes.bookingHistoryPageRoute,
                              isSelected: selectedRoute ==
                                  Routes.bookingHistoryPageRoute,
                              onTap: () => _handleNavigation(
                                  Routes.bookingHistoryPageRoute),
                            ),
                            Consumer<AuthentificationCtrl>(
                              builder: (context, auth, _) {
                                final premium = auth.user.isPremium == true;
                                final route = premium
                                    ? Routes.paymentHistoryRoute
                                    : Routes.subscriptionPaymentRoute;
                                return _buildDrawerItem(
                                  icon: premium
                                      ? Icons.receipt_long_rounded
                                      : Icons.workspace_premium_rounded,
                                  title: premium
                                      ? 'Historique des paiements'
                                      : 'Abonnement',
                                  routeName: route,
                                  isSelected: selectedRoute == route,
                                  onTap: () => _handleNavigation(route),
                                );
                              },
                            ),

                            // LOGIQUE DE FILTRAGE
                            Builder(builder: (context) {
                              bool showMesProprietes = false;
                              bool showMesServices = false;
                              bool showMonAgence = false;
                              bool isGerant = false;

                              // Analyser user_accounts
                              if (userAccounts != null &&
                                  userAccounts is List) {
                                // Vérifier d'abord si Gérant est présent
                                isGerant = userAccounts.any((acc) {
                                  final typeId = (acc['typeAccount']
                                          ?['typeAccountId'] ??
                                      (acc['typeAccountId'] ??
                                          acc['TypeAccountId']));
                                  final name = (acc['name'] ?? acc['Name'])
                                          ?.toString()
                                          .toLowerCase() ??
                                      '';
                                  return typeId == 2 &&
                                      (name.contains('gerant') ||
                                          acc['id'] == 3);
                                  // Note: En JSON fourni, gerant a id:3 et typeAccount.name="Proprietaire" (id:2)
                                  // Donc on check aussi le nom ou l'ID spécifique si on veut être strict
                                });

                                // Gérant -> voit Mon Agence
                                if (isGerant) {
                                  showMonAgence = true;
                                // Le gérant est aussi un owner: il doit voir "Mes propriétés"
                                // (ex. salles de fête / funéraires).
                                showMesProprietes = true;
                                }

                                for (var acc in userAccounts) {
                                  final typeId = (acc['typeAccount']
                                          ?['typeAccountId'] ??
                                      (acc['typeAccountId'] ??
                                          acc['TypeAccountId']));
                                  final name = (acc['name'] ?? acc['Name'])
                                          ?.toString()
                                          .toLowerCase() ??
                                      '';
                                  final accId = acc['id']; // id du compte

                                  // Propriétaire (typeAccountId == 2)
                                  // (le gérant est déjà autorisé via showMesProprietes)
                                  if (typeId == 2) {
                                    // Si c'est un gérant, on l'a déjà traité pour showMonAgence
                                    // Si ce N'EST PAS un gérant, alors c'est Commissionnaire ou Bailleur -> voit Mes Propriétés
                                    if (!name.contains('gerant') &&
                                        accId != 3) {
                                      showMesProprietes = true;
                                    }
                                  }

                                  // Prestataire (typeAccountId == 3) -> voit Mes Services
                                  if (typeId == 3) {
                                    showMesServices = true;
                                  }
                                }
                              }

                              return Column(
                                children: [
                                  // "Mes propriétés" - Commissionnaire/Bailleur + Gérant
                                  if (showMesProprietes)
                                    _buildDrawerItem(
                                      icon: Icons.apartment_rounded,
                                      title: isGerant ? 'Mes salles' : 'Mes propriétés',
                                      routeName: Routes.myPropertiesRoute,
                                      isSelected: selectedRoute ==
                                          Routes.myPropertiesRoute,
                                      onTap: () => _handleNavigation(
                                        Routes.myPropertiesRoute,
                                        arguments: isGerant
                                            ? {'onlyFestiveAndFuneraire': true}
                                            : null,
                                      ),
                                    ),

                                  // "Mes hôtels & chambres" - Seulement pour Gérant
                                  if (showMonAgence)
                                    _buildDrawerItem(
                                      icon: Icons.hotel_rounded,
                                      title: 'Mes hôtels & chambres',
                                      routeName: Routes.myHotelsRoute,
                                      isSelected:
                                          selectedRoute == Routes.myHotelsRoute,
                                      onTap: () => _handleNavigation(
                                          Routes.myHotelsRoute),
                                    ),

                                  // "Mes services" - Visible pour TOUS (si loggé)
                                  // Modification demandée: Tout le monde voit le menu, mais l'intérieur change
                                  _buildDrawerItem(
                                    icon: Icons.work_rounded,
                                    title: 'Mes activités',
                                    routeName: Routes.myServicesRoute,
                                    isSelected:
                                        selectedRoute == Routes.myServicesRoute,
                                    onTap: () => _handleNavigation(
                                        Routes.myServicesRoute),
                                  ),

                                  // "Mon Agence" - Seulement pour Gérant
                                  if (showMonAgence)
                                    _buildDrawerItem(
                                      icon: Icons.store_mall_directory_rounded,
                                      title: 'Mon Agence',
                                      routeName: '/my-agency',
                                      isSelected: selectedRoute == '/my-agency',
                                      onTap: () =>
                                          _handleNavigation('/my-agency'),
                                    ),
                                ],
                              );
                            }),
                          ],
                        ],
                      ),

                      // SECTION SOCIAL
                      _buildDrawerSection(
                        title: "SOCIAL",
                        items: [
                          if (isLoggedIn)
                            _buildDrawerItem(
                              icon: Icons.people_alt_rounded,
                              title: 'Parrainer',
                              routeName: Routes.ParrainagePageRoute,
                              isSelected:
                                  selectedRoute == Routes.ParrainagePageRoute,
                              onTap: () =>
                                  _handleNavigation(Routes.ParrainagePageRoute),
                            ),
                          _buildDrawerItem(
                            icon: Icons.share_rounded,
                            title: 'Partager l\'app',
                            isSelected: selectedRoute == '/share',
                            onTap: _shareApp,
                          ),
                        ],
                      ),

                      // SECTION SUPPORT
                      _buildDrawerSection(
                        title: "SUPPORT",
                        items: [
                          _buildDrawerItem(
                            icon: Icons.help_outline_rounded,
                            title: 'Aide & Support',
                            isSelected:
                                selectedRoute == Routes.helpSupportRoute,
                            onTap: () =>
                                _handleNavigation(Routes.helpSupportRoute),
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
                                    Navigator.pushNamed(
                                        context, Routes.loginRoute);
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryColor,
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.symmetric(
                                        vertical: 14, horizontal: 20),
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
                                    Navigator.pushNamed(
                                        context, Routes.registerRoute);
                                  },
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: primaryColor,
                                    side: BorderSide(
                                        color: primaryColor, width: 1.5),
                                    padding: EdgeInsets.symmetric(
                                        vertical: 14, horizontal: 20),
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
                      Center(
                        child: Text(
                          _packageInfoLoaded
                              ? 'Version $_appVersion'
                              : 'Version …',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
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

  void _shareApp() {
    Navigator.pop(context); // Close drawer
    Share.share(
      CasanayoShareCopy.appInvitationMessage(),
      subject: CasanayoShareCopy.shareAppSubject,
    );
  }

  void _handleNavigation(String routeName, {Object? arguments}) {
    Navigator.pop(context);

    if (routeName == Routes.bottomPageRoute) {
      // Déjà sur la page d'accueil (contenue dans BottomNavBar), on ferme juste le drawer
      return;
    }

    if (routeName == Routes.commissionnaireDashboardPageRoute ||
        routeName == Routes.myPropertiesRoute ||
        routeName == Routes.myHotelsRoute ||
        routeName == Routes.myServicesRoute ||
        routeName == Routes.ParrainagePageRoute ||
        routeName == Routes.bookingHistoryPageRoute ||
        routeName == Routes.quickServiceRequestRoute ||
        routeName == Routes.myServiceRequestsRoute ||
        routeName == Routes.notificationPageRoute ||
        routeName == Routes.helpSupportRoute ||
        routeName == Routes.subscriptionPaymentRoute ||
        routeName == Routes.paymentHistoryRoute) {
      Navigator.pushNamed(context, routeName, arguments: arguments);
    } else if (routeName == '/my-agency') {
      Navigator.push(
          context, MaterialPageRoute(builder: (_) => MyAgencyPage()));
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

    final bgColor =
        isSelected ? primaryColor.withOpacity(0.1) : Colors.transparent;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: isSelected
              ? Border.all(
                  color: primaryColor.withOpacity(0.3),
                  width: 1,
                )
              : null,
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
                      color: isSelected
                          ? primaryColor.withOpacity(0.15)
                          : Colors.grey[100],
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
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.normal,
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
                padding: const EdgeInsets.fromLTRB(24, 50, 24, 20),
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
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => PropertySearchPage()),
                          );
                        },
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
    final propertyCtrl = Provider.of<PropertyController>(context);

    // Si la liste est vide, on utilise une liste de fallback pour éviter un écran vide au premier démarrage
    // Si la liste est vide, on utilise une liste de fallback complète pour couvrir tous les besoins
    final List<Map<String, dynamic>> categories =
        propertyCtrl.propertyTypes.isNotEmpty
            ? propertyCtrl.propertyTypes
                .map((type) => {
                      'propertyTypeId': type['propertyTypeId'],
                      'label': type['name'],
                      'image': _getCategoryImage(type['name'] ?? ''),
                      'value': _getCategoryValue(type['name'] ?? ''),
                    })
                .toList()
            : [
                {
                  'label': 'Studios',
                  'image': 'assets/images/studio.png',
                  'value': 'Studio'
                },
                {
                  'label': 'Apparts',
                  'image': 'assets/images/apart.png',
                  'value': 'Apparts'
                },
                {
                  'label': 'Maisons',
                  'image': 'assets/images/maison.png',
                  'value': 'Maisons'
                },
                {
                  'label': 'Bureaux',
                  'image': 'assets/images/office.png',
                  'value': 'Bureau'
                },
                {
                  'label': 'Fêtes',
                  'image': 'assets/images/fete.png',
                  'value': 'Salle de fête'
                },
                {
                  'label': 'Funéraires',
                  'image': 'assets/images/funebre.png',
                  'value': 'Salle funéraires'
                },
                {
                  'label': 'Terrains',
                  'image': 'assets/images/Terrain.png',
                  'value': 'Terrain'
                },
                {
                  'label': 'Hôtels',
                  'image': 'assets/images/hotel.png',
                  'value': 'Hotels'
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
                    'Voir tout ',
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
              controller: _categoryScrollController,
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
                        final rawValue = (category['value'] as String?) ?? '';
                        final normalizedValue =
                            rawValue.toLowerCase().contains('appart')
                                ? 'Apparts'
                                : rawValue;
                        _logCategoryTap(normalizedValue);

                        // Navigate to TerrainPropertiesPage for terrains
                        if (normalizedValue == 'Terrain') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => TerrainPropertiesPage(),
                            ),
                          );
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CategoryPropertiesPage(
                                category: normalizedValue,
                              ),
                            ),
                          );
                        }
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

  void _startAutoScrolls() {
    _categoryTimer =
        _createAutoScrollTimer(_categoryScrollController, delta: 100);
    _rentalsTimer =
        _createAutoScrollTimer(_rentalsScrollController, delta: 200);
    _salesTimer = _createAutoScrollTimer(_salesScrollController, delta: 200);
    _hotelsTimer = _createAutoScrollTimer(_hotelsScrollController, delta: 200);
    _majordhommeTimer =
        _createAutoScrollTimer(_majordhommeScrollController, delta: 220);
    _demenagementTimer =
        _createAutoScrollTimer(_demenagementScrollController, delta: 220);
  }

  Timer _createAutoScrollTimer(ScrollController controller,
      {double delta = 150.0}) {
    return Timer.periodic(Duration(seconds: 4), (timer) {
      if (controller.hasClients) {
        double maxScroll = controller.position.maxScrollExtent;
        double currentScroll = controller.offset;

        if (currentScroll + delta >= maxScroll) {
          controller.animateTo(
            0,
            duration: Duration(milliseconds: 1500),
            curve: Curves.easeOutQuad,
          );
        } else {
          controller.animateTo(
            currentScroll + delta,
            duration: Duration(milliseconds: 1000),
            curve: Curves.easeInOutQuad,
          );
        }
      }
    });
  }

  void _startCategoryAutoScroll() {
    // Logic moved to _startAutoScrolls and _createAutoScrollTimer
  }

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
    required VoidCallback onSeeAll,
    GlobalKey? showcaseKey,
    String? showcaseDescription,
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
              showcaseKey != null
                  ? Showcase(
                      key: showcaseKey,
                      title: 'Explorer',
                      description: showcaseDescription ??
                          "Ouvrez la liste complète pour voir tous les éléments de cette section.",
                      child: InkWell(
                        onTap: onSeeAll,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding:
                              EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Explorer',
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
                    )
                  : InkWell(
                      onTap: onSeeAll,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Explorer',
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
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  Container(
                                      width: 60,
                                      height: 15,
                                      color: Colors.white),
                                  Container(
                                      width: 60,
                                      height: 15,
                                      color: Colors.white),
                                  Container(
                                      width: 60,
                                      height: 15,
                                      color: Colors.white),
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
    required List<PrestationModel> services,
    required bool isLoading,
    required ServiceType serviceType,
    ScrollController? scrollController,
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
        controller: scrollController,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: 24),
        itemCount: min(5, services.length),
        itemBuilder: (context, index) {
          final service = services[index];

          final String? imageUrl =
              (service.profile != null && service.profile!.isNotEmpty)
                  ? service.profile
                  : (service.images?.isNotEmpty ?? false
                      ? service.images!.first
                      : null);

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
                        builder: (context) =>
                            ServiceDetailPage(service: service),
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
                            tag: 'service-image-${service.id}',
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
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                    primaryColor),
                                          ),
                                        ),
                                      ),
                                      errorWidget: (context, url, error) =>
                                          Container(
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
                                        "${service.cityValue}, ${service.communeValue}",
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
                        // Favorite Button
                        if (service.id != null)
                          Positioned(
                            top: 12,
                            right: 12,
                            child: FavoriteHeartIcon(
                              propertyId: service.id.toString(),
                              isPrestation: true,
                              size: 24,
                              splashRadius: 20,
                              activeColor: Colors.red,
                              inactiveColor: Colors.white,
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

  String _getPriceRange(PrestationModel service) {
    if (service.minPrice == null && service.maxPrice == null)
      return 'Prix sur demande';

    final double? minP =
        service.minPrice != null ? service.minPrice!.toDouble() : null;
    final double? maxP =
        service.maxPrice != null ? service.maxPrice!.toDouble() : null;
    final String currency = service.currency;

    if (minP != null) {
      return 'A partir de ${_formatServicePrice(minP)} $currency';
    } else if (maxP != null) {
      return 'Jusqu\'à ${_formatServicePrice(maxP)} $currency';
    }

    return 'Prix sur demande';
  }

  String _formatServicePrice(num price) {
    return NumberFormat('#,###').format(price);
  }

  Widget _buildOtherServicesGrid({
    required Map<ServiceType, List<PrestationModel>> servicesByType,
    required bool isLoading,
  }) {
    // Utiliser uniquement les prestations depuis l'API (pas de fallback statique)
    Map<ServiceType, List<PrestationModel>> groupedServices = servicesByType;

    // Liste des types de services à afficher (priorité)
    final List<ServiceType> priorityServiceTypes = [
      ServiceType.plomberie,
      ServiceType.electricite,
      ServiceType.peinture,
      ServiceType.coiffure,
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
        .where((type) =>
            groupedServices.containsKey(type) &&
            groupedServices[type]!.isNotEmpty)
        .take(6) // Limiter à 6 services pour la grille 2x2 (3 lignes)
        .toList();

    if (isLoading || availableServiceTypes.isEmpty) {
      return Container(
        height: 570, // Augmenté pour 3 rangées de 2 colonnes
        margin: EdgeInsets.symmetric(horizontal: 24),
        child: GridView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, // 2 colonnes
            crossAxisSpacing: 16, // Espacement un peu plus large
            mainAxisSpacing: 16,
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
          crossAxisCount: 2, // 2 colonnes au lieu de 3
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio:
              1.1, // Ratio plus large pour laisser de la place au titre
        ),
        itemCount: availableServiceTypes.length,
        itemBuilder: (context, index) {
          final serviceType = availableServiceTypes[index];
          final serviceList = groupedServices[serviceType]!;
          final serviceCount = serviceList.length;
          final firstService = serviceList.first;

          // Récupérer l'image de fond depuis le premier service
          // Chercher dans tous les services de la liste si le premier n'a pas d'image
          String? backgroundImageUrl;

          // Fonction locale pour extraire l'image d'une prestation
          String? getPrestationImage(PrestationModel p) {
            if (p.profile != null && p.profile!.isNotEmpty) return p.profile;
            if (p.images != null && p.images!.isNotEmpty)
              return p.images!.first;
            return null;
          }

          backgroundImageUrl = getPrestationImage(firstService);

          if (backgroundImageUrl == null) {
            // Parcourir les autres services pour trouver une image
            for (var service in serviceList) {
              final img = getPrestationImage(service);
              if (img != null) {
                backgroundImageUrl = img;
                break;
              }
            }
          }

          // Debug: afficher les informations sur les images
          if (backgroundImageUrl == null) {
            print(
                "⚠️ [HomePage] Aucune image trouvée pour le type de service: $serviceType (${serviceList.length} services)");
            for (var i = 0; i < serviceList.length && i < 3; i++) {
              final s = serviceList[i];
              print(
                  "  Service ${i + 1}: images = ${s.images?.length ?? 0} (${s.images?.join(', ') ?? 'null'})");
            }
          } else {
            print(
                " [HomePage] Image trouvée pour $serviceType: $backgroundImageUrl");
          }

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
                              )),
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

                      // Overlay sombre pour améliorer la lisibilité
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.3),
                              Colors.black.withOpacity(0.7),
                            ],
                            stops: [0.0, 0.5, 1.0],
                          ),
                        ),
                      ),

                      // Contenu avec design moderne et épuré
                      Container(
                        padding: EdgeInsets.all(12),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Badge nombre en haut à gauche - Design simple et moderne
                            Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.5),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 8,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Text(
                                "$serviceCount",
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),

                            // Titre du service en bas
                            Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Colors.black.withOpacity(0.7),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    serviceType.displayName,
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.3,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    serviceType.description,
                                    style: GoogleFonts.inter(
                                      color: Colors.white.withOpacity(0.85),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      height: 1.2,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
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
                  final propertyCtrl =
                      Provider.of<PropertyController>(context, listen: false);
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
    String? heroPrefix,
    ScrollController? scrollController,
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
        controller: scrollController,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: 24),
        itemCount: min(5, properties.length),
        itemBuilder: (context, index) {
          final property = properties[index];
          // Tag unique par carte (évite collision si le même propertyId apparaît deux fois dans la liste)
          final String carouselHeroTag = heroPrefix != null
              ? '${heroPrefix}-${property.propertyId}-$index'
              : 'property-image-${property.propertyId}-$index';

          final firstImage = property.propertyImage?.isNotEmpty ?? false
              ? property.propertyImage!.first
              : null;
          final imageUrl = firstImage != null
              ? "${firstImage.path ?? firstImage.path}"
              : null;

          final typeName =
              (property.propertyType?.name ?? '').toString().toLowerCase();
          final bool isHotel = property.propertyTypeId == 5 ||
              typeName.contains('hotel') ||
              typeName.contains('hôtel');

          // Hôtels: ne pas afficher le prix sur la home.
          final String? priceText = isHotel
              ? null
              : ((isForRent && !isHotel)
                  ? '${property.price?.toStringAsFixed(0) ?? '0'} ${property.currency}/mois'
                  : '${property.price?.toStringAsFixed(0) ?? '0'} ${property.currency}');

          // Hôtels: enrichir les chambres en cache-first (local + refresh async) pour afficher le vrai nombre.
          if (isHotel && property.propertyId != null) {
            final id = property.propertyId!;
            final hasRooms = (property.hotelStructure?.isNotEmpty ?? false);
            if (!hasRooms && !_requestedHotelRoomEnrich.contains(id)) {
              _requestedHotelRoomEnrich.add(id);
              Future.microtask(() {
                try {
                  context.read<PropertyController>().getPropertyById(
                        id,
                        propertyTypeId: 5,
                        mergeWith: property,
                      );
                } catch (_) {}
              });
            }
          }

          return Container(
            width: 280,
            height:
                380, // Hauteur fixe pour que l'image remplisse toute la carte
            margin: EdgeInsets.only(right: 20, bottom: 10, top: 10),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: () async {
                    _logPropertyView(property, isForRent);
                    await navigateToPropertyDetail(
                      context,
                      property,
                      heroTag: carouselHeroTag,
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
                      fit: StackFit
                          .expand, // S'assurer que le Stack prend toute la place
                      children: [
                        Positioned.fill(
                          child: Hero(
                            tag: carouselHeroTag,
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
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                    primaryColor),
                                          ),
                                        ),
                                      ),
                                      errorWidget: (context, url, error) =>
                                          Container(
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
                                        "${property.cityValue}, ${property.communeValue}",
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
                              if (priceText != null)
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
                                child: isHotel
                                    ? Row(
                                        children: [
                                          const Icon(Icons.hotel_rounded,
                                              size: 18, color: Colors.white),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              (property.address ?? '')
                                                      .trim()
                                                      .isNotEmpty
                                                  ? property.address!.trim()
                                                  : "${property.cityValue ?? ''}${(property.communeValue ?? '').toString().trim().isNotEmpty ? ', ${property.communeValue}' : ''}",
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.inter(
                                                color: Colors.white
                                                    .withOpacity(0.92),
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: Colors.white
                                                  .withOpacity(0.16),
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                              border: Border.all(
                                                  color: Colors.white
                                                      .withOpacity(0.18)),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.bed_rounded,
                                                    size: 14,
                                                    color: Colors.white),
                                                const SizedBox(width: 6),
                                                Text(
                                                  '${property.hotelStructure?.length ?? 0}',
                                                  style: GoogleFonts.inter(
                                                    color: Colors.white,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      )
                                    : Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceAround,
                                        children: [
                                          if (property.propertyTypeId != 4 &&
                                              property.propertyTypeId != 7 &&
                                              property.propertyTypeId != 8 &&
                                              property.propertyTypeId != 9) ...[
                                            _buildModernFeatureItem(
                                              icon: FontAwesomeIcons.bed,
                                              value:
                                                  '${property.bedrooms ?? 0}',
                                            ),
                                            _buildModernFeatureItem(
                                              icon: FontAwesomeIcons.bath,
                                              value:
                                                  '${property.bathroom ?? 0}',
                                            ),
                                          ] else ...[
                                            if (property.propertyTypeId ==
                                                4) ...[
                                              // Bureau special fields
                                              _buildModernFeatureItem(
                                                icon:
                                                    Icons.meeting_room_outlined,
                                                value:
                                                    '${property.roomMeet ?? 0}',
                                              ),
                                              _buildModernFeatureItem(
                                                icon: property.isEquip == true
                                                    ? Icons.chair
                                                    : Icons.chair_outlined,
                                                value: property.isEquip == true
                                                    ? 'Oui'
                                                    : 'Non',
                                              ),
                                            ],
                                            if (property.propertyTypeId == 7 ||
                                                property.propertyTypeId ==
                                                    8) ...[
                                              // Festive/Funeraire special fields
                                              _buildModernFeatureItem(
                                                icon: Icons.people_outline,
                                                value:
                                                    '${property.capacityPeople ?? 0}',
                                              ),
                                            ],
                                            if (property.propertyTypeId ==
                                                9) ...[
                                              // Terrain: surface uniquement (pas de chambres/salon).
                                              _buildModernFeatureItem(
                                                icon: FontAwesomeIcons
                                                    .rulerCombined,
                                                value:
                                                    '${property.surface?.toStringAsFixed(0) ?? '0'}',
                                              ),
                                            ],
                                          ],
                                          if (property.propertyTypeId != 9) ...[
                                            _buildModernFeatureItem(
                                              icon: FontAwesomeIcons
                                                  .rulerCombined,
                                              value:
                                                  '${property.surface?.toStringAsFixed(0) ?? '0'}',
                                            ),
                                            _buildModernFeatureItem(
                                              icon: Icons.zoom_out_map,
                                              value: '${property.rooms ?? 0}',
                                            ),
                                          ],
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
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _buildHomePropertyTopBadges(
                                  property,
                                  isForRent,
                                ),
                              ),
                              if (property.propertyId != null)
                                Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: FavoriteHeartIcon(
                                    propertyId: property.propertyId.toString(),
                                    propertyTypeId: property.propertyTypeId,
                                    size: 24,
                                    splashRadius: 20,
                                    activeColor: Colors.red,
                                    inactiveColor: Colors.white,
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

  /// Pastille transaction + pastille d’état (Disponible / Vendu / Non disponible / Retiré), lisibles sur la photo.
  Widget _buildHomePropertyTopBadges(PropertyModel property, bool isForRent) {
    final listingAllowed = property.listingAllowed;
    final sold = property.sold;
    final tt = property.transactionType;

    Widget transactionChip() {
      return AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isForRent
              ? Colors.blueAccent.withOpacity(0.92)
              : Colors.greenAccent.withOpacity(0.92),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.45), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.28),
              blurRadius: 8,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Text(
          isForRent ? 'À LOUER' : 'À VENDRE',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            shadows: [
              Shadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
        ),
      );
    }

    final statusChip = PropertyListingStatusChip(
      sold: sold,
      transactionType: tt,
      available: property.available,
      listingAllowed: listingAllowed,
      compact: false,
      onDarkBackground: true,
    );

    if (!listingAllowed) {
      return statusChip;
    }

    return Wrap(
      spacing: 8,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        transactionChip(),
        statusChip,
      ],
    );
  }

  Widget _buildModernFeatureItem(
      {required IconData icon, required String value}) {
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

  String _getCategoryImage(String name) {
    String n = name.toLowerCase();
    if (n.contains('studio')) return 'assets/images/studio.png';
    if (n.contains('appart')) return 'assets/images/apart.png';
    if (n.contains('maison') || n.contains('villa'))
      return 'assets/images/maison.png';
    if (n.contains('bureau') || n.contains('office'))
      return 'assets/images/office.png';
    if (n.contains('hotel')) return 'assets/images/hotel.png';
    if (n.contains('vacance')) return 'assets/images/plage.png';
    if (n.contains('fête')) return 'assets/images/fete.png';
    if (n.contains('funérair')) return 'assets/images/funebre.png';
    if (n.contains('entrepôt')) return 'assets/images/Entrepot.png';
    if (n.contains('terrain')) return 'assets/images/Terrain.png';
    return 'assets/images/apart.png'; // Fallback
  }

  String _getCategoryValue(String name) {
    String n = name.toLowerCase();
    if (n.contains('studio')) return 'Studio';
    if (n.contains('appart')) return 'Apparts';
    if (n.contains('maison')) return 'Maisons';
    if (n.contains('bureau')) return 'Bureau';
    if (n.contains('hotel') || n.contains('hôtel')) return 'Hotels';
    if (n.contains('vacance')) return 'Vacances';
    if (n.contains('funérair')) return 'Salle funéraires';
    if (n.contains('fête')) return 'Salle de fête';
    if (n.contains('terrain')) return 'Terrain';
    return name;
  }
}
