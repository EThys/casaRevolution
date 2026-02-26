import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:casa/controllers/AuthentificationCtrl.dart';
import 'package:casa/models/TerrainModel.dart';
import 'package:casa/screens/FullScreenImageViewer.dart'; // Ensure this exists or use placeholder
import 'package:casa/screens/auth/LoginScreen.dart';
import 'package:casa/utils/FancyNotification.dart';
import 'package:casa/utils/Constantes.dart';
import 'package:casa/utils/Routes.dart';
import 'package:casa/utils/StockageKeys.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get_storage/get_storage.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import '../screens/FullScreenProfileImage.dart';
import '../models/PropertyImageModel.dart'; // For full screen viewer compatibility

class TerrainDetailPage extends StatefulWidget {
  final TerrainModel terrain;
  final String? heroTag;

  const TerrainDetailPage({
    Key? key,
    required this.terrain,
    this.heroTag,
  }) : super(key: key);

  @override
  _TerrainDetailPageState createState() => _TerrainDetailPageState();
}

class _TerrainDetailPageState extends State<TerrainDetailPage> {
  final Color _primaryColor = Color(0xFF1976D2);
  final Color _secondaryColor = Color(0xFF64B5F6);
  final Color _darkColor = Color(0xFF2D3748);
  final Color _lightColor = Color(0xFFF8F9FA);
  final Color _greyColor = Color(0xFF6C757D);
  
  final GetStorage storage = GetStorage();
  final PageController _imageController = PageController();
  int _currentImageIndex = 0;
  Timer? _autoScrollTimer;
  bool _isDescriptionExpanded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startAutoScroll();
    });
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _imageController.dispose();
    super.dispose();
  }

  void _startAutoScroll() {
    final images = widget.terrain.images ?? [];
    if (images.length <= 1) return;

    _autoScrollTimer?.cancel();
    _autoScrollTimer = Timer.periodic(Duration(seconds: 4), (timer) {
      if (!mounted || !_imageController.hasClients) {
        timer.cancel();
        return;
      }
      final nextIndex = (_currentImageIndex + 1) % images.length;
      _imageController.animateToPage(
        nextIndex,
        duration: Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _lightColor,
      extendBody: true, // For transparency behind bottom/top if needed
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _buildImageCarousel(),
          ),
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                SizedBox(height: 20),
                _buildHeaderSection(),
                SizedBox(height: 16),
                _buildLocationPreview(),
                SizedBox(height: 16),
                _buildCharacteristicsSection(),
                SizedBox(height: 16),
                _buildPublicationInfoSection(),
                SizedBox(height: 16),
                _buildDescriptionSection(),
                SizedBox(height: 24),
                _buildBottomActionBar(),
                SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageCarousel() {
    final images = widget.terrain.images ?? [];
    final carouselHeight = MediaQuery.of(context).size.height * 0.45;

    return Stack(
      children: [
        SizedBox(
          height: carouselHeight,
          child: images.isEmpty
              ? Container(
                  color: Colors.grey[300],
                  child: Center(
                    child: Icon(FontAwesomeIcons.mountain, size: 50, color: Colors.grey[400]),
                  ),
                )
              : PageView.builder(
                  controller: _imageController,
                  itemCount: images.length,
                  onPageChanged: (index) {
                    setState(() => _currentImageIndex = index);
                    _startAutoScroll();
                  },
                  itemBuilder: (context, index) {
                    final img = images[index];
                    return GestureDetector(
                      onTap: () {
                         // Adapting to FullScreenImageViewer which typically expects PropertyImageModel
                         // creating dummy models or passing paths
                         final propertyImages = images.map((tImg) => 
                           PropertyImageModel(path: tImg.path) 
                         ).toList();
                         
                         Navigator.push(
                           context,
                           MaterialPageRoute(
                             builder: (_) => FullScreenImageViewer(
                               images: propertyImages,
                               initialIndex: index,
                             ),
                           ),
                         );
                      },
                      child: Hero(
                        tag: index == 0 && widget.heroTag != null
                            ? widget.heroTag!
                            : 'terrain_image_${widget.terrain.terrain?.id}_$index',
                        child: CachedNetworkImage(
                          imageUrl: img.path ?? '',
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: Colors.grey[200],
                            child: Icon(Icons.broken_image, color: Colors.grey[400]),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
        // Gradient
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: Container(
            height: 100,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withOpacity(0.5)],
              ),
            ),
          ),
        ),
        // Indicators
        if (images.length > 1)
          Positioned(
            bottom: 20,
            left: 0, right: 0,
            child: Center(
              child: SmoothPageIndicator(
                controller: _imageController,
                count: images.length,
                effect: ScrollingDotsEffect(
                  activeDotColor: Colors.white,
                  dotColor: Colors.white.withOpacity(0.5),
                  dotHeight: 8,
                  dotWidth: 8,
                ),
              ),
            ),
          ),
        // Back Button
        Positioned(
          top: 50,
          left: 20,
          child: _buildCircleButton(
            icon: Icons.arrow_back,
            onTap: () => Navigator.pop(context),
          ),
        ),
        // Share Button
        Positioned(
          top: 50,
          right: 20,
          child: _buildCircleButton(
            icon: Icons.share,
            onTap: _shareTerrain,
          ),
        ),
      ],
    );
  }

  Widget _buildCircleButton({required IconData icon, required VoidCallback onTap}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white),
        onPressed: onTap,
      ),
    );
  }

  Future<void> _shareTerrain() async {
    final title = widget.terrain.terrain?.title ?? 'Terrain';
    final price = widget.terrain.terrain?.price ?? 0;
    final rawCurrency = widget.terrain.devise?.code ?? 'USD';
    final currency = (rawCurrency == 'USD') ? '\$' : (rawCurrency == 'CDF' ? 'FC' : rawCurrency);
    
    await Share.share(
      'Découvrez ce terrain : $title\nPrix : $price $currency\nSur l\'application CasaNayo!',
      subject: 'Terrain à voir',
    );
  }

  Widget _buildHeaderSection() {
    final t = widget.terrain.terrain;
    final isVente = t?.transactionType?.toLowerCase().contains('vente') ?? false;
    final isAvailable = t?.isAvailable ?? true;
    final price = t?.price ?? 0;
    final rawCurrency = widget.terrain.devise?.code ?? 'USD';
    final currency = (rawCurrency == 'USD') ? '\$' : (rawCurrency == 'CDF' ? 'FC' : rawCurrency);
    final title = t?.title ?? 'Terrain';
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: isVente ? Colors.green.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                isVente ? 'À VENDRE' : 'À LOUER',
                style: TextStyle(
                  color: isVente ? Colors.green[700] : Colors.blue[700],
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            Spacer(),
            Container(
               padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
               decoration: BoxDecoration(
                 color: isAvailable ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                 borderRadius: BorderRadius.circular(8),
               ),
               child: Row(
                 mainAxisSize: MainAxisSize.min,
                 children: [
                   Icon(isAvailable ? Icons.check_circle : Icons.cancel, size: 14, color: isAvailable ? Colors.green : Colors.red),
                   SizedBox(width: 4),
                   Text(
                     isAvailable ? 'DISPONIBLE' : 'INDISPONIBLE',
                     style: TextStyle(
                       color: isAvailable ? Colors.green : Colors.red,
                       fontWeight: FontWeight.bold,
                       fontSize: 12,
                     ),
                   ),
                 ],
               ),
            ),
          ],
        ),
        SizedBox(height: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: _darkColor,
          ),
        ),
        SizedBox(height: 8),
        Text(
          '${price.toStringAsFixed(0)} $currency',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: _primaryColor,
          ),
        ),
      ],
    );
  }

  Widget _buildLocationPreview() {
    final addr = widget.terrain.address;
    final locationText = "${addr?.cityValue}, ${addr?.communeValue}";

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.location_on, color: _primaryColor),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('LOCALISATION', style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.bold, color: _greyColor, letterSpacing: 1.2
                )),
                SizedBox(height: 4),
                Text(locationText, style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600, color: _darkColor
                )),
                if (addr?.countryValue != null)
                   Text(addr!.countryValue!, style: TextStyle(fontSize: 13, color: _greyColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCharacteristicsSection() {
    final surface = widget.terrain.terrain?.surface;
    if (surface == null || surface.isEmpty) return SizedBox();

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
           BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('CARACTÉRISTIQUES', style: TextStyle(
             fontSize: 10, fontWeight: FontWeight.bold, color: _greyColor, letterSpacing: 1.2
          )),
          SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.square_foot, color: _secondaryColor),
              SizedBox(width: 8),
              Text('Surface', style: TextStyle(color: _greyColor, fontSize: 14)),
              Spacer(),
              Text('$surface m²', style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 16, color: _darkColor
              )),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPublicationInfoSection() {
    // Logic to resolve publisher info
    String publisherName = '';
    String? publisherImage = widget.terrain.publisherImage;

    // Try postBy
    if (widget.terrain.postBy != null && widget.terrain.postBy!.isNotEmpty) {
      publisherName = widget.terrain.postBy!.replaceAll('@', '').trim();
    }
    
    if (publisherName.isEmpty) {
      publisherName = 'Prestataire';
    }

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _primaryColor.withOpacity(0.1)),
        boxShadow: [
           BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('PUBLIÉ PAR', style: TextStyle(
             fontSize: 10, fontWeight: FontWeight.bold, color: _greyColor, letterSpacing: 1.2
          )),
          SizedBox(height: 12),
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  if (publisherImage != null && publisherImage.isNotEmpty) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => FullScreenProfileImage(imageUrl: publisherImage)),
                    );
                  }
                },
                child: Hero(
                   tag: 'publisher_profile_${widget.terrain.terrain?.id}',
                   child: Container(
                     width: 50, height: 50,
                     decoration: BoxDecoration(
                       shape: BoxShape.circle,
                       border: Border.all(color: _primaryColor.withOpacity(0.2), width: 2),
                     ),
                     child: ClipOval(
                       child: publisherImage != null && publisherImage.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: publisherImage,
                              fit: BoxFit.cover,
                              errorWidget: (_,__,___) => Icon(Icons.person, color: _greyColor),
                            )
                          : Container(
                              color: _primaryColor.withOpacity(0.1),
                              child: Icon(Icons.person, color: _primaryColor),
                            ),
                     ),
                   ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  publisherName,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _darkColor,
                  ),
                ),
              ),
              if (widget.terrain.terrain?.createdAt != null)
                Text(
                  _formatDate(widget.terrain.terrain!.createdAt!),
                  style: TextStyle(color: _greyColor, fontSize: 12),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd/MM/yyyy').format(date);
    } catch (_) {
      return '';
    }
  }

  Widget _buildDescriptionSection() {
    final desc = widget.terrain.terrain?.description;
    if (desc == null || desc.isEmpty) return SizedBox();

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
           BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('DESCRIPTION', style: TextStyle(
             fontSize: 10, fontWeight: FontWeight.bold, color: _greyColor, letterSpacing: 1.2
          )),
          SizedBox(height: 8),
          Text(
            desc,
            style: TextStyle(fontSize: 15, color: _darkColor, height: 1.5),
            maxLines: _isDescriptionExpanded ? null : 4,
            overflow: _isDescriptionExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
          ),
          if (desc.length > 200)
             TextButton(
               onPressed: () => setState(() => _isDescriptionExpanded = !_isDescriptionExpanded),
               child: Text(_isDescriptionExpanded ? 'Voir moins' : 'Voir plus'),
             ),
        ],
      ),
    );
  }

  Widget _buildBottomActionBar() {
    final isAvailable = widget.terrain.terrain?.isAvailable ?? true;

    return Column(
      children: [
        ElevatedButton(
          onPressed: () {
            if (!isAvailable) {
              SnackbarForCasa.error(context, "Ce terrain n'est pas disponible.");
              return;
            }

            final token = storage.read(StockageKeys.tokenKey);
            if (token == null) {
              FancyNotification.show(
                context, 
                "Vous devez être connecté pour planifier une visite",
                type: NotificationType.info
              );
              Navigator.push(context, MaterialPageRoute(builder: (_) => LoginScreen()));
            } else {
              Navigator.pushNamed(
                context,
                Routes.bookingVisitPageRoute,
                arguments: widget.terrain,
              );
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: isAvailable ? _primaryColor : _greyColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: EdgeInsets.symmetric(vertical: 16),
            elevation: isAvailable ? 2 : 0,
            minimumSize: Size(double.infinity, 50),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(isAvailable ? Icons.calendar_today : Icons.block, size: 20),
              SizedBox(width: 8),
              Text(
                isAvailable ? 'PLANIFIER UNE VISITE' : 'NON DISPONIBLE',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        SizedBox(height: 8),
        Text(
          "Visitez en toute tranquillité pendant un an grâce à un pass accessible de 4\$",
          style: TextStyle(color: Colors.grey[500], fontSize: 12, fontStyle: FontStyle.italic),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
