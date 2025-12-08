import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:provider/provider.dart';

import '../controllers/PropertyCtrl.dart';
import '../models/PropertyModel.dart';
import '../utils/Constantes.dart';
import '../utils/FancyNotification.dart';
import '../utils/Routes.dart';
import '../utils/FavoriteEartIcon.dart';

class AllPropertiesPage extends StatefulWidget {
  final List<PropertyModel> initialProperties;
  final bool isForRent;

  const AllPropertiesPage({
    Key? key,
    required this.initialProperties,
    required this.isForRent,
  }) : super(key: key);

  @override
  _AllPropertiesPageState createState() => _AllPropertiesPageState();
}

class _AllPropertiesPageState extends State<AllPropertiesPage> {
  late List<PropertyModel> _filteredProperties;
  final TextEditingController _searchController = TextEditingController();
  final RefreshController _refreshController = RefreshController();
  bool _isGridView = false;
  String _selectedFilter = 'Tous';
  final List<String> _filters = ['Tous', 'Apparts', 'Maisons', 'Studios', 'Bureaux', 'Villas'];

  // Couleurs du design PropertySearchPage
  final Color _primaryColor = Color(0xFF1976D2);
  final Color _darkColor = Color(0xFF1A1D26);
  final Color _lightColor = Color(0xFFF5F6FA);
  final Color _greyColor = Color(0xFF7F8C8D);
  final Color _accentColor = Color(0xFF4CAF50);

  @override
  void initState() {
    super.initState();
    _filteredProperties = widget.initialProperties;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final propertyCtrl = context.watch<PropertyController>();

    return Scaffold(
      backgroundColor: isDarkMode ? _darkColor : _lightColor,
      appBar: _buildAppBar(theme),
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
              valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
            ),
          ),
        ),
        onRefresh: () async {
          await _handlePullToRefresh(propertyCtrl);
        },
        child: Column(
          children: [
            //_buildSearchBar(isDarkMode),
            _buildFilterChips(isDarkMode),

            // Indicateur de synchronisation discret
            if (propertyCtrl.syncing)
              _buildMinimalSyncIndicator(),

            Expanded(
              child: _filteredProperties.isEmpty
                  ? _buildEmptyState(isDarkMode)
                  : _isGridView
                  ? _buildPropertyGrid(isDarkMode)
                  : _buildPropertyList(isDarkMode),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips(bool isDarkMode) {
    final filterIcons = {
      'Tous': Icons.all_inclusive_rounded,
      'Apparts': FontAwesomeIcons.building,
      'Maisons': FontAwesomeIcons.house,
      'Studios': FontAwesomeIcons.buildingCircleCheck,
      'Bureaux': FontAwesomeIcons.buildingColumns,
      'Villas': FontAwesomeIcons.houseChimney,
    };

    return Container(
      height: 66,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[900] : Colors.white,
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
        itemCount: _filters.length,
        separatorBuilder: (_, __) => SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = _filters[index];
          final isSelected = _selectedFilter == filter;

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedFilter = filter;
                _applyFilters();
              });
            },
            child: AnimatedContainer(
              duration: Duration(milliseconds: 200),
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? _primaryColor : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
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

  Future<void> _handlePullToRefresh(PropertyController propertyCtrl) async {
    try {
      await propertyCtrl.refreshProperties();

      // Mettre à jour la liste filtrée avec les nouvelles données
      final newProperties = propertyCtrl.properties.where((p) =>
      p.transactionType?.toLowerCase().contains(widget.isForRent ? 'location' : 'vente') ?? false
      ).toList();

      setState(() {
        _filteredProperties = newProperties;
      });

      _refreshController.refreshCompleted();
      SnackbarForCasa.success(context, "Liste actualisée");

    } catch (e) {
      print("❌ Erreur refresh: $e");
      _refreshController.refreshFailed();
      SnackbarForCasa.error(context, "Erreur de connexion");
    }
  }

  PreferredSizeWidget _buildAppBar(ThemeData theme) {
    return AppBar(
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        widget.isForRent ? 'Locations disponibles' : 'Biens à vendre',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 20,
          letterSpacing: 0.5,
          color: Colors.white,
        ),
      ),
      centerTitle: true,
      elevation: 0,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_primaryColor, Color(0xFF64B5F6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
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
          tooltip: _isGridView ? 'Vue en liste' : 'Vue en grille',
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildSearchBar(bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: SizedBox(
        height: 50,
        child: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Rechercher une propriété...',
            hintStyle: TextStyle(color: _greyColor),
            prefixIcon: Icon(Icons.search, color: _primaryColor),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
              icon: Icon(Icons.clear, color: _greyColor),
              onPressed: () {
                _searchController.clear();
                _applyFilters();
              },
            )
                : null,
            filled: true,
            fillColor: isDarkMode ? Colors.grey[800] : Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 16),
          ),
          style: TextStyle(
            fontSize: 16,
            color: isDarkMode ? Colors.white : _darkColor,
          ),
          onChanged: (value) => _applyFilters(),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDarkMode) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.home_work_outlined,
            size: 72,
            color: _primaryColor.withOpacity(0.3),
          ),
          const SizedBox(height: 24),
          Text(
            'Aucun résultat trouvé',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.white : _darkColor,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Ajustez vos filtres pour trouver plus de résultats.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: isDarkMode ? Colors.grey[400] : _greyColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPropertyList(bool isDarkMode) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredProperties.length,
      itemBuilder: (context, index) => _buildPropertyListItem(_filteredProperties[index], isDarkMode),
    );
  }

  Widget _buildPropertyGrid(bool isDarkMode) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.72,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _filteredProperties.length,
      itemBuilder: (context, index) {
        return _buildPropertyCard(_filteredProperties[index], isDarkMode);
      },
    );
  }

  // Carte en mode liste - Design moderne avec superposition améliorée
  Widget _buildPropertyListItem(PropertyModel property, bool isDarkMode) {
    final priceText = widget.isForRent
        ? '${property.price?.toStringAsFixed(0) ?? '0'}\$/mois'
        : '${property.price?.toStringAsFixed(0) ?? '0'}\$';

    // Utilisation des vraies images du modèle
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
          color: isDarkMode ? Colors.grey[900] : Colors.white,
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
                          size: 20,
                          splashRadius: 18,
                          activeColor: Colors.red,
                          inactiveColor: _greyColor,
                        ),
                      ),
                    ),

                  // Prix en bas - Design amélioré avec gradient
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
                              color: widget.isForRent ? Colors.blue[500] : Colors.green[500],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              widget.isForRent ? 'LOCATION' : 'VENTE',
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
                          color: isDarkMode ? Colors.white : _darkColor,
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
                            property.address ?? 'Adresse non disponible',
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
                    Row(
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

  // Carte en mode grille - Design moderne avec superposition améliorée
  Widget _buildPropertyCard(PropertyModel property, bool isDarkMode) {
    final priceText = widget.isForRent
        ? '${property.price?.toStringAsFixed(0) ?? '0'}\$/mois'
        : '${property.price?.toStringAsFixed(0) ?? '0'}\$';

    // Utilisation des vraies images du modèle
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
          color: isDarkMode ? Colors.grey[900] : Colors.white,
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
                            size: 18,
                            splashRadius: 16,
                            activeColor: Colors.red,
                            inactiveColor: _greyColor,
                          ),
                        ),
                      ),

                    // Prix en bas - Design amélioré avec gradient
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
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              decoration: BoxDecoration(
                                color: widget.isForRent ? Colors.blue[500] : Colors.green[500],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                widget.isForRent ? 'LOC' : 'VENTE',
                                style: TextStyle(
                                  fontSize: 8,
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
            ),

            // Section détails
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
                              color: isDarkMode ? Colors.white : _darkColor,
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
                                property.address ?? 'Adresse non disponible',
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildMiniFeatureItem(FontAwesomeIcons.bed, '${property.bedrooms ?? 0}'),
                        _buildMiniFeatureItem(FontAwesomeIcons.bath, '${property.bathroom ?? 0}'),
                        _buildMiniFeatureItem(FontAwesomeIcons.rulerCombined, '${property.surface?.toStringAsFixed(0) ?? '0'}m²'),
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
  void _navigateToDetail(PropertyModel property) {
    Navigator.pushNamed(
      context,
      Routes.detailPageRoute,
      arguments: property,
    );
  }

  // Méthode pour déterminer le type de propriété depuis le titre
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

  void _applyFilters() {
    setState(() {
      _filteredProperties = widget.initialProperties.where((property) {
        final searchText = _searchController.text.toLowerCase();
        final matchesSearch = searchText.isEmpty ||
            (property.title?.toLowerCase().contains(searchText) ?? false) ||
            (property.description?.toLowerCase().contains(searchText) ?? false) ||
            (property.address?.toLowerCase().contains(searchText) ?? false) ||
            (property.quartier?.toLowerCase().contains(searchText) ?? false);

        final matchesCategory = _selectedFilter == 'Tous' ||
            _matchesCategory(property, _selectedFilter);

        return matchesSearch && matchesCategory;
      }).toList();
    });
  }

  bool _matchesCategory(PropertyModel property, String category) {
    final propertyTypeName = property.propertyType?.name?.toLowerCase() ?? '';

    switch (category) {
      case 'Apparts':
        return propertyTypeName.contains('appart') ||
            propertyTypeName.contains('apart');
      case 'Maisons':
        return propertyTypeName.contains('maison') ||
            propertyTypeName.contains('house');
      case 'Studios':
        return propertyTypeName.contains('studio');
      case 'Bureaux':
        return propertyTypeName.contains('bureau') ||
            propertyTypeName.contains('office');
      case 'Villas':
        return propertyTypeName.contains('villa');
      default:
        return true;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _refreshController.dispose();
    super.dispose();
  }
}