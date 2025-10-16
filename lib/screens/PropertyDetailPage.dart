import 'package:casa/screens/FullScreenImageViewer.dart';
import 'package:casa/screens/FullScreenProfileImage.dart' hide FullScreenImageViewer;
import 'package:casa/utils/Constantes.dart';
import 'package:casa/utils/FavoriteEartIcon.dart';
import 'package:casa/utils/Routes.dart';
import 'package:casa/utils/StockageKeys.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get_storage/get_storage.dart';
import 'package:share_plus/share_plus.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/PropertyImageModel.dart';
import '../utils/FancyNotification.dart';

class PropertyDetailPage extends StatefulWidget {
  final dynamic property;
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

  // Catégories d'images par pièces
  final List<ImageCategory> _imageCategories = [
    ImageCategory(
      id: 'bedroom',
      name: 'Chambres',
      icon: FontAwesomeIcons.bed,
      color: Color(0xFF4CAF50),
    ),
    ImageCategory(
      id: 'living_room',
      name: 'Salon',
      icon: FontAwesomeIcons.couch,
      color: Color(0xFF2196F3),
    ),
    ImageCategory(
      id: 'kitchen',
      name: 'Cuisine',
      icon: FontAwesomeIcons.kitchenSet,
      color: Color(0xFFFF9800),
    ),
    ImageCategory(
      id: 'bathroom',
      name: 'Salle de bain',
      icon: FontAwesomeIcons.bath,
      color: Color(0xFF9C27B0),
    ),
    ImageCategory(
      id: 'exterior_front',
      name: 'Devant maison',
      icon: FontAwesomeIcons.home,
      color: Color(0xFF795548),
    ),
    ImageCategory(
      id: 'exterior_back',
      name: 'Arrière maison',
      icon: FontAwesomeIcons.tree,
      color: Color(0xFF388E3C),
    ),
    ImageCategory(
      id: 'other',
      name: 'Autres pièces',
      icon: FontAwesomeIcons.plus,
      color: Color(0xFF607D8B),
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
    final images = widget.property?.images ?? [];
    final groupedImages = <String, List<PropertyImageModel>>{};

    // Initialiser toutes les catégories
    for (var category in _imageCategories) {
      groupedImages[category.id] = [];
    }

    // Grouper les images par catégorie
    for (var image in images) {
      if (image is PropertyImageModel) {
        final category = (image.category?.toString().toLowerCase() ?? 'other');
        if (groupedImages.containsKey(category)) {
          groupedImages[category]!.add(image);
        } else {
          groupedImages['other']!.add(image);
        }
      }
    }

    // Retirer les catégories vides
    groupedImages.removeWhere((key, value) => value.isEmpty);

    return groupedImages;
  }

  @override
  Widget build(BuildContext context) {
    final groupedImages = _getGroupedImages();
    final allImages = (widget.property?.images ?? []).whereType<PropertyImageModel>().toList();

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
                SizedBox(height: 24),
                _buildPriceSection(),
                SizedBox(height: 24),
                _buildFeaturesSection(),
                SizedBox(height: 24),
                _buildDescriptionSection(),
                SizedBox(height: 24),
                // Nouvelle section pour les images groupées
                _buildGroupedImagesSection(groupedImages),
                SizedBox(height: 24),
                _buildAdditionalFeaturesSection(),
                SizedBox(height: 24),
                _buildAgentSection(),
                SizedBox(height: 24),
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
    final property = widget.property;

    Future<void> _shareProperty() async {
      if (widget.property == null) return;

      final firstImageUrl = images.isNotEmpty
          ? '${Constantes.URL_IMAGES}${images.first.path}'
          : null;

      bool isForRent = widget.property.transactionType == "location";

      final priceText = isForRent
          ? '${widget.property.price?.toStringAsFixed(0) ?? '0'}\$/mois'
          : '${widget.property.price?.toStringAsFixed(0) ?? '0'}\$';

      final shareText = '''
        🏠 ${widget.property.title ?? 'Belle propriété'} - ${widget.property.commune ?? ''}, ${widget.property.city ?? ''}
        
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
          subject: 'Propriété ${widget.property.transactionType == "location" ? 'à louer' : 'à vendre'}',
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
              final imagePath = image.path ?? '';
              final correctedPath = imagePath.startsWith('/')
                  ? imagePath.substring(1)
                  : imagePath;
              final imageUrl = '${Constantes.URL_IMAGES}$correctedPath';

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
                  tag: 'property_image_${property?.PropertyId}_$index',
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
              if (property?.PropertyId != null)
                FavoriteHeartIcon(
                  propertyId: property!.PropertyId.toString(),
                  size: 32,
                  splashRadius: 24,
                  activeColor: Colors.red,
                  inactiveColor: Colors.white,
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
            orElse: () => _imageCategories.last,
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
                final imagePath = image.path ?? '';
                final correctedPath = imagePath.startsWith('/')
                    ? imagePath.substring(1)
                    : imagePath;
                final imageUrl = '${Constantes.URL_IMAGES}$correctedPath';

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          children: [
            Chip(
              backgroundColor: _primaryColor.withOpacity(0.1),
              label: Text(
                widget.property?.transactionType == "location" ? 'À LOUER' : 'À VENDRE',
                style: TextStyle(
                  color: _primaryColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              shape: StadiumBorder(),
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            ),
            Chip(
              backgroundColor: _secondaryColor.withOpacity(0.1),
              label: Text(
                "${widget.property?.property_type.name}" ?? '',
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
          widget.property!.title ?? '',
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
                widget.property!.address ?? "",
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

  Widget _buildPriceSection() {
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
                    '${widget.property! .price!.toInt()}\$',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: _primaryColor,
                    ),
                  ),
                  if (widget.property?.transactionType == "location")
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
                '${widget.property!.surface!.toInt()} m²',
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildFeatureItem(
                'assets/images/bed.png',
                '${widget.property!.bedrooms}',
                'Chambres',
              ),
              _buildFeatureItem(
                'assets/images/douche.png',
                '${widget.property!.bathroom}',
                'SDB',
              ),
              _buildFeatureItem(
                'assets/images/parking.png',
                '${(widget.property?.floor ?? 0) >= 1 ? 'Oui' : 'Non'}',
                'Parking',
              ),
              _buildFeatureItem(
                'assets/images/bed.png',
                '${(widget.property?.floor ?? 0) >= 1 ? 'Oui' : 'Non'}',
                'Étage',
              ),
            ],
          ),
          SizedBox(height: 12),
          Divider(height: 1),
          SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildFeatureItem(
                'assets/images/salon.png',
                '${widget.property!.living_room}',
                'Salons',
              ),
              _buildFeatureItem(
                'assets/images/quisine.png',
                '${widget.property!.kitchen}',
                'Cuisine',
              ),
              _buildFeatureItem(
                'assets/images/wifi.png',
                '${widget.property?.features?.any((f) => f.name == 'WiFi') ?? false ? 'Oui' : 'Non'}',
                'Wi-Fi',
              ),
              _buildFeatureItem(
                'assets/images/clim.png',
                '${widget.property?.features?.any((f) => f.name == 'Climatisation') ?? false ? 'Oui' : 'Non'}',
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
          widget.property!.description ?? "",
          style: TextStyle(
            color: _darkColor.withOpacity(0.8),
            fontSize: 15,
            height: 1.6,
          ),
        ),
      ],
    );
  }

  Widget _buildAdditionalFeaturesSection() {
    final features = {
      'Construction': '2015',
      'État du bien': 'Excellent',
      'Ascenseur': widget.property?.features?.any((f) => f.name == 'Ascenseur') ?? false ? 'Oui' : 'Non',
      'Parking': 'Sous-sol',
      'Terrasse': '12 m²',
      'Piscine': widget.property?.features?.any((f) => f.name == 'Piscine') ?? false ? 'Oui' : 'Non',
    };
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
            children: features.entries.map((e) => Container(
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
                      child: Image.asset("assets/images/check.png",width: 16,height: 20,),
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
            image: DecorationImage(
              image: AssetImage('assets/map_placeholder.jpg'),
              fit: BoxFit.cover,
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
                    widget.property!.address ?? "",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'À 5 min à pied du métro le plus proche',
                    style: TextStyle(
                      color: _greyColor,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () {},
              child: Text('Itinéraire', style: TextStyle(color: _primaryColor)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAgentSection() {
    final user = widget.property?.user;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Agent immobilier',
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
              GestureDetector(
                onTap: () {
                  if (user?.profilePicture != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => FullScreenProfileImage(
                          imageUrl: '${Constantes.URL_IMAGES}${user!.profilePicture!}',
                        ),
                      ),
                    );
                  }
                },
                child: Hero(
                  tag: 'profile_image_${user?.userId}',
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      image: DecorationImage(
                        image: user?.profilePicture != null
                            ? NetworkImage('${Constantes.URL_IMAGES}${user!.profilePicture!}')
                            : AssetImage('assets/images/default_profile.png') as ImageProvider,
                        fit: BoxFit.cover,
                      ),
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
                      user?.fullname ?? user?.username ?? 'Nom non disponible',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _darkColor,
                      ),
                    ),
                    SizedBox(height: 4),
                    if (user?.isAgent ?? false)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified, size: 16, color: Colors.green),
                          SizedBox(width: 4),
                          Text(
                            "Agent certifié",
                            style: TextStyle(
                              color: _primaryColor,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      )
                    else if (user?.isAdmin ?? false)
                      Text(
                        "Administrateur",
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 13,
                        ),
                      )
                    else
                      Text(
                        "Particulier",
                        style: TextStyle(
                          color: _greyColor,
                          fontSize: 13,
                        ),
                      ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.email, size: 16, color: _greyColor),
                        SizedBox(width: 8),
                        Text(
                          user?.email ?? 'Non renseigné',
                          style: TextStyle(
                            color: _greyColor,
                            fontSize: 12,
                          ),
                        ),
                      ],
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

  Widget _buildSimilarProperties() {
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
        SizedBox(
          height: 240,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: 4,
            separatorBuilder: (_, __) => SizedBox(width: 16),
            itemBuilder: (context, index) {
              return Container(
                width: 180,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.white,
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
                    ClipRRect(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                      child: Container(
                        height: 120,
                        color: Colors.grey[200],
                        child: Center(
                          child: Icon(Icons.home, size: 40, color: Colors.grey[400]),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Appartement moderne',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: _darkColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.location_on, size: 14, color: _greyColor),
                              SizedBox(width: 4),
                              Text(
                                'Paris',
                                style: TextStyle(color: _greyColor, fontSize: 12),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '\$1,200',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: _primaryColor,
                                ),
                              ),
                              Row(
                                children: [
                                  Icon(Icons.king_bed, size: 14, color: _greyColor),
                                  SizedBox(width: 4),
                                  Text('3', style: TextStyle(fontSize: 12, color: _greyColor)),
                                  SizedBox(width: 8),
                                  Icon(Icons.bathtub, size: 14, color: _greyColor),
                                  SizedBox(width: 4),
                                  Text('2', style: TextStyle(fontSize: 12, color: _greyColor)),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _navigateToBookingPage() {
    final token = storage.read(StockageKeys.tokenKey);
    if (token == null) {
      FancyNotification.show(
        context,
        "Vous devez être connecté pour ajouter aux favoris",
      );
    } else {
      Navigator.pushNamed(context, Routes.bookingVisitPageRoute, arguments: widget.property);
    }
  }

  Widget _buildBottomActionBar() {
    final token = storage.read(StockageKeys.tokenKey);
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
        onPressed: () {
          print("louuuuuuuuuuuuupe${widget.property}");
          _navigateToBookingPage();
        },
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