import 'package:casa/screens/FullScreenImageViewer.dart';
import 'package:casa/screens/auth/LoginScreen.dart';
import 'package:casa/screens/FullScreenProfileImage.dart' hide FullScreenImageViewer;
import 'package:casa/utils/Constantes.dart';
import 'package:casa/utils/FavoriteEartIcon.dart';
import 'package:casa/utils/Routes.dart';
import 'package:casa/utils/SubscriptionHelper.dart';
import 'package:casa/utils/StockageKeys.dart';
import 'package:casa/utils/casanayo_share_copy.dart';
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
import '../utils/property_availability_ui.dart';
import '../utils/property_snapshot_merge.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
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
  PropertyModel? _localPropertySnapshot;

  PropertyModel _resolvedDetailProperty(PropertyController c) {
    final nav = widget.property;
    final id = nav.propertyId;
    if (id == null) return nav;
    final cur = c.currentProperty;
    PropertyModel? fill;
    if (cur != null && cur.propertyId == id) {
      fill = cur;
    } else {
      fill = _localPropertySnapshot;
    }
    if (fill == null) return nav;
    return PropertySnapshotMerge.mergeFillMissing(nav, fill);
  }

  bool _showSurfaceFor(PropertyModel property) {
    final surface = property.surface;
    return surface != null && surface > 0;
  }
  bool _showFloorFor(PropertyModel property) => (property.floor ?? 0) > 0;
  
  bool _shouldHideBedroomsFor(PropertyModel property) {
    final typeId = property.propertyTypeId;
    // 4: Bureau, 7: Salle funéraire, 8: Salle de fête, 9: Terrain
    return typeId == 4 || typeId == 7 || typeId == 8 || typeId == 9;
  }

  bool _shouldHideSalonsFor(PropertyModel property) {
    final typeId = property.propertyTypeId;
    // 7: Salle funéraire, 8: Salle de fête, 9: Terrain
    return typeId == 7 || typeId == 8 || typeId == 9;
  }

  bool _shouldHideKitchenFor(PropertyModel property) {
    final typeId = property.propertyTypeId;
    // 4: Bureau, 7: Salle funéraire, 8: Salle de fête, 9: Terrain
    return typeId == 4 || typeId == 7 || typeId == 8 || typeId == 9;
  }

  bool _shouldShowDetailedCharacteristics(PropertyModel property) {
    if (_showSurfaceFor(property)) return true;
    final id = property.propertyTypeId;
    return id == 7 || id == 8;
  }

  List<String> _parseUsageTokens(String? raw) {
    if (raw == null || raw.trim().isEmpty) return [];
    return raw
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  bool _isFestiveOrFuneraireFor(PropertyModel property) {
    final typeId = property.propertyTypeId;
    if (typeId != null) {
      // 7: Salle funéraire, 8: Salle de fête
      return typeId == 7 || typeId == 8;
    }
    final name = property.propertyType?.name?.toLowerCase() ?? '';
    return name.contains('fête') || name.contains('festive') || name.contains('funéra') || name.contains('deuil');
  }

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
      color: Color(0xFF4CAF50),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _imageController = PageController(viewportFraction: 1.0);
    _favoriteController.addListener(() {
      setState(() {});
    });
    
    // Démarrer le défilement automatique dès le début
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _startAutoScrollForProperty(widget.property);
      }
      
      final ctrl = context.read<PropertyController>();
      if (widget.property.propertyId != null) {
        // Reset current property to signal loading if it's different
        if (ctrl.currentProperty?.propertyId != widget.property.propertyId) {
          ctrl.currentProperty = null;
        }

        final pid = widget.property.propertyId!;
        final tid = widget.property.propertyTypeId;
        ctrl.findCachedPropertySnapshot(pid, typeId: tid).then((snap) {
          if (!mounted || snap == null) return;
          setState(() => _localPropertySnapshot = snap);
          _startAutoScrollForProperty(
            PropertySnapshotMerge.mergeFillMissing(widget.property, snap),
          );
        });

        // Charger la propriété complète et ses similaires depuis l'API détail
        ctrl.getPropertyById(pid,
            propertyTypeId: tid, mergeWith: widget.property);
        
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
  void _startAutoScrollForProperty(PropertyModel property) {
    final allImages = _getAllImagesFor(property);
    if (allImages.length <= 1) return; // Pas besoin de défilement si une seule image

    _autoScrollTimer?.cancel(); // Annuler le timer existant s'il y en a un
    
    _autoScrollTimer = Timer.periodic(Duration(seconds: 3), (timer) {
      if (!mounted || !_imageController.hasClients) {
        timer.cancel();
        return;
      }
      
      final int nextIndex = (_currentImageIndex + 1) % allImages.length;
      _imageController.animateToPage(
        nextIndex,
        duration: Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  // Grouper les images par catégorie
  Map<String, List<PropertyImageModel>> _getGroupedImagesFor(PropertyModel property) {
    final groupedImages = <String, List<PropertyImageModel>>{};

    // Initialiser toutes les catégories
    for (var category in _imageCategories) {
      groupedImages[category.id] = [];
    }

    // Grouper les images principales
    if (property.propertyImage != null && property.propertyImage!.isNotEmpty) {
      groupedImages['propertyImage'] = property.propertyImage!;
    }

    // Grouper les images des chambres
    if (property.propertyImageRoom != null && property.propertyImageRoom!.isNotEmpty && !_shouldHideBedroomsFor(property)) {
      groupedImages['propertyImageRoom'] = property.propertyImageRoom!
          .map((roomImage) => PropertyImageModel(path: roomImage.path))
          .toList();
    }

    // Grouper les images du salon
    if (property.propertyImageLivingRoom != null && property.propertyImageLivingRoom!.isNotEmpty && !_shouldHideSalonsFor(property)) {
      groupedImages['propertyImageLivingRoom'] = property.propertyImageLivingRoom!
          .map((livingRoomImage) => PropertyImageModel(path: livingRoomImage.path))
          .toList();
    }

    // Grouper les images de la cuisine
    if (property.propertyImageKitchen != null && property.propertyImageKitchen!.isNotEmpty && !_shouldHideKitchenFor(property)) {
      groupedImages['propertyImageKitchen'] = property.propertyImageKitchen!
          .map((kitchenImage) => PropertyImageModel(path: kitchenImage.path))
          .toList();
    }

    // Retirer les catégories vides
    groupedImages.removeWhere((key, value) => value.isEmpty);

    return groupedImages;
  }

  // Obtenir toutes les images pour le carousel principal
  List<PropertyImageModel> _getAllImagesFor(PropertyModel property) {
    final allImages = <PropertyImageModel>[];

    if (property.propertyImage != null && property.propertyImage!.isNotEmpty) {
      allImages.addAll(property.propertyImage!);
    }
    if (property.propertyImageRoom != null &&
        property.propertyImageRoom!.isNotEmpty &&
        !_shouldHideBedroomsFor(property)) {
      allImages.addAll(property.propertyImageRoom!.map((roomImage) =>
          PropertyImageModel(path: roomImage.path)));
    }
    if (property.propertyImageLivingRoom != null &&
        property.propertyImageLivingRoom!.isNotEmpty &&
        !_shouldHideSalonsFor(property)) {
      allImages.addAll(property.propertyImageLivingRoom!.map((livingRoomImage) =>
          PropertyImageModel(path: livingRoomImage.path)));
    }
    if (property.propertyImageKitchen != null &&
        property.propertyImageKitchen!.isNotEmpty &&
        !_shouldHideKitchenFor(property)) {
      allImages.addAll(property.propertyImageKitchen!.map((kitchenImage) =>
          PropertyImageModel(path: kitchenImage.path)));
    }

    return allImages;
  }

  @override
  Widget build(BuildContext context) {
    final propertyCtrl = context.watch<PropertyController>();
    final similar = propertyCtrl.similarProperties;

    final bool hasFullData =
        propertyCtrl.currentProperty?.propertyId == widget.property.propertyId;
    final PropertyModel property = _resolvedDetailProperty(propertyCtrl);
    final bool isLoading = propertyCtrl.loading && !hasFullData;

    final groupedImages = _getGroupedImagesFor(property);
    final allImages = _getAllImagesFor(property);

    return Scaffold(
      backgroundColor: _lightColor,
      extendBody: true,
      body: CustomScrollView(
        physics: ClampingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: isLoading && allImages.length <= 1
                ? _buildShimmerCarousel()
                : _buildImageCarousel(allImages, property),
          ),
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                SizedBox(height: 20),
                _buildHeaderSectionFor(property),
                SizedBox(height: 16),
                _buildAnimatedStatsSectionFor(property),
                SizedBox(height: 16),
                _buildHighlightsSectionFor(property),
                SizedBox(height: 16),
                if (property.propertyTypeId == 8 && _parseUsageTokens(property.usage).isNotEmpty) ...[
                  _buildEventUsageSectionFor(property),
                  SizedBox(height: 16),
                ],
                // Caractéristiques Détaillées
                if (_shouldShowDetailedCharacteristics(property))
                  Padding(
                    padding: EdgeInsets.only(top: 24),
                    child: _buildDetailedCharacteristicsSectionFor(property),
                  ),
                SizedBox(height: 16),
                _buildPublicationInfoSectionFor(property),
                SizedBox(height: 16),
                _buildDescriptionSectionFor(property),
                SizedBox(height: 16),
                _buildAdditionalFeaturesSectionFor(property),
                SizedBox(height: 16),
                _buildEssentialServicesSectionFor(property),
                SizedBox(height: 16),
                _buildLocationPreviewFor(property),
                SizedBox(height: 16),
                if (property.propertyTypeId == 5) ...[
                  _buildHotelRoomsSectionFor(property),
                  SizedBox(height: 16),
                ],
                if (groupedImages.isNotEmpty) _buildGroupedImagesSection(groupedImages),
                SizedBox(height: 16),
                _buildSimilarProperties(similar),
                SizedBox(height: 24),
                _buildBottomActionBarFor(property),
                SizedBox(height: 40),
              ].where((widget) => widget != null).toList().cast<Widget>()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerCarousel() {
    final carouselHeight = MediaQuery.of(context).size.height * 0.4;
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        height: carouselHeight,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
        ),
        child: Stack(
          children: [
            Center(
              child: Icon(Icons.photo, color: Colors.grey[400], size: 100),
            ),
            Positioned(
              bottom: 20,
              left: 20,
              child: Container(
                width: 150,
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageCarousel(List<PropertyImageModel> images, PropertyModel property) {
    final carouselHeight = MediaQuery.of(context).size.height * 0.4;

    Future<void> _shareProperty() async {
      bool isForRent = property.transactionType?.toLowerCase().contains('location') ?? false;

      final priceText = isForRent && !_isFestiveOrFuneraireFor(property)
          ? '${property.price?.toStringAsFixed(0) ?? '0'} ${property.currency}/mois'
          : '${property.price?.toStringAsFixed(0) ?? '0'} ${property.currency}';

      final lines = <String>[
        '🏠 ${property.title ?? 'Belle propriété'}',
        '',
        '💰 $priceText',
      ];
      if (!_shouldHideBedroomsFor(property)) {
        lines.add('🛏️ ${property.bedrooms ?? 0} chambres');
      }
      lines.add('🚿 ${property.bathroom ?? 0} salles de bain');
      if (_showSurfaceFor(property)) {
        lines.add('📐 ${property.surface?.toInt() ?? 0} m²');
      }
      lines.add('');
      lines.add('Découvrez plus de détails sur CasaNayo !');
      final shareText =
          '${lines.join('\n')}\n\n${CasanayoShareCopy.listingShareFooter(listingId: property.propertyId, kindLabel: 'propriété')}';

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
              _startAutoScrollForProperty(property);
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
                      : 'property_image_${property.propertyId}_$index',
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
              if (property.propertyId != null)
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
                      propertyId: property.propertyId.toString(),
                      propertyTypeId: property.propertyTypeId, // Pass propertyTypeId
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
        : groupedImages.entries.take(5).toList();

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

  Widget _buildHeaderSectionFor(PropertyModel property) {
    final isForRent = property.transactionType?.toLowerCase().contains('location') ?? false;
    final listingStatus = PropertyAvailabilityUi.listingStatusLabel(
      sold: property.sold,
      available: property.available,
      transactionType: property.transactionType,
      listingAllowed: property.listingAllowed,
    );
    final canVisit = PropertyAvailabilityUi.isListingAvailableForVisit(
      sold: property.sold,
      available: property.available,
      listingAllowed: property.listingAllowed,
    );

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
            if (property.propertyTypeId != null)
              Chip(
                backgroundColor: _secondaryColor.withOpacity(0.1),
                label: Text(
                  _getPropertyTypeFromTitleFor(property.propertyType?.name, property),
                  style: TextStyle(
                    color: _secondaryColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                shape: StadiumBorder(),
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              ),
            // Disponibilité (aligné FavoritesPage / PropertyListingStatusChip)
            Chip(
              backgroundColor: canVisit
                  ? const Color(0xFF00B894).withOpacity(0.12)
                  : const Color(0xFFD63031).withOpacity(0.12),
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    canVisit ? Icons.check_circle : Icons.cancel,
                    size: 14,
                    color: canVisit ? const Color(0xFF00B894) : const Color(0xFFD63031),
                  ),
                  SizedBox(width: 4),
                  Text(
                    (listingStatus ?? 'Disponible').toUpperCase(),
                    style: TextStyle(
                      color: canVisit ? const Color(0xFF00B894) : const Color(0xFFD63031),
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
          property.title ?? 'Sans titre',
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
                  _formatLocationFor(property),
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

  String _formatLocationFor(PropertyModel property) {
    final city = property.cityValue;
    final commune = property.communeValue;
    final parts = <String>[];
    if (city != null && city.isNotEmpty) parts.add(city);
    if (commune != null && commune.isNotEmpty) parts.add(commune);
    if (parts.isEmpty) return 'Ville / commune non renseignée';
    return parts.join(', ');
  }

  Widget _buildEventUsageSectionFor(PropertyModel property) {
    final tokens = _parseUsageTokens(property.usage);
    if (tokens.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _greyColor.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.celebration_outlined, size: 20, color: _primaryColor),
              const SizedBox(width: 8),
              Text(
                'TYPES D\'ÉVÉNEMENT',
                style: TextStyle(
                  fontSize: 11,
                  color: _greyColor,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: tokens
                .map(
                  (t) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: _primaryColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _primaryColor.withOpacity(0.2)),
                    ),
                    child: Text(
                      t,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _darkColor,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  String _getPropertyTypeFromTitleFor(String? title, PropertyModel property) {
    // 1. D'abord vérifier le propertyTypeId si disponible
    final typeId = property.propertyTypeId;
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
      if (typeId == 11) return 'Tourisme';
    }

    // 2. Fallback sur le titre si propertyTypeId est manquant
    if (title == null) return 'Propriété';
    final lowerTitle = title.toLowerCase();
    
    if (lowerTitle.contains('appart')) return 'Appartement';
    if (lowerTitle.contains('maison') || lowerTitle.contains('villa')) return 'Maison';
    if (lowerTitle.contains('studio')) return 'Studio';
    if (lowerTitle.contains('bureau')) return 'Bureau';
    if (lowerTitle.contains('hotel')) return 'Hotel';
    if (lowerTitle.contains('fête') || lowerTitle.contains('fete')) return 'Salle de fête';
    if (lowerTitle.contains('funéra') || lowerTitle.contains('deuil')) return 'Espace Funéraire';
    if (lowerTitle.contains('terrain') || lowerTitle.contains('parcelle')) return 'Terrain';
    if (lowerTitle.contains('tourisme') || lowerTitle.contains('tourist')) return 'Tourisme';

    return 'Propriété';
  }

  Widget _buildPriceSectionFor(PropertyModel property) {
    final isForRent = property.transactionType?.toLowerCase().contains('location') ?? false;

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
                      '${property.price?.toInt() ?? 0}',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: _primaryColor,
                        height: 1,
                      ),
                    ),
                    Text(
                      property.currency ?? '\$',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: _primaryColor,
                      ),
                    ),
                    if (isForRent && !_isFestiveOrFuneraireFor(property))
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
          if (_showSurfaceFor(property))
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
                        '${property.surface?.toInt() ?? 0}',
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

  Widget _buildFeaturesSectionFor(PropertyModel property) {
    final hasWifi = property.features?.any((f) => f.name?.toLowerCase().contains('wifi') ?? false) ?? false;
    final hasClim = property.features?.any((f) => f.name?.toLowerCase().contains('climatisation') ?? false) ?? false;
    final hasParking = property.features?.any((f) => f.name?.toLowerCase().contains('parking') ?? false) ?? false;

    // Créer une liste dynamique des éléments à afficher avec le bon type
    final List<Widget> featureItems = <Widget>[];

    // Ajouter les chambres seulement si > 0 et si on ne doit pas les cacher
    if ((property.bedrooms ?? 0) > 0 && !_shouldHideBedroomsFor(property)) {
      featureItems.add(_buildFeatureItem(
        'assets/images/bed.png',
        '${property.bedrooms ?? 0}',
        'Chambres',
      ));
    }

    // Ajouter les salles de bain seulement si > 0
    if ((property.bathroom ?? 0) > 0) {
      featureItems.add(_buildFeatureItem(
        'assets/images/douche.png',
        '${property.bathroom ?? 0}',
        'SDB',
      ));
    }

    // Ajouter l'étage seulement si > 0
    if (_showFloorFor(property)) {
      featureItems.add(_buildFeatureItem(
        'assets/images/wifi.png',
        '${property.floor ?? 0}',
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
  Widget _buildAnimatedStatsSectionFor(PropertyModel property) {
    final isForRent = property.transactionType?.toLowerCase().contains('location') ?? false;
    final price = property.price?.toInt() ?? 0;
    
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
                (isForRent && !_isFestiveOrFuneraireFor(property)) ? '${property.currency ?? '\$'}/mois' : '${property.currency ?? '\$'}',
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
  Widget _buildDetailedCharacteristicsSectionFor(PropertyModel property) {
    final stats = <Map<String, dynamic>>[];
    
    // Bedrooms (chambres)
    if (property.bedrooms != null && property.bedrooms! > 0 && !_shouldHideBedroomsFor(property)) {
      stats.add({
        'icon': Icons.bed_outlined,
        'label': 'Chambres',
        'value': '${property.bedrooms}',
        'unit': property.bedrooms! > 1 ? 'chambres' : 'chambre',
        'color': Color(0xFF1976D2),
      });
    }
    
    // Living Room (salon)
    if (property.livingRoom != null && property.livingRoom! > 0 && !_shouldHideSalonsFor(property)) {
      stats.add({
        'icon': Icons.weekend_outlined,
        'label': 'Salon',
        'value': '${property.livingRoom}',
        'unit': property.livingRoom! > 1 ? 'salons' : 'salon',
        'color': Color(0xFF42A5F5),
      });
    }
    
    // Kitchen (cuisine)
    if (property.kitchen != null && property.kitchen! > 0 && !_shouldHideKitchenFor(property)) {
      stats.add({
        'icon': Icons.kitchen_outlined,
        'label': 'Cuisine',
        'value': '${property.kitchen}',
        'unit': property.kitchen! > 1 ? 'cuisines' : 'cuisine',
        'color': Color(0xFF64B5F6),
      });
    }
    
    // Bathroom (salles de bain)
    if (property.bathroom != null && property.bathroom! > 0) {
      stats.add({
        'icon': Icons.bathroom_outlined,
        'label': 'Salle de bain',
        'value': '${property.bathroom}',
        'unit': property.bathroom! > 1 ? 'SDB' : 'SDB',
        'color': Color(0xFF90CAF9),
      });
    }

    // SPECIAL FIELDS
    // Bureau
    if (property.propertyTypeId == 4) {
      if (property.roomMeet != null && property.roomMeet! > 0) {
        stats.add({
          'icon': Icons.meeting_room_outlined,
          'label': 'Réunions',
          'value': '${property.roomMeet}',
          'unit': property.roomMeet! > 1 ? 'salles' : 'salle',
          'color': Color(0xFF42A5F5),
        });
      }
      if (property.isEquip != null) {
        stats.add({
          'icon': property.isEquip == true ? Icons.chair : Icons.chair_outlined,
          'label': 'Meublé',
          'value': property.isEquip == true ? 'Oui' : 'Non',
          'unit': property.isEquip == true ? 'Équipé' : 'Vide',
          'color': Color(0xFF42A5F5),
        });
      }
    }

    // Festive/Funeraire
    if (property.propertyTypeId == 7 || property.propertyTypeId == 8) {
      if (property.capacityPeople != null && property.capacityPeople! > 0) {
        stats.add({
          'icon': Icons.people_outline,
          'label': 'Capacité',
          'value': '${property.capacityPeople}',
          'unit': 'pers.',
          'color': Color(0xFF42A5F5),
        });
      }
      if (property.propertyTypeId == 8 && property.pisteDanse != null) {
          stats.add({
            'icon': Icons.music_note_outlined,
            'label': 'Piste',
            'value': property.pisteDanse == true ? 'Oui' : 'Non',
            'unit': 'Danse',
            'color': Color(0xFF42A5F5),
          });
      }
      if (property.isDecore != null) {
          stats.add({
            'icon': Icons.auto_awesome_outlined,
            'label': 'Décoré',
            'value': property.isDecore == true ? 'Oui' : 'Non',
            'unit': 'Déco',
            'color': Color(0xFF42A5F5),
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
  Widget _buildHighlightsSectionFor(PropertyModel property) {
    final highlights = <Map<String, dynamic>>[];
    
    // Add highlights based on property features
    if (property.isVerified ?? false) {
      highlights.add({
        'icon': Icons.verified_outlined,
        'label': 'Vérifié',
        'color': _primaryColor,
      });
    }
    
    if ((property.viewCount ?? 0) > 50) {
      highlights.add({
        'icon': Icons.trending_up,
        'label': 'Populaire',
        'color': Color(0xFF1565C0),
      });
    }
    
    final hasPool = property.features?.any((f) => f.name?.toLowerCase().contains('piscine') ?? false) ?? false;
    if (hasPool) {
      highlights.add({
        'icon': Icons.pool_outlined,
        'label': 'Avec piscine',
        'color': _secondaryColor,
      });
    }
    
    final hasParking = property.features?.any((f) => f.name?.toLowerCase().contains('parking') ?? false) ?? false;
    if (hasParking) {
      highlights.add({
        'icon': Icons.local_parking_outlined,
        'label': 'Parking',
        'color': Color(0xFF0288D1),
      });
    }
    
    final hasGarden = property.features?.any((f) => f.name?.toLowerCase().contains('jardin') ?? false) ?? false;
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

  // NEW: Location Preview Section (ville + commune uniquement, jamais l'adresse complète)
  Widget _buildLocationPreviewFor(PropertyModel property) {
    final hasCity = property.cityValue != null && property.cityValue!.trim().isNotEmpty;
    final hasCommune = property.communeValue != null && property.communeValue!.trim().isNotEmpty;
    if (!hasCity && !hasCommune) {
      return const SizedBox.shrink();
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
                      _formatLocationFor(property),
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
          if (hasCommune || hasCity) ...[
            SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (hasCommune)
                  _buildLocationChip(Icons.location_city_outlined, property.communeValue!.trim()),
                if (hasCity)
                  _buildLocationChip(Icons.place_outlined, property.cityValue!.trim()),
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

  Widget _buildDescriptionSectionFor(PropertyModel property) {
    final description = property.description;
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


  Widget _buildPublicationInfoSectionFor(PropertyModel property) {
    final user = property.user;
    // Show section if we have postBy or user info
    // Obtenir le nom de l'utilisateur
    String publisherName = '';
    if (property.user?.username != null) {
      publisherName = property.user!.username!;
    } else if (property.postBy != null) {
      publisherName = property.postBy!;
    } else if (property.username != null) {
      publisherName = property.username!;
    }
    
    // Nettoyer le nom (enlever @ si présent)
    publisherName = publisherName.replaceAll('@', '').trim();

    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 15,
            offset: Offset(0, 5),
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
                      final imageUrl = (property.image != null && property.image!.isNotEmpty)
                          ? property.image!
                          : (property.user?.profilePicture ?? '');
                      
                      if (imageUrl.isNotEmpty) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => FullScreenProfileImage(
                              imageUrl: imageUrl,
                              heroTag: 'profile_image_${property.propertyId}',
                            ),
                          ),
                        );
                      }
                    },
                    child: Hero(
                      tag: 'profile_image_${property.propertyId}',
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(23),
                        child: (property.image != null && property.image!.isNotEmpty)
                            ? CachedNetworkImage(
                                imageUrl: property.image!,
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
                            : (property.user?.profilePicture != null && property.user!.profilePicture!.isNotEmpty)
                                ? CachedNetworkImage(
                                    imageUrl: property.user!.profilePicture!,
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
                        if (property.isVerified ?? false)
                          Icon(
                            Icons.verified,
                            size: 16,
                            color: Colors.blue,
                          ),
                      ],
                    ),
                    SizedBox(height: 6),
                    if (property.createdAt != null || property.createdStart != null)
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
                              'Publié le ${_formatPublicationDate(property.createdAt ?? property.createdStart!)}',
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

  Widget _buildAdditionalFeaturesSectionFor(PropertyModel property) {
    final hasElevator = property.features?.any((f) => f.name?.toLowerCase().contains('ascenseur') ?? false) ?? false;
    final hasPool = property.features?.any((f) => f.name?.toLowerCase().contains('piscine') ?? false) ?? false;
    final hasGarden = property.features?.any((f) => f.name?.toLowerCase().contains('jardin') ?? false) ?? false;
    final hasTerrace = property.features?.any((f) => f.name?.toLowerCase().contains('terrasse') ?? false) ?? false;

    // Créer une map des caractéristiques avec leurs valeurs
    final features = <String, String>{};

    if ((property.bedrooms ?? 0) > 0) {
      features['Chambres'] = '${property.bedrooms ?? 0}';
    }
    if ((property.bathroom ?? 0) > 0) {
      features['Salles de bain'] = '${property.bathroom ?? 0}';
    }
    if (_showSurfaceFor(property)) {
      features['Surface'] = '${property.surface ?? 0} m²';
    }
    if (_showFloorFor(property)) {
      features['Étage'] = '${property.floor ?? 0}';
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
                              _formatLocationFor(prop),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: _greyColor,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              prop.price != null ? "${prop.price} ${prop.currency ?? '\$'}" : "--",
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

  Widget _buildEssentialServicesSectionFor(PropertyModel property) {
    final electric = property.electric;
    final water = property.water;

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

  Widget _buildHotelRoomsSectionFor(PropertyModel property) {
    final rooms = property.hotelStructure;
    if (rooms == null || rooms.isEmpty) return SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Nos Chambres',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: _darkColor,
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${rooms.length} types disponibles',
                style: TextStyle(
                  color: _primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 16),
        ListView.separated(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: rooms.length,
          separatorBuilder: (context, index) => SizedBox(height: 16),
          itemBuilder: (context, index) {
            return _buildRoomCard(rooms[index], property);
          },
        ),
      ],
    );
  }

  Widget _buildRoomCard(HotelRoomStructure roomStructure, PropertyModel hotelProperty) {
    final room = roomStructure.chambre;
    final images = roomStructure.images ?? [];
    if (room == null) return SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Room images carousel
          if (images.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              child: SizedBox(
                height: 200,
                child: Stack(
                  children: [
                    PageView.builder(
                      itemCount: images.length,
                      itemBuilder: (context, idx) {
                        return CachedNetworkImage(
                          imageUrl: images[idx].path ?? '',
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(color: Colors.grey[200]),
                          errorWidget: (context, url, error) => Icon(Icons.error),
                        );
                      },
                    ),
                    Positioned(
                      bottom: 12,
                      right: 12,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${images.length} photos',
                          style: TextStyle(color: Colors.white, fontSize: 10),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        room.title ?? 'Chambre standard',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _darkColor,
                        ),
                      ),
                    ),
                    Text(
                      '${room.price?.toStringAsFixed(0) ?? '0'} ${hotelProperty.currency ?? '\$'}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _primaryColor,
                      ),
                    ),
                  ],
                ),
                if (room.priceHeure != null && room.priceHeure!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      'Prix/heure: ${room.priceHeure}',
                      style: TextStyle(color: _greyColor, fontSize: 13),
                    ),
                  ),
                SizedBox(height: 12),
                if (room.description != null && room.description!.isNotEmpty)
                  Text(
                    room.description!,
                    style: TextStyle(color: _greyColor, fontSize: 14),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                SizedBox(height: 16),
                Row(
                  children: [
                    _buildRoomFeature(Icons.king_bed_outlined, '${room.numberPiece ?? 1} lits'),
                    SizedBox(width: 16),
                    _buildRoomFeature(Icons.check_circle_outline, room.available == true ? 'Disponible' : 'Occupé'),
                  ],
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => _reserveRoom(hotelProperty, room),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    foregroundColor: Colors.white,
                    minimumSize: Size(double.infinity, 45),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'RÉSERVER CETTE CHAMBRE',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomFeature(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 16, color: _greyColor),
        SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(color: _greyColor, fontSize: 13),
        ),
      ],
    );
  }

  void _reserveRoom(PropertyModel displayProperty, HotelRoomModel room) {
     final token = storage.read(StockageKeys.tokenKey);
     if (token == null) {
       FancyNotification.show(
         context, 
         "Vous devez être connecté pour réserver une chambre",
         type: NotificationType.info
       );
       Navigator.push(
         context,
         MaterialPageRoute(builder: (context) => LoginScreen()),
       );
     } else {
       SubscriptionHelper.checkPremiumForPropertyReservation(
         context: context,
         onProceed: () {
           Navigator.pushNamed(
             context,
             Routes.bookingVisitPageRoute,
             arguments: {
               'property': displayProperty,
               'chambreId': room.id,
             },
           );
         },
       );
     }
  }

  void _navigateToBookingPage(PropertyModel displayProperty) {
    final p = displayProperty;
    if (PropertyAvailabilityUi.blocksSchedulingVisit(
      sold: p.sold,
      available: p.available,
      listingAllowed: p.listingAllowed,
    )) {
      String msg;
      if (p.sold == true) {
        final t = p.transactionType?.toLowerCase() ?? '';
        msg = t.contains('vente')
            ? 'Ce bien a été vendu.'
            : "Ce bien n'est plus disponible pour une visite.";
      } else {
        msg = "Ce bien n'est plus disponible pour une visite.";
      }
      SnackbarForCasa.error(context, msg);
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
      SubscriptionHelper.checkPremiumForPropertyReservation(
        context: context,
        onProceed: () {
          Navigator.pushNamed(
            context,
            Routes.bookingVisitPageRoute,
            arguments: displayProperty,
          );
        },
      );
    }
  }

  Widget _buildBottomActionBarFor(PropertyModel property) {
    final blocked = PropertyAvailabilityUi.blocksSchedulingVisit(
      sold: property.sold,
      available: property.available,
      listingAllowed: property.listingAllowed,
    );
    final statusLabel = PropertyAvailabilityUi.listingStatusLabel(
      sold: property.sold,
      available: property.available,
      transactionType: property.transactionType,
      listingAllowed: property.listingAllowed,
    );
    final buttonLabel = !blocked
        ? 'PLANIFIER UNE VISITE'
        : (statusLabel ?? 'NON DISPONIBLE').toUpperCase();

    return Column(
      children: [
        ElevatedButton(
          onPressed: blocked ? null : () => _navigateToBookingPage(property),
          style: ElevatedButton.styleFrom(
            backgroundColor: blocked ? _greyColor : _primaryColor,
            foregroundColor: Colors.white,
            disabledForegroundColor: Colors.white.withOpacity(0.9),
            disabledBackgroundColor: _greyColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: EdgeInsets.symmetric(vertical: 16),
            elevation: blocked ? 0 : 2,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                blocked ? Icons.block : Icons.calendar_today,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                buttonLabel,
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