import 'package:casa/screens/FullScreenImageViewer.dart';
import 'package:casa/screens/FullScreenProfileImage.dart' hide FullScreenImageViewer;
import 'package:casa/utils/Constantes.dart';
import 'package:casa/utils/FavoriteEartIcon.dart';
import 'package:casa/utils/Routes.dart';
import 'package:casa/utils/StockageKeys.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get_storage/get_storage.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/PropertyModel.dart';
import '../models/PropertyImageModel.dart';
import '../models/PropertyFeatureModel.dart';
import '../utils/FancyNotification.dart';

class PropertyDetailPage extends StatefulWidget {
  final PropertyModel property;
  const PropertyDetailPage({Key? key, required this.property}) : super(key: key);

  @override
  _PropertyDetailPageState createState() => _PropertyDetailPageState();
}

class _PropertyDetailPageState extends State<PropertyDetailPage> {
  final Color _primaryColor = Color(0xFF1976D2);
  final Color _secondaryColor = Color(0xFF64B5F6);
  final Color _darkColor = Color(0xFF2D3748);
  final Color _lightColor = Color(0xFFF8F9FA);
  final Color _greyColor = Color(0xFF6C757D);
  final Color _accentColor = Color(0xFFFF6B35);
  final GetStorage storage = GetStorage();

  bool _showMoreFeatures = false;
  bool _showAllImages = false;
  final _favoriteController = ValueNotifier<bool>(false);
  late final PageController _imageController;
  int _currentImageIndex = 0;

  bool get _showSurface => (widget.property.surface ?? 0) > 0;
  bool get _showFloor => (widget.property.floor ?? 0) > 0;
  bool get _isAvailable => widget.property.transactionType?.toLowerCase() != 'vente' &&
      widget.property.transactionType?.toLowerCase() != 'location';

  final List<ImageCategory> _imageCategories = [
    ImageCategory(
      id: 'propertyImage',
      name: 'Photos principales',
      icon: FontAwesomeIcons.home,
      color: Color(0xFF2196F3),
    ),
    ImageCategory(
      id: 'propertyImageRoom',
      name: 'Chambres',
      icon: FontAwesomeIcons.bed,
      color: Color(0xFFFF9800),
    ),
    ImageCategory(
      id: 'propertyImageLivingRoom',
      name: 'Salon',
      icon: FontAwesomeIcons.couch,
      color: Color(0xFF2196F3),
    ),
    ImageCategory(
      id: 'propertyImageKitchen',
      name: 'Cuisine',
      icon: FontAwesomeIcons.kitchenSet,
      color: Color(0xFFFF9800),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _imageController = PageController(viewportFraction: 1.0);
    _favoriteController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _imageController.dispose();
    _favoriteController.dispose();
    super.dispose();
  }

  // Grouper les images par catégorie avec le bon typage
  // Grouper les images par catégorie avec le bon typage
  Map<String, List<PropertyImageModel>> _getGroupedImages() {
    final groupedImages = <String, List<PropertyImageModel>>{};

    // Initialiser toutes les catégories
    for (var category in _imageCategories) {
      groupedImages[category.id] = [];
    }

    // Grouper les images principales
    if (widget.property.propertyImage != null) {
      groupedImages['propertyImage'] = widget.property.propertyImage!;
    }

    // Grouper les images des chambres
    if (widget.property.propertyImageRoom != null) {
      groupedImages['propertyImageRoom'] = widget.property.propertyImageRoom!
          .map((roomImage) => PropertyImageModel(path: roomImage.path))
          .toList();
    }

    // Grouper les images du salon
    if (widget.property.propertyImageLivingRoom != null) {
      groupedImages['propertyImageLivingRoom'] = widget.property.propertyImageLivingRoom!
          .map((livingRoomImage) => PropertyImageModel(path: livingRoomImage.path))
          .toList();
    }

    // Grouper les images de la cuisine
    if (widget.property.propertyImageKitchen != null) {
      groupedImages['propertyImageKitchen'] = widget.property.propertyImageKitchen!
          .map((kitchenImage) => PropertyImageModel(path: kitchenImage.path))
          .toList();
    }

    // Retirer les catégories vides
    groupedImages.removeWhere((key, value) => value.isEmpty);

    return groupedImages;
  }

  // Obtenir toutes les images pour le carousel principal
  // Obtenir toutes les images pour le carousel principal
  List<PropertyImageModel> _getAllImages() {
    final allImages = <PropertyImageModel>[];

    if (widget.property.propertyImage != null) {
      allImages.addAll(widget.property.propertyImage!);
    }
    if (widget.property.propertyImageRoom != null) {
      // Ne pas caster, mais extraire les PropertyImageModel
      allImages.addAll(widget.property.propertyImageRoom!.map((roomImage) =>
          PropertyImageModel(
            path: roomImage.path,
            // Ajoutez d'autres propriétés nécessaires selon votre modèle
          )));
    }
    if (widget.property.propertyImageLivingRoom != null) {
      allImages.addAll(widget.property.propertyImageLivingRoom!.map((livingRoomImage) =>
          PropertyImageModel(
            path: livingRoomImage.path,
            // Ajoutez d'autres propriétés nécessaires selon votre modèle
          )));
    }
    if (widget.property.propertyImageKitchen != null) {
      allImages.addAll(widget.property.propertyImageKitchen!.map((kitchenImage) =>
          PropertyImageModel(
            path: kitchenImage.path,
            // Ajoutez d'autres propriétés nécessaires selon votre modèle
          )));
    }

    return allImages;
  }

  @override
  @override
  Widget build(BuildContext context) {
    final groupedImages = _getGroupedImages();
    final allImages = _getAllImages();

    return Scaffold(
      backgroundColor: _lightColor,
      extendBody: true,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _buildImageCarousel(allImages),
          ),
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                SizedBox(height: 20),
                _buildHeaderSection(),
                SizedBox(height: 20),
                _buildPriceSection(),
                SizedBox(height: 20),
                _buildPublicationInfoSection(),
                SizedBox(height: 20),
                _buildFeaturesSection(),
                SizedBox(height: 20),
                _buildEssentialServicesSection(),
                SizedBox(height: 20),
                _buildDescriptionSection(),
                SizedBox(height: 20),
                _buildGroupedImagesSection(groupedImages),
                SizedBox(height: 20),
                _buildAdditionalFeaturesSection(),
                SizedBox(height: 20),
                _buildLocationSection(),
                SizedBox(height: 20),
                _buildSimilarProperties(),
                SizedBox(height: 100),
              ]),
            ),
          ),
        ],
      ),
      bottomSheet: _buildBottomActionBar(),
    );
  }

  Widget _buildImageCarousel(List<PropertyImageModel> images) {
    final carouselHeight = MediaQuery.of(context).size.height * 0.4;

    Future<void> _shareProperty() async {
      final firstImageUrl = images.isNotEmpty
          ? '${images.first.path ?? images.first.path}'
          : null;

      bool isForRent = widget.property.transactionType?.toLowerCase().contains('location') ?? false;

      final priceText = isForRent
          ? '${widget.property.price?.toStringAsFixed(0) ?? '0'}\$/mois'
          : '${widget.property.price?.toStringAsFixed(0) ?? '0'}\$';

      final shareText = '''
        🏠 ${widget.property.title ?? 'Belle propriété'} - ${widget.property.address ?? ''}
        
        💰 ${priceText}
        🛏️ ${widget.property.bedrooms ?? 0} chambres
        🚿 ${widget.property.bathroom ?? 0} salles de bain
        📐 ${widget.property.surface ?? 0} m²
        
        Découvrez plus de détails sur Yinzo!
''';

      try {
        final box = context.findRenderObject() as RenderBox?;
        await Share.share(
          shareText,
          subject: 'Propriété ${isForRent ? 'à louer' : 'à vendre'}',
          sharePositionOrigin: box!.localToGlobal(Offset.zero) & box.size ?? Rect.zero,
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur lors du partage: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }

    return Stack(
      children: [
        SizedBox(
          height: carouselHeight,
          child: PageView.builder(
            controller: _imageController,
            itemCount: images.length,
            onPageChanged: (index) {
              setState(() => _currentImageIndex = index);
            },
            itemBuilder: (context, index) {
              final image = images[index];
              final imagePath = image.path ?? image.path ?? '';
              final correctedPath = imagePath.startsWith('/')
                  ? imagePath.substring(1)
                  : imagePath;
              final imageUrl = '${correctedPath}';

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FullScreenImageViewer(
                        images: images,
                        initialIndex: index,
                      ),
                    ),
                  );
                },
                child: Hero(
                  tag: 'property_image_${widget.property.propertyId}_$index',
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
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
                        child: Icon(
                          Icons.broken_image,
                          color: Colors.grey[400],
                          size: 40,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // Gradient overlay
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            height: 100,
            decoration: BoxDecoration(
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

        // Page indicator
        if (images.length > 1)
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Center(
              child: SmoothPageIndicator(
                controller: _imageController,
                count: images.length,
                effect: ScrollingDotsEffect(
                  activeDotColor: Colors.white,
                  dotColor: Colors.white.withOpacity(0.5),
                  dotHeight: 8,
                  dotWidth: 8,
                  spacing: 6,
                ),
              ),
            ),
          ),

        // Back button
        Positioned(
          top: 50,
          left: 20,
          child: _buildActionButton(
            icon: Icons.arrow_back,
            onPressed: () => Navigator.pop(context),
          ),
        ),

        // Action buttons
        Positioned(
          top: 50,
          right: 20,
          child: Row(
            children: [
              // Share button
              _buildActionButton(
                icon: Icons.share,
                onPressed: _shareProperty,
              ),
              const SizedBox(width: 12),
              // Favorite button
              // if (widget.property.propertyId != null)
              //   FavoriteHeartIcon(
              //     propertyId: widget.property.propertyId.toString(),
              //     size: 32,
              //     splashRadius: 24,
              //     activeColor: Colors.red,
              //     inactiveColor: Colors.white,
              //   ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGroupedImagesSection(Map<String, List<PropertyImageModel>> groupedImages) {
    if (groupedImages.isEmpty) return SizedBox();

    final displayedCategories = _showAllImages
        ? groupedImages.entries.toList()
        : groupedImages.entries.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Galerie par pièces',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _darkColor,
              ),
            ),
            if (groupedImages.length > 3)
              TextButton(
                onPressed: () {
                  setState(() {
                    _showAllImages = !_showAllImages;
                  });
                },
                child: Text(
                  _showAllImages ? 'Voir moins' : 'Voir tout',
                  style: TextStyle(
                    color: _primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        SizedBox(height: 16),
        ...displayedCategories.map((entry) {
          final categoryId = entry.key;
          final images = entry.value;
          final category = _imageCategories.firstWhere(
                (cat) => cat.id == categoryId,
            orElse: () => _imageCategories.first,
          );

          return _buildImageCategoryCard(category, images);
        }),
      ],
    );
  }

  Widget _buildImageCategoryCard(ImageCategory category, List<PropertyImageModel> images) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
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
          // En-tête de la catégorie
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: category.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    category.icon,
                    color: category.color,
                    size: 20,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: _darkColor,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '${images.length} photo(s)',
                        style: TextStyle(
                          color: _greyColor,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: category.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${images.length}',
                    style: TextStyle(
                      color: category.color,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Grille d'images
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: GridView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1,
              ),
              itemCount: images.length > 6 ? 6 : images.length,
              itemBuilder: (context, index) {
                final image = images[index];
                final imagePath = image.path ?? image.path ?? '';
                final correctedPath = imagePath.startsWith('/')
                    ? imagePath.substring(1)
                    : imagePath;
                final imageUrl = '${correctedPath}';

                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => FullScreenImageViewer(
                          images: images,
                          initialIndex: index,
                        ),
                      ),
                    );
                  },
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          placeholder: (context, url) => Container(
                            color: Colors.grey[200],
                            child: Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(category.color),
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: Colors.grey[200],
                            child: Icon(
                              Icons.photo,
                              color: Colors.grey[400],
                            ),
                          ),
                        ),
                      ),
                      if (index == 5 && images.length > 6)
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              '+${images.length - 6}',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Bouton "Voir plus" si plus de 6 images
          if (images.length > 6)
            Padding(
              padding: EdgeInsets.all(16),
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FullScreenImageViewer(
                        images: images,
                        initialIndex: 0,
                        categoryName: category.name,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: category.color.withOpacity(0.1),
                  foregroundColor: category.color,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                ),
                icon: Icon(Icons.photo_library, size: 18),
                label: Text(
                  'Voir toutes les photos ${category.name.toLowerCase()}',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    Color iconColor = Colors.white,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.4),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: iconColor,
            size: 24,
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    final isForRent = widget.property.transactionType?.toLowerCase().contains('location') ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          children: [
            Chip(
              backgroundColor: _primaryColor.withOpacity(0.1),
              label: Text(
                isForRent ? 'À LOUER' : 'À VENDRE',
                style: TextStyle(
                  color: _primaryColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              shape: StadiumBorder(),
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            ),
            if (widget.property.propertyTypeId != null)
              Chip(
                backgroundColor: _secondaryColor.withOpacity(0.1),
                label: Text(
                  _getPropertyTypeText(widget.property.propertyTypeId!),
                  style: TextStyle(
                    color: _secondaryColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                shape: StadiumBorder(),
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              ),
          ],
        ),
        SizedBox(height: 16),
        Text(
          widget.property.title ?? 'Sans titre',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: _darkColor,
            height: 1.3,
          ),
        ),
        SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.location_on_outlined, size: 18, color: _greyColor),
            SizedBox(width: 6),
            Expanded(
              child: Text(
                widget.property.address ?? "Adresse non disponible",
                style: TextStyle(
                  color: _greyColor,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _getPropertyTypeText(int propertyTypeId) {
    switch (propertyTypeId) {
      case 1: return 'Studio';
      case 2: return 'Appartement';
      case 3: return 'Maison';
      case 4: return 'Bureau';
      case 5: return 'Hôtel';
      case 6: return 'Résidence vacances';
      default: return 'Propriété';
    }
  }

  Widget _buildPriceSection() {
    final isForRent = widget.property.transactionType?.toLowerCase().contains('location') ?? false;

    return Container(
      padding: EdgeInsets.all(16),
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
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PRIX',
                style: TextStyle(
                  fontSize: 12,
                  color: _greyColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    '${widget.property.price?.toInt() ?? 0}\$',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: _primaryColor,
                    ),
                  ),
                  if (isForRent)
                    Text(
                      ' /mois',
                      style: TextStyle(
                        fontSize: 14,
                        color: _greyColor,
                      ),
                    ),
                ],
              ),
            ],
          ),
          Spacer(),
          if (_showSurface)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'SURFACE',
                  style: TextStyle(
                    fontSize: 12,
                    color: _greyColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '${widget.property.surface?.toInt() ?? 0} m²',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: _darkColor,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
  Widget _buildFeaturesSection() {
    final hasWifi = widget.property.features?.any((f) => f.name?.toLowerCase().contains('wifi') ?? false) ?? false;
    final hasClim = widget.property.features?.any((f) => f.name?.toLowerCase().contains('climatisation') ?? false) ?? false;
    final hasParking = widget.property.features?.any((f) => f.name?.toLowerCase().contains('parking') ?? false) ?? false;

    // Créer une liste dynamique des éléments à afficher
    final featureItems = <Widget>[
      _buildFeatureItem(
        'assets/images/bed.png',
        '${widget.property.bedrooms ?? 0}',
        'Chambres',
      ),
      _buildFeatureItem(
        'assets/images/douche.png',
        '${widget.property.bathroom ?? 0}',
        'SDB',
      ),
      _buildFeatureItem(
        'assets/images/parking.png',
        hasParking ? 'Oui' : 'Non',
        'Parking',
      ),
    ];

    // Ajouter l'étage seulement si > 0
    if (_showFloor) {
      featureItems.add(
        _buildFeatureItem(
          'assets/images/wifi.png',
          '${widget.property.floor ?? 0}',
          'Étage',
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(16),
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
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: featureItems,
          ),
          SizedBox(height: 12),
          Divider(height: 1),
          SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildFeatureItem(
                'assets/images/salon.png',
                '${widget.property.livingRoom ?? 0}',
                'Salons',
              ),
              _buildFeatureItem(
                'assets/images/quisine.png',
                '${widget.property.kitchen ?? 0}',
                'Cuisine',
              ),
              _buildFeatureItem(
                'assets/images/wifi.png',
                hasWifi ? 'Oui' : 'Non',
                'Wi-Fi',
              ),
              _buildFeatureItem(
                'assets/images/clim.png',
                hasClim ? 'Oui' : 'Non',
                'Clim',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(String imagePath, String value, String label) {
    return Column(
      children: [
        Container(
          width: 45,
          height: 45,
          decoration: BoxDecoration(
            color: _primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Image.asset(
              imagePath,
              width: 40,
              height: 40,
              fit: BoxFit.contain,
            ),
          ),
        ),
        SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: _darkColor,
          ),
        ),
        SizedBox(height: 2),
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
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: _darkColor,
          ),
        ),
        SizedBox(height: 12),
        Text(
          widget.property.description ?? "Aucune description disponible",
          style: TextStyle(
            color: _darkColor.withOpacity(0.8),
            fontSize: 15,
            height: 1.6,
          ),
        ),
      ],
    );
  }

  Widget _buildPublicationInfoSection() {
    return Container(
      padding: EdgeInsets.all(16),
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
          // Informations du publieur
          if (widget.property.user?.email != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Publié par',
                  style: TextStyle(
                    fontSize: 14,
                    color: _greyColor,
                  ),
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    // Photo de profil
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: widget.property.user?.email != null
                          ? ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: CachedNetworkImage(
                          imageUrl: "dedde",
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
                            ),
                          ),
                          errorWidget: (context, url, error) => Icon(
                            Icons.person,
                            color: _primaryColor,
                            size: 20,
                          ),
                        ),
                      )
                          : Icon(
                        Icons.person,
                        color: _primaryColor,
                        size: 20,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "${widget.property}",
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              color: _darkColor,
                            ),
                          ),
                          if (widget.property.createdStart != null)
                            Text(
                              'Publié ${_formatDate(widget.property.createdStart!)}',
                              style: TextStyle(
                                color: _greyColor,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }


  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays == 0) {
        return "aujourd'hui";
      } else if (difference.inDays == 1) {
        return 'hier';
      } else if (difference.inDays < 7) {
        return 'il y a ${difference.inDays} jours';
      } else if (difference.inDays < 30) {
        final weeks = (difference.inDays / 7).floor();
        return 'il y a $weeks semaine${weeks > 1 ? 's' : ''}';
      } else {
        return 'le ${DateFormat('dd/MM/yyyy').format(date)}';
      }
    } catch (e) {

      return dateString;
    }
  }

  // String _formatDate(DateTime date) {
  //   final now = DateTime.now();
  //   final difference = now.difference(date);
  //
  //   if (difference.inDays == 0) {
  //     return "aujourd'hui";
  //   } else if (difference.inDays == 1) {
  //     return 'hier';
  //   } else if (difference.inDays < 7) {
  //     return 'il y a ${difference.inDays} jours';
  //   } else if (difference.inDays < 30) {
  //     final weeks = (difference.inDays / 7).floor();
  //     return 'il y a $weeks semaine${weeks > 1 ? 's' : ''}';
  //   } else {
  //     return 'le ${DateFormat('dd/MM/yyyy').format(date)}';
  //   }
  // }

  Widget _buildAdditionalFeaturesSection() {
    final hasElevator = widget.property.features?.any((f) => f.name?.toLowerCase().contains('ascenseur') ?? false) ?? false;
    final hasPool = widget.property.features?.any((f) => f.name?.toLowerCase().contains('piscine') ?? false) ?? false;
    final hasGarden = widget.property.features?.any((f) => f.name?.toLowerCase().contains('jardin') ?? false) ?? false;
    final hasTerrace = widget.property.features?.any((f) => f.name?.toLowerCase().contains('terrasse') ?? false) ?? false;

    final features = {
      'Chambres': '${widget.property.bedrooms ?? 0}',
      'Salles de bain': '${widget.property.bathroom ?? 0}',
      'Surface': '${widget.property.surface ?? 0} m²',
      'Étage': '${widget.property.floor ?? 0}',
      'Ascenseur': hasElevator ? 'Oui' : 'Non',
      'Piscine': hasPool ? 'Oui' : 'Non',
      'Jardin': hasGarden ? 'Oui' : 'Non',
      'Terrasse': hasTerrace ? 'Oui' : 'Non',
    };

    final displayedFeatures = _showMoreFeatures
        ? features.entries.toList()
        : features.entries.take(4).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _showMoreFeatures = !_showMoreFeatures),
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Colors.grey.withOpacity(0.2),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Caractéristiques détaillées',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _darkColor,
                  ),
                ),
                Icon(
                  _showMoreFeatures ? Icons.expand_less : Icons.expand_more,
                  color: _greyColor,
                ),
              ],
            ),
          ),
        ),
        if (_showMoreFeatures) ...[
          SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: displayedFeatures.map((e) => Container(
              width: (MediaQuery.of(context).size.width - 64) / 2,
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.withOpacity(0.1)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: _primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Image.asset("assets/images/check.png", width: 16, height: 20),
                    ),
                  ),
                  SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        e.key,
                        style: TextStyle(
                          color: _greyColor,
                          fontSize: 12,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        e.value,
                        style: TextStyle(
                          color: _darkColor,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            )).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildLocationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Localisation',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: _darkColor,
          ),
        ),
        SizedBox(height: 16),
        Container(
          height: 200,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.grey[200],
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.map, size: 40, color: _greyColor),
                SizedBox(height: 8),
                Text(
                  'Carte non disponible',
                  style: TextStyle(color: _greyColor),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 16),
        Row(
          children: [
            Icon(Icons.location_on, size: 20, color: _primaryColor),
            SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.property.address ?? "Adresse non disponible",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '${widget.property.quartier ?? ''}, ${widget.property.communeId ?? ''}',
                    style: TextStyle(
                      color: _greyColor,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSimilarProperties() {
    // Cette section peut être remplie avec des données réelles plus tard
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Propriétés similaires',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: _darkColor,
          ),
        ),
        SizedBox(height: 16),
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: Text(
              'Aucune propriété similaire pour le moment',
              style: TextStyle(color: _greyColor),
            ),
          ),
        ),
      ],
    );
  }

  // Dans la classe _PropertyDetailPageState, ajoutez ces méthodes :

  String _getElectricText(int? electricValue) {
    if (electricValue == null) return 'Non spécifié';

    switch (electricValue) {
      case 80:
        return 'Élevée - Coupe rarement';
      case 60:
        return 'Bonne - Quelques coupures';
      case 40:
        return 'Moyenne - Coupures régulières';
      case 20:
        return 'Faible - Coupe souvent';
      default:
        return 'Non spécifié';
    }
  }

  String _getWaterText(int? waterValue) {
    if (waterValue == null) return 'Non spécifié';

    switch (waterValue) {
      case 80:
        return 'Excellente - Coupures très rares';
      case 60:
        return 'Bonne - Quelques coupures';
      case 40:
        return 'Moyenne - Coupures régulières';
      case 20:
        return 'Faible - Coupures fréquentes';
      default:
        return 'Non spécifié';
    }
  }

  Widget _buildEssentialServicesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Services essentiels',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: _darkColor,
          ),
        ),
        SizedBox(height: 16),

        // Service Électricité
        Container(
          margin: EdgeInsets.only(bottom: 12),
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: _getServiceColor(widget.property.electric).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.electrical_services_rounded,
                  color: _getServiceColor(widget.property.electric),
                  size: 24,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Électricité',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: _darkColor,
                          ),
                        ),
                        Spacer(),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getServiceColor(widget.property.electric).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _getServiceColor(widget.property.electric).withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            _getServicePercentage(widget.property.electric),
                            style: TextStyle(
                              color: _getServiceColor(widget.property.electric),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      _getElectricText(widget.property.electric),
                      style: TextStyle(
                        color: _greyColor,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Service Eau
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: _getServiceColor(widget.property.water).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.water_drop_rounded,
                  color: _getServiceColor(widget.property.water),
                  size: 24,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Eau',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: _darkColor,
                          ),
                        ),
                        Spacer(),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getServiceColor(widget.property.water).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _getServiceColor(widget.property.water).withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            _getServicePercentage(widget.property.water),
                            style: TextStyle(
                              color: _getServiceColor(widget.property.water),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      _getWaterText(widget.property.water),
                      style: TextStyle(
                        color: _greyColor,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _getServiceColor(int? value) {
    if (value == null) return _greyColor;

    if (value >= 80) return Colors.green;
    if (value >= 60) return Colors.lightGreen;
    if (value >= 40) return Colors.orange;
    return Colors.red;
  }

  String _getServicePercentage(int? value) {
    if (value == null) return '?%';
    return '$value%';
  }



  void _navigateToBookingPage() {
    final token = storage.read(StockageKeys.tokenKey);
    if (token == null) {
      FancyNotification.show(
        context,
        "Vous devez être connecté pour planifier une visite",
      );
    } else {
      Navigator.pushNamed(
          context,
          Routes.bookingVisitPageRoute,
          arguments: widget.property
      );
    }
  }

  Widget _buildBottomActionBar() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, -5),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _navigateToBookingPage,
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: EdgeInsets.symmetric(vertical: 16),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today, size: 20),
            SizedBox(width: 8),
            Text(
              'PLANIFIER UNE VISITE',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ImageCategory {
  final String id;
  final String name;
  final IconData icon;
  final Color color;

  ImageCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
  });
}