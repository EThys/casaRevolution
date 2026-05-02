import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:intl/intl.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:casa/models/AgenceModel.dart';
import 'package:casa/models/PropertyImageModel.dart';
import 'package:casa/models/PropertyModel.dart';
import 'package:casa/screens/auth/LoginScreen.dart';
import 'package:casa/utils/FancyNotification.dart';
import 'package:casa/utils/Routes.dart';
import 'package:casa/utils/SubscriptionHelper.dart';
import 'package:casa/utils/StockageKeys.dart';
import 'dart:async';

class SiteDetailsPage extends StatefulWidget {
  final AgenceSiteModel site;

  const SiteDetailsPage({Key? key, required this.site}) : super(key: key);

  @override
  _SiteDetailsPageState createState() => _SiteDetailsPageState();
}

class _SiteDetailsPageState extends State<SiteDetailsPage> {
  final Color _primaryColor = Color(0xFF1976D2);
  final Color _secondaryColor = Color(0xFF64B5F6);
  final Color _darkColor = Color(0xFF2D3748);
  final Color _lightColor = Color(0xFFF8F9FA);
  final Color _greyColor = Color(0xFF6C757D);
  final GetStorage _storage = GetStorage();
  
  late final PageController _imageController;
  int _currentImageIndex = 0;
  Timer? _autoScrollTimer;
  bool _isDescriptionExpanded = false;

  @override
  void initState() {
    super.initState();
    _imageController = PageController(viewportFraction: 1.0);
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
    final images = widget.site.images ?? [];
    if (images.length <= 1) return;

    _autoScrollTimer?.cancel();
    
    _autoScrollTimer = Timer.periodic(Duration(seconds: 3), (timer) {
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
  Widget build(BuildContext context) {
    final images = widget.site.images ?? [];
    
    return Scaffold(
      backgroundColor: _lightColor,
      extendBody: true,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _buildImageCarousel(images),
          ),
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                SizedBox(height: 20),
                _buildHeaderSection(),
                SizedBox(height: 16),
                _buildPriceSection(),
                SizedBox(height: 16),
                _buildInfoChips(),
                SizedBox(height: 16),
                _buildDescriptionSection(),
                SizedBox(height: 16),
                _buildAdditionalInfo(),
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

  DateTime? _parseVacanceDateRaw(String raw) {
    final s = raw.trim();
    try {
      return DateTime.parse(s);
    } catch (_) {}
    try {
      if (RegExp(r'^\d{1,2}/\d{1,2}/\d{4}$').hasMatch(s)) {
        final p = s.split('/');
        return DateTime(
          int.parse(p[2]),
          int.parse(p[1]),
          int.parse(p[0]),
        );
      }
    } catch (_) {}
    return null;
  }

  String _dateVacanceAffichee(String raw) {
    final d = _parseVacanceDateRaw(raw);
    if (d == null) return raw;
    return DateFormat('dd/MM/yyyy', 'fr_FR').format(d);
  }

  PropertyModel _stubPropertyForBooking() {
    final site = widget.site;
    return PropertyModel(
      propertyId: site.id,
      title: site.title,
      propertyTypeId: 6,
      available: site.available ?? true,
      listingAllowed: true,
      price: site.price,
      propertyImage: site.images
          ?.map((u) => PropertyImageModel(path: u))
          .toList(),
    );
  }

  void _navigateToBooking() {
    if (widget.site.available == false) {
      SnackbarForCasa.error(
        context,
        "Ce site n'est pas disponible pour une réservation.",
      );
      return;
    }
    if (widget.site.id == null) {
      SnackbarForCasa.error(context, "Impossible de réserver : identifiant du site manquant.");
      return;
    }

    final token = _storage.read(StockageKeys.tokenKey);
    if (token == null) {
      FancyNotification.show(
        context,
        "Vous devez être connecté pour réserver",
        type: NotificationType.info,
      );
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => LoginScreen()),
      );
      return;
    }

    SubscriptionHelper.checkPremiumForPropertyReservation(
      context: context,
      onProceed: () {
        Navigator.pushNamed(
          context,
          Routes.bookingVisitPageRoute,
          arguments: {
            'property': _stubPropertyForBooking(),
            'agenceVacanceBooking': true,
            'initialVacanceDate': widget.site.dateVacance,
            'initialVacanceHeure': widget.site.heureVacance,
          },
        );
      },
    );
  }

  Widget _buildImageCarousel(List<String> images) {
    final carouselHeight = MediaQuery.of(context).size.height * 0.4;

    if (images.isEmpty) {
      return Container(
        height: carouselHeight,
        color: Colors.grey[200],
        child: Center(
          child: Icon(Icons.image_not_supported, size: 60, color: Colors.grey[400]),
        ),
      );
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
              _startAutoScroll();
            },
            itemBuilder: (context, index) {
              return CachedNetworkImage(
                imageUrl: images[index],
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

        // Share button
        Positioned(
          top: 50,
          right: 20,
          child: _buildActionButton(
            icon: Icons.share,
            onPressed: () {
              // Share functionality
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Partage en cours de développement')),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
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
            color: Colors.white,
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
          runSpacing: 8,
          children: [
            if (widget.site.available == true)
              Chip(
                backgroundColor: Colors.green.withOpacity(0.1),
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, size: 14, color: Colors.green),
                    SizedBox(width: 4),
                    Text(
                      'DISPONIBLE',
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                shape: StadiumBorder(),
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              ),
            Chip(
              backgroundColor: _secondaryColor.withOpacity(0.1),
              label: Text(
                'SITE TOURISTIQUE',
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
          widget.site.title ?? 'Site Touristique',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: _darkColor,
            height: 1.3,
          ),
        ),
      ],
    );
  }

  Widget _buildPriceSection() {
    if (widget.site.price == null || widget.site.price! <= 0) {
      return SizedBox.shrink();
    }

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
                Text(
                  'Droit de participation',
                  style: TextStyle(
                    fontSize: 12,
                    color: _greyColor,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.6,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  '${widget.site.price?.toInt() ?? 0} \$',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: _primaryColor,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChips() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        if (widget.site.dateVacance != null && widget.site.dateVacance!.isNotEmpty)
          _buildInfoChip(
            icon: Icons.calendar_month,
            label: 'Date · ${_dateVacanceAffichee(widget.site.dateVacance!)}',
            color: _primaryColor,
          ),
        if (widget.site.heureVacance != null && widget.site.heureVacance!.isNotEmpty)
          _buildInfoChip(
            icon: Icons.access_time,
            label: 'Heure · ${widget.site.heureVacance!}',
            color: _secondaryColor,
          ),
      ],
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionSection() {
    if (widget.site.description == null || widget.site.description!.isEmpty) {
      return SizedBox.shrink();
    }

    final shouldTruncate = widget.site.description!.length > 200;
    final displayText = _isDescriptionExpanded || !shouldTruncate
        ? widget.site.description!
        : '${widget.site.description!.substring(0, 200)}...';

    return Container(
      padding: EdgeInsets.all(20),
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
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.description, size: 20, color: _primaryColor),
              ),
              SizedBox(width: 12),
              Text(
                'Description',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _darkColor,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(
            displayText,
            style: TextStyle(
              fontSize: 15,
              color: _greyColor,
              height: 1.6,
            ),
          ),
          if (shouldTruncate) ...[
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
                    _isDescriptionExpanded ? 'Voir moins' : 'Voir plus',
                    style: TextStyle(
                      color: _primaryColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(
                    _isDescriptionExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: _primaryColor,
                    size: 20,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAdditionalInfo() {
    return Container(
      padding: EdgeInsets.all(20),
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
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _secondaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.info_outline, size: 20, color: _secondaryColor),
              ),
              SizedBox(width: 12),
              Text(
                'Informations pratiques',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _darkColor,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          _buildInfoItem(
            icon: Icons.event_available,
            title: 'Disponibilité',
            value: widget.site.available == true ? 'Disponible' : 'Non disponible',
            valueColor: widget.site.available == true ? Colors.green : Colors.red,
          ),
          if (widget.site.dateVacance != null && widget.site.dateVacance!.isNotEmpty) ...[
            Divider(height: 24),
            _buildInfoItem(
              icon: Icons.calendar_today,
              title: 'Date',
              value: _dateVacanceAffichee(widget.site.dateVacance!),
            ),
          ],
          if (widget.site.heureVacance != null && widget.site.heureVacance!.isNotEmpty) ...[
            Divider(height: 24),
            _buildInfoItem(
              icon: Icons.schedule,
              title: 'Heure',
              value: widget.site.heureVacance!,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String title,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: _greyColor),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  color: _greyColor,
                ),
              ),
              SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: valueColor ?? _darkColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomActionBar() {
    final blocked = widget.site.available == false || widget.site.id == null;
    final buttonLabel =
        blocked ? 'NON DISPONIBLE' : 'RÉSERVER MAINTENANT';

    return Column(
      children: [
        ElevatedButton(
          onPressed: blocked ? null : _navigateToBooking,
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
      ],
    );
  }
}
