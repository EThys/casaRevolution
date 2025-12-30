import 'package:casa/controllers/ServiceController.dart';
import 'package:casa/models/PrestationModel.dart';
import 'package:casa/models/ServiceModel.dart';
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
  List<int> _deletingIds = [];
  bool _isGridView = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMyPrestations();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadMyPrestations() async {
    try {
      setState(() {
        _isLoadingData = true;
        _isRefreshing = true;
      });

      final serviceController = Provider.of<ServiceController>(context, listen: false);
      final prestations = await serviceController.getMyPrestations();
      
      if (mounted) {
        setState(() {
          _myPrestations = prestations;
          _isLoadingData = false;
          _isRefreshing = false;
        });
      }
    } catch (e) {
      print("❌ Erreur lors du chargement des prestations: $e");
      if (mounted) {
        setState(() {
          _isLoadingData = false;
          _isRefreshing = false;
        });
        FancyNotification.show(context, "Erreur lors du chargement des prestations");
      }
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
           Navigator.pushNamed(context, Routes.createServicePostRoute).then((_) => _loadMyPrestations());
        }
      });
      return;
    }

    Navigator.pushNamed(context, Routes.createServicePostRoute)
        .then((_) => _loadMyPrestations());
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _lightGrey,
      appBar: _buildAppBar(),
      body: Column(
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
      ),
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
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.work_rounded, color: Colors.white, size: 18),
          ),
          SizedBox(width: 12),
          Text(
            'Mes services',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 18,
            ),
            textAlign: TextAlign.left,
          ),
        ],
      ),
      actions: [
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
        Tooltip(
          message: 'Actualiser',
          child: Stack(
            children: [
              IconButton(
                icon: Icon(_isRefreshing ? Icons.refresh : Icons.refresh, color: Colors.white),
                onPressed: _isRefreshing ? null : _loadMyPrestations,
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
      bottom: PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Container(
          height: 1,
          color: Colors.white.withOpacity(0.2),
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
      transitionBuilder: (Widget child, Animation<double> animation) {
        return ScaleTransition(
          scale: animation,
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
      child: _isLoadingData
          ? _buildShimmerEffect()
          : prestations.isEmpty
          ? _buildEmptyState()
          : _buildPrestationListContent(prestations),
    );
  }

  Widget _buildPrestationListContent(List<PrestationModel> prestations) {
    return RefreshIndicator(
      color: _primaryColor,
      backgroundColor: Colors.white,
      onRefresh: _loadMyPrestations,
      child: _isGridView
          ? _buildGridView(prestations)
          : ListView.separated(
              padding: EdgeInsets.all(20),
              itemCount: prestations.length,
              separatorBuilder: (_, __) => SizedBox(height: 20),
              itemBuilder: (context, index) {
                final prestation = prestations[index];
                return AnimatedSwitcher(
                  duration: Duration(milliseconds: 300),
                  child: _buildPrestationCard(prestation, isGrid: false),
                );
              },
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
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: Colors.white,
            ),
            padding: EdgeInsets.all(1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 180,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    color: Colors.grey[400],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 20,
                        width: double.infinity,
                        color: Colors.grey[400],
                      ),
                      SizedBox(height: 8),
                      Container(
                        height: 16,
                        width: 150,
                        color: Colors.grey[400],
                      ),
                      SizedBox(height: 12),
                      Container(
                        height: 16,
                        width: 200,
                        color: Colors.grey[400],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    final emptyMessages = [
      "Aucun service publié",
      "Aucun service actif",
      "Aucun service inactif"
    ];

    final emptyIcons = [
      Icons.work_outline,
      Icons.check_circle_outline,
      Icons.hourglass_empty
    ];

    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: _lightGrey,
                shape: BoxShape.circle,
              ),
              child: Icon(
                emptyIcons[_tabController.index],
                size: 60,
                color: _mediumGrey.withOpacity(0.3),
              ),
            ),
            SizedBox(height: 20),
            Text(
              'Aucun service',
              style: TextStyle(
                color: _mediumGrey,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 10),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                emptyMessages[_tabController.index],
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _mediumGrey.withOpacity(0.8),
                  fontSize: 14,
                ),
              ),
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _navigateToCreateService,
              icon: Icon(Icons.add_rounded, size: 20),
              label: Text('Créer un service'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListView(List<PrestationModel> prestations) {
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: prestations.length,
      itemBuilder: (context, index) {
        final prestation = prestations[index];
        return _buildPrestationCard(prestation, isGrid: false);
      },
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
          // Convertir PrestationModel en ServiceModel
          final serviceModel = _prestationToServiceModel(prestation);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ServiceDetailPage(service: serviceModel),
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
                      if (prestation.cityValue != null && prestation.cityValue!.isNotEmpty)
                        Row(
                          children: [
                            Icon(Icons.location_on, size: 14, color: _mediumGrey),
                            SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                prestation.cityValue!,
                                style: TextStyle(
                                  fontSize: isGrid ? 11 : 12,
                                  color: _mediumGrey,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      Spacer(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (prestation.minPrice != null)
                            Text(
                              '${NumberFormat('#,###').format(prestation.minPrice)} CDF',
                              style: GoogleFonts.inter(
                                fontSize: isGrid ? 12 : 14,
                                fontWeight: FontWeight.w600,
                                color: _primaryColor,
                              ),
                            ),
                          IconButton(
                            icon: Icon(Icons.more_vert, size: 20, color: _mediumGrey),
                            onPressed: () => _showOptionsMenu(prestation),
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
                  // Convertir PrestationModel en ServiceModel
                  final serviceModel = _prestationToServiceModel(prestation);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ServiceDetailPage(service: serviceModel),
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

  // Convertir PrestationModel en ServiceModel
  ServiceModel _prestationToServiceModel(PrestationModel prestation) {
    // Utiliser profile en premier, puis les images de portfolio
    List<String>? imagesList = [];
    
    // Ajouter la photo de profil en premier si elle existe
    if (prestation.profile != null && prestation.profile!.isNotEmpty) {
      imagesList.add(prestation.profile!);
    }
    
    // Ajouter les images de portfolio après
    if (prestation.images != null && prestation.images!.isNotEmpty) {
      imagesList.addAll(prestation.images!);
    }
    
    if (imagesList.isEmpty) {
      imagesList = null;
    }
    
    return ServiceModel()
      ..serviceId = prestation.id
      ..title = prestation.title ?? ''
      ..description = prestation.description ?? ''
      ..price = prestation.minPrice ?? prestation.maxPrice
      ..serviceType = ServiceType.reparation // Type par défaut
      ..address = prestation.address ?? ''
      ..cityValue = prestation.cityValue ?? ''
      ..communeValue = prestation.communeValue ?? ''
      ..quartierValue = prestation.quartierValue ?? ''
      ..isAvailable = prestation.isActive ?? true
      ..isVerified = prestation.isCertified ?? false
      ..rating = 4.5
      ..images = imagesList;
  }
}

