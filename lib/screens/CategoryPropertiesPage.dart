import 'package:cached_network_image/cached_network_image.dart';
import 'package:casa/controllers/PropertyCtrl.dart';
import 'package:casa/utils/Constantes.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../models/PropertyModel.dart';
import '../utils/FavoriteEartIcon.dart';
import '../utils/Routes.dart';

class CategoryPropertiesPage extends StatefulWidget {
  final String category;

  const CategoryPropertiesPage({Key? key, required this.category}) : super(key: key);

  @override
  _CategoryPropertiesPageState createState() => _CategoryPropertiesPageState();
}

class _CategoryPropertiesPageState extends State<CategoryPropertiesPage> {
  final Color primaryColor = Color(0xFF1976D2);
  final Color _secondaryColor = Color(0xFF64B5F6);
  final Color darkBlue = Color(0xFF0D47A1);
  bool _isGridView = false;
  String _selectedFilter = 'Tous';
  final List<String> _filters = ['Tous', 'Location', 'Vente', 'Populaires', 'Nouveautés'];

  @override
  Widget build(BuildContext context) {
    final propertyCtrl = context.watch<PropertyController>();
    final properties = propertyCtrl.properties.where((p) =>
        _matchesCategory(p, widget.category)).toList();

    final filteredProperties = _applyFilter(properties, _selectedFilter);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildFilterChips(),
          Expanded(
            child: propertyCtrl.loading
                ? _buildShimmerLoading()
                : filteredProperties.isEmpty
                ? _buildEmptyState()
                : _buildPropertyListOrGrid(filteredProperties),
          ),
        ],
      ),
    );
  }

  bool _matchesCategory(PropertyModel property, String category) {
    if (category == 'Tous') return true;

    final propertyTypeName = property.property_type?.name?.toLowerCase();
    if (propertyTypeName == null) return false;

    final categoryMap = {
      'Apparts': ['appartement', 'studio', 'loft'],
      'Maisons': ['maison', 'duplex', 'villa'],
      'Studios': ['studio'],
      'Bureaux': ['bureau', 'espace commercial'],
      'Hotels': ['hotel'],
      'Vacances': ['résidence de vacances', 'maison de vacances'],
    };

    return categoryMap[category]?.any((type) => propertyTypeName.contains(type)) ?? false;
  }

  List<PropertyModel> _applyFilter(List<PropertyModel> properties, String filter) {
    switch (filter) {
      case 'Location':
        return properties.where((p) => p.transactionType == 'location').toList();
      case 'Vente':
        return properties.where((p) => p.transactionType == 'vente').toList();
      case 'Populaires':
        return properties..sort((a, b) => ( 0).compareTo( 0));
      case 'Nouveautés':
        return properties..sort((a, b) => ( DateTime.now())
            .compareTo( DateTime.now()));
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
    };

    return AppBar(
      elevation: 0,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [primaryColor, _secondaryColor],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ), // Fond bleu
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new, color: Colors.white), // Icône blanche
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          Icon(categoryIcons[widget.category] ?? FontAwesomeIcons.building,
              size: 20, color: Colors.white), // Icône blanche
          SizedBox(width: 10),
          Text(
            widget.category,
            style: TextStyle(
              color: Colors.white, // Texte blanc
              fontWeight: FontWeight.w600, // Semi-bold au lieu de bold pour plus d'élégance
              fontSize: 18, // Légèrement réduit
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
          color: Colors.white.withOpacity(0.2), // Ligne de séparation semi-transparente
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

    return Container(
      height: 66,
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
        itemCount: _filters.length,
        separatorBuilder: (_, __) => SizedBox(width: 10),
        itemBuilder: (context, index) {
          final filter = _filters[index];
          final isSelected = _selectedFilter == filter;

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedFilter = filter;
              });
            },
            child: AnimatedContainer(
              duration: Duration(milliseconds: 200),
              padding: EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? primaryColor.withOpacity(0.12) : Colors.grey[100],
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: isSelected ? primaryColor : Colors.grey[300]!,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    filterIcons[filter],
                    size: 18,
                    color: isSelected ? primaryColor : Colors.black54,
                  ),
                  SizedBox(width: 8),
                  Text(
                    filter,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: isSelected ? primaryColor : Colors.black87,
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
          color: Colors.white,
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
                              Theme.of(context).colorScheme.primary),
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
                        color: Theme.of(context).colorScheme.primary,
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

  Widget _buildPropertyListOrGrid(List<PropertyModel> properties) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: _isGridView
          ? GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.75,
        ),
        itemCount: properties.length,
        itemBuilder: (context, index) {
          final property = properties[index];
          final isForRent = property.transactionType == 'location';
          return _buildPropertyCard(property, isForRent);
        },
      )
          : ListView.builder(
        itemCount: properties.length,
        itemBuilder: (context, index) {
          final property = properties[index];
          final isForRent = property.transactionType == 'location';
          return _buildPropertyListItem(property, isForRent);
        },
      ),
    );
  }

  Widget _buildPropertyGrid(List<PropertyModel> properties) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.75,
        ),
        itemCount: properties.length,
        itemBuilder: (context, index) {
          final property = properties[index];
          final isForRent = property.transactionType == 'location';

          return _buildPropertyCard(property, isForRent);
        },
      ),
    );
  }

  Widget _buildPropertyCard(PropertyModel property, bool isForRent) {
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
      borderRadius: BorderRadius.circular(16),
      child: Card(
        elevation: 3,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: SizedBox(
          width: 180, // Largeur fixe pour une meilleure consistance
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min, // Pour éviter l'expansion inutile
            children: [
              // Image Section
              Stack(
                children: [
                  Container(
                    height: 120,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                      color: Colors.grey[200],
                    ),
                    child: firstImagePath != null
                        ? ClipRRect(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                      child: CachedNetworkImage(
                        imageUrl: "${Constantes.URL_IMAGES}$firstImagePath",
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                Theme.of(context).colorScheme.primary),
                          ),
                        ),
                        errorWidget: (context, url, error) => Center(
                          child: Icon(
                            Icons.photo_outlined,
                            size: 48,
                            color: Colors.grey[400],
                          ),
                        ),
                      ),
                    )
                        : Center(
                      child: Icon(
                        Icons.photo_outlined,
                        size: 48,
                        color: Colors.grey[400],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.black.withOpacity(0.6), Colors.transparent],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                        borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
                      ),
                      child: Text(
                        priceText,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13, // Légèrement réduit
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: isForRent ? Colors.blueAccent : Colors.green,
                        borderRadius: BorderRadius.circular(10), // Plus petit
                        boxShadow: [
                        BoxShadow(
                        color: Colors.black12,
                        blurRadius: 3,
                        offset: Offset(1, 1),
                        )
                        ],
                      ),
                      child: Text(
                        isForRent ? 'À LOUER' : 'À VENDRE', // Texte plus court
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9, // Plus petit
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              // Details Section
              Padding(
                padding: const EdgeInsets.all(10), // Padding réduit
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      property.title ?? 'Sans titre',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13, // Légèrement réduit
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4), // Espacement réduit
                    // Address
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined, size: 12, color: Colors.grey[600]),
                        SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            [property.commune, property.city]
                                .where((e) => e != null && e!.isNotEmpty)
                                .join(', '),
                            style: TextStyle(
                              fontSize: 10, // Plus petit
                              color: Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    // Features
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildFeatureIcon(
                          icon: FontAwesomeIcons.bed,
                          value: '${property.bedrooms ?? 0}',
                          iconSize: 12, // Ajout d'un paramètre de taille
                        ),
                        _buildFeatureIcon(
                          icon: FontAwesomeIcons.bath,
                          value: '${property.bedrooms ?? 0}', // Corrigé: bathrooms au lieu de bedrooms
                          iconSize: 12,
                        ),
                        _buildFeatureIcon(
                          icon: FontAwesomeIcons.rulerCombined,
                          value: '${property.surface?.toStringAsFixed(0) ?? '0'}m²',
                          iconSize: 12,
                        ),
                      ],
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

// Fonction modifiée pour accepter la taille de l'icône
  Widget _buildFeatureIcon({required IconData icon, required String value, double iconSize = 14}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: iconSize, color: Colors.grey[600]),
        SizedBox(width: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: iconSize - 2, // Taille proportionnelle
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildShimmerLoading() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: _isGridView
          ? GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.75,
        ),
        itemCount: 6,
        itemBuilder: (context, index) {
          return Shimmer.fromColors(
            baseColor: Colors.grey[300]!,
            highlightColor: Colors.grey[100]!,
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 120,
                    width: double.infinity,
                    color: Colors.white,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          height: 16,
                          color: Colors.white,
                        ),
                        SizedBox(height: 8),
                        Container(
                          width: 120,
                          height: 12,
                          color: Colors.white,
                        ),
                        SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(width: 40, height: 12, color: Colors.white),
                            Container(width: 40, height: 12, color: Colors.white),
                            Container(width: 40, height: 12, color: Colors.white),
                          ],
                        ),
                      ],
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
                borderRadius: BorderRadius.circular(12),
                color: Colors.white,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    color: Colors.white,
                  ),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(width: 150, height: 16, color: Colors.white),
                          SizedBox(height: 8),
                          Container(width: 100, height: 12, color: Colors.white),
                          SizedBox(height: 16),
                          Row(
                            children: [
                              Container(width: 40, height: 12, color: Colors.white),
                              SizedBox(width: 8),
                              Container(width: 40, height: 12, color: Colors.white),
                              SizedBox(width: 8),
                              Container(width: 40, height: 12, color: Colors.white),
                              Spacer(),
                              Container(width: 60, height: 14, color: Colors.white),
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
          // SizedBox(height: 20),
          // ElevatedButton(
          //   onPressed: () {
          //     setState(() {
          //       _selectedFilter = 'Tous';
          //     });
          //   },
          //   style: ElevatedButton.styleFrom(
          //     backgroundColor: primaryColor,
          //     shape: RoundedRectangleBorder(
          //       borderRadius: BorderRadius.circular(12),
          //     ),
          //     padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          //   ),
          //   child: Text(
          //     'Réinitialiser les filtres',
          //     style: TextStyle(color: Colors.white),
          //   ),
          // ),
        ],
      ),
    );
  }
}