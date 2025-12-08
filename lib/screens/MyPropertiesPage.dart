import 'package:casa/controllers/PropertyCtrl.dart';
import 'package:casa/models/PropertyModel.dart';
import 'package:casa/models/ServiceModel.dart';
import 'package:casa/screens/PropertyDetailPage.dart';
import 'package:casa/utils/FancyNotification.dart';
import 'package:casa/utils/Routes.dart';
import 'package:casa/utils/StockageKeys.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:flutter_animate/flutter_animate.dart';

class MyPropertiesPage extends StatefulWidget {
  @override
  _MyPropertiesPageState createState() => _MyPropertiesPageState();
}

class _MyPropertiesPageState extends State<MyPropertiesPage> {
  final Color _primaryColor = Color(0xFF1976D2);
  final Color _accentColor = Color(0xFF64B5F6);
  final Color _darkColor = Color(0xFF1A237E);
  final Color _greyColor = Color(0xFF607D8B);
  final Color _greyLight = Color(0xFFECEFF1);
  final Color _cardColor = Colors.white;
  final Color _dangerColor = Color(0xFFF44336);
  final Color _successColor = Color(0xFF4CAF50);

  List<PropertyModel> _myProperties = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final GetStorage _stockage = GetStorage();
  final RefreshController _refreshController = RefreshController(initialRefresh: false);

  @override
  void initState() {
    super.initState();
    _loadMyProperties();
  }

  @override
  void dispose() {
    _refreshController.dispose();
    super.dispose();
  }

  Future<void> _loadMyProperties({bool isRefresh = false}) async {
    if (!isRefresh) {
      setState(() => _isLoading = true);
    }
    try {
      final propertyController = Provider.of<PropertyController>(context, listen: false);
      final properties = await propertyController.getMyProperties();
      if (mounted) {
        setState(() {
          _myProperties = properties;
          _isLoading = false;
        });
        if (isRefresh) {
          _refreshController.refreshCompleted();

        }
      }
    } catch (e) {
      print("❌ Erreur lors du chargement des propriétés: $e");
      if (mounted) {
        setState(() => _isLoading = false);
        if (isRefresh) {
          _refreshController.refreshFailed();
        }
        FancyNotification.show(context, "Erreur lors du chargement des propriétés");
      }
    }
  }

  void _onRefresh() async {
    await _loadMyProperties(isRefresh: true);
  }

  Future<void> _deleteProperty(PropertyModel property) async {
    if (property.propertyId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Supprimer la propriété',
          style: TextStyle(fontWeight: FontWeight.w700, color: _darkColor),
        ),
        content: Text(
          'Êtes-vous sûr de vouloir supprimer "${property.title}" ? Cette action est irréversible.',
          style: TextStyle(color: _greyColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Annuler', style: TextStyle(color: _greyColor)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _dangerColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Supprimer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

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
          _loadMyProperties();
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
    }
  }

  void _editProperty(PropertyModel property) {
    Navigator.pushNamed(
      context,
      Routes.createPropertyRoute,
      arguments: property, // Passer la propriété pour l'édition
    ).then((_) => _loadMyProperties());
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
    // typeAccount peut être un objet imbriqué ou directement un ID
    var typeAccountObj = userData?['typeAccount'];
    var typeAccountId = typeAccountObj is Map 
        ? (typeAccountObj['typeAccountId'] ?? typeAccountObj['TypeAccountId'])
        : (userData?['typeAccountId'] ?? userData?['TypeAccountId']);

    if (token == null) {
      SnackbarForCasa.info(
        context,
        "Vous devez avoir un compte et être connecté pour publier une annonce",
        onTap: () {
          Navigator.pushNamed(context, Routes.loginRoute);
        },
      );
      return;
    }

    // Vérifier le type de compte
    if (typeAccountId == 4) {
      // Locataire - ne peut pas créer
      SnackbarForCasa.info(
        context,
        "La création d'annonces est réservée aux bailleurs, commissionnaires et prestataires de services",
      );
      return;
    }

    if (typeAccountId == 5) {
      // Prestataire de service - vérifier le type de service
      var profile = _stockage.read(StockageKeys.profileKey);
      var serviceProvider = userData?['serviceProvider'] ?? profile?['serviceProvider'];
      var serviceType = serviceProvider?['serviceType'] ?? 
                       serviceProvider?['service_type'] ?? 
                       profile?['serviceType'] ??
                       userData?['serviceType'];
      
      if (serviceType == 'majordhomme' || serviceType == 'Majordhomme') {
        // Rediriger vers CreateServicePage avec type majordhomme
        Navigator.pushNamed(
          context,
          Routes.createServiceRoute,
          arguments: ServiceType.majordhomme,
        ).then((_) => _loadMyProperties());
      } else if (serviceType == 'demenagement' || serviceType == 'Demenagement') {
        // Rediriger vers CreateServicePage avec type déménagement
        Navigator.pushNamed(
          context,
          Routes.createServiceRoute,
          arguments: ServiceType.demenagement,
        ).then((_) => _loadMyProperties());
      } else {
        // Si le type n'est pas trouvé, permettre à l'utilisateur de choisir
        Navigator.pushNamed(
          context,
          Routes.createServiceRoute,
        ).then((_) => _loadMyProperties());
      }
      return;
    }

    // Bailleur (3) ou Commissionnaire (2) - peuvent créer des propriétés
    if (typeAccountId == 2 || typeAccountId == 3) {
      Navigator.pushNamed(context, Routes.createPropertyRoute)
          .then((_) => _loadMyProperties());
    } else {
      SnackbarForCasa.info(
        context,
        "Type de compte non reconnu. Veuillez contacter le support.",
      );
    }
  }

  List<PropertyModel> get _filteredProperties {
    if (_searchQuery.isEmpty) return _myProperties;
    return _myProperties.where((property) {
      final title = property.title?.toLowerCase() ?? '';
      final address = property.address?.toLowerCase() ?? '';
      final query = _searchQuery.toLowerCase();
      return title.contains(query) || address.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _greyLight,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(120),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_primaryColor, _accentColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: _primaryColor.withOpacity(0.3),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Mes Propriétés',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            fontSize: 22,
                            letterSpacing: -0.5,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '${_myProperties.length} annonce${_myProperties.length > 1 ? 's' : ''}',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: Icon(Icons.refresh_rounded, color: Colors.white),
                      onPressed: _loadMyProperties,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Barre de recherche améliorée
          Container(
            margin: EdgeInsets.fromLTRB(16, 16, 16, 12),
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(Icons.search_rounded, color: _primaryColor, size: 22),
                SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    onChanged: (value) => setState(() => _searchQuery = value),
                    style: TextStyle(fontSize: 15, color: _darkColor),
                    decoration: InputDecoration(
                      hintText: 'Rechercher une propriété...',
                      hintStyle: TextStyle(color: _greyColor, fontSize: 15),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                if (_searchQuery.isNotEmpty)
                  GestureDetector(
                    onTap: () => setState(() => _searchQuery = ''),
                    child: Container(
                      padding: EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: _greyLight,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.close_rounded, color: _greyColor, size: 18),
                    ),
                  ),
              ],
            ),
          ),

          // Statistiques améliorées
          if (!_isLoading && _myProperties.isNotEmpty)
            Container(
              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _cardColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 16,
                    offset: Offset(0, 4),
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem(
                    Icons.home_rounded,
                    '${_myProperties.length}',
                    'Total',
                    _primaryColor,
                  ),
                  Container(width: 1, height: 40, color: _greyLight),
                  _buildStatItem(
                    Icons.check_circle_rounded,
                    '${_myProperties.where((p) => p.isActive == true).length}',
                    'Actives',
                    _successColor,
                  ),
                  Container(width: 1, height: 40, color: _greyLight),
                  _buildStatItem(
                    Icons.visibility_rounded,
                    '${_myProperties.fold(0, (sum, p) => sum + (p.viewCount ?? 0))}',
                    'Vues',
                    _accentColor,
                  ),
                ],
              ),
            ),

          SizedBox(height: 16),

          // Liste des propriétés avec SmartRefresher
          Expanded(
            child: _isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: _primaryColor),
                        SizedBox(height: 16),
                        Text(
                          'Chargement de vos propriétés...',
                          style: TextStyle(
                            color: _greyColor,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                : _filteredProperties.isEmpty
                    ? SmartRefresher(
                        controller: _refreshController,
                        enablePullDown: true,
                        enablePullUp: false,
                        header: CustomHeader(
                          builder: (context, mode) {
                            return _buildRefreshHeader(mode!);
                          },
                        ),
                        onRefresh: _onRefresh,
                        child: _buildEmptyState(),
                      )
                    : SmartRefresher(
                        controller: _refreshController,
                        enablePullDown: true,
                        enablePullUp: false,
                        header: CustomHeader(
                          builder: (context, mode) {
                            return _buildRefreshHeader(mode!);
                          },
                        ),
                        onRefresh: _onRefresh,
                        child: ListView.separated(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: _filteredProperties.length,
                          separatorBuilder: (context, index) => SizedBox(height: 16),
                          itemBuilder: (context, index) {
                            return _buildPropertyCard(_filteredProperties[index])
                                .animate()
                                .fadeIn(duration: 300.ms, delay: (index * 50).ms)
                                .slideY(begin: 0.1, end: 0, duration: 300.ms, delay: (index * 50).ms);
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: Container(
        width: 56,
        height: 56,
        child: FloatingActionButton(
          backgroundColor: Colors.transparent,
          elevation: 0,
          highlightElevation: 0,
          splashColor: Colors.transparent,
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [_primaryColor, _accentColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: _primaryColor.withOpacity(0.4),
                  spreadRadius: 1,
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Icon(Icons.add_rounded, color: Colors.white, size: 28),
          ),
          onPressed: _handleCreateProperty,
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              color: _darkColor,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: _greyColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPropertyCard(PropertyModel property) {
    final firstImage = property.propertyImage?.isNotEmpty ?? false
        ? property.propertyImage!.first
        : null;
    final imageUrl = firstImage?.path != null
        ? "${firstImage!.path}"
        : null;

    final isActive = property.isActive == true;
    final priceText = property.transactionType?.toLowerCase() == 'vente'
        ? '${NumberFormat('#,###').format(property.price?.toInt() ?? 0)}\$'
        : '${NumberFormat('#,###').format(property.price?.toInt() ?? 0)}\$/mois';

    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: Offset(0, 6),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: _primaryColor.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => _viewProperty(property),
          splashColor: _primaryColor.withOpacity(0.1),
          highlightColor: _primaryColor.withOpacity(0.05),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image avec badge de statut
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                    child: Stack(
                      children: [
                        imageUrl != null
                            ? CachedNetworkImage(
                                imageUrl: imageUrl,
                                width: double.infinity,
                                height: 180,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  height: 180,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        _greyLight,
                                        _greyLight.withOpacity(0.8),
                                      ],
                                    ),
                                  ),
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
                                    ),
                                  ),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  height: 180,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        _greyLight,
                                        _greyLight.withOpacity(0.8),
                                      ],
                                    ),
                                  ),
                                  child: Icon(Icons.home_rounded, size: 40, color: _greyColor),
                                ),
                              )
                            : Container(
                                height: 180,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      _greyLight,
                                      _greyLight.withOpacity(0.8),
                                    ],
                                  ),
                                ),
                                child: Icon(Icons.home_rounded, size: 40, color: _greyColor),
                              ),
                        // Gradient overlay
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withOpacity(0.1),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isActive
                              ? [_successColor, _successColor.withOpacity(0.8)]
                              : [_dangerColor, _dangerColor.withOpacity(0.8)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: (isActive ? _successColor : _dangerColor).withOpacity(0.4),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                          SizedBox(width: 6),
                          Text(
                            isActive ? 'Active' : 'Inactive',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (property.viewCount != null && property.viewCount! > 0)
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.visibility_rounded, color: Colors.white, size: 16),
                            SizedBox(width: 6),
                            Text(
                              '${property.viewCount}',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),

              // Contenu
              Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      property.title ?? 'Sans titre',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _darkColor,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.location_on_rounded, size: 16, color: _greyColor),
                        SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            property.address ?? 'Adresse non spécifiée',
                            style: TextStyle(
                              fontSize: 13,
                              color: _greyColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          priceText,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: _primaryColor,
                          ),
                        ),
                        Row(
                          children: [
                            if (property.bedrooms != null && property.bedrooms! > 0) ...[
                              _buildFeatureChip('${property.bedrooms}', Icons.bed_rounded),
                              SizedBox(width: 8),
                            ],
                            if (property.bathroom != null && property.bathroom! > 0) ...[
                              _buildFeatureChip('${property.bathroom}', Icons.bathroom_rounded),
                              SizedBox(width: 8),
                            ],
                            if (property.surface != null && property.surface! > 0)
                              _buildFeatureChip(
                                '${property.surface!.toStringAsFixed(0)}m²',
                                Icons.square_foot_rounded,
                              ),
                          ],
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 44,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [_primaryColor, _accentColor],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: _primaryColor.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => _editProperty(property),
                                borderRadius: BorderRadius.circular(12),
                                child: Center(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.edit_rounded, color: Colors.white, size: 18),
                                      SizedBox(width: 6),
                                      Text(
                                        'Modifier',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            height: 44,
                            decoration: BoxDecoration(
                              color: _dangerColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: _dangerColor, width: 1.5),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => _deleteProperty(property),
                                borderRadius: BorderRadius.circular(12),
                                child: Center(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.delete_rounded, color: _dangerColor, size: 18),
                                      SizedBox(width: 6),
                                      Text(
                                        'Supprimer',
                                        style: TextStyle(
                                          color: _dangerColor,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
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
        ),
      ),
    );
  }

  Widget _buildFeatureChip(String label, IconData icon) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: _primaryColor),
          SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: _primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRefreshHeader(RefreshStatus mode) {
    Widget content;

    switch (mode) {
      case RefreshStatus.idle:
        content = _buildHeaderItem(
          icon: Icons.arrow_downward_rounded,
          text: "Tirer pour rafraîchir",
          color: _greyColor,
        );
        break;
      case RefreshStatus.canRefresh:
        content = _buildHeaderItem(
          icon: Icons.arrow_upward_rounded,
          text: "Relâcher pour rafraîchir",
          color: _primaryColor,
        );
        break;
      case RefreshStatus.refreshing:
        content = _buildRefreshInProgress();
        break;
      case RefreshStatus.completed:
        content = _buildHeaderItem(
          icon: Icons.check_circle_rounded,
          text: "Rafraîchissement terminé",
          color: _successColor,
        );
        break;
      case RefreshStatus.failed:
        content = _buildHeaderItem(
          icon: Icons.error_outline_rounded,
          text: "Échec du rafraîchissement",
          color: _dangerColor,
        );
        break;
      default:
        content = Container();
    }

    return Container(
      height: 80,
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Center(child: content),
    );
  }

  Widget _buildHeaderItem({required IconData icon, required String text, required Color color}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        SizedBox(height: 8),
        Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildRefreshInProgress() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _primaryColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
            ),
          ),
        ),
        SizedBox(height: 8),
        Text(
          "Mise à jour...",
          style: TextStyle(
            color: _primaryColor,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.home_work_outlined,
                size: 64,
                color: _primaryColor,
              ),
            ),
            SizedBox(height: 24),
            Text(
              'Aucune propriété',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: _darkColor,
                letterSpacing: -0.5,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Commencez par créer votre première annonce\net partagez vos biens immobiliers',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: _greyColor,
                height: 1.5,
              ),
            ),
            SizedBox(height: 32),
            Container(
              height: 50,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_primaryColor, _accentColor],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: _primaryColor.withOpacity(0.4),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _handleCreateProperty,
                  borderRadius: BorderRadius.circular(16),
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_rounded, color: Colors.white, size: 24),
                        SizedBox(width: 8),
                        Text(
                          'Créer une annonce',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

