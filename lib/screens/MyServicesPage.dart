import 'package:casa/controllers/CotationController.dart';
import 'package:casa/controllers/ServiceController.dart';
import 'package:casa/models/PrestationModel.dart';
import 'package:casa/models/UserModel.dart';
import 'package:casa/models/ServiceModel.dart';
import 'package:casa/models/SollicitationModel.dart';
import 'package:casa/screens/ServiceDetailPage.dart';
import 'package:casa/utils/Endpoints.dart';
import 'package:casa/utils/FancyNotification.dart';
import 'package:casa/utils/requetes.dart';
import 'package:casa/utils/crashlytics_api.dart';
import 'package:casa/utils/Routes.dart';
import 'package:casa/utils/StockageKeys.dart';
import 'package:casa/utils/decertification_access_guard.dart';
import 'package:casa/utils/offline_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:google_fonts/google_fonts.dart';
import '../controllers/AuthentificationCtrl.dart';
import '../utils/database/DatabaseHelper.dart';
import '../utils/UserInfoBottomSheet.dart';
import 'FullScreenImageViewer.dart'; // Pour le zoom image
// Détails: on reste sur ServiceDetailPage (avec cotations sollicitationId).
import 'package:casa/utils/SubscriptionHelper.dart';
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:casa/utils/export_directory.dart';
import '../utils/realtime_refresh_hub.dart';
import '../utils/french_date.dart';
import '../utils/review_eligibility.dart';
import '../utils/status_labels_fr.dart';
import '../widgets/ReviewComposerSheet.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';

class MyServicesPage extends StatefulWidget {
  /// 0 = Mes annonces, 1 = Mes demandes, 2 = Demandes reçues (ex. deep link notification).
  final int? initialTabIndex;

  const MyServicesPage({Key? key, this.initialTabIndex}) : super(key: key);

  @override
  _MyServicesPageState createState() => _MyServicesPageState();
}

class _MyServicesPageState extends State<MyServicesPage>
    with SingleTickerProviderStateMixin {
  // View mode: 0 = Mes Annonces, 1 = Mes Demandes, 2 = Demandes reçues
  int _viewMode = 0;
  bool _isLoadingData = true;
  bool _isRefreshing = false;
  final Set<int> _loadedTabs = {}; // Suivi des onglets déjà chargés via API

  late TabController _tabController;
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

  List<PrestationModel> _myPrestations = [];
  List<SollicitationModel> _mySolicitations = []; // Sent by user
  List<SollicitationModel> _hostSolicitations = []; // Received by provider
  List<int> _deletingIds = [];
  static const String _ratedCotationStorageKey =
      'cotation_rated_sollicitation_ids';
  Set<int> _ratedSolicitationIds = {};
  bool _isGridView = false;
  bool _isProcessingAction = false; // Pour les overlays de chargement
  pw.MemoryImage? _logoImage;
  StreamSubscription<String>? _realtimeRefreshSub;

  /// Compte prestataire de services (catégorie 3).
  bool _isPrestataireAccount() {
    final userAccounts = _stockage.read('user_accounts');
    if (userAccounts == null || userAccounts is! List) return false;

    for (final acc in userAccounts) {
      if (acc is! Map) continue;
      final catId = acc['categoryId'];
      if (catId != null && catId.toString() == '3') return true;
      final typeAccount = acc['typeAccount'];
      if (typeAccount is Map) {
        final nestedCat = typeAccount['categoryId'];
        if (nestedCat != null && nestedCat.toString() == '3') return true;
      }
    }
    return false;
  }

  /// Onglet initial : prestataire → Mes annonces (0), sinon → Mes demandes (1).
  int _defaultTabIndex() => _isPrestataireAccount() ? 0 : 1;

  @override
  void initState() {
    super.initState();
    _loadRatedSolicitationIds();
    _realtimeRefreshSub = RealtimeRefreshHub.instance.stream.listen((channel) {
      if (!mounted) return;
      if (channel == RealtimeRefreshHub.serviceSolicitations) {
        _loadData(forceRefresh: true);
      }
    });
    final initialTab = widget.initialTabIndex;
    final int idx;
    if (initialTab != null && initialTab >= 0 && initialTab < 3) {
      idx = initialTab;
    } else {
      idx = _defaultTabIndex();
    }
    _viewMode = idx;
    _tabController = TabController(length: 3, vsync: this, initialIndex: idx);
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
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (await DecertificationAccessGuard.redirectIfInactiveDecertified(
        context,
      )) {
        return;
      }
      if (!mounted) return;
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

  /// Plus récent en premier (date de création, sinon id).
  int _compareSolicitationsNewestFirst(
      SollicitationModel a, SollicitationModel b) {
    DateTime? da;
    DateTime? db;
    if (a.createdAt != null && a.createdAt!.isNotEmpty) {
      da = DateTime.tryParse(a.createdAt!);
    }
    if (b.createdAt != null && b.createdAt!.isNotEmpty) {
      db = DateTime.tryParse(b.createdAt!);
    }
    if (da != null && db != null && da != db) return db.compareTo(da);
    if (da != null && db == null) return -1;
    if (da == null && db != null) return 1;
    return (b.id ?? 0).compareTo(a.id ?? 0);
  }

  @override
  void dispose() {
    _realtimeRefreshSub?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  void _loadRatedSolicitationIds() {
    final raw = _stockage.read(_ratedCotationStorageKey);
    if (raw is List) {
      final next = <int>{};
      for (final e in raw) {
        final v = int.tryParse(e.toString());
        if (v != null && v > 0) next.add(v);
      }
      _ratedSolicitationIds = next;
    }
  }

  int? _currentUserIdFromStorage() {
    final raw = _stockage.read(StockageKeys.userKey);
    if (raw is Map) {
      return UserModel.fromJson(Map<String, dynamic>.from(raw)).userId;
    }
    return null;
  }

  /// Onglet « Mes demandes » : avis seulement après acceptation et date de fin passée.
  bool _canShowCotationButton(SollicitationModel item) {
    if (_viewMode != 1) return false;
    _loadRatedSolicitationIds();
    return solicitationCanBeReviewed(
      item,
      userId: _currentUserIdFromStorage(),
      alreadyRated: _ratedSolicitationIds,
    );
  }

  Future<void> _showCotationDialog(SollicitationModel item) async {
    final me = _currentUserIdFromStorage();
    final sid = item.id;
    if (me == null || sid == null) return;
    if (!_canShowCotationButton(item)) {
      FancyNotification.show(
        context,
        'L’avis s’ouvre une fois la demande acceptée et la date de fin passée.',
        type: NotificationType.info,
      );
      return;
    }
    final ok = await showReviewComposer(
      context: context,
      userId: me,
      sollicitationId: sid,
      serviceTitle: item.prestation?.title,
    );
    if (!mounted || !ok) return;
    setState(() => _ratedSolicitationIds.add(sid));
    await _stockage.write(
      _ratedCotationStorageKey,
      _ratedSolicitationIds.toList(),
    );
    FancyNotification.show(
      context,
      'Merci pour votre avis.',
      type: NotificationType.success,
    );
    await _loadMySolicitations(forceRefresh: true);
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
      final serviceController =
          Provider.of<ServiceController>(context, listen: false);
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
        final sorted = List<SollicitationModel>.from(cachedSolicitations)
          ..sort(_compareSolicitationsNewestFirst);
        setState(() {
          _mySolicitations = sorted;
          // Si on a des données en cache et qu'on n'est pas en force refresh, on peut arrêter le shimmer
          if (!forceRefresh) _isLoadingData = false;
        });
        print(
            "📁 [MyServicesPage] ${_mySolicitations.length} sollicitations chargées depuis le cache");
      }

      // 2. Appel API
      final serviceController =
          Provider.of<ServiceController>(context, listen: false);
      final solicitations = await serviceController.fetchUserSollicitations();

      if (mounted) {
        // 3. Comparer et mettre à jour si différent
        bool hasChanges =
            forceRefresh || _mySolicitations.length != solicitations.length;
        if (!hasChanges) {
          for (int i = 0; i < solicitations.length; i++) {
            if (i >= _mySolicitations.length ||
                solicitations[i].id != _mySolicitations[i].id ||
                solicitations[i].status != _mySolicitations[i].status) {
              hasChanges = true;
              break;
            }
          }
        }

        if (hasChanges) {
          solicitations.sort(_compareSolicitationsNewestFirst);
          setState(() {
            _mySolicitations = solicitations;
          });
          // 4. Mettre à jour le cache
          await db.clearUserSolicitations();
          await db.insertMultipleUserSolicitations(solicitations);
          print(
              "💾 [MyServicesPage] Cache des sollicitations utilisateur mis à jour");
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
        final sorted = List<SollicitationModel>.from(cachedSolicitations)
          ..sort(_compareSolicitationsNewestFirst);
        setState(() {
          _hostSolicitations = sorted;
          if (!forceRefresh) _isLoadingData = false;
        });
        print(
            "📁 [MyServicesPage] ${_hostSolicitations.length} sollicitations host chargées depuis le cache");
      }

      // 2. Appel API
      final serviceController =
          Provider.of<ServiceController>(context, listen: false);
      final solicitations = await serviceController.fetchHostSollicitations();

      if (mounted) {
        // 3. Comparer et mettre à jour
        bool hasChanges =
            forceRefresh || _hostSolicitations.length != solicitations.length;
        if (!hasChanges) {
          for (int i = 0; i < solicitations.length; i++) {
            if (i >= _hostSolicitations.length ||
                solicitations[i].id != _hostSolicitations[i].id ||
                solicitations[i].status != _hostSolicitations[i].status) {
              hasChanges = true;
              break;
            }
          }
        }

        if (hasChanges) {
          solicitations.sort(_compareSolicitationsNewestFirst);
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
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
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
      final serviceController =
          Provider.of<ServiceController>(context, listen: false);
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
          reportApiFailureToCrashlytics(
            'MyServicesPage',
            response: response,
            reason: 'delete_prestation',
          );
          FancyNotification.show(
            context,
            response.errorMsg ??
                "La suppression du service n’a pas abouti. Réessayez.",
            isError: true,
          );
        }
      }
    } catch (e, st) {
      reportApiFailureToCrashlytics(
        'MyServicesPage',
        error: e,
        stackTrace: st,
        reason: 'delete_prestation_exception',
      );
      if (mounted) {
        FancyNotification.show(
          context,
          "La suppression a été interrompue. Vérifiez la connexion et réessayez.",
          isError: true,
        );
      }
    } finally {
      if (mounted && prestation.id != null) {
        setState(() {
          _deletingIds.remove(prestation.id!);
        });
      }
    }
  }

  Future<void> _togglePrestationActive(PrestationModel prestation) async {
    final id = prestation.id;
    if (id == null) return;
    final me = _currentUserIdFromStorage();
    if (me == null || prestation.userId != me) return;

    final nextActive = !(prestation.isActive == true);

    setState(() {
      final idx = _myPrestations.indexWhere((p) => p.id == id);
      if (idx != -1) _myPrestations[idx].isActive = nextActive;
    });

    try {
      final serviceCtrl = context.read<ServiceController>();
      final resp = await serviceCtrl.updatePrestationPut(id, {
        // API migration: disponibilité via `status`
        // (on garde aussi les anciens champs en fallback si backend mixte).
        'status': nextActive,
        'active': nextActive,
        'isActive': nextActive,
      });

      if (resp.status == true) {
        FancyNotification.show(
          context,
          nextActive ? "Service rendu disponible" : "Service rendu indisponible",
          type: NotificationType.success,
        );
      } else {
        setState(() {
          final idx = _myPrestations.indexWhere((p) => p.id == id);
          if (idx != -1) _myPrestations[idx].isActive = !nextActive;
        });
        FancyNotification.show(
          context,
          resp.errorMsg ?? "Impossible de changer le statut. Réessayez.",
          isError: true,
        );
      }
    } catch (_) {
      setState(() {
        final idx = _myPrestations.indexWhere((p) => p.id == id);
        if (idx != -1) _myPrestations[idx].isActive = !nextActive;
      });
      FancyNotification.show(
        context,
        "Erreur réseau. Réessayez.",
        isError: true,
      );
    }
  }

  bool _isOwnerPrestation(PrestationModel p) {
    final me = _currentUserIdFromStorage();
    if (me == null) return false;
    return p.userId != null && p.userId == me;
  }

  void _navigateToCreateService() {
    SubscriptionHelper.checkLoggedInThenProceed(
      context: context,
      onProceed: () {
        Navigator.pushNamed(context, Routes.createServicePostRoute)
            .then((_) => _loadData());
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _lightGrey,
      appBar: _buildAppBar(),
      body: _buildBody(),
    );
  }

  double get _safeBottom => MediaQuery.viewPaddingOf(context).bottom;

  EdgeInsets get _listPadding =>
      EdgeInsets.fromLTRB(16, 12, 16, 24 + _safeBottom);

  Widget _buildBody() {
    final titles = ['Mes annonces', 'Mes demandes', 'Demandes reçues'];
    final hints = [
      'Services que vous proposez',
      'Demandes que vous avez envoyées',
      'Demandes arrivées sur vos services',
    ];
    final icons = [
      Icons.home_repair_service_rounded,
      Icons.send_rounded,
      Icons.move_to_inbox_rounded,
    ];
    final counts = [
      _myPrestations.length,
      _mySolicitations.length,
      _hostSolicitations.length,
    ];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _primaryColor.withOpacity(0.12)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _primaryColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icons[_viewMode], color: _primaryColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titles[_viewMode],
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: _darkColor,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hints[_viewMode],
                        style: TextStyle(
                          color: _mediumGrey,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _primaryColor.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${counts[_viewMode]}',
                    style: TextStyle(
                      color: _primaryColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildPrestationList(_myPrestations),
              _buildSolicitationList(_mySolicitations),
              _buildSolicitationList(_hostSolicitations),
            ],
          ),
        ),
      ],
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      iconTheme: IconThemeData(color: Colors.white),
      elevation: 0,
      backgroundColor: Colors.transparent,
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
        dividerColor: Colors.transparent,
        isScrollable: true,
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
          Tab(text: 'Demandes Reçues'),
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
                onPressed:
                    _isRefreshing ? null : () => _loadData(forceRefresh: true),
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
              padding: _listPadding,
              itemCount: prestations.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
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
        padding: _listPadding,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) => _buildSolicitationCard(items[index]),
      ),
    );
  }

  Widget _buildShimmerEffect() {
    return ListView.separated(
      padding: _listPadding,
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
    return Padding(
      padding: EdgeInsets.only(bottom: _safeBottom),
      child: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.work_outline,
              size: 60, color: _mediumGrey.withOpacity(0.3)),
          SizedBox(height: 20),
          Text('Aucun service publié',
              style: TextStyle(
                  color: _mediumGrey,
                  fontSize: 18,
                  fontWeight: FontWeight.w600)),
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
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildEmptyStateSolicitation() {
    return Padding(
      padding: EdgeInsets.only(bottom: _safeBottom),
      child: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment_outlined,
              size: 60, color: _mediumGrey.withOpacity(0.3)),
          SizedBox(height: 20),
          Text('Aucune demande trouvée',
              style: TextStyle(
                  color: _mediumGrey,
                  fontSize: 18,
                  fontWeight: FontWeight.w600)),
        ],
      ),
      ),
    );
  }

  Widget _buildGridView(List<PrestationModel> prestations) {
    return GridView.builder(
      padding: _listPadding,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.68,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: prestations.length,
      itemBuilder: (context, index) {
        final prestation = prestations[index];
        return _buildPrestationCard(prestation, isGrid: true);
      },
    );
  }

  Widget _coverImage(String? url, {double? size, bool topRounded = false}) {
    final clean = url?.trim() ?? '';
    final image = clean.isNotEmpty
        ? OfflineNetworkImage(
            imageUrl: clean,
            width: size ?? double.infinity,
            height: size ?? double.infinity,
            fit: BoxFit.cover,
            placeholder: (context, imageUrl) => Container(
              color: const Color(0xFFE8EEF4),
              child: const Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
            errorWidget: (context, imageUrl, error) => Container(
              color: const Color(0xFFE8EEF4),
              child: Icon(Icons.home_repair_service_rounded, color: _mediumGrey),
            ),
          )
        : Container(
            color: const Color(0xFFE8EEF4),
            child: Icon(Icons.home_repair_service_rounded, color: _mediumGrey, size: 28),
          );
    if (size != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(width: size, height: size, child: image),
      );
    }
    return ClipRRect(
      borderRadius: topRounded
          ? const BorderRadius.vertical(top: Radius.circular(20))
          : BorderRadius.zero,
      child: SizedBox.expand(child: image),
    );
  }

  Widget _availabilityChip(PrestationModel prestation) {
    final active = prestation.isActive == true;
    return InkWell(
      onTap: () => _togglePrestationActive(prestation),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFE8F8F3) : const Color(0xFFF1F3F6),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          active ? 'Disponible' : 'Indisponible',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: active ? const Color(0xFF047857) : _mediumGrey,
          ),
        ),
      ),
    );
  }

  Widget _buildPrestationCard(PrestationModel prestation,
      {required bool isGrid}) {
    final isDeleting =
        prestation.id != null && _deletingIds.contains(prestation.id);
    final imageUrl = prestation.profile ??
        (prestation.images != null && prestation.images!.isNotEmpty
            ? prestation.images!.first
            : null);
    final title = (prestation.title ?? '').trim().isEmpty
        ? 'Sans titre'
        : prestation.title!.trim();
    final city = (prestation.cityValue ?? '').trim();
    final hasPrice = (prestation.minPrice ?? 0) > 0;
    final price = hasPrice
        ? '${NumberFormat('#,##0', 'fr_FR').format(prestation.minPrice)} ${prestation.currency}'
        : '';
    final isOwner = _isOwnerPrestation(prestation);

    void openDetail() {
      if (isDeleting || prestation.id == null) return;
      final serviceController =
          Provider.of<ServiceController>(context, listen: false);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ServiceDetailPage(
            service: prestation,
            serviceTypeName:
                serviceController.getServiceName(prestation.serviceId),
          ),
        ),
      );
    }

    return Opacity(
      opacity: isDeleting ? 0.5 : 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: openDetail,
            child: isGrid
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _coverImage(imageUrl, topRounded: true)),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: _darkColor,
                                height: 1.2,
                              ),
                            ),
                            if (price.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                price,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: _primaryColor,
                                ),
                              ),
                            ],
                            if (isOwner) ...[
                              const SizedBox(height: 6),
                              _availabilityChip(prestation),
                            ],
                          ],
                        ),
                      ),
                    ],
                  )
                : Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _coverImage(imageUrl, size: 92),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: _darkColor,
                                  height: 1.25,
                                ),
                              ),
                              if (city.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  city,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _mediumGrey,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      price.isEmpty ? 'Prix sur demande' : price,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: price.isEmpty
                                            ? _mediumGrey
                                            : _primaryColor,
                                      ),
                                    ),
                                  ),
                                  if (isOwner) _availabilityChip(prestation),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildSolicitationCard(SollicitationModel item) {
    final currency = item.deviseId == 1 ? 'FC' : '\$';
    final canCancel = _viewMode == 1 &&
        (item.status?.toUpperCase() == 'PENDING') &&
        item.id != null;
    final statusColor = _getStatusColor(item.status);
    final statusText =
        statusColor == _warningColor ? const Color(0xFFB45309) : statusColor;
    final statusKey = item.status?.toUpperCase().trim();
    final isCancelled = statusKey == 'CANCELLED' || statusKey == 'CANCELED';
    final isValidated = statusKey == 'APPROVED' ||
        statusKey == 'ACCEPTED' ||
        statusKey == 'CONFIRMED';
    final markByBorder = _viewMode == 1 && (isCancelled || isValidated);
    final cardBorder = !markByBorder
        ? BorderSide.none
        : BorderSide(
            color: isCancelled ? _errorColor : _successColor,
            width: 1.6,
          );
    final created = formatFrenchDateTime(item.createdAt);
    final period = formatFrenchStay(item.startDate, item.endDate);
    final prestation = item.prestation;
    final imageUrl = prestation?.profile ??
        ((prestation?.images != null && prestation!.images!.isNotEmpty)
            ? prestation.images!.first
            : null);
    final title = (prestation?.title ?? '').trim().isEmpty
        ? 'Service'
        : prestation!.title!.trim();
    final city = (prestation?.cityValue ?? '').trim();
    final budgetLabel = item.budget == null
        ? ''
        : '${NumberFormat('#,##0', 'fr_FR').format(item.budget)} $currency';
    final description = (item.description ?? '').trim();
    final requester = _viewMode == 2 ? item.user : null;
    final requesterName = requester == null ? '' : requester.displayFullName;
    final photo = (item.requesterPhoto ?? '').trim();

    void open() {
      if (_viewMode == 2) {
        _showSolicitationActionBottomSheet(item);
        return;
      }
      if (prestation == null) return;
      final serviceController =
          Provider.of<ServiceController>(context, listen: false);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ServiceDetailPage(
            service: prestation,
            serviceTypeName:
                serviceController.getServiceName(prestation.serviceId),
            sollicitationId: item.id,
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: cardBorder,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: open,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (!markByBorder)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          frSolicitationStatus(item.status),
                          style: TextStyle(
                            color: statusText,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    const Spacer(),
                    if (created != '—')
                      Text(
                        created,
                        style: TextStyle(
                          color: _mediumGrey,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _coverImage(imageUrl, size: 72),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: _darkColor,
                              height: 1.25,
                            ),
                          ),
                          if (city.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              city,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: _mediumGrey,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          if (period != '—') ...[
                            const SizedBox(height: 6),
                            Text(
                              period,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: _darkColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                if (requester != null) ...[
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () => UserInfoBottomSheet.show(context, requester),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: _primaryColor.withOpacity(0.12),
                            backgroundImage: photo.isNotEmpty
                                ? OfflineImageProvider(photo)
                                : null,
                            child: photo.isEmpty
                                ? Icon(Icons.person_rounded,
                                    size: 16, color: _primaryColor)
                                : null,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              requesterName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _darkColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                if (budgetLabel.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    budgetLabel,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: _primaryColor,
                    ),
                  ),
                ],
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: Color(0xFF4B5563),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                const Divider(height: 1, color: Color(0xFFEEF2F6)),
                Wrap(
                  spacing: 2,
                  runSpacing: 0,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _cardAction(
                      icon: Icons.share_rounded,
                      label: 'Partager',
                      onTap: () => _shareSolicitationPdf(item),
                    ),
                    _cardAction(
                      icon: Icons.download_rounded,
                      label: 'PDF',
                      onTap: () => _downloadSolicitationPdf(item),
                    ),
                    if (_canShowCotationButton(item))
                      _cardAction(
                        icon: Icons.star_rounded,
                        label: 'Avis',
                        onTap: () => _showCotationDialog(item),
                      ),
                    if (canCancel)
                      _cardAction(
                        icon: Icons.close_rounded,
                        label: 'Annuler',
                        color: _errorColor,
                        onTap: _isProcessingAction
                            ? null
                            : () => _confirmCancelUserSolicitation(item),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }


  Widget _cardAction({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    Color? color,
  }) {
    final tint = color ?? _primaryColor;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: tint),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: tint,
              ),
            ),
          ],
        ),
      ),
    );
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
    final photo = (item.requesterPhoto ?? '').trim();

    return Container(
      padding: EdgeInsets.fromLTRB(
          24, 12, 24, 24 + MediaQuery.viewPaddingOf(context).bottom),
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
              decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          SizedBox(height: 24),
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: _primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle),
                child: Icon(Icons.assignment_ind_rounded,
                    color: _primaryColor, size: 28),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Détail de la demande",
                        style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: _darkColor)),
                    Text("Gérer la sollicitation reçue",
                        style: TextStyle(color: _mediumGrey, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 24),
          if (item.user != null) ...[
            Text("Demandeur",
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: _darkColor)),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: _lightGrey,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () {
                      if (photo.isNotEmpty) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => FullScreenImageViewer(
                                imagePath: photo),
                          ),
                        );
                      }
                    },
                    child: CircleAvatar(
                      radius: 24,
                      backgroundColor: _primaryColor.withOpacity(0.2),
                      backgroundImage: photo.isNotEmpty
                          ? OfflineImageProvider(photo)
                          : null,
                      child: photo.isEmpty
                          ? Icon(Icons.person, color: _primaryColor)
                          : null,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.user!.username ?? "Utilisateur",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: _darkColor)),
                        SizedBox(height: 4),
                        // Téléphone
                        if (item.user!.phone != null &&
                            item.user!.phone!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Row(
                              children: [
                                Icon(Icons.phone_iphone_rounded,
                                    size: 14, color: _mediumGrey),
                                SizedBox(width: 4),
                                Text(item.user!.phone!,
                                    style: TextStyle(
                                        color: _darkColor, fontSize: 13)),
                              ],
                            ),
                          ),
                        // Email (si disponible)
                        if (item.user!.email != null &&
                            item.user!.email!.isNotEmpty &&
                            item.user!.email != 'null')
                          Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Row(
                              children: [
                                Icon(Icons.email_outlined,
                                    size: 14, color: _mediumGrey),
                                SizedBox(width: 4),
                                Expanded(
                                    child: Text(item.user!.email!,
                                        style: TextStyle(
                                            color: _darkColor, fontSize: 13),
                                        overflow: TextOverflow.ellipsis)),
                              ],
                            ),
                          ),
                        // Localisation (si disponible)
                        if (item.user!.formattedLocation.isNotEmpty)
                          Row(
                            children: [
                              Icon(Icons.location_on_outlined,
                                  size: 14, color: _mediumGrey),
                              SizedBox(width: 4),
                              Expanded(
                                  child: Text(item.user!.formattedLocation,
                                      style: TextStyle(
                                          color: _darkColor, fontSize: 13),
                                      overflow: TextOverflow.ellipsis)),
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
          Text("Service concerné",
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: _darkColor)),
          SizedBox(height: 8),
          InkWell(
            onTap: () {
              Navigator.pop(context); // Fermer le bottom sheet
              if (item.prestation != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) =>
                          ServiceDetailPage(service: item.prestation!)),
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
            Text(
                "Budget proposé: ${NumberFormat('#,###').format(item.budget)} $currency",
                style: TextStyle(
                    color: _successColor, fontWeight: FontWeight.bold)),
          ],
          if (item.description != null && item.description!.isNotEmpty) ...[
            SizedBox(height: 16),
            Text("Description",
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: _mediumGrey)),
            SizedBox(height: 4),
            Text(item.description!,
                style: TextStyle(color: _darkColor, height: 1.4)),
          ],
          SizedBox(height: 32),
          if (isPending) ...[
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () =>
                        _handleSolicitationAction(item, 'CANCELLED'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _errorColor.withOpacity(0.1),
                      foregroundColor: _errorColor,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side:
                              BorderSide(color: _errorColor.withOpacity(0.2))),
                    ),
                    child: Text("REFUSER",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () =>
                        _handleSolicitationAction(item, 'APPROVED'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _successColor,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      elevation: 4,
                      shadowColor: _successColor.withOpacity(0.4),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text("VALIDER",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                  ),
                ),
              ],
            ),
          ] else ...[
            Center(
              child: Text(
                "Statut actuel : ${frSolicitationStatus(item.status)}",
                style: TextStyle(
                    color: _getStatusColor(item.status),
                    fontWeight: FontWeight.bold),
              ),
            ),
          ],
          SizedBox(height: 12),
        ],
      ),
    );
  }

  /// `null` si la personne ferme la feuille. Chaîne vide si elle confirme sans motif.
  Future<String?> _askOptionalCancelReason({
    required String title,
    required String message,
    required String confirmText,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _OptionalCancelReasonSheet(
        title: title,
        message: message,
        confirmText: confirmText,
      ),
    );
  }

  Future<void> _confirmCancelUserSolicitation(SollicitationModel item) async {
    final reason = await _askOptionalCancelReason(
      title: 'Annuler la demande',
      message:
          'Vous pouvez indiquer pourquoi vous annulez. Ce motif est optionnel.',
      confirmText: 'ANNULER LA DEMANDE',
    );
    if (reason == null || !mounted) return;
    await _processUserSolicitationCancel(item, reason);
  }

  Future<bool> _processUserSolicitationCancel(
      SollicitationModel item, String reason) async {
    if (item.id == null) return false;
    setState(() => _isProcessingAction = true);
    try {
      final serviceCtrl =
          Provider.of<ServiceController>(context, listen: false);
      final response = await serviceCtrl.updateSollicitationStatus(
        item.id!,
        'CANCELLED',
        reason: reason,
      );
      if (response.status == true) {
        await _loadMySolicitations(forceRefresh: true);
        if (mounted) {
          FancyNotification.show(
            context,
            'Demande annulée',
            type: NotificationType.success,
          );
        }
        return true;
      } else {
        if (mounted) {
          reportApiFailureToCrashlytics(
            'MyServicesPage',
            response: response,
            reason: 'user_cancel_sollicitation',
          );
          FancyNotification.show(
            context,
            response.errorMsg ??
                "L’annulation n’a pas abouti. Réessayez dans un instant.",
            isError: true,
          );
        }
        return false;
      }
    } catch (e, st) {
      reportApiFailureToCrashlytics(
        'MyServicesPage',
        error: e,
        stackTrace: st,
        reason: 'user_cancel_sollicitation_exception',
      );
      if (mounted) {
        FancyNotification.show(
          context,
          "L’annulation n’a pas pu être enregistrée. Réessayez.",
          isError: true,
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _isProcessingAction = false);
    }
  }

  Future<void> _handleSolicitationAction(
      SollicitationModel item, String status) async {
    Navigator.pop(context); // Fermer le BottomSheet

    final bool isAccept =
        status == 'APPROVED' || status.toUpperCase() == 'ACCEPTED';

    if (!isAccept) {
      final reason = await _askOptionalCancelReason(
        title: 'Refuser la demande',
        message:
            'Vous pouvez indiquer pourquoi vous refusez. Ce motif est optionnel.',
        confirmText: 'REFUSER',
      );
      if (reason == null || !mounted) return;
      await _processSolicitationStatusUpdate(
        item,
        status,
        isAccept,
        reason: reason,
      );
      return;
    }

    // Pour l'acceptation, on lance directement
    await _processSolicitationStatusUpdate(item, status, isAccept);
  }

  Future<bool> _processSolicitationStatusUpdate(
    SollicitationModel item,
    String status,
    bool isAccept, {
    String? reason,
  }) async {
    setState(() => _isProcessingAction = true);

    try {
      final serviceCtrl =
          Provider.of<ServiceController>(context, listen: false);
      final response = await serviceCtrl.updateSollicitationStatus(
        item.id!,
        status,
        reason: reason,
      );

      if (response.status == true) {
        await _loadHostSolicitations(forceRefresh: true);

        if (mounted && isAccept) {
          _showActionSuccessDialog(item);
        } else if (mounted) {
          FancyNotification.show(
            context,
            "La demande a été refusée.",
            type: NotificationType.success,
          );
        }
        return true;
      } else {
        if (mounted) {
          reportApiFailureToCrashlytics(
            'MyServicesPage',
            response: response,
            reason: 'host_sollicitation_status_$status',
          );
          FancyNotification.show(
            context,
            response.errorMsg ?? "La mise à jour n’a pas abouti. Réessayez.",
            isError: true,
          );
        }
        return false;
      }
    } catch (e, st) {
      reportApiFailureToCrashlytics(
        'MyServicesPage',
        error: e,
        stackTrace: st,
        reason: 'host_sollicitation_status_exception',
      );
      if (mounted) {
        FancyNotification.show(
          context,
          "L’action n’a pas pu être enregistrée. Vérifiez la connexion et réessayez.",
          isError: true,
        );
      }
      return false;
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
                decoration: BoxDecoration(
                    color: _successColor.withOpacity(0.1),
                    shape: BoxShape.circle),
                child: Icon(Icons.check_circle_rounded,
                    color: _successColor, size: 60),
              ),
              SizedBox(height: 24),
              Text("Félicitations !",
                  style: GoogleFonts.inter(
                      fontSize: 22, fontWeight: FontWeight.bold)),
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
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
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
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text("FERMER",
                    style: TextStyle(
                        color: _mediumGrey, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- PDF Logic for Services ---

  // --- PDF Logic for Services (Premium Redesign) ---

  String _cleanContact(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty || text.toLowerCase() == 'null') return '';
    return text;
  }

  void _fillProviderFromAccount(PrestationModel prestation) {
    final me = _currentUserIdFromStorage();
    if (me == null || prestation.userId != me) return;

    Map<String, dynamic>? asMap(dynamic value) {
      if (value is Map) return Map<String, dynamic>.from(value);
      return null;
    }

    final user = asMap(_stockage.read(StockageKeys.userKey));
    final nested = asMap(user?['user']) ?? user;
    final profile = asMap(_stockage.read(StockageKeys.profileKey));
    String? text(dynamic value) => _cleanContact(value?.toString()).isEmpty
        ? null
        : _cleanContact(value?.toString());

    if (_cleanContact(prestation.postBy).isEmpty) {
      prestation.postBy = text(profile?['fullName']) ??
          text(profile?['fullname']) ??
          text(nested?['fullName']) ??
          text(nested?['username']);
    }
    if (_cleanContact(prestation.phone).isEmpty) {
      prestation.phone = text(nested?['phone']) ??
          text(profile?['phone']) ??
          text(profile?['telephone']);
    }
    if (_cleanContact(prestation.email).isEmpty) {
      prestation.email = text(nested?['email']) ?? text(profile?['email']);
    }
  }

  Future<void> _completeProviderForDocument(SollicitationModel item) async {
    final prestation = item.prestation;
    if (prestation == null) return;

    for (final known in _myPrestations) {
      if (known.id != null && known.id == prestation.id) {
        prestation.mergePublisherFrom(known);
      }
    }
    _fillProviderFromAccount(prestation);

    final hasName = _cleanContact(prestation.postBy).isNotEmpty ||
        _cleanContact(prestation.username).isNotEmpty;
    final hasPhone = _cleanContact(prestation.phone).isNotEmpty ||
        _cleanContact(item.postByTel).isNotEmpty;
    final hasEmail = _cleanContact(prestation.email).isNotEmpty;
    if (hasName && (hasPhone || hasEmail)) return;

    final id = prestation.id ?? item.prestationId;
    if (id == null) return;
    final token = _stockage.read(StockageKeys.tokenKey)?.toString();
    final urls = <String>[
      '${Endpoints.publicPrestations}/$id',
      '${Endpoints.prestations}/$id',
    ];
    for (final url in urls) {
      final raw = await getData(
        url,
        token: url.contains('/public/') ? '' : token,
      );
      if (raw is! Map) continue;
      final envelope = Map<String, dynamic>.from(raw);
      final data = envelope['data'] is Map
          ? Map<String, dynamic>.from(envelope['data'] as Map)
          : envelope;
      final node = data['prestation'] is Map
          ? Map<String, dynamic>.from(data['prestation'] as Map)
          : data;
      final fetched = PrestationModel.fromJson(node);
      fetched.absorbPublisher(data);
      fetched.absorbPublisher(envelope);
      prestation.mergePublisherFrom(fetched);
      final ready = _cleanContact(prestation.postBy).isNotEmpty &&
          (_cleanContact(prestation.phone).isNotEmpty ||
              _cleanContact(prestation.email).isNotEmpty);
      if (ready) return;
    }
  }

  Future<Uint8List> _buildSolicitationPdfBytes(SollicitationModel item) async {
    await _completeProviderForDocument(item);
    final doc = pw.Document();

    pw.Font? ttf;
    try {
      final fontData =
          await rootBundle.load('assets/fonts/Outfit-SemiBold.ttf');
      ttf = pw.Font.ttf(fontData);
    } catch (_) {}

    final now = DateFormat('dd/MM/yy HH:mm', 'fr_FR').format(DateTime.now());
    final prestation = item.prestation;
    final String currency = (item.deviseId == 1) ? "FC" : "\$";

    String clean(String? value) {
      final text = value?.trim() ?? '';
      if (text.isEmpty || text.toLowerCase() == 'null') return '';
      return text;
    }

    final providerName = clean(prestation?.postBy).isNotEmpty
        ? clean(prestation?.postBy)
        : (clean(prestation?.username).isNotEmpty
            ? clean(prestation?.username)
            : (prestation?.user == null ? '' : prestation!.user!.displayFullName));
    final providerPhone = clean(item.postByTel).isNotEmpty
        ? clean(item.postByTel)
        : (clean(prestation?.phone).isNotEmpty
            ? clean(prestation?.phone)
            : clean(prestation?.user?.phone));
    final providerEmail = clean(prestation?.email).isNotEmpty
        ? clean(prestation?.email)
        : clean(prestation?.user?.email);
    final street = clean(prestation?.address);
    final place = [
      clean(prestation?.quartierValue),
      clean(prestation?.communeValue),
      clean(prestation?.cityValue),
      clean(prestation?.countryValue),
    ].where((part) => part.isNotEmpty && !street.toLowerCase().contains(part.toLowerCase())).join(', ');
    final availability = [
      clean(prestation?.plageJourPrestation),
      clean(prestation?.plageHeurePrestation),
    ].where((part) => part.isNotEmpty).join(' · ');
    final tariff = () {
      String fmt(double? amount) {
        if (amount == null || amount <= 0) return '';
        return '${NumberFormat('#,##0', 'fr_FR').format(amount)} ${prestation?.currency ?? currency}';
      }

      final min = fmt(prestation?.minPrice);
      final max = fmt(prestation?.maxPrice);
      if (min.isEmpty && max.isEmpty) return '';
      if (max.isEmpty || min == max) return min.isEmpty ? '' : 'À partir de $min';
      if (min.isEmpty) return 'Jusqu’à $max';
      return 'De $min à $max';
    }();
    final clientName = item.user == null ? '' : item.user!.displayFullName;
    final budgetLabel = item.budget == null
        ? ''
        : '${NumberFormat('#,##0.##', 'fr_FR').format(item.budget)} $currency';

    pw.Widget _buildDetailRow(String label, String value) {
      final text = value.trim().isEmpty ? 'Non renseigné' : value.trim();
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 3),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
              width: 132,
              child: pw.Text(label,
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
            ),
            pw.Expanded(child: pw.Text(text, style: const pw.TextStyle(fontSize: 10))),
          ],
        ),
      );
    }

    doc.addPage(
      pw.MultiPage(
        theme: ttf != null ? pw.ThemeData.withFont(base: ttf, bold: ttf) : null,
        margin: const pw.EdgeInsets.all(32),
        build: (ctx) => [
            // --- HEADER PREMIUM ---
            pw.Container(
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#1976D2'),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'SOLLICITATION DE SERVICE',
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        'Identifiant : #SOL-${item.id}',
                        style: pw.TextStyle(
                          color: PdfColor.fromInt(0xE6FFFFFF),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  if (_logoImage != null)
                    pw.Container(
                      width: 45,
                      height: 45,
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.white,
                        shape: pw.BoxShape.circle,
                      ),
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Image(_logoImage!),
                    ),
                ],
              ),
            ),

            pw.SizedBox(height: 24),

            // --- STATUT ET DATE ---
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Document Officiel CasaNayo',
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold, fontSize: 10)),
                    pw.Text('Généré le $now',
                        style: pw.TextStyle(
                            fontSize: 9, color: PdfColors.grey700)),
                  ],
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey400),
                    borderRadius:
                        const pw.BorderRadius.all(pw.Radius.circular(4)),
                  ),
                  child: pw.Text(frSolicitationStatus(item.status),
                      style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromHex('#1976D2'))),
                ),
              ],
            ),

            pw.SizedBox(height: 24),
            pw.Divider(color: PdfColors.grey300),
            pw.SizedBox(height: 16),

            // --- SECTION 1: PRESTATAIRE & SERVICE ---
            pw.Text('1. DÉTAILS DU SERVICE & PRESTATAIRE',
                style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromHex('#1976D2'))),
            pw.SizedBox(height: 12),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius:
                      const pw.BorderRadius.all(pw.Radius.circular(4))),
              child: pw.Column(
                children: [
                  _buildDetailRow('Service sollicité',
                      prestation?.title ?? 'Service CasaNayo'),
                  _buildDetailRow('Prestataire', providerName),
                  if (providerPhone.isNotEmpty)
                    _buildDetailRow('Téléphone', providerPhone)
                  else
                    _buildDetailRow('E-mail', providerEmail),
                  _buildDetailRow('Adresse', street),
                  _buildDetailRow('Lieu', place),
                  if (tariff.isNotEmpty) _buildDetailRow('Tarif annoncé', tariff),
                  if (availability.isNotEmpty)
                    _buildDetailRow('Disponibilité', availability),
                ],
              ),
            ),

            pw.SizedBox(height: 24),

            // --- SECTION 2: CLIENT ---
            pw.Text('2. DÉTAILS DU DEMANDEUR (CLIENT)',
                style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromHex('#1976D2'))),
            pw.SizedBox(height: 12),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius:
                      const pw.BorderRadius.all(pw.Radius.circular(4))),
              child: pw.Column(
                children: [
                  _buildDetailRow('Nom', clientName),
                  _buildDetailRow('Téléphone', clean(item.user?.phone)),
                  _buildDetailRow('E-mail', clean(item.user?.email)),
                ],
              ),
            ),

            pw.SizedBox(height: 24),

            // --- SECTION 3: OBJET ET BUDGET ---
            pw.Text('3. OBJET ET PÉRIODE DE LA DEMANDE',
                style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromHex('#1976D2'))),
            pw.SizedBox(height: 12),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey200),
                  borderRadius:
                      const pw.BorderRadius.all(pw.Radius.circular(4))),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _buildDetailRow('Début', formatFrenchShortDate(item.startDate)),
                  _buildDetailRow('Fin', formatFrenchShortDate(item.endDate)),
                  _buildDetailRow('Budget proposé', budgetLabel),
                  _buildDetailRow('Statut', frSolicitationStatus(item.status)),
                  _buildDetailRow(
                    'Envoyée le',
                    item.createdAt == null || item.createdAt!.trim().isEmpty
                        ? ''
                        : formatFrenchShortDate(item.createdAt),
                  ),
                  if (item.description != null &&
                      item.description!.isNotEmpty) ...[
                    pw.SizedBox(height: 8),
                    pw.Divider(color: PdfColors.grey200),
                    pw.SizedBox(height: 8),
                    pw.Text('Description',
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold, fontSize: 10)),
                    pw.SizedBox(height: 4),
                    pw.Text(item.description!,
                        style: const pw.TextStyle(fontSize: 10)),
                  ],
                ],
              ),
            ),

            pw.SizedBox(height: 20),

            // --- FOOTER ---
            pw.Divider(color: PdfColors.grey400),
            pw.SizedBox(height: 8),
            pw.Text(
              "IMPORTANT : Ce document est une preuve de sollicitation de service via CasaNayo. Il ne constitue pas un contrat final tant qu'il n'est pas validé par l'acceptation formelle du prestataire. Pour toute assistance : +243 836 323 805.",
              style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
              textAlign: pw.TextAlign.justify,
            ),
            pw.SizedBox(height: 12),
            pw.Text('Document généré par CasaNayo - www.casanayo.com',
                style: const pw.TextStyle(fontSize: 8)),
          ],
      ),
    );
    return doc.save();
  }

  Future<void> _shareSolicitationPdf(SollicitationModel item) async {
    try {
      final bytes = await _buildSolicitationPdfBytes(item);
      final generationDate =
          DateFormat('dd_MMMM_yyyy_HH_mm', 'fr_FR').format(DateTime.now());
      final fileName =
          'Sollicitation_Service_Ref_${item.id}_du_$generationDate.pdf';

      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/$fileName');
      await tempFile.writeAsBytes(bytes);

      final xfile =
          XFile(tempFile.path, mimeType: 'application/pdf', name: fileName);
      await Share.shareXFiles([xfile],
          text: "Sollicitation de service CasaNayo - Ref: ${item.id}");
    } catch (e) {
      FancyNotification.show(context, "Impossible de partager le PDF");
    }
  }

  Future<void> _downloadSolicitationPdf(SollicitationModel item) async {
    try {
      final dir = await pickExportDirectoryOrNull();
      if (dir == null) {
        if (mounted) {
          FancyNotification.show(
            context,
            "Enregistrement annulé : aucun dossier sélectionné.",
            type: NotificationType.info,
          );
        }
        return;
      }

      final bytes = await _buildSolicitationPdfBytes(item);

      final generationDate =
          DateFormat('dd_MMMM_yyyy_HH_mm', 'fr_FR').format(DateTime.now());
      final fileName =
          'Sollicitation_Service_Ref_${item.id}_du_$generationDate.pdf';
      final file = File('${dir.path}/$fileName');

      await file.writeAsBytes(bytes);
      if (!mounted) return;
      FancyNotification.show(
        context,
        "PDF enregistré dans : ${describePickedDirectoryPathForUser(dir.path)}",
        type: NotificationType.success,
      );
    } catch (e) {
      FancyNotification.show(
        context,
        "Le PDF n’a pas pu être enregistré. Vérifiez l’espace disque et réessayez.",
        isError: true,
      );
    }
  }

  Color _getStatusColor(String? status) {
    switch (status?.toUpperCase()) {
      case 'APPROVED':
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

}

class _OptionalCancelReasonSheet extends StatefulWidget {
  final String title;
  final String message;
  final String confirmText;

  const _OptionalCancelReasonSheet({
    required this.title,
    required this.message,
    required this.confirmText,
  });

  @override
  State<_OptionalCancelReasonSheet> createState() =>
      _OptionalCancelReasonSheetState();
}

class _OptionalCancelReasonSheetState extends State<_OptionalCancelReasonSheet> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        padding: EdgeInsets.fromLTRB(
          24,
          22,
          24,
          24 + MediaQuery.viewPaddingOf(context).bottom,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              widget.title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.message,
              style: const TextStyle(
                color: Color(0xFF5D4037),
                fontSize: 13,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Motif (optionnel)',
              style: TextStyle(
                color: Color(0xFF666666),
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _controller,
              maxLines: 3,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Ex: dates plus disponibles, empêchement…',
                hintStyle: const TextStyle(
                  color: Color(0xFFAAAAAA),
                  fontSize: 14,
                ),
                fillColor: const Color(0xFFF5F5F5),
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, _controller.text.trim()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD32F2F),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  widget.confirmText,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'RETOUR',
                  style: TextStyle(
                    color: Color(0xFF666666),
                    fontWeight: FontWeight.w700,
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
