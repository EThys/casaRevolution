import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/ServiceRequestModel.dart';
import '../models/ServiceModel.dart';
import '../controllers/ServiceRequestController.dart';
import '../utils/FancyNotification.dart';
import '../utils/networkCheck.dart';
import 'ServiceRequestDetailPage.dart';
import 'ServiceRequestResponseDialog.dart';

class ServiceRequestsForProvidersPage extends StatefulWidget {
  const ServiceRequestsForProvidersPage({Key? key}) : super(key: key);

  @override
  _ServiceRequestsForProvidersPageState createState() => _ServiceRequestsForProvidersPageState();
}

class _ServiceRequestsForProvidersPageState extends State<ServiceRequestsForProvidersPage> {
  final Color _primaryColor = Color(0xFF1976D2);
  final Color _primaryDark = Color(0xFF1565C0);
  final Color _textPrimary = Color(0xFF1A1A1A);
  final Color _textSecondary = Color(0xFF666666);
  final Color _successColor = Color(0xFF00B894);
  final Color _warningColor = Color(0xFFFFA000);

  String _filterType = 'all'; // 'all', 'urgent', 'normal'
  bool _showRespondedOnly = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRequests();
    });
  }

  Future<void> _loadRequests() async {
    final controller = context.read<ServiceRequestController>();
    await controller.fetchProviderRequests();
  }

  List<ServiceRequestModel> _getFilteredRequests(ServiceRequestController controller) {
    var requests = controller.providerRequests;

    // Filtrer par urgence
    if (_filterType == 'urgent') {
      requests = requests.where((r) => r.isUrgent == true).toList();
    } else if (_filterType == 'normal') {
      requests = requests.where((r) => r.isUrgent != true).toList();
    }

    // Filtrer par réponses déjà envoyées
    if (_showRespondedOnly) {
      // TODO: Filtrer les demandes auxquelles le prestataire a déjà répondu
      // Pour l'instant, on garde toutes les demandes
    }

    return requests;
  }

  String _getTimeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) return 'À l\'instant';
        return 'Il y a ${difference.inMinutes} ${difference.inMinutes > 1 ? 'minutes' : 'minute'}';
      }
      return 'Aujourd\'hui';
    } else if (difference.inDays == 1) {
      return 'Hier';
    } else if (difference.inDays < 7) {
      return 'Il y a ${difference.inDays} ${difference.inDays > 1 ? 'jours' : 'jour'}';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return 'Il y a ${weeks} ${weeks > 1 ? 'semaines' : 'semaine'}';
    } else {
      return DateFormat('dd MMM yyyy', 'fr_FR').format(date);
    }
  }

  ServiceType _getServiceType(ServiceRequestModel request) {
    if (request.serviceType == null) return ServiceType.reparation;
    return ServiceTypeExtension.fromString(request.serviceType);
  }

  Future<void> _showResponseDialog(ServiceRequestModel request) async {
    if (request.requestId == null) return;

    final result = await showDialog(
      context: context,
      builder: (context) => ServiceRequestResponseDialog(
        requestId: request.requestId!,
      ),
    );

    if (result != null && result == true) {
      // Le dialog a été soumis, recharger les demandes
      await _loadRequests();
    }
  }

  Future<void> _respondToRequest(ServiceRequestModel request, {
    required String message,
    double? price,
    String? estimatedTime,
  }) async {
    if (request.requestId == null) return;

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
    final result = await controller.respondToRequest(
      requestId: request.requestId!,
      message: message,
      price: price,
      estimatedTime: estimatedTime,
    );

    if (!mounted) return;

    if (result.status) {
      FancyNotification.show(
        context,
        'Votre réponse a été envoyée avec succès',
        type: NotificationType.success,
      );
      await _loadRequests();
    } else {
      FancyNotification.show(
        context,
        result.errorMsg ?? 'Erreur lors de l\'envoi de la réponse',
        type: NotificationType.error,
      );
    }
  }

  Widget _buildRequestCard(ServiceRequestModel request) {
    final serviceType = _getServiceType(request);
    final responseCount = request.responses?.length ?? 0;
    final hasResponded = false; // TODO: Vérifier si le prestataire actuel a déjà répondu

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 2,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ServiceRequestDetailPage(request: request),
            ),
          ).then((_) => _loadRequests());
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      serviceType.icon,
                      color: _primaryColor,
                      size: 24,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          serviceType.displayName,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: _textPrimary,
                          ),
                        ),
                        if (request.isUrgent == true) ...[
                          SizedBox(height: 4),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.priority_high, size: 12, color: Colors.orange),
                                SizedBox(width: 4),
                                Text(
                                  'Urgent',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: Colors.orange[700],
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
                  if (responseCount > 0)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$responseCount',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _textSecondary,
                        ),
                      ),
                    ),
                ],
              ),
              if (request.message != null && request.message!.isNotEmpty) ...[
                SizedBox(height: 12),
                Text(
                  request.message!.length > 120
                      ? '${request.message!.substring(0, 120)}...'
                      : request.message!,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: _textSecondary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (request.address != null) ...[
                SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.location_on, size: 14, color: _textSecondary),
                    SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        request.address!,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: _textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              SizedBox(height: 12),
              Row(
                children: [
                  if (request.createdAt != null) ...[
                    Icon(Icons.access_time, size: 14, color: _textSecondary),
                    SizedBox(width: 4),
                    Text(
                      _getTimeAgo(request.createdAt!),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: _textSecondary,
                      ),
                    ),
                    Spacer(),
                  ],
                  ElevatedButton.icon(
                    onPressed: hasResponded
                        ? null
                        : () async {
                            final result = await showDialog<Map<String, dynamic>>(
                              context: context,
                              builder: (context) => ServiceRequestResponseDialog(
                                requestId: request.requestId!,
                              ),
                            );

                            if (result != null) {
                              await _respondToRequest(
                                request,
                                message: result['message'] ?? '',
                                price: result['price'] as double?,
                                estimatedTime: result['estimatedTime'] as String?,
                              );
                            }
                          },
                    icon: Icon(Icons.reply, size: 18),
                    label: Text(hasResponded ? 'Déjà répondu' : 'Répondre'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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

  Widget _buildFilters() {
    return Container(
      padding: EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Filtres',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _textPrimary,
            ),
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: Text('Toutes'),
                  selected: _filterType == 'all',
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _filterType = 'all');
                    }
                  },
                  selectedColor: _primaryColor.withOpacity(0.2),
                  labelStyle: GoogleFonts.inter(
                    color: _filterType == 'all' ? _primaryColor : _textSecondary,
                    fontWeight: _filterType == 'all' ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: ChoiceChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.priority_high, size: 16),
                      SizedBox(width: 4),
                      Text('Urgentes'),
                    ],
                  ),
                  selected: _filterType == 'urgent',
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _filterType = 'urgent');
                    }
                  },
                  selectedColor: Colors.orange.withOpacity(0.2),
                  labelStyle: GoogleFonts.inter(
                    color: _filterType == 'urgent' ? Colors.orange[700] : _textSecondary,
                    fontWeight: _filterType == 'urgent' ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: ChoiceChip(
                  label: Text('Normales'),
                  selected: _filterType == 'normal',
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _filterType = 'normal');
                    }
                  },
                  selectedColor: _primaryColor.withOpacity(0.2),
                  labelStyle: GoogleFonts.inter(
                    color: _filterType == 'normal' ? _primaryColor : _textSecondary,
                    fontWeight: _filterType == 'normal' ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_primaryColor, _primaryDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: Text(
          'Demandes disponibles',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Consumer<ServiceRequestController>(
        builder: (context, controller, child) {
          if (controller.loading) {
            return Center(
              child: CircularProgressIndicator(color: _primaryColor),
            );
          }

          final filteredRequests = _getFilteredRequests(controller);

          if (filteredRequests.isEmpty) {
            return Column(
              children: [
                _buildFilters(),
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inbox_outlined,
                          size: 80,
                          color: _textSecondary,
                        ),
                        SizedBox(height: 24),
                        Text(
                          'Aucune demande',
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: _textPrimary,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Il n\'y a pas de demandes correspondant à vos critères',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: _textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }

          return Column(
            children: [
              _buildFilters(),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _loadRequests,
                  color: _primaryColor,
                  child: ListView.builder(
                    padding: EdgeInsets.all(20),
                    itemCount: filteredRequests.length,
                    itemBuilder: (context, index) {
                      return _buildRequestCard(filteredRequests[index]);
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

