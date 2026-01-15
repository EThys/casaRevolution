import 'package:casa/screens/FullScreenImageViewer.dart';
import 'package:casa/screens/auth/LoginScreen.dart';
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
import 'dart:async';
import 'package:provider/provider.dart';
import '../controllers/PropertyCtrl.dart';
import '../controllers/AuthentificationCtrl.dart';
import '../controllers/provider/FavoriteProvider.dart';

class PropertyDetailPage extends StatefulWidget {
  final PropertyModel property;
  final String? heroTag;
  
  const PropertyDetailPage({
    Key? key, 
    required this.property,
    this.heroTag,
  }) : super(key: key);

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
  bool _isDescriptionExpanded = false;
  final _favoriteController = ValueNotifier<bool>(false);
  late final PageController _imageController;
  int _currentImageIndex = 0;
  Timer? _autoScrollTimer;

  bool get _showSurface {
    final surface = widget.property.surface;
    return surface != null && surface > 0;
  }
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
    // Démarrer le défilement automatique après l'initialisation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startAutoScroll();
      // Charger la propriété et ses similaires depuis l'API détail
      final ctrl = context.read<PropertyController>();
      if (widget.property.propertyId != null) {
        ctrl.getPropertyById(widget.property.propertyId!);
        
        // SYNC: Vérifier l'état du favori pour cette propriété
        final authCtrl = context.read<AuthentificationCtrl>();
        if (authCtrl.token.isNotEmpty && authCtrl.user.userId != null) {
          context.read<FavoriteProvider>().syncFavorites(authCtrl.user.userId.toString());
        }
      }
    });
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _imageController.dispose();
    _favoriteController.dispose();
    super.dispose();
  }

  // Défilement automatique du carousel d'images
  void _startAutoScroll() {
    final allImages = _getAllImages();
    if (allImages.length <= 1) return; // Pas besoin de défilement si une seule image

    _autoScrollTimer?.cancel(); // Annuler le timer existant s'il y en a un
    
    _autoScrollTimer = Timer.periodic(Duration(seconds: 3), (timer) {
      if (!mounted || !_imageController.hasClients) {
        timer.cancel();
        return;
      }
      
      final nextIndex = (_currentImageIndex + 1) % allImages.length;
      _imageController.animateToPage(
        nextIndex,
        duration: Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  // Grouper les images par catégorie
  Map<String, List<PropertyImageModel>> _getGroupedImages() {
    final groupedImages = <String, List<PropertyImageModel>>{};

    // Initialiser toutes les catégories
    for (var category in _imageCategories) {
      groupedImages[category.id] = [];
    }

    // Grouper les images principales
    if (widget.property.propertyImage != null && widget.property.propertyImage!.isNotEmpty) {
      groupedImages['propertyImage'] = widget.property.propertyImage!;
    }

    // Grouper les images des chambres
    if (widget.property.propertyImageRoom != null && widget.property.propertyImageRoom!.isNotEmpty) {
      groupedImages['propertyImageRoom'] = widget.property.propertyImageRoom!
          .map((roomImage) => PropertyImageModel(path: roomImage.path))
          .toList();
    }

    // Grouper les images du salon
    if (widget.property.propertyImageLivingRoom != null && widget.property.propertyImageLivingRoom!.isNotEmpty) {
      groupedImages['propertyImageLivingRoom'] = widget.property.propertyImageLivingRoom!
          .map((livingRoomImage) => PropertyImageModel(path: livingRoomImage.path))
          .toList();
    }

    // Grouper les images de la cuisine
    if (widget.property.propertyImageKitchen != null && widget.property.propertyImageKitchen!.isNotEmpty) {
      groupedImages['propertyImageKitchen'] = widget.property.propertyImageKitchen!
          .map((kitchenImage) => PropertyImageModel(path: kitchenImage.path))
          .toList();
    }

    // Retirer les catégories vides
    groupedImages.removeWhere((key, value) => value.isEmpty);

    return groupedImages;
  }

  // Obtenir toutes les images pour le carousel principal
  List<PropertyImageModel> _getAllImages() {
    final allImages = <PropertyImageModel>[];

    if (widget.property.propertyImage != null && widget.property.propertyImage!.isNotEmpty) {
      allImages.addAll(widget.property.propertyImage!);
    }
    if (widget.property.propertyImageRoom != null && widget.property.propertyImageRoom!.isNotEmpty) {
      allImages.addAll(widget.property.propertyImageRoom!.map((roomImage) =>
          PropertyImageModel(path: roomImage.path)));
    }
    if (widget.property.propertyImageLivingRoom != null && widget.property.propertyImageLivingRoom!.isNotEmpty) {
      allImages.addAll(widget.property.propertyImageLivingRoom!.map((livingRoomImage) =>
          PropertyImageModel(path: livingRoomImage.path)));
    }
    if (widget.property.propertyImageKitchen != null && widget.property.propertyImageKitchen!.isNotEmpty) {
      allImages.addAll(widget.property.propertyImageKitchen!.map((kitchenImage) =>
          PropertyImageModel(path: kitchenImage.path)));
    }

    return allImages;
  }

  @override
  Widget build(BuildContext context) {
    final groupedImages = _getGroupedImages();
    final allImages = _getAllImages();
    final similar = context.watch<PropertyController>().similarProperties;

    return Scaffold(
      backgroundColor: _lightColor,
      extendBody: true,
      body: CustomScrollView(
        physics: ClampingScrollPhysics(), // Empêche l'effet de rebond blanc
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
                SizedBox(height: 16),
                _buildAnimatedStatsSection(),
                SizedBox(height: 16),
                _buildHighlightsSection(),
                SizedBox(height: 16),
                _buildDetailedCharacteristicsSection(),
                SizedBox(height: 16),
                _buildPublicationInfoSection(),
                SizedBox(height: 16),
                _buildDescriptionSection(),
                SizedBox(height: 16),
                _buildAdditionalFeaturesSection(),
                SizedBox(height: 16),
                _buildEssentialServicesSection(),
                SizedBox(height: 16),
                _buildLocationPreview(),
                SizedBox(height: 16),
                if (groupedImages.isNotEmpty) _buildGroupedImagesSection(groupedImages),
                SizedBox(height: 16),
                _buildSimilarProperties(similar),
                SizedBox(height: 24),
                _buildBottomActionBar(), // Moved from bottomSheet
                SizedBox(height: 40),
              ].where((widget) => widget != null).toList()),
            ),
          ),
        ],
      ),
      // bottomSheet: _buildBottomActionBar(), // Removed
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
          ? '${widget.property.price?.toStringAsFixed(0) ?? '0'} ${widget.property.currency}/mois'
          : '${widget.property.price?.toStringAsFixed(0) ?? '0'} ${widget.property.currency}';

      final surfaceText = _showSurface ? '📐 ${widget.property.surface?.toInt() ?? 0} m²' : '';
      
      final shareText = '''
        🏠 ${widget.property.title ?? 'Belle propriété'} - ${widget.property.address ?? ''}
        
        💰 ${priceText}
        🛏️ ${widget.property.bedrooms ?? 0} chambres
        🚿 ${widget.property.bathroom ?? 0} salles de bain
        ${surfaceText.isNotEmpty ? '$surfaceText\n' : ''}
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
              // Redémarrer le timer après chaque changement de page
              _startAutoScroll();
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
                  tag: index == 0 && widget.heroTag != null 
                      ? widget.heroTag! 
                      : 'property_image_${widget.property.propertyId}_$index',
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
              // Favorite button
              if (widget.property.propertyId != null)
                Material(
                  color: Colors.transparent,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                      shape: BoxShape.circle,
                    ),
                    child: FavoriteHeartIcon(
                      propertyId: widget.property.propertyId.toString(),
                      propertyTypeId: widget.property.propertyTypeId, // Pass propertyTypeId
                      size: 24,
                      splashRadius: 20,
                      activeColor: Colors.red,
                      inactiveColor: Colors.white,
                    ),
                  ),
                ),
              const SizedBox(width: 12),
              // Share button
              _buildActionButton(
                icon: Icons.share,
                onPressed: _shareProperty,
              ),
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
    final isAvailable = widget.property.available ?? true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
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
                  _getPropertyTypeFromTitle(widget.property.propertyType?.name),
                  style: TextStyle(
                    color: _secondaryColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                shape: StadiumBorder(),
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              ),
            // Availability badge
            Chip(
              backgroundColor: isAvailable 
                  ? Colors.green.withOpacity(0.1) 
                  : Colors.red.withOpacity(0.1),
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isAvailable ? Icons.check_circle : Icons.cancel,
                    size: 14,
                    color: isAvailable ? Colors.green : Colors.red,
                  ),
                  SizedBox(width: 4),
                  Text(
                    isAvailable ? 'DISPONIBLE' : 'OCCUPÉ',
                    style: TextStyle(
                      color: isAvailable ? Colors.green : Colors.red,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
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
                (widget.property.address != null && widget.property.address!.isNotEmpty)
                    ? widget.property.address!
                    : "Adresse non disponible",
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

  String _getPropertyTypeFromTitle(String? title) {
    // 1. D'abord vérifier le propertyTypeId si disponible
    final typeId = widget.property.propertyTypeId;
    if (typeId != null) {
      if (typeId == 1) return 'Studio';
      if (typeId == 2) return 'Appartement';
      if (typeId == 3) return 'Maison';
      if (typeId == 4) return 'Bureau'; 
      if (typeId == 5) return 'Hotel';
      if (typeId == 6) return 'Chambre';
      if (typeId == 7) return 'Espace Funéraire';
      if (typeId == 8) return 'Salle de fête';
      if (typeId == 9) return 'Terrain';
      if (typeId == 10) return 'Entrepôt';
    }

    // 2. Fallback sur le titre si propertyTypeId est manquant
    if (title == null) return 'Propriété';
    final lowerTitle = title.toLowerCase();
    
    if (lowerTitle.contains('appart')) return 'Appartement';
    if (lowerTitle.contains('maison')) return 'Maison';
    if (lowerTitle.contains('studio')) return 'Studio';
    if (lowerTitle.contains('villa')) return 'Villa';
    if (lowerTitle.contains('bureau')) return 'Bureau';
    if (lowerTitle.contains('hotel')) return 'Hotel';
    if (lowerTitle.contains('fête') || lowerTitle.contains('fete')) return 'Salle de fête';
    if (lowerTitle.contains('funéra') || lowerTitle.contains('deuil')) return 'Espace Funéraire';
    if (lowerTitle.contains('terrain') || lowerTitle.contains('parcelle')) return 'Terrain';
    
    return 'Propriété';
  }

  Widget _buildPriceSection() {
    final isForRent = widget.property.transactionType?.toLowerCase().contains('location') ?? false;

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _primaryColor.withOpacity(0.05),
            _secondaryColor.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _primaryColor.withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withOpacity(0.1),
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.attach_money,
                      size: 16,
                      color: _primaryColor,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'PRIX',
                      style: TextStyle(
                        fontSize: 12,
                        color: _greyColor,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${widget.property.price?.toInt() ?? 0}',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: _primaryColor,
                        height: 1,
                      ),
                    ),
                    Text(
                      widget.property.currency ?? '\$',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: _primaryColor,
                      ),
                    ),
                    if (isForRent)
                      Padding(
                        padding: EdgeInsets.only(left: 4, bottom: 2),
                        child: Text(
                          '/mois',
                          style: TextStyle(
                            fontSize: 14,
                            color: _greyColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (_showSurface)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.square_foot,
                        size: 16,
                        color: _darkColor,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'SURFACE',
                        style: TextStyle(
                          fontSize: 12,
                          color: _greyColor,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${widget.property.surface?.toInt() ?? 0}',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: _darkColor,
                          height: 1,
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.only(left: 2, bottom: 2),
                        child: Text(
                          'm²',
                          style: TextStyle(
                            fontSize: 14,
                            color: _greyColor,
                            fontWeight: FontWeight.w500,
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
    );
  }

  Widget _buildFeaturesSection() {
    final hasWifi = widget.property.features?.any((f) => f.name?.toLowerCase().contains('wifi') ?? false) ?? false;
    final hasClim = widget.property.features?.any((f) => f.name?.toLowerCase().contains('climatisation') ?? false) ?? false;
    final hasParking = widget.property.features?.any((f) => f.name?.toLowerCase().contains('parking') ?? false) ?? false;

    // Créer une liste dynamique des éléments à afficher avec le bon type
    final List<Widget> featureItems = <Widget>[];

    // Ajouter les chambres seulement si > 0
    if ((widget.property.bedrooms ?? 0) > 0) {
      featureItems.add(_buildFeatureItem(
        'assets/images/bed.png',
        '${widget.property.bedrooms ?? 0}',
        'Chambres',
      ));
    }

    // Ajouter les salles de bain seulement si > 0
    if ((widget.property.bathroom ?? 0) > 0) {
      featureItems.add(_buildFeatureItem(
        'assets/images/douche.png',
        '${widget.property.bathroom ?? 0}',
        'SDB',
      ));
    }

    // Ajouter l'étage seulement si > 0
    if (_showFloor) {
      featureItems.add(_buildFeatureItem(
        'assets/images/wifi.png',
        '${widget.property.floor ?? 0}',
        'Étage',
      ));
    }

    // Ajouter le parking seulement si disponible
    if (hasParking) {
      featureItems.add(_buildFeatureItem(
        'assets/images/parking.png',
        'Oui',
        'Parking',
      ));
    }

    // Si aucun élément à afficher, retourner un SizedBox
    if (featureItems.isEmpty) {
      return SizedBox();
    }

    // Répartir les éléments en deux lignes si nécessaire
    final List<Widget> firstRowItems = featureItems.length > 4
        ? featureItems.sublist(0, 4)
        : featureItems;

    final List<Widget> secondRowItems = featureItems.length > 4
        ? featureItems.sublist(4)
        : <Widget>[];

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
            children: firstRowItems,
          ),
          if (secondRowItems.isNotEmpty) ...[
            SizedBox(height: 12),
            Divider(height: 1),
            SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: secondRowItems,
            ),
          ],
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
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _primaryColor,
              width: 1,
            ),
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

  // NEW: Main Price Section
  // NEW: Main Price Section
  Widget _buildAnimatedStatsSection() {
    final isForRent = widget.property.transactionType?.toLowerCase().contains('location') ?? false;
    final price = widget.property.price?.toInt() ?? 0;
    
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: _primaryColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withOpacity(0.3),
            blurRadius: 15,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PRIX',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          SizedBox(height: 6),
          Row(
            textBaseline: TextBaseline.alphabetic,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            children: [
              Text(
                '$price',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -1,
                ),
              ),
              SizedBox(width: 4),
              Text(
                isForRent ? '\$/mois' : '\$',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // NEW: Detailed Characteristics Section
  Widget _buildDetailedCharacteristicsSection() {
    final stats = <Map<String, dynamic>>[];
    
    // Bedrooms (chambres)
    if (widget.property.bedrooms != null && widget.property.bedrooms! > 0) {
      stats.add({
        'icon': Icons.bed_outlined,
        'label': 'Chambres',
        'value': '${widget.property.bedrooms}',
        'unit': widget.property.bedrooms! > 1 ? 'chambres' : 'chambre',
        'color': Color(0xFF1976D2),
      });
    }
    
    // Living Room (salon)
    if (widget.property.livingRoom != null && widget.property.livingRoom! > 0) {
      stats.add({
        'icon': Icons.weekend_outlined,
        'label': 'Salon',
        'value': '${widget.property.livingRoom}',
        'unit': widget.property.livingRoom! > 1 ? 'salons' : 'salon',
        'color': Color(0xFF42A5F5),
      });
    }
    
    // Kitchen (cuisine)
    if (widget.property.kitchen != null && widget.property.kitchen! > 0) {
      stats.add({
        'icon': Icons.kitchen_outlined,
        'label': 'Cuisine',
        'value': '${widget.property.kitchen}',
        'unit': widget.property.kitchen! > 1 ? 'cuisines' : 'cuisine',
        'color': Color(0xFF64B5F6),
      });
    }
    
    // Bathroom (salles de bain)
    if (widget.property.bathroom != null && widget.property.bathroom! > 0) {
      stats.add({
        'icon': Icons.bathroom_outlined,
        'label': 'Salle de bain',
        'value': '${widget.property.bathroom}',
        'unit': widget.property.bathroom! > 1 ? 'SDB' : 'SDB',
        'color': Color(0xFF90CAF9),
      });
    }

    // SPECIAL FIELDS
    // Bureau
    if (widget.property.propertyTypeId == 4) {
      if (widget.property.roomMeet != null && widget.property.roomMeet! > 0) {
        stats.add({
          'icon': Icons.meeting_room_outlined,
          'label': 'Réunions',
          'value': '${widget.property.roomMeet}',
          'unit': widget.property.roomMeet! > 1 ? 'salles' : 'salle',
          'color': Color(0xFF5C6BC0),
        });
      }
      if (widget.property.isEquip != null) {
        stats.add({
          'icon': widget.property.isEquip == true ? Icons.chair : Icons.chair_outlined,
          'label': 'Meublé',
          'value': widget.property.isEquip == true ? 'Oui' : 'Non',
          'unit': widget.property.isEquip == true ? 'Équipé' : 'Vide',
          'color': Color(0xFF26A69A),
        });
      }
    }

    // Festive/Funeraire
    if (widget.property.propertyTypeId == 7 || widget.property.propertyTypeId == 8) {
      if (widget.property.capacityPeople != null && widget.property.capacityPeople! > 0) {
        stats.add({
          'icon': Icons.people_outline,
          'label': 'Capacité',
          'value': '${widget.property.capacityPeople}',
          'unit': 'pers.',
          'color': Color(0xFFEC407A),
        });
      }
      if (widget.property.propertyTypeId == 8 && widget.property.pisteDanse != null) {
          stats.add({
            'icon': Icons.music_note_outlined,
            'label': 'Piste',
            'value': widget.property.pisteDanse == true ? 'Oui' : 'Non',
            'unit': 'Danse',
            'color': Color(0xFFFF7043),
          });
      }
      if (widget.property.isDecore != null) {
          stats.add({
            'icon': Icons.auto_awesome_outlined,
            'label': 'Décoré',
            'value': widget.property.isDecore == true ? 'Oui' : 'Non',
            'unit': 'Déco',
            'color': Color(0xFFAB47BC),
          });
      }
    }

    if (stats.isEmpty) return SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Icon(
                Icons.grid_view,
                size: 18,
                color: _primaryColor,
              ),
              SizedBox(width: 8),
              Text(
                'CARACTÉRISTIQUES DÉTAILLÉES',
                style: TextStyle(
                  fontSize: 11,
                  color: _greyColor,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final double cardWidth = (constraints.maxWidth - 12) / 2;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: stats.map((stat) {
                return SizedBox(
                  width: cardWidth,
                  child: _buildModernStatCard(
                    icon: stat['icon'] as IconData,
                    label: stat['label'] as String,
                    value: stat['value'] as String,
                    unit: stat['unit'] as String,
                    color: stat['color'] as Color,
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildModernStatCard({
    required IconData icon,
    required String label,
    required String value,
    required String unit,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white,
            color.withOpacity(0.03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: color,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    color: _greyColor,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: color,
                    height: 1,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(width: 4),
              Expanded(
                child: Text(
                  unit,
                  style: TextStyle(
                    fontSize: 13,
                    color: _greyColor,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // NEW: Highlights Section
  Widget _buildHighlightsSection() {
    final highlights = <Map<String, dynamic>>[];
    
    // Add highlights based on property features
    if (widget.property.isVerified ?? false) {
      highlights.add({
        'icon': Icons.verified_outlined,
        'label': 'Vérifié',
        'color': _primaryColor,
      });
    }
    
    if ((widget.property.viewCount ?? 0) > 50) {
      highlights.add({
        'icon': Icons.trending_up,
        'label': 'Populaire',
        'color': Color(0xFF1565C0),
      });
    }
    
    final hasPool = widget.property.features?.any((f) => f.name?.toLowerCase().contains('piscine') ?? false) ?? false;
    if (hasPool) {
      highlights.add({
        'icon': Icons.pool_outlined,
        'label': 'Avec piscine',
        'color': _secondaryColor,
      });
    }
    
    final hasParking = widget.property.features?.any((f) => f.name?.toLowerCase().contains('parking') ?? false) ?? false;
    if (hasParking) {
      highlights.add({
        'icon': Icons.local_parking_outlined,
        'label': 'Parking',
        'color': Color(0xFF0288D1),
      });
    }
    
    final hasGarden = widget.property.features?.any((f) => f.name?.toLowerCase().contains('jardin') ?? false) ?? false;
    if (hasGarden) {
      highlights.add({
        'icon': Icons.yard_outlined,
        'label': 'Jardin',
        'color': Color(0xFF42A5F5),
      });
    }
    
    if (highlights.isEmpty) {
      return SizedBox();
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Icon(
                Icons.star_outline,
                size: 18,
                color: _primaryColor,
              ),
              SizedBox(width: 8),
              Text(
                'POINTS FORTS',
                style: TextStyle(
                  fontSize: 11,
                  color: _greyColor,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: highlights.map((highlight) {
              return Container(
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: (highlight['color'] as Color).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: (highlight['color'] as Color).withOpacity(0.25),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      highlight['icon'] as IconData,
                      size: 18,
                      color: highlight['color'] as Color,
                    ),
                    SizedBox(width: 8),
                    Text(
                      highlight['label'] as String,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: highlight['color'] as Color,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),

      ],
    );
  }

  // NEW: Location Preview Section
  Widget _buildLocationPreview() {
    if (widget.property.address == null || widget.property.address!.isEmpty) {
      return SizedBox();
    }
    
    return Container(
      padding: EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _greyColor.withOpacity(0.15),
          width: 1,
        ),
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
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.location_on,
                  size: 22,
                  color: _primaryColor,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'LOCALISATION',
                      style: TextStyle(
                        fontSize: 11,
                        color: _greyColor,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      widget.property.address ?? '',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: _darkColor,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (widget.property.quartierValue != null || widget.property.communeValue != null || widget.property.cityValue != null) ...[
            SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (widget.property.quartierValue != null)
                  _buildLocationChip(Icons.home_work_outlined, widget.property.quartierValue!),
                if (widget.property.communeValue != null)
                  _buildLocationChip(Icons.location_city_outlined, widget.property.communeValue!),
                if (widget.property.cityValue != null)
                  _buildLocationChip(Icons.place_outlined, widget.property.cityValue!),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLocationChip(IconData icon, String label) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _primaryColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _primaryColor.withOpacity(0.15),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: _primaryColor,
          ),
          SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _darkColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionSection() {
    final description = widget.property.description;
    if (description == null || description.isEmpty) {
      return SizedBox();
    }

    final bool isLongDescription = description.length > 200;
    final String displayText = (!_isDescriptionExpanded && isLongDescription)
        ? '${description.substring(0, 200)}...'
        : description;

    return Container(
      padding: EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _greyColor.withOpacity(0.15),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.description_outlined,
                size: 18,
                color: _primaryColor,
              ),
              SizedBox(width: 8),
              Text(
                'DESCRIPTION',
                style: TextStyle(
                  fontSize: 11,
                  color: _greyColor,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          SizedBox(height: 14),
          Text(
            displayText,
            style: TextStyle(
              color: _darkColor.withOpacity(0.85),
              fontSize: 15,
              height: 1.7,
              letterSpacing: 0.2,
            ),
          ),
          if (isLongDescription) ...[
            SizedBox(height: 12),
            InkWell(
              onTap: () {
                setState(() {
                  _isDescriptionExpanded = !_isDescriptionExpanded;
                });
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _isDescriptionExpanded ? 'Lire moins' : 'Lire plus',
                    style: TextStyle(
                      color: _primaryColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(
                    _isDescriptionExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: _primaryColor,
                    size: 18,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
  String get safeUsername {
    final userData = storage.read(StockageKeys.userKey);
    final profileData = storage.read(StockageKeys.profileKey);

    // PRIORITÉ 1: fullName
    final fullName = profileData?['fullname']?.toString() ?? profileData?['fullName']?.toString() ??
        userData?['fullname']?.toString() ?? userData?['fullName']?.toString();

    if (fullName != null && fullName.isNotEmpty) {
      return fullName;
    }

    // PRIORITÉ 2: username
    return userData?['username']?.toString() ??
        profileData?['username']?.toString() ??
        'Bio'; // Or Visiteur
  }


  Widget _buildPublicationInfoSection() {
    final user = widget.property.user;
    // Show section if we have postBy or user info
    if (widget.property.postBy == null && user?.email == null) {
      return SizedBox();
    }

    // Get publisher name from postBy or fallback to username
    String publisherName = widget.property.postBy ?? user?.username ?? widget.property.username ?? '';
    // Remove @ symbol if present
    publisherName = publisherName.replaceAll('@', '').trim();
    
    if (publisherName.isEmpty) {
      return SizedBox();
    }

    return Container(
      padding: EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white,
            _primaryColor.withOpacity(0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _primaryColor.withOpacity(0.1),
          width: 1,
        ),
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
          Row(
            children: [
              Icon(
                Icons.person_outline,
                size: 16,
                color: _primaryColor,
              ),
              SizedBox(width: 6),
              Text(
                'PUBLIÉ PAR',
                style: TextStyle(
                  fontSize: 11,
                  color: _greyColor,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Row(
            children: [
              // Photo de profil
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _primaryColor.withOpacity(0.2),
                      _secondaryColor.withOpacity(0.2),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(
                    color: _primaryColor.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                  child: GestureDetector(
                    onTap: () {
                      final imageUrl = (widget.property.image != null && widget.property.image!.isNotEmpty)
                          ? widget.property.image!
                          : (widget.property.user?.profilePicture ?? '');
                      
                      if (imageUrl.isNotEmpty) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => FullScreenProfileImage(
                              imageUrl: imageUrl,
                              heroTag: 'profile_image_${widget.property.propertyId}',
                            ),
                          ),
                        );
                      }
                    },
                    child: Hero(
                      tag: 'profile_image_${widget.property.propertyId}',
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(23),
                        child: (widget.property.image != null && widget.property.image!.isNotEmpty)
                            ? CachedNetworkImage(
                                imageUrl: widget.property.image!,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
                                  ),
                                ),
                                errorWidget: (context, url, error) => Center(
                                  child: Text(
                                    publisherName.isNotEmpty
                                        ? publisherName[0].toUpperCase()
                                        : 'A',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: _primaryColor,
                                    ),
                                  ),
                                ),
                              )
                            : (widget.property.user?.profilePicture != null && widget.property.user!.profilePicture!.isNotEmpty)
                                ? CachedNetworkImage(
                                    imageUrl: widget.property.user!.profilePicture!,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => Center(
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
                                      ),
                                    ),
                                    errorWidget: (context, url, error) => Center(
                                      child: Text(
                                        publisherName.isNotEmpty
                                            ? publisherName[0].toUpperCase()
                                            : 'A',
                                        style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: _primaryColor,
                                        ),
                                      ),
                                    ),
                                  )
                                : Center(
                                    child: Text(
                                      publisherName.isNotEmpty
                                          ? publisherName[0].toUpperCase()
                                          : 'A',
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: _primaryColor,
                                      ),
                                    ),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            publisherName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 17,
                              color: _darkColor,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(width: 6),
                        if (widget.property.isVerified ?? false)
                          Icon(
                            Icons.verified,
                            size: 16,
                            color: Colors.blue,
                          ),
                      ],
                    ),
                    SizedBox(height: 6),
                    if (widget.property.createdAt != null || widget.property.createdStart != null)
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 13,
                            color: _greyColor,
                          ),
                          SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'Publié le ${_formatPublicationDate(widget.property.createdAt ?? widget.property.createdStart!)}',
                              style: TextStyle(
                                color: _greyColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
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
  
  // Format date and time in French: "Publié le 24 décembre 2024 à 09:15"
  String _formatFrenchDateTime(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);
      
      // For recent dates, show relative time
      if (difference.inHours < 1) {
        return 'Publié il y a ${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''}';
      } else if (difference.inDays == 0) {
        return "Publié aujourd'hui à ${DateFormat('HH:mm').format(date)}";
      } else if (difference.inDays == 1) {
        return 'Publié hier à ${DateFormat('HH:mm').format(date)}';
      } else if (difference.inDays < 7) {
        return 'Publié il y a ${difference.inDays} jours';
      } else {
        return 'Publié le ${DateFormat('dd/MM/yyyy').format(date)}';
      }
    } catch (e) {
      return 'Publié récemment';
    }
  }

  // Format date as DD/MM/YYYY
  String _formatPublicationDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('dd/MM/yyyy').format(date);
    } catch (e) {
      return dateString;
    }
  }

  Widget _buildAdditionalFeaturesSection() {
    final hasElevator = widget.property.features?.any((f) => f.name?.toLowerCase().contains('ascenseur') ?? false) ?? false;
    final hasPool = widget.property.features?.any((f) => f.name?.toLowerCase().contains('piscine') ?? false) ?? false;
    final hasGarden = widget.property.features?.any((f) => f.name?.toLowerCase().contains('jardin') ?? false) ?? false;
    final hasTerrace = widget.property.features?.any((f) => f.name?.toLowerCase().contains('terrasse') ?? false) ?? false;

    // Créer une map des caractéristiques avec leurs valeurs
    final features = <String, String>{};

    if ((widget.property.bedrooms ?? 0) > 0) {
      features['Chambres'] = '${widget.property.bedrooms ?? 0}';
    }
    if ((widget.property.bathroom ?? 0) > 0) {
      features['Salles de bain'] = '${widget.property.bathroom ?? 0}';
    }
    if (_showSurface) {
      features['Surface'] = '${widget.property.surface ?? 0} m²';
    }
    if (_showFloor) {
      features['Étage'] = '${widget.property.floor ?? 0}';
    }
    if (hasElevator) {
      features['Ascenseur'] = 'Oui';
    }
    if (hasPool) {
      features['Piscine'] = 'Oui';
    }
    if (hasGarden) {
      features['Jardin'] = 'Oui';
    }
    if (hasTerrace) {
      features['Terrasse'] = 'Oui';
    }

    // Si aucune caractéristique à afficher, retourner un SizedBox
    if (features.isEmpty) {
      return SizedBox();
    }

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
    final address = widget.property.address;
    final quartier = widget.property.quartier;
    final communeId = widget.property.communeId;

    if (address == null && quartier == null && communeId == null) {
      return SizedBox();
    }

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
                  if (address != null)
                    Text(
                      address,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  // if (quartier != null || communeId != null)
                  //   Text(
                  //     '${quartier ?? ''}${quartier != null && communeId != null ? ', ' : ''}${communeId ?? ''}',
                  //     style: TextStyle(
                  //       color: _greyColor,
                  //       fontSize: 14,
                  //     ),
                  //   ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSimilarProperties(List<PropertyModel> similars) {
    if (similars.isEmpty) {
      return SizedBox.shrink();
    }

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
        SizedBox(height: 12),
        SizedBox(
          height: 240,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: similars.length,
            separatorBuilder: (_, __) => SizedBox(width: 12),
            itemBuilder: (context, index) {
              final prop = similars[index];
              final image = (prop.propertyImage != null && prop.propertyImage!.isNotEmpty)
                  ? prop.propertyImage!.first.path
                  : (prop.propertyImageRoom != null && prop.propertyImageRoom!.isNotEmpty)
                      ? prop.propertyImageRoom!.first.path
                      : null;
              return GestureDetector(
                onTap: () {
                  // Éviter de “piler” la navigation : si on est déjà sur ce bien, ne rien faire.
                  if (prop.propertyId == widget.property.propertyId) return;
                  // Remplacer la page actuelle pour ne pas empiler de multiples détails.
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PropertyDetailPage(property: prop),
                    ),
                  );
                },
                child: Container(
                  width: 180,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 12,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                        child: image != null
                            ? CachedNetworkImage(
                                imageUrl: image,
                                height: 120,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => Container(
                                  height: 120,
                                  color: Colors.grey.shade200,
                                ),
                                errorWidget: (_, __, ___) => Container(
                                  height: 120,
                                  color: Colors.grey.shade200,
                                  child: Icon(Icons.image_not_supported, color: Colors.grey),
                                ),
                              )
                            : Container(
                                height: 120,
                                width: double.infinity,
                                color: Colors.grey.shade200,
                                child: Icon(Icons.image, color: Colors.grey),
                              ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              prop.title ?? "Sans titre",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: _darkColor,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              prop.address ?? prop.cityValue ?? prop.communeValue ?? "Adresse inconnue",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: _greyColor,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              prop.price != null ? "${prop.price} \$" : "--",
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: _primaryColor,
                              ),
                            ),
                          ],
                        ),
                      )
                    ],
                  ),
                ),
              );
            },
          ),
        )
      ],
    );
  }

  Widget _buildEssentialServicesSection() {
    final electric = widget.property.electric;
    final water = widget.property.water;

    // Si aucun service n'est défini, ne pas afficher la section
    if (electric == null && water == null) {
      return SizedBox();
    }

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
        if (electric != null)
          Container(
            margin: EdgeInsets.only(bottom: water != null ? 12 : 0),
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
                    color: _getServiceColor(electric).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.electrical_services_rounded,
                    color: _getServiceColor(electric),
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
                              color: _getServiceColor(electric).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _getServiceColor(electric).withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              _getServicePercentage(electric),
                              style: TextStyle(
                                color: _getServiceColor(electric),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4),
                      Text(
                        _getElectricText(electric),
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
        if (water != null)
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
                    color: _getServiceColor(water).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.water_drop_rounded,
                    color: _getServiceColor(water),
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
                              color: _getServiceColor(water).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _getServiceColor(water).withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              _getServicePercentage(water),
                              style: TextStyle(
                                color: _getServiceColor(water),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4),
                      Text(
                        _getWaterText(water),
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

  void _navigateToBookingPage() {
    final isAvailable = widget.property.available ?? true;
    
    // Check if property is available
    if (!isAvailable) {
      SnackbarForCasa.error(
        context,
        "Cette propriété est déjà occupée et n'est plus disponible",
      );
      return;
    }
    
    final token = storage.read(StockageKeys.tokenKey);
    if (token == null) {
      FancyNotification.show(
        context, 
        "Vous devez être connecté pour planifier une visite",
        type: NotificationType.info
      );
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => LoginScreen()),
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
    final isAvailable = widget.property.available ?? true;
    
    return Column(
      children: [
        ElevatedButton(
          onPressed: _navigateToBookingPage,
          style: ElevatedButton.styleFrom(
            backgroundColor: isAvailable ? _primaryColor : _greyColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: EdgeInsets.symmetric(vertical: 16),
            elevation: isAvailable ? 2 : 0,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isAvailable ? Icons.calendar_today : Icons.block,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                isAvailable ? 'PLANIFIER UNE VISITE' : 'NON DISPONIBLE',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 8),
        Text(
          "Visitez en toute tranquillité pendant un an grâce à un   accessible de 4\$",
          style: TextStyle(
            color: Colors.grey[500],
            fontSize: 12,
            fontStyle: FontStyle.italic,
          ),
          textAlign: TextAlign.center,
        ),
      ],
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