import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:casa/controllers/PropertyCtrl.dart';
import 'package:casa/utils/Constantes.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:shimmer/shimmer.dart';

import '../models/PropertyModel.dart';
import '../utils/FancyNotification.dart';
import '../utils/FavoriteEartIcon.dart';
import '../utils/property_detail_navigation.dart';
import '../controllers/AuthentificationCtrl.dart';
import '../controllers/provider/FavoriteProvider.dart';
import '../controllers/AgenceController.dart';
import '../models/AgenceModel.dart';
import 'AgenceDetailsPage.dart';
import 'package:casa/widgets/property_sold_badge.dart';

class CategoryPropertiesPage extends StatefulWidget {
  final String category;

  const CategoryPropertiesPage({Key? key, required this.category}) : super(key: key);

  @override
  _CategoryPropertiesPageState createState() => _CategoryPropertiesPageState();
}

class _CategoryPropertiesPageState extends State<CategoryPropertiesPage> {
  final Color _primaryColor = Color(0xFF1976D2);
  final Color _secondaryColor = Color(0xFF64B5F6);
  final Color _darkColor = Color(0xFF1A1D26);
  final Color _lightColor = Color(0xFFF5F6FA);
  final Color _greyColor = Color(0xFF7F8C8D);

  bool _isGridView = true;
  String _selectedFilter = 'Tous';
  final List<String> _filters = ['Tous', 'Location', 'Vente', 'Populaires', 'Nouveautés'];
  final RefreshController _refreshController = RefreshController();
  
  int _visibleCount = 15;
  final int _pageSize = 15;
  bool _isLoadingMore = false;
  
  final Map<String, int> _categoryToId = {
    'Maison': 3,
    'Appartement': 2,
    'Studio': 1,
    'Bureau': 4,
    'Terrain': 9,
    'Hotels': 5,
    'Salle de fête': 8,
    'Salle funéraires': 7,
  };

  @override
  void initState() {
    super.initState();
    if (widget.category == 'Vacances') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Provider.of<AgenceController>(context, listen: false).fetchAgences();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final propertyCtrl = context.watch<PropertyController>();
    
    // Pour les catégories spéciales → liste dédiée uniquement (IDs indépendants par endpoint)
    // Pour les autres → propriétés standard uniquement
    // IMPORTANT: On ne mélange PAS les listes car les IDs ne sont pas globaux
    List<PropertyModel> allRelevantProperties;

    if (widget.category == 'Bureau') {
      allRelevantProperties = List.from(propertyCtrl.bureaux);
    } else if (widget.category == 'Salle de fête') {
      allRelevantProperties = List.from(propertyCtrl.festives);
    } else if (widget.category == 'Salle funéraires') {
      allRelevantProperties = List.from(propertyCtrl.funeraires);
    } else if (widget.category == 'Terrain') {
      allRelevantProperties = List.from(propertyCtrl.terrainProperties);
    } else if (widget.category == 'Hotels') {
      allRelevantProperties = List.from(propertyCtrl.hotels);
    } else {
      allRelevantProperties = List.from(propertyCtrl.properties);
    }

    allRelevantProperties =
        allRelevantProperties.where((p) => p.listingAllowed).toList();

    if (widget.category == 'Terrain') {
      print("🏞️ [CategoryPropertiesPage] ${propertyCtrl.terrains.length} terrains disponibles");
    }

    final properties = allRelevantProperties.where((p) =>
        _matchesCategory(p, widget.category)).toList();

    final filteredProperties = _applyFilter(properties, _selectedFilter);

    // Combine agencies and properties if category is Vacances
    final List<dynamic> displayItems = [];
    if (widget.category == 'Vacances') {
      final agenceCtrl = context.watch<AgenceController>();
      displayItems.addAll(agenceCtrl.agences);
    }
    displayItems.addAll(filteredProperties);

    // DEBUG: Afficher les propriétés filtrées avec le filtre actif
    print("🔍 [CategoryPropertiesPage] Build - Filtre actif: $_selectedFilter");
    print("📊 [CategoryPropertiesPage] Items: ${displayItems.length} (Propriétés: ${properties.length})");

    return Scaffold(
      backgroundColor: _lightColor,
      appBar: _buildAppBar(),
      body: SmartRefresher(
        controller: _refreshController,
        enablePullDown: true,
        enablePullUp: true,
        header: WaterDropMaterialHeader(
          backgroundColor: _primaryColor,
          color: Colors.white,
        ),
        footer: ClassicFooter(
          loadingText: "Chargement de la suite...",
          noDataText: "Toutes les propriétés sont affichées",
          canLoadingText: "Relâchez pour charger plus",
          idleText: "Scrollez pour voir plus",
          loadingIcon: SizedBox(
            width: 25,
            height: 25,
            child: CircularProgressIndicator(strokeWidth: 2, color: _primaryColor),
          ),
        ),
        onRefresh: () async {
          setState(() => _visibleCount = _pageSize);
          await _handlePullToRefresh(propertyCtrl);
        },
        onLoading: () async {
          await _loadMore(propertyCtrl);
        },
        child: Column(
          children: [
            _buildFilterChips(),

            // Indicateur de synchronisation discret
            if (propertyCtrl.syncing)
              _buildMinimalSyncIndicator(),

            Expanded(
              child: propertyCtrl.loading
                  ? _buildShimmerLoading()
                  : displayItems.isEmpty
                  ? _buildEmptyState()
                  : _buildPropertyListOrGrid(displayItems),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMinimalSyncIndicator() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: EdgeInsets.all(8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
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

  Future<void> _loadMore(PropertyController propertyCtrl) async {
    if (_isLoadingMore) return;

    // 1. Calculer le pool de données actuel
    List<PropertyModel> allRelevantProperties;
    if (widget.category == 'Bureau') {
      allRelevantProperties = propertyCtrl.bureaux;
    } else if (widget.category == 'Salle de fête') {
      allRelevantProperties = propertyCtrl.festives;
    } else if (widget.category == 'Salle funéraires') {
      allRelevantProperties = propertyCtrl.funeraires;
    } else if (widget.category == 'Terrain') {
      allRelevantProperties = propertyCtrl.terrainProperties;
    } else {
      allRelevantProperties = propertyCtrl.properties;
    }

    allRelevantProperties =
        allRelevantProperties.where((p) => p.listingAllowed).toList();

    final filtered = allRelevantProperties.where((p) => _matchesCategory(p, widget.category)).toList();
    final totalLoaded = filtered.length;

    // 2. Si on a encore des éléments non affichés localement, les révéler
    if (_visibleCount < totalLoaded) {
      setState(() => _isLoadingMore = true);
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) {
        setState(() {
          _visibleCount = (_visibleCount + _pageSize).clamp(0, totalLoaded);
          _isLoadingMore = false;
        });
        _refreshController.loadComplete();
      }
      return;
    }

    // 3. Sinon, si l'API a encore des données (Infinity Scroll réel)
    if (propertyCtrl.hasMoreData) {
      setState(() => _isLoadingMore = true);
      
      // Mapper la catégorie vers un type pour l'API
      int? typeId = _categoryToId[widget.category];
      
      // Déterminer le type de transaction basé sur le filtre (optionnel)
      bool? isSold;
      if (_selectedFilter == 'Location' || _selectedFilter == 'Vente') {
          // Note: filterProperties handles typeMaison. Transaction type is more complex.
      }

      await propertyCtrl.filterProperties(
        typeMaison: typeId,
        isLoadMore: true,
        sortBy: 'id',
        sortOrder: 'desc',
      );

      if (mounted) {
        setState(() {
          _visibleCount = (_visibleCount + _pageSize);
          _isLoadingMore = false;
        });
        _refreshController.loadComplete();
      }
    } else {
      _refreshController.loadNoData();
    }
  }

  Future<void> _handlePullToRefresh(PropertyController propertyCtrl) async {
    // Sauvegarder le filtre actuel avant le refresh
    final currentFilter = _selectedFilter;
    print("🔄 [CategoryPropertiesPage] Début du refresh - Filtre actuel: $currentFilter");
    
    try {
      // Sync Favorites
      if (mounted) {
        final authCtrl = Provider.of<AuthentificationCtrl>(context, listen: false);
        final favProvider = Provider.of<FavoriteProvider>(context, listen: false);
        if (authCtrl.token.isNotEmpty && authCtrl.user.userId != null) {
          favProvider.syncFavorites(authCtrl.user.userId.toString());
        }
      }

      await propertyCtrl.refreshProperties();
      await propertyCtrl.syncAllSpecialCategories();
      
      if (widget.category == 'Vacances' && mounted) {
        await Provider.of<AgenceController>(context, listen: false).fetchAgences();
      }

      _refreshController.refreshCompleted();
      
      // Vérifier que le filtre est toujours le même après le refresh
      if (_selectedFilter != currentFilter) {
        print("⚠️ [CategoryPropertiesPage] Le filtre a changé! Avant: $currentFilter, Après: $_selectedFilter");
      }
      // Suppression du snackbar de succès demandé par l'utilisateur
    } catch (e) {
      print("❌ Erreur refresh: $e");
      _refreshController.refreshFailed();
      // On garde le snackbar d'erreur pour informer l'utilisateur d'un problème réel
      SnackbarForCasa.error(context, "Erreur de connexion");
    }
  }

  bool _matchesCategory(PropertyModel property, String category) {
    if (category == 'Tous') return true;
    if (property.title?.toLowerCase() == 'string') return false;

    // Récupérer l'ID du type de propriété
    final propertyTypeId = property.propertyType?.propertyTypeId?.toString();
    // Ne pas retourner faux ici car les propriétés spéciales n'ont pas forcément de typeId dans le JSON
    // if (propertyTypeId == null) return false; 


    final categoryMap = {
      'Studio': ['1'],
      'Apparts': ['2'],
      'Maisons': ['3'],
      'Bureau': ['4'],
      'Hotels': ['5'],
      'Vacances': ['6'],
      'Salle funéraires': ['7'],
      'Salle de fête': ['8'],
      'Terrain': ['9'],
      'Entrepôt': ['10'],
    };

    // Vérifier aussi le nom du type de propriété pour plus de fiabilité
    final propertyTypeName = property.propertyType?.name?.toLowerCase() ?? '';

    bool matchesById = categoryMap[category]?.contains(propertyTypeId) ?? false;
    bool matchesByName = _matchesCategoryByName(propertyTypeName, category);
    
    // Cas spécial: si la propriété est dans une liste spécialisée du controlleur
    final propertyCtrl = Provider.of<PropertyController>(context, listen: false);
    bool isInSpecialList = false;
    if (category == 'Bureau') isInSpecialList = propertyCtrl.bureaux.any((b) => b.propertyId == property.propertyId);
    if (category == 'Salle de fête') isInSpecialList = propertyCtrl.festives.any((f) => f.propertyId == property.propertyId);
    if (category == 'Salle funéraires') isInSpecialList = propertyCtrl.funeraires.any((f) => f.propertyId == property.propertyId);

    print("Property: ${property.title}, TypeID: $propertyTypeId, TypeName: $propertyTypeName, MatchesById: $matchesById, MatchesByName: $matchesByName, Special: $isInSpecialList");

    return matchesById || matchesByName || isInSpecialList;
  }

  bool _matchesCategoryByName(String propertyTypeName, String category) {
    switch (category) {
      case 'Apparts':
        return propertyTypeName.contains('appart') ||
            propertyTypeName.contains('apart') ||
            propertyTypeName.contains('studio') && !propertyTypeName.contains('studio seul');
      case 'Maisons':
        return propertyTypeName.contains('maison') ||
            propertyTypeName.contains('house') ||
            propertyTypeName.contains('villa');
      case 'Studio':
        return propertyTypeName.contains('studio') ||
            propertyTypeName.contains('studio seul') ||
            propertyTypeName.contains('studette');
      case 'Bureau':
        return propertyTypeName.contains('bureau') ||
            propertyTypeName.contains('office') ||
            propertyTypeName.contains('commercial');
      case 'Hotels':
        return propertyTypeName.contains('hotel') ||
            propertyTypeName.contains('hotel') ||
            propertyTypeName.contains('resort');
      case 'Vacances':
        return propertyTypeName.contains('vacance') ||
            propertyTypeName.contains('holiday') ||
            propertyTypeName.contains('location saisonnière');
      case 'Salle funéraires':
        return propertyTypeName.contains('funérair') || propertyTypeName.contains('morgue');
      case 'Salle de fête':
        return propertyTypeName.contains('fête') || propertyTypeName.contains('salle de fête');
      case 'Terrain':
        return propertyTypeName.contains('terrain') || propertyTypeName.contains('parcelle');
      case 'Entrepôt':
        return propertyTypeName.contains('entrepôt') || propertyTypeName.contains('depot');
      default:
        return false;
    }
  }

  List<PropertyModel> _applyFilter(List<PropertyModel> properties, String filter) {
    switch (filter) {
      case 'Location':
        return properties.where((p) => p.transactionType?.toLowerCase().contains('location') ?? false).toList();
      case 'Vente':
        return properties.where((p) => p.transactionType?.toLowerCase().contains('vente') ?? false).toList();
      case 'Nouveautés':
        return properties..sort((a, b) => (b.propertyId ?? 0).compareTo(a.propertyId ?? 0));
      default:
        return properties;
    }
  }

  PreferredSizeWidget _buildAppBar() {
    final categoryIcons = {
      'Apparts': FontAwesomeIcons.building,
      'Maisons': FontAwesomeIcons.house,
      'Villas': FontAwesomeIcons.houseChimney,
      'Studios': FontAwesomeIcons.buildingCircleCheck,
      'Bureaux': FontAwesomeIcons.buildingColumns,
      'Résidences': FontAwesomeIcons.buildingUser,
      'Hotels': FontAwesomeIcons.hotel,
      'Vacances': FontAwesomeIcons.umbrellaBeach,
    };

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
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          Icon(categoryIcons[widget.category] ?? FontAwesomeIcons.building,
              size: 20, color: Colors.white),
          SizedBox(width: 10),
          Text(
            widget.category,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 18,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(
            _isGridView ? Icons.list_rounded : Icons.grid_view_rounded,
            color: Colors.white,
          ),
          onPressed: () {
            setState(() {
              _isGridView = !_isGridView;
            });
          },
        ),
      ],
      bottom: PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Container(
          color: Colors.white.withOpacity(0.2),
          height: 1,
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    final filterIcons = {
      'Tous': Icons.all_inclusive_rounded,
      'Location': Icons.apartment_rounded,
      'Vente': Icons.sell_rounded,
      'Populaires': Icons.trending_up_rounded,
      'Nouveautés': Icons.fiber_new_rounded,
    };

    // Filter logic specific for 'Vacances'
    final activeFilters = widget.category == 'Vacances'
        ? _filters.where((f) => !['Location', 'Vente'].contains(f)).toList()
        : _filters;

    return Container(
      height: 66,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: activeFilters.length,
        separatorBuilder: (_, __) => SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = activeFilters[index];
          final isSelected = _selectedFilter == filter;

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedFilter = filter;
              });
            },
            child: AnimatedContainer(
              duration: Duration(milliseconds: 200),
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? _primaryColor : Colors.transparent,
                borderRadius: BorderRadius.circular(12), // Border radius réduit
                border: Border.all(
                  color: isSelected ? _primaryColor : Colors.grey[300]!,
                  width: 1.5,
                ),
                boxShadow: isSelected ? [
                  BoxShadow(
                    color: _primaryColor.withOpacity(0.3),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  )
                ] : [],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    filterIcons[filter],
                    size: 16,
                    color: isSelected ? Colors.white : Colors.black54,
                  ),
                  SizedBox(width: 6),
                  Text(
                    filter,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: isSelected ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPropertyListOrGrid(List<dynamic> items) {
    final visibleItems = items.take(_visibleCount).toList();
    
    if (_isGridView) {
      return GridView.builder(
        padding: EdgeInsets.all(16),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.72,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: visibleItems.length,
        itemBuilder: (context, index) {
          final item = visibleItems[index];
          if (item is AgenceModel) {
            return _buildAgenceCard(item);
          } else {
            final property = item as PropertyModel;
            final isForRent = property.transactionType?.toLowerCase().contains('location') ?? false;
            return _buildPropertyCard(property, isForRent);
          }
        },
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: visibleItems.length,
      itemBuilder: (context, index) {
        final item = visibleItems[index];
        if (item is AgenceModel) {
          return _buildAgenceListItem(item);
        } else {
          final property = item as PropertyModel;
          final isForRent = property.transactionType?.toLowerCase().contains('location') ?? false;
          return _buildPropertyListItem(property, isForRent);
        }
      },
    );
  }

  Widget _buildShimmerGridItem() {
     return Shimmer.fromColors(
       baseColor: Colors.grey[300]!,
       highlightColor: Colors.grey[100]!,
       child: Container(
         decoration: BoxDecoration(
           borderRadius: BorderRadius.circular(16),
           color: Colors.white,
         ),
       ),
     );
  }

  // --- AGENCY WIDGETS ---

  Widget _buildAgenceListItem(AgenceModel agence) {
    ImageProvider? imageProvider;
    if (agence.logo != null && agence.logo!.isNotEmpty) {
      if (agence.logo!.startsWith('http')) {
        imageProvider = CachedNetworkImageProvider(agence.logo!);
      } else if (agence.logo!.startsWith('data:image')) {
        try {
          final base64String = agence.logo!.split(',').last;
          imageProvider = MemoryImage(base64Decode(base64String));
        } catch (e) {
          print('Error decoding base64: $e');
        }
      }
    }

    return InkWell(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => AgenceDetailsPage(agency: agence)));
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
          border: Border.all(color: _primaryColor.withOpacity(0.1)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Logo Section
            Container(
              width: 100,
              height: 100,
              margin: EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.grey[50],
                image: imageProvider != null ? DecorationImage(
                  image: imageProvider,
                  fit: BoxFit.cover,
                ) : null,
              ),
              child: imageProvider == null ? Icon(Icons.business, color: Colors.grey[300], size: 40) : null,
            ),

            // Content Section
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(top: 12, right: 12, bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'AGENCE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: _primaryColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      agence.name ?? 'Agence',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: _darkColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined, size: 14, color: _greyColor),
                        SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            agence.address ?? '',
                            style: TextStyle(color: _greyColor, fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.phone_outlined, size: 14, color: _primaryColor),
                        SizedBox(width: 4),
                        Text(
                          agence.phone1 ?? '',
                          style: TextStyle(
                            color: _primaryColor, 
                            fontSize: 13, 
                            fontWeight: FontWeight.w500
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
      ),
    );
  }

  Widget _buildAgenceCard(AgenceModel agence) {
    // Similar logic for Grid View
    final hasLogo = agence.logo != null && agence.logo!.isNotEmpty;
    ImageProvider? imageProvider;
    
    if (hasLogo) {
       if (agence.logo!.startsWith('http')) {
         imageProvider = CachedNetworkImageProvider(agence.logo!);
       } else if (agence.logo!.startsWith('data:image')) {
         try {
           final base64String = agence.logo!.split(',').last;
           imageProvider = MemoryImage(base64Decode(base64String));
         } catch (e) {
           print('Error decoding base64 image: $e');
         }
       }
    }
    
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AgenceDetailsPage(agency: agence))),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                  color: Colors.grey[50],
                  image: imageProvider != null ? DecorationImage(
                    image: imageProvider,
                    fit: BoxFit.cover,
                  ) : null,
                ),
                child: Stack(
                  children: [
                    if (imageProvider == null)
                      Center(child: Icon(Icons.business, color: Colors.grey[300], size: 40)),
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'AGENCE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: _primaryColor,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      agence.name ?? 'Agence',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: _darkColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined, size: 12, color: _greyColor),
                        SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            agence.address ?? '',
                            style: TextStyle(
                              fontSize: 12,
                              color: _greyColor,
                            ),
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
      ),
    );
  }



  // Carte en mode liste - Design moderne avec superposition
  Widget _buildPropertyListItem(PropertyModel property, bool isForRent) {
    final priceText = isForRent
        ? '${property.price?.toStringAsFixed(0) ?? '0'} ${property.currency}/mois'
        : '${property.price?.toStringAsFixed(0) ?? '0'} ${property.currency}';

    // Utilisation des vraies images du modèle PropertyModel
    final firstImage = property.propertyImage?.isNotEmpty ?? false
        ? property.propertyImage!.first
        : null;
    final imageUrl = firstImage != null
        ? "${firstImage.path ?? firstImage.path}"
        : null;

    String propertyType = _getPropertyTypeFromTitle(property.propertyType?.name);

    return InkWell(
      onTap: () => _navigateToDetail(property),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section Image avec superposition moderne
            Container(
              width: 140,
              height: 175,
              margin: EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Image principale
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Hero(
                      tag: 'category-list-${property.propertyId}',
                      child: imageUrl != null
                          ? CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        placeholder: (context, url) => Container(
                          color: Colors.grey[200],
                          child: Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) {
                          return Container(
                            color: Colors.grey[200],
                            child: Icon(Icons.home_rounded, size: 40, color: Colors.grey[400]),
                          );
                        },
                      )
                          : Container(
                        color: Colors.grey[200],
                        child: Icon(Icons.home_rounded, size: 40, color: Colors.grey[400]),
                      ),
                    ),
                  ),

                  // Gradient overlay pour meilleur contraste
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.1),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Badge type de propriété en haut à gauche
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: _primaryColor.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 4,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Text(
                        propertyType,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),

                  Positioned(
                    top: 40,
                    left: 8,
                    child: PropertyListingStatusChip(
                      sold: property.sold,
                      transactionType: property.transactionType,
                      available: property.available,
                      listingAllowed: property.listingAllowed,
                    ),
                  ),

                  // Bouton favoris en haut à droite
                  if (property.propertyId != null)
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
                          propertyId: property.propertyId.toString(),
                          propertyTypeId: property.propertyTypeId,
                          size: 20,
                          splashRadius: 18,
                          activeColor: Colors.red,
                          inactiveColor: _greyColor,
                        ),
                      ),
                    ),

                  // Prix en bas - Design amélioré
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(12),
                          bottomRight: Radius.circular(12),
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.8),
                          ],
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              priceText,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isForRent ? Colors.blue[500] : Colors.green[500],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isForRent ? 'LOCATION' : 'VENTE',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Section détails
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(top: 12, right: 12, bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Titre avec gestion du overflow
                    Container(
                      constraints: BoxConstraints(maxHeight: 40),
                      child: Text(
                        property.title ?? 'Sans titre',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: _darkColor,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                    SizedBox(height: 6),

                    // Localisation avec gestion du overflow
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined, size: 14, color: _primaryColor),
                        SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            "${property.cityValue}, ${property.communeValue}",
                            style: TextStyle(
                              color: _greyColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 12),

                    // Caractéristiques
                    Builder(
                      builder: (context) {
                        final typeId = property.propertyType?.propertyTypeId;
                        final isBureau = typeId == 4;
                        final isFuneraire = typeId == 7;
                        final isFestive = typeId == 8;

                        if (isBureau) {
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildFeatureItem(
                                icon: FontAwesomeIcons.handshake,
                                value: '${property.roomMeet ?? 0}',
                                label: 'Réunion',
                              ),
                              _buildFeatureItem(
                                icon: FontAwesomeIcons.chair,
                                value: property.isEquip == true ? 'Oui' : 'Non',
                                label: 'Équipé',
                              ),
                              _buildFeatureItem(
                                icon: FontAwesomeIcons.rulerCombined,
                                value: '${property.surface?.toStringAsFixed(0) ?? '0'}',
                                label: 'm²',
                              ),
                            ],
                          );
                        } else if (isFestive) {
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildFeatureItem(
                                icon: FontAwesomeIcons.users,
                                value: '${property.capacityPeople ?? 0}',
                                label: 'Pers.',
                              ),
                              _buildFeatureItem(
                                icon: FontAwesomeIcons.music,
                                value: property.pisteDanse == true ? 'Oui' : 'Non',
                                label: 'Piste',
                              ),
                              _buildFeatureItem(
                                icon: FontAwesomeIcons.paintRoller,
                                value: property.isDecore == true ? 'Oui' : 'Non',
                                label: 'Décoré',
                              ),
                            ],
                          );
                        } else if (isFuneraire) {
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildFeatureItem(
                                icon: FontAwesomeIcons.users,
                                value: '${property.capacityPeople ?? 0}',
                                label: 'Pers.',
                              ),
                              _buildFeatureItem(
                                icon: FontAwesomeIcons.rulerCombined,
                                value: '${property.surface?.toStringAsFixed(0) ?? '0'}',
                                label: 'm²',
                              ),
                            ],
                          );
                        }

                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildFeatureItem(
                              icon: FontAwesomeIcons.bed,
                              value: '${property.bedrooms ?? 0}',
                              label: 'Chambres',
                            ),
                            _buildFeatureItem(
                              icon: FontAwesomeIcons.bath,
                              value: '${property.bathroom ?? 0}',
                              label: 'SDB',
                            ),
                            _buildFeatureItem(
                              icon: FontAwesomeIcons.rulerCombined,
                              value: '${property.surface?.toStringAsFixed(0) ?? '0'}',
                              label: 'm²',
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getPropertyTypeFromTitle(String? title) {
    if (title == null) return 'Propriété';

    final lowerTitle = title.toLowerCase();
    if (lowerTitle.contains('appart') || lowerTitle.contains('apart')) {
      return 'Appart';
    } else if (lowerTitle.contains('maison')) {
      return 'Maison';
    } else if (lowerTitle.contains('studio')) {
      return 'Studio';
    } else if (lowerTitle.contains('villa')) {
      return 'Villa';
    } else if (lowerTitle.contains('bureau')) {
      return 'Bureau';
    } else if (lowerTitle.contains('hotel')) {
      return 'Hôtel';
    } else if (lowerTitle.contains('penthouse')) {
      return 'Penthouse';
    }
    return 'Propriété';
  }

  Widget _buildPropertyCard(PropertyModel property, bool isForRent) {
    final priceText = isForRent
        ? '${property.price?.toStringAsFixed(0) ?? '0'} ${property.currency}/mois'
        : '${property.price?.toStringAsFixed(0) ?? '0'} ${property.currency}';

    // Utilisation des vraies images du modèle PropertyModel
    final firstImage = property.propertyImage?.isNotEmpty ?? false
        ? property.propertyImage!.first
        : null;
    final imageUrl = firstImage != null
        ? "${firstImage.path ?? firstImage.path}"
        : null;

    String propertyType = _getPropertyTypeFromTitle(property.propertyType?.name);

    return InkWell(
      onTap: () => _navigateToDetail(property),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section Image avec superposition
            Expanded(
              flex: 6,
              child: Container(
                margin: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // Image principale
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Hero(
                        tag: 'category-grid-${property.propertyId}',
                        child: imageUrl != null
                            ? CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          placeholder: (context, url) => Container(
                            color: Colors.grey[200],
                            child: Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) {
                            return Container(
                              color: Colors.grey[200],
                              child: Icon(Icons.home_rounded, size: 40, color: Colors.grey[400]),
                            );
                          },
                        )
                            : Container(
                          color: Colors.grey[200],
                          child: Icon(Icons.home_rounded, size: 40, color: Colors.grey[400]),
                        ),
                      ),
                    ),

                    // Gradient overlay
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.3),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Badge type de propriété
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _primaryColor.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          propertyType,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),

                    Positioned(
                      top: 40,
                      left: 8,
                      child: PropertyListingStatusChip(
                        sold: property.sold,
                        transactionType: property.transactionType,
                        available: property.available,
                        listingAllowed: property.listingAllowed,
                      ),
                    ),

                    // Bouton favoris
                    if (property.propertyId != null)
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
                            propertyId: property.propertyId.toString(),
                            propertyTypeId: property.propertyTypeId,
                            size: 18,
                            splashRadius: 16,
                            activeColor: Colors.red,
                            inactiveColor: _greyColor,
                          ),
                        ),
                      ),

                    // Prix en bas - Design amélioré
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(12),
                            bottomRight: Radius.circular(12),
                          ),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.8),
                            ],
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                priceText,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              constraints: const BoxConstraints(maxWidth: 45),
                              decoration: BoxDecoration(
                                color: isForRent ? Colors.blue[500] : Colors.green[500],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                isForRent ? 'LOC' : 'VENTE',
                                style: const TextStyle(
                                  fontSize: 7,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                                textAlign: TextAlign.center,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Expanded(
              flex: 4,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Titre et localisation avec gestion du overflow
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          constraints: BoxConstraints(maxHeight: 32),
                          child: Text(
                            property.title ?? 'Sans titre',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                              color: _darkColor,
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.location_on_outlined, size: 10, color: _greyColor),
                            SizedBox(width: 2),
                            Expanded(
                              child: Text(
                                "${property.cityValue}, ${property.communeValue}",
                                style: TextStyle(
                                  color: _greyColor,
                                  fontSize: 10,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // Caractéristiques
                    Builder(
                      builder: (context) {
                        final typeId = property.propertyType?.propertyTypeId;
                        final isBureau = typeId == 4;
                        final isFuneraire = typeId == 7;
                        final isFestive = typeId == 8;

                        if (isBureau) {
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildMiniFeatureItem(FontAwesomeIcons.handshake, '${property.roomMeet ?? 0}'),
                              _buildMiniFeatureItem(FontAwesomeIcons.chair, property.isEquip == true ? 'Oui' : 'Non'),
                              _buildMiniFeatureItem(FontAwesomeIcons.rulerCombined, '${property.surface?.toStringAsFixed(0) ?? '0'}m²'),
                            ],
                          );
                        } else if (isFestive) {
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildMiniFeatureItem(FontAwesomeIcons.users, '${property.capacityPeople ?? 0}'),
                              _buildMiniFeatureItem(FontAwesomeIcons.music, property.pisteDanse == true ? 'Oui' : 'Non'),
                              _buildMiniFeatureItem(FontAwesomeIcons.paintRoller, property.isDecore == true ? 'Oui' : 'Non'),
                            ],
                          );
                        } else if (isFuneraire) {
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildMiniFeatureItem(FontAwesomeIcons.users, '${property.capacityPeople ?? 0}'),
                              _buildMiniFeatureItem(FontAwesomeIcons.rulerCombined, '${property.surface?.toStringAsFixed(0) ?? '0'}m²'),
                            ],
                          );
                        }

                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildMiniFeatureItem(FontAwesomeIcons.bed, '${property.bedrooms ?? 0}'),
                            _buildMiniFeatureItem(FontAwesomeIcons.bath, '${property.bathroom ?? 0}'),
                            _buildMiniFeatureItem(FontAwesomeIcons.rulerCombined, '${property.surface?.toStringAsFixed(0) ?? '0'}m²'),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Item de caractéristique pour la vue liste
  Widget _buildFeatureItem({required IconData icon, required String value, required String label}) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: _primaryColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 14,
            color: _primaryColor,
          ),
        ),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: _darkColor,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: _greyColor,
          ),
        ),
      ],
    );
  }

  // Item de caractéristique miniature pour la vue grille
  Widget _buildMiniFeatureItem(IconData icon, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 10, color: _primaryColor),
        SizedBox(width: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: _darkColor,
          ),
        ),
      ],
    );
  }

  // Navigation vers la page de détail
  Future<void> _navigateToDetail(PropertyModel property) async {
    await navigateToPropertyDetail(
      context,
      property,
      heroTag: _isGridView ? 'category-grid-${property.propertyId}' : 'category-list-${property.propertyId}',
    );
  }



  Widget _buildShimmerLoading() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: _isGridView
          ? GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.72,
        ),
        itemCount: 6,
        itemBuilder: (context, index) {
          return Shimmer.fromColors(
            baseColor: Colors.grey[300]!,
            highlightColor: Colors.grey[100]!,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Colors.white,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image shimmer
                  Expanded(
                    flex: 6,
                    child: Container(
                      margin: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.white,
                      ),
                    ),
                  ),
                  // Details shimmer
                  Expanded(
                    flex: 4,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: double.infinity,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              SizedBox(height: 6),
                              Container(
                                width: 80,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(width: 25, height: 10, color: Colors.white),
                              Container(width: 25, height: 10, color: Colors.white),
                              Container(width: 25, height: 10, color: Colors.white),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      )
          : ListView.builder(
        itemCount: 6,
        itemBuilder: (context, index) {
          return Shimmer.fromColors(
            baseColor: Colors.grey[300]!,
            highlightColor: Colors.grey[100]!,
            child: Container(
              margin: EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Colors.white,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image shimmer
                  Container(
                    width: 140,
                    height: 140,
                    margin: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.white,
                    ),
                  ),
                  // Details shimmer
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(top: 12, right: 12, bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 150,
                            height: 16,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          SizedBox(height: 8),
                          Container(
                            width: 120,
                            height: 12,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Container(width: 40, height: 40, color: Colors.white),
                              Container(width: 40, height: 40, color: Colors.white),
                              Container(width: 40, height: 40, color: Colors.white),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            FontAwesomeIcons.buildingCircleXmark,
            size: 60,
            color: Colors.grey[400],
          ),
          SizedBox(height: 20),
          Text(
            'Aucune propriété disponible',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Nous n\'avons trouvé aucun ${widget.category.toLowerCase()} correspondant à vos critères',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _refreshController.dispose();
    super.dispose();
  }
}