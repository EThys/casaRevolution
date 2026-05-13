import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:casa/models/TerrainModel.dart';
import 'package:casa/screens/FullScreenImageViewer.dart'; // Ensure this exists or use placeholder
import 'package:casa/screens/auth/LoginScreen.dart';
import 'package:casa/utils/FancyNotification.dart';
import 'package:casa/utils/Constantes.dart';
import 'package:casa/utils/Routes.dart';
import 'package:casa/utils/SubscriptionHelper.dart';
import 'package:casa/utils/StockageKeys.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get_storage/get_storage.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import '../controllers/PropertyCtrl.dart';
import '../screens/FullScreenProfileImage.dart';
import '../models/PropertyImageModel.dart';
import '../utils/FavoriteEartIcon.dart';
import '../utils/property_availability_ui.dart';
import '../utils/listing_fields_parse.dart';
import 'package:casa/utils/casanayo_share_copy.dart';

/// Complète [incoming] avec les champs encore présents dans [base] (navigation depuis liste partielle).
TerrainModel _mergeTerrainSnapshot(TerrainModel base, TerrainModel incoming) {
  String? coalesceStr(String? a, String? b) {
    if (a != null && a.trim().isNotEmpty) return a;
    return b;
  }

  final bt = base.terrain;
  final it = incoming.terrain;

  TerrainData? mergedTerrain;
  if (it != null && bt != null) {
    mergedTerrain = TerrainData(
      id: it.id ?? bt.id,
      userId: it.userId ?? bt.userId,
      title: coalesceStr(it.title, bt.title),
      description: coalesceStr(it.description, bt.description),
      price: it.price ?? bt.price,
      surface: coalesceStr(it.surface, bt.surface),
      transactionType: coalesceStr(it.transactionType, bt.transactionType),
      isAvailable:
          ListingFieldsParse.mergeAvailable(it.isAvailable, bt.isAvailable) ??
              it.isAvailable ??
              bt.isAvailable,
      sold: ListingFieldsParse.mergeSold(it.sold, bt.sold) ?? it.sold ?? bt.sold,
      createdAt: coalesceStr(it.createdAt, bt.createdAt),
    );
  } else {
    mergedTerrain = it ?? bt;
  }

  final mergedImages = (incoming.images != null && incoming.images!.isNotEmpty)
      ? incoming.images
      : base.images;

  return TerrainModel(
    terrain: mergedTerrain,
    devise: incoming.devise ?? base.devise,
    postBy: coalesceStr(incoming.postBy, base.postBy),
    address: incoming.address ?? base.address,
    localAddress: incoming.localAddress ?? base.localAddress,
    geoZone: incoming.geoZone ?? base.geoZone,
    images: mergedImages,
    typeProperty: incoming.typeProperty ?? base.typeProperty,
    publisherImage: coalesceStr(incoming.publisherImage, base.publisherImage),
  );
}

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
  late TerrainModel _displayTerrain;

  @override
  void initState() {
    super.initState();
    _displayTerrain = widget.terrain;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _startAutoScroll();
      final ctrl = context.read<PropertyController>();
      final id = _displayTerrain.terrain?.id;
      if (id != null) {
        final snap = await ctrl.findCachedPropertySnapshot(id, typeId: 9);
        if (mounted && snap != null) {
          setState(() {
            _displayTerrain = _mergeTerrainSnapshot(
              _displayTerrain,
              TerrainModel.fromPropertyListing(snap),
            );
          });
          _startAutoScroll();
        }
      }
      await _refreshTerrainFromApi();
    });
  }

  Future<void> _refreshTerrainFromApi() async {
    final id = _displayTerrain.terrain?.id;
    if (id == null) return;
    final ctrl = context.read<PropertyController>();
    final fresh = await ctrl.fetchTerrainById(id);
    if (!mounted || fresh == null) return;
    setState(() {
      _displayTerrain = _mergeTerrainSnapshot(_displayTerrain, fresh);
    });
    _startAutoScroll();
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _imageController.dispose();
    super.dispose();
  }

  void _startAutoScroll() {
    final images = _displayTerrain.images ?? [];
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
                _buildTerrainTypeSection(),
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
    final images = _displayTerrain.images ?? [];
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
                            : 'terrain_image_${_displayTerrain.terrain?.id}_$index',
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
        // Favorite & Share Buttons
        Positioned(
          top: 50,
          right: 20,
          child: Row(
            children: [
              if (_displayTerrain.terrain?.id != null)
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  child: FavoriteHeartIcon(
                    propertyId: _displayTerrain.terrain!.id.toString(),
                    propertyTypeId: 9, // Terrain
                    size: 24,
                    splashRadius: 20,
                    activeColor: Colors.red,
                    inactiveColor: Colors.white,
                  ),
                ),
              const SizedBox(width: 12),
              _buildCircleButton(
                icon: Icons.share,
                onTap: _shareTerrain,
              ),
            ],
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
    final title = _displayTerrain.terrain?.title ?? 'Terrain';
    final price = _displayTerrain.terrain?.price ?? 0;
    final rawCurrency = _displayTerrain.devise?.code ?? 'USD';
    final currency = (rawCurrency == 'USD') ? '\$' : (rawCurrency == 'CDF' ? 'FC' : rawCurrency);
    
    final intro = <String>[
      'Découvrez ce terrain : $title',
      '',
      'Prix : $price $currency',
      '',
      "Sur l'application CasaNayo !",
    ].join('\n');
    await Share.share(
      '$intro\n\n${CasanayoShareCopy.listingShareFooter(listingId: _displayTerrain.terrain?.id, kindLabel: 'terrain')}',
      subject: 'Terrain à voir',
    );
  }

  bool _terrainIsVente(TerrainData? t) =>
      t?.transactionType?.toLowerCase().contains('vente') ?? false;

  bool _terrainVisitBlocked(TerrainData? t) {
    return PropertyAvailabilityUi.blocksSchedulingVisit(
      sold: t?.sold,
      available: t?.isAvailable,
      listingAllowed: true,
    );
  }

  String _terrainAvailabilityTitleCase(TerrainData? t) {
    final lbl = PropertyAvailabilityUi.listingStatusLabel(
      sold: t?.sold,
      available: t?.isAvailable,
      transactionType: t?.transactionType,
      listingAllowed: true,
    );
    return lbl ?? 'Disponible';
  }

  Widget _buildHeaderSection() {
    final t = _displayTerrain.terrain;
    final isVente = _terrainIsVente(t);
    final blocked = _terrainVisitBlocked(t);
    final canVisit = !blocked;
    final availLabel = _terrainAvailabilityTitleCase(t);
    final price = t?.price ?? 0;
    final rawCurrency = _displayTerrain.devise?.code ?? 'USD';
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
                 color: canVisit
                     ? const Color(0xFF00B894).withOpacity(0.12)
                     : const Color(0xFFD63031).withOpacity(0.12),
                 borderRadius: BorderRadius.circular(8),
               ),
               child: Row(
                 mainAxisSize: MainAxisSize.min,
                 children: [
                   Icon(
                     canVisit ? Icons.check_circle : Icons.block,
                     size: 14,
                     color: canVisit ? const Color(0xFF00B894) : const Color(0xFFD63031),
                   ),
                   SizedBox(width: 4),
                   Text(
                     availLabel.toUpperCase(),
                     style: TextStyle(
                       color: canVisit ? const Color(0xFF00B894) : const Color(0xFFD63031),
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

  /// Localisation : afficher uniquement commune + ville (confidentialité).
  Widget _buildLocationPreview() {
    final addr = _displayTerrain.address;
    final city = addr?.cityValue ?? _displayTerrain.localAddress?.city?.name ?? 'Kinshasa';
    final commune = addr?.communeValue ?? _displayTerrain.localAddress?.commune?.name ?? '';
    final locationText = commune.isNotEmpty ? "$city, $commune" : city;

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
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTerrainTypeSection() {
    final typeName = _displayTerrain.typeProperty?.name?.trim();
    if (typeName == null || typeName.isEmpty) return const SizedBox.shrink();
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
          Text('TYPE DE BIEN', style: TextStyle(
            fontSize: 10, fontWeight: FontWeight.bold, color: _greyColor, letterSpacing: 1.2,
          )),
          SizedBox(height: 8),
          Text(typeName, style: TextStyle(fontSize: 14, color: _darkColor)),
        ],
      ),
    );
  }

  String _formatTransactionLabel(String raw) {
    final t = raw.toLowerCase();
    if (t.contains('vente')) return 'Vente';
    if (t.contains('locat')) return 'Location';
    return raw;
  }

  Widget _characteristicRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _secondaryColor, size: 22),
          SizedBox(width: 10),
          Expanded(
            child: Text(label, style: TextStyle(color: _greyColor, fontSize: 14)),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: _darkColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCharacteristicsSection() {
    final t = _displayTerrain.terrain;
    final surface = t?.surface;
    final tt = t?.transactionType?.trim();
    final hasSurface = surface != null && surface.isNotEmpty;
    final hasTx = tt != null && tt.isNotEmpty;
    if (!hasSurface && !hasTx) return const SizedBox.shrink();

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
            fontSize: 10, fontWeight: FontWeight.bold, color: _greyColor, letterSpacing: 1.2,
          )),
          SizedBox(height: 8),
          if (hasTx) _characteristicRow(Icons.swap_horiz, 'Transaction', _formatTransactionLabel(tt!)),
          if (hasSurface)
            _characteristicRow(
              Icons.square_foot,
              'Surface',
              surface!.contains('x') || surface.contains('×') ? surface : '$surface m²',
            ),
        ],
      ),
    );
  }

  Widget _buildPublicationInfoSection() {
    String publisherName = '';
    String? publisherImage = _displayTerrain.publisherImage;

    if (_displayTerrain.postBy != null && _displayTerrain.postBy!.isNotEmpty) {
      publisherName = _displayTerrain.postBy!.replaceAll('@', '').trim();
    }

    if (publisherName.isEmpty) {
      publisherName = 'Propriétaire';
    }

    final published = _displayTerrain.terrain?.createdAt;
    final publishedLabel = published != null && published.trim().isNotEmpty
        ? _formatDate(published)
        : '';

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
                   tag: 'publisher_profile_${_displayTerrain.terrain?.id}',
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      publisherName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _darkColor,
                      ),
                    ),
                    if (publishedLabel.isNotEmpty) ...[
                      SizedBox(height: 6),
                      Text(
                        'Publié le $publishedLabel',
                        style: TextStyle(color: _greyColor, fontSize: 13),
                      ),
                    ],
                  ],
                ),
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
    final desc = _displayTerrain.terrain?.description;
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
    final t = _displayTerrain.terrain;
    final blocked = _terrainVisitBlocked(t);

    return Column(
      children: [
        ElevatedButton(
          onPressed: blocked
              ? null
              : () {
                  final token = storage.read(StockageKeys.tokenKey);
                  if (token == null) {
                    FancyNotification.show(
                      context,
                      "Vous devez être connecté pour planifier une visite",
                      type: NotificationType.info,
                    );
                    Navigator.push(context, MaterialPageRoute(builder: (_) => LoginScreen()));
                  } else {
                    SubscriptionHelper.checkPremiumForPropertyReservation(
                      context: context,
                      onProceed: () {
                        Navigator.pushNamed(
                          context,
                          Routes.bookingVisitPageRoute,
                          arguments: _displayTerrain,
                        );
                      },
                    );
                  }
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: blocked ? Colors.red.shade700 : _primaryColor,
            foregroundColor: Colors.white,
            disabledForegroundColor: Colors.white.withOpacity(0.95),
            disabledBackgroundColor: Colors.red.shade800,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: EdgeInsets.symmetric(vertical: 16),
            elevation: blocked ? 0 : 2,
            minimumSize: Size(double.infinity, 50),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(blocked ? Icons.block : Icons.calendar_today, size: 20),
              SizedBox(width: 8),
              Text(
                blocked
                    ? _terrainAvailabilityTitleCase(t).toUpperCase()
                    : 'PLANIFIER UNE VISITE',
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
