import 'package:casa/controllers/PropertyCtrl.dart';
import 'package:casa/models/PropertyModel.dart';
import 'package:casa/screens/PropertyDetailPage.dart';
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

class MyPropertiesPage extends StatefulWidget {
  @override
  _MyPropertiesPageState createState() => _MyPropertiesPageState();
}

class _MyPropertiesPageState extends State<MyPropertiesPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoadingData = true;
  bool _isRefreshing = false;
  final DateFormat _dateFormat = DateFormat('dd MMM yyyy', 'fr_FR');
  final GetStorage _stockage = GetStorage();
  
  // Couleurs modernes (même que FavoritesPage)
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

  List<PropertyModel> _myProperties = [];
  List<int> _deletingIds = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMyProperties();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadMyProperties() async {
    try {
      setState(() {
        _isLoadingData = true;
        _isRefreshing = true;
      });

      final propertyController = Provider.of<PropertyController>(context, listen: false);
      final properties = await propertyController.getMyProperties();
      
      if (mounted) {
        setState(() {
          _myProperties = properties;
          _isLoadingData = false;
          _isRefreshing = false;
        });
      }
    } catch (e) {
      print("❌ Erreur lors du chargement des propriétés: $e");
      if (mounted) {
        setState(() {
          _isLoadingData = false;
          _isRefreshing = false;
        });
        FancyNotification.show(context, "Erreur lors du chargement des propriétés");
      }
    }
  }

  Future<void> _deleteProperty(PropertyModel property) async {
    if (property.propertyId == null) return;

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
          'Êtes-vous sûr de vouloir supprimer "${property.title}" ?\n\nCette action est irréversible.',
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
      if (property.propertyId != null) {
        _deletingIds.add(property.propertyId!);
      }
    });

    try {
      final propertyController = Provider.of<PropertyController>(context, listen: false);
      final response = await propertyController.deleteProperty(property.propertyId!);

      if (response.status == true) {
        if (mounted) {
          FancyNotification.show(
            context,
            "Propriété supprimée avec succès",
            type: NotificationType.success,
          );
          await _loadMyProperties();
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
      if (mounted && property.propertyId != null) {
        setState(() {
          _deletingIds.remove(property.propertyId!);
        });
      }
    }
  }

  void _editProperty(PropertyModel property) {
    // TODO: Créer une page séparée pour l'édition ou restaurer la fonctionnalité
    FancyNotification.show(
      context,
      "La modification sera disponible prochainement",
      type: NotificationType.info,
    );
  }

  void _viewProperty(PropertyModel property) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PropertyDetailPage(property: property),
      ),
    );
  }

  void _handleCreateProperty() {
    var token = _stockage.read(StockageKeys.tokenKey);
    var userData = _stockage.read(StockageKeys.userKey);
    var typeAccountObj = userData?['typeAccount'];
    var typeAccountId = typeAccountObj is Map 
        ? (typeAccountObj['typeAccountId'] ?? typeAccountObj['TypeAccountId'])
        : (userData?['typeAccountId'] ?? userData?['TypeAccountId']);

    if (token == null) {
      FancyNotification.show(
        context,
        "Vous devez avoir un compte et être connecté pour publier une annonce",
        type: NotificationType.info,
      );
      return;
    }

    if (typeAccountId == 4) {
      FancyNotification.show(
        context,
        "La création d'annonces est réservée aux bailleurs, commissionnaires et prestataires de services",
        type: NotificationType.info,
      );
      return;
    }

    if (typeAccountId != null && typeAccountId >= 5 && typeAccountId <= 20) {
      Navigator.pushNamed(
        context,
        Routes.createServicePostRoute,
      ).then((_) => _loadMyProperties());
      return;
    }

    if (typeAccountId == 2 || typeAccountId == 3) {
      Navigator.pushNamed(context, Routes.createPropertyRoute)
          .then((_) => _loadMyProperties());
    } else {
      FancyNotification.show(
        context,
        "Type de compte non reconnu. Veuillez contacter le support.",
        type: NotificationType.info,
      );
    }
  }

  List<PropertyModel> get _activeProperties => _myProperties.where((p) => p.isActive == true).toList();
  List<PropertyModel> get _inactiveProperties => _myProperties.where((p) => p.isActive != true).toList();

  List<PropertyModel> _filterProperties(String filter) {
    switch (filter) {
      case 'active':
        return _activeProperties;
      case 'inactive':
        return _inactiveProperties;
      case 'all':
      default:
        return _myProperties;
    }
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
                _buildPropertyList(_filterProperties('all')),
                _buildPropertyList(_filterProperties('active')),
                _buildPropertyList(_filterProperties('inactive')),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: "my_properties_fab",
        onPressed: _handleCreateProperty,
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 3,
        icon: Icon(Icons.add_rounded, size: 24),
        label: Text(
          'Nouveau',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
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
            child: Icon(Icons.home_rounded, color: Colors.white, size: 18),
          ),
          SizedBox(width: 12),
          Text(
            'Mes propriétés',
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
          message: 'Actualiser',
          child: Stack(
            children: [
              IconButton(
                icon: Icon(_isRefreshing ? Icons.refresh : Icons.refresh, color: Colors.white),
                onPressed: _isRefreshing ? null : _loadMyProperties,
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
    final allCount = _filterProperties('all').length;
    final activeCount = _filterProperties('active').length;
    final inactiveCount = _filterProperties('inactive').length;

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

  Widget _buildPropertyList(List<PropertyModel> properties) {
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
          : properties.isEmpty
          ? _buildEmptyState()
          : _buildPropertyListContent(properties),
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
      "Aucune propriété publiée",
      "Aucune propriété active",
      "Aucune propriété inactive"
    ];

    final emptyIcons = [
      Icons.home_work_outlined,
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
              'Aucune propriété',
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
              onPressed: _handleCreateProperty,
              icon: Icon(Icons.add_rounded, size: 20),
              label: Text('Créer une annonce'),
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

  Widget _buildPropertyListContent(List<PropertyModel> properties) {
    return RefreshIndicator(
      color: _primaryColor,
      backgroundColor: Colors.white,
      onRefresh: _loadMyProperties,
      child: ListView.separated(
        padding: EdgeInsets.all(20),
        itemCount: properties.length,
        separatorBuilder: (_, __) => SizedBox(height: 20),
        itemBuilder: (context, index) {
          final property = properties[index];
          return AnimatedSwitcher(
            duration: Duration(milliseconds: 300),
            child: _buildPropertyCard(property),
          );
        },
      ),
    );
  }

  Widget _buildPropertyCard(PropertyModel property) {
    final isForRent = property.transactionType?.toLowerCase() == 'location';
    final isAvailable = property.isActive == true;
    final isDeleting = _deletingIds.contains(property.propertyId);

    final firstImage = property.propertyImage?.isNotEmpty ?? false
        ? property.propertyImage!.first
        : null;
    final imageUrl = firstImage?.path;

    final priceText = isForRent
        ? '${NumberFormat('#,###').format(property.price?.toInt() ?? 0)}\$/mois'
        : '${NumberFormat('#,###').format(property.price?.toInt() ?? 0)}\$';

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => _viewProperty(property),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: _cardBackground,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              spreadRadius: 1,
              offset: Offset(0, 10),
            )
          ],
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    Container(
                      height: 180,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                        color: _lightGrey,
                      ),
                      child: imageUrl != null
                          ? ClipRRect(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                        child: CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          placeholder: (context, url) => Container(
                            color: _lightGrey,
                            child: Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: _primaryColor,
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) {
                            return Container(
                              color: _lightGrey,
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.home, size: 50, color: _mediumGrey),
                                    SizedBox(height: 8),
                                    Text(
                                      'Image non disponible',
                                      style: TextStyle(
                                        color: _mediumGrey,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      )
                          : Container(
                        color: _lightGrey,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.home, size: 50, color: _mediumGrey),
                              SizedBox(height: 8),
                              Text(
                                'Aucune image',
                                style: TextStyle(
                                  color: _mediumGrey,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 15,
                      left: 15,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isAvailable ? _successColor.withOpacity(0.9) : _errorColor.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          isAvailable ? 'Active' : 'Inactive',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 15,
                      right: 15,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          priceText,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    if (property.viewCount != null && property.viewCount! > 0)
                      Positioned(
                        top: 15,
                        left: 15,
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.visibility_rounded, color: Colors.white, size: 14),
                              SizedBox(width: 4),
                              Text(
                                '${property.viewCount}',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "${property.title ?? 'Propriété sans titre'}",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: _darkColor,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 16,
                            color: _mediumGrey,
                          ),
                          SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              "${property.address ?? 'Adresse non disponible'}",
                              style: TextStyle(
                                color: _mediumGrey,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 15),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _buildFeatureChips(property),
                      ),
                      SizedBox(height: 15),
                      Divider(height: 1, color: _lightGrey),
                      SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => _editProperty(property),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: _primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: _primaryColor.withOpacity(0.3)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.edit_outlined,
                                      size: 16,
                                      color: _primaryColor,
                                    ),
                                    SizedBox(width: 5),
                                    Text(
                                      'Modifier',
                                      style: TextStyle(
                                        color: _primaryColor,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: InkWell(
                              onTap: () => _deleteProperty(property),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: _errorColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: _errorColor.withOpacity(0.3)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (isDeleting)
                                      SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: _errorColor,
                                        ),
                                      )
                                    else
                                      Icon(
                                        Icons.delete_outline,
                                        size: 16,
                                        color: _errorColor,
                                      ),
                                    if (!isDeleting) ...[
                                      SizedBox(width: 5),
                                      Text(
                                        'Supprimer',
                                        style: TextStyle(
                                          color: _errorColor,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
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
            if (isDeleting)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildFeatureChips(PropertyModel property) {
    final features = <Widget>[];

    if (property.bedrooms != null && property.bedrooms! > 0) {
      features.add(_buildFeatureChip('${property.bedrooms} chambres'));
    }
    if (property.bathroom != null && property.bathroom! > 0) {
      features.add(_buildFeatureChip('${property.bathroom} sdb'));
    }
    if (property.surface != null && property.surface! > 0) {
      features.add(_buildFeatureChip('${property.surface!.toStringAsFixed(0)}m²'));
    }
    if (property.rooms != null && property.rooms! > 0) {
      features.add(_buildFeatureChip('${property.rooms} pièces'));
    }

    return features;
  }

  Widget _buildFeatureChip(String text) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _chipBackground,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: _darkColor,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
