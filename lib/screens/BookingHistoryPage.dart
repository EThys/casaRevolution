import 'package:cached_network_image/cached_network_image.dart';
import 'package:casa/models/ReservationModel.dart';
import 'package:casa/screens/PropertyDetailPage.dart';
import 'package:casa/utils/Constantes.dart';
import 'package:casa/utils/FancyNotification.dart';
import 'package:casa/utils/Routes.dart';
import 'package:casa/utils/StockageKeys.dart';
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../controllers/ReservationController.dart';
import '../utils/networkCheck.dart';

class BookingHistoryPage extends StatefulWidget {
  const BookingHistoryPage({Key? key}) : super(key: key);

  @override
  _BookingHistoryPageState createState() => _BookingHistoryPageState();
}

class _BookingHistoryPageState extends State<BookingHistoryPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoadingData = true;
  final DateFormat _dateFormat = DateFormat('EEEE d MMMM y', 'fr_FR');
  final DateFormat _timeFormat = DateFormat('HH:mm', 'fr_FR');
  final TextEditingController _reasonController = TextEditingController();
  final GetStorage storage = GetStorage();
  bool _isLoading = false;
  AutovalidateMode _autoValidateMode = AutovalidateMode.disabled;

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadReservations();
  }

  Widget _buildShimmerEffect() {
    return ListView.separated(
      padding: EdgeInsets.all(20),
      itemCount: 3,
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
            height: 250,
          ),
        );
      },
    );
  }

  Future<void> _loadReservations() async {
    try {
      if (!mounted) return;

      setState(() => _isLoadingData = true);

      final reservationCtrl = Provider.of<ReservationController>(context, listen: false);
      await reservationCtrl.getAllReservations();
      print("Réservations chargées: ${reservationCtrl.reservations.length}");
    } catch (e) {
      print("Erreur lors du chargement des réservations: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoadingData = false);
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reservationCtrl = Provider.of<ReservationController>(context);

    return Scaffold(
      backgroundColor: _lightGrey,
      appBar: _buildReservationsAppBar(),
      body: Column(
        children: [
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildReservationList(_filterReservations(reservationCtrl.reservations, 'PENDING')),
                _buildReservationList(_filterReservations(reservationCtrl.reservations, 'CONFIRMED')),
                _buildReservationList(_filterReservations(reservationCtrl.reservations, 'CANCELLED')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildReservationsAppBar() {
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
          Icon(Icons.book_online, color: Colors.white, size: 20),
          SizedBox(width: 8),
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
        IconButton(
          icon: Icon(Icons.refresh, color: Colors.white),
          onPressed: _loadReservations,
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
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        labelColor: _primaryColor,
        unselectedLabelColor: _mediumGrey,
        indicatorColor: _primaryColor,
        indicatorWeight: 3,
        indicatorSize: TabBarIndicatorSize.tab,
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
            icon: Icon(Icons.pending_actions, size: 20),
            text: 'En attente',
          ),
          Tab(
            icon: Icon(Icons.check_circle_outline, size: 20),
            text: 'Confirmées',
          ),
          Tab(
            icon: Icon(Icons.cancel_outlined, size: 20),
            text: 'Annulées',
          ),
        ],
      ),
    );
  }

  List<ReservationModel> _filterReservations(List<ReservationModel> reservations, String status) {
    return reservations.where((reservation) => reservation.status == status).toList();
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
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
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReservationDetails(ReservationModel reservation) {
    final isPending = reservation.status == 'PENDING';
    final isCancelled = reservation.status == 'CANCELLED';

    // Utilisation des images de la propriété
    final firstImage = reservation.property?.propertyImage?.isNotEmpty ?? false
        ? reservation.property!.propertyImage!.first
        : null;
    final imageUrl = firstImage != null
        ? "${Constantes.URL_IMAGES}${firstImage.path ?? firstImage.path}"
        : null;

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
                Text(
                  'Détails de la réservation',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: _darkColor,
                  ),
                ),
                SizedBox(height: 20),
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
                      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                      child: CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        placeholder: (context, url) => Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _primaryColor,
                          ),
                        ),
                        errorWidget: (context, url, error) => Center(
                          child: Icon(Icons.home, size: 50, color: _mediumGrey),
                        ),
                      ),
                    )
                        : Center(
                      child: Icon(Icons.home, size: 50, color: _mediumGrey),
                    ),
                  ),
                ),
                SizedBox(height: 20),
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
                    Text(
                      "${reservation.property?.address ?? 'Adresse non disponible'}",
                      style: TextStyle(
                        color: _mediumGrey,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20),
                Divider(height: 1, color: Colors.grey[200]),
                SizedBox(height: 15),
                _buildDetailRow(
                  icon: Icons.date_range,
                  label: 'Date de début',
                  value: reservation.startDate ?? 'Non spécifiée',
                ),
                _buildDetailRow(
                  icon: Icons.date_range,
                  label: 'Date de fin',
                  value: reservation.endDate ?? 'Non spécifiée',
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
                  icon: Icons.info_outline_rounded,
                  label: 'Statut',
                  value: _getStatusText(reservation.status),
                  valueColor: _getStatusColor(reservation.status),
                ),
                if (isCancelled && reservation.cancellationReason != null)
                  _buildDetailRow(
                    icon: Icons.cancel_outlined,
                    label: 'Motif d\'annulation',
                    value: reservation.cancellationReason!,
                    valueColor: _errorColor,
                  ),
                SizedBox(height: 15),
                Divider(height: 1, color: Colors.grey[200]),
                SizedBox(height: 15),
                Text(
                  'Caractéristiques de la propriété',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _darkColor,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  '${reservation.property?.bedrooms ?? 0} chambres · ${reservation.property?.surface ?? 0}m² · ${reservation.property?.floor ?? 0}ème étage',
                  style: TextStyle(
                    color: _darkColor.withOpacity(0.8),
                    fontSize: 15,
                  ),
                ),
                SizedBox(height: 25),
                if (isPending)
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
                      child: Text(
                        'ANNULER LA RÉSERVATION',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
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

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'PENDING':
        return _warningColor;
      case 'CONFIRMED':
        return _successColor;
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
      _isLoadingData = true;
    });

    FocusScope.of(context).unfocus();

    final isConnected = await NetworkUtils.checkInternetConnectivity();
    if (!isConnected) {
      FancyNotification.show(context, "Pas de connexion internet");
      setState(() => _isLoading = false);
      return;
    }

    try {
      final reservationCtrl = Provider.of<ReservationController>(context, listen: false);
      final response = await reservationCtrl.cancelReservation(
        reservation.reservationId!,
        reason,
      );

      if (!mounted) return;

      if (response == 200) {
        FancyNotification.show(context, "Réservation annulée avec succès", isError: false);

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
      print("Erreur d'annulation: $e");
      FancyNotification.show(context, "Erreur technique lors de l'annulation");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingData = false;
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.book_online_outlined,
            size: 60,
            color: _mediumGrey.withOpacity(0.3),
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
              _tabController.index == 0
                  ? 'Vous n\'avez pas de réservation en attente'
                  : _tabController.index == 1
                  ? 'Aucune réservation confirmée'
                  : 'Aucune réservation annulée',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _mediumGrey.withOpacity(0.8),
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReservationListContent(List<ReservationModel> reservations) {
    return RefreshIndicator(
      color: _primaryColor,
      backgroundColor: Colors.white,
      onRefresh: _loadReservations,
      child: ListView.separated(
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
                Text(
                  'Annuler la réservation',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _darkColor,
                  ),
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

  Widget _buildReservationCard(ReservationModel reservation) {
    final isPending = reservation.status == 'PENDING';
    final isCancelled = reservation.status == 'CANCELLED';

    // Utilisation des images de la propriété
    final firstImage = reservation.property?.propertyImage?.isNotEmpty ?? false
        ? reservation.property!.propertyImage!.first
        : null;
    final imageUrl = firstImage != null
        ? "${Constantes.URL_IMAGES}${firstImage.path ?? firstImage.path}"
        : null;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => _showReservationDetails(reservation),
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
        child: Column(
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
                      placeholder: (context, url) => Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _primaryColor,
                        ),
                      ),
                      errorWidget: (context, url, error) => Center(
                        child: Icon(Icons.home, size: 50, color: _mediumGrey),
                      ),
                    ),
                  )
                      : Center(
                    child: Icon(Icons.home, size: 50, color: _mediumGrey),
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
                  Row(
                    children: [
                      Icon(
                        Icons.date_range,
                        size: 18,
                        color: _mediumGrey,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${reservation.startDate ?? 'N/A'} - ${reservation.endDate ?? 'N/A'}',
                          style: TextStyle(
                            color: _darkColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (isPending)
                        InkWell(
                          onTap: () {
                            _showCancelConfirmationDialog(reservation);
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _errorColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.cancel_outlined,
                                  size: 20,
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
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}