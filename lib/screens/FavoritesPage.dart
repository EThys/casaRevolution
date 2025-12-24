import 'package:cached_network_image/cached_network_image.dart';
import 'package:casa/controllers/PropertyFavoriteCtrl.dart';
import 'package:casa/controllers/provider/FavoriteProvider.dart';
import 'package:casa/models/PropertyFavoriteModel.dart';
import 'package:casa/models/PropertyModel.dart';
import 'package:casa/utils/Constantes.dart';
import 'package:casa/utils/FancyNotification.dart';
import 'package:casa/utils/StockageKeys.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../controllers/AuthentificationCtrl.dart';
import '../utils/Routes.dart';
import '../utils/FavoriteEartIcon.dart';

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
  bool _isGridView = false; // Toggle pour vue liste/grille

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadFavorites();
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
      }

    } catch (e) {
      print("❌ Erreur lors du chargement des favoris: $e");
      FancyNotification.show(context, "Erreur lors du chargement des favoris");
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingData = false;
          _isRefreshing = false;
        });
      }
    }
  }

  Future<void> _removeFavorite(int? propertyId) async {
    if (propertyId == null) return;

    final authCtrl = context.read<AuthentificationCtrl>();
    final userId = authCtrl.user.userId?.toString();

    if (userId == null) {
      _showNotification("Erreur: Utilisateur non connecté", isError: true);
      return;
    }

    setState(() {
      _deletingIds.add(propertyId);
    });

    try {
      final propertyCtrl = Provider.of<PropertyFavoriteCtrl>(context, listen: false);
      final success = await propertyCtrl.removeFavorite(userId, propertyId.toString());

      if (success) {
        final favoriteProvider = Provider.of<FavoriteProvider>(context, listen: false);
        await favoriteProvider.syncFavorites(userId);

        await Future.delayed(Duration(milliseconds: 300));
        _showNotification("Supprimé des favoris", isError: false);

        // Recharger les données
        await _loadFavorites();
      }
    } catch (e) {
      _showNotification("Échec de la suppression", isError: true);
      print("Erreur lors de la suppression: $e");
    } finally {
      if (mounted) {
        setState(() {
          _deletingIds.remove(propertyId);
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

  List<PropertyFavoriteModel> _filterFavorites(List<PropertyFavoriteModel> favorites, String filter) {
    switch (filter) {
      case 'available':
        return favorites.where((fav) => !(fav.property?.sold ?? true)).toList();
      case 'rent':
        return favorites.where((fav) => fav.property?.transactionType == 'location').toList();
      case 'all':
      default:
        return favorites;
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
      backgroundColor: Colors.white,
      onRefresh: _loadFavorites,
      child: _isGridView
          ? _buildFavoriteGridContent(favorites)
          : ListView.separated(
              padding: EdgeInsets.all(20),
              itemCount: favorites.length,
              separatorBuilder: (_, __) => SizedBox(height: 20),
              itemBuilder: (context, index) {
                final favorite = favorites[index];
                return AnimatedSwitcher(
                  duration: Duration(milliseconds: 300),
                  child: _buildFavoriteCard(favorite),
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
          child: _buildFavoriteGridCard(favorite),
        );
      },
    );
  }

  Widget _buildFavoriteGridCard(PropertyFavoriteModel favorite) {
    final propertyData = favorite.property;
    final isForRent = propertyData?.transactionType == 'location';
    final isAvailable = !(propertyData?.sold ?? true);
    final isDeleting = _deletingIds.contains(propertyData?.propertyId);

    final firstImage = propertyData?.propertyImage?.isNotEmpty ?? false
        ? propertyData?.propertyImage?.first
        : null;
    final imageUrl = firstImage?.path;

    final priceText = isForRent
        ? '${propertyData?.price?.toStringAsFixed(0) ?? '0'}\$/mois'
        : '${propertyData?.price?.toStringAsFixed(0) ?? '0'}\$';

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.pushNamed(context, Routes.detailPageRoute, arguments: propertyData);
      },
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
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isAvailable ? _successColor.withOpacity(0.9) : _errorColor.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isAvailable ? 'Disponible' : 'Vendu',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
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
                                propertyData?.address ?? 'Adresse non renseignée',
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
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.black.withOpacity(0.5),
                ),
                child: Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFavoriteCard(PropertyFavoriteModel favorite) {
    final propertyData = favorite.property;
    final isForRent = propertyData?.transactionType == 'location';
    final isAvailable = !(propertyData?.sold ?? true);
    final isDeleting = _deletingIds.contains(propertyData?.propertyId);

    final firstImage = propertyData?.propertyImage?.isNotEmpty ?? false
        ? propertyData?.propertyImage?.first
        : null;
    final imageUrl = firstImage?.path;

    final priceText = isForRent
        ? '${propertyData?.price?.toStringAsFixed(0) ?? '0'}\$/mois'
        : '${propertyData?.price?.toStringAsFixed(0) ?? '0'}\$';

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        Navigator.pushNamed(context, Routes.detailPageRoute, arguments: propertyData);
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: _cardBackground,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              spreadRadius: 1,
              offset: Offset(0, 10),
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
                        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                        color: _lightGrey,
                      ),
                      child: imageUrl != null
                          ? ClipRRect(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                        child: CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          placeholder: (context, url) => Container(
                            color: _lightGrey,
                            child: Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: _primaryColor,
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) {
                            return Container(
                              color: _lightGrey,
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.home, size: 50, color: _mediumGrey),
                                    SizedBox(height: 8),
                                    Text(
                                      'Image non disponible',
                                      style: TextStyle(
                                        color: _mediumGrey,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      )
                          : Container(
                        color: _lightGrey,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.home, size: 50, color: _mediumGrey),
                              SizedBox(height: 8),
                              Text(
                                'Aucune image',
                                style: TextStyle(
                                  color: _mediumGrey,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 15,
                      left: 15,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isAvailable ? _successColor.withOpacity(0.9) : _errorColor.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          isAvailable ? 'Disponible' : 'Indisponible',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 15,
                      right: 15,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              priceText,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          SizedBox(width: 8),
                          if (propertyData?.propertyId != null)
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.9),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: FavoriteHeartIcon(
                                propertyId: propertyData!.propertyId.toString(),
                                size: 20,
                                splashRadius: 18,
                                activeColor: Colors.red,
                                inactiveColor: _mediumGrey,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "${propertyData?.title ?? 'Propriété sans titre'}",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: _darkColor,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 16,
                            color: _mediumGrey,
                          ),
                          SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              "${propertyData?.address ?? 'Adresse non disponible'}",
                              style: TextStyle(
                                color: _mediumGrey,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 15),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _buildFeatureChips(propertyData),
                      ),
                      SizedBox(height: 15),
                      Divider(height: 1, color: _lightGrey),
                      SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.favorite, size: 16, color: _primaryColor),
                          SizedBox(width: 6),
                          Text(
                            'Ajouté le ${_dateFormat.format(DateTime.now())}',
                            style: TextStyle(
                              color: _mediumGrey,
                              fontSize: 12,
                            ),
                          ),
                          Spacer(),
                          if (isDeleting)
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: _errorColor,
                              ),
                            )
                          else
                            InkWell(
                              onTap: () {
                                if (propertyData?.propertyId != null) {
                                  _removeFavorite(propertyData!.propertyId!);
                                }
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _errorColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: _errorColor.withOpacity(0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.delete_outline,
                                      size: 16,
                                      color: _errorColor,
                                    ),
                                    SizedBox(width: 5),
                                    Text(
                                      'Supprimer',
                                      style: TextStyle(
                                        color: _errorColor,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
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
            if (isDeleting)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildFeatureChips(PropertyModel? propertyData) {
    final features = <Widget>[];

    if (propertyData?.bedrooms != null) {
      features.add(_buildFeatureChip('${propertyData!.bedrooms} chambres'));
    }
    if (propertyData?.bathroom != null) {
      features.add(_buildFeatureChip('${propertyData!.bathroom} sdb'));
    }
    if (propertyData?.surface != null) {
      features.add(_buildFeatureChip('${propertyData!.surface}m²'));
    }
    if (propertyData?.rooms != null) {
      features.add(_buildFeatureChip('${propertyData!.rooms} pièces'));
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
      backgroundColor: _lightGrey,
      appBar: AppBar(
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
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Mes favoris',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(32),
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
                child: Icon(Icons.favorite_border, size: 60, color: _mediumGrey.withOpacity(0.3)),
              ),
              SizedBox(height: 24),
              Text(
                'Connexion Requise',
                style: TextStyle(
                  color: _darkColor,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 12),
              Text(
                'Connectez-vous pour accéder à vos propriétés favorites',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _mediumGrey,
                  fontSize: 16,
                ),
              ),
              SizedBox(height: 32),
              Container(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushNamed(context, Routes.loginRoute);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(
                    'SE CONNECTER',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
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