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
import '../utils/database/DatabaseHelper.dart';
import '../utils/UserInfoBottomSheet.dart';
import '../widgets/ModernCustomDialog.dart'; // Import du nouveau modal
import 'FullScreenImageViewer.dart'; // Pour le zoom image
import 'auth/IdentityVerificationPage.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';

class MyServicesPage extends StatefulWidget {
  @override
  _MyServicesPageState createState() => _MyServicesPageState();
}

class _MyServicesPageState extends State<MyServicesPage> with SingleTickerProviderStateMixin {
  // View mode: 0 = Mes Annonces, 1 = Mes Demandes, 2 = Demandes reçues
  int _viewMode = 0;
  bool _isLoadingData = true;
  bool _isRefreshing = false;
  final Set<int> _loadedTabs = {}; // Suivi des onglets déjà chargés via API

  late TabController _tabController;
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

  List<PrestationModel> _myPrestations = [];
  List<SollicitationModel> _mySolicitations = []; // Sent by user
  List<SollicitationModel> _hostSolicitations = []; // Received by provider
  List<int> _deletingIds = [];
  bool _isGridView = false;
  bool _isProcessingAction = false; // Pour les overlays de chargement
  pw.MemoryImage? _logoImage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        final newIndex = _tabController.index;
        if (newIndex != _viewMode) {
          setState(() {
            _viewMode = newIndex;
            // Si l'onglet n'a pas encore été chargé, on déclenche le shimmer
            if (!_loadedTabs.contains(newIndex)) {
              _isLoadingData = true;
            }
          });
          _loadData();
        }
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
      _loadLogo();
    });
  }

  Future<void> _loadLogo() async {
    try {
      final data = await rootBundle.load('assets/images/logoCasa.png');
      setState(() {
        _logoImage = pw.MemoryImage(data.buffer.asUint8List());
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData({bool forceRefresh = false}) async {
    // Si on a déjà chargé l'onglet et qu'on ne force pas le refresh, on ne fait rien
    if (_loadedTabs.contains(_viewMode) && !forceRefresh) {
      if (mounted) {
        setState(() {
          _isLoadingData = false;
          _isRefreshing = false;
        });
      }
      return;
    }

    setState(() {
      _isLoadingData = true;
      _isRefreshing = true;
    });

    // Load based on current view
    if (_viewMode == 0) {
      // Mes Annonces
      await _loadMyPrestations();
    } else if (_viewMode == 1) {
      // Mes Demandes
      await _loadMySolicitations(forceRefresh: forceRefresh);
    } else if (_viewMode == 2) {
      // Demandes reçues
      await _loadHostSolicitations(forceRefresh: forceRefresh);
    }

    if (mounted) {
      setState(() {
        _isLoadingData = false;
        _isRefreshing = false;
        if (!forceRefresh) _loadedTabs.add(_viewMode);
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
  
  Future<void> _loadMySolicitations({bool forceRefresh = false}) async {
    try {
      // 1. Charger le cache d'abord
      final db = DatabaseHelper.instance;
      final cachedSolicitations = await db.getAllUserSolicitations();
      
      if (cachedSolicitations.isNotEmpty && mounted) {
        setState(() {
          _mySolicitations = cachedSolicitations;
          // Si on a des données en cache et qu'on n'est pas en force refresh, on peut arrêter le shimmer
          if (!forceRefresh) _isLoadingData = false;
        });
        print("📁 [MyServicesPage] ${_mySolicitations.length} sollicitations chargées depuis le cache");
      }

      // 2. Appel API
      final serviceController = Provider.of<ServiceController>(context, listen: false);
      final solicitations = await serviceController.fetchUserSollicitations();
      
      if (mounted) {
        // 3. Comparer et mettre à jour si différent
        bool hasChanges = forceRefresh || _mySolicitations.length != solicitations.length;
        if (!hasChanges) {
          for (int i = 0; i < solicitations.length; i++) {
            if (i >= _mySolicitations.length || solicitations[i].id != _mySolicitations[i].id || solicitations[i].status != _mySolicitations[i].status) {
              hasChanges = true;
              break;
            }
          }
        }

        if (hasChanges) {
          setState(() {
            _mySolicitations = solicitations;
          });
          // 4. Mettre à jour le cache
          await db.clearUserSolicitations();
          await db.insertMultipleUserSolicitations(solicitations);
          print("💾 [MyServicesPage] Cache des sollicitations utilisateur mis à jour");
        }
      }
    } catch (e) {
      print("❌ Erreur lors du chargement des sollicitations: $e");
    }
  }

  Future<void> _loadHostSolicitations({bool forceRefresh = false}) async {
    try {
      // 1. Charger le cache d'abord
      final db = DatabaseHelper.instance;
      final cachedSolicitations = await db.getAllHostSolicitations();
      
      if (cachedSolicitations.isNotEmpty && mounted) {
        setState(() {
          _hostSolicitations = cachedSolicitations;
          if (!forceRefresh) _isLoadingData = false;
        });
        print("📁 [MyServicesPage] ${_hostSolicitations.length} sollicitations host chargées depuis le cache");
      }

      // 2. Appel API
      final serviceController = Provider.of<ServiceController>(context, listen: false);
      final solicitations = await serviceController.fetchHostSollicitations();
      
      if (mounted) { 
        // 3. Comparer et mettre à jour
        bool hasChanges = forceRefresh || _hostSolicitations.length != solicitations.length;
        if (!hasChanges) {
          for (int i = 0; i < solicitations.length; i++) {
            if (i >= _hostSolicitations.length || solicitations[i].id != _hostSolicitations[i].id || solicitations[i].status != _hostSolicitations[i].status) {
              hasChanges = true;
              break;
            }
          }
        }

        if (hasChanges) {
          setState(() {
            _hostSolicitations = solicitations;
          });
          // 4. Mettre à jour le cache
          await db.clearHostSolicitations();
          await db.insertMultipleHostSolicitations(solicitations);
          print("💾 [MyServicesPage] Cache des sollicitations host mis à jour");
        }
      }
    } catch (e) {
      print("❌ Erreur lors du chargement des sollicitations host: $e");
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



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _lightGrey,
      appBar: _buildAppBar(),
      body: _buildBody(),
      floatingActionButton: _viewMode == 0 ? _buildFAB() : null,
    );
  }

  Widget _buildBody() {
    return TabBarView(
      controller: _tabController,
      children: [
        // Tab 0: Mes Annonces
        _buildPrestationList(_myPrestations),
        // Tab 1: Mes Demandes
        _buildSolicitationList(_mySolicitations),
        // Tab 2: Demandes Reçues
        _buildSolicitationList(_hostSolicitations),
      ],
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      iconTheme: IconThemeData(color: Colors.white),
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
      bottom: TabBar(
        controller: _tabController,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white.withOpacity(0.6),
        indicatorColor: Colors.white,
        indicatorWeight: 3,
        labelStyle: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        unselectedLabelStyle: TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 13,
        ),
        tabs: [
          Tab(text: 'Mes Annonces '),
          Tab(text: 'Mes Demandes '),
          Tab(text: 'Demandes Reçues)'),
        ],
      ),
      actions: [
        if (_viewMode == 0) ...[
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
                onPressed: _isRefreshing ? null : () => _loadData(forceRefresh: true),
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
  
  Widget _buildFAB() {
    return FloatingActionButton.extended(
      onPressed: _navigateToCreateService,
      backgroundColor: _primaryColor,
      icon: Icon(Icons.add_rounded, color: Colors.white),
      label: Text(
        'Créer un service',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
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
        onRefresh: () => _loadData(forceRefresh: true),
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
          Text('Aucune demande trouvée', style: TextStyle(color: _mediumGrey, fontSize: 18, fontWeight: FontWeight.w600)),
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
    final imageUrl = prestation.profile ?? (prestation.images != null && prestation.images!.isNotEmpty ? prestation.images!.first : null);
    
    return GestureDetector(
      onTap: isDeleting ? null : () {
        if (prestation.id != null) {
          final serviceController = Provider.of<ServiceController>(context, listen: false);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ServiceDetailPage(
                service: prestation,
                serviceTypeName: serviceController.getServiceName(prestation.serviceId),
              ),
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
          height: isGrid ? null : 320, 
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
                      child: imageUrl != null && imageUrl.isNotEmpty
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
                            '${NumberFormat('#,###').format(prestation.minPrice)} ${prestation.currency}',
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
                                   final serviceController = Provider.of<ServiceController>(context, listen: false);
                                   Navigator.push(
                                     context, 
                                     MaterialPageRoute(
                                       builder: (c) => ServiceDetailPage(
                                         service: prestation,
                                         serviceTypeName: serviceController.getServiceName(prestation.serviceId),
                                       ),
                                     ),
                                   );
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
                                      final serviceController = Provider.of<ServiceController>(context, listen: false);
                                      Navigator.push(
                                        context, 
                                        MaterialPageRoute(
                                          builder: (c) => ServiceDetailPage(
                                            service: prestation,
                                            serviceTypeName: serviceController.getServiceName(prestation.serviceId),
                                          ),
                                        ),
                                      );
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
    // Logic for currency based on deviseId (1 = FC, 2 = $)
    final String currency = (item.deviseId == 1) ? "FC" : "\$";

    return GestureDetector(
      onTap: () {
        if (_viewMode == 2) {
          // Si on est dans "Demandes reçues", on affiche le BottomSheet de gestion
          _showSolicitationActionBottomSheet(item);
        } else if (item.prestation != null) {
          final serviceController = Provider.of<ServiceController>(context, listen: false);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ServiceDetailPage(
                service: item.prestation!,
                serviceTypeName: serviceController.getServiceName(item.prestation!.serviceId),
              ),
            ),
          );
        }
      },
      child: Container(
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
                  Row(
                    children: [
                      if (_viewMode == 2 && item.user != null) ...[
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: BoxConstraints(),
                          icon: Icon(Icons.person_pin_rounded, size: 20, color: _primaryColor),
                          onPressed: () => UserInfoBottomSheet.show(context, item.user!),
                          tooltip: "Voir le demandeur",
                        ),
                        SizedBox(width: 8),
                      ],
                      Text(
                        item.createdAt != null && item.createdAt!.isNotEmpty
                            ? _dateFormat.format(DateTime.parse(item.createdAt!))
                            : '',
                        style: TextStyle(color: _mediumGrey, fontSize: 12),
                      ),
                    ],
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
                         image: (item.prestation!.profile != null || (item.prestation!.images?.isNotEmpty ?? false))
                           ? DecorationImage(
                               image: CachedNetworkImageProvider(
                                 item.prestation!.profile ?? item.prestation!.images!.first,
                               ),
                               fit: BoxFit.cover,
                             )
                           : null,
                       ),
                       child: (item.prestation!.profile == null && (item.prestation!.images?.isEmpty ?? true))
                         ? Icon(Icons.build, color: _mediumGrey)
                         : null,
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
                     'Budget: ${NumberFormat('#,###').format(item.budget)} $currency',
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
  
  void _showSolicitationActionBottomSheet(SollicitationModel item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildSolicitationBottomSheetContent(item),
    );
  }

  Widget _buildSolicitationBottomSheetContent(SollicitationModel item) {
    final String currency = (item.deviseId == 1) ? "FC" : "\$";
    final isPending = item.status?.toUpperCase() == 'PENDING';

    return Container(
      padding: EdgeInsets.fromLTRB(24, 12, 24, 24 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),
          ),
          SizedBox(height: 24),
          Row(
             children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(color: _primaryColor.withOpacity(0.1), shape: BoxShape.circle),
                  child: Icon(Icons.assignment_ind_rounded, color: _primaryColor, size: 28),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Détail de la demande", style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: _darkColor)),
                      Text("Gérer la sollicitation reçue", style: TextStyle(color: _mediumGrey, fontSize: 13)),
                    ],
                  ),
                ),
             ],
          ),
          SizedBox(height: 24),
          
          if (item.user != null) ...[
             Text("Demandeur", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: _darkColor)),
             SizedBox(height: 12),
             Container(
               padding: EdgeInsets.all(12),
               decoration: BoxDecoration(color: _lightGrey, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[200]!)),
               child: Row(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   GestureDetector(
                     onTap: () {
                        if (item.user?.profilePicture != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => FullScreenImageViewer(imagePath: item.user!.profilePicture!),
                            ),
                          );
                        }
                     },
                     child: CircleAvatar(
                       radius: 24,
                       backgroundColor: _primaryColor.withOpacity(0.2),
                       backgroundImage: (item.user?.profilePicture != null && item.user!.profilePicture!.isNotEmpty)
                           ? CachedNetworkImageProvider(item.user!.profilePicture!)
                           : null,
                       child: (item.user?.profilePicture == null || item.user!.profilePicture!.isEmpty)
                           ? Icon(Icons.person, color: _primaryColor)
                           : null,
                     ),
                   ),
                   SizedBox(width: 16),
                   Expanded(
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         Text(
                           item.user!.username ?? "Utilisateur", 
                           style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _darkColor)
                         ),
                         SizedBox(height: 4),
                         // Téléphone
                         if (item.user!.phone != null && item.user!.phone!.isNotEmpty)
                           Padding(
                             padding: const EdgeInsets.only(bottom: 2),
                             child: Row(
                               children: [
                                 Icon(Icons.phone_iphone_rounded, size: 14, color: _mediumGrey),
                                 SizedBox(width: 4),
                                 Text(item.user!.phone!, style: TextStyle(color: _darkColor, fontSize: 13)),
                               ],
                             ),
                           ),
                         // Email (si disponible)
                         if (item.user!.email != null && item.user!.email!.isNotEmpty && item.user!.email != 'null')
                           Padding(
                             padding: const EdgeInsets.only(bottom: 2),
                             child: Row(
                               children: [
                                 Icon(Icons.email_outlined, size: 14, color: _mediumGrey),
                                 SizedBox(width: 4),
                                 Expanded(child: Text(item.user!.email!, style: TextStyle(color: _darkColor, fontSize: 13), overflow: TextOverflow.ellipsis)),
                               ],
                             ),
                           ),
                         // Localisation (si disponible)
                         if (item.user!.formattedLocation.isNotEmpty)
                           Row(
                             children: [
                               Icon(Icons.location_on_outlined, size: 14, color: _mediumGrey),
                               SizedBox(width: 4),
                               Expanded(child: Text(item.user!.formattedLocation, style: TextStyle(color: _darkColor, fontSize: 13), overflow: TextOverflow.ellipsis)),
                             ],
                           ),
                       ],
                     ),
                   ),
                 ],
               ),
             ),
             SizedBox(height: 20),
          ],

          Text("Service concerné", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: _darkColor)),
          SizedBox(height: 8),
          InkWell(
            onTap: () {
              Navigator.pop(context); // Fermer le bottom sheet
              if (item.prestation != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ServiceDetailPage(service: item.prestation!)),
                ).then((_) {
                   // Au retour, on reste sur l'onglet "Demandes Reçues" car setState n'a pas changé _viewMode
                   // Mais on peut forcer un refresh si besoin
                });
              }
            },
            child: Text(
              item.prestation?.title ?? "Service", 
              style: TextStyle(
                fontSize: 16, 
                color: _primaryColor, 
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline, // Souligné comme demandé
              ),
              maxLines: 1, // Une seule ligne
              overflow: TextOverflow.ellipsis, // Couper si trop long
            ),
          ),
          SizedBox(height: 4),
          if (item.budget != null) ...[
            SizedBox(height: 4),
            Text("Budget proposé: ${NumberFormat('#,###').format(item.budget)} $currency", style: TextStyle(color: _successColor, fontWeight: FontWeight.bold)),
          ],
          
          if (item.description != null && item.description!.isNotEmpty) ...[
            SizedBox(height: 16),
            Text("Description", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _mediumGrey)),
            SizedBox(height: 4),
            Text(item.description!, style: TextStyle(color: _darkColor, height: 1.4)),
          ],

          SizedBox(height: 32),
          if (isPending) ...[
             Row(
               children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _handleSolicitationAction(item, 'REJECTED'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _errorColor.withOpacity(0.1),
                        foregroundColor: _errorColor,
                        padding: EdgeInsets.symmetric(vertical: 16),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: _errorColor.withOpacity(0.2))),
                      ),
                      child: Text("REFUSER", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _handleSolicitationAction(item, 'ACCEPTED'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _successColor,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 16),
                        elevation: 4,
                        shadowColor: _successColor.withOpacity(0.4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text("VALIDER", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                    ),
                  ),
               ],
             ),
          ] else ...[
             Center(
               child: Text(
                 "Statut actuel: ${item.status?.toUpperCase()}",
                 style: TextStyle(color: _getStatusColor(item.status), fontWeight: FontWeight.bold),
               ),
             ),
          ],
          SizedBox(height: 12),
        ],
      ),
    );
  }

  Future<void> _handleSolicitationAction(SollicitationModel item, String status) async {
    Navigator.pop(context); // Fermer le BottomSheet
    
    final bool isAccept = status == 'ACCEPTED';
    
    // Demander confirmation via le nouveau ModernCustomDialog pour le refus
    if (!isAccept) {
       ModernCustomDialog.show(
         context,
         title: "Refuser la demande",
         message: "Êtes-vous sûr de vouloir refuser cette demande ? Cette action est irréversible.",
         confirmText: "REFUSER",
         cancelText: "ANNULER",
         isDanger: true,
         onConfirm: () async {
            // Logique de refus
            await _processSolicitationStatusUpdate(item, status, isAccept);
         },
       );
       return;
    }

    // Pour l'acceptation, on lance directement
    await _processSolicitationStatusUpdate(item, status, isAccept);
  }

  Future<void> _processSolicitationStatusUpdate(SollicitationModel item, String status, bool isAccept) async {

    setState(() => _isProcessingAction = true);
    
    try {
      final serviceCtrl = Provider.of<ServiceController>(context, listen: false);
      final response = await serviceCtrl.updateSollicitationStatus(item.id!, status);
      
      if (response.status == true) {
        await _loadHostSolicitations(forceRefresh: true);
        
        if (mounted && isAccept) {
           _showActionSuccessDialog(item);
        } else if (mounted) {
           FancyNotification.show(context, "Demande refusée avec succès", type: NotificationType.success);
        }
      } else {
        if (mounted) FancyNotification.show(context, response.errorMsg ?? "Erreur lors de la mise à jour");
      }
    } catch (e) {
      if (mounted) FancyNotification.show(context, "Une erreur est survenue: $e");
    } finally {
      if (mounted) setState(() => _isProcessingAction = false);
    }
  }

  void _showActionSuccessDialog(SollicitationModel item) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
               Container(
                 padding: EdgeInsets.all(16),
                 decoration: BoxDecoration(color: _successColor.withOpacity(0.1), shape: BoxShape.circle),
                 child: Icon(Icons.check_circle_rounded, color: _successColor, size: 60),
               ),
               SizedBox(height: 24),
               Text("Félicitations !", style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold)),
               SizedBox(height: 12),
               Text(
                 "Vous avez validé cette demande de service. Vous pouvez maintenant télécharger le bon de validation ou le partager avec le client.",
                 textAlign: TextAlign.center,
                 style: TextStyle(color: _mediumGrey, height: 1.5),
               ),
               SizedBox(height: 32),
               Row(
                 children: [
                   Expanded(
                     child: OutlinedButton.icon(
                       onPressed: () => _shareSolicitationPdf(item),
                       icon: Icon(Icons.share_rounded, size: 18),
                       label: Text("PARTAGER"),
                       style: OutlinedButton.styleFrom(
                         padding: EdgeInsets.symmetric(vertical: 14),
                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                       ),
                     ),
                   ),
                   SizedBox(width: 12),
                   Expanded(
                     child: ElevatedButton.icon(
                       onPressed: () => _downloadSolicitationPdf(item),
                       icon: Icon(Icons.download_rounded, size: 18),
                       label: Text("TÉLÉCHARGER"),
                       style: ElevatedButton.styleFrom(
                         backgroundColor: _primaryColor,
                         foregroundColor: Colors.white,
                         padding: EdgeInsets.symmetric(vertical: 14),
                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                         elevation: 0,
                       ),
                     ),
                   ),
                 ],
               ),
               SizedBox(height: 16),
               TextButton(
                 onPressed: () => Navigator.pop(context),
                 child: Text("FERMER", style: TextStyle(color: _mediumGrey, fontWeight: FontWeight.bold)),
               ),
            ],
          ),
        ),
      ),
    );
  }

  // --- PDF Logic for Services ---

  Future<Uint8List> _buildSolicitationPdfBytes(SollicitationModel item) async {
    final doc = pw.Document();
    final now = DateFormat('dd/MM/yy HH:mm').format(DateTime.now());
    
    final prestation = item.prestation;
    final String currency = (item.deviseId == 1) ? "FC" : "\$";

    doc.addPage(
      pw.Page(
        build: (context) => pw.Container(
          padding: const pw.EdgeInsets.all(32),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                   if (_logoImage != null) pw.Container(width: 60, height: 60, child: pw.Image(_logoImage!)),
                   pw.Column(
                     crossAxisAlignment: pw.CrossAxisAlignment.end,
                     children: [
                       pw.Text('CasaNayo Service', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                       pw.Text('Bon de validation #SOL-${item.id}'),
                       pw.Text('Généré le $now'),
                     ],
                   )
                ],
              ),
              pw.SizedBox(height: 40),
              pw.Text('DÉTAILS DE LA PRESTATION', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.Divider(),
              pw.SizedBox(height: 10),
              pw.Text('Service : ${prestation?.title ?? "Non spécifié"}'),
              pw.Text('Budget : ${NumberFormat('#,###').format(item.budget)} $currency'),
              pw.Text('Période : Du ${_formatDate(item.startDate)} au ${_formatDate(item.endDate)}'),
              pw.SizedBox(height: 30),
              pw.Text('INFORMATION CLIENT', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.Divider(),
              pw.SizedBox(height: 10),
              pw.Text('Nom : ${item.user?.username ?? "Client"}'),
              pw.Text('Téléphone : ${item.user?.phone ?? "N/A"}'),
              pw.SizedBox(height: 40),
              pw.Container(
                padding: pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(color: PdfColors.grey100, borderRadius: pw.BorderRadius.circular(8)),
                child: pw.Text(
                  "Ce document confirme l'acceptation de la sollicitation. Le prestataire s'engage à effectuer le service selon les termes convenus via la plateforme CasaNayo.",
                  style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic),
                  textAlign: pw.TextAlign.justify,
                ),
              ),
              pw.Spacer(),
              pw.Divider(),
              pw.Center(child: pw.Text("CasaNayo - Simplifiez votre vie immobilière et services.", style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600))),
            ],
          ),
        ),
      ),
    );
    return doc.save();
  }

  Future<void> _shareSolicitationPdf(SollicitationModel item) async {
    try {
      final bytes = await _buildSolicitationPdfBytes(item);
      final xfile = XFile.fromData(bytes, mimeType: 'application/pdf', name: 'Validation_Service_${item.id}.pdf');
      await Share.shareXFiles([xfile], text: "Bon de validation de service CasaNayo");
    } catch (e) {
      FancyNotification.show(context, "Impossible de partager le PDF");
    }
  }

  Future<void> _downloadSolicitationPdf(SollicitationModel item) async {
    try {
      final bytes = await _buildSolicitationPdfBytes(item);
      Directory? dir;
      if (Platform.isAndroid) {
        dir = Directory('/storage/emulated/0/Download');
        if (!await dir.exists()) dir = await getExternalStorageDirectory();
      } else {
        dir = await getApplicationDocumentsDirectory();
      }
      
      final file = File('${dir!.path}/Validation_Service_${item.id}.pdf');
      await file.writeAsBytes(bytes);
      FancyNotification.show(context, "PDF enregistré dans ${dir.path}", type: NotificationType.success);
    } catch (e) {
      FancyNotification.show(context, "Erreur lors de l'enregistrement: $e");
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
}
