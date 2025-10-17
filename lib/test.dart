import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class BookingHistoryPage extends StatefulWidget {
  const BookingHistoryPage({Key? key}) : super(key: key);

  @override
  _BookingHistoryPageState createState() => _BookingHistoryPageState();
}

class _BookingHistoryPageState extends State<BookingHistoryPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<Reservation> _reservations = [];
  final DateFormat _dateFormat = DateFormat('EEEE d MMMM y', 'fr_FR');
  final DateFormat _timeFormat = DateFormat('HH:mm', 'fr_FR');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadReservations();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadReservations() {
    // Données simulées - à remplacer par votre appel API
    setState(() {
      _reservations.addAll([
        Reservation(
          id: '1',
          propertyTitle: 'Appartement lumineux à Paris',
          propertyImage: 'https://source.unsplash.com/random/300x200/?apartment,1',
          date: DateTime.now().add(Duration(days: 2)),
          status: ReservationStatus.pending,
          address: '15 Rue de Rivoli, 75004 Paris',
        ),
        Reservation(
          id: '2',
          propertyTitle: 'Studio moderne hypercentre',
          propertyImage: 'https://source.unsplash.com/random/300x200/?studio,1',
          date: DateTime.now().subtract(Duration(days: 3)),
          status: ReservationStatus.completed,
          address: '22 Rue Montorgueil, 75001 Paris',
        ),
        Reservation(
          id: '3',
          propertyTitle: 'Duplex loft Marais',
          propertyImage: 'https://source.unsplash.com/random/300x200/?loft,1',
          date: DateTime.now().subtract(Duration(days: 10)),
          status: ReservationStatus.cancelled,
          address: '40 Rue des Archives, 75004 Paris',
          cancellationReason: 'Changement de programme',
        ),
        Reservation(
          id: '4',
          propertyTitle: 'Appartement haussmannien',
          propertyImage: 'https://source.unsplash.com/random/300x200/?haussmann,1',
          date: DateTime.now().add(Duration(days: 5)),
          status: ReservationStatus.pending,
          address: '12 Avenue de l\'Opéra, 75002 Paris',
        ),
        Reservation(
          id: '5',
          propertyTitle: 'Maison avec jardin',
          propertyImage: 'https://source.unsplash.com/random/300x200/?house,1',
          date: DateTime.now().subtract(Duration(days: 15)),
          status: ReservationStatus.completed,
          address: '5 Rue des Jardins, 75016 Paris',
        ),
      ]);
    });
  }

  List<Reservation> _getFilteredReservations(ReservationStatus status) {
    return _reservations.where((r) => r.status == status).toList();
  }

  void _cancelReservation(String id) {
    setState(() {
      final reservation = _reservations.firstWhere((r) => r.id == id);
      reservation.status = ReservationStatus.cancelled;
      reservation.cancellationReason = 'Annulé par l\'utilisateur';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Réservation annulée'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showReservationDetails(Reservation reservation) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return _buildReservationDetails(reservation);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Mes Réservations',
          style: TextStyle(
            color: Color(0xFF1A1D26),
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Color(0xFF4A6BFF),
          unselectedLabelColor: Color(0xFF6C757D),
          indicatorColor: Color(0xFF4A6BFF),
          tabs: [
            Tab(text: 'À venir'),
            Tab(text: 'Passées'),
            Tab(text: 'Annulées'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Onglet "À venir"
          _buildReservationList(_getFilteredReservations(ReservationStatus.pending)),

          // Onglet "Passées"
          _buildReservationList(_getFilteredReservations(ReservationStatus.completed)),

          // Onglet "Annulées"
          _buildReservationList(_getFilteredReservations(ReservationStatus.cancelled)),
        ],
      ),
    );
  }

  Widget _buildReservationList(List<Reservation> reservations) {
    if (reservations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/empty.svg',
              height: 150,
              color: Color(0xFF6C757D).withOpacity(0.5),
            ),
            SizedBox(height: 16),
            Text(
              'Aucune réservation',
              style: TextStyle(
                color: Color(0xFF6C757D),
                fontSize: 18,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        // Simuler un rafraîchissement
        await Future.delayed(Duration(seconds: 1));
        _loadReservations();
      },
      child: ListView.separated(
        padding: EdgeInsets.all(16),
        itemCount: reservations.length,
        separatorBuilder: (context, index) => SizedBox(height: 16),
        itemBuilder: (context, index) {
          final reservation = reservations[index];
          return _buildReservationCard(reservation);
        },
      ),
    );
  }

  Widget _buildReservationCard(Reservation reservation) {
    final isPending = reservation.status == ReservationStatus.pending;
    final isCancelled = reservation.status == ReservationStatus.cancelled;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showReservationDetails(reservation),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      reservation.propertyImage,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: 80,
                        height: 80,
                        color: Colors.grey[200],
                        child: Icon(Icons.home, color: Colors.grey),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          reservation.propertyTitle,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Color(0xFF1A1D26),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 4),
                        Text(
                          reservation.address,
                          style: TextStyle(
                            color: Color(0xFF6C757D),
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today_rounded,
                              size: 16,
                              color: Color(0xFF6C757D),
                            ),
                            SizedBox(width: 4),
                            Text(
                              _dateFormat.format(reservation.date),
                              style: TextStyle(
                                color: Color(0xFF6C757D),
                                fontSize: 14,
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(
                              Icons.access_time_rounded,
                              size: 16,
                              color: Color(0xFF6C757D),
                            ),
                            SizedBox(width: 4),
                            Text(
                              _timeFormat.format(reservation.date),
                              style: TextStyle(
                                color: Color(0xFF6C757D),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getStatusColor(reservation.status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _getStatusText(reservation.status),
                      style: TextStyle(
                        color: _getStatusColor(reservation.status),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Spacer(),
                  if (isPending)
                    TextButton(
                      onPressed: () => _cancelReservation(reservation.id),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      ),
                      child: Text(
                        'ANNULER',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
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
  }

  Widget _buildReservationDetails(Reservation reservation) {
    final isPending = reservation.status == ReservationStatus.pending;
    final isCancelled = reservation.status == ReservationStatus.cancelled;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: EdgeInsets.all(24),
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
            SizedBox(height: 24),
            Text(
              'Détails de la réservation',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1D26),
              ),
            ),
            SizedBox(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    reservation.propertyImage,
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 80,
                      height: 80,
                      color: Colors.grey[200],
                      child: Icon(Icons.home, color: Colors.grey),
                    ),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reservation.propertyTitle,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Color(0xFF1A1D26),
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        reservation.address,
                        style: TextStyle(
                          color: Color(0xFF6C757D),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 24),
            _buildDetailRow(
              icon: Icons.calendar_today_rounded,
              label: 'Date',
              value: _dateFormat.format(reservation.date),
            ),
            _buildDetailRow(
              icon: Icons.access_time_rounded,
              label: 'Heure',
              value: _timeFormat.format(reservation.date),
            ),
            _buildDetailRow(
              icon: Icons.info_outline_rounded,
              label: 'Statut',
              value: _getStatusText(reservation.status),
              valueColor: _getStatusColor(reservation.status),
            ),
            if (isCancelled && reservation.cancellationReason != null)
              _buildDetailRow(
                icon: Icons.close_rounded,
                label: 'Motif d\'annulation',
                value: reservation.cancellationReason!,
                valueColor: Colors.red,
              ),
            SizedBox(height: 32),
            if (isPending)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _cancelReservation(reservation.id);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.withOpacity(0.1),
                    foregroundColor: Colors.red,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(
                    'ANNULER LA RÉSERVATION',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            SizedBox(height: 8),
          ],
        ),
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
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(
            icon,
            size: 24,
            color: Color(0xFF6C757D),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Color(0xFF6C757D),
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    color: valueColor ?? Color(0xFF1A1D26),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(ReservationStatus status) {
    switch (status) {
      case ReservationStatus.pending:
        return Color(0xFFFFA726); // Orange
      case ReservationStatus.completed:
        return Color(0xFF66BB6A); // Vert
      case ReservationStatus.cancelled:
        return Color(0xFFEF5350); // Rouge
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
}

enum ReservationStatus {
  pending,
  completed,
  cancelled,
}

class Reservation {
  final String id;
  final String propertyTitle;
  final String propertyImage;
  final String address;
  final DateTime date;
  ReservationStatus status;
  String? cancellationReason;

  Reservation({
    required this.id,
    required this.propertyTitle,
    required this.propertyImage,
    required this.address,
    required this.date,
    required this.status,
    this.cancellationReason,
  });
}