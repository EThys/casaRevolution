import 'package:cached_network_image/cached_network_image.dart';
import 'package:casa/models/ReservationModel.dart';
import 'package:open_file/open_file.dart';
import 'package:casa/utils/property_detail_navigation.dart';
import 'package:casa/utils/FancyNotification.dart';
import 'package:casa/utils/crashlytics_api.dart';
import 'package:casa/utils/requetes.dart' show HttpResponse;
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:get_storage/get_storage.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import '../controllers/ReservationController.dart';
import '../controllers/PropertyCtrl.dart';
import '../controllers/TypeAccountController.dart';
import '../models/PropertyModel.dart';
import '../utils/Endpoints.dart';
import '../utils/networkCheck.dart';
import '../utils/database/DatabaseHelper.dart';
import '../utils/FavoriteEartIcon.dart';
import '../utils/UserInfoBottomSheet.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/ModernModal.dart';
import 'package:casa/utils/export_directory.dart';
import '../utils/realtime_refresh_hub.dart';
import '../utils/status_labels_fr.dart';
import '../utils/reservation_pdf_bytes.dart';
import '../utils/decertification_access_guard.dart';

class BookingHistoryPage extends StatefulWidget {
  /// Si `true` (ex. notification « réservation reçue » côté hôte), ouvre l’onglet **Réservations reçues**.
  final bool initialHostView;
  /// Index initial du TabBar (0=En attente, 1=Confirmées, 2=Annulées).
  final int? initialTabIndex;

  const BookingHistoryPage({
    Key? key,
    this.initialHostView = false,
    this.initialTabIndex,
  }) : super(key: key);

  @override
  _BookingHistoryPageState createState() => _BookingHistoryPageState();
}

class _BookingHistoryPageState extends State<BookingHistoryPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoadingData = true;
  bool _isRefreshing = false;
  final Set<int> _loadedTabs = {}; // Suivi des onglets/vues chargés via API
  final DateFormat _dateFormat = DateFormat('dd MMM yyyy', 'fr_FR');
  final GetStorage _storage = GetStorage();
  bool _isLoading = false;
  List<String> _cancellingIds = [];
  bool _isGridView = true;

  // Host Logic
  bool _isHostView = false;
  bool _isHost = false;
  List<ReservationModel> _hostReservations = [];

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

  // Statistiques
  Map<String, int> _reservationCounts = {};
  pw.MemoryImage? _logoImage;
  StreamSubscription<String>? _realtimeRefreshSub;

  // Optimisation: éviter de refaire le même enrichissement d’images plusieurs fois.
  final Map<int, PropertyModel> _imageEnrichCacheById = {};
  final Map<int, Future<PropertyModel>> _imageEnrichInFlightById = {};

  @override
  void initState() {
    super.initState();
    // Déterminer le rôle à partir du cache local AVANT d'initialiser la vue par défaut.
    final isHostFromCache = _computeHostFromCachedAccounts();
    _isHost = isHostFromCache;
    // UX: si l'utilisateur est bailleur/commissionnaire/gérant (host), ouvrir "Réservations reçues" par défaut.
    _isHostView = widget.initialHostView || isHostFromCache;
    _checkUserRole(); // Vérification/normalisation (peut affiner via TypeAccountController)
    final initialIndex = (widget.initialTabIndex ?? 0).clamp(0, 2);
    _tabController = TabController(length: 3, vsync: this, initialIndex: initialIndex);
    _loadLogo();
    _realtimeRefreshSub = RealtimeRefreshHub.instance.stream.listen((channel) {
      if (!mounted) return;
      if (channel == RealtimeRefreshHub.reservations) {
        _loadReservations();
        _loadReservationCounts();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (await DecertificationAccessGuard.redirectIfInactiveDecertified(
            context,
          )) {
        return;
      }
      if (!mounted) return;
      _loadReservations();
      _loadReservationCounts();
    });
  }

  void _checkUserRole() {
    final userAccounts = _storage.read('user_accounts');
    if (userAccounts != null && userAccounts is List) {
      // Vérification initiale basée sur les données stockées
      bool foundHost = userAccounts.any((acc) {
         // Vérifier si categoryId == 2 (Owner)
         final catId = acc['categoryId']; 
         if (catId != null && catId.toString() == '2') return true;
         
         final typeAccount = acc['typeAccount'];
         if (typeAccount != null && typeAccount is Map) {
            final nestedCat = typeAccount['categoryId'];
             if (nestedCat != null && nestedCat.toString() == '2') return true;
         }
         return false;
      });

      if (foundHost) {
        if (mounted) setState(() => _isHost = true);
      } else {
        // Vérification via le TypeAccountController pour être sûr
        WidgetsBinding.instance.addPostFrameCallback((_) {
            try {
              final typeCtrl = Provider.of<TypeAccountController>(context, listen: false);
              // On s'assure que les types sont chargés
              if (typeCtrl.ownerTypes.isEmpty) {
                 typeCtrl.fetchTypeAccounts().then((_) {
                    _verifyHostWithController(userAccounts, typeCtrl);
                 });
              } else {
                 _verifyHostWithController(userAccounts, typeCtrl);
              }
            } catch(e) {
              print("Erreur check role controller: $e");
            }
        });
      }
    }
  }

  bool _computeHostFromCachedAccounts() {
    final userAccounts = _storage.read('user_accounts');
    if (userAccounts == null || userAccounts is! List) return false;
    return userAccounts.any((acc) {
      if (acc is! Map) return false;
      final catId = acc['categoryId'];
      if (catId != null && catId.toString() == '2') return true;
      final typeAccount = acc['typeAccount'];
      if (typeAccount != null && typeAccount is Map) {
        final nestedCat = typeAccount['categoryId'];
        if (nestedCat != null && nestedCat.toString() == '2') return true;
      }
      return false;
    });
  }

  void _verifyHostWithController(List userAccounts, TypeAccountController typeCtrl) {
      final ownerTypeIds = typeCtrl.ownerTypes.map((e) {
         // Gérer Map ou Model
         if (e is Map) return (e['typeAccountId'] ?? e['TypeAccountId'] ?? e['id']).toString();
         return e.typeAccountId.toString();
      }).toList();
      
      final hasOwnerAccount = userAccounts.any((acc) {
          final id = (acc['typeAccount']?['typeAccountId'] ?? (acc['typeAccountId'] ?? acc['TypeAccountId']))?.toString();
          return ownerTypeIds.contains(id);
      });
      
      if (hasOwnerAccount != _isHost) {
          setState(() {
            _isHost = hasOwnerAccount;
          });
          // Si on devient host et qu'on a déjà chargé, on recharge pour avoir les données host
          // (évite un cache « reçues » vide si [initialHostView] était true avant détection du rôle)
          if (_isHost) _loadReservations(forceRefresh: true);
      }
  }

  Future<void> _loadLogo() async {
    try {
      final data = await rootBundle.load('assets/images/logoCasa.png');
      setState(() {
        _logoImage = pw.MemoryImage(data.buffer.asUint8List());
      });
    } catch (_) {
      // ignore logo load failure
    }
  }

  // Shimmer effect amélioré
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

  /// Données chargées via [ReservationController] (GET sous `api/v1/protected/reservations/...`, voir [Endpoints.reservationsProtected] et variantes *ByUser / *ByHost).
  Future<void> _loadReservations({bool forceRefresh = false}) async {
    try {
      if (!mounted) return;
      if (kDebugMode && forceRefresh) {
        debugPrint(
          '[BookingHistory] sync réservations (endpoints protected): ${Endpoints.reservationsProtected}/…',
        );
      }

      final currentViewIndex = _isHostView ? 1 : 0;
      if (_loadedTabs.contains(currentViewIndex) && !forceRefresh) {
        return;
      }

      // 1. Charger le cache (aperçu rapide)
      final db = DatabaseHelper.instance;
      final cachedUserReservations = await db.getAllUserReservations();
      final cachedHostReservations = await db.getAllHostReservations();

      final reservationCtrl = Provider.of<ReservationController>(context, listen: false);

      if (mounted) {
        setState(() {
          if (cachedUserReservations.isNotEmpty) {
            reservationCtrl.reservations = cachedUserReservations;
          }
          if (cachedHostReservations.isNotEmpty) {
            _hostReservations = cachedHostReservations;
          }
          
          // Si on a des données, on peut déjà arrêter le shimmer si ce n'est pas un premier chargement ou force refresh
          if (!forceRefresh && (cachedUserReservations.isNotEmpty || cachedHostReservations.isNotEmpty)) {
            _isLoadingData = false;
          }
        });
      }

      // Enrichissement images depuis le cache local (sans bloquer l’UI).
      _enrichReservationPropertiesFromCache(reservationCtrl.reservations);
      _enrichReservationPropertiesFromCache(_hostReservations);

      setState(() {
        _isRefreshing = true;
        if (forceRefresh) _isLoadingData = true;
      });

      // 2. Appel API en parallèle
      if (_isHost) {
        await Future.wait([
          reservationCtrl.getMyReservations(),
          _loadHostReservations(reservationCtrl),
        ]);
      } else {
        await reservationCtrl.getMyReservations();
      }

      // 3. Mettre à jour le cache et notifier si changement
      if (mounted) {
        await db.clearUserReservations();
        await db.insertMultipleUserReservations(reservationCtrl.reservations);

        await db.clearHostReservations();
        await db.insertMultipleHostReservations(_hostReservations);

        print("💾 [BookingHistoryPage] Cache des réservations mis à jour");
      }

      print("📊 Réservations synchronisées: ${reservationCtrl.reservations.length} (Host: ${_hostReservations.length})");

      // Après sync, enrichir encore depuis cache (si des snapshots locaux existent déjà).
      _enrichReservationPropertiesFromCache(reservationCtrl.reservations);
      _enrichReservationPropertiesFromCache(_hostReservations);

      await _loadReservationCounts();
    } catch (e) {
      print("❌ Erreur lors du chargement des réservations: $e");
      if (mounted) {
        FancyNotification.show(
          context,
          "Les réservations n’ont pas pu être chargées. Tirez pour rafraîchir ou réessayez plus tard.",
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingData = false;
          _isRefreshing = false;
          _loadedTabs.add(_isHostView ? 1 : 0);
        });
      }
    }
  }

  Future<void> _enrichReservationPropertiesFromCache(List<ReservationModel> list) async {
    if (!mounted) return;
    final propertyCtrl = context.read<PropertyController>();

    bool changed = false;

    // Limiter la charge: traiter par lots en parallèle (max 4).
    const batchSize = 4;
    const priorityCount = 10;
    final candidates = list
        .where((r) => r.property != null)
        .where((r) => r.property!.propertyImage?.isNotEmpty != true)
        .toList();

    Future<bool> enrichOne(ReservationModel r) async {
      final p = r.property;
      if (p == null) return false;
      final id = p.propertyId;
      if (id == null) return false;

      final cached = _imageEnrichCacheById[id];
      if (cached != null && cached.propertyImage?.isNotEmpty == true) {
        r.property = cached;
        return true;
      }

      final inFlight = _imageEnrichInFlightById[id];
      if (inFlight != null) {
        try {
          final enriched = await inFlight;
          if (enriched.propertyImage?.isNotEmpty == true) {
            _imageEnrichCacheById[id] = enriched;
            r.property = enriched;
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
          r.property = enriched;
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
      final batch = priority.skip(i).take(batchSize).toList();

      final futures = batch.map((r) async {
        return enrichOne(r);
      }).toList();

      final results = await Future.wait(futures);
      if (results.any((r) => r)) changed = true;
      await Future<void>.delayed(Duration.zero);
    }

    // 2) Reste de la liste (arrière-plan).
    final rest = candidates.skip(priorityCount).toList();
    for (var i = 0; i < rest.length; i += batchSize) {
      if (!mounted) return;
      final batch = rest.skip(i).take(batchSize).toList();
      final futures = batch.map((r) async => enrichOne(r)).toList();
      final results = await Future.wait(futures);
      if (results.any((r) => r)) changed = true;
      await Future<void>.delayed(Duration.zero);
    }

    if (changed && mounted) setState(() {});
  }

  Future<void> _loadReservationCounts() async {
    try {
      final reservationCtrl = Provider.of<ReservationController>(context, listen: false);
      final counts = await reservationCtrl.getMyReservationCounts();

      if (mounted) {
        setState(() {
          _reservationCounts = counts;
        });
      }
    } catch (e) {
      print("❌ Erreur lors du chargement des statistiques: $e");
    }
  }

  @override
  void dispose() {
    _realtimeRefreshSub?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reservationCtrl = Provider.of<ReservationController>(context);

    final source = _isHostView ? _hostReservations : reservationCtrl.reservations;

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
                _buildReservationList(
                  _filterReservationsByStatuses(source, const {'PENDING'}),
                ),
                _buildReservationList(
                  _filterReservationsByStatuses(
                      source, const {'CONFIRMED', 'APPROVED'}),
                ),
                _buildReservationList(
                  _filterReservationsByStatuses(
                      source, const {'CANCELLED', 'CANCELED'}),
                ),
              ],
            ),
          ),
        ],
      ),
      // Bouton d'action flottant pour rafraîchir
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  // Carte de statistiques améliorée
  Widget _buildStatsCard(ReservationController reservationCtrl) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 500),
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_primaryColor.withOpacity(0.9), _secondaryColor.withOpacity(0.9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withOpacity(0.2),
            blurRadius: 15,
            spreadRadius: 2,
            offset: Offset(0, 5),
          )
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.analytics_outlined, color: Colors.white, size: 20),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Mes Réservations',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${reservationCtrl.reservations.length} total',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(_reservationCounts['pending'] ?? 0, 'En attente', _warningColor),
              _buildStatItem(_reservationCounts['confirmed'] ?? 0, 'Confirmées', _successColor),
              _buildStatItem(_reservationCounts['cancelled'] ?? 0, 'Annulées', _errorColor),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(int count, String label, Color color) {
    return Column(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3), width: 2),
          ),
          child: Center(
            child: Text(
              count.toString(),
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // Bouton d'action flottant amélioré
  Widget _buildFloatingActionButton() {
    return FloatingActionButton(
      heroTag: "booking_history_fab", // Tag unique pour éviter les conflits Hero
      onPressed: _isRefreshing ? null : () => _loadReservations(forceRefresh: true),
      backgroundColor: _primaryColor,
      foregroundColor: Colors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: AnimatedSwitcher(
        duration: Duration(milliseconds: 300),
        child: _isRefreshing
            ? SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white,
          ),
        )
            : Icon(Icons.refresh_rounded, size: 24),
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
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new, color: Colors.white),
        onPressed: () => Navigator.pop(context),
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
            child: Icon(Icons.book_online, color: Colors.white, size: 18),
          ),
          SizedBox(width: 12),
          Text(
            'Mes réservations',
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
      ],
      bottom: PreferredSize(
        preferredSize: Size.fromHeight(_isHost ? 60 : 1),
        child: Column(
          children: [
            if (_isHost) _buildViewToggle(),
            Container(
              height: 1,
              color: Colors.white.withOpacity(0.2),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilteredListView() {
      final reservationCtrl = Provider.of<ReservationController>(context);
      final List<ReservationModel> sourceList = _isHostView ? _hostReservations : reservationCtrl.reservations;
      
      return TabBarView(
        controller: _tabController,
        children: [
          _buildReservationList(
              _filterReservationsByStatuses(sourceList, const {'PENDING'})),
          _buildReservationList(_filterReservationsByStatuses(
              sourceList, const {'CONFIRMED', 'APPROVED'})),
          _buildReservationList(_filterReservationsByStatuses(
              sourceList, const {'CANCELLED', 'CANCELED'})),
        ],
      );
  }

  Widget _buildViewToggle() {
    if (!_isHost) return SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: EdgeInsets.all(4),
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: _buildToggleButton("Mes réservations", !_isHostView, () {
              if (_isHostView) {
                setState(() => _isHostView = false);
                _loadReservations();
              }
            }),
          ),
          Expanded(
             child: _buildToggleButton("Réservations reçues", _isHostView, () {
              if (!_isHostView) {
                setState(() => _isHostView = true);
                _loadReservations();
              }
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
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    // Calculer les compteurs depuis les données actuelles
    final reservationCtrl = Provider.of<ReservationController>(context, listen: false);
    // Choix de la source selon la vue
    final currentList = _isHostView ? _hostReservations : reservationCtrl.reservations;

    final pendingCount =
        _filterReservationsByStatuses(currentList, const {'PENDING'}).length;
    final confirmedCount = _filterReservationsByStatuses(
            currentList, const {'CONFIRMED', 'APPROVED'})
        .length;
    final cancelledCount = _filterReservationsByStatuses(
            currentList, const {'CANCELLED', 'CANCELED'})
        .length;

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
              Tab(
                text: 'En attente ($pendingCount)',
              ),
              Tab(
                text: 'Confirmées ($confirmedCount)',
              ),
              Tab(
                text: 'Annulées ($cancelledCount)',
              ),
            ],
          ),
          // Indicateur de chargement pour les tabs
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

  List<ReservationModel> _filterReservationsByStatuses(
    List<ReservationModel> reservations,
    Set<String> statuses,
  ) {
    final normalized = statuses.map((e) => e.toUpperCase()).toSet();
    final filtered = reservations
        .where((r) => normalized.contains((r.status ?? '').toUpperCase()))
        .toList();

    // Tri stable: date desc, puis reservationId desc (évite l'effet "jump" si date manquante)
    filtered.sort((a, b) {
      final dateA = DateTime.tryParse(a.createdAt ?? '');
      final dateB = DateTime.tryParse(b.createdAt ?? '');
      if (dateA != null && dateB != null) {
        final byDate = dateB.compareTo(dateA);
        if (byDate != 0) return byDate;
      } else if (dateA == null && dateB != null) {
        return 1;
      } else if (dateA != null && dateB == null) {
        return -1;
      }
      return (b.reservationId ?? 0).compareTo(a.reservationId ?? 0);
    });

    return filtered;
  }

  // Récupération correcte de l'URL de l'image
  String? _getImageUrl(ReservationModel reservation) {
    if (reservation.property?.propertyImage != null &&
        reservation.property!.propertyImage!.isNotEmpty) {
      final firstImage = reservation.property!.propertyImage!.first;
      if (firstImage.path != null) {
        final url = firstImage.path!;
        print("🖼️ Image URL: $url");
        return url;
      }
    }
    return null;
  }

  Widget _buildReservationList(List<ReservationModel> reservations) {
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
      child: KeyedSubtree(
        key: ValueKey('${_tabController.index}-${_isGridView}-${_isHostView}-${_isLoadingData}-${reservations.length}'),
        child: _isLoadingData
          ? _buildShimmerEffect()
          : reservations.isEmpty
          ? _buildEmptyState()
          : _buildReservationListContent(reservations),
      ),
    );
  }

  Widget _buildEmptyState() {
    final emptyMessages = [
      "Aucune réservation en attente de confirmation",
      "Aucune réservation confirmée pour le moment",
      "Aucune réservation annulée"
    ];

    final emptyIcons = [
      Icons.pending_actions,
      Icons.check_circle_outline,
      Icons.cancel_outlined
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
              'Aucune réservation',
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
            SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _loadReservations,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              icon: Icon(Icons.refresh, size: 18),
              label: Text(
                'Actualiser',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReservationListContent(List<ReservationModel> reservations) {
    return RefreshIndicator(
      color: _primaryColor,
      backgroundColor: Colors.white,
      onRefresh: () => _loadReservations(forceRefresh: true),
      child: _isGridView
          ? _buildReservationGridContent(reservations)
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.viewPaddingOf(context).bottom),
              itemCount: reservations.length,
              separatorBuilder: (_, __) => SizedBox(height: 20),
              itemBuilder: (context, index) {
                final reservation = reservations[index];
                return KeyedSubtree(
                  key: ValueKey('r-${reservation.reservationId ?? '${reservation.createdAt}-$index'}'),
                  child: _buildReservationCard(reservation),
                );
              },
            ),
    );
  }

  Widget _buildReservationGridContent(List<ReservationModel> reservations) {
    return GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.viewPaddingOf(context).bottom),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.75, // Ajusté pour éviter l'overflow
      ),
      itemCount: reservations.length,
      itemBuilder: (context, index) {
        final reservation = reservations[index];
        return KeyedSubtree(
          key: ValueKey('rg-${reservation.reservationId ?? '${reservation.createdAt}-$index'}'),
          child: _buildReservationGridCard(reservation),
        );
      },
    );
  }

  Widget _buildReservationGridCard(ReservationModel reservation) {
    final isCancelling = _cancellingIds.contains(reservation.reservationId);
    final imageUrl = _getImageUrl(reservation);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        _showReservationDetails(reservation);
      },
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
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getStatusColor(reservation.status).withOpacity(0.9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _getStatusText(reservation.status),
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${_formatDate(reservation.createdAt)?.split(' ')[0] ?? 'N/A'}',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
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
                          reservation.property?.title ?? 'Sans titre',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: _darkColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 4),
                        if (reservation.startDate != null) ...[
                          Row(
                            children: [
                              Icon(Icons.calendar_today_rounded, size: 12, color: _mediumGrey),
                              SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  _formatDate(reservation.startDate) ?? 'Date non renseignée',
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
                        ],
                        if (reservation.reservationHeure != null) ...[
                          Row(
                            children: [
                              Icon(Icons.access_time_rounded, size: 12, color: _mediumGrey),
                              SizedBox(width: 4),
                              Text(
                                reservation.reservationHeure ?? '',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: _mediumGrey,
                                ),
                              ),
                            ],
                          ),
                        ],

                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (isCancelling)
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

  Widget _buildReservationCard(ReservationModel reservation) {
    final status = reservation.status?.toUpperCase() ?? '';
    final isPending = status == 'PENDING';
    final isCancelled = status == 'CANCELLED' || status == 'CANCELED';
    final isConfirmed = status == 'CONFIRMED' || status == 'APPROVED';
    final isCompleted = status == 'COMPLETED';
    final isCancelling = _cancellingIds.contains(reservation.reservationId!.toString());
    final imageUrl = _getImageUrl(reservation);
    final cancelReason = reservation.cancellationReason?.toString().trim();
    final hasCancelReason = cancelReason != null &&
        cancelReason.isNotEmpty &&
        cancelReason.toLowerCase() != 'null';

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        _showReservationDetails(reservation);
      },
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
                          color: _getStatusColor(reservation.status).withOpacity(0.9),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _getStatusText(reservation.status),
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    if (_isHostView && reservation.user != null)
                      Positioned(
                        bottom: 15,
                        right: 15,
                        child: GestureDetector(
                          onTap: () => UserInfoBottomSheet.show(context, reservation.user!),
                          child: Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.9),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 10,
                                  offset: Offset(0, 4),
                                )
                              ],
                            ),
                            child: Icon(Icons.person_pin_rounded, color: _primaryColor, size: 24),
                          ),
                        ),
                      ),
                    Positioned(
                      top: 15,
                      right: 15,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${_formatDate(reservation.createdAt)?.split(' ')[0] ?? 'N/A'}',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          SizedBox(width: 8),
                          if (reservation.property?.propertyId != null)
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.9),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: FavoriteHeartIcon(
                                propertyId: reservation.property!.propertyId.toString(),
                                propertyTypeId: reservation.property!.propertyTypeId,
                                size: 20,
                                splashRadius: 18,
                                activeColor: Colors.red,
                                inactiveColor: _mediumGrey,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (isCancelled && hasCancelReason)
                      Positioned(
                        bottom: 15,
                        right: 15,
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 220),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.92),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: _errorColor.withOpacity(0.25)),
                          ),
                          child: Text(
                            'Motif: $cancelReason',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _errorColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
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
                        "${reservation.property?.title ?? 'Sans titre'}",
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
                              "${reservation.property?.address ?? 'Adresse non disponible'}",
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
                        children: _buildFeatureChips(reservation.property),
                      ),
                      SizedBox(height: 15),
                      Divider(height: 1, color: _lightGrey),
                      SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.calendar_today, size: 16, color: _primaryColor),
                          SizedBox(width: 6),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Du ${_formatDate(reservation.startDate) ?? 'N/A'}',
                                  style: TextStyle(
                                    color: _darkColor,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  'Au ${_formatDate(reservation.endDate) ?? 'N/A'}',
                                  style: TextStyle(
                                    color: _darkColor,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isPending)
                            if (_isHostView) 
                               Row(
                                 mainAxisSize: MainAxisSize.min,
                                 children: [
                                     InkWell(
                                      onTap: () => _handleReservationAction(reservation, 'CANCELLED', fromBottomSheet: false),
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        margin: EdgeInsets.only(right: 8),
                                        decoration: BoxDecoration(
                                          color: _errorColor.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: _errorColor.withOpacity(0.3)),
                                        ),
                                        child: Icon(Icons.close, size: 16, color: _errorColor),
                                      ),
                                    ),
                                    InkWell(
                                      onTap: () => _handleReservationAction(reservation, 'APPROVED', fromBottomSheet: false),
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: _successColor.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: _successColor.withOpacity(0.3)),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(Icons.check, size: 16, color: _successColor),
                                            SizedBox(width: 4),
                                            Text("Valider", style: TextStyle(color: _successColor, fontWeight: FontWeight.bold, fontSize: 12))
                                          ],
                                        ),
                                      ),
                                    ),
                                 ],
                               )
                            else
                            isCancelling
                                ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: _errorColor,
                              ),
                            )
                                : InkWell(
                              onTap: () {
                                _showCancelConfirmationDialog(reservation);
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _errorColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: _errorColor.withOpacity(0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.cancel_outlined,
                                      size: 16,
                                      color: _errorColor,
                                    ),
                                    SizedBox(width: 5),
                                    Text(
                                      'Annuler',
                                      style: TextStyle(
                                        color: _errorColor,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          if (isConfirmed)
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: _successColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: _successColor.withOpacity(0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.check_circle,
                                    size: 16,
                                    color: _successColor,
                                  ),
                                  SizedBox(width: 5),
                                  Text(
                                    'Confirmée',
                                    style: TextStyle(
                                      color: _successColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (isCompleted)
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: _primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: _primaryColor.withOpacity(0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.done_all,
                                    size: 16,
                                    color: _primaryColor,
                                  ),
                                  SizedBox(width: 5),
                                  Text(
                                    'Terminée',
                                    style: TextStyle(
                                      color: _primaryColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (isCancelled)
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: _errorColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: _errorColor.withOpacity(0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.cancel,
                                    size: 16,
                                    color: _errorColor,
                                  ),
                                  SizedBox(width: 5),
                                  Text(
                                    'Annulée',
                                    style: TextStyle(
                                      color: _errorColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (isCancelling)
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

  List<Widget> _buildFeatureChips(PropertyModel? propertyData) {
    final features = <Widget>[];

    if (propertyData?.bedrooms != null) {
      features.add(_buildFeatureChip('${propertyData!.bedrooms} chambres'));
    }
    if (propertyData?.bathroom != null) {
      features.add(_buildFeatureChip('${propertyData!.bathroom} sdb'));
    }
    if (propertyData?.surface != null) {
      features.add(_buildFeatureChip('${propertyData!.surface}m²'));
    }
    if (propertyData?.rooms != null) {
      features.add(_buildFeatureChip('${propertyData!.rooms} pièces'));
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

  String? _formatDate(String? dateString) {
    if (dateString == null) return null;
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('dd/MM/yyyy').format(date);
    } catch (e) {
      return dateString;
    }
  }

  Color _getStatusColor(String? status) {
    switch (status?.toUpperCase()) {
      case 'PENDING':
        return _warningColor;
      case 'CONFIRMED':
      case 'APPROVED':
        return _successColor;
      case 'COMPLETED':
        return _primaryColor;
      case 'CANCELLED':
      case 'CANCELED':
        return _errorColor;
      default:
        return _mediumGrey;
    }
  }

  String _getStatusText(String? status) => frReservationStatus(status);

  Future<bool> _cancelReservation(ReservationModel reservation, String reason) async {
    if (!mounted || _isLoading) return false;

    setState(() {
      _isLoading = true;
      _cancellingIds.add(reservation.reservationId!.toString());
    });

    FocusScope.of(context).unfocus();

    final isConnected = await NetworkUtils.checkInternetConnectivity();
    if (!isConnected) {
      FancyNotification.show(context, "Pas de connexion internet");
      setState(() {
        _isLoading = false;
        _cancellingIds.remove(reservation.reservationId!.toString());
      });
      return false;
    }

    try {
      final reservationCtrl = Provider.of<ReservationController>(context, listen: false);
      final response = await reservationCtrl.cancelReservation(
        reservation.reservationId!,
        reason,
        reservation: reservation,
      );

      if (!mounted) return false;

      if (response.status == true) {
        FancyNotification.show(context, "Réservation annulée", type: NotificationType.success);

        // Recharger les données
        await _loadReservations();
        
        // Redirection vers le tab des réservations annulées (index 2, tabs=3)
        if (mounted && _tabController.length > 0) {
          const cancelledTabIndex = 2;
          final safeIndex = cancelledTabIndex.clamp(0, _tabController.length - 1);
          _tabController.animateTo(safeIndex);
        }

        setState(() {
          _isLoading = false;
          _cancellingIds.remove(reservation.reservationId!.toString());
        });
        return true;
      } else {
        reportApiFailureToCrashlytics(
          'BookingHistoryPage',
          response: response,
          reason: 'cancel_reservation',
        );
        FancyNotification.show(
          context,
          response.errorMsg ??
              "L’annulation n’a pas abouti. Réessayez dans un instant.",
          isError: true,
        );
      }
    } catch (e, st) {
      reportApiFailureToCrashlytics(
        'BookingHistoryPage',
        error: e,
        stackTrace: st,
        reason: 'cancel_reservation_exception',
      );
      print("❌ Erreur lors de l'annulation: $e");
      FancyNotification.show(
        context,
        "L’annulation n’a pas pu être enregistrée. Vérifiez la connexion et réessayez.",
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _cancellingIds.remove(reservation.reservationId!.toString());
        });
      }
    }
    return false;
  }


  void _showReservationDetails(ReservationModel reservation) {
    if (_isHostView) {
      _showHostManagementBottomSheet(reservation);
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => _buildReservationDetails(reservation),
      );
    }
  }

  void _showHostManagementBottomSheet(ReservationModel reservation) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildHostManagementContent(reservation),
    );
  }

  Widget _buildHostManagementContent(ReservationModel reservation) {
    final status = reservation.status?.toUpperCase() ?? '';
    final isPending = status == 'PENDING';
    final imageUrl = _getImageUrl(reservation);

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
                  child: Icon(Icons.manage_accounts_rounded, color: _primaryColor, size: 28),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Gérer la réservation", style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: _darkColor)),
                      Text("Action sur la demande de visite", style: TextStyle(color: _mediumGrey, fontSize: 13)),
                    ],
                  ),
                ),
             ],
          ),
          SizedBox(height: 24),
          
          if (reservation.user != null) ...[
             Text("Client", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: _darkColor)),
             SizedBox(height: 12),
             InkWell(
               onTap: () {
                 if (reservation.userImage != null && reservation.userImage!.isNotEmpty) {
                   reservation.user!.profilePicture = reservation.userImage;
                 }
                 UserInfoBottomSheet.show(context, reservation.user!);
               },
               borderRadius: BorderRadius.circular(12),
               child: Container(
                 padding: EdgeInsets.all(12),
                 decoration: BoxDecoration(color: _lightGrey, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[200]!)),
                 child: Row(
                   children: [
                     CircleAvatar(
                       radius: 20,
                       backgroundColor: _primaryColor.withOpacity(0.2),
                       backgroundImage: (reservation.userImage != null && reservation.userImage!.isNotEmpty)
                           ? CachedNetworkImageProvider(reservation.userImage!) as ImageProvider
                           : null,
                       child: (reservation.userImage != null && reservation.userImage!.isNotEmpty)
                           ? null
                           : Icon(Icons.person, color: _primaryColor),
                     ),
                     SizedBox(width: 12),
                     Expanded(
                       child: Column(
                         crossAxisAlignment: CrossAxisAlignment.start,
                         children: [
                           Text(reservation.user!.username ?? "Client", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                          Text(
                            (() {
                              final raw = reservation.user?.phone?.toString().trim() ?? '';
                              if (raw.isEmpty || raw.toLowerCase() == 'null') {
                                return 'Pas de téléphone';
                              }
                              return raw;
                            })(),
                            style: TextStyle(color: _mediumGrey, fontSize: 12),
                          ),
                         ],
                       ),
                     ),
                     Icon(Icons.chevron_right, color: _mediumGrey),
                   ],
                 ),
               ),
             ),
             SizedBox(height: 20),
          ],

          Text("Bien immobilier", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: _darkColor)),
          SizedBox(height: 8),
          Text(reservation.property?.title ?? "Propriété", style: TextStyle(fontSize: 16, color: _darkColor, fontWeight: FontWeight.w500)),
          SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.calendar_today_rounded, size: 14, color: _primaryColor),
              SizedBox(width: 6),
              Text(
                'Visite prévue: ${_formatDate(reservation.startDate)} à ${reservation.reservationHeure ?? "N/A"}',
                style: TextStyle(fontSize: 13, color: _mediumGrey),
              ),
            ],
          ),
          
          if (reservation.message != null && reservation.message!.isNotEmpty) ...[
            SizedBox(height: 16),
            Text("Message du client", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _mediumGrey)),
            SizedBox(height: 4),
            Text(reservation.message!, style: TextStyle(color: _darkColor, height: 1.4)),
          ],

          // Partager / Télécharger (utile si le modal de succès a été raté)
          SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async => await _shareReservationPdf(reservation),
                  icon: Icon(Icons.ios_share_rounded, color: _primaryColor),
                  label: Text(
                    "Partager le bon",
                    style: TextStyle(
                      color: _darkColor.withOpacity(0.9),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: BorderSide(
                      color: _primaryColor.withOpacity(0.3),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async => await _downloadReservationPdf(reservation),
                  icon: Icon(Icons.download_rounded, color: _primaryColor),
                  label: Text(
                    "Télécharger (PDF)",
                    style: TextStyle(
                      color: _darkColor.withOpacity(0.9),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: BorderSide(
                      color: _primaryColor.withOpacity(0.3),
                    ),
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: 32),
          if (isPending) ...[
             Row(
               children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _handleReservationAction(reservation, 'CANCELLED', fromBottomSheet: true),
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
                      onPressed: () => _handleReservationAction(reservation, 'APPROVED', fromBottomSheet: true),
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
                 "Statut actuel: ${_getStatusText(reservation.status)}",
                 style: TextStyle(color: _getStatusColor(reservation.status), fontWeight: FontWeight.bold),
               ),
             ),
          ],
          SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildReservationDetails(ReservationModel reservation) {
    final status = reservation.status?.toUpperCase() ?? '';
    final isPending = status == 'PENDING';
    final isCancelled = status == 'CANCELLED';
    final isCompleted = status == 'COMPLETED';
    final imageUrl = _getImageUrl(reservation);

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, controller) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          padding: EdgeInsets.all(24),
          child: SingleChildScrollView(
            controller: controller,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),
                SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Détails',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: _darkColor,
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _getStatusColor(reservation.status).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _getStatusColor(reservation.status).withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        _getStatusText(reservation.status),
                        style: TextStyle(
                          color: _getStatusColor(reservation.status),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20),

                // Section propriété
                Text(
                  'Propriété réservée',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _darkColor,
                  ),
                ),
                SizedBox(height: 12),

                GestureDetector(
                  onTap: () async {
                    if (reservation.property == null) return;
                    await navigateToPropertyDetail(
                      context,
                      reservation.property!,
                    );
                  },
                  child: Container(
                    height: 180,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      color: _lightGrey,
                    ),
                    child: imageUrl != null
                        ? ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: Stack(
                        children: [
                          CachedNetworkImage(
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
                              return _buildImageErrorWidget();
                            },
                          ),
                          Positioned(
                            bottom: 10,
                            right: 10,
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.7),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.visibility, color: Colors.white, size: 12),
                                  SizedBox(width: 4),
                                  Text(
                                    'Voir détails',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                        : _buildImageErrorWidget(),
                  ),
                ),
                SizedBox(height: 15),

                Text(
                  "${reservation.property?.title ?? 'Sans titre'}",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: _darkColor,
                  ),
                ),
                SizedBox(height: 5),
                Row(
                  children: [
                    Icon(Icons.location_on_outlined, size: 16, color: _mediumGrey),
                    SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        "${reservation.property?.address ?? 'Adresse non disponible'}",
                        style: TextStyle(
                          color: _mediumGrey,
                          fontSize: 14,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20),

                // Section informations réservation
                Text(
                  'Informations de réservation',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _darkColor,
                  ),
                ),
                SizedBox(height: 15),

                _buildDetailRow(
                  icon: Icons.date_range,
                  label: 'Date de début',
                  value: _formatDate(reservation.startDate) ?? 'Non spécifiée',
                  isImportant: true,
                ),
                _buildDetailRow(
                  icon: Icons.date_range,
                  label: 'Date de fin',
                  value: _formatDate(reservation.endDate) ?? 'Non spécifiée',
                  isImportant: true,
                ),
                _buildDetailRow(
                  icon: Icons.access_time,
                  label: 'Heure',
                  value: reservation.reservationHeure ?? 'Non spécifiée',
                ),
                _buildDetailRow(
                  icon: Icons.message,
                  label: 'Message',
                  value: reservation.message ?? 'Aucun message',
                ),
                _buildDetailRow(
                  icon: Icons.calendar_today,
                  label: 'Date de réservation',
                  value: _formatDate(reservation.createdAt) ?? 'Non spécifiée',
                ),
                if (isCancelled && reservation.cancellationReason != null)
                  _buildDetailRow(
                    icon: Icons.cancel_outlined,
                    label: 'Motif d\'annulation',
                    value: reservation.cancellationReason!,
                    valueColor: _errorColor,
                  ),
                SizedBox(height: 15),

                // Boutons Partager et Télécharger (disponibles pour tous les statuts)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async => await _shareReservationPdf(reservation),
                        icon: Icon(Icons.ios_share_rounded, color: _primaryColor),
                        label: Text(
                          "Partager",
                          style: TextStyle(
                            color: _darkColor.withOpacity(0.9),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(
                            color: _primaryColor.withOpacity(0.3),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async => await _downloadReservationPdf(reservation),
                        icon: Icon(Icons.download_rounded, color: _primaryColor),
                        label: Text(
                          "Télécharger",
                          style: TextStyle(
                            color: _darkColor.withOpacity(0.9),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(
                            color: _primaryColor.withOpacity(0.3),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),

                // Actions spécifiques au statut
                if (isPending)
                  Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _showCancelConfirmationDialog(reservation);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _errorColor.withOpacity(0.1),
                            foregroundColor: _errorColor,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.cancel_outlined, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'ANNULER LA RÉSERVATION',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        'En attente de confirmation par le propriétaire',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _warningColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                if (isCompleted)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _showReviewDialog(reservation);
                      },
                      icon: Icon(Icons.star_outline, size: 20),
                      label: Text('LAISSER UN AVIS'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor,
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
    bool isImportant = false,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 20,
              color: _primaryColor,
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: _mediumGrey,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    color: valueColor ?? _darkColor,
                    fontSize: isImportant ? 17 : 16,
                    fontWeight: isImportant ? FontWeight.bold : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageErrorWidget() {
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
  }

  void _showCancelConfirmationDialog(ReservationModel reservation) {
    final reasonController = TextEditingController();
    bool isSheetLoading = false;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final bottomInset = MediaQuery.of(sheetContext).viewInsets.bottom;

            Future<void> onConfirm() async {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) {
                FancyNotification.show(sheetContext, "Veuillez entrer une raison simple");
                return;
              }
              setSheetState(() => isSheetLoading = true);
              final ok = await _cancelReservation(reservation, reason);
              if (!mounted) return;
              if (ok) {
                Navigator.pop(sheetContext);
              } else {
                setSheetState(() => isSheetLoading = false);
              }
            }

            return AnimatedPadding(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              padding: EdgeInsets.only(bottom: bottomInset),
              child: SafeArea(
                top: false,
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(24)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.12),
                        blurRadius: 24,
                        offset: const Offset(0, -8),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 22),
                          decoration: const BoxDecoration(
                            color: Color(0xFFFFEBEE),
                            borderRadius:
                                BorderRadius.vertical(top: Radius.circular(24)),
                          ),
                          child: Center(
                            child: Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFFFEBEE)
                                        .withOpacity(0.55),
                                    blurRadius: 10,
                                    spreadRadius: 5,
                                  )
                                ],
                              ),
                              child: const Icon(
                                Icons.warning_amber_rounded,
                                color: Color(0xFFD32F2F),
                                size: 36,
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 22, 24, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Center(
                                child: Text(
                                  'Annuler la visite ?',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1A1A1A),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF9C4)
                                      .withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFFFBC02D)
                                        .withOpacity(0.2),
                                  ),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.info_outline,
                                        color: Color(0xFFFBC02D), size: 20),
                                    SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'Attention : Cette action est définitive.',
                                        style: TextStyle(
                                          color: Color(0xFF5D4037),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 18),
                              const Text(
                                'Pourquoi souhaitez-vous annuler ?',
                                style: TextStyle(
                                  color: Color(0xFF666666),
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: reasonController,
                                enabled: !isSheetLoading,
                                maxLines: 3,
                                style: const TextStyle(fontSize: 14),
                                decoration: InputDecoration(
                                  hintText:
                                      'Ex: empêchement de dernière minute…',
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
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                          child: Column(
                            children: [
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: isSheetLoading ? null : onConfirm,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFD32F2F),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: isSheetLoading
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white),
                                        )
                                      : const Text(
                                          'Confirmer l\'annulation',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: TextButton(
                                  onPressed: isSheetLoading
                                      ? null
                                      : () => Navigator.pop(sheetContext),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
                                  ),
                                  child: const Text(
                                    'Garder ma réservation',
                                    style: TextStyle(
                                      color: Color(0xFF666666),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      try {
        reasonController.dispose();
      } catch (_) {}
    });
  }

  void _showReviewDialog(ReservationModel reservation) {
    double rating = 5.0;
    final commentController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                padding: EdgeInsets.all(24),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: _primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.star, color: _primaryColor, size: 24),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Laisser un avis',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: _darkColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 20),
                      Text(
                        'Évaluez ce service',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: _darkColor,
                        ),
                      ),
                      SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (index) {
                          final starIndex = index + 1;
                          return GestureDetector(
                            onTap: () {
                              setDialogState(() {
                                rating = starIndex.toDouble();
                              });
                            },
                            child: Icon(
                              starIndex <= rating ? Icons.star : Icons.star_border,
                              color: Colors.amber,
                              size: 40,
                            ),
                          );
                        }),
                      ),
                      SizedBox(height: 20),
                      Text(
                        'Votre commentaire',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: _darkColor,
                        ),
                      ),
                      SizedBox(height: 12),
                      TextField(
                        controller: commentController,
                        decoration: InputDecoration(
                          hintText: 'Partagez votre expérience...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: _primaryColor),
                          ),
                          contentPadding: EdgeInsets.all(15),
                        ),
                        maxLines: 5,
                      ),
                      SizedBox(height: 25),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () {
                              commentController.dispose();
                              Navigator.pop(context);
                            },
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            ),
                            child: Text(
                              'Annuler',
                              style: TextStyle(
                                color: _mediumGrey,
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          SizedBox(width: 10),
                          ElevatedButton(
                            onPressed: () async {
                              if (commentController.text.trim().isEmpty) {
                                FancyNotification.show(
                                  context,
                                  'Veuillez ajouter un commentaire',
                                  type: NotificationType.warning,
                                );
                                return;
                              }
                              
                              Navigator.pop(context);
                              
                              // TODO: Envoyer l'avis à l'API
                              // Pour l'instant, on affiche juste une notification de succès
                              FancyNotification.show(
                                context,
                                'Avis envoyé avec succès !',
                                type: NotificationType.success,
                              );
                              
                              commentController.dispose();
                              
                              // Recharger les réservations
                              await _loadReservations();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _primaryColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            ),
                            child: Text(
                              'Envoyer',
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<Uint8List> _buildReservationPdfBytes(ReservationModel reservation) async {
    return buildReservationPdfBytes(reservation, _logoImage);
  }



  Future<void> _loadHostReservations(ReservationController ctrl) async {
     try {
       final hosts = await ctrl.getHostReservations();
       if (mounted) {
         setState(() {
           _hostReservations = hosts;
         });
       }
     } catch(e) {
       print("Erreur loading host reservations: $e");
     }
  }

  Widget _buildActionButton({required IconData icon, required Color color, required String label, required VoidCallback onTap}) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.5)),
          ),
          child: Column(
            children: [
              Icon(icon, size: 18, color: color),
              Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold))
            ],
          ),
        ),
      ),
    );
  }

  // Dialog pour refuser une réservation (Host)
  Future<Map<String, dynamic>?> _showHostRefuseDialog(ReservationModel reservation) async {
    final reasonController = TextEditingController();
    bool isDialogLoading = false;

    return await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: Offset(0, 10),
                    )
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header avec icône Warning
                    Container(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      decoration: BoxDecoration(
                        color: Color(0xFFFFEBEE),
                        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                      ),
                      child: Center(
                        child: Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Color(0xFFFFEBEE).withOpacity(0.5),
                                blurRadius: 10,
                                spreadRadius: 5,
                              )
                            ],
                          ),
                          child: Icon(Icons.cancel_outlined, color: Color(0xFFD32F2F), size: 36),
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(24, 24, 24, 16),
                      child: Column(
                        children: [
                          Text(
                            'Refuser la réservation ?',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                          SizedBox(height: 12),
                          Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Color(0xFFFFF9C4).withOpacity(0.3),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Color(0xFFFBC02D).withOpacity(0.2)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline, color: Color(0xFFFBC02D), size: 20),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Cette action refusera définitivement la demande de visite du client.',
                                    style: TextStyle(
                                      color: Color(0xFF5D4037),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 20),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Motif du refus (optionnel)',
                              style: TextStyle(
                                color: Color(0xFF666666),
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          SizedBox(height: 12),
                          TextField(
                            controller: reasonController,
                            enabled: !isDialogLoading,
                            maxLines: 3,
                            style: TextStyle(fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'Ex: propriété déjà louée, dates non disponibles...',
                              hintStyle: TextStyle(color: Color(0xFFAAAAAA), fontSize: 14),
                              fillColor: Color(0xFFF5F5F5),
                              filled: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: EdgeInsets.all(16),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(24, 0, 24, 24),
                      child: Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: isDialogLoading 
                                  ? null 
                                  : () {
                                      reasonController.dispose();
                                      Navigator.pop(context, {
                                        'confirmed': true,
                                        'reason': reasonController.text.isEmpty 
                                            ? "Refusé par l'hôte" 
                                            : reasonController.text
                                      });
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Color(0xFFD32F2F),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: Text(
                                'Confirmer le refus',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ),
                          ),
                          SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: TextButton(
                              onPressed: isDialogLoading 
                                  ? null 
                                  : () {
                                      reasonController.dispose();
                                      Navigator.pop(context, null);
                                    },
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.symmetric(vertical: 16),
                              ),
                              child: Text(
                                'Annuler',
                                style: TextStyle(
                                  color: Color(0xFF666666),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                            ),
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
      },
    );
  }

  // Dialog pour valider une réservation (Host)
  Future<bool?> _showHostValidateDialog(ReservationModel reservation) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: Offset(0, 10),
                )
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header avec icône Success
                Container(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  decoration: BoxDecoration(
                    color: Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Center(
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Color(0xFFE8F5E9).withOpacity(0.5),
                            blurRadius: 10,
                            spreadRadius: 5,
                          )
                        ],
                      ),
                      child: Icon(Icons.check_circle_outline, color: Color(0xFF00B894), size: 36),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(24, 24, 24, 16),
                  child: Column(
                    children: [
                      Text(
                        'Valider la réservation ?',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      SizedBox(height: 12),
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Color(0xFFE8F5E9).withOpacity(0.5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Color(0xFF00B894).withOpacity(0.2)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: Color(0xFF00B894), size: 20),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Le client recevra une notification de confirmation et pourra procéder à la visite.',
                                style: TextStyle(
                                  color: Color(0xFF2D5016),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF00B894),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            'Confirmer la validation',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                      ),
                      SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: Text(
                            'Annuler',
                            style: TextStyle(
                              color: Color(0xFF666666),
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ),
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

  Future<void> _handleReservationAction(ReservationModel reservation, String action, {bool fromBottomSheet = false}) async {
      final ctrl = Provider.of<ReservationController>(context, listen: false);
      if (reservation.reservationId == null) return;
      
      bool confirm = false;
      String? reason;
      
      if (action == 'CANCELLED') {
        final result = await _showHostRefuseDialog(reservation);
        if (result != null && result['confirmed'] == true) {
          confirm = true;
          reason = result['reason'];
        }
      } else {
        final result = await _showHostValidateDialog(reservation);
        confirm = result ?? false;
      }
      
      if (confirm) {
         if (fromBottomSheet && mounted) Navigator.pop(context); // Fermer le management BottomSheet seulement si demandé
         setState(() => _isLoading = true);
         try {
           bool success = false;
           HttpResponse? lastResp;
           if (action == 'CANCELLED') {
            lastResp = await ctrl.cancelReservation(
              reservation.reservationId!,
              reason ?? "Cancelled",
              reservation: reservation,
            );
            success = lastResp.status == true;
         } else if (action == 'APPROVED' || action == 'CONFIRMED') {
            // Validation hôte : statut API = APPROVED (CONFIRMED = ancien libellé UI uniquement).
            lastResp = await ctrl.validateReservation(
              reservation.reservationId!,
              true,
              reservation: reservation,
            );
            success = lastResp.status == true;
         } else {
            lastResp = await ctrl.updateReservationStatus(reservation.reservationId!, action);
            success = lastResp.status == true;
         }
           
           if (success) {
             if (mounted) {
                if (action == 'APPROVED' || action == 'CONFIRMED') {
                  _showHostActionSuccessDialog(reservation);
                } else {
                  FancyNotification.show(context, "Action effectuée avec succès", type: NotificationType.success);
                }
             }
             if (action == 'APPROVED' || action == 'CONFIRMED') {
               // 1) Mise à jour locale immédiate pour faire disparaître l'item de "En attente"
               // (évite double validation avant refresh réseau).
               void updateLocal(List<ReservationModel> list) {
                 final idx = list.indexWhere(
                     (r) => r.reservationId == reservation.reservationId);
                 if (idx != -1) {
                   list[idx].status = 'APPROVED';
                 }
               }

               if (mounted) {
                 setState(() {
                   updateLocal(_hostReservations);
                 });
               } else {
                 updateLocal(_hostReservations);
               }

               // 2) Switch direct vers "Confirmées"
               if (mounted && _tabController.length > 0) {
                 const confirmedTabIndex = 1;
                 final safeIndex =
                     confirmedTabIndex.clamp(0, _tabController.length - 1);
                 _tabController.animateTo(safeIndex);
               }

               // 3) Refresh global forcé (await) pour resynchroniser tous les onglets
               if (mounted) {
                 await _loadReservations(forceRefresh: true);
               }
             } else {
               // Autres actions: refresh simple
               _loadReservations(forceRefresh: true);
             }
           } else if (mounted && lastResp != null) {
             reportApiFailureToCrashlytics(
               'BookingHistoryPage',
               response: lastResp,
               reason: 'host_reservation_action_$action',
             );
             FancyNotification.show(
               context,
               "L’action n’a pas abouti. Réessayez dans un instant.",
               isError: true,
             );
           }
         } catch(e, st) {
           reportApiFailureToCrashlytics(
             'BookingHistoryPage',
             error: e,
             stackTrace: st,
             reason: 'host_reservation_action_exception',
           );
           if (mounted) {
             FancyNotification.show(
               context,
               "L’action n’a pas abouti. Réessayez dans un instant.",
               isError: true,
             );
           }
         } finally {
           if (mounted) setState(() => _isLoading = false);
         }
      }
  }

  void _showHostActionSuccessDialog(ReservationModel reservation) {
    // Uniformisation UX: utiliser le même modèle que le bottomsheet (Partager / Télécharger).
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return AnimatedPadding(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
          child: SafeArea(
            top: false,
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + MediaQuery.of(sheetContext).padding.bottom),
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
                    "Réservation validée",
                    style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: _darkColor),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Vous avez confirmé cette demande de visite. Le client a été notifié. Vous pouvez partager ou télécharger le bon de visite maintenant.",
                    style: TextStyle(color: _mediumGrey, height: 1.35),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async => await _shareReservationPdf(reservation),
                          icon: Icon(Icons.ios_share_rounded, color: _primaryColor),
                          label: Text(
                            "Partager le bon",
                            style: TextStyle(
                              color: _darkColor.withOpacity(0.9),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: BorderSide(
                              color: _primaryColor.withOpacity(0.3),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async => await _downloadReservationPdf(reservation),
                          icon: Icon(Icons.download_rounded, color: _primaryColor),
                          label: Text(
                            "Télécharger (PDF)",
                            style: TextStyle(
                              color: _darkColor.withOpacity(0.9),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: BorderSide(
                              color: _primaryColor.withOpacity(0.3),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      child: Text(
                        "Fermer",
                        style: TextStyle(color: _mediumGrey, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _downloadReservationPdf(ReservationModel reservation) async {
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

      final bytes = await _buildReservationPdfBytes(reservation);
      final generationDate = DateFormat('dd_MMMM_yyyy_HH_mm', 'fr_FR').format(DateTime.now());
      final filePath = '${dir.path}/Bon_Reservation_Ref_${reservation.reservationId}_du_$generationDate.pdf';
      final file = File(filePath);
      await file.writeAsBytes(bytes, flush: true);

      try {
        await OpenFile.open(filePath);
      } catch (e) {
        print("Erreur ouverture PDF: $e");
      }

      if (!mounted) return;
      FancyNotification.show(
        context,
        "PDF enregistré dans : ${describePickedDirectoryPathForUser(dir.path)}",
        isError: false,
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

  Future<void> _shareReservationPdf(ReservationModel reservation) async {
    try {
      final bytes = await _buildReservationPdfBytes(reservation);
      final generationDate = DateFormat('dd_MMMM_yyyy_HH_mm', 'fr_FR').format(DateTime.now());
      final fileName = 'Bon_Reservation_Ref_${reservation.reservationId}_du_$generationDate.pdf';
      
      // Pour garantir le nom du fichier au partage, on l'écrit d'abord dans un fichier temporaire
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/$fileName');
      await tempFile.writeAsBytes(bytes);
      
      final xfile = XFile(tempFile.path, mimeType: 'application/pdf', name: fileName);
      
      await Share.shareXFiles(
        [xfile],
        text: "Confirmation de réservation - ${reservation.property?.title ?? 'Propriété'}",
      );
    } catch (e) {
      FancyNotification.show(context, "Partage du PDF impossible");
    }
  }
}
