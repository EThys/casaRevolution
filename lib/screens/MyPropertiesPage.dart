import 'package:casa/controllers/PropertyCtrl.dart';
import 'package:casa/models/PropertyModel.dart';
import 'package:casa/screens/HotelDetailPage.dart';
import 'package:casa/screens/PropertyDetailPage.dart';
import 'package:casa/utils/FancyNotification.dart';
import 'package:casa/utils/crashlytics_api.dart';
import 'package:casa/utils/Routes.dart';
import 'package:casa/utils/SubscriptionHelper.dart';
import 'package:casa/utils/StockageKeys.dart';
import 'package:casa/utils/decertification_access_guard.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:google_fonts/google_fonts.dart';
import '../controllers/AuthentificationCtrl.dart';

class MyPropertiesPage extends StatefulWidget {
  /// Gérant → entrée « Mes salles » : uniquement salles festives (8) et funéraires (7).
  final bool onlyFestiveAndFuneraire;

  const MyPropertiesPage({super.key, this.onlyFestiveAndFuneraire = false});

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
  bool _isGridView = false; // Toggle pour vue liste/grille

  // Optimisation: éviter de refaire le même enrichissement d’images plusieurs fois.
  final Map<int, PropertyModel> _imageEnrichCacheById = {};
  final Map<int, Future<PropertyModel>> _imageEnrichInFlightById = {};

  int? _currentUserIdFromStorage() {
    final raw = _stockage.read(StockageKeys.userKey);
    if (raw is Map) {
      final dynamic uid = raw['user']?['userId'] ?? raw['userId'];
      if (uid is int) return uid;
      if (uid is String) return int.tryParse(uid);
      return int.tryParse(uid?.toString() ?? '');
    }
    return null;
  }

  bool _isOwner(PropertyModel p) {
    final me = _currentUserIdFromStorage();
    if (me == null) return false;
    final uid = p.userId ?? p.user?.userId;
    return uid != null && uid == me;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (await DecertificationAccessGuard.redirectIfInactiveDecertified(
            context,
          )) {
        return;
      }
      if (!mounted) return;
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
          // Les hôtels sont gérés dans l’espace "Mes hôtels & chambres" (gérant).
          var list =
              properties.where((p) => (p.propertyTypeId ?? 0) != 5).toList();
          if (widget.onlyFestiveAndFuneraire) {
            const festiveId = 8;
            const funeraireId = 7;
            list = list
                .where((p) {
                  final id = p.propertyTypeId ?? 0;
                  return id == festiveId || id == funeraireId;
                })
                .toList();
          }
          _myProperties = list;
          _isLoadingData = false;
          _isRefreshing = false;
        });
      }

      // Enrichissement images depuis le cache local (sans spinner / non bloquant).
      _enrichMyPropertiesFromCache();
    } catch (e) {
      print("❌ Erreur lors du chargement des propriétés: $e");
      if (mounted) {
        setState(() {
          _isLoadingData = false;
          _isRefreshing = false;
        });
        FancyNotification.show(
          context,
          "Vos annonces n’ont pas pu être chargées. Tirez pour rafraîchir ou réessayez plus tard.",
          isError: true,
        );
      }
    }
  }

  Future<void> _enrichMyPropertiesFromCache() async {
    if (!mounted) return;
    final propertyCtrl = context.read<PropertyController>();

    bool changed = false;
    const batchSize = 4;
    const priorityCount = 10;
    final candidates = <int>[];
    for (var i = 0; i < _myProperties.length; i++) {
      if (_myProperties[i].propertyImage?.isNotEmpty == true) continue;
      candidates.add(i);
    }

    Future<bool> enrichAt(int idx) async {
      final p = _myProperties[idx];
      final id = p.propertyId;
      if (id == null) return false;

      final cached = _imageEnrichCacheById[id];
      if (cached != null && cached.propertyImage?.isNotEmpty == true) {
        _myProperties[idx] = cached;
        return true;
      }

      final inFlight = _imageEnrichInFlightById[id];
      if (inFlight != null) {
        try {
          final enriched = await inFlight;
          if (enriched.propertyImage?.isNotEmpty == true) {
            _imageEnrichCacheById[id] = enriched;
            _myProperties[idx] = enriched;
            return true;
          }
        } catch (_) {}
        return false;
      }

      final fut = propertyCtrl.enrichPropertySnapshot(p);
      _imageEnrichInFlightById[id] = fut;
      try {
        final enriched = await fut;
        _imageEnrichInFlightById.remove(id);
        if (enriched.propertyImage?.isNotEmpty == true) {
          _imageEnrichCacheById[id] = enriched;
          _myProperties[idx] = enriched;
          return true;
        }
      } catch (_) {
        _imageEnrichInFlightById.remove(id);
      }
      return false;
    }

    // 1) Priorité: premiers éléments visibles.
    final priority = candidates.take(priorityCount).toList();
    for (var i = 0; i < priority.length; i += batchSize) {
      if (!mounted) return;
      final batchIndexes = priority.skip(i).take(batchSize).toList();

      final futures = batchIndexes.map((idx) async {
        return enrichAt(idx);
      }).toList();

      final results = await Future.wait(futures);
      if (results.any((r) => r)) changed = true;
      await Future<void>.delayed(Duration.zero);
    }

    // 2) Reste de la liste (arrière-plan).
    final rest = candidates.skip(priorityCount).toList();
    for (var i = 0; i < rest.length; i += batchSize) {
      if (!mounted) return;
      final batchIndexes = rest.skip(i).take(batchSize).toList();
      final futures = batchIndexes.map((idx) async => enrichAt(idx)).toList();
      final results = await Future.wait(futures);
      if (results.any((r) => r)) changed = true;
      await Future<void>.delayed(Duration.zero);
    }

    if (changed && mounted) setState(() {});
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
          reportApiFailureToCrashlytics(
            'MyPropertiesPage',
            response: response,
            reason: 'delete_property',
          );
          FancyNotification.show(
            context,
            response.errorMsg ??
                "La suppression n’a pas abouti. Réessayez dans un moment.",
            isError: true,
          );
        }
      }
    } catch (e, st) {
      reportApiFailureToCrashlytics(
        'MyPropertiesPage',
        error: e,
        stackTrace: st,
        reason: 'delete_property_exception',
      );
      if (mounted) {
        FancyNotification.show(
          context,
          "La suppression a été interrompue. Vérifiez la connexion et réessayez.",
          isError: true,
        );
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
    Navigator.pushNamed(
      context,
      Routes.editPropertyRoute,
      arguments: property,
    ).then((success) {
      if (success == true) {
        _loadMyProperties(); // Recharger la liste après modification
      }
    });
  }

  Future<void> _togglePropertyAvailability(PropertyModel property) async {
    final pid = property.propertyId;
    final tid = property.propertyTypeId;
    if (pid == null || tid == null) return;
    if (!_isOwner(property)) return;

    // Dans l’UI : Disponible = sold != true ; Indisponible = sold == true
    final nextSold = !(property.sold == true);
    final label = (property.title ?? 'Annonce').trim().isEmpty ? 'Annonce' : (property.title ?? 'Annonce').trim();

    setState(() {
      // Optimistic UI: on bascule immédiatement
      final idx = _myProperties.indexWhere((p) => p.propertyId == pid);
      if (idx != -1) {
        _myProperties[idx].sold = nextSold;
      }
    });

    try {
      final ctrl = context.read<PropertyController>();
      final resp = await ctrl.syncPropertySoldFlag(pid, tid, sold: nextSold);
      if (resp.status == true) {
        FancyNotification.show(
          context,
          nextSold
              ? "« $label » est maintenant indisponible."
              : "« $label » est maintenant disponible.",
          type: NotificationType.success,
        );
        // Recharger la liste pour refléter l'état serveur (et les autres champs éventuels).
        if (mounted) {
          await _loadMyProperties();
        }
      } else {
        // rollback
        setState(() {
          final idx = _myProperties.indexWhere((p) => p.propertyId == pid);
          if (idx != -1) _myProperties[idx].sold = !nextSold;
        });
        FancyNotification.show(
          context,
          "Impossible de changer la disponibilité pour « $label ». Réessayez.",
          isError: true,
        );
      }
    } catch (e) {
      // rollback
      setState(() {
        final idx = _myProperties.indexWhere((p) => p.propertyId == pid);
        if (idx != -1) _myProperties[idx].sold = !nextSold;
      });
      FancyNotification.show(
        context,
        "Connexion instable. Réessayez dans un instant.",
        isError: true,
      );
    }
  }

  void _viewProperty(PropertyModel property) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => property.propertyTypeId == 5
            ? HotelDetailPage(property: property)
            : PropertyDetailPage(property: property),
      ),
    );
  }

  void _handleCreateProperty() {
    var token = _stockage.read(StockageKeys.tokenKey);
    if (token == null) {
      FancyNotification.show(
        context,
        "Vous devez être connecté pour publier une annonce",
        type: NotificationType.info,
      );
      return;
    }

    SubscriptionHelper.checkLoggedInThenProceed(
      context: context,
      onProceed: () {
        Navigator.pushNamed(context, Routes.createPropertyRoute)
            .then((_) => _loadMyProperties());
      },
    );
  }

  /// Filtre « Mes annonces » basé sur [sold] (référence métier), pas sur isActive.
  List<PropertyModel> get _disponibleProperties =>
      _myProperties.where((p) => p.sold != true).toList();
  List<PropertyModel> get _indisponibleProperties =>
      _myProperties.where((p) => p.sold == true).toList();

  List<PropertyModel> _filterProperties(String filter) {
    switch (filter) {
      case 'disponible':
        return _disponibleProperties;
      case 'indisponible':
        return _indisponibleProperties;
      case 'all':
      default:
        return _myProperties;
    }
  }

  /// Afficher « /mois » seulement pour locations « classiques » (pas séjours / salles / hôtel / terrain).
  bool _showMonthlyPriceSuffix(PropertyModel p) {
    final tid = p.propertyTypeId ?? 0;
    if (tid == 5 || tid == 6 || tid == 7 || tid == 8 || tid == 9) return false;
    final tt = p.transactionType?.toLowerCase() ?? '';
    return tt.contains('location');
  }

  Widget _buildStatusBadge(PropertyModel property, {bool isGrid = false}) {
    // Mes annonces : uniquement `sold` (+ type transaction). Pas isAvailable / isActive.
    final tt = property.transactionType?.toLowerCase() ?? '';
    final isRent = tt.contains('location');

    final Color bgColor;
    final Color fgColor;
    final String text;

    if (property.sold == true) {
      if (isRent) {
        bgColor = const Color(0xFFFFEBEE);
        fgColor = const Color(0xFFC62828);
        text = 'Plus disponible';
      } else {
        bgColor = const Color(0xFFFFEBEE);
        fgColor = const Color(0xFFC62828);
        text = 'Vendu';
      }
    } else {
      bgColor = const Color(0xFFE8F5E9);
      fgColor = const Color(0xFF2E7D32);
      text = 'Disponible';
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: isGrid ? 8 : 12, vertical: isGrid ? 4 : 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(isGrid ? 12 : 20),
        border: Border.all(color: fgColor.withOpacity(0.22)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: fgColor,
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
                _buildPropertyList(_filterProperties('all')),
                _buildPropertyList(_filterProperties('disponible')),
                _buildPropertyList(_filterProperties('indisponible')),
              ],
            ),
          ),
        ],
      ),
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
        // Toggle vue liste/grille
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
    final disponibleCount = _filterProperties('disponible').length;
    final indisponibleCount = _filterProperties('indisponible').length;

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
              Tab(text: 'Disponible ($disponibleCount)'),
              Tab(text: 'Indisponible ($indisponibleCount)'),
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
      "Aucune annonce encore disponible (non vendue / non retirée).",
      "Aucune annonce indisponible ou vendue."
    ];

    final emptyIcons = [
      Icons.home_work_outlined,
      Icons.check_circle_outline,
      Icons.remove_circle_outline
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
      child: _isGridView
          ? _buildPropertyGridContent(properties)
          : ListView.separated(
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

  Widget _buildPropertyGridContent(List<PropertyModel> properties) {
    return GridView.builder(
      padding: EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.75, // Ajusté pour éviter l'overflow
      ),
      itemCount: properties.length,
      itemBuilder: (context, index) {
        final property = properties[index];
        return AnimatedSwitcher(
          duration: Duration(milliseconds: 300),
          child: _buildPropertyGridCard(property),
        );
      },
    );
  }

  Widget _buildPropertyGridCard(PropertyModel property) {
    final isForRent =
        property.transactionType?.toLowerCase().contains('location') ?? false;
    final isDeleting = _deletingIds.contains(property.propertyId);

    final firstImage = property.propertyImage?.isNotEmpty ?? false
        ? property.propertyImage!.first
        : null;
    final imageUrl = firstImage?.path;

    final priceText = isForRent && _showMonthlyPriceSuffix(property)
        ? '${NumberFormat('#,###').format(property.price?.toInt() ?? 0)} ${property.currency}/mois'
        : '${NumberFormat('#,###').format(property.price?.toInt() ?? 0)} ${property.currency}';

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _viewProperty(property),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: _cardBackground,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              spreadRadius: 1,
              offset: Offset(0, 4),
            )
          ],
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image
                Expanded(
                  flex: 3,
                  child: Stack(
                    children: [
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                          color: _lightGrey,
                        ),
                        child: imageUrl != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                                child: CachedNetworkImage(
                                  imageUrl: imageUrl,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: double.infinity,
                                  placeholder: (context, url) => Container(
                                    color: _lightGrey,
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: _primaryColor,
                                      ),
                                    ),
                                  ),
                                  errorWidget: (context, url, error) => Container(
                                    color: _lightGrey,
                                    child: Icon(Icons.home, size: 30, color: _mediumGrey),
                                  ),
                                ),
                              )
                            : Container(
                                color: _lightGrey,
                                child: Icon(Icons.home, size: 30, color: _mediumGrey),
                              ),
                      ),
                        Positioned(
                          bottom: 8,
                          left: 8,
                          child: _buildStatusBadge(property, isGrid: true),
                        ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            priceText,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Contenu
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          property.title ?? 'Propriété',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: _darkColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.location_on_rounded, size: 12, color: _mediumGrey),
                            SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                property.listingPlace,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: _mediumGrey,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 4),
                        Row(
                          children: [
                            if (property.bedrooms != null && property.bedrooms! > 0) ...[
                              Icon(Icons.bed_rounded, size: 12, color: _mediumGrey),
                              SizedBox(width: 4),
                              Text(
                                '${property.bedrooms}',
                                style: TextStyle(fontSize: 11, color: _mediumGrey),
                              ),
                              SizedBox(width: 8),
                            ],
                            if (property.bathroom != null && property.bathroom! > 0) ...[
                              Icon(Icons.bathtub_rounded, size: 12, color: _mediumGrey),
                              SizedBox(width: 4),
                              Text(
                                '${property.bathroom}',
                                style: TextStyle(fontSize: 11, color: _mediumGrey),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (isDeleting)
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.black.withOpacity(0.5),
                ),
                child: Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPropertyCard(PropertyModel property) {
    final isForRent =
        property.transactionType?.toLowerCase().contains('location') ?? false;
    final isDeleting = _deletingIds.contains(property.propertyId);

    final firstImage = property.propertyImage?.isNotEmpty ?? false
        ? property.propertyImage!.first
        : null;
    final imageUrl = firstImage?.path;

    final priceText = isForRent && _showMonthlyPriceSuffix(property)
        ? '${NumberFormat('#,###').format(property.price?.toInt() ?? 0)} ${property.currency}/mois'
        : '${NumberFormat('#,###').format(property.price?.toInt() ?? 0)} ${property.currency}';

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
                      child: _buildStatusBadge(property, isGrid: false),
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
                              property.listingPlace,
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
                      if (property.rejectionReason != null && property.rejectionReason!.isNotEmpty)
                        Container(
                          margin: EdgeInsets.only(bottom: 15),
                          padding: EdgeInsets.all(10),
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: _errorColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _errorColor.withOpacity(0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "⚠️ Refusé pour le motif suivant :",
                                style: TextStyle(
                                  color: _errorColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                property.rejectionReason!,
                                style: TextStyle(
                                  color: _darkColor,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      Divider(height: 1, color: _lightGrey),
                      SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: _isOwner(property)
                                  ? () => _togglePropertyAvailability(property)
                                  : null,
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
                                      (property.sold == true)
                                          ? Icons.toggle_on_rounded
                                          : Icons.toggle_off_rounded,
                                      size: 16,
                                      color: _primaryColor,
                                    ),
                                    SizedBox(width: 5),
                                    Text(
                                      (property.sold == true)
                                          ? 'Rendre disponible'
                                          : 'Rendre indisponible',
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
    final typeName = property.propertyType?.name?.toLowerCase() ?? '';
    final tid = property.propertyTypeId ?? property.propertyType?.propertyTypeId ?? 0;
    final isHotel = tid == 5 || typeName.contains('hotel') || typeName.contains('hôtel');
    final isTerrain = tid == 9 || typeName.contains('terrain');
    final isFestive = tid == 8 || typeName.contains('fête') || typeName.contains('fete');
    final isFuneraire = tid == 7 || typeName.contains('funéra') || typeName.contains('funera');
    final isBureau = tid == 4 || typeName.contains('bureau') || typeName.contains('office');

    if (isTerrain) {
      if (property.surface != null && property.surface! > 0) {
        features.add(_buildFeatureChip('${property.surface!.toStringAsFixed(0)}m²'));
      }
      return features;
    }

    if (isHotel) {
      features.add(_buildFeatureChip('Hôtel'));
      if (property.surface != null && property.surface! > 0) {
        features.add(_buildFeatureChip('${property.surface!.toStringAsFixed(0)}m²'));
      }
      return features;
    }

    if (isFestive || isFuneraire) {
      if (property.capacityPeople != null && property.capacityPeople! > 0) {
        features.add(_buildFeatureChip('${property.capacityPeople} pers.'));
      }
      if (property.surface != null && property.surface! > 0) {
        features.add(_buildFeatureChip('${property.surface!.toStringAsFixed(0)}m²'));
      }
      return features;
    }

    if (isBureau) {
      if (property.roomMeet != null && property.roomMeet! > 0) {
        features.add(_buildFeatureChip('${property.roomMeet} réunions'));
      }
      features.add(_buildFeatureChip(property.isEquip == true ? 'Équipé' : 'Non équipé'));
      if (property.surface != null && property.surface! > 0) {
        features.add(_buildFeatureChip('${property.surface!.toStringAsFixed(0)}m²'));
      }
      return features;
    }

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
