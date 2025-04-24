import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

class Property {
  final String id;
  final String title;
  final String address;
  final double price;
  final bool isForRent;
  final List<String> images;
  final int bedrooms;
  final int bathrooms;
  final double area;
  final int floor;
  final String description;
  final LatLng location;
  final String agentName;
  final String agentBio;
  final double rating;
  final List<Property> similarProperties;

  Property({
    required this.id,
    required this.title,
    required this.address,
    required this.price,
    required this.isForRent,
    required this.images,
    required this.bedrooms,
    required this.bathrooms,
    required this.area,
    required this.floor,
    required this.description,
    required this.location,
    required this.agentName,
    required this.agentBio,
    required this.rating,
    required this.similarProperties,
  });
}

class PropertyDetailPage extends StatefulWidget {
  final Property property;

  const PropertyDetailPage({Key? key, required this.property}) : super(key: key);

  @override
  _PropertyDetailPageState createState() => _PropertyDetailPageState();
}

class _PropertyDetailPageState extends State<PropertyDetailPage> {

  final Color _primaryColor = Color(0xFF1976D2);
  final Color _secondaryColor = Color(0xFF64B5F6);
  final Color darkBlue = Color(0xFF0D47A1);
  final Color _darkColor = Color(0xFF1A1D26);
  final Color _lightColor = Color(0xFFF8F9FA);
  final Color _greyColor = Color(0xFF6C757D);
  bool _showMoreFeatures = false; // Pour la section dépliable

  late final PageController _imageController;
  int _currentImageIndex = 0;
  late GoogleMapController _mapController;
  bool _isFavorite = false;

  @override
  void initState() {
    super.initState();
    _imageController = PageController();
  }

  @override
  void dispose() {
    _imageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _lightColor,
      body: CustomScrollView(
        slivers: [
          // AppBar avec carrousel d'images
          SliverAppBar(
            expandedHeight: MediaQuery.of(context).size.height * 0.4,
            pinned: true,
            floating: false,
            flexibleSpace: FlexibleSpaceBar(
              background: _buildImageCarousel(),
              collapseMode: CollapseMode.parallax,
            ),
            leading: _buildAppBarButton(
              icon: Icons.arrow_back_ios_new_rounded,
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              _buildAppBarButton(
                icon: _isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                onPressed: () => setState(() => _isFavorite = !_isFavorite),
              ),
              _buildAppBarButton(
                icon: Icons.share_rounded,
                onPressed: _shareProperty,
              ),
            ],
            bottom: PreferredSize(
              preferredSize: Size.fromHeight(20),
              child: _buildImageIndicator(),
            ),
          ),

          // Contenu principal
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 24),
                  // En-tête avec titre et prix
                  _buildHeaderSection(),
                  SizedBox(height: 16),

                  // Caractéristiques principales
                  _buildFeaturesSection(),
                  SizedBox(height: 24),

                  // Description
                  _buildDescriptionSection(),
                  SizedBox(height: 24),

                  // Carte
                  //_buildMapSection(),
                  _buildAdditionalFeaturesSection(),
                  SizedBox(height: 24),

                  // Agent immobilier
                  _buildAgentSection(),
                  SizedBox(height: 24),

                  // Évaluation
                  _buildRatingSection(),
                  SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // Propriétés similaires
          SliverPadding(
            padding: EdgeInsets.only(left: 24, right: 24, bottom: 24),
            sliver: SliverToBoxAdapter(
              child: _buildSimilarProperties(),
            ),
          ),
        ],
      ),

      // Bouton de contact fixe
      bottomNavigationBar: _buildContactButton(),
    );
  }

  Widget _buildAppBarButton({required IconData icon, required VoidCallback onPressed}) {
    return IconButton(
      icon: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.4),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
      onPressed: onPressed,
    );
  }

  Widget _buildImageCarousel() {
    return Stack(
      children: [
        PageView.builder(
          controller: _imageController,
          itemCount: widget.property.images.length,
          onPageChanged: (index) {
            setState(() {
              _currentImageIndex = index;
            });
          },
          itemBuilder: (context, index) {
            return Image.asset(
              widget.property.images[index], // Assure-toi que ce chemin pointe vers une image locale dans tes assets
              fit: BoxFit.cover,
              // Pas besoin de loadingBuilder pour les assets locaux
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: Colors.grey[200],
                  child: Icon(Icons.broken_image, color: Colors.grey[400]),
                );
              },
            );
          },

        ),
        Positioned(
          bottom: 16,
          left: 12,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: widget.property.isForRent ? _secondaryColor : _primaryColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: _primaryColor.withOpacity(0.2),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              widget.property.isForRent
                  ? '${widget.property.price.toInt()}\$/mois'
                  : '${widget.property.price.toInt()}\$',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        // Overlay gradient
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.1),
                ],
                stops: [0.7, 1],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImageIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: SmoothPageIndicator(
          controller: _imageController,
          count: widget.property.images.length,
          effect: ScrollingDotsEffect(
            activeDotColor: _primaryColor,
            dotColor: Colors.white.withOpacity(0.6),
            dotHeight: 8,
            dotWidth: 8,
            spacing: 4,
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Titre et badge
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                widget.property.title,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: _darkColor,
                  height: 1.3,
                ),
              ),
            ),

          ],
        ),
        SizedBox(height: 8),

        // Localisation et note
        Row(
          children: [
            Icon(Icons.location_on_outlined, size: 18, color: _greyColor),
            SizedBox(width: 6),
            Expanded(
              child: Text(
                widget.property.address,
                style: TextStyle(
                  color: _greyColor,
                  fontSize: 16,
                ),
              ),
            ),
            RatingBarIndicator(
              rating: widget.property.rating,
              itemBuilder: (context, index) => Icon(
                Icons.star_rounded,
                color: Colors.amber,
              ),
              itemCount: 5,
              itemSize: 18,
              unratedColor: Colors.amber.withAlpha(50),
            ),
            SizedBox(width: 4),
            Text(
              widget.property.rating.toStringAsFixed(1),
              style: TextStyle(
                color: _darkColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFeaturesSection() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildFeatureItem(
              icon: FontAwesomeIcons.bed,
              value: widget.property.bedrooms.toString(),
              label: 'Chambres',
            ),
            VerticalDivider(color: Colors.grey[200], thickness: 1),
            _buildFeatureItem(
              icon: FontAwesomeIcons.bath,
              value: widget.property.bathrooms.toString(),
              label: 'Salles de bain',
            ),
            VerticalDivider(color: Colors.grey[200], thickness: 1),
            _buildFeatureItem(
              icon: FontAwesomeIcons.rulerCombined,
              value: '${widget.property.area.toInt()}',
              label: 'm²',
            ),
            VerticalDivider(color: Colors.grey[200], thickness: 1),
            _buildFeatureItem(
              icon: FontAwesomeIcons.building,
              value: widget.property.floor.toString(),
              label: 'Étage',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem({required IconData icon, required String value, required String label}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _primaryColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 18, color: _primaryColor),
        ),
        SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: _darkColor,
          ),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: _greyColor,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildDescriptionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Description',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: _darkColor,
          ),
        ),
        SizedBox(height: 12),
        Text(
          widget.property.description,
          style: TextStyle(
            color: _darkColor.withOpacity(0.8),
            fontSize: 15,
            height: 1.6,
          ),
        ),
      ],
    );
  }

  // Widget _buildMapSection() {
  //   return Column(
  //     crossAxisAlignment: CrossAxisAlignment.start,
  //     children: [
  //       Text(
  //         'Localisation',
  //         style: TextStyle(
  //           fontSize: 20,
  //           fontWeight: FontWeight.bold,
  //           color: _darkColor,
  //         ),
  //       ),
  //       SizedBox(height: 12),
  //       Container(
  //         height: 200,
  //         decoration: BoxDecoration(
  //           borderRadius: BorderRadius.circular(16),
  //           boxShadow: [
  //             BoxShadow(
  //               color: Colors.black.withOpacity(0.1),
  //               blurRadius: 16,
  //               offset: Offset(0, 8),
  //             ),
  //           ],
  //         ),
  //         child: ClipRRect(
  //           borderRadius: BorderRadius.circular(16),
  //           child: Stack(
  //             children: [
  //               GoogleMap(
  //                 initialCameraPosition: CameraPosition(
  //                   target: widget.property.location,
  //                   zoom: 15,
  //                 ),
  //                 markers: {
  //                   Marker(
  //                     markerId: MarkerId('property'),
  //                     position: widget.property.location,
  //                     icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
  //                   ),
  //                 },
  //                 onMapCreated: (controller) {
  //                   _mapController = controller;
  //                 },
  //                 mapType: MapType.normal,
  //                 myLocationEnabled: true,
  //                 zoomControlsEnabled: false,
  //               ),
  //               Positioned(
  //                 bottom: 12,
  //                 right: 12,
  //                 child: FloatingActionButton.small(
  //                   onPressed: () {
  //                     _mapController.animateCamera(
  //                       CameraUpdate.newLatLng(widget.property.location),
  //                     );
  //                   },
  //                   backgroundColor: Colors.white,
  //                   child: Icon(Icons.gps_fixed_rounded, color: _primaryColor),
  //                 ),
  //               ),
  //             ],
  //           ),
  //         ),
  //       ),
  //       SizedBox(height: 12),
  //       Text(
  //         widget.property.address,
  //         style: TextStyle(
  //           color: _greyColor,
  //           fontSize: 15,
  //         ),
  //       ),
  //     ],
  //   );
  // }

  Widget _buildAgentSection() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [_primaryColor, _secondaryColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Center(
              child: Text(
                  // .split(' ').map((n) => n[0]).join(),
                widget.property.agentName,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.property.agentName,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _darkColor,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  widget.property.agentBio,
                  style: TextStyle(
                    color: _greyColor,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.message_rounded, color: _primaryColor),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  // Nouvelle méthode pour la section "Autres particularités"
  Widget _buildAdditionalFeaturesSection() {
    final additionalFeatures = {
      'Année de construction': '2015',
      'État du bien': 'Excellent',
      'Type de chauffage': 'Gaz',
      'Classe énergie': 'B',
      'Exposition': 'Sud',
      'Ascenseur': 'Oui',
      'Parking': 'Sous-sol',
      'Terrasse': '12 m²',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _showMoreFeatures = !_showMoreFeatures),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Autres particularités',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _darkColor,
                ),
              ),
              Icon(
                _showMoreFeatures ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                color: _primaryColor,
              ),
            ],
          ),
        ),
        SizedBox(height: 12),
        AnimatedCrossFade(
          duration: Duration(milliseconds: 300),
          crossFadeState: _showMoreFeatures ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          firstChild: Container(),
          secondChild: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 16,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                ...additionalFeatures.entries.map((entry) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        entry.key,
                        style: TextStyle(
                          color: _greyColor,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        entry.value,
                        style: TextStyle(
                          color: _darkColor,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )).toList(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRatingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Évaluations',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: _darkColor,
          ),
        ),
        SizedBox(height: 12),
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 16,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Note moyenne',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _darkColor,
                    ),
                  ),
                  RatingBarIndicator(
                    rating: widget.property.rating,
                    itemBuilder: (context, index) => Icon(
                      Icons.star_rounded,
                      color: Colors.amber,
                    ),
                    itemCount: 5,
                    itemSize: 20,
                    unratedColor: Colors.amber.withAlpha(50),
                  ),
                ],
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: _lightColor,
                  foregroundColor: _primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: _primaryColor.withOpacity(0.3)),
                  ),
                  padding: EdgeInsets.symmetric(vertical: 12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_rounded, size: 18),
                    SizedBox(width: 8),
                    Text('Ajouter une évaluation'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSimilarProperties() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Propriétés similaires',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: _darkColor,
          ),
        ),
        SizedBox(height: 16),
        SizedBox(
          height: 240,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: widget.property.similarProperties.length,
            itemBuilder: (context, index) {
              final property = widget.property.similarProperties[index];
              return Container(
                width: 200,
                margin: EdgeInsets.only(right: 16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PropertyDetailPage(property: property),
                      ),
                    );
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Image
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              image: DecorationImage(
                                image: AssetImage(property.images.first),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 12),
                      // Titre
                      Text(
                        property.title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: _darkColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4),
                      // Localisation
                      Row(
                        children: [
                          Icon(Icons.location_on_outlined, size: 14, color: _greyColor),
                          SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              property.address.split(',').first,
                              style: TextStyle(
                                color: _greyColor,
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      // Prix
                      Text(
                        property.isForRent
                            ? '${property.price.toInt()}\$/mois'
                            : '${property.price.toInt()}\$',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: _primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildContactButton() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton(
          onPressed: () {
            // Action pour organiser une visite
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: _primaryColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: EdgeInsets.symmetric(vertical: 16),
            elevation: 3,
            shadowColor: _primaryColor.withOpacity(0.3),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.calendar_today_rounded, size: 20), // Icône de calendrier
              SizedBox(width: 8),
              Text(
                'ORGANISER UNE VISITE', // Texte modifié
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  void _shareProperty() {
    // Implémentez le partage ici
  }
}