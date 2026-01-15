import 'package:casa/controllers/ServiceController.dart';
import 'package:casa/models/PrestationModel.dart';
import 'package:casa/models/ServiceModel.dart';
import 'package:casa/models/SollicitationModel.dart';
import 'package:casa/screens/ServiceDetailPage.dart';
import 'package:casa/utils/FancyNotification.dart';
import 'package:casa/utils/Routes.dart';
import 'package:casa/utils/StockageKeys.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:google_fonts/google_fonts.dart';
import '../controllers/AuthentificationCtrl.dart';
import 'auth/IdentityVerificationPage.dart';

class MyServicesPage extends StatefulWidget {
  @override
  _MyServicesPageState createState() => _MyServicesPageState();
}

class _MyServicesPageState extends State<MyServicesPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoadingData = true;
  bool _isRefreshing = false;
  
  // View mode: Provider (Prestations) vs Consumer (Solicitations)
  bool _isProviderView = true;

  final DateFormat _dateFormat = DateFormat('dd MMM yyyy', 'fr_FR');
  final GetStorage _stockage = GetStorage();
  
  // Couleurs modernes
  final Color _primaryColor = Color(0xFF1976D2);
  final Color _secondaryColor = Color(0xFF64B5F6);
  final Color _darkColor = Color(0xFF1A1D26);
  final Color _lightGrey = Color(0xFFF5F6FA);
  final Color _mediumGrey = Color(0xFF7F8C8D);
  final Color _successColor = Color(0xFF00B894);
  final Color _warningColor = Color(0xFFFDCB6E);
  final Color _errorColor = Color(0xFFD63031);
  final Color _cardBackground = Colors.white;
  final Color _chipBackground = Color(0xFFE8F4F8);

  List<PrestationModel> _myPrestations = [];
  List<SollicitationModel> _mySolicitations = [];
  List<int> _deletingIds = [];
  bool _isGridView = false;

  // Role check
  bool _isPrestataire = false;

  @override
  void initState() {
    super.initState();
    _checkUserRole();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  void _checkUserRole() {
    final userAccounts = _stockage.read('user_accounts');
    if (userAccounts != null && userAccounts is List) {
      _isPrestataire = userAccounts.any((acc) {
        final typeId = (acc['typeAccount']?['typeAccountId'] ?? (acc['typeAccountId'] ?? acc['TypeAccountId']));
        return typeId == 3; // Prestataire
      });
    }
    
    // Si pas prestataire, on force la vue "Mes Demandes" (Consumer)
    if (!_isPrestataire) {
      _isProviderView = false;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ... (existing methods)

  Future<void> _loadData() async {
    setState(() {
      _isLoadingData = true;
      _isRefreshing = true;
    });

    // Si prestataire, on charge les deux. Sinon juste les sollicitations.
    if (_isPrestataire) {
       await Future.wait([
        _loadMyPrestations(),
        _loadMySolicitations(),
      ]);
    } else {
       await _loadMySolicitations();
    }

    if (mounted) {
      setState(() {
        _isLoadingData = false;
        _isRefreshing = false;
      });
    }
  }

  Future<void> _loadMyPrestations() async {
    try {
      final serviceController = Provider.of<ServiceController>(context, listen: false);
      final prestations = await serviceController.getMyPrestations();
      if (mounted) {
        setState(() {
          _myPrestations = prestations;
        });
      }
    } catch (e) {
      print("❌ Erreur lors du chargement des prestations: $e");
    }
  }
  
  Future<void> _loadMySolicitations() async {
    try {
      final serviceController = Provider.of<ServiceController>(context, listen: false);
      final solicitations = await serviceController.fetchUserSollicitations();
      if (mounted) {
        setState(() {
          _mySolicitations = solicitations;
        });
      }
    } catch (e) {
      print("❌ Erreur lors du chargement des sollicitations: $e");
    }
  }

  Future<void> _deletePrestation(PrestationModel prestation) async {
    if (prestation.id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: _errorColor, size: 28),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Supprimer',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: _darkColor,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Êtes-vous sûr de vouloir supprimer "${prestation.title}" ?\n\nCette action est irréversible.',
          style: TextStyle(
            color: _mediumGrey,
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Annuler', style: TextStyle(color: _mediumGrey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _errorColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Supprimer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      if (prestation.id != null) {
        _deletingIds.add(prestation.id!);
      }
    });

    try {
      final serviceController = Provider.of<ServiceController>(context, listen: false);
      final response = await serviceController.deletePrestation(prestation.id!);

      if (response.status == true) {
        if (mounted) {
          FancyNotification.show(
            context,
            "Service supprimé avec succès",
            type: NotificationType.success,
          );
          await _loadMyPrestations();
        }
      } else {
        if (mounted) {
          FancyNotification.show(
            context,
            response.errorMsg ?? "Erreur lors de la suppression",
          );
        }
      }
    } catch (e) {
      if (mounted) {
        FancyNotification.show(context, "Erreur: ${e.toString()}");
      }
    } finally {
      if (mounted && prestation.id != null) {
        setState(() {
          _deletingIds.remove(prestation.id!);
        });
      }
    }
  }

  void _navigateToCreateService() {
    final authCtrl = context.read<AuthentificationCtrl>();
    if (authCtrl.user.isCertified != true) {
      Navigator.push(
        context, 
        MaterialPageRoute(builder: (context) => IdentityVerificationPage())
      ).then((result) {
        if (result == true) {
           Navigator.pushNamed(context, Routes.createServicePostRoute).then((_) => _loadData());
        }
      });
      return;
    }

    Navigator.pushNamed(context, Routes.createServicePostRoute)
        .then((_) => _loadData());
  }

  List<PrestationModel> get _activePrestations => _myPrestations.where((p) => p.isActive == true).toList();
  List<PrestationModel> get _inactivePrestations => _myPrestations.where((p) => p.isActive != true).toList();

  List<PrestationModel> _filterPrestations(String filter) {
    switch (filter) {
      case 'active':
        return _activePrestations;
      case 'inactive':
        return _inactivePrestations;
      case 'all':
      default:
        return _myPrestations;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _lightGrey,
      appBar: _buildAppBar(),
      body: _isProviderView 
        ? Column(
            children: [
              _buildTabBar(),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildPrestationList(_filterPrestations('all')),
                    _buildPrestationList(_filterPrestations('active')),
                    _buildPrestationList(_filterPrestations('inactive')),
                  ],
                ),
              ),
            ],
          )
        : _buildSolicitationList(_mySolicitations),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_primaryColor, _secondaryColor],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
      title: Text(
        'Mes activités',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 18,
        ),
      ),
      bottom: PreferredSize(
        preferredSize: Size.fromHeight(60),
        child: Container(
           padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
           child: _buildViewToggle(),
        ),
      ),
      actions: [
        if (_isProviderView) ...[
          Tooltip(
            message: _isGridView ? 'Vue liste' : 'Vue grille',
            child: IconButton(
              icon: Icon(
                _isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
                color: Colors.white,
              ),
              onPressed: () {
                setState(() {
                  _isGridView = !_isGridView;
                });
              },
            ),
          ),
        ],
        Tooltip(
          message: 'Actualiser',
          child: Stack(
            children: [
              IconButton(
                icon: Icon(Icons.refresh, color: Colors.white),
                onPressed: _isRefreshing ? null : _loadData,
              ),
              if (_isRefreshing)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
  


  Widget _buildViewToggle() {
    // Si l'utilisateur n'est pas prestataire, on cache le toggle car il ne peut voir que "Mes Demandes"
    if (!_isPrestataire) {
       return Container(
         width: double.infinity,
         padding: EdgeInsets.symmetric(vertical: 12),
         alignment: Alignment.center,
         decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
         ),
         child: Text(
           "Mes Demandes",
           style: TextStyle(
             color: Colors.white,
             fontWeight: FontWeight.w600,
             fontSize: 16,
           ),
         ),
       );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: _buildToggleButton("Mes Annonces", _isProviderView, () {
              setState(() => _isProviderView = true);
            }),
          ),
          Expanded(
             child: _buildToggleButton("Mes Demandes", !_isProviderView, () {
              setState(() => _isProviderView = false);
            }),
          ),
        ],
      ),
    );
  }
  
  Widget _buildToggleButton(String text, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected ? [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))] : [],
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          style: TextStyle(
            color: isSelected ? _primaryColor : Colors.white.withOpacity(0.8),
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    final allCount = _filterPrestations('all').length;
    final activeCount = _filterPrestations('active').length;
    final inactiveCount = _filterPrestations('inactive').length;

    return Container(
      color: Colors.white,
      child: Column(
        children: [
          TabBar(
            controller: _tabController,
            labelColor: _primaryColor,
            unselectedLabelColor: _mediumGrey,
            indicatorColor: _primaryColor,
            indicatorWeight: 3,
            indicatorSize: TabBarIndicatorSize.tab,
            indicatorPadding: EdgeInsets.symmetric(horizontal: 10),
            labelStyle: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
            unselectedLabelStyle: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
            tabs: [
              Tab(text: 'Toutes ($allCount)'),
              Tab(text: 'Actives ($activeCount)'),
              Tab(text: 'Inactives ($inactiveCount)'),
            ],
          ),
          if (_isLoadingData)
            LinearProgressIndicator(
              backgroundColor: _lightGrey,
              valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
              minHeight: 2,
            ),
        ],
      ),
    );
  }

  Widget _buildPrestationList(List<PrestationModel> prestations) {
    return AnimatedSwitcher(
      duration: Duration(milliseconds: 300),
      child: prestations.isEmpty && !_isLoadingData
          ? _buildEmptyState()
          : _buildPrestationListContent(prestations),
    );
  }

  Widget _buildPrestationListContent(List<PrestationModel> prestations) {
    return RefreshIndicator(
      color: _primaryColor,
      backgroundColor: Colors.white,
      onRefresh: _loadData,
      child: _isGridView
          ? _buildGridView(prestations)
          : ListView.separated(
              padding: EdgeInsets.all(20),
              itemCount: prestations.length,
              separatorBuilder: (_, __) => SizedBox(height: 20),
              itemBuilder: (context, index) {
                final prestation = prestations[index];
                return _buildPrestationCard(prestation, isGrid: false);
              },
            ),
    );
  }
  
  Widget _buildSolicitationList(List<SollicitationModel> items) {
     if (_isLoadingData) return _buildShimmerEffect();
     if (items.isEmpty) return _buildEmptyStateSolicitation();
     
     return RefreshIndicator(
        color: _primaryColor,
        backgroundColor: Colors.white,
        onRefresh: _loadData,
        child: ListView.separated(
          padding: EdgeInsets.all(16),
          itemCount: items.length,
          separatorBuilder: (_, __) => SizedBox(height: 16),
          itemBuilder: (context, index) => _buildSolicitationCard(items[index]),
        ),
     );
  }

  Widget _buildShimmerEffect() {
    return ListView.separated(
      padding: EdgeInsets.all(20),
      itemCount: 4,
      separatorBuilder: (_, __) => SizedBox(height: 20),
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Container(
            height: 120,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: Colors.white,
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.work_outline, size: 60, color: _mediumGrey.withOpacity(0.3)),
          SizedBox(height: 20),
          Text('Aucun service publié', style: TextStyle(color: _mediumGrey, fontSize: 18, fontWeight: FontWeight.w600)),
          SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _navigateToCreateService,
            icon: Icon(Icons.add_rounded, size: 20),
            label: Text('Créer un service'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildEmptyStateSolicitation() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment_outlined, size: 60, color: _mediumGrey.withOpacity(0.3)),
          SizedBox(height: 20),
          Text('Aucune demande effectuée', style: TextStyle(color: _mediumGrey, fontSize: 18, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildGridView(List<PrestationModel> prestations) {
    return GridView.builder(
      padding: EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: prestations.length,
      itemBuilder: (context, index) {
        final prestation = prestations[index];
        return _buildPrestationCard(prestation, isGrid: true);
      },
    );
  }

  Widget _buildPrestationCard(PrestationModel prestation, {required bool isGrid}) {
    final isDeleting = prestation.id != null && _deletingIds.contains(prestation.id);
    final imageUrl = prestation.profile ?? (prestation.images?.isNotEmpty == true ? prestation.images!.first : null);
    
    return GestureDetector(
      onTap: isDeleting ? null : () {
        if (prestation.id != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ServiceDetailPage(service: prestation),
            ),
          );
        }
      },
      child: Opacity(
        opacity: isDeleting ? 0.5 : 1.0,
        child: Container(
          decoration: BoxDecoration(
            color: _cardBackground,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          // Fix: Enforce height in ListView so Expanded works inside Column
          height: isGrid ? null : 280, 
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image
              Expanded(
                flex: isGrid ? 3 : 2,
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                      child: imageUrl != null
                          ? CachedNetworkImage(
                              imageUrl: imageUrl,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                color: _lightGrey,
                                child: Center(child: CircularProgressIndicator()),
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: _lightGrey,
                                child: Icon(Icons.image_not_supported, color: _mediumGrey),
                              ),
                            )
                          : Container(
                              color: _lightGrey,
                              child: Icon(Icons.work_outline, size: 50, color: _mediumGrey),
                            ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: _buildStatusBadge(prestation, isGrid: isGrid),
                    ),
                    if (prestation.minPrice != null)
                      Positioned(
                        bottom: 8,
                        left: 8,
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${NumberFormat('#,###').format(prestation.minPrice)} ${prestation.currency ?? "CDF"}',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    if (prestation.cityValue != null && prestation.cityValue!.isNotEmpty)
                       Positioned(
                         top: 8,
                         left: 8,
                         child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.location_on, size: 12, color: Colors.white),
                              SizedBox(width: 4),
                              ConstrainedBox(
                                constraints: BoxConstraints(maxWidth: 100),
                                child: Text(
                                  prestation.cityValue!,
                                  style: TextStyle( color: Colors.white, fontSize: 10, fontWeight: FontWeight.w500),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              )
                            ],
                          ),
                         ),
                       ),
                  ],
                ),
              ),
              // Contenu
              Expanded(
                flex: isGrid ? 2 : 1,
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        prestation.title ?? 'Sans titre',
                        style: GoogleFonts.inter(
                          fontSize: isGrid ? 14 : 16,
                          fontWeight: FontWeight.w600,
                          color: _darkColor,
                        ),
                        maxLines: isGrid ? 2 : 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4),
                      SizedBox(height: 8),
                      // Action Buttons
                      if (!isGrid) // Use buttons primarily in List View where there is space
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                 // Modifier logic - navigate to edit (reuse create route with args if supported or show details)
                                 // For now, redirect to detail which usually has edit
                                 if (prestation.id != null) {
                                   Navigator.push(context, MaterialPageRoute(builder: (c) => ServiceDetailPage(service: prestation)));
                                 }
                              }, 
                              icon: Icon(Icons.edit, size: 14, color: _primaryColor),
                              label: Text("Modifier", style: TextStyle(fontSize: 12, color: _primaryColor)),
                              style: OutlinedButton.styleFrom(
                                alignment: Alignment.center,
                                padding: EdgeInsets.symmetric(vertical: 0, horizontal: 8),
                                side: BorderSide(color: _primaryColor.withOpacity(0.5)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _deletePrestation(prestation), 
                              icon: Icon(Icons.delete, size: 14, color: _errorColor),
                              label: Text("Supprimer", style: TextStyle(fontSize: 12, color: _errorColor)),
                              style: OutlinedButton.styleFrom(
                                alignment: Alignment.center,
                                padding: EdgeInsets.symmetric(vertical: 0, horizontal: 8),
                                side: BorderSide(color: _errorColor.withOpacity(0.5)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                          ),
                        ],
                      )
                      else // In Grid View, keep simple menu or IconButtons
                        Row(
                           mainAxisAlignment: MainAxisAlignment.end,
                           children: [
                              InkWell(
                                onTap: () {
                                   if (prestation.id != null) {
                                      Navigator.push(context, MaterialPageRoute(builder: (c) => ServiceDetailPage(service: prestation)));
                                   }
                                },
                                child: Container(
                                  padding: EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: _primaryColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(Icons.edit, size: 16, color: _primaryColor),
                                ),
                              ),
                              SizedBox(width: 8),
                              InkWell(
                                onTap: () => _deletePrestation(prestation),
                                child: Container(
                                  padding: EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: _errorColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(Icons.delete, size: 16, color: _errorColor),
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
      ),
    );
  }
  
  Widget _buildSolicitationCard(SollicitationModel item) {
    return Container(
       padding: EdgeInsets.all(16),
       decoration: BoxDecoration(
         color: _cardBackground,
         borderRadius: BorderRadius.circular(16),
         boxShadow: [
           BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: Offset(0, 4))
         ],
       ),
       child: Column(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(item.status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    item.status ?? 'PENDING',
                    style: TextStyle(color: _getStatusColor(item.status), fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
                Text(
                  item.createdAt != null && item.createdAt!.isNotEmpty
                      ? _dateFormat.format(DateTime.parse(item.createdAt!))
                      : '',
                  style: TextStyle(color: _mediumGrey, fontSize: 12),
                ),
              ],
            ),
            SizedBox(height: 12),
            if (item.prestation != null) ...[
               Row(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   Container(
                     width: 50, 
                     height: 50,
                     decoration: BoxDecoration(
                       borderRadius: BorderRadius.circular(8),
                       color: _lightGrey,
                     ),
                     child: ClipRRect(
                       borderRadius: BorderRadius.circular(8),
                       child: (item.prestation!.profile != null || (item.prestation!.images?.isNotEmpty ?? false))
                         ? CachedNetworkImage(
                             imageUrl: item.prestation!.profile ?? item.prestation!.images!.first,
                             fit: BoxFit.cover,
                             errorWidget: (context, url, err) => Icon(Icons.build, color: _mediumGrey),
                           )
                         : Icon(Icons.build, color: _mediumGrey),
                     ),
                   ),
                   SizedBox(width: 12),
                   Expanded(
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                          Text(
                            item.prestation!.title ?? 'Service',
                            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: _darkColor),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 4),
                          Text(
                            item.prestation!.cityValue ?? '',
                            style: TextStyle(fontSize: 12, color: _mediumGrey),
                          ),
                       ],
                     ),
                   ),
                 ],
               ),
               SizedBox(height: 12),
            ],
            Divider(color: Colors.grey[200]),
            SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.calendar_today_rounded, size: 16, color: _primaryColor),
                SizedBox(width: 8),
                Text(
                  '${_formatDate(item.startDate)} - ${_formatDate(item.endDate)}',
                  style: TextStyle(fontSize: 13, color: _darkColor),
                ),
              ],
            ),
            SizedBox(height: 8),
            Row(
               children: [
                 Icon(Icons.monetization_on_rounded, size: 16, color: _successColor),
                 SizedBox(width: 8),
                 Text(
                   'Budget: ${NumberFormat('#,###').format(item.budget)} ${item.prestation?.currency ?? 'CDF'}',
                   style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _darkColor),
                 ),
               ],
            ),
            if (item.description != null && item.description!.isNotEmpty) ...[
               SizedBox(height: 8),
               Container(
                 padding: EdgeInsets.all(10),
                 decoration: BoxDecoration(
                   color: _lightGrey,
                   borderRadius: BorderRadius.circular(8),
                 ),
                 child: Text(
                   item.description!,
                   style: TextStyle(fontSize: 13, color: Colors.grey[800]),
                   maxLines: 2,
                   overflow: TextOverflow.ellipsis,
                 ),
               ),
            ],
         ],
       ),
    );
  }
  
  String _formatDate(String? dateStr) {
     if (dateStr == null) return '';
     try {
       final date = DateTime.parse(dateStr);
       return DateFormat('dd MMM').format(date);
     } catch (e) {
       return dateStr;
     }
  }
  
  Color _getStatusColor(String? status) {
    switch (status?.toUpperCase()) {
      case 'ACCEPTED':
      case 'CONFIRMED':
        return _successColor;
      case 'PENDING': 
        return _warningColor;
      case 'REJECTED': 
      case 'CANCELLED':
        return _errorColor;
      default: 
        return _mediumGrey;
    }
  }

  Widget _buildStatusBadge(PrestationModel prestation, {bool isGrid = false}) {
    Color bgColor;
    String text;

    if (prestation.isActive == true) {
      bgColor = _successColor;
      text = 'Active';
    } else {
      bgColor = _mediumGrey;
      text = 'Inactive';
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: isGrid ? 8 : 12, vertical: isGrid ? 4 : 6),
      decoration: BoxDecoration(
        color: bgColor.withOpacity(0.9),
        borderRadius: BorderRadius.circular(isGrid ? 12 : 20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: isGrid ? 10 : 12,
        ),
      ),
    );
  }

  void _showOptionsMenu(PrestationModel prestation) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.visibility, color: _primaryColor),
              title: Text('Voir les détails'),
              onTap: () {
                Navigator.pop(context);
                if (prestation.id != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ServiceDetailPage(service: prestation),
                    ),
                  );
                }
              },
            ),
            ListTile(
              leading: Icon(Icons.delete, color: _errorColor),
              title: Text('Supprimer', style: TextStyle(color: _errorColor)),
              onTap: () {
                Navigator.pop(context);
                _deletePrestation(prestation);
              },
            ),
          ],
        ),
      ),
    );
  }
}
