import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:get_storage/get_storage.dart';

import '../controllers/CotationController.dart';
import '../models/ServiceRequestModel.dart';
import '../models/ServiceModel.dart';
import '../models/UserModel.dart';
import '../controllers/ServiceRequestController.dart';
import '../utils/FancyNotification.dart';
import '../utils/Routes.dart';
import '../utils/StockageKeys.dart';
import '../utils/networkCheck.dart';
import '../utils/database/DatabaseHelper.dart';
import 'package:shimmer/shimmer.dart';
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
  final Color _darkColor = Color(0xFF1A1D26);
  bool _isLoadingData = true;
  bool _isInitialLoad = true;

  final GetStorage _stockage = GetStorage();
  /// Même clé que [MyServicesPage] : IDs déjà notés (cotation envoyée avec succès).
  static const String _ratedCotationStorageKey = 'cotation_rated_sollicitation_ids';
  Set<int> _ratedSolicitationIds = {};

  @override
  void initState() {
    super.initState();
    _loadRatedSolicitationIds();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRequests();
    });
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

  /// Demandeur uniquement ; même règles que l’onglet « Mes demandes » de [MyServicesPage].
  bool _canShowCotationButton(ServiceRequestModel request) {
    if (request.requestId == null) return false;
    final me = _currentUserIdFromStorage();
    if (me == null || request.userId != me) return false;
    if (_ratedSolicitationIds.contains(request.requestId!)) return false;
    final st = request.status?.toUpperCase() ?? '';
    return st == 'COMPLETED' || st == 'ACCEPTED';
  }

  Future<void> _showCotationDialog(ServiceRequestModel request) async {
    final me = _currentUserIdFromStorage();
    if (me == null || request.requestId == null) {
      FancyNotification.show(
        context,
        'Session invalide. Reconnectez-vous.',
        type: NotificationType.error,
      );
      return;
    }

    final commentCtrl = TextEditingController();
    double cote = 4.0;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return Consumer<CotationController>(
          builder: (ctx, cotationCtrl, _) {
            return StatefulBuilder(
              builder: (ctx, setDialogState) {
                return AlertDialog(
                  title: Text(
                    'Mettre un avis',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                  ),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Note : ${cote.toStringAsFixed(1)} / 5',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: _darkColor,
                          ),
                        ),
                        Slider(
                          value: cote,
                          min: 0.5,
                          max: 5.0,
                          divisions: 9,
                          label: cote.toStringAsFixed(1),
                          activeColor: _primaryColor,
                          onChanged: cotationCtrl.loading
                              ? null
                              : (v) => setDialogState(() => cote = v),
                        ),
                        SizedBox(height: 8),
                        TextField(
                          controller: commentCtrl,
                          maxLines: 4,
                          decoration: InputDecoration(
                            labelText: 'Commentaire',
                            hintText: 'Décrivez votre expérience',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed:
                          cotationCtrl.loading ? null : () => Navigator.pop(ctx),
                      child: Text('Annuler'),
                    ),
                    TextButton(
                      onPressed: cotationCtrl.loading
                          ? null
                          : () async {
                              final text = commentCtrl.text.trim();
                              if (text.length < 3) {
                                FancyNotification.show(
                                  ctx,
                                  'Le commentaire doit contenir au moins 3 caractères.',
                                  type: NotificationType.warning,
                                );
                                return;
                              }
                              final resp = await cotationCtrl.createCotation(
                                userId: me,
                                sollicitationId: request.requestId!,
                                commentaire: text,
                                cote: cote,
                              );
                              if (!ctx.mounted) return;
                              if (resp.status) {
                                Navigator.pop(ctx);
                                if (!mounted) return;
                                setState(() {
                                  _ratedSolicitationIds.add(request.requestId!);
                                });
                                _stockage.write(
                                  _ratedCotationStorageKey,
                                  _ratedSolicitationIds.toList(),
                                );
                                FancyNotification.show(
                                  context,
                                  'Merci pour votre avis.',
                                  type: NotificationType.success,
                                );
                                await _loadRequests(forceRefresh: true);
                              } else {
                                final msg = resp.errorMsg ??
                                    (resp.data is Map
                                        ? (resp.data['message']?.toString())
                                        : null) ??
                                    'Impossible d\'enregistrer l\'avis.';
                                FancyNotification.show(
                                  ctx,
                                  msg,
                                  type: NotificationType.error,
                                );
                              }
                            },
                      child: cotationCtrl.loading
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text('Envoyer'),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
    commentCtrl.dispose();
  }

  Future<void> _loadRequests({bool forceRefresh = false}) async {
    final controller = context.read<ServiceRequestController>();
    final db = DatabaseHelper.instance;

    _loadRatedSolicitationIds();

    setState(() {
      _isLoadingData = true;
    });

    try {
      // 1. Charger le cache d'abord
      final cachedRequests = await db.getAllServiceRequests();
      if (cachedRequests.isNotEmpty && mounted) {
        setState(() {
          controller.requests = cachedRequests;
          _isLoadingData = false; // On peut arrêter le shimmer si on a des données
          _isInitialLoad = false;
        });
        print("📁 [MyServiceRequestsPage] ${cachedRequests.length} demandes chargées depuis le cache");
      }

      // 2. Appel API
      await controller.fetchUserRequests();

      // 3. Mettre à jour le cache
      if (mounted) {
        await db.clearServiceRequests();
        await db.insertMultipleServiceRequests(controller.requests);
        print("💾 [MyServiceRequestsPage] Cache des demandes mis à jour");
      }
    } catch (e) {
      print("❌ Erreur lors du chargement des demandes: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingData = false;
          _isInitialLoad = false;
        });
      }
    }
  }

  Widget _buildShimmerEffect() {
    return ListView.separated(
      padding: EdgeInsets.all(20),
      itemCount: 5,
      separatorBuilder: (_, __) => SizedBox(height: 12),
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Container(
            height: 120,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        );
      },
    );
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
              if (_canShowCotationButton(request)) ...[
                SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    onPressed: () => _showCotationDialog(request),
                    icon: Icon(Icons.rate_review_rounded, size: 18),
                    label: Text(
                      'Mettre un avis',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryColor,
                      foregroundColor: Colors.white,
                      padding:
                          EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
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
          if (_isLoadingData && controller.requests.isEmpty) {
            return _buildShimmerEffect();
          }

          if (controller.requests.isEmpty) {
            return Center(
              child: RefreshIndicator(
                onRefresh: () => _loadRequests(forceRefresh: true),
                child: SingleChildScrollView(
                  physics: AlwaysScrollableScrollPhysics(),
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
                      SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () => _loadRequests(forceRefresh: true),
                        icon: Icon(Icons.refresh),
                        label: Text('Actualiser'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => _loadRequests(forceRefresh: true),
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

