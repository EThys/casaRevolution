import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart'; // Added for date formatting
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import '../models/PrestationModel.dart';
import '../utils/FancyNotification.dart';
import '../utils/FavoriteEartIcon.dart';
import '../utils/Routes.dart';
import 'ServiceFullScreenImageViewer.dart';
import 'RequestInterventionPage.dart';
import 'package:get_storage/get_storage.dart';
import 'package:casa/utils/StockageKeys.dart';
import '../controllers/ServiceController.dart'; // Added
import 'package:provider/provider.dart'; // Added
import 'auth/LoginScreen.dart';

class ServiceDetailPage extends StatefulWidget {
  final PrestationModel service;
  final String? serviceTypeName;

  const ServiceDetailPage({
    Key? key,
    required this.service,
    this.serviceTypeName,
  }) : super(key: key);

  @override
  _ServiceDetailPageState createState() => _ServiceDetailPageState();
}

class _ServiceDetailPageState extends State<ServiceDetailPage> {
  static const Color primaryColor = Color(0xFF1976D2);
  static const Color accentColor = Color(0xFF64B5F6);
  static const Color darkBlue = Color(0xFF0D47A1);

  late PageController _imageController;
  int _currentImageIndex = 0;
  Timer? _autoScrollTimer;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('fr_FR', null);
    
    // Ensure images list includes profile if images is empty or null
    List<String> images = widget.service.images ?? [];
    if (images.isEmpty && widget.service.profile != null && widget.service.profile!.isNotEmpty) {
      images = [widget.service.profile!];
      widget.service.images = images; // Update the service model
    }
    
    _imageController = PageController(initialPage: 0);

    // Démarrage du défilement automatique si plusieurs images
    if (images.length > 1) {
      _startAutoScroll();
    }
  }

  void _startAutoScroll() {
    final images = widget.service.images ?? [];
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
        duration: Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _imageController.dispose();
    super.dispose();
  }

  Future<void> _shareService() async {
    final priceText = _getPriceRange(widget.service);

    final shareText = '''
🔧 ${widget.service.title ?? 'Service professionnel'} - ${widget.service.cityValue}, ${widget.service.communeValue}

💰 ${priceText}
${widget.service.description != null ? '\n${widget.service.description}\n' : ''}
Découvrez ce service sur Casa!
''';

    try {
      final box = context.findRenderObject() as RenderBox?;
      if (box != null) {
        await Share.share(
          shareText,
          subject: 'Service ${widget.service.title ?? ''}',
          sharePositionOrigin: box.localToGlobal(Offset.zero) & box.size,
        );
      } else {
        await Share.share(
          shareText,
          subject: 'Service ${widget.service.title ?? ''}',
        );
      }
    } catch (e) {
      if (mounted) {
        FancyNotification.show(
          context,
          'Erreur lors du partage: ${e.toString()}',
          type: NotificationType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final serviceCtrl = context.watch<ServiceController>();
    
    // Choose the best data available
    final bool hasFullData = serviceCtrl.currentPrestation?.id == widget.service.id;
    final PrestationModel service = hasFullData ? serviceCtrl.currentPrestation! : widget.service;
    final bool isLoading = serviceCtrl.loading && !hasFullData;

    final images = service.images ?? [];
    final hasImages = images.isNotEmpty;
    final firstImage = hasImages ? images.first : null;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        slivers: [
          // AppBar avec carrousel d'images
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: isLoading && !hasImages
                  ? _buildShimmerCarousel()
                  : hasImages && images.length > 1
                      ? _buildImageCarousel(images)
                      : firstImage != null
                          ? GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ServiceFullScreenImageViewer(
                                      imageUrls: images,
                                      initialIndex: 0,
                                    ),
                                  ),
                                );
                              },
                              child: CachedNetworkImage(
                                imageUrl: firstImage,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  color: primaryColor.withOpacity(0.1),
                              child: Center(
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: primaryColor.withOpacity(0.1),
                              child: Icon(
                                Icons.build,
                                size: 64,
                                color: primaryColor.withOpacity(0.3),
                              ),
                            ),
                          ),
                        )
                      : Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [primaryColor, darkBlue],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Center(
                            child: Icon(
                              Icons.build,
                              size: 64,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                        ),
            ),
            leading: IconButton(
              icon: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 16),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              // Bouton favoris
              Container(
                margin: EdgeInsets.only(right: 8),
              child: FavoriteHeartIcon(
                propertyId: widget.service.id.toString(),
                isPrestation: true,
                size: 24,
                activeColor: Colors.red,
                inactiveColor: Colors.white,
              ),
              ),
              // Bouton partager
              IconButton(
                icon: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.share, color: Colors.white, size: 18),
                ),
                onPressed: () => _shareServiceFor(service),
              ),
            ],
          ),

          // Contenu
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Badge Vérifié
                  if (service.isCertified == true)
                    Container(
                      margin: EdgeInsets.only(bottom: 16),
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified, color: Colors.white, size: 16),
                          SizedBox(width: 4),
                          Text(
                            'Vérifié',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Titre et note
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              service.title ?? 'Service sans titre',
                              style: GoogleFonts.inter(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: darkBlue,
                              ),
                            ),
                            SizedBox(height: 8),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.build,
                                    size: 16,
                                    color: primaryColor,
                                  ),
                                  SizedBox(width: 6),
                                  Consumer<ServiceController>(
                                    builder: (context, serviceController, child) {
                                      final resolvedName = widget.serviceTypeName ?? 
                                                         serviceController.getServiceName(service.serviceId);
                                      return Text(
                                        resolvedName,
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: primaryColor,
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // if (service.rating != null) ...[
                      //   // Rating removed as it is not present in PrestationModel
                      // ],
                    ],
                  ),
                  SizedBox(height: 24),

                  // Prix
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [primaryColor, accentColor],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withOpacity(0.3),
                          blurRadius: 8,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Prix',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          _getPriceRange(service),
                          style: GoogleFonts.inter(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 24),

                  // Description
                  if (service.description != null) ...[
                    Text(
                      'Description',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: darkBlue,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      service.description!,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        color: Colors.grey[700],
                        height: 1.6,
                      ),
                    ),
                    SizedBox(height: 24),
                  ],

                  // Expérience professionnelle
                  if (service.experience != null && service.experience!.isNotEmpty) ...[
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.work_outline, color: primaryColor, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Expérience professionnelle',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: darkBlue,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 12),
                          Text(
                            _formatExperience(service.experience),
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              color: Colors.grey[800],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 24),
                  ],

                  // Localisation
                  Text(
                    'Localisation',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: darkBlue,
                    ),
                  ),
                  SizedBox(height: 16),
                  _buildInfoRow(
                    Icons.location_on_outlined, 
                    service.communeId != null 
                        ? '${service.quartier ?? ''}, ${service.communeId}'
                        : (service.quartier ?? 'Localisation non spécifiée'), 
                    Colors.red
                  ),
                  SizedBox(height: 24),
                  
                  // Infos de contact
                  Text(
                    'Contact',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: darkBlue,
                    ),
                  ),
                  SizedBox(height: 16),
                  if (service.email != null)
                    _buildInfoRow(Icons.email_outlined, service.email!, Colors.blue),
                  if (service.phone != null)
                    _buildInfoRow(Icons.phone_outlined, service.phone!, Colors.green, 
                        onTap: () => _makePhoneCall(context, service.phone!)),
                  if (service.whatsapp != null)
                    _buildInfoRow(Icons.message_outlined, 'WhatsApp', Color(0xFF25D366), 
                        onTap: () => _openWhatsApp(context, service.whatsapp!)),
                  
                  SizedBox(height: 32),

                  // Infos Publication
                  _buildPublicationInfoSectionFor(service),
                  
                  SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: Offset(0, -5),
            ),
          ],
        ),
        child: Row(
          children: [
            if (service.phone != null)
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _makePhoneCall(context, service.phone!),
                  icon: Icon(Icons.phone, size: 20),
                  label: Text('Appeler'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            if (service.phone != null && service.whatsapp != null)
              SizedBox(width: 12),
            if (service.whatsapp != null)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openWhatsApp(context, service.whatsapp!),
                  icon: Icon(Icons.message, size: 20),
                  label: Text('WhatsApp'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Color(0xFF25D366),
                    side: BorderSide(color: Color(0xFF25D366)),
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageCarousel(List<String> images) {
    return Stack(
      children: [
        PageView.builder(
          controller: _imageController,
          itemCount: images.length,
          onPageChanged: (index) {
            setState(() {
              _currentImageIndex = index;
            });
          },
          itemBuilder: (context, index) {
            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ServiceFullScreenImageViewer(
                      imageUrls: images,
                      initialIndex: index,
                    ),
                  ),
                );
              },
              child: Hero(
                tag: 'service_image_$index',
                child: CachedNetworkImage(
                  imageUrl: images[index],
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  placeholder: (context, url) => Container(
                    color: primaryColor.withOpacity(0.1),
                    child: Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: primaryColor.withOpacity(0.1),
                    child: Icon(
                      Icons.build,
                      size: 64,
                      color: primaryColor.withOpacity(0.3),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        // Indicateur de page
        if (images.length > 1)
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_currentImageIndex + 1} / ${images.length}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String text, Color color,
      {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
          ),
          if (onTap != null)
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
        ],
      ),
    );
  }

  String _formatPrice(num price) {
    if (price >= 1000000) {
      return '${(price / 1000000).toStringAsFixed(1)}M';
    } 
    // Logic for 'K' removed as per request
    return price.toStringAsFixed(0);
  }

  String _getPriceRange(PrestationModel service) {
    if (service.minPrice == null)
      return 'Prix sur demande';

    final double minPrice = service.minPrice!;
    // Max price ignored for display as per request ("À partir de")

    final displayCurrency = service.currency;

    return 'À partir de ${_formatPrice(minPrice)} $displayCurrency';
  }

  void _makePhoneCall(BuildContext context, String phone) {
    FancyNotification.show(
      context,
      'Numéro: $phone',
      type: NotificationType.info,
    );
    // TODO: Implémenter l'appel téléphonique avec url_launcher
  }

  void _openWhatsApp(BuildContext context, String phone) {
    FancyNotification.show(
      context,
      'Numéro WhatsApp: $phone',
      type: NotificationType.info,
    );
    // TODO: Implémenter l'ouverture WhatsApp avec url_launcher
  }

  String _getTimeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'À l\'instant';
        }
        return 'Il y a ${difference.inMinutes} ${difference.inMinutes > 1 ? 'minutes' : 'minute'}';
      }
      return 'Aujourd\'hui à ${date.hour.toString().padLeft(2, '0')}h${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Hier à ${date.hour.toString().padLeft(2, '0')}h${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays < 7) {
      return 'Il y a ${difference.inDays} ${difference.inDays > 1 ? 'jours' : 'jour'}';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return 'Il y a ${weeks} ${weeks > 1 ? 'semaines' : 'semaine'}';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return 'Il y a ${months} ${months > 1 ? 'mois' : 'mois'}';
    } else {
      final years = (difference.inDays / 365).floor();
      return 'Il y a ${years} ${years > 1 ? 'ans' : 'an'}';
    }
  }

  Widget _buildReviewCard({
    required String name,
    required double rating,
    required String comment,
    DateTime? datePosted,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: primaryColor.withOpacity(0.1),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: TextStyle(
                      color: primaryColor, fontWeight: FontWeight.bold),
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: darkBlue,
                      ),
                    ),
                    Row(
                      children: [
                        Icon(Icons.star, color: Colors.amber, size: 16),
                        SizedBox(width: 4),
                        Text(
                          rating.toStringAsFixed(1),
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                          ),
                        ),
                        if (datePosted != null) ...[
                          SizedBox(width: 8),
                          Text(
                            '• ${_getTimeAgo(datePosted)}',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            comment,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: Colors.grey[700],
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPublicationInfoSectionFor(PrestationModel service) {
    final user = service.user;
    
    // Get publisher name from user info or fallback
    String publisherName = user?.username ?? service.username ?? '';
    // Remove @ symbol if present
    publisherName = publisherName.replaceAll('@', '').trim();
    
    if (publisherName.isEmpty) {
      return SizedBox();
    }

    final String? profilePicture = user?.profilePicture;
    final String? createdAt = service.createdAt;

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[100]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Publié par',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[500],
              letterSpacing: 0.5,
            ),
          ),
          SizedBox(height: 16),
          Row(
            children: [
              // Photo de profil
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withOpacity(0.1),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: profilePicture != null && profilePicture.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: profilePicture,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                            ),
                          ),
                          errorWidget: (context, url, error) => Center(
                            child: Text(
                              publisherName[0].toUpperCase(),
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
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
                              color: primaryColor,
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
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            publisherName,
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: darkBlue,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (service.isCertified == true) ...[
                          SizedBox(width: 6),
                          Icon(Icons.verified, size: 18, color: Colors.blue),
                        ],
                      ],
                    ),
                    if (createdAt != null) ...[
                      SizedBox(height: 4),
                      Text(
                        'Publication : ${DateFormat('dd/MM/yyyy').format(DateTime.parse(createdAt))}',
                        style: GoogleFonts.inter(
                          color: Colors.grey[500],
                          fontSize: 13,
                        ),
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

  Widget _buildShimmerCarousel() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        height: 300,
        color: Colors.white,
        child: Center(
          child: Icon(Icons.photo, size: 80, color: Colors.grey[400]),
        ),
      ),
    );
  }

  String _formatExperience(String? experience) {
    if (experience == null || experience.isEmpty) return 'Non précisée';
    final n = int.tryParse(experience);
    if (n == null) return experience; // Return original if not a pure number
    if (n == 1) return '1 an';
    return '$n ans';
  }
}
