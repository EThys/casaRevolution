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

    // SILENT LOADING: Charger la prestation complète en arrière-plan
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.service.id != null) {
        context.read<ServiceController>().getPrestationById(widget.service.id!);
      }
    });
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

  Future<void> _shareService(PrestationModel service) async {
    final priceText = _getPriceRange(service);

    final shareText = '''
🔧 ${service.title ?? 'Service professionnel'} - ${service.cityValue}, ${service.communeValue}

💰 ${priceText}
${service.description != null ? '\n${service.description}\n' : ''}
Découvrez ce service sur CasaNayo!
''';

    try {
      final box = context.findRenderObject() as RenderBox?;
      if (box != null) {
        await Share.share(
          shareText,
          subject: 'Service ${service.title ?? ''}',
          sharePositionOrigin: box.localToGlobal(Offset.zero) & box.size,
        );
      } else {
        await Share.share(
          shareText,
          subject: 'Service ${service.title ?? ''}',
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
    // SILENT LOADING: Ecouter le controller pour mettre à jour les données dès qu'elles arrivent
    final serviceCtrl = context.watch<ServiceController>();
    final bool hasFullData = serviceCtrl.currentPrestation?.id == widget.service.id;
    final PrestationModel service = hasFullData ? serviceCtrl.currentPrestation! : widget.service;

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
              background: hasImages && images.length > 1
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
                propertyId: service.id.toString(),
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
                onPressed: () => _shareService(service),
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
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [primaryColor.withOpacity(0.1), accentColor.withOpacity(0.1)],
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.work_history,
                              color: primaryColor,
                              size: 28,
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Expérience professionnelle',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                SizedBox(height: 4),
                                 Text(
                                  _formatExperience(service.experience),
                                  style: GoogleFonts.inter(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: darkBlue,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 24),
                  ],

                  // Informations du publicateur
                  _buildPublicationInfoSectionFor(service),
                  SizedBox(height: 24),

                  // Informations de contact
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Informations de contact',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: darkBlue,
                          ),
                        ),
                        SizedBox(height: 16),
                        if (service.address != null && service.address!.isNotEmpty)
                          _buildInfoRow(
                            Icons.location_on,
                            "${service.cityValue}, ${service.communeValue}",
                            Colors.red,
                          ),
                        SizedBox(height: 12),
                        _buildInfoRow(
                          Icons.lock,
                          'Les contacts seront partagés après validation de votre demande.',
                          Colors.orange,
                          onTap: null,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 24),

                  // Disponibilité
                  if (service.plageJourPrestation != null ||
                      service.plageHeurePrestation != null)
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Disponibilité',
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: darkBlue,
                            ),
                          ),
                          SizedBox(height: 12),
                          if (service.plageJourPrestation != null &&
                              service.plageJourPrestation!.isNotEmpty)
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: service.plageJourPrestation!
                                  .split(',')
                                  .map((day) {
                                return Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: primaryColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    day.trim(),
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: primaryColor,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          if (service.plageHeurePrestation != null &&
                              service.plageHeurePrestation!.isNotEmpty) ...[
                            SizedBox(height: 12),
                            Row(
                              children: [
                                Icon(Icons.access_time,
                                    size: 16, color: primaryColor),
                                SizedBox(width: 8),
                                Text(
                                  service.plageHeurePrestation!,
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  SizedBox(height: 24),

                  // Réalisations précédentes (galerie)
                  if (hasImages && images.length > 1) ...[
                    SizedBox(height: 24),
                    Text(
                      'Réalisations précédentes',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: darkBlue,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Quelques travaux déjà réalisés par ce prestataire.',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.grey[700],
                      ),
                    ),
                    SizedBox(height: 12),
                    SizedBox(
                      height: 120,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: images.length,
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
                            child: Container(
                              width: 120,
                              margin: EdgeInsets.only(right: 12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: primaryColor.withOpacity(0.2),
                                  width: 2,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: CachedNetworkImage(
                                  imageUrl: images[index],
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(
                                    color: primaryColor.withOpacity(0.1),
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                            primaryColor),
                                      ),
                                    ),
                                  ),
                                  errorWidget: (context, url, error) =>
                                      Container(
                                    color: primaryColor.withOpacity(0.1),
                                    child: Icon(
                                      Icons.image,
                                      color: primaryColor.withOpacity(0.3),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],

                  // Avis clients (statiques)
                  SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Avis des clients',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: darkBlue,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          Navigator.pushNamed(
                            context,
                            Routes.allReviewsRoute,
                            arguments: service,
                          );
                        },
                        icon: Icon(Icons.arrow_forward_ios, size: 14),
                        label: Text(
                          'Voir tous',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  _buildReviewCard(
                    name: 'Patrick K.',
                    rating: 4.8,
                    comment:
                        'Travail propre et rapide, très professionnel. Je recommande.',
                    datePosted: DateTime.now().subtract(Duration(days: 5)),
                  ),
                  SizedBox(height: 8),
                  _buildReviewCard(
                    name: 'Mireille N.',
                    rating: 4.7,
                    comment:
                        'Ponctuel et soigneux, les finitions sont impeccables.',
                    datePosted: DateTime.now().subtract(Duration(days: 12)),
                  ),
                  SizedBox(height: 8),
                  _buildReviewCard(
                    name: 'Arnaud T.',
                    rating: 4.9,
                    comment:
                        'Très bonne communication et respect des délais.',
                    datePosted: DateTime.now().subtract(Duration(days: 3)),
                  ),

                  // Bouton principal : Demander une intervention
                  SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        final storage = GetStorage();
                        final token = storage.read(StockageKeys.tokenKey);
                        
                        if (token == null) {
                          FancyNotification.show(
                            context, 
                            "Vous devez être connecté pour demander une intervention",
                            type: NotificationType.info
                          );
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => LoginScreen()),
                          );
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => RequestInterventionPage(
                                service: service,
                              ),
                            ),
                          );
                        }
                      },
                      icon: Icon(Icons.handshake),
                      label: Text('Demander une intervention'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Les coordonnées seront partagées après validation de votre demande.',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.grey[700],
                    ),
                  ),
                  SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
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

  String _formatExperience(String? experience) {
    if (experience == null || experience.isEmpty) {
      return 'Non spécifié';
    }
    // Assuming experience is a number string representing years
    try {
      final int years = int.parse(experience);
      if (years > 0) {
        return '$years ${years > 1 ? 'ans' : 'an'}';
      }
    } catch (e) {
      // Not a number, return as is
    }
    return experience;
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
    // Modified to use properties available in PrestationModel only
    final String? username = service.username;
    final String? postBy = service.postBy;
    final String? profilePicture = service.profile;

    String publisherName = '';
    
    // Essayer postBy d'abord car souvent plus fiable (ex: @LéaReckiel)
    if (postBy != null && postBy.isNotEmpty && postBy != 'null') {
      publisherName = postBy.replaceAll('@', '').trim();
    } 
    // Sinon essayer username
    else if (username != null && username.isNotEmpty && username != 'null') {
      publisherName = username.replaceAll('@', '').trim();
    }
    
    if (publisherName.isEmpty) publisherName = 'Prestataire';

    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Publié par',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: darkBlue,
            ),
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      primaryColor.withOpacity(0.2),
                      accentColor.withOpacity(0.2)
                    ],
                  ),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(
                      color: primaryColor.withOpacity(0.3), width: 2),
                ),
                  child: GestureDetector(
                    onTap: () {
                      if (profilePicture != null && profilePicture.isNotEmpty) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ServiceFullScreenImageViewer(
                              imageUrls: [profilePicture],
                              initialIndex: 0,
                            ),
                          ),
                        );
                      }
                    },
                    child: Hero(
                      tag: 'service_profile_${service.id}',
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(23),
                        child: profilePicture != null &&
                                profilePicture.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: profilePicture,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Center(
                                    child: CircularProgressIndicator(strokeWidth: 2)),
                                errorWidget: (context, url, error) => Center(
                                    child: Text(
                                  publisherName.isNotEmpty
                                      ? publisherName[0].toUpperCase()
                                      : 'A',
                                  style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: primaryColor),
                                )),
                              )
                            : Center(
                                child: Text(
                                  publisherName.isNotEmpty
                                      ? publisherName[0].toUpperCase()
                                      : 'A',
                                  style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: primaryColor),
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
                              color: Colors.black87,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(width: 6),
                        if (service.isCertified ?? false)
                          Icon(Icons.verified, size: 16, color: Colors.blue),
                      ],
                    ),
                    if (service.dateCreated != null)
                      Text(
                        'Publié le ${DateFormat('dd MMM yyyy', 'fr_FR').format(service.dateCreated!)}',
                        style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13,
                            fontWeight: FontWeight.w500),
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

}

