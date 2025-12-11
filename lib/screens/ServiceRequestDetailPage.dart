import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/ServiceRequestModel.dart';
import '../models/ServiceRequestResponseModel.dart';
import '../models/ServiceModel.dart';
import '../controllers/ServiceRequestController.dart';
import '../utils/FancyNotification.dart';
import '../utils/networkCheck.dart';

class ServiceRequestDetailPage extends StatefulWidget {
  final ServiceRequestModel request;

  const ServiceRequestDetailPage({
    Key? key,
    required this.request,
  }) : super(key: key);

  @override
  _ServiceRequestDetailPageState createState() => _ServiceRequestDetailPageState();
}

class _ServiceRequestDetailPageState extends State<ServiceRequestDetailPage> {
  final Color _primaryColor = Color(0xFF1976D2);
  final Color _primaryDark = Color(0xFF1565C0);
  final Color _textPrimary = Color(0xFF1A1A1A);
  final Color _textSecondary = Color(0xFF666666);
  final Color _successColor = Color(0xFF00B894);
  final Color _warningColor = Color(0xFFFFA000);

  bool _isLoading = false;
  ServiceRequestModel? _currentRequest;

  @override
  void initState() {
    super.initState();
    _currentRequest = widget.request;
    _loadRequestDetails();
  }

  Future<void> _loadRequestDetails() async {
    if (_currentRequest?.requestId == null) return;

    final controller = context.read<ServiceRequestController>();
    setState(() => _isLoading = true);

    final request = await controller.fetchRequestById(_currentRequest!.requestId!);
    if (request != null) {
      setState(() {
        _currentRequest = request;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _acceptResponse(ServiceRequestResponseModel response) async {
    if (_currentRequest?.requestId == null || response.responseId == null) return;

    final isConnected = await NetworkUtils.checkInternetConnectivity();
    if (!isConnected) {
      FancyNotification.show(
        context,
        'Pas de connexion internet',
        type: NotificationType.error,
      );
      return;
    }

    final controller = context.read<ServiceRequestController>();
    setState(() => _isLoading = true);

    final result = await controller.acceptResponse(
      requestId: _currentRequest!.requestId!,
      responseId: response.responseId!,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.status) {
      FancyNotification.show(
        context,
        'Réponse acceptée avec succès',
        type: NotificationType.success,
      );
      await _loadRequestDetails();
    } else {
      FancyNotification.show(
        context,
        result.errorMsg ?? 'Erreur lors de l\'acceptation',
        type: NotificationType.error,
      );
    }
  }

  Future<void> _contactProvider(String? phone) async {
    if (phone == null || phone.isEmpty) {
      FancyNotification.show(
        context,
        'Numéro de téléphone non disponible',
        type: NotificationType.warning,
      );
      return;
    }

    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      FancyNotification.show(
        context,
        'Impossible d\'ouvrir l\'application téléphone',
        type: NotificationType.error,
      );
    }
  }

  Future<void> _openWhatsApp(String? phone) async {
    if (phone == null || phone.isEmpty) {
      FancyNotification.show(
        context,
        'Numéro WhatsApp non disponible',
        type: NotificationType.warning,
      );
      return;
    }

    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri.parse('https://wa.me/$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      FancyNotification.show(
        context,
        'Impossible d\'ouvrir WhatsApp',
        type: NotificationType.error,
      );
    }
  }

  String _getTimeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) return 'À l\'instant';
        return 'Il y a ${difference.inMinutes} ${difference.inMinutes > 1 ? 'minutes' : 'minute'}';
      }
      return 'Aujourd\'hui à ${date.hour.toString().padLeft(2, '0')}h${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Hier à ${date.hour.toString().padLeft(2, '0')}h${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays < 7) {
      return 'Il y a ${difference.inDays} ${difference.inDays > 1 ? 'jours' : 'jour'}';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return 'Il y a ${weeks} ${weeks > 1 ? 'semaines' : 'semaine'}';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return 'Il y a ${months} ${months > 1 ? 'mois' : 'mois'}';
    } else {
      final years = (difference.inDays / 365).floor();
      return 'Il y a ${years} ${years > 1 ? 'ans' : 'an'}';
    }
  }

  String _getStatusText(String? status) {
    switch (status?.toUpperCase()) {
      case 'PENDING':
        return 'En attente';
      case 'ACCEPTED':
        return 'Acceptée';
      case 'DECLINED':
        return 'Refusée';
      case 'COMPLETED':
        return 'Terminée';
      case 'CANCELLED':
        return 'Annulée';
      default:
        return 'Inconnu';
    }
  }

  Color _getStatusColor(String? status) {
    switch (status?.toUpperCase()) {
      case 'PENDING':
        return _warningColor;
      case 'ACCEPTED':
        return _successColor;
      case 'DECLINED':
      case 'CANCELLED':
        return Colors.red;
      case 'COMPLETED':
        return _primaryColor;
      default:
        return _textSecondary;
    }
  }

  ServiceType _getServiceType() {
    if (_currentRequest?.serviceType == null) return ServiceType.reparation;
    return ServiceTypeExtension.fromString(_currentRequest!.serviceType);
  }

  Widget _buildHeader() {
    final serviceType = _getServiceType();
    final isAccepted = _currentRequest?.status?.toUpperCase() == 'ACCEPTED';
    final isCompleted = _currentRequest?.status?.toUpperCase() == 'COMPLETED';

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_primaryColor, _primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
                Expanded(
                  child: Text(
                    'Détails de la demande',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _getStatusText(_currentRequest?.status),
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    serviceType.icon,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        serviceType.displayName,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (_currentRequest?.isUrgent == true) ...[
                        SizedBox(height: 4),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.priority_high, color: Colors.white, size: 14),
                              SizedBox(width: 4),
                              Text(
                                'Urgent',
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (_currentRequest?.createdAt != null) ...[
              SizedBox(height: 12),
              Text(
                _getTimeAgo(_currentRequest!.createdAt!),
                style: GoogleFonts.inter(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRequestInfo() {
    return Container(
      margin: EdgeInsets.all(20),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: _primaryColor.withOpacity(0.1),
                backgroundImage: _currentRequest?.userAvatar != null
                    ? CachedNetworkImageProvider(_currentRequest!.userAvatar!)
                    : null,
                child: _currentRequest?.userAvatar == null
                    ? Text(
                        _currentRequest?.userName?.isNotEmpty == true
                            ? _currentRequest!.userName![0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          color: _primaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      )
                    : null,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _currentRequest?.userName ?? 'Utilisateur',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _textPrimary,
                      ),
                    ),
                    if (_currentRequest?.address != null) ...[
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.location_on, size: 14, color: _textSecondary),
                          SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              _currentRequest!.address!,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: _textSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (_currentRequest?.message != null && _currentRequest!.message!.isNotEmpty) ...[
            SizedBox(height: 20),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _currentRequest!.message!,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: _textPrimary,
                  height: 1.5,
                ),
              ),
            ),
          ],
          // Placeholder pour la carte (sera implémenté plus tard)
          if (_currentRequest?.latitude != null && _currentRequest?.longitude != null) ...[
            SizedBox(height: 16),
            Container(
              height: 150,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.map, size: 40, color: _textSecondary),
                    SizedBox(height: 8),
                    Text(
                      'Carte non disponible',
                      style: GoogleFonts.inter(
                        color: _textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResponseCard(ServiceRequestResponseModel response) {
    final isAccepted = response.status?.toUpperCase() == 'ACCEPTED';
    final isAcceptedResponse = _currentRequest?.acceptedResponseId == response.responseId;

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isAcceptedResponse
            ? Border.all(color: _successColor, width: 2)
            : Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: _primaryColor.withOpacity(0.1),
                backgroundImage: response.providerAvatar != null
                    ? CachedNetworkImageProvider(response.providerAvatar!)
                    : null,
                child: response.providerAvatar == null
                    ? Text(
                        response.providerName?.isNotEmpty == true
                            ? response.providerName![0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          color: _primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            response.providerName ?? 'Prestataire',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: _textPrimary,
                            ),
                          ),
                        ),
                        if (isAcceptedResponse)
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _successColor,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Acceptée',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (response.createdAt != null) ...[
                      SizedBox(height: 4),
                      Text(
                        _getTimeAgo(response.createdAt!),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: _textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (response.message != null && response.message!.isNotEmpty) ...[
            SizedBox(height: 12),
            Text(
              response.message!,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: _textPrimary,
                height: 1.5,
              ),
            ),
          ],
          if (response.price != null || response.estimatedTime != null) ...[
            SizedBox(height: 12),
            Row(
              children: [
                if (response.price != null) ...[
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.attach_money, size: 16, color: _primaryColor),
                        SizedBox(width: 4),
                        Text(
                          '${NumberFormat.currency(locale: 'fr_FR', symbol: '', decimalDigits: 0).format(response.price)} CDF',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 8),
                ],
                if (response.estimatedTime != null) ...[
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.access_time, size: 16, color: Colors.orange),
                        SizedBox(width: 4),
                        Text(
                          response.estimatedTime!,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ],
          SizedBox(height: 12),
          Row(
            children: [
              if (_currentRequest?.status?.toUpperCase() == 'PENDING' && !isAcceptedResponse) ...[
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _acceptResponse(response),
                    icon: Icon(Icons.check_circle, size: 18),
                    label: Text('Accepter'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _successColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                SizedBox(width: 8),
              ],
              if (response.providerPhone != null && response.providerPhone!.isNotEmpty) ...[
                OutlinedButton.icon(
                  onPressed: () => _openWhatsApp(response.providerPhone),
                  icon: Icon(Icons.message, size: 18),
                  label: Text('WhatsApp'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _primaryColor,
                    side: BorderSide(color: _primaryColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  ),
                ),
                SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => _contactProvider(response.providerPhone),
                  child: Icon(Icons.phone, size: 20),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _primaryColor,
                    side: BorderSide(color: _primaryColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: EdgeInsets.all(12),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResponsesSection() {
    final responses = _currentRequest?.responses ?? [];
    final hasResponses = responses.isNotEmpty;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Réponses des prestataires',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${responses.length}',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _primaryColor,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          if (!hasResponses)
            Container(
              padding: EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Icon(Icons.inbox_outlined, size: 64, color: _textSecondary),
                  SizedBox(height: 16),
                  Text(
                    'Aucune réponse pour le moment',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _textSecondary,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Les prestataires vont bientôt répondre à votre demande',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: _textSecondary,
                    ),
                  ),
                ],
              ),
            )
          else
            ...responses.map((response) => _buildResponseCard(response)).toList(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _primaryColor))
          : RefreshIndicator(
              onRefresh: _loadRequestDetails,
              color: _primaryColor,
              child: CustomScrollView(
                slivers: [
                  SliverAppBar(
                    expandedHeight: 200,
                    pinned: true,
                    flexibleSpace: _buildHeader(),
                    backgroundColor: _primaryColor,
                  ),
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        SizedBox(height: 20),
                        _buildRequestInfo(),
                        SizedBox(height: 20),
                        _buildResponsesSection(),
                        SizedBox(height: 20),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

