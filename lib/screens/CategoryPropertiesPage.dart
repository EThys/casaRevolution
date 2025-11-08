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
  final Color _primaryColor = Color(0xFF1976D2);
  final Color _secondaryColor = Color(0xFF64B5F6);
  final Color _darkColor = Color(0xFF1A1D26);
  final Color _lightColor = Color(0xFFF5F6FA);
  final Color _greyColor = Color(0xFF7F8C8D);

  bool _isGridView = false;
  String _selectedFilter = 'Tous';
  final List<String> _filters = ['Tous', 'Location', 'Vente', 'Populaires', 'Nouveautés'];

  @override
  Widget build(BuildContext context) {
    final propertyCtrl = context.watch<PropertyController>();
    final properties = propertyCtrl.properties.where((p) =>
        _matchesCategory(p, widget.category)).toList();

    final filteredProperties = _applyFilter(properties, _selectedFilter);

    // DEBUG: Afficher les propriétés filtrées
    if (propertyCtrl.properties.isNotEmpty) {
      print("=== DEBUG CATEGORY FILTER ===");
      print("Catégorie sélectionnée: ${widget.category}");
      print("Total propriétés: ${propertyCtrl.properties.length}");
      print("Propriétés filtrées: ${properties.length}");
      print("Types de propriétés disponibles:");
      propertyCtrl.properties.forEach((p) {
        print("- ${p.propertyType?.name} (ID: ${p.propertyType?.propertyTypeId})");
      });
      print("=============================");
    }

    return Scaffold(
      backgroundColor: _lightColor,
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

    // Récupérer l'ID du type de propriété
    final propertyTypeId = property.propertyType?.propertyTypeId?.toString();
    if (propertyTypeId == null) return false;

    final categoryMap = {
      'Apparts': ['2'], // ID pour Apparts
      'Maisons': ['3'], // ID pour Maisons
      'Studio': ['1'], // ID pour Studios
      'Bureau': ['4'], // ID pour Bureaux
      'Hotels': ['5'], // ID pour Hotels
      'Vacances': ['6'],
    };


    // Vérifier aussi le nom du type de propriété pour plus de fiabilité
    final propertyTypeName = property.propertyType?.name?.toLowerCase() ?? '';

    bool matchesById = categoryMap[category]?.contains(propertyTypeId) ?? false;
    bool matchesByName = _matchesCategoryByName(propertyTypeName, category);

    print("Property: ${property.title}, TypeID: $propertyTypeId, TypeName: $propertyTypeName, MatchesById: $matchesById, MatchesByName: $matchesByName");

    return matchesById || matchesByName;
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
                color: isSelected ? _primaryColor.withOpacity(0.12) : Colors.grey[100],
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: isSelected ? _primaryColor : Colors.grey[300]!,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    filterIcons[filter],
                    size: 18,
                    color: isSelected ? _primaryColor : Colors.black54,
                  ),
                  SizedBox(width: 8),
                  Text(
                    filter,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: isSelected ? _primaryColor : Colors.black87,
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
          final isForRent = property.transactionType?.toLowerCase().contains('location') ?? false;
          return _buildPropertyCard(property, isForRent);
        },
      )
          : ListView.builder(
        itemCount: properties.length,
        itemBuilder: (context, index) {
          final property = properties[index];
          final isForRent = property.transactionType?.toLowerCase().contains('location') ?? false;
          return _buildPropertyListItem(property, isForRent);
        },
      ),
    );
  }

  // Carte en mode liste - Design moderne avec superposition
  Widget _buildPropertyListItem(PropertyModel property, bool isForRent) {
    final priceText = isForRent
        ? '${property.price?.toStringAsFixed(0) ?? '0'}\$/mois'
        : '${property.price?.toStringAsFixed(0) ?? '0'}\$';

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
                      // child: FavoriteHeartIcon(
                      //   propertyId: property.propertyId.toString(),
                      //   size: 20,
                      //   splashRadius: 18,
                      //   activeColor: Colors.red,
                      //   inactiveColor: _greyColor,
                      // ),
                    ),
                  ),

                  // Prix en bas à gauche sur l'image
                  Positioned(
                    bottom: 8,
                    left: 8,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        priceText,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
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
                    // Titre
                    Text(
                      property.title ?? 'Sans titre',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: _darkColor,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    SizedBox(height: 6),

                    // Localisation
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

                    SizedBox(height: 12),

                    // Type de transaction
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isForRent ? Colors.blue[50] : Colors.green[50],
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isForRent ? Colors.blue[100]! : Colors.green[100]!,
                        ),
                      ),
                      child: Text(
                        isForRent ? 'À LOUER' : 'À VENDRE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isForRent ? Colors.blue[800]! : Colors.green[800]!,
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
    );
  }

  String _getPropertyTypeFromTitle(String? title) {
    if (title == null) return 'Propriété';

    final lowerTitle = title.toLowerCase();
    if (lowerTitle.contains('appart') || lowerTitle.contains('apart')) {
      return 'Appartement';
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
        ? '${property.price?.toStringAsFixed(0) ?? '0'}\$/mois'
        : '${property.price?.toStringAsFixed(0) ?? '0'}\$';

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
                        // child: FavoriteHeartIcon(
                        //   propertyId: property.propertyId.toString(),
                        //   size: 18,
                        //   splashRadius: 16,
                        //   activeColor: Colors.red,
                        //   inactiveColor: _greyColor,
                        // ),
                      ),
                    ),

                    // Prix en bas
                    Positioned(
                      bottom: 8,
                      left: 8,
                      right: 8,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          priceText,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
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
                    // Titre et localisation
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          property.title ?? 'Sans titre',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: _darkColor,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
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
                        _buildMiniFeatureItem(FontAwesomeIcons.rulerCombined, '${property.surface?.toStringAsFixed(0) ?? '0'}'),
                      ],
                    ),

                    // Type de transaction
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isForRent ? Colors.blue[50] : Colors.green[50],
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: isForRent ? Colors.blue[100]! : Colors.green[100]!,
                        ),
                      ),
                      child: Text(
                        isForRent ? 'LOCATION' : 'VENTE',
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w600,
                          color: isForRent ? Colors.blue[800]! : Colors.green[800]!,
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
                                height: 14,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              SizedBox(height: 6),
                              Container(
                                width: 100,
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
                              Container(width: 30, height: 10, color: Colors.white),
                              Container(width: 30, height: 10, color: Colors.white),
                              Container(width: 30, height: 10, color: Colors.white),
                            ],
                          ),
                          Container(
                            width: 60,
                            height: 16,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
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
                          SizedBox(height: 12),
                          Container(
                            width: 80,
                            height: 20,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
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
}