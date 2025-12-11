import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/ServiceRequestModel.dart';
import '../models/ServiceModel.dart';
import '../controllers/ServiceRequestController.dart';
import '../utils/FancyNotification.dart';
import '../utils/Routes.dart';
import '../utils/networkCheck.dart';
import 'ServiceRequestDetailPage.dart';

class MyServiceRequestsPage extends StatefulWidget {
  const MyServiceRequestsPage({Key? key}) : super(key: key);

  @override
  _MyServiceRequestsPageState createState() => _MyServiceRequestsPageState();
}

class _MyServiceRequestsPageState extends State<MyServiceRequestsPage> {
  final Color _primaryColor = Color(0xFF1976D2);
  final Color _primaryDark = Color(0xFF1565C0);
  final Color _textPrimary = Color(0xFF1A1A1A);
  final Color _textSecondary = Color(0xFF666666);
  final Color _successColor = Color(0xFF00B894);
  final Color _warningColor = Color(0xFFFFA000);
  final Color _errorColor = Color(0xFFD63031);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRequests();
    });
  }

  Future<void> _loadRequests() async {
    final controller = context.read<ServiceRequestController>();
    await controller.fetchUserRequests();
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
        return _errorColor;
      case 'COMPLETED':
        return _primaryColor;
      default:
        return _textSecondary;
    }
  }

  IconData _getStatusIcon(String? status) {
    switch (status?.toUpperCase()) {
      case 'PENDING':
        return Icons.hourglass_empty;
      case 'ACCEPTED':
        return Icons.check_circle;
      case 'DECLINED':
      case 'CANCELLED':
        return Icons.cancel;
      case 'COMPLETED':
        return Icons.check_circle_outline;
      default:
        return Icons.help_outline;
    }
  }

  ServiceType _getServiceType(ServiceRequestModel request) {
    if (request.serviceType == null) return ServiceType.reparation;
    return ServiceTypeExtension.fromString(request.serviceType);
  }

  Widget _buildRequestCard(ServiceRequestModel request) {
    final serviceType = _getServiceType(request);
    final responseCount = request.responses?.length ?? 0;
    final isAccepted = request.status?.toUpperCase() == 'ACCEPTED';
    final isCompleted = request.status?.toUpperCase() == 'COMPLETED';

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
                          Row(
                            children: [
                              Icon(Icons.priority_high, size: 14, color: Colors.orange),
                              SizedBox(width: 4),
                              Text(
                                'Urgent',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: Colors.orange,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getStatusColor(request.status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getStatusIcon(request.status),
                          size: 14,
                          color: _getStatusColor(request.status),
                        ),
                        SizedBox(width: 4),
                        Text(
                          _getStatusText(request.status),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _getStatusColor(request.status),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (request.message != null && request.message!.isNotEmpty) ...[
                SizedBox(height: 12),
                Text(
                  request.message!.length > 100
                      ? '${request.message!.substring(0, 100)}...'
                      : request.message!,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: _textSecondary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              SizedBox(height: 12),
              Row(
                children: [
                  if (responseCount > 0) ...[
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.reply, size: 14, color: _primaryColor),
                          SizedBox(width: 4),
                          Text(
                            '$responseCount ${responseCount > 1 ? 'réponses' : 'réponse'}',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 8),
                  ],
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
                  ],
                ],
              ),
            ],
          ),
        ),
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
          'Mes demandes',
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

          if (controller.requests.isEmpty) {
            return Center(
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
                    'Vous n\'avez pas encore créé de demande de service',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: _textSecondary,
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _loadRequests,
            color: _primaryColor,
            child: ListView.builder(
              padding: EdgeInsets.all(20),
              itemCount: controller.requests.length,
              itemBuilder: (context, index) {
                return _buildRequestCard(controller.requests[index]);
              },
            ),
          );
        },
      ),
    );
  }
}

