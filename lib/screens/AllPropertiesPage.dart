import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../models/PropertyModel.dart';
import '../utils/Constantes.dart';
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
  bool _isGridView = false; // Par défaut en mode grille

  // Couleurs
  final Color _primaryColor = Color(0xFF1976D2);
  final Color _secondaryColor = Color(0xFF64B5F6);
  final Color _lightColor = const Color(0xFFF8F9FA);
  final Color _darkColor = const Color(0xFF212529);

  @override
  void initState() {
    super.initState();
    _filteredProperties = widget.initialProperties;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? _darkColor : _lightColor,
      appBar: _buildAppBar(theme),
      body: Column(
        children: [
          _buildSearchBar(isDarkMode),
          Expanded(
            child: _filteredProperties.isEmpty
                ? _buildEmptyState(isDarkMode)
                : _isGridView
                ? _buildPropertyGrid(isDarkMode)
                : _buildPropertyList(isDarkMode),
          ),
        ],
      ),
    );
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
            colors: [_primaryColor, _secondaryColor],
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
            hintStyle: TextStyle(color: Colors.grey[600]),
            prefixIcon: Icon(Icons.search, color: _primaryColor),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
              icon: Icon(Icons.clear, color: Colors.grey),
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
            color: isDarkMode ? Colors.white : Colors.black,
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
              'Ajustez votre recherche pour trouver plus de résultats.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPropertyList(bool isDarkMode) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: _filteredProperties.length,
      itemBuilder: (context, index) {
        return _buildPropertyListItem(_filteredProperties[index], widget.isForRent);
      },
    );
  }

  Widget _buildPropertyGrid(bool isDarkMode) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _filteredProperties.length,
      itemBuilder: (context, index) {
        return _buildPropertyCard(context, _filteredProperties[index], widget.isForRent, isDarkMode);
      },
    );
  }

  Widget _buildPropertyCard(BuildContext context, PropertyModel property, bool isForRent, bool isDarkMode) {
    final priceText = isForRent
        ? '${property.price?.toStringAsFixed(0) ?? '0'}\$/mois'
        : '${property.price?.toStringAsFixed(0) ?? '0'}\$';

    final firstImagePath = property.images?.isNotEmpty ?? false
        ? property.images!.first.path
        : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        return InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.pushNamed(
              context,
              Routes.detailPageRoute,
              arguments: property,
            );
          },
          child: Container(
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.grey[900] : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 6,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // IMAGE
                ClipRRect(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(5)),
                  child: Stack(
                    children: [
                      Container(
                        height: constraints.maxHeight * 0.4,
                        width: double.infinity,
                        child: firstImagePath != null
                            ? CachedNetworkImage(
                          imageUrl: "${Constantes.URL_IMAGES}$firstImagePath",
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: Colors.grey[300],
                            child: Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                          errorWidget: (context, url, error) => Icon(Icons.broken_image, size: 40, color: Colors.grey),
                        )
                            : Container(color: Colors.grey[300]),
                      ),

                      // OVERLAY GRADIENT
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 50,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Colors.black.withOpacity(0.7),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),

                      // BADGE TYPE
                      Positioned(
                        top: 10,
                        left: 10,
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isForRent ? Colors.blueAccent : Colors.green,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isForRent ? 'À LOUER' : 'À VENDRE',
                            style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),

                      // FAVORITE BUTTON
                      Positioned(
                        top: 10,
                        right: 10,
                        child: FavoriteHeartIcon(
                          propertyId: property.PropertyId.toString(),
                          size: 24,
                          splashRadius: 20,
                          activeColor: Colors.red,
                          inactiveColor: Colors.white,
                        ),
                      ),

                      // PRIX
                      Positioned(
                        bottom: 10,
                        left: 10,
                        child: Text(
                          priceText,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            shadows: [Shadow(color: Colors.black45, blurRadius: 4)],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // INFOS
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // TITRE
                        Text(
                          property.title ?? 'Sans titre',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 6),

                        // LOCALISATION
                        Row(
                          children: [
                            Icon(Icons.location_on_outlined, size: 14, color: Colors.grey[600]),
                            SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                '${property.commune ?? ''}, ${property.city ?? ''}',
                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        Spacer(),

                        // CARACTÉRISTIQUES
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildFeatureChip(FontAwesomeIcons.bed, '${property.bedrooms ?? 0}'),
                            _buildFeatureChip(FontAwesomeIcons.bath, '${property.bedrooms ?? 0}'),
                            _buildFeatureChip(FontAwesomeIcons.rulerCombined, '${property.surface?.toStringAsFixed(0) ?? '0'}m²'),
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
    );
  }

  Widget _buildFeatureChip(IconData icon, String value) {
    return Row(
      children: [
        Icon(icon, size: 12, color: Colors.grey[600]),
        SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(fontSize: 12, color: Colors.grey[700]),
        ),
      ],
    );
  }






  Widget _buildPropertyListItem(PropertyModel property, bool isForRent) {
    final priceText = isForRent
        ? '${property.price?.toStringAsFixed(0) ?? '0'}\$/mois'
        : '${property.price?.toStringAsFixed(0) ?? '0'}\$';
    final firstImagePath = property.images?.isNotEmpty == true
        ? property.images!.first.path
        : null;

    return InkWell(
      onTap: () {
        Navigator.pushNamed(
          context,
          Routes.detailPageRoute,
          arguments: property,
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Theme.of(context).cardColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 6,
              offset: Offset(0, 3),
            )
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Section avec bouton favoris
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.horizontal(left: Radius.circular(12)),
                  child: Container(
                    width: 120,
                    height: 130,
                    color: Colors.grey[200],
                    child: firstImagePath != null
                        ? CachedNetworkImage(
                      imageUrl: "${Constantes.URL_IMAGES}$firstImagePath",
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                              _primaryColor),
                        ),
                      ),
                      errorWidget: (context, url, error) => Center(
                        child: Icon(
                          Icons.photo_outlined,
                          size: 36,
                          color: Colors.grey[400],
                        ),
                      ),
                    )
                        : Center(
                      child: Icon(
                        Icons.photo_outlined,
                        size: 36,
                        color: Colors.grey[400],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: FavoriteHeartIcon(
                    propertyId: property.PropertyId.toString(),
                    size: 24,
                    splashRadius: 20,
                    activeColor: Colors.red,
                    inactiveColor: Colors.white,
                  ),
                ),
              ],
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            property.title ?? 'Sans titre',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: isForRent ? Colors.blueAccent : Colors.green,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            isForRent ? 'À LOUER' : 'À VENDRE',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined, size: 14, color: Colors.grey[600]),
                        SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            [property.commune, property.city]
                                .where((e) => e != null && e!.isNotEmpty)
                                .join(', '),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildFeatureIcon(
                          icon: FontAwesomeIcons.bed,
                          value: ' ${property.bedrooms ?? 0}',
                          iconSize: 14,
                        ),
                        _buildFeatureIcon(
                          icon: FontAwesomeIcons.bath,
                          value: ' ${property.bedrooms ?? 0}',
                          iconSize: 14,
                        ),
                        _buildFeatureIcon(
                          icon: FontAwesomeIcons.rulerCombined,
                          value: ' ${property.surface?.toStringAsFixed(0) ?? '0'}m²',
                          iconSize: 14,
                        ),
                      ],
                    ),
                    SizedBox(height: 15),
                    Text(
                      priceText,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: _primaryColor,
                      ),
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

  Widget _buildFeatureIcon({required IconData icon, required String value, double iconSize = 16}) {
    return Row(
      children: [
        Icon(icon, size: iconSize, color: Colors.grey),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  void _applyFilters() {
    setState(() {
      _filteredProperties = widget.initialProperties.where((property) {
        final searchText = _searchController.text.toLowerCase();
        return searchText.isEmpty ||
            (property.title?.toLowerCase().contains(searchText) ?? false) ||
            (property.description?.toLowerCase().contains(searchText) ?? false) ||
            (property.commune?.toLowerCase().contains(searchText) ?? false) ||
            (property.city?.toLowerCase().contains(searchText) ?? false);
      }).toList();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}