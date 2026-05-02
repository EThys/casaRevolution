import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/AgenceModel.dart';
import '../utils/FancyNotification.dart';
import '../utils/FavoriteEartIcon.dart';
import 'SiteDetailsPage.dart';

String _formatAgenceVacanceDateFr(String raw) {
  final s = raw.trim();
  try {
    final d = DateTime.parse(s);
    return DateFormat('dd/MM/yyyy', 'fr_FR').format(d);
  } catch (_) {}
  try {
    if (RegExp(r'^\d{1,2}/\d{1,2}/\d{4}$').hasMatch(s)) {
      final p = s.split('/');
      final d = DateTime(int.parse(p[2]), int.parse(p[1]), int.parse(p[0]));
      return DateFormat('dd/MM/yyyy', 'fr_FR').format(d);
    }
  } catch (_) {}
  return raw;
}

class AgenceDetailsPage extends StatelessWidget {
  final AgenceModel agency;

  const AgenceDetailsPage({Key? key, required this.agency}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final primaryColor = Color(0xFF1976D2);
    final secondaryColor = Color(0xFF64B5F6);
    final darkColor = Color(0xFF2D3748);
    final lightColor = Color(0xFFF8F9FA);
    
    return Scaffold(
      backgroundColor: lightColor,
      body: CustomScrollView(
        slivers: [
          // Modern App Bar with all main info
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: primaryColor,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [darkColor, primaryColor],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    stops: [0.0, 0.8],
                  ),
                ),
                child: Stack(
                  children: [
                    // Decorative circles
                    Positioned(
                      top: -20,
                      right: -20,
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -30,
                      left: -30,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.08),
                        ),
                      ),
                    ),
                    
                    // Main content
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Logo
                            _buildLogo(),
                            SizedBox(height: 12),
                            
                            // Title
                            Text(
                              agency.name ?? "Agence",
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                            
                            // Address
                            if (agency.address != null && agency.address!.isNotEmpty) ...[
                              SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.location_on, size: 14, color: Colors.white70),
                                  SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      agency.address!,
                                      style: TextStyle(color: Colors.white70, fontSize: 12),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            
                            SizedBox(height: 12),
                            
                            // Badges row: Certified + Sites count
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Certified badge
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.green.withOpacity(0.5)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.verified, size: 12, color: Colors.white),
                                      SizedBox(width: 4),
                                      Text(
                                        'VÉRIFIÉ',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                
                                SizedBox(width: 12),
                                
                                // Sites count badge
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.white.withOpacity(0.5)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.location_city, size: 12, color: Colors.white),
                                      SizedBox(width: 4),
                                      Text(
                                        '${agency.sites?.length ?? 0} sites',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),


              centerTitle: true,
            ),
          ),
          
          SliverPadding(
            padding: EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Only "À propos" section
                if (agency.description != null && agency.description!.isNotEmpty)
                  _buildAboutSection(primaryColor, darkColor),
                SizedBox(height: 20),
                _buildContactSection(context, agency, primaryColor, darkColor),
                SizedBox(height: 20),
                _buildSitesSection(context, primaryColor, secondaryColor, darkColor),
                SizedBox(height: 30),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    Widget logoWidget;
    if (agency.logo != null && agency.logo!.isNotEmpty) {
      if (agency.logo!.startsWith('http')) {
        logoWidget = CachedNetworkImage(
          imageUrl: agency.logo!,
          fit: BoxFit.cover,
          placeholder: (context, url) => Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
          errorWidget: (context, url, error) => Icon(Icons.business, size: 35, color: Colors.white70),
        );
      } else if (agency.logo!.startsWith('data:image')) {
        try {
          final base64String = agency.logo!.split(',').last;
          logoWidget = Image.memory(
            base64Decode(base64String),
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Icon(Icons.business, size: 35, color: Colors.white70),
          );
        } catch (e) {
          logoWidget = Icon(Icons.business, size: 35, color: Colors.white70);
        }
      } else {
        logoWidget = Icon(Icons.business, size: 35, color: Colors.white70);
      }
    } else {
      logoWidget = Icon(Icons.business, size: 35, color: Colors.white70);
    }

    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipOval(child: logoWidget),
    );
  }

  Widget _buildAboutSection(Color primaryColor, Color darkColor) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.1),
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.info_outline, size: 20, color: primaryColor),
              ),
              SizedBox(width: 12),
              Text(
                'À propos',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: darkColor,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(
            agency.description!,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactSection(
    BuildContext context,
    AgenceModel agency,
    Color primaryColor,
    Color darkColor,
  ) {
    final contactItems = <Map<String, dynamic>>[];
    
    if (agency.phone1 != null && agency.phone1!.isNotEmpty) {
      contactItems.add({
        'icon': Icons.phone,
        'label': 'Téléphone principal',
        'value': agency.phone1,
      });
    }
    
    if (agency.phone2 != null && agency.phone2!.isNotEmpty) {
      contactItems.add({
        'icon': Icons.phone_android,
        'label': 'Téléphone secondaire',
        'value': agency.phone2,
      });
    }
    
    if (contactItems.isEmpty) return SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Coordonnées',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: darkColor,
          ),
        ),
        SizedBox(height: 12),
        ...contactItems.map((item) => Container(
          margin: EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: ListTile(
            leading: Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(item['icon'], color: primaryColor, size: 20),
            ),
            title: Text(
              item['label'],
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            subtitle: Text(
              item['value'],
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: darkColor,
              ),
            ),
            trailing: IconButton(
              icon: Icon(Icons.content_copy, color: Colors.grey[400], size: 20),
              onPressed: () async {
                final v = (item['value']?.toString() ?? '').trim();
                if (v.isEmpty) return;
                await Clipboard.setData(ClipboardData(text: v));
                if (!context.mounted) return;
                FancyNotification.show(
                  context,
                  '${item['label']?.toString() ?? 'Valeur'} copié',
                  isError: false,
                  type: NotificationType.success,
                  duration: 2,
                );
              },
            ),
          ),
        )),
      ],
    );
  }

  Widget _buildSitesSection(BuildContext context, Color primaryColor, Color secondaryColor, Color darkColor) {
    if (agency.sites == null || agency.sites!.isEmpty) {
      return Container(
        padding: EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.landscape_rounded, size: 50, color: Colors.grey[400]),
              ),
              SizedBox(height: 16),
              Text(
                "Aucune offre disponible pour le moment",
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Nos Offres & Sites",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: darkColor,
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${agency.sites!.length} offres',
                style: TextStyle(
                  color: primaryColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 16),
        ListView.separated(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: agency.sites!.length,
          separatorBuilder: (c, i) => SizedBox(height: 16),
          itemBuilder: (c, i) => _buildSiteCard(agency.sites![i], primaryColor, secondaryColor, darkColor),
        ),
      ],
    );
  }

  Widget _buildSiteCard(AgenceSiteModel site, Color primaryColor, Color secondaryColor, Color darkColor) {
    String? firstImage = (site.images != null && site.images!.isNotEmpty) ? site.images!.first : null;
    
    return Builder(
      builder: (context) => InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SiteDetailsPage(site: site))),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withOpacity(0.1),
                blurRadius: 15,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image Header with gradient overlay
              Stack(
                children: [
                  Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                      color: Colors.grey[100],
                      image: firstImage != null
                          ? DecorationImage(
                              image: CachedNetworkImageProvider(firstImage),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: firstImage == null
                        ? Center(
                            child: Icon(
                              Icons.image_not_supported_outlined,
                              color: Colors.grey[300],
                              size: 50,
                            ),
                          )
                        : null,
                  ),
                  // Gradient overlay
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 80,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.5),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Price badge
                  if (site.price != null && site.price! > 0)
                    Positioned(
                      top: 16,
                      right: 16,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [primaryColor, secondaryColor],
                          ),
                          borderRadius: BorderRadius.circular(25),
                          boxShadow: [
                            BoxShadow(
                              color: primaryColor.withOpacity(0.4),
                              blurRadius: 10,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Text(
                          "${(site.price ?? 0).toStringAsFixed((site.price ?? 0) % 1 == 0 ? 0 : 2)} \$",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),

                  // Favori (Vacance/Agence) — vacanceId = site.id
                  if (site.id != null)
                    Positioned(
                      top: 14,
                      left: 14,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.92),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.12),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: FavoriteHeartIcon(
                          propertyId: site.id.toString(),
                          propertyTypeId: 11,
                          size: 20,
                          splashRadius: 18,
                          activeColor: Colors.red,
                          inactiveColor: Colors.grey,
                        ),
                      ),
                    ),
                ],
              ),
              
              // Content
              Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      site.title ?? "Site Touristique",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: darkColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 8),
                    if (site.dateVacance != null && site.dateVacance!.isNotEmpty)
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: secondaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.calendar_month_outlined, size: 14, color: secondaryColor),
                            SizedBox(width: 6),
                            Text(
                              _formatAgenceVacanceDateFr(site.dateVacance!),
                              style: TextStyle(
                                fontSize: 13,
                                color: secondaryColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (site.description != null) ...[
                      SizedBox(height: 12),
                      Text(
                        site.description!,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                          height: 1.5,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.remove_red_eye, size: 16, color: primaryColor),
                                SizedBox(width: 6),
                                Text(
                                  'Voir détails',
                                  style: TextStyle(
                                    color: primaryColor,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
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
        ),
      ),
    );
  }
}
