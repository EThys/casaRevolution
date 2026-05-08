import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:get_storage/get_storage.dart';
import 'package:shimmer/shimmer.dart';
import '../utils/StockageKeys.dart';
import '../utils/decertification_access_guard.dart';
import '../utils/Endpoints.dart';
import '../utils/FancyNotification.dart';
import '../utils/requetes.dart';

import '../controllers/AgenceController.dart';
import '../controllers/AuthentificationCtrl.dart';
import '../models/AgenceModel.dart';
import 'CreateAgencePage.dart';
import 'CreatePropertyPostPage.dart';
import 'SiteDetailsPage.dart';

class MyAgencyPage extends StatefulWidget {
  @override
  _MyAgencyPageState createState() => _MyAgencyPageState();
}

class _MyAgencyPageState extends State<MyAgencyPage> {
  bool _isLoading = true;
  AgenceModel? _myAgency;
  String? _errorMessage;
  bool _noAgencyYet = false;
  final Set<int> _togglingVacanceIds = <int>{};

  static const Color _primaryColor = Color(0xFF1976D2);
  static const Color _secondaryColor = Color(0xFF64B5F6);
  static const Color _darkColor = Color(0xFF1A1D26);
  static const Color _lightGrey = Color(0xFFF5F6FA);
  static const Color _mediumGrey = Color(0xFF7F8C8D);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (await DecertificationAccessGuard.redirectIfInactiveDecertified(
            context,
          )) {
        return;
      }
      if (!mounted) return;
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
          _errorMessage = null;
          _noAgencyYet = false;
        });
      } else {
         setState(() {
          _myAgency = null;
          _errorMessage = null;
          _noAgencyYet = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
        _noAgencyYet = false;
      });
    }
  }

  Future<void> _toggleVacanceAvailability(AgenceSiteModel site) async {
    final vid = site.id;
    if (vid == null || vid <= 0) return;
    if (_togglingVacanceIds.contains(vid)) return;

    // UI: Disponible = available==true. L'API "sold" attend {status:true} pour rendre indisponible.
    final nextAvailable = !(site.available == true);
    final payloadStatus = !nextAvailable; // indisponible => true ; disponible => false

    setState(() {
      _togglingVacanceIds.add(vid);
      // Optimistic UI
      site.available = nextAvailable;
    });

    try {
      final tkn = GetStorage().read<String>(StockageKeys.tokenKey) ?? '';
      final url = "${Endpoints.soldVacanceDirect}$vid";
      final resp = await putData(url, {'status': payloadStatus}, token: tkn);
      if (resp.status == true) {
        FancyNotification.show(
          context,
          nextAvailable ? "Offre rendue disponible." : "Offre rendue indisponible.",
          type: NotificationType.success,
        );
        if (mounted) {
          await _loadAgency(); // refresh immédiat
        }
      } else {
        // rollback
        setState(() {
          site.available = !nextAvailable;
        });
        FancyNotification.show(
          context,
          "Impossible de changer la disponibilité. Réessayez.",
          isError: true,
        );
      }
    } catch (_) {
      // rollback
      setState(() {
        site.available = !nextAvailable;
      });
      FancyNotification.show(
        context,
        "Connexion instable. Réessayez dans un instant.",
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _togglingVacanceIds.remove(vid));
      } else {
        _togglingVacanceIds.remove(vid);
      }
    }
  }

  Widget _buildShimmer() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Container(
            height: 120,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Container(
            height: 180,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Container(
            height: 180,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_primaryColor, _secondaryColor],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: _primaryColor.withOpacity(0.25),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(Icons.business_rounded, color: Colors.white, size: 42),
            ),
            const SizedBox(height: 18),
            Text(
              'Aucune agence pour le moment',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _darkColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Créez votre agence pour publier vos offres et recevoir des réservations.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: _mediumGrey,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: () async {
                  final created = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(builder: (_) => CreateAgencePage()),
                  );
                  if (!mounted) return;
                  if (created == true) {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CreatePropertyPostPage(
                          openAfterAgencyVacanceStep2: true,
                        ),
                      ),
                    );
                  }
                  if (!mounted) return;
                  _loadAgency();
                },
                style: FilledButton.styleFrom(
                  backgroundColor: _primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.add_business_rounded),
                label: const Text(
                  'Créer mon agence',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: _loadAgency,
              child: Text(
                'Actualiser',
                style: TextStyle(color: _mediumGrey, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                color: _primaryColor.withOpacity(0.10),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(Icons.wifi_off_rounded, size: 38, color: _primaryColor),
            ),
            const SizedBox(height: 14),
            Text(
              'Impossible de charger votre agence',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: _darkColor),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Erreur inconnue',
              textAlign: TextAlign.center,
              style: TextStyle(color: _mediumGrey, height: 1.35),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: _loadAgency,
                style: FilledButton.styleFrom(
                  backgroundColor: _primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Réessayer', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _lightGrey,
      appBar: AppBar(
        iconTheme: IconThemeData(color: Colors.white),
        title: Text("Mon Agence", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: _primaryColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading 
          ? _buildShimmer()
          : _errorMessage != null
              ? _buildErrorState()
              : _myAgency == null 
                  ? _buildEmptyState()
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
      final available = site.available == true;
      final vid = site.id;
      final isToggling = vid != null && _togglingVacanceIds.contains(vid);
      
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
                                       Row(
                                         mainAxisSize: MainAxisSize.min,
                                         children: [
                                           Container(
                                             padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                             decoration: BoxDecoration(
                                               color: available ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
                                               borderRadius: BorderRadius.circular(20),
                                               border: Border.all(
                                                 color: (available ? const Color(0xFF2E7D32) : const Color(0xFFC62828))
                                                     .withOpacity(0.15),
                                               ),
                                             ),
                                             child: Text(
                                               available ? 'Disponible' : 'Indisponible',
                                               style: TextStyle(
                                                 color: available ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
                                                 fontWeight: FontWeight.bold,
                                                 fontSize: 12,
                                               ),
                                             ),
                                           ),
                                           const SizedBox(width: 10),
                                           Switch.adaptive(
                                             value: available,
                                             onChanged: (vid == null || isToggling)
                                                 ? null
                                                 : (_) => _toggleVacanceAvailability(site),
                                             activeColor: const Color(0xFF1976D2),
                                           ),
                                           if (site.price != null && site.price! > 0) ...[
                                             const SizedBox(width: 6),
                                             Container(
                                               padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                               decoration: BoxDecoration(
                                                 color: color.withOpacity(0.1),
                                                 borderRadius: BorderRadius.circular(20),
                                               ),
                                               child: Text(
                                                 "\$${site.price}",
                                                 style: TextStyle(color: color, fontWeight: FontWeight.bold),
                                               ),
                                             ),
                                           ],
                                         ],
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
