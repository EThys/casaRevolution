import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:get_storage/get_storage.dart';
import '../utils/StockageKeys.dart';

import '../controllers/AgenceController.dart';
import '../controllers/AuthentificationCtrl.dart';
import '../models/AgenceModel.dart';
import 'SiteDetailsPage.dart';

class MyAgencyPage extends StatefulWidget {
  @override
  _MyAgencyPageState createState() => _MyAgencyPageState();
}

class _MyAgencyPageState extends State<MyAgencyPage> {
  bool _isLoading = true;
  AgenceModel? _myAgency;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAgency();
    });
  }

  Future<void> _loadAgency() async {
    final agenceCtrl = Provider.of<AgenceController>(context, listen: false);
    
    // Récupérer le userId depuis le GetStorage local (plus fiable que le contrôleur par défaut)
    final storage = GetStorage();
    final userData = storage.read(StockageKeys.userKey);
    
    dynamic userId;
    if (userData != null) {
      if (userData is Map) {
         userId = userData['user']?['userId'] ?? userData['userId'];
      }
    }

    // Fallback sur le contrôleur si non trouvé
    if (userId == null) {
      final authCtrl = Provider.of<AuthentificationCtrl>(context, listen: false);
      userId = authCtrl.user.userId;
    }

    if (userId == null) {
      setState(() {
        _errorMessage = "Utilisateur non identifié. Veuillez vous reconnecter.";
        _isLoading = false;
      });
      return;
    }

    try {
      await agenceCtrl.fetchAgencesByUser(userId);
      
      if (agenceCtrl.agences.isNotEmpty) {
        // Find the agency that belongs to this user (though fetchAgencesByUser should only return theirs)
        // Adjust logic if multiple agencies are allowed. Assuming one for now or taking the first.
        setState(() {
          _myAgency = agenceCtrl.agences.first; 
          _isLoading = false;
        });
      } else {
         setState(() {
          _errorMessage = "Aucune agence trouvée pour ce compte.";
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text("Mon Agence", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Color(0xFF1976D2),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading 
          ? Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                    SizedBox(height: 16),
                    Text(_errorMessage!, style: TextStyle(color: Colors.grey[700])),
                    SizedBox(height: 16),
                    ElevatedButton(onPressed: _loadAgency, child: Text("Réessayer"))
                  ],
                ))
              : _myAgency == null 
                  ? Center(child: Text("Aucune agence trouvée"))
                  : SingleChildScrollView(
                      child: Column(
                        children: [
                          _buildHeader(_myAgency!),
                          _buildDetails(_myAgency!),
                          SizedBox(height: 16),
                          _buildSitesSection(_myAgency!),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildHeader(AgenceModel agency) {
    Widget logoWidget;
    if (agency.logo != null && agency.logo!.isNotEmpty) {
      if (agency.logo!.startsWith('http')) {
        logoWidget = CachedNetworkImage(
          imageUrl: agency.logo!,
          fit: BoxFit.cover,
          placeholder: (context, url) => Center(child: CircularProgressIndicator(strokeWidth: 2)),
          errorWidget: (context, url, error) => Icon(Icons.business, size: 40, color: Colors.grey[300]),
        );
      } else if (agency.logo!.startsWith('data:image')) {
        try {
          final base64String = agency.logo!.split(',').last;
          logoWidget = Image.memory(
            base64Decode(base64String),
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Icon(Icons.business, size: 40, color: Colors.grey[300]),
          );
        } catch (e) {
          logoWidget = Icon(Icons.business, size: 40, color: Colors.grey[300]);
        }
      } else {
        logoWidget = Icon(Icons.business, size: 40, color: Colors.grey[300]);
      }
    } else {
      logoWidget = Icon(Icons.business, size: 40, color: Colors.grey[300]);
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 5)
          )
        ]
      ),
      padding: EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo Section (Left)
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey[200]!, width: 2),
            ),
            child: ClipOval(child: logoWidget),
          ),
          SizedBox(width: 16),

          // Details Section (Right)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  agency.name ?? "Nom de l'agence",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (agency.description != null && agency.description!.isNotEmpty) ...[
                  SizedBox(height: 8),
                  Text(
                    agency.description!,
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetails(AgenceModel agency) {
      return Padding(
          padding: EdgeInsets.all(16),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                  Text("Coordonnées", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1976D2))),
                  SizedBox(height: 16),
                  _buildDetailItem(Icons.location_on_outlined, "Adresse", agency.address),
                  _buildDetailItem(Icons.phone_outlined, "Téléphone", agency.phone1),
                  if (agency.phone2 != null && agency.phone2!.isNotEmpty)
                    _buildDetailItem(Icons.phone_outlined, "Téléphone 2", agency.phone2),
                  
                  // Add more valid fields if available in model
              ],
          ),
      );
  }
  
  Widget _buildSitesSection(AgenceModel agency) {
    if (agency.sites == null || agency.sites!.isEmpty) {
        return Padding(
            padding: EdgeInsets.all(32),
            child: Center(
              child: Column(
                  children: [
                      Icon(Icons.landscape_rounded, size: 50, color: Colors.grey[300]),
                      SizedBox(height: 8),
                      Text("Aucune offre disponible", style: TextStyle(color: Colors.grey[500]))
                  ],
              ),
            ),
        ); 
    }

    return Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                Text("Mes Offres & Sites", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1976D2))),
                SizedBox(height: 12),
                ListView.separated(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    itemCount: agency.sites!.length,
                    separatorBuilder: (c, i) => SizedBox(height: 16),
                    itemBuilder: (c, i) => _buildSiteCard(agency.sites![i]),
                ),
                SizedBox(height: 30),
            ],
        ),
    );
  }

  Widget _buildSiteCard(AgenceSiteModel site) {
      String? firstImage = (site.images != null && site.images!.isNotEmpty) ? site.images!.first : null;
      final color = Color(0xFF1976D2);
      
      return InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SiteDetailsPage(site: site))),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: Offset(0, 4))
              ]
          ),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                   // Image Header
                   Container(
                       height: 160,
                       width: double.infinity,
                       decoration: BoxDecoration(
                           borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                           color: Colors.grey[100],
                           image: firstImage != null ? DecorationImage(
                               image: CachedNetworkImageProvider(firstImage),
                               fit: BoxFit.cover
                           ) : null
                       ),
                       child: firstImage == null ? Center(child: Icon(Icons.image_not_supported_outlined, color: Colors.grey[300], size: 40)) : null,
                   ),
                   
                   // Content
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
                                            site.title ?? "Site Touristique", 
                                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                           ),
                                       ),
                                       if (site.price != null && site.price! > 0)
                                          Container(
                                              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(
                                                  color: color.withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(20)
                                              ),
                                              child: Text(
                                                  "\$${site.price}",
                                                  style: TextStyle(color: color, fontWeight: FontWeight.bold),
                                              ),
                                          ),
                                   ],
                               ),
                               SizedBox(height: 8),
                               if (site.dateVacance != null && site.dateVacance!.isNotEmpty)
                                  Row(
                                      children: [
                                          Icon(Icons.calendar_month_outlined, size: 14, color: Colors.grey[500]),
                                          SizedBox(width: 4),
                                          Text("Date: ${site.dateVacance}", style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                                      ],
                                  ),
                               if (site.description != null) ...[
                                    SizedBox(height: 8),
                                    Text(
                                        site.description!,
                                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                    ),
                               ],
                           ],
                       ),
                   )
               ],
           ),
        ),
      );
  }

  Widget _buildDetailItem(IconData icon, String label, String? value) {
      if (value == null || value.isEmpty) return SizedBox.shrink();
      
      return Container(
          margin: EdgeInsets.only(bottom: 12),
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!)
          ),
          child: Row(
              children: [
                  Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: Color(0xFF1976D2).withOpacity(0.1),
                          shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: Color(0xFF1976D2), size: 18),
                  ),
                  SizedBox(width: 16),
                  Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                          SizedBox(height: 2),
                          Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.black87)),
                      ],
                  )
              ],
          ),
      );
  }
}
