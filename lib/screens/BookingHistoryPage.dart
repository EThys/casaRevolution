import 'package:cached_network_image/cached_network_image.dart';
import 'package:casa/controllers/PropertyVisitCtrl.dart';
import 'package:casa/models/PropertyVisitModel.dart';
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
    print("aliceeeeeeeeeeee");
    _loadVisits();
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

  Future<void> _loadVisits() async {
    try {
      if (!mounted) return;

      setState(() => _isLoadingData = true);

      final userId = storage.read(StockageKeys.userKey)?['UserId'];
      if (userId != null) {
        final propertyCtrl = Provider.of<PropertyVisitCtrl>(context, listen: false);
        await propertyCtrl.getVisitsByUser(userId.toString());
        print("Visites chargées: ${propertyCtrl.propertyVisits.length}"); // Debug
      }
    } catch (e) {
      print("Erreur lors du c hargement des visites: $e");
      // Vous pourriez aussi afficher un message d'erreur à l'utilisateur
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
    final propertyCtrl = Provider.of<PropertyVisitCtrl>(context);

    return Scaffold(
      backgroundColor: _lightGrey,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Mes Visites',
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
          _buildVisitList(_filterVisits(propertyCtrl.propertyVisits, 'pending')),
          _buildVisitList(_filterVisits(propertyCtrl.propertyVisits, 'validated')),
          _buildVisitList(_filterVisits(propertyCtrl.propertyVisits, 'cancelled')),
        ],
      ),
    );
  }

  List<PropertyVisitModel> _filterVisits(List<PropertyVisitModel> visits, String status) {
    return visits.where((visit) => visit.status == status).toList();
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

  Widget _buildVisitDetails(PropertyVisitModel visit) {
    final isForRent = visit.property.transactionType == 'location';
    final isPending = visit.status == 'pending';
    final isCancelled = visit.status == 'cancelled';

    final firstImagePath = visit.property.images!.isNotEmpty
        ? visit.property.images!.first.path
        : null;

    final priceText = isForRent
        ? '${visit.property.price?.toStringAsFixed(0) ?? '0'}\$/mois'
        : '${visit.property.price?.toStringAsFixed(0) ?? '0'}\$';

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
                  'Détails de la visite',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: _darkColor,
                  ),
                ),
                SizedBox(height: 20),
                GestureDetector(
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      Routes.detailPageRoute,
                      arguments: visit.property,
                    );
                  },
                  child: Container(
                    height: 180,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      color: _lightGrey,
                    ),
                    child: firstImagePath != null
                        ? ClipRRect(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                      child: CachedNetworkImage(
                        imageUrl: "${Constantes.URL_IMAGES}${firstImagePath}",
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
                  "${visit.property.title}",
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
                      "${visit.property.address}",
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
                  value: _dateFormat.format(visit.visitDate),
                ),
                _buildDetailRow(
                  icon: Icons.access_time_outlined,
                  label: 'Heure',
                  value: visit.visitHour,
                ),
                _buildDetailRow(
                  icon: Icons.attach_money,
                  label: 'Prix',
                  value: '${priceText}',
                ),
                _buildDetailRow(
                  icon: Icons.info_outline_rounded,
                  label: 'Statut',
                  value: _getStatusText(visit.status),
                  valueColor: _getStatusColor(visit.status),
                ),
                if (isCancelled && visit.cancellationReason != null)
                  _buildDetailRow(
                    icon: Icons.cancel_outlined,
                    label: 'Motif d\'annulation',
                    value: visit.cancellationReason!,
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
                  '${visit.property.bedrooms} chambres · ${visit.property.surface}m² · ${visit.property.floor}ème étage',
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
                        _showCancelConfirmationDialog(visit);
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
                        'ANNULER LA VISITE',
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


  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return _warningColor;
      case 'validated':
        return _successColor;
      case 'cancelled':
        return _errorColor;
      default:
        return _mediumGrey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'En attente';
      case 'validated':
        return 'Déjà visité';
      case 'cancelled':
        return 'Annulée';
      default:
        return status;
    }
  }

  Future<void> _cancelVisit(PropertyVisitModel visit, String reason) async {
    if (!mounted || _isLoading) return;

    // Supprimez immédiatement la visite de la liste avant l'animation
    final propertyCtrl = Provider.of<PropertyVisitCtrl>(context, listen: false);
    propertyCtrl.removeVisit(visit.propertyVisitId.toString());

    setState(() {
      _isLoading = true;
      _isLoadingData = true;
    });

    FocusScope.of(context).unfocus();

    final isConnected = await NetworkUtils.checkInternetConnectivity();
    if (!isConnected) {
      FancyNotification.show(context, "Pas de connexion internet");
      setState(() => _isLoading = false);
      // Remettre la visite si échec
      propertyCtrl.addVisit(visit);
      return;
    }

    try {
      final requestData = {
        'status': 'cancelled',
        'cancellation_reason': reason,
      };

      final response = await propertyCtrl.changeVisitStatus(
        visitId: visit.propertyVisitId.toString(),
        requestData: requestData,
      );

      if (!mounted) return;

      if (response.status == 200 && response.data['success'] == true) {
        FancyNotification.show(context, "Visite annulée avec succès", isError: false);

        // Recharger les données
        await _loadVisits();

        if (mounted) {
          Navigator.of(context).pop(); // Fermer le bottom sheet des détails
        }
      } else {
        String errorMsg = response.data['message'] ?? "Échec de l'annulation";
        FancyNotification.show(context, errorMsg);
        // Remettre la visite si échec
        propertyCtrl.addVisit(visit);
      }
    } catch (e) {
      print("Erreur d'annulation: $e");
      FancyNotification.show(context, "Erreur technique lors de l'annulation");
      // Remettre la visite si erreur
      propertyCtrl.addVisit(visit);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingData = false;
        });
      }
    }
  }


  void _showVisitDetails(PropertyVisitModel visit) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildVisitDetails(visit),
    );
  }

  Widget _buildVisitList(List<PropertyVisitModel> visits) {
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
          : visits.isEmpty
          ? _buildEmptyState()
          : _buildVisitListContent(visits),
    );
  }

  Widget _buildEmptyState() {
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
            'Aucune visite',
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
                  ? 'Vous n\'avez pas de visite à venir'
                  : _tabController.index == 1
                  ? 'Aucune visite passée'
                  : 'Aucune visite annulée',
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

  Widget _buildVisitListContent(List<PropertyVisitModel> visits) {
    return RefreshIndicator(
      color: _primaryColor,
      backgroundColor: Colors.white,
      onRefresh: _loadVisits,
      child: ListView.separated(
        padding: EdgeInsets.all(20),
        itemCount: visits.length,
        separatorBuilder: (_, __) => SizedBox(height: 20),
        itemBuilder: (context, index) {
          final visit = visits[index];
          return AnimatedSwitcher(
            duration: Duration(milliseconds: 300),
            child: _buildVisitCard(visit),
          );
        },
      ),
    );
  }

  void _showCancelConfirmationDialog(PropertyVisitModel visit) {
    // Créez un nouveau TextEditingController local pour ce dialogue
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
                  'Annuler la visite',
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
                  controller: reasonController, // Utilisez le contrôleur local
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
                        reasonController.dispose(); // Nettoyez le contrôleur
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
                          await _cancelVisit(visit,reasonController.text);
                          reasonController.dispose(); // Nettoyez le contrôleur
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

  Widget _buildVisitCard(PropertyVisitModel visit) {
    final isPending = visit.status == 'pending';
    final isCancelled = visit.status == 'cancelled';
    final isForRent = visit.property.transactionType == 'location';
    // Récupération de la première image de la propriété
    final firstImagePath = visit.property.images!.isNotEmpty
        ? visit.property.images!.first.path
        : null;

    final priceText = isForRent
        ? '${visit.property.price?.toStringAsFixed(0) ?? '0'}\$/mois'
        : '${visit.property.price?.toStringAsFixed(0) ?? '0'}\$';



    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => _showVisitDetails(visit),
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
                // Conteneur d'image avec CachedNetworkImage
                Container(
                  height: 180,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    color: _lightGrey,
                  ),
                  child: firstImagePath != null
                      ? ClipRRect(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    child: CachedNetworkImage(
                      imageUrl: "${Constantes.URL_IMAGES}${firstImagePath}",
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
                      '${priceText}',
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
                      color: _getStatusColor(visit.status).withOpacity(0.9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _getStatusText(visit.status),
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
                    "${visit.property.title}",
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
                         "${visit.property.address}",
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
                        _dateFormat.format(visit.visitDate),
                        style: TextStyle(
                          color: _darkColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Spacer(),
                      if (isPending)
                        InkWell(
                          onTap: () {
                            print("TESTTTTTTTT${Constantes.URL_IMAGES}${firstImagePath}");
                            _showCancelConfirmationDialog(visit);
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
                                  Icons.delete_outline,
                                  size: 20,
                                  color: _errorColor,
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