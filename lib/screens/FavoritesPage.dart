import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:casa/controllers/PropertyFavoriteCtrl.dart';
import 'package:casa/controllers/provider/FavoriteProvider.dart';
import 'package:casa/models/PropertyFavoriteModel.dart';
import 'package:casa/models/PropertyModel.dart';
import 'package:casa/models/PrestationModel.dart';
import 'package:casa/utils/Constantes.dart';
import 'package:casa/utils/FancyNotification.dart';
import 'package:casa/utils/crashlytics_api.dart';
import 'package:casa/utils/StockageKeys.dart';
import 'package:casa/utils/AppColors.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../controllers/TutorialController.dart';

import '../controllers/AuthentificationCtrl.dart';
import '../controllers/PropertyCtrl.dart';
import '../controllers/ServiceController.dart';
import '../models/AgenceModel.dart';
import '../utils/property_detail_navigation.dart';
import 'SiteDetailsPage.dart';
import '../utils/Routes.dart';
import '../utils/FavoriteEartIcon.dart';
import '../utils/property_availability_ui.dart';
import '../widgets/property_sold_badge.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({Key? key}) : super(key: key);

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoadingData = true;
  bool _isRefreshing = false;
  final DateFormat _dateFormat = DateFormat('dd MMM yyyy', 'fr_FR');
  final GetStorage _storage = GetStorage();
  bool _isLoading = false;
  final TutorialController _tutorialController = TutorialController();

  // Couleurs modernes
  final Color _primaryColor = Color(0xFF1976D2);
  final Color _secondaryColor = Color(0xFF64B5F6);
  final Color _darkColor = Color(0xFF1A1D26);
  final Color _lightGrey = Color(0xFFF5F6FA);
  final Color _mediumGrey = Color(0xFF7F8C8D);
  final Color _successColor = Color(0xFF00B894);
  final Color _warningColor = Color(0xFFFDCB6E);
  final Color _errorColor = Color(0xFFD63031);
  final Color _cardBackground = Colors.white;
  final Color _chipBackground = Color(0xFFE8F4F8);

  List<int> _deletingIds = [];
  bool _isGridView = true;

  // Optimisation: éviter de refaire le même enrichissement d’images plusieurs fois.
  final Map<int, PropertyModel> _imageEnrichCacheById = {};
  final Map<int, Future<PropertyModel>> _imageEnrichInFlightById = {};

  String? _stableImageUrlForProperty(PropertyModel? p) {
    if (p == null) return null;
    final direct = (p.propertyImage?.isNotEmpty == true) ? p.propertyImage!.first.path : null;
    if (direct != null && direct.toString().trim().isNotEmpty) return direct;

    final id = p.propertyId;
    if (id == null) return null;
    final cached = _imageEnrichCacheById[id];
    final fromCache = (cached?.propertyImage?.isNotEmpty == true) ? cached!.propertyImage!.first.path : null;
    if (fromCache != null && fromCache.toString().trim().isNotEmpty) return fromCache;
    return null;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // Fix: Delay load to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadFavorites();
    });
  }

  // Shimmer effect
  Widget _buildShimmerEffect() {
    return ListView.separated(
      padding: EdgeInsets.all(20),
      itemCount: 4,
      separatorBuilder: (_, __) => SizedBox(height: 20),
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: Colors.white,
            ),
            padding: EdgeInsets.all(1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 180,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    color: Colors.grey[400],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 20,
                        width: double.infinity,
                        color: Colors.grey[400],
                      ),
                      SizedBox(height: 8),
                      Container(
                        height: 16,
                        width: 150,
                        color: Colors.grey[400],
                      ),
                      SizedBox(height: 12),
                      Container(
                        height: 16,
                        width: 200,
                        color: Colors.grey[400],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _loadFavorites() async {
    try {
      if (!mounted) return;

      final authCtrl = context.read<AuthentificationCtrl>();
      final isLoggedIn = authCtrl.token.isNotEmpty;

      if (!isLoggedIn) {
        setState(() {
          _isLoadingData = false;
          _isRefreshing = false;
        });
        return;
      }

      setState(() {
        _isLoadingData = true;
        _isRefreshing = true;
      });

      final userId = authCtrl.user.userId?.toString();
      if (userId != null) {
        final propertyCtrl = Provider.of<PropertyFavoriteCtrl>(context, listen: false);
        await propertyCtrl.getFavoritesByUser(userId);
        
        // SYNC: Mettre à jour le provider d'état global pour que les icônes (coeurs) soient à jour
        final favoriteProvider = Provider.of<FavoriteProvider>(context, listen: false);
        favoriteProvider.syncFavorites(userId); // Pas besoin d'await ici pour ne pas bloquer l'UI
        
        print("📊 Favoris chargés: ${propertyCtrl.propertyFavorites.length}");

        // Enrichissement rapide depuis le cache local (sans spinner / sans bloquer l’UI):
        // permet de récupérer les images déjà disponibles localement (terrains/bureaux/etc.)
        // même si l’API favoris ne renvoie pas toujours les images.
        _enrichFavoritePropertiesFromCache(propertyCtrl);
      }

    } catch (e, st) {
      reportApiFailureToCrashlytics(
        'FavoritesPage',
        error: e,
        stackTrace: st,
        reason: 'load_favorites',
      );
      print("❌ Erreur lors du chargement des favoris: $e");
      // FancyNotification.show(context, "Erreur lors du chargement des favoris"); // Silent error
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingData = false;
          _isRefreshing = false;
        });
      }
    }
  }

  Future<void> _enrichFavoritePropertiesFromCache(PropertyFavoriteCtrl favCtrl) async {
    if (!mounted) return;
    final propertyCtrl = context.read<PropertyController>();

    // Ne pas bloquer l’UI: enrichissement en arrière-plan (par lots),
    // et un seul refresh UI à la fin.
    bool changed = false;

    // Limiter la charge CPU/IO: 4 enrichissements en parallèle max.
    const batchSize = 4;
    const priorityCount = 10;
    final candidates = favCtrl.propertyFavorites
        .where((fav) => fav.property != null)
        .where((fav) => fav.property!.propertyImage?.isNotEmpty != true)
        .where((fav) {
          final tid = fav.property!.propertyTypeId;
          // Ne pas fusionner le cache SQLite par id seul : collision possible avec funéraire/festif.
          if (tid == 6 || tid == 10 || tid == 11) return false;
          return true;
        })
        .toList();

    Future<bool> enrichOne(PropertyFavoriteModel fav) async {
      final p = fav.property;
      if (p == null) return false;
      final id = p.propertyId;
      if (id == null) return false;

      final cached = _imageEnrichCacheById[id];
      if (cached != null && cached.propertyImage?.isNotEmpty == true) {
        fav.property = cached;
        return true;
      }

      final inFlight = _imageEnrichInFlightById[id];
      if (inFlight != null) {
        try {
          final enriched = await inFlight;
          if (enriched.propertyImage?.isNotEmpty == true) {
            _imageEnrichCacheById[id] = enriched;
            fav.property = enriched;
            return true;
          }
        } catch (_) {}
        return false;
      }

      final fut = propertyCtrl.enrichPropertySnapshot(p);
      _imageEnrichInFlightById[id] = fut;
      try {
        final enriched = await fut;
        _imageEnrichInFlightById.remove(id);
        if (enriched.propertyImage?.isNotEmpty == true) {
          _imageEnrichCacheById[id] = enriched;
          fav.property = enriched;
          return true;
        }
      } catch (_) {
        _imageEnrichInFlightById.remove(id);
      }
      return false;
    }

    // 1) Priorité: premiers éléments visibles.
    final priority = candidates.take(priorityCount).toList();
    for (var i = 0; i < priority.length; i += batchSize) {
      if (!mounted) return;
      final batch = priority.skip(i).take(batchSize).toList();

      final futures = batch.map((fav) async {
        return enrichOne(fav);
      }).toList();

      final results = await Future.wait(futures);
      if (results.any((r) => r)) changed = true;

      // Laisser respirer l’UI.
      await Future<void>.delayed(Duration.zero);
    }

    // 2) Reste de la liste (arrière-plan).
    final rest = candidates.skip(priorityCount).toList();
    for (var i = 0; i < rest.length; i += batchSize) {
      if (!mounted) return;
      final batch = rest.skip(i).take(batchSize).toList();

      final futures = batch.map((fav) async => enrichOne(fav)).toList();
      final results = await Future.wait(futures);
      if (results.any((r) => r)) changed = true;
      await Future<void>.delayed(Duration.zero);
    }

    if (changed && mounted) setState(() {});
  }

  void _removeFavorite(int? propertyId, {int? propertyTypeId, bool isPrestation = false}) {
    if (propertyId == null) return;

    final authCtrl = context.read<AuthentificationCtrl>();
    final userId = authCtrl.user.userId?.toString();

    if (userId == null) {
      _showNotification(
        "Connectez-vous pour gérer vos favoris.",
        isError: true,
      );
      return;
    }

    final propertyCtrl = Provider.of<PropertyFavoriteCtrl>(context, listen: false);
    PropertyFavoriteModel? removedItem;
    int index = -1;

    // Trouver l'élément à supprimer
    for (int i = 0; i < propertyCtrl.propertyFavorites.length; i++) {
      final fav = propertyCtrl.propertyFavorites[i];
      if (isPrestation && fav.prestation?.id == propertyId) {
        removedItem = fav;
        index = i;
        break;
      } else if (!isPrestation && fav.property?.propertyId == propertyId) {
        removedItem = fav;
        index = i;
        break;
      }
    }

    // Suppression optimiste de l'interface
    if (index != -1) {
      setState(() {
        propertyCtrl.propertyFavorites.removeAt(index);
      });
    }

    // Exécution de l'appel API en arrière-plan
    _performBackgroundRemoval(userId, propertyId, propertyCtrl, propertyTypeId: propertyTypeId, isPrestation: isPrestation, removedItem: removedItem, index: index);
  }

  Future<void> _performBackgroundRemoval(String userId, int propertyId, PropertyFavoriteCtrl propertyCtrl, {int? propertyTypeId, bool isPrestation = false, PropertyFavoriteModel? removedItem, int? index}) async {
    try {
      final success = await propertyCtrl.removeFavorite(userId, propertyId.toString(), propertyTypeId: propertyTypeId, isPrestation: isPrestation);

      if (success) {
        final favoriteProvider = Provider.of<FavoriteProvider>(context, listen: false);
        favoriteProvider.syncFavorites(userId);
      } else if (removedItem != null && index != null) {
        reportApiFailureToCrashlytics(
          'FavoritesPage',
          reason: 'remove_favorite_failed',
        );
        // En cas d'échec non géré par le cache hors ligne, restaurer l'élément
        if (mounted) {
          setState(() {
            propertyCtrl.propertyFavorites.insert(index, removedItem);
          });
          _showNotification("Échec de la suppression", isError: true);
        }
      }
    } catch (e, st) {
      reportApiFailureToCrashlytics(
        'FavoritesPage',
        error: e,
        stackTrace: st,
        reason: 'remove_favorite_exception',
      );
      print("Erreur lors de la suppression en arrière-plan: $e");
      if (removedItem != null && index != null && mounted) {
        setState(() {
          propertyCtrl.propertyFavorites.insert(index, removedItem);
        });
      }
    }
  }

  void _showNotification(String message, {bool isError = false}) {
    FancyNotification.show(
      context,
      message,
      isError: isError,
    );
  }

  Future<void> _navigateToPropertyDetail(PropertyModel? property) async {
    if (property == null) return;
    final tid = property.propertyTypeId;
    final PropertyModel enriched;
    if (tid == 6 || tid == 10 || tid == 11) {
      enriched = property;
    } else {
      enriched = await context
          .read<PropertyController>()
          .enrichPropertySnapshot(property);
    }
    if (!mounted) return;

    if (tid == 6 || tid == 10 || tid == 11) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SiteDetailsPage(
            site: AgenceSiteModel.fromVacanceProperty(enriched),
          ),
        ),
      );
      return;
    }

    await navigateToPropertyDetail(context, enriched);
  }

  void _navigateToPrestationDetail(PrestationModel? prestation) {
    if (prestation == null) return;
    // Pré-charger depuis cache/API (non bloquant) pour récupérer les images portfolio
    // avant/pendant l'affichage du détail.
    final id = prestation.id;
    if (id != null) {
      // Fire-and-forget: ServiceDetailPage écoute déjà le controller.
      context.read<ServiceController>().getPrestationById(id);
    }
    Navigator.pushNamed(context, Routes.serviceDetail, arguments: prestation);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final propertyCtrl = Provider.of<PropertyFavoriteCtrl>(context);
    final authCtrl = Provider.of<AuthentificationCtrl>(context);

    // Si l'utilisateur n'est pas connecté
    if (!authCtrl.token.isNotEmpty) {
      return _buildNotConnectedView();
    }

    return Scaffold(
      backgroundColor: _lightGrey,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildFavoriteList(_filterFavorites(propertyCtrl.propertyFavorites, 'all')),
                _buildFavoriteList(_filterFavorites(propertyCtrl.propertyFavorites, 'available')),
                _buildFavoriteList(_filterFavorites(propertyCtrl.propertyFavorites, 'rent')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      automaticallyImplyLeading: false,
      elevation: 0,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_primaryColor, _secondaryColor],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.favorite_rounded, color: Colors.white, size: 18),
          ),
          SizedBox(width: 12),
          Text(
            'Mes favoris',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 18,
            ),
            textAlign: TextAlign.left,
          ),
        ],
      ),
      actions: [
        // Toggle vue liste/grille
        Tooltip(
          message: _isGridView ? 'Vue liste' : 'Vue grille',
          child: IconButton(
            icon: Icon(
              _isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
              color: Colors.white,
            ),
            onPressed: () {
              setState(() {
                _isGridView = !_isGridView;
              });
            },
          ),
        ),
        Tooltip(
          message: 'Actualiser',
          child: Stack(
            children: [
              IconButton(
                icon: Icon(_isRefreshing ? Icons.refresh : Icons.refresh, color: Colors.white),
                onPressed: _isRefreshing ? null : _loadFavorites,
              ),
              if (_isRefreshing)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Container(
          height: 1,
          color: Colors.white.withOpacity(0.2),
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    final propertyCtrl = Provider.of<PropertyFavoriteCtrl>(context, listen: false);
    final favorites = propertyCtrl.propertyFavorites;

    final allCount = _filterFavorites(favorites, 'all').length;
    final availableCount = _filterFavorites(favorites, 'available').length;
    final rentCount = _filterFavorites(favorites, 'rent').length;

    return Container(
      color: Colors.white,
      child: Column(
        children: [
          TabBar(
            controller: _tabController,
            labelColor: _primaryColor,
            unselectedLabelColor: _mediumGrey,
            indicatorColor: _primaryColor,
            indicatorWeight: 3,
            indicatorSize: TabBarIndicatorSize.tab,
            indicatorPadding: EdgeInsets.symmetric(horizontal: 10),
            labelStyle: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
            unselectedLabelStyle: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
            tabs: [
              Tab(
                text: 'Tous ($allCount)',
              ),
              Tab(
                text: 'Disponibles ($availableCount)',
              ),
              Tab(
                text: 'À louer ($rentCount)',
              ),
            ],
          ),
          // Indicateur de chargement pour les tabs
          if (_isLoadingData)
            LinearProgressIndicator(
              backgroundColor: _lightGrey,
              valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
              minHeight: 2,
            ),
        ],
      ),
    );
  }

  /// Tourisme / vacances / fiches liées agence : masqués provisoirement (cohérence navigation).
  bool _isHiddenTourismeOrAgenceFavorite(PropertyFavoriteModel fav) {
    if (fav.prestation != null) return false;
    final p = fav.property;
    if (p == null) return false;
    final tid = p.propertyTypeId ?? p.propertyType?.propertyTypeId;
    return tid == 6 || tid == 10 || tid == 11;
  }

  List<PropertyFavoriteModel> _filterFavorites(List<PropertyFavoriteModel> favorites, String filter) {
    final visible =
        favorites.where((f) => !_isHiddenTourismeOrAgenceFavorite(f)).toList();
    switch (filter) {
      case 'available':
        return visible.where((fav) {
          if (fav.prestation != null) return fav.prestation?.isActive ?? true;
          final p = fav.property;
          if (p == null) return false;
          return PropertyAvailabilityUi.isListingAvailableForVisit(
            sold: p.sold,
            available: p.available,
            listingAllowed: p.listingAllowed,
          );
        }).toList();
      case 'rent':
        return visible
            .where((fav) => fav.property?.transactionType == 'location')
            .toList();
      case 'all':
      default:
        return visible;
    }
  }

  Widget _buildFavoriteList(List<PropertyFavoriteModel> favorites) {
    return AnimatedSwitcher(
      duration: Duration(milliseconds: 300),
      transitionBuilder: (Widget child, Animation<double> animation) {
        return ScaleTransition(
          scale: animation,
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
      child: _isLoadingData
          ? _buildShimmerEffect()
          : favorites.isEmpty
          ? _buildEmptyState()
          : _buildFavoriteListContent(favorites),
    );
  }

  Widget _buildEmptyState() {
    final emptyMessages = [
      "Aucune propriété dans vos favoris",
      "Aucune propriété disponible dans vos favoris",
      "Aucune propriété à louer dans vos favoris"
    ];

    final emptyIcons = [
      Icons.favorite_border,
      Icons.check_circle_outline,
      Icons.home_work_outlined
    ];

    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: _lightGrey,
                shape: BoxShape.circle,
              ),
              child: Icon(
                emptyIcons[_tabController.index],
                size: 60,
                color: _mediumGrey.withOpacity(0.3),
              ),
            ),
            SizedBox(height: 20),
            Text(
              'Aucun favori',
              style: TextStyle(
                color: _mediumGrey,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 10),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                emptyMessages[_tabController.index],
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _mediumGrey.withOpacity(0.8),
                  fontSize: 14,
                ),
              ),
            ),

          ],
        ),
      ),
    );
  }

  Widget _buildFavoriteListContent(List<PropertyFavoriteModel> favorites) {
    return RefreshIndicator(
      color: _primaryColor,
      backgroundColor: AppColors.surfaceColor(context),
      onRefresh: _loadFavorites,
      child: _isGridView
          ? _buildFavoriteGridContent(favorites)
          : ListView.builder(
              padding: EdgeInsets.only(top: 20, left: 20, right: 20),
              itemCount: favorites.length,
              itemBuilder: (context, index) {
                final favorite = favorites[index];
                return AnimatedSwitcher(
                  duration: Duration(milliseconds: 300),
                  child: favorite.prestation != null 
                    ? _buildPrestationCard(favorite)
                    : _buildFavoriteCard(favorite),
                );
              },
            ),
    );
  }

  Widget _buildFavoriteGridContent(List<PropertyFavoriteModel> favorites) {
    return GridView.builder(
      padding: EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.75, // Ajusté pour éviter l'overflow
      ),
      itemCount: favorites.length,
      itemBuilder: (context, index) {
        final favorite = favorites[index];
        return AnimatedSwitcher(
          duration: Duration(milliseconds: 300),
          child: favorite.prestation != null 
            ? _buildPrestationGridCard(favorite)
            : _buildFavoriteGridCard(favorite),
        );
      },
    );
  }

  Widget _buildFavoriteGridCard(PropertyFavoriteModel favorite) {
    final propertyData = favorite.property;
    final isForRent = propertyData?.transactionType == 'location';
    final p = propertyData;
    final isDeleting = _deletingIds.contains(propertyData?.propertyId);

    final imageUrl = _stableImageUrlForProperty(propertyData);

    final typeName = propertyData?.propertyType?.name?.toLowerCase() ?? '';
    final tid = propertyData?.propertyTypeId ?? propertyData?.propertyType?.propertyTypeId ?? 0;
    final isHotel = tid == 5 || typeName.contains('hotel') || typeName.contains('hôtel');
    final isTerrain = tid == 9 || typeName.contains('terrain');
    final isFestive = tid == 8 || typeName.contains('fête') || typeName.contains('fete');
    final isFuneraire = tid == 7 || typeName.contains('funéra') || typeName.contains('funera');
    final showMonthly = isForRent && !isHotel && !isTerrain && !isFestive && !isFuneraire;

    final priceText = showMonthly
        ? '${propertyData?.price?.toStringAsFixed(0) ?? '0'} ${propertyData?.currency ?? '\$'}/mois'
        : '${propertyData?.price?.toStringAsFixed(0) ?? '0'} ${propertyData?.currency ?? '\$'}';

    final showPriceOnCard = !isHotel;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _navigateToPropertyDetail(propertyData),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: _cardBackground,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              spreadRadius: 1,
              offset: Offset(0, 4),
            )
          ],
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image
                Expanded(
                  flex: 3,
                  child: Stack(
                    children: [
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                          color: _lightGrey,
                        ),
                        child: imageUrl != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                                child: CachedNetworkImage(
                                  imageUrl: imageUrl,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: double.infinity,
                                  placeholder: (context, url) => Container(
                                    color: _lightGrey,
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: _primaryColor,
                                      ),
                                    ),
                                  ),
                                  errorWidget: (context, url, error) => Container(
                                    color: _lightGrey,
                                    child: Icon(Icons.home, size: 30, color: _mediumGrey),
                                  ),
                                ),
                              )
                            : Container(
                                color: _lightGrey,
                                child: Icon(Icons.home, size: 30, color: _mediumGrey),
                              ),
                      ),
                      Positioned(
                        bottom: 8,
                        left: 8,
                        child: p != null
                            ? PropertyListingStatusChip(
                                sold: p.sold,
                                transactionType: p.transactionType,
                                available: p.available,
                                listingAllowed: p.listingAllowed,
                                onDarkBackground: true,
                              )
                            : const SizedBox.shrink(),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 4,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                          child: FavoriteHeartIcon(
                            propertyId: propertyData!.propertyId.toString(),
                            propertyTypeId: propertyData.propertyTypeId,
                            size: 16,
                            splashRadius: 16,
                            activeColor: Colors.red,
                            inactiveColor: _mediumGrey,
                            onLikeChanged: (isLiked) {
                              // Désormais géré automatiquement par PropertyFavoriteCtrl
                            },
                          ),
                        ),
                      ),
                      if (showPriceOnCard)
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              priceText,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // Contenu
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          propertyData?.title ?? 'Propriété',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: _darkColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.location_on_rounded, size: 12, color: _mediumGrey),
                            SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                "${propertyData?.cityValue}, ${propertyData?.communeValue}",
                                style: TextStyle(
                                  fontSize: 11,
                                  color: _mediumGrey,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 4),
                        Row(
                          children: [
                            if (propertyData?.bedrooms != null && propertyData!.bedrooms! > 0) ...[
                              Icon(Icons.bed_rounded, size: 12, color: _mediumGrey),
                              SizedBox(width: 4),
                              Text(
                                '${propertyData.bedrooms}',
                                style: TextStyle(fontSize: 11, color: _mediumGrey),
                              ),
                              SizedBox(width: 8),
                            ],
                            if (propertyData?.bathroom != null && propertyData!.bathroom! > 0) ...[
                              Icon(Icons.bathtub_rounded, size: 12, color: _mediumGrey),
                              SizedBox(width: 4),
                              Text(
                                '${propertyData.bathroom}',
                                style: TextStyle(fontSize: 11, color: _mediumGrey),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (isDeleting)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                    ),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                            )
                          ],
                        ),
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: _primaryColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

          ],
        ),
      ),
    );
  }

  Widget _buildFavoriteCard(PropertyFavoriteModel favorite) {
    final propertyData = favorite.property;
    if (propertyData == null) return const SizedBox();
    
    final isForRent = propertyData.transactionType == 'location';
    final isDeleting = _deletingIds.contains(propertyData.propertyId);

    final imageUrl = _stableImageUrlForProperty(propertyData);

    final typeName = propertyData.propertyType?.name?.toLowerCase() ?? '';
    final tid = propertyData.propertyTypeId ?? propertyData.propertyType?.propertyTypeId ?? 0;
    final isHotel = tid == 5 || typeName.contains('hotel') || typeName.contains('hôtel');
    final isTerrain = tid == 9 || typeName.contains('terrain');
    final isFestive = tid == 8 || typeName.contains('fête') || typeName.contains('fete');
    final isFuneraire = tid == 7 || typeName.contains('funéra') || typeName.contains('funera');
    final showMonthly = isForRent && !isHotel && !isTerrain && !isFestive && !isFuneraire;

    final priceText = showMonthly
        ? '${propertyData.price?.toStringAsFixed(0) ?? '0'} ${propertyData.currency ?? '\$'}/mois'
        : '${propertyData.price?.toStringAsFixed(0) ?? '0'} ${propertyData.currency ?? '\$'}';

    final showPriceOnCard = !isHotel;

    final cardContent = InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => _navigateToPropertyDetail(propertyData),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: _cardBackground,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              spreadRadius: 1,
              offset: const Offset(0, 10),
            )
          ],
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    Container(
                      height: 180,
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                        color: _lightGrey,
                      ),
                      child: imageUrl != null && imageUrl.isNotEmpty
                          ? ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                              child: CachedNetworkImage(
                                imageUrl: imageUrl,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                placeholder: (context, url) => Container(
                                  color: _lightGrey,
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  color: _lightGrey,
                                  child: const Center(
                                    child: Icon(Icons.home, size: 50, color: Colors.grey),
                                  ),
                                ),
                              ),
                            )
                          : Container(
                              color: _lightGrey,
                              child: const Center(
                                child: Icon(Icons.home, size: 50, color: Colors.grey),
                              ),
                            ),
                    ),
                    Positioned(
                      bottom: 15,
                      left: 15,
                      child: PropertyListingStatusChip(
                        sold: propertyData.sold,
                        transactionType: propertyData.transactionType,
                        available: propertyData.available,
                        listingAllowed: propertyData.listingAllowed,
                        onDarkBackground: true,
                      ),
                    ),
                    Positioned(
                      top: 15,
                      right: 15,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (showPriceOnCard) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.7),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                priceText,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.9),
                              shape: BoxShape.circle,
                            ),
                            child: FavoriteHeartIcon(
                              propertyId: propertyData.propertyId.toString(),
                              propertyTypeId: propertyData.propertyTypeId,
                              size: 20,
                              onLikeChanged: (isLiked) {
                                // Déjà géré par FavoriteProvider dans l'icône
                                // Pas de call à _removeFavorite ici pour éviter le double appel
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        propertyData.title ?? 'Propriété',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: _darkColor,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.location_on_outlined, size: 16, color: _mediumGrey),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              "${propertyData.cityValue}, ${propertyData.communeValue}",
                              style: TextStyle(color: _mediumGrey, fontSize: 14),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _buildFeatureChips(propertyData),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (isDeleting)
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                  child: Container(
                    color: Colors.white.withOpacity(0.2),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                            )
                          ],
                        ),
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: _primaryColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: cardContent,
    );
  }

  Widget _buildPrestationCard(PropertyFavoriteModel favorite) {
    final prestation = favorite.prestation;
    if (prestation == null) return const SizedBox();
    
    final imageUrl = prestation.profile;
    final priceText = "${prestation.minPrice?.toStringAsFixed(0) ?? '0'} ${prestation.currency}";
    final isDeleting = _deletingIds.contains(prestation.id);

    final cardContent = InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => _navigateToPrestationDetail(prestation),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: _cardBackground,
          boxShadow: [
             BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              spreadRadius: 1,
              offset: const Offset(0, 10),
            )
          ],
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    Container(
                      height: 180,
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                        color: _lightGrey,
                      ),
                      child: imageUrl != null && imageUrl.isNotEmpty
                          ? ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                        child: CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          placeholder: (context, url) => Container(
                            color: _lightGrey,
                            child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: _lightGrey,
                            child: const Center(child: Icon(Icons.person, size: 50, color: Colors.grey)),
                          ),
                        ),
                      )
                          : Container(
                        color: _lightGrey,
                        child: const Center(child: Icon(Icons.person, size: 50, color: Colors.grey)),
                      ),
                    ),
                    Positioned(
                      top: 15,
                      right: 15,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              priceText,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.9),
                              shape: BoxShape.circle,
                            ),
                            child: FavoriteHeartIcon(
                              propertyId: prestation.id.toString(),
                              isPrestation: true,
                              size: 20,
                              onLikeChanged: (isLiked) {
                                // Déjà géré par FavoriteProvider dans l'icône
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        prestation.title ?? 'Service',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: _darkColor),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.location_on_outlined, size: 16, color: _mediumGrey),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              "${prestation.cityValue}, ${prestation.communeValue}",
                              style: TextStyle(color: _mediumGrey, fontSize: 14),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _buildPrestationFeatureChips(prestation),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (isDeleting)
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                  child: Container(
                    color: Colors.white.withOpacity(0.2),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                            )
                          ],
                        ),
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: _primaryColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: cardContent,
    );
  }

  Widget _buildPrestationGridCard(PropertyFavoriteModel favorite) {
    final prestation = favorite.prestation;
    if (prestation == null) return const SizedBox();
    
    final imageUrl = prestation.profile;
    final priceText = "${prestation.minPrice?.toStringAsFixed(0) ?? '0'} ${prestation.currency}";
    final isDeleting = _deletingIds.contains(prestation.id);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _navigateToPrestationDetail(prestation),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: _cardBackground,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              spreadRadius: 1,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Stack(
                    children: [
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                          color: _lightGrey,
                        ),
                        child: imageUrl != null && imageUrl.isNotEmpty
                            ? ClipRRect(
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                child: CachedNetworkImage(
                                  imageUrl: imageUrl,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                  errorWidget: (context, url, error) => const Icon(Icons.person, size: 30, color: Colors.grey),
                                ),
                              )
                            : const Center(child: Icon(Icons.person, size: 30, color: Colors.grey)),
                      ),
                      Positioned(
                        bottom: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: (prestation.isActive ?? true) ? _successColor.withOpacity(0.9) : _errorColor.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            (prestation.isActive ?? true) ? 'Disponible' : 'Indisponible',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            shape: BoxShape.circle,
                          ),
                          child: FavoriteHeartIcon(
                            propertyId: prestation.id.toString(),
                            isPrestation: true,
                            size: 16,
                            onLikeChanged: (isLiked) {
                              // Déjà géré par FavoriteProvider dans l'icône
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          prestation.title ?? 'Service',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _darkColor),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          priceText,
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: _primaryColor),
                        ),
                        Row(
                          children: [
                            Icon(Icons.location_on_rounded, size: 12, color: _mediumGrey),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                "${prestation.cityValue}",
                                style: TextStyle(fontSize: 11, color: _mediumGrey),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (isDeleting)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                    ),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                            )
                          ],
                        ),
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: _primaryColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildPrestationFeatureChips(PrestationModel prestation) {
    final features = <Widget>[];
    if (prestation.experience != null && prestation.experience!.isNotEmpty) {
      features.add(_buildFeatureChip('${prestation.experience} ans exp.'));
    }
    if (prestation.isCertified ?? false) {
      features.add(_buildFeatureChip('Certifié'));
    }
    return features;
  }

  List<Widget> _buildFeatureChips(PropertyModel? propertyData) {
    final features = <Widget>[];

    final typeName = propertyData?.propertyType?.name?.toLowerCase() ?? '';
    final tid = propertyData?.propertyTypeId ?? propertyData?.propertyType?.propertyTypeId ?? 0;
    final isHotel = tid == 5 || typeName.contains('hotel') || typeName.contains('hôtel');
    final isTerrain = tid == 9 || typeName.contains('terrain');
    final isFestive = tid == 8 || typeName.contains('fête') || typeName.contains('fete');
    final isFuneraire = tid == 7 || typeName.contains('funéra') || typeName.contains('funera');
    final isBureau = tid == 6 || typeName.contains('bureau');

    if (isTerrain) {
      if (propertyData?.surface != null) {
        features.add(_buildFeatureChip('${propertyData!.surface}m²'));
      }
      return features;
    }

    if (isHotel) {
      if (propertyData?.rooms != null && (propertyData!.rooms ?? 0) > 0) {
        features.add(_buildFeatureChip('${propertyData.rooms} chambres'));
      } else if (propertyData?.bedrooms != null && (propertyData!.bedrooms ?? 0) > 0) {
        features.add(_buildFeatureChip('${propertyData.bedrooms} chambres'));
      }
      if (propertyData?.surface != null) {
        features.add(_buildFeatureChip('${propertyData!.surface}m²'));
      }
      return features;
    }

    if (isFestive || isFuneraire) {
      if (propertyData?.surface != null) {
        features.add(_buildFeatureChip('${propertyData!.surface}m²'));
      }
      final cap = propertyData?.capacityPeople;
      if (cap != null && cap > 0) {
        features.add(_buildFeatureChip('$cap pers.'));
      }
      return features;
    }

    if (isBureau) {
      if (propertyData?.surface != null) {
        features.add(_buildFeatureChip('${propertyData!.surface}m²'));
      }
      final meet = propertyData?.roomMeet;
      if (meet != null && meet > 0) {
        features.add(_buildFeatureChip('$meet salle(s)'));
      }
      final equip = propertyData?.isEquip;
      if (equip != null && equip.toString().toLowerCase() == 'oui') {
        features.add(_buildFeatureChip('Équipé'));
      }
      return features;
    }

    if (propertyData?.bedrooms != null && (propertyData!.bedrooms ?? 0) > 0) {
      features.add(_buildFeatureChip('${propertyData.bedrooms} chambres'));
    }
    if (propertyData?.bathroom != null && (propertyData!.bathroom ?? 0) > 0) {
      features.add(_buildFeatureChip('${propertyData.bathroom} sdb'));
    }
    if (propertyData?.surface != null) {
      features.add(_buildFeatureChip('${propertyData!.surface}m²'));
    }
    if (propertyData?.rooms != null && (propertyData!.rooms ?? 0) > 0) {
      features.add(_buildFeatureChip('${propertyData.rooms} pièces'));
    }

    return features;
  }

  Widget _buildFeatureChip(String text) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _chipBackground,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: _darkColor,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  // Vue quand l'utilisateur n'est pas connecté
  Widget _buildNotConnectedView() {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor(context),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_primaryColor, _secondaryColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: Text(
          'Mes favoris',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  color: _primaryColor.withOpacity(0.05),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.favorite_outline_rounded,
                  size: 70,
                  color: _primaryColor,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Connectez-vous',
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: _darkColor,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Connectez-vous pour enregistrer vos propriétés préférées et les retrouver facilement.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: _mediumGrey,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pushNamed(context, Routes.loginRoute),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                    shadowColor: _primaryColor.withOpacity(0.3),
                  ),
                  child: Text(
                    'SE CONNECTER',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}