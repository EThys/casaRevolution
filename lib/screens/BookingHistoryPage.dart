import 'package:cached_network_image/cached_network_image.dart';
import 'package:casa/models/ReservationModel.dart';
import 'package:casa/screens/PropertyDetailPage.dart';
import 'package:casa/utils/Constantes.dart';
import 'package:casa/utils/FancyNotification.dart';
import 'package:casa/utils/Routes.dart';
import 'package:casa/utils/StockageKeys.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:get_storage/get_storage.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:io';
import 'dart:typed_data';
import '../controllers/ReservationController.dart';
import '../models/PropertyModel.dart';
import '../utils/networkCheck.dart';
import '../utils/FavoriteEartIcon.dart';

class BookingHistoryPage extends StatefulWidget {
  const BookingHistoryPage({Key? key}) : super(key: key);

  @override
  _BookingHistoryPageState createState() => _BookingHistoryPageState();
}

class _BookingHistoryPageState extends State<BookingHistoryPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoadingData = true;
  bool _isRefreshing = false;
  final DateFormat _dateFormat = DateFormat('dd MMM yyyy', 'fr_FR');
  final GetStorage _storage = GetStorage();
  bool _isLoading = false;
  List<String> _cancellingIds = [];
  bool _isGridView = false; // Toggle pour vue liste/grille

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadLogo();
    _loadReservations();
    _loadReservationCounts();
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

  Future<void> _loadReservations() async {
    try {
      if (!mounted) return;

      setState(() {
        _isLoadingData = true;
        _isRefreshing = true;
      });

      final reservationCtrl = Provider.of<ReservationController>(context, listen: false);
      await reservationCtrl.getMyReservations();

      print("📊 Réservations chargées: ${reservationCtrl.reservations.length}");

      // Recharger les compteurs après le chargement
      await _loadReservationCounts();

    } catch (e) {
      print("❌ Erreur lors du chargement des réservations: $e");
      FancyNotification.show(context, "Erreur lors du chargement des réservations");
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingData = false;
          _isRefreshing = false;
        });
      }
    }
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
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reservationCtrl = Provider.of<ReservationController>(context);

    return Scaffold(
      backgroundColor: _lightGrey,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // Carte de statistiques
          _buildTabBar(),
          Expanded(
            child:             TabBarView(
              controller: _tabController,
              children: [
                _buildReservationList(_filterReservations(reservationCtrl.reservations, 'PENDING')),
                _buildReservationList(_filterReservations(reservationCtrl.reservations, 'CONFIRMED')),
                _buildReservationList(_filterReservations(reservationCtrl.reservations, 'COMPLETED')),
                _buildReservationList(_filterReservations(reservationCtrl.reservations, 'CANCELLED')),
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
      onPressed: _isRefreshing ? null : _loadReservations,
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
        Tooltip(
          message: 'Actualiser',
          child: Stack(
            children: [
              IconButton(
                icon: Icon(_isRefreshing ? Icons.refresh : Icons.refresh, color: Colors.white),
                onPressed: _isRefreshing ? null : _loadReservations,
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
    // Calculer les compteurs depuis les données actuelles
    final reservationCtrl = Provider.of<ReservationController>(context, listen: false);
    final userReservations = reservationCtrl.reservations;

    final pendingCount = _filterReservations(userReservations, 'PENDING').length;
    final confirmedCount = _filterReservations(userReservations, 'CONFIRMED').length;
    final completedCount = _filterReservations(userReservations, 'COMPLETED').length;
    final cancelledCount = _filterReservations(userReservations, 'CANCELLED').length;

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
                text: 'Terminées ($completedCount)',
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

  List<ReservationModel> _filterReservations(List<ReservationModel> reservations, String status) {
    final filtered = reservations.where((reservation) => reservation.status == status).toList();

    // Trier par date (les plus récentes en premier)
    filtered.sort((a, b) {
      final dateA = DateTime.tryParse(a.createdAt ?? '');
      final dateB = DateTime.tryParse(b.createdAt ?? '');
      if (dateA == null || dateB == null) return 0;
      return dateB.compareTo(dateA);
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
      child: _isLoadingData
          ? _buildShimmerEffect()
          : reservations.isEmpty
          ? _buildEmptyState()
          : _buildReservationListContent(reservations),
    );
  }

  Widget _buildEmptyState() {
    final emptyMessages = [
      "Aucune réservation en attente de confirmation",
      "Aucune réservation confirmée pour le moment",
      "Aucune réservation terminée",
      "Aucune réservation annulée"
    ];

    final emptyIcons = [
      Icons.pending_actions,
      Icons.check_circle_outline,
      Icons.done_all,
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
      onRefresh: _loadReservations,
      child: _isGridView
          ? _buildReservationGridContent(reservations)
          : ListView.separated(
              padding: EdgeInsets.all(20),
              itemCount: reservations.length,
              separatorBuilder: (_, __) => SizedBox(height: 20),
              itemBuilder: (context, index) {
                final reservation = reservations[index];
                return AnimatedSwitcher(
                  duration: Duration(milliseconds: 300),
                  child: _buildReservationCard(reservation),
                );
              },
            ),
    );
  }

  Widget _buildReservationGridContent(List<ReservationModel> reservations) {
    return GridView.builder(
      padding: EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.75, // Ajusté pour éviter l'overflow
      ),
      itemCount: reservations.length,
      itemBuilder: (context, index) {
        final reservation = reservations[index];
        return AnimatedSwitcher(
          duration: Duration(milliseconds: 300),
          child: _buildReservationGridCard(reservation),
        );
      },
    );
  }

  Widget _buildReservationGridCard(ReservationModel reservation) {
    final isPending = reservation.status == 'PENDING';
    final isCancelled = reservation.status == 'CANCELLED';
    final isConfirmed = reservation.status == 'CONFIRMED';
    final isCompleted = reservation.status == 'COMPLETED';
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
    final isPending = reservation.status == 'PENDING';
    final isCancelled = reservation.status == 'CANCELLED';
    final isConfirmed = reservation.status == 'CONFIRMED';
    final isCompleted = reservation.status == 'COMPLETED';
    final isCancelling = _cancellingIds.contains(reservation.reservationId);
    final imageUrl = _getImageUrl(reservation);

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
                                size: 20,
                                splashRadius: 18,
                                activeColor: Colors.red,
                                inactiveColor: _mediumGrey,
                              ),
                            ),
                        ],
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
    switch (status) {
      case 'PENDING':
        return _warningColor;
      case 'CONFIRMED':
        return _successColor;
      case 'COMPLETED':
        return _primaryColor;
      case 'CANCELLED':
        return _errorColor;
      default:
        return _mediumGrey;
    }
  }

  String _getStatusText(String? status) {
    switch (status) {
      case 'PENDING':
        return 'En attente';
      case 'CONFIRMED':
        return 'Confirmée';
      case 'COMPLETED':
        return 'Terminée';
      case 'CANCELLED':
        return 'Annulée';
      default:
        return status ?? 'Inconnu';
    }
  }

  Future<void> _cancelReservation(ReservationModel reservation, String reason) async {
    if (!mounted || _isLoading) return;

    setState(() {
      _isLoading = true;
      _cancellingIds.add(reservation.reservationId! as String);
    });

    FocusScope.of(context).unfocus();

    final isConnected = await NetworkUtils.checkInternetConnectivity();
    if (!isConnected) {
      FancyNotification.show(context, "Pas de connexion internet");
      setState(() {
        _isLoading = false;
        _cancellingIds.remove(reservation.reservationId!);
      });
      return;
    }

    try {
      final reservationCtrl = Provider.of<ReservationController>(context, listen: false);
      final response = await reservationCtrl.cancelReservation(
        reservation.reservationId!,
        reason,
      );

      if (!mounted) return;

      if (response.status == true) {
        FancyNotification.show(context, "Réservation annulée avec succès", type: NotificationType.success);

        // Recharger les données
        await _loadReservations();

        if (mounted) {
          Navigator.of(context).pop(); // Fermer le bottom sheet des détails
        }
      } else {
        String errorMsg = response.errorMsg ?? "Échec de l'annulation";
        FancyNotification.show(context, errorMsg);
      }
    } catch (e) {
      print("❌ Erreur d'annulation: $e");
      FancyNotification.show(context, "Erreur technique lors de l'annulation");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _cancellingIds.remove(reservation.reservationId!);
        });
      }
    }
  }

  void _showReservationDetails(ReservationModel reservation) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildReservationDetails(reservation),
    );
  }

  Widget _buildReservationDetails(ReservationModel reservation) {
    final isPending = reservation.status == 'PENDING';
    final isCancelled = reservation.status == 'CANCELLED';
    final isCompleted = reservation.status == 'COMPLETED';
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
                  onTap: () {
                    if (reservation.property != null) {
                      Navigator.pushNamed(
                        context,
                        Routes.detailPageRoute,
                        arguments: reservation.property,
                      );
                    }
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

                // Actions
                if (isPending)
                  Column(
                    children: [
                      // Boutons Partager et Télécharger
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

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: EdgeInsets.all(20),
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
                        color: _warningColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.warning_amber_rounded, color: _warningColor, size: 24),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Annuler la visite',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: _darkColor,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 15),
                Text(
                  'Veuillez indiquer le motif de l\'annulation :',
                  style: TextStyle(
                    color: _mediumGrey,
                    fontSize: 15,
                  ),
                ),
                SizedBox(height: 15),
                TextField(
                  controller: reasonController,
                  decoration: InputDecoration(
                    hintText: 'Motif de l\'annulation...',
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
                  maxLines: 3,
                ),
                SizedBox(height: 25),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        reasonController.dispose();
                        Navigator.pop(context);
                      },
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      child: Text(
                        'Retour',
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
                        if (reasonController.text.trim().isNotEmpty) {
                          Navigator.pop(context);
                          await _cancelReservation(reservation, reasonController.text);
                          reasonController.dispose();
                        } else {
                          FancyNotification.show(context, "Veuillez indiquer un motif d\'annulation");
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _errorColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      child: Text(
                        'Confirmer',
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
        );
      },
    );
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
    final doc = pw.Document();
    final now = DateFormat('dd/MM/yy HH:mm').format(DateTime.now());
    
    final property = reservation.property;
    final publisher = property?.user;
    
    // Infos propriétaire/commissionnaire
    final publisherName = publisher?.username?.toString() ?? 
        publisher?.email?.toString()?.split('@').first ?? 
        'Non renseigné';
    final publisherPhone = publisher?.phone?.toString() ?? 'Non renseigné';
    final publisherEmail = publisher?.email?.toString() ?? 'Non renseigné';
    final typeAccountName = publisher?.typeAccount?.name?.toString()?.toLowerCase() ?? '';
    final publisherRole = typeAccountName.contains('bailleur')
        ? 'Bailleur'
        : (typeAccountName.contains('commission') || typeAccountName.contains('commissionnaire')
            ? 'Commissionnaire'
            : 'Annonceur');

    // Localisation enrichie - utiliser les valeurs *Value en priorité (elles contiennent les noms)
    final quartierName = (property?.quartierValue?.toString()?.isNotEmpty ?? false)
        ? property!.quartierValue!.toString()
        : (property?.quartier?.toString()?.isNotEmpty ?? false)
            ? property!.quartier!.toString()
            : '';
    final communeName = property?.communeValue?.toString() ?? '';
    final cityName = property?.cityValue?.toString() ?? '';
    final countryName = property?.countryValue?.toString() ?? '';
    
    final addressParts = <String>[
      property?.address?.toString() ?? '',
      quartierName,
      communeName,
      cityName,
      countryName,
    ].where((e) => e.isNotEmpty).toList();
    final fullAddress = addressParts.join(', ');

    // Formatage des dates
    String formatDate(String? dateStr) {
      if (dateStr == null) return 'Non spécifiée';
      try {
        final date = DateTime.parse(dateStr);
        return DateFormat('dd-MM-yyyy').format(date);
      } catch (e) {
        return dateStr;
      }
    }

    final userName = reservation.user?.username?.toString() ?? 
        reservation.user?.email?.toString()?.split('@').first ?? 
        'Client';
    final userPhone = reservation.user?.phone?.toString() ?? '';
    final userEmail = reservation.user?.email?.toString() ?? '';

    doc.addPage(
      pw.Page(
        build: (context) => pw.Container(
          padding: const pw.EdgeInsets.all(24),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  if (_logoImage != null)
                    pw.Container(
                      width: 48,
                      height: 48,
                      margin: const pw.EdgeInsets.only(right: 12),
                      child: pw.Image(_logoImage!),
                    ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'CasaNayo',
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        'Confirmation de la visite',
                        style: pw.TextStyle(
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Text('Généré le $now'),
              pw.Divider(),
              pw.SizedBox(height: 12),

              pw.Text('Propriété', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.Text(property?.title ?? 'Propriété'),
              if (fullAddress.isNotEmpty) ...[
                pw.SizedBox(height: 6),
                pw.Text(fullAddress),
              ],
              pw.SizedBox(height: 16),

              pw.Text('Visite', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.Text('Date : ${formatDate(reservation.startDate)}'),
              pw.Text('Heure : ${reservation.reservationHeure ?? 'Non spécifiée'}'),
              pw.Text('Fin estimée : ${formatDate(reservation.endDate)}'),
              pw.SizedBox(height: 16),

              pw.Text('Client', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.Text('Nom : $userName'),
              if (userPhone.isNotEmpty) pw.Text('Téléphone : $userPhone'),
              if (userEmail.isNotEmpty) pw.Text('Email : $userEmail'),
              pw.SizedBox(height: 16),

              pw.Text('Publié par', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.Text('Nom : $publisherName'),
              pw.Text('Rôle : $publisherRole'),
              pw.Text('Téléphone : $publisherPhone'),
              pw.Text('Email : $publisherEmail'),
              pw.SizedBox(height: 24),

              pw.Text(
                "Ce document constitue un aval préalable pour accéder à la visite. "
                "Le $publisherRole doit encore valider la demande ; un document complémentaire sera émis après acceptation. "
                "Conservez ce PDF comme preuve de demande et présentez-le le jour de la visite.",
                style: pw.TextStyle(fontSize: 12),
                textAlign: pw.TextAlign.justify,
              ),
              pw.SizedBox(height: 18),
              pw.Text(
                "Coordonnées CasaNayo :",
                style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
              ),
              pw.Text("Siège : CasaNayo, Service Réservations"),
              pw.Text("Téléphone : +243 820 000 000"),
              pw.Text("Email : contact@casanayo.com"),
              pw.Text("CEO : Gaius Handjila"),
            ],
          ),
        ),
      ),
    );

    return doc.save();
  }

  Future<Directory> _getExportDir() async {
    try {
      // Sur Android, utiliser directement le chemin du stockage externe public
      if (Platform.isAndroid) {
        final dir = Directory('/storage/emulated/0/casaNayo/documents');
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        return dir;
      }
      
      // Pour les autres plateformes, utiliser getExternalStorageDirectory
      final ext = await getExternalStorageDirectory();
      if (ext != null) {
        final parts = ext.path.split('/');
        int androidIndex = parts.indexOf('Android');
        String base;
        if (androidIndex > 0) {
          base = parts.sublist(0, androidIndex).join('/');
        } else {
          base = ext.path;
        }
        if (base.isEmpty) base = '/storage/emulated/0';
        final dir = Directory('$base/casaNayo/documents');
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        return dir;
      }
    } catch (e) {
      print("Erreur lors de la création du répertoire: $e");
    }

    // Fallback: répertoire documents applicatif
    final docs = await getApplicationDocumentsDirectory();
    final fallbackDir = Directory('${docs.path}/casaNayo/documents');
    if (!await fallbackDir.exists()) {
      await fallbackDir.create(recursive: true);
    }
    return fallbackDir;
  }

  Future<void> _downloadReservationPdf(ReservationModel reservation) async {
    try {
      final bytes = await _buildReservationPdfBytes(reservation);
      final dir = await _getExportDir();
      final userName = reservation.user?.username?.toString() ?? 
          reservation.user?.email?.toString()?.split('@').first ?? 
          'Client';
      final dateStr = reservation.startDate != null 
          ? DateFormat('dd-MM-yyyy').format(DateTime.parse(reservation.startDate!))
          : 'date';
      final timeStr = reservation.reservationHeure?.replaceAll(':', '-') ?? 'heure';
      final baseName = '${userName.replaceAll(' ', '_')}_$dateStr\_$timeStr';
      final filePath = '${dir.path}/reservation_$baseName.pdf';
      final file = File(filePath);
      await file.writeAsBytes(bytes, flush: true);
      FancyNotification.show(
        context,
        "PDF enregistré dans ${dir.path}",
        isError: false,
        type: NotificationType.success,
      );
    } catch (e) {
      FancyNotification.show(context, "Impossible de générer le PDF");
    }
  }

  Future<void> _shareReservationPdf(ReservationModel reservation) async {
    try {
      final bytes = await _buildReservationPdfBytes(reservation);
      final userName = reservation.user?.username?.toString() ?? 
          reservation.user?.email?.toString()?.split('@').first ?? 
          'Client';
      final dateStr = reservation.startDate != null 
          ? DateFormat('dd-MM-yyyy').format(DateTime.parse(reservation.startDate!))
          : 'date';
      final timeStr = reservation.reservationHeure?.replaceAll(':', '-') ?? 'heure';
      final baseName = '${userName.replaceAll(' ', '_')}_$dateStr\_$timeStr';
      final xfile = XFile.fromData(
        bytes,
        mimeType: 'application/pdf',
        name: 'reservation_$baseName.pdf',
      );
      await Share.shareXFiles(
        [xfile],
        text: "Confirmation de réservation - ${reservation.property?.title ?? 'Propriété'}",
      );
    } catch (e) {
      FancyNotification.show(context, "Partage du PDF impossible");
    }
  }
}