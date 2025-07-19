import 'package:cached_network_image/cached_network_image.dart';
import 'package:casa/models/PropertyModel.dart';
import 'package:casa/utils/Constantes.dart';
import 'package:casa/utils/Routes.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

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
  bool _isGridView = false;

  // Couleurs modernes

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
        icon: Icon(Icons.arrow_back,color: Colors.white,),
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
            colors: [_secondaryColor, _primaryColor],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.view_list, color: !_isGridView ? Colors.white : Colors.white70),
          onPressed: () => setState(() => _isGridView = false),
          tooltip: 'Vue en liste',
        ),
        IconButton(
          icon: Icon(Icons.grid_view, color: _isGridView ? Colors.white : Colors.white70),
          onPressed: () => setState(() => _isGridView = true),
          tooltip: 'Vue en grille',
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
        return _buildPropertyCard(_filteredProperties[index], isDarkMode);
      },
    );
  }

  Widget _buildPropertyGrid(bool isDarkMode) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calcul dynamique de la hauteur en fonction de la largeur
        final cardHeight = constraints.maxWidth / 2 * 1.4;

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
            return SizedBox(
              height: cardHeight,
              child: _buildPropertyCard(_filteredProperties[index], isDarkMode, isGrid: true),
            );
          },
        );
      },
    );
  }

  Widget _buildPropertyCard(PropertyModel property, bool isDarkMode, {bool isGrid = false}) {
    final firstImagePath = property.images?.isNotEmpty ?? false
        ? property.images!.first.path
        : null;

    final priceText = widget.isForRent
        ? '${property.price?.toStringAsFixed(0) ?? '0'}\$/mois'
        : '${property.price?.toStringAsFixed(0) ?? '0'}\$';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.pushNamed(
            context,
            Routes.detailPageRoute,
            arguments: property,
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image avec badge
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: firstImagePath != null
                      ?  CachedNetworkImage(
                    imageUrl: "${Constantes.URL_IMAGES}${firstImagePath}",
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: Colors.grey[200],
                      child: Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey[200],
                      child: Center(
                        child: Icon(Icons.broken_image,
                            color: Colors.grey[400], size: 40),
                      ),
                    ),
                  )
                      :Container(
                    color: Colors.green[200],
                    child: Center(
                      child: Icon(
                        Icons.photo_outlined,
                        size: 48,
                        color: Colors.grey[400],
                      ),
                    ),
                  )
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: widget.isForRent ? Colors.blue : Colors.green,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      widget.isForRent ? 'À LOUER' : 'À VENDRE',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            // Détails
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Titre et prix
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          property.title ?? 'Propriété sans titre',
                          style: TextStyle(
                            fontSize: isGrid ? 14 : 16,
                            fontWeight: FontWeight.w600,
                            color: isDarkMode ? Colors.white : Colors.black,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        priceText,
                        style: TextStyle(
                          fontSize: isGrid ? 13 : 15,
                          fontWeight: FontWeight.bold,
                          color: _primaryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Localisation
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 14,
                        color: _primaryColor,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${property.commune ?? ''}, ${property.city ?? ''}',
                          style: TextStyle(
                            color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                            fontSize: isGrid ? 12 : 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Caractéristiques
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.grey[700] : _lightColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildFeatureItem(
                          icon: FontAwesomeIcons.bed,
                          value: '${property.bedrooms ?? 0}',
                          label: 'Chambres',
                          isDarkMode: isDarkMode,
                          isGrid: isGrid,
                        ),
                        _buildFeatureItem(
                          icon: FontAwesomeIcons.bath,
                          value: '${property.bedrooms ?? 0}',
                          label: 'SDB',
                          isDarkMode: isDarkMode,
                          isGrid: isGrid,
                        ),
                        _buildFeatureItem(
                          icon: FontAwesomeIcons.rulerCombined,
                          value: '${property.surface?.toStringAsFixed(0) ?? '0'}',
                          label: 'm²',
                          isDarkMode: isDarkMode,
                          isGrid: isGrid,
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
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required String value,
    required String label,
    required bool isDarkMode,
    bool isGrid = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: isGrid ? 16 : 18,
          color: _primaryColor,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: isGrid ? 12 : 13,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : _darkColor,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: isGrid ? 10 : 11,
            color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
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