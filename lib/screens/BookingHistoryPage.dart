import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class BookingHistoryPage extends StatefulWidget {
  const BookingHistoryPage({Key? key}) : super(key: key);

  @override
  _BookingHistoryPageState createState() => _BookingHistoryPageState();
}

class _BookingHistoryPageState extends State<BookingHistoryPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<Reservation> _reservations = [];
  final DateFormat _dateFormat = DateFormat('EEEE d MMMM y', 'fr_FR');
  final DateFormat _timeFormat = DateFormat('HH:mm', 'fr_FR');
  final TextEditingController _reasonController = TextEditingController();

  // Couleurs modernes
  final Color _primaryColor = Color(0xFF1976D2);
  final Color darkBlue = Color(0xFF0D47A1);
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

  @override
  void dispose() {
    _tabController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  void _loadReservations() {
    setState(() {
      _reservations.addAll([
        Reservation(
          id: '1',
          propertyTitle: 'Appartement lumineux avec vue sur la tour Eiffel',
          propertyImage: 'assets/images/one.jpg',
          date: DateTime.now().add(Duration(days: 2)),
          status: ReservationStatus.pending,
          address: '15 Rue , 75004 Limete',
          price: 1200,
          features: '2 chambres · 75m² · 3ème étage',
          amenities: ['Wifi', 'Cuisine', 'TV', 'Climatisation'],
        ),
        Reservation(
          id: '2',
          propertyTitle: 'Studio design en hypercentre',
          propertyImage: 'assets/images/three.jpg',
          date: DateTime.now().subtract(Duration(days: 3)),
          status: ReservationStatus.completed,
          address: '2 Rue , 75001 Limete',
          price: 850,
          features: '1 chambre · 35m² · Rez-de-chaussée',
          amenities: ['Wifi', 'Espace de travail', 'Machine à laver'],
        ),
        Reservation(
          id: '3',
          propertyTitle: 'Duplex loft dans le Marais',
          propertyImage: 'assets/images/one.jpg',
          date: DateTime.now().subtract(Duration(days: 10)),
          status: ReservationStatus.cancelled,
          address: '40 Rue des Archives, 75004 Paris',
          price: 1500,
          features: '3 chambres · 110m² · 2ème étage',
          cancellationReason: 'Changement de programme',
          amenities: ['Wifi', 'Parking', 'Terrasse', 'Climatisation'],
        ),
        Reservation(
          id: '4',
          propertyTitle: 'Appartement haussmannien rénové',
          propertyImage: 'assets/images/two.jpg',
          date: DateTime.now().add(Duration(days: 5)),
          status: ReservationStatus.pending,
          address: '12 Avenue de l\'Opéra, 75002 Paris',
          price: 1800,
          features: '2 chambres · 90m² · 4ème étage',
          amenities: ['Wifi', 'Ascenseur', 'Cheminée', 'Vue dégagée'],
        ),
        Reservation(
          id: '5',
          propertyTitle: 'Maison avec jardin arboré',
          propertyImage: 'assets/images/three.jpg',
          date: DateTime.now().subtract(Duration(days: 15)),
          status: ReservationStatus.completed,
          address: '5 Rue des Jardins, 75016 Paris',
          price: 2500,
          features: '4 chambres · 150m² · Jardin 50m²',
          amenities: ['Wifi', 'Jardin', 'Piscine', 'Parking'],
        ),
      ]);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _lightGrey,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Text(
          'Mes Réservations',
          style: TextStyle(
            color: _darkColor,
            fontWeight: FontWeight.w700,
            fontSize: 19,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: _primaryColor,
          unselectedLabelColor: _mediumGrey,
          indicatorColor: _primaryColor,
          indicatorWeight: 3,
          labelStyle: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
          tabs: [
            Tab(text: 'À venir'),
            Tab(text: 'Passées'),
            Tab(text: 'Annulées'),
          ],
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(20),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildReservationList(_getFilteredReservations(ReservationStatus.pending)),
          _buildReservationList(_getFilteredReservations(ReservationStatus.completed)),
          _buildReservationList(_getFilteredReservations(ReservationStatus.cancelled)),
        ],
      ),
    );
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

  Widget _buildReservationDetails(Reservation reservation) {
    final isPending = reservation.status == ReservationStatus.pending;
    final isCancelled = reservation.status == ReservationStatus.cancelled;

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
                ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: Image.asset(
                    reservation.propertyImage,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 180,
                      color: _lightGrey,
                      child: Center(
                        child: Icon(Icons.home, size: 50, color: _mediumGrey),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 20),
                Text(
                  reservation.propertyTitle,
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
                      reservation.address,
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
                  icon: Icons.calendar_today_outlined,
                  label: 'Date',
                  value: _dateFormat.format(reservation.date),
                ),
                _buildDetailRow(
                  icon: Icons.access_time_outlined,
                  label: 'Heure',
                  value: _timeFormat.format(reservation.date),
                ),
                _buildDetailRow(
                  icon: Icons.attach_money
                  ,
                  label: 'Prix',
                  value: '${reservation.price}\$',
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
                  'Caractéristiques',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _darkColor,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  reservation.features,
                  style: TextStyle(
                    color: _darkColor.withOpacity(0.8),
                    fontSize: 15,
                  ),
                ),
                SizedBox(height: 15),
                if (reservation.amenities != null && reservation.amenities!.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Équipements',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _darkColor,
                        ),
                      ),
                      SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: reservation.amenities!
                            .map(
                              (amenity) => Chip(
                            label: Text(amenity),
                            backgroundColor: _chipBackground,
                            labelStyle: TextStyle(
                              color: _darkColor,
                              fontSize: 13,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        )
                            .toList(),
                      ),
                    ],
                  ),
                SizedBox(height: 25),
                if (isPending)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _showCancelConfirmationDialog(reservation.id);
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


  Color _getStatusColor(ReservationStatus status) {
    switch (status) {
      case ReservationStatus.pending:
        return _warningColor;
      case ReservationStatus.completed:
        return _successColor;
      case ReservationStatus.cancelled:
        return _errorColor;
    }
  }

  String _getStatusText(ReservationStatus status) {
    switch (status) {
      case ReservationStatus.pending:
        return 'En attente';
      case ReservationStatus.completed:
        return 'Terminée';
      case ReservationStatus.cancelled:
        return 'Annulée';
    }
  }

  List<Reservation> _getFilteredReservations(ReservationStatus status) {
    return _reservations.where((r) => r.status == status).toList();
  }

  void _cancelReservation(String id, String reason) {
    setState(() {
      final reservation = _reservations.firstWhere((r) => r.id == id);
      reservation.status = ReservationStatus.cancelled;
      reservation.cancellationReason = reason;
      _reasonController.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Réservation annulée'),
        backgroundColor: _errorColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  void _showReservationDetails(Reservation reservation) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildReservationDetails(reservation),
    );
  }

  Widget _buildReservationList(List<Reservation> reservations) {
    if (reservations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calendar_today_outlined,
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
                    ? 'Vous n\'avez pas de réservation à venir'
                    : _tabController.index == 1
                    ? 'Aucune réservation passée'
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

    return RefreshIndicator(
      color: _primaryColor,
      backgroundColor: Colors.white,
      onRefresh: () async {
        await Future.delayed(Duration(seconds: 1));
        _loadReservations();
      },
      child: ListView.separated(
        padding: EdgeInsets.all(20),
        itemCount: reservations.length,
        separatorBuilder: (_, __) => SizedBox(height: 20),
        itemBuilder: (context, index) {
          return _buildReservationCard(reservations[index]);
        },
      ),
    );
  }

  void _showCancelConfirmationDialog(String id) {
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
                  controller: _reasonController,
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
                      onPressed: () => Navigator.pop(context),
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
                      onPressed: () {
                        if (_reasonController.text.trim().isNotEmpty) {
                          Navigator.pop(context);
                          _cancelReservation(id, _reasonController.text);
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

  Widget _buildReservationCard(Reservation reservation) {
    final isPending = reservation.status == ReservationStatus.pending;
    final isCancelled = reservation.status == ReservationStatus.cancelled;

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
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  child: Image.asset(
                    reservation.propertyImage,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    // loadingBuilder: (context, child, loadingProgress) {
                    //   if (loadingProgress == null) return child;
                    //   return Container(
                    //     height: 180,
                    //     color: _lightGrey,
                    //     child: Center(
                    //       child: CircularProgressIndicator(
                    //         color: _primaryColor,
                    //         strokeWidth: 2,
                    //       ),
                    //     ),
                    //   );
                    // },
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 180,
                      color: _lightGrey,
                      child: Center(
                        child: Icon(
                          Icons.home_outlined,
                          size: 40,
                          color: _mediumGrey.withOpacity(0.5),
                        ),
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
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Text(
                      '${reservation.price}\$/${reservation.status == ReservationStatus.pending ? 'mois' : 'visite'}',
                      style: TextStyle(
                        color: _primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
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
              ],
            ),
            Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reservation.propertyTitle,
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
                          reservation.address,
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
                        Icons.calendar_today_outlined,
                        size: 18,
                        color: _mediumGrey,
                      ),
                      SizedBox(width: 8),
                      Text(
                        _dateFormat.format(reservation.date),
                        style: TextStyle(
                          color: _darkColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Spacer(),
                      if (isPending)
                        InkWell(
                          onTap: () => _showCancelConfirmationDialog(reservation.id),
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
                                  Icons.close,
                                  size: 16,
                                  color: _errorColor,
                                ),
                                SizedBox(width: 5),
                                Text(
                                  'Annuler',
                                  style: TextStyle(
                                    color: _errorColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
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

enum ReservationStatus { pending, completed, cancelled }

class Reservation {
  final String id;
  final String propertyTitle;
  final String propertyImage;
  final String address;
  final DateTime date;
  final int price;
  final String features;
  ReservationStatus status;
  String? cancellationReason;
  List<String>? amenities;

  Reservation({
    required this.id,
    required this.propertyTitle,
    required this.propertyImage,
    required this.address,
    required this.date,
    required this.status,
    required this.price,
    required this.features,
    this.cancellationReason,
    this.amenities,
  });
}