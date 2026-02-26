import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/PrestationModel.dart';
import '../models/ServiceModel.dart';
import '../utils/FavoriteEartIcon.dart';
import '../controllers/ServiceController.dart'; // Added
import 'package:provider/provider.dart'; // Added
import 'ServiceDetailPage.dart';

class ServiceCategoryPage extends StatefulWidget {
  final ServiceType serviceType;
  final List<PrestationModel> services;

  const ServiceCategoryPage({
    Key? key,
    required this.serviceType,
    required this.services,
  }) : super(key: key);

  static const Color primaryColor = Color(0xFF1976D2);
  static const Color accentColor = Color(0xFF64B5F6);
  static const Color darkBlue = Color(0xFF0D47A1);

  String _getPriceRange(PrestationModel service) {
    if (service.minPrice == null || service.minPrice == 0) return 'Prix sur demande';
    return 'À partir de ${service.minPrice!.toStringAsFixed(0)} ${service.currency}';
  }

  @override
  State<ServiceCategoryPage> createState() => _ServiceCategoryPageState();
}

class _ServiceCategoryPageState extends State<ServiceCategoryPage> {
  bool _isGrid = true;
  String _sort = 'Aucun';

  Color get primaryColor => ServiceCategoryPage.primaryColor;
  Color get accentColor => ServiceCategoryPage.accentColor;
  Color get darkBlue => ServiceCategoryPage.darkBlue;



  List<PrestationModel> get _sortedServices {
    final list = List<PrestationModel>.from(widget.services);
    switch (_sort) {
      case 'Prix ↑':
        list.sort((a, b) => (a.minPrice ?? 0).compareTo(b.minPrice ?? 0));
        break;
      case 'Prix ↓':
        list.sort((a, b) => (b.minPrice ?? 0).compareTo(a.minPrice ?? 0));
        break;
      case 'Note':
        // list.sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));
        break;
      default:
        break;
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final services = _sortedServices;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [ServiceCategoryPage.primaryColor, ServiceCategoryPage.darkBlue],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.serviceType.displayName,
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              '${services.length} service${services.length > 1 ? 's' : ''} disponible${services.length > 1 ? 's' : ''}',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.white.withOpacity(0.8),
              ),
            ),
          ],
        ),
        centerTitle: false,
      ),
      body: services.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    widget.serviceType.icon,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Aucun service disponible',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            )
          : ListView(
              padding: EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _sort,
                        decoration: InputDecoration(
                          labelText: 'Trier',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          isDense: true,
                        ),
                        items: const [
                          DropdownMenuItem(value: 'Aucun', child: Text('Aucun')),
                          DropdownMenuItem(value: 'Prix ↑', child: Text('Prix croissant')),
                          DropdownMenuItem(value: 'Prix ↓', child: Text('Prix décroissant')),
                          DropdownMenuItem(value: 'Note', child: Text('Note élevée')),
                        ],
                        onChanged: (v) {
                          setState(() => _sort = v ?? 'Aucun');
                        },
                      ),
                    ),
                    SizedBox(width: 12),
                    InkWell(
                      onTap: () => setState(() => _isGrid = !_isGrid),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: ServiceCategoryPage.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: ServiceCategoryPage.primaryColor.withOpacity(0.2)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_isGrid ? Icons.view_list_rounded : Icons.grid_view_rounded,
                                size: 18, color: ServiceCategoryPage.primaryColor),
                            SizedBox(width: 6),
                            Text(
                              _isGrid ? 'Liste' : 'Grille',
                              style: GoogleFonts.inter(
                                color: ServiceCategoryPage.primaryColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                if (_isGrid)
                  GridView.builder(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.72, // Ajusté pour accommoder image + titre + ville + reviews
                    ),
                    itemCount: services.length,
                    itemBuilder: (context, index) {
                      return _buildServiceCard(context, services[index], isCompact: true);
                    },
                  )
                else
                  ...services.map((service) => _buildServiceCard(context, service)).toList(),
              ],
            ),
    );
  }

  Widget _buildServiceCard(BuildContext context, PrestationModel service, {bool isCompact = false}) {
    final firstImage = service.profile ?? (service.images != null && service.images!.isNotEmpty
        ? service.images!.first
        : null);

    final priceText = widget._getPriceRange(service);

    // Mode compact (grille) - Layout optimisé
    if (isCompact) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              spreadRadius: 2,
              offset: Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: primaryColor.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              final serviceCtrl = Provider.of<ServiceController>(context, listen: false);
              final resolvedName = serviceCtrl.serviceIdToNameMap.containsKey(service.serviceId) 
                  ? serviceCtrl.getServiceName(service.serviceId) 
                  : widget.serviceType.displayName;

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ServiceDetailPage(
                    service: service,
                    serviceTypeName: resolvedName,
                  ),
                ),
              );
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Image avec prix superposé
                ClipRRect(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
                  child: AspectRatio(
                    aspectRatio: 1.1, // Ratio fixe pour l'image
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        firstImage != null
                            ? CachedNetworkImage(
                                imageUrl: firstImage,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  color: primaryColor.withOpacity(0.1),
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                                    ),
                                  ),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  color: primaryColor.withOpacity(0.1),
                                  child: Icon(
                                    widget.serviceType.icon,
                                    size: 48,
                                    color: primaryColor.withOpacity(0.3),
                                  ),
                                ),
                              )
                            : Container(
                                color: primaryColor.withOpacity(0.1),
                                child: Icon(
                                  widget.serviceType.icon,
                                  size: 48,
                                  color: primaryColor.withOpacity(0.3),
                                ),
                              ),
                        
                        // Gradient overlay en bas pour le prix
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            height: 60,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withOpacity(0.7),
                                ],
                              ),
                            ),
                          ),
                        ),
                        
                        // Prix superposé en bas
                        Positioned(
                          bottom: 8,
                          left: 8,
                          right: 8,
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.95),
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              priceText,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: primaryColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        
                        // Bouton favoris
                        Positioned(
                          top: 8,
                          right: 8,
                          child: FavoriteHeartIcon(
                            propertyId: 'service_${service.serviceId}',
                            size: 20,
                            splashRadius: 18,
                            activeColor: Colors.red,
                            inactiveColor: Colors.white,
                          ),
                        ),
                        
                        // Badge vérifié
                        if (service.isCertified == true)
                          Positioned(
                            top: 8,
                            left: 8,
                            child: Container(
                              padding: EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Icon(Icons.verified, color: Colors.white, size: 12),
                            ),
                          ),
                        // Type de service superposé (Top Left)
                        Positioned(
                          top: 8,
                          left: service.isCertified == true ? 36 : 8, // Décale si vérifié
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: primaryColor.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Builder(
                              builder: (context) {
                                final serviceCtrl = Provider.of<ServiceController>(context, listen: false);
                                final resolvedName = serviceCtrl.serviceIdToNameMap.containsKey(service.serviceId) 
                                    ? serviceCtrl.getServiceName(service.serviceId) 
                                    : widget.serviceType.displayName;
                                return Text(
                                  resolvedName,
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                );
                              }
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Contenu textuel (titre, ville, reviews)
                Padding(
                  padding: EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Titre
                      Text(
                        service.title ?? 'Service sans titre',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: darkBlue,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 6),
                      
                      // Ville et Reviews
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Ville
                          if (service.address != null)
                            Expanded(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.location_on,
                                    size: 12,
                                    color: Colors.grey[600],
                                  ),
                                  SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      "${service.cityValue}, ${service.communeValue}",
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.w500,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          
                          // Reviews (étoiles) - Hidden for now as PrestationModel doesn't have it
                          /*
                          if (service.rating != null) ...[
                            if (service.address != null) SizedBox(width: 8),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.star,
                                  size: 12,
                                  color: Colors.amber,
                                ),
                                SizedBox(width: 2),
                                Text(
                                  service.rating!.toStringAsFixed(1),
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.grey[800],
                                  ),
                                ),
                                if (service.reviewCount != null && service.reviewCount! > 0) ...[
                                  SizedBox(width: 2),
                                  Text(
                                    '(${service.reviewCount})',
                                    style: GoogleFonts.inter(
                                      fontSize: 9,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                          */
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

    // Mode liste (layout complet)
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 2,
            offset: Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: primaryColor.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            final serviceCtrl = Provider.of<ServiceController>(context, listen: false);
            final resolvedName = serviceCtrl.serviceIdToNameMap.containsKey(service.serviceId) 
                ? serviceCtrl.getServiceName(service.serviceId) 
                : widget.serviceType.displayName;

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ServiceDetailPage(
                  service: service,
                  serviceTypeName: resolvedName,
                ),
              ),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image
              if (firstImage != null)
                ClipRRect(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                  child: Stack(
                    children: [
                      CachedNetworkImage(
                        imageUrl: firstImage,
                        width: double.infinity,
                        height: 200,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          height: 200,
                          color: primaryColor.withOpacity(0.1),
                          child: Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          height: 200,
                          color: primaryColor.withOpacity(0.1),
                          child: Icon(
                            widget.serviceType.icon,
                            size: 64,
                            color: primaryColor.withOpacity(0.3),
                          ),
                        ),
                      ),
                      // Bouton favoris
                      Positioned(
                        top: 12,
                        right: 12,
                        child: FavoriteHeartIcon(
                          propertyId: 'service_${service.id}',
                          size: 24,
                          splashRadius: 20,
                          activeColor: Colors.red,
                          inactiveColor: Colors.white,
                        ),
                      ),
                      // Badge vérifié
                      if (service.isCertified == true)
                        Positioned(
                          top: 12,
                          left: 12,
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.verified, color: Colors.white, size: 14),
                                SizedBox(width: 4),
                                Text(
                                  'Vérifié',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        // Type de service superposé (Top Left)
                        Positioned(
                          top: 12,
                          left: service.isCertified == true ? 80 : 12, // Décale si vérifié
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: primaryColor.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Builder(
                              builder: (context) {
                                final serviceCtrl = Provider.of<ServiceController>(context, listen: false);
                                final resolvedName = serviceCtrl.serviceIdToNameMap.containsKey(service.serviceId) 
                                    ? serviceCtrl.getServiceName(service.serviceId) 
                                    : widget.serviceType.displayName;
                                return Text(
                                  resolvedName,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                );
                              }
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              
              Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Titre
                    Text(
                      service.title ?? 'Service sans titre',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: darkBlue,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 8),
                    
                    // Description
                    if (service.description != null)
                      Text(
                        service.description!,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.grey[700],
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    SizedBox(height: 12),
                    
                    // Prix et note
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [primaryColor, accentColor],
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            priceText,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        /*
                        if (service.rating != null)
                          Row(
                            children: [
                              Icon(Icons.star, color: Colors.amber, size: 18),
                              SizedBox(width: 4),
                              Text(
                                '${service.rating!.toStringAsFixed(1)}',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[800],
                                ),
                              ),
                              if (service.reviewCount != null && service.reviewCount! > 0)
                                Text(
                                  ' (${service.reviewCount})',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                            ],
                          ),
                        */
                      ],
                    ),
                    SizedBox(height: 12),
                    
                    // Adresse
                    if (service.address != null || service.cityValue != null)
                      Row(
                        children: [
                          Icon(Icons.location_on, size: 16, color: primaryColor),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              "${service.cityValue}, ${service.communeValue}",
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
                              maxLines: 1,
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
        ),
      ),
    );
  }

}

