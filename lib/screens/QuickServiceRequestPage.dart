import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:casa/models/ServiceModel.dart';
import 'package:casa/utils/FancyNotification.dart';
import 'package:casa/utils/networkCheck.dart';
import 'package:casa/utils/StockageKeys.dart';
import 'package:get_storage/get_storage.dart';

class QuickServiceRequestPage extends StatefulWidget {
  const QuickServiceRequestPage({Key? key}) : super(key: key);

  @override
  _QuickServiceRequestPageState createState() => _QuickServiceRequestPageState();
}

class _QuickServiceRequestPageState extends State<QuickServiceRequestPage> {
  final Color _primaryColor = Color(0xFF1976D2);
  final Color _primaryDark = Color(0xFF1565C0);
  final Color _accentColor = Color(0xFFE3F2FD);
  final Color _textPrimary = Color(0xFF1A1A1A);
  final Color _textSecondary = Color(0xFF666666);
  final Color _cardColor = Colors.white;
  final Color _borderColor = Color(0xFFEEEEEE);

  final TextEditingController _messageController = TextEditingController();
  ServiceType? _selectedServiceType;
  bool _isUrgent = false;
  bool _isLoading = false;
  final GetStorage _storage = GetStorage();

  // Types de services populaires avec icônes
  final List<Map<String, dynamic>> _serviceTypes = [
    {'type': ServiceType.plomberie, 'label': 'Plomberie', 'icon': Icons.plumbing_rounded},
    {'type': ServiceType.electricite, 'label': 'Électricité', 'icon': Icons.electrical_services_rounded},
    {'type': ServiceType.peinture, 'label': 'Peinture', 'icon': Icons.format_paint_rounded},
    {'type': ServiceType.nettoyage, 'label': 'Nettoyage', 'icon': Icons.cleaning_services_rounded},
    {'type': ServiceType.reparation, 'label': 'Réparation', 'icon': Icons.build_rounded},
    {'type': ServiceType.jardinage, 'label': 'Jardinage', 'icon': Icons.grass_rounded},
    {'type': ServiceType.climatisation, 'label': 'Climatisation', 'icon': Icons.ac_unit_rounded},
    {'type': ServiceType.serrurerie, 'label': 'Serrurerie', 'icon': Icons.lock_rounded},
    {'type': ServiceType.carrelage, 'label': 'Carrelage', 'icon': Icons.square_foot_rounded},
    {'type': ServiceType.renovation, 'label': 'Rénovation', 'icon': Icons.home_repair_service_rounded},
  ];

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submitRequest() async {
    if (_selectedServiceType == null) {
      FancyNotification.show(
        context,
        'Veuillez sélectionner un type de service',
        type: NotificationType.warning,
      );
      return;
    }

    if (!mounted || _isLoading) return;
    setState(() => _isLoading = true);

    FocusScope.of(context).unfocus();

    final isConnected = await NetworkUtils.checkInternetConnectivity();
    if (!isConnected) {
      if (mounted) {
        FancyNotification.show(
          context,
          'Pas de connexion internet',
          type: NotificationType.error,
        );
        setState(() => _isLoading = false);
      }
      return;
    }

    try {
      // Récupérer l'userId si l'utilisateur est connecté
      dynamic userData = _storage.read(StockageKeys.userKey);
      int? userId;
      
      if (userData != null) {
        if (userData is Map) {
          final userIdValue = userData['userId'];
          if (userIdValue is int) {
            userId = userIdValue;
          } else if (userIdValue is String) {
            userId = int.tryParse(userIdValue);
          }
        }
      }
      
      // TODO: Implémenter l'appel API pour créer la demande
      // Exemple de payload:
      // {
      //   "serviceType": _selectedServiceType?.value,
      //   "message": _messageController.text.trim(),
      //   "isUrgent": _isUrgent,
      //   "userId": userId,
      // }
      
      // Pour l'instant, on simule un délai
      await Future.delayed(Duration(seconds: 1));

      if (!mounted) return;

      // Afficher le message de succès
      _showSuccessDialog();
    } catch (e) {
      if (mounted) {
        FancyNotification.show(
          context,
          'Erreur lors de l\'envoi de la demande: $e',
          type: NotificationType.error,
        );
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          padding: EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_primaryColor, _primaryDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 40,
                ),
              ),
              SizedBox(height: 24),
              Text(
                'Demande envoyée !',
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Votre demande a été transmise aux prestataires. Vous recevrez des réponses sous peu.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: _textSecondary,
                  fontSize: 15,
                ),
              ),
              SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // Fermer le dialog de succès
                    Navigator.pop(context); // Retourner à la page précédente
                    setState(() => _isLoading = false);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(
                    'Parfait',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
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
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Demander un service',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            'Remplissez ce formulaire',
            style: GoogleFonts.inter(
              color: Colors.white.withOpacity(0.9),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header card
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_primaryColor, _primaryDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: _primaryColor.withOpacity(0.3),
                    blurRadius: 15,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.add_task_rounded,
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
                          'Besoin d\'un service ?',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Décrivez votre besoin et recevez des devis rapidement',
                          style: GoogleFonts.inter(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 24),

            // Type de service
            Text(
              'Type de service',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: _textPrimary,
              ),
            ),
            SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _serviceTypes.map((service) {
                final type = service['type'] as ServiceType;
                final label = service['label'] as String;
                final icon = service['icon'] as IconData;
                final isSelected = _selectedServiceType == type;

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedServiceType = type;
                    });
                  },
                  child: AnimatedContainer(
                    duration: Duration(milliseconds: 200),
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? _primaryColor : _cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? _primaryColor : _borderColor,
                        width: isSelected ? 2 : 1.5,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: _primaryColor.withOpacity(0.3),
                                blurRadius: 8,
                                offset: Offset(0, 4),
                              ),
                            ]
                          : [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          icon,
                          color: isSelected ? Colors.white : _primaryColor,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          label,
                          style: GoogleFonts.inter(
                            color: isSelected ? Colors.white : _textPrimary,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),

            SizedBox(height: 24),

            // Message
            Text(
              'Décrivez votre besoin (optionnel)',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: _textPrimary,
              ),
            ),
            SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: _messageController,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: 'Ex: Fuite d\'eau dans la salle de bain, besoin urgent...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _borderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _primaryColor, width: 2),
                  ),
                  filled: true,
                  fillColor: _cardColor,
                  contentPadding: EdgeInsets.all(16),
                  hintStyle: GoogleFonts.inter(
                    color: _textSecondary.withOpacity(0.6),
                    fontSize: 14,
                  ),
                ),
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: _textPrimary,
                ),
              ),
            ),

            SizedBox(height: 20),

            // Option Urgent
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _accentColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _primaryColor.withOpacity(0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.priority_high_rounded,
                    color: Colors.orange,
                    size: 24,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Demande urgente',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: _textPrimary,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Les prestataires seront notifiés en priorité',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: _textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _isUrgent,
                    onChanged: (value) {
                      setState(() {
                        _isUrgent = value;
                      });
                    },
                    activeColor: Colors.orange,
                  ),
                ],
              ),
            ),

            SizedBox(height: 32),

            // Bouton de soumission
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: EdgeInsets.symmetric(vertical: 18),
                  elevation: 4,
                  shadowColor: _primaryColor.withOpacity(0.4),
                ),
                child: _isLoading
                    ? SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: Colors.white,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.send_rounded, size: 20),
                          SizedBox(width: 10),
                          Text(
                            'ENVOYER MA DEMANDE',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

