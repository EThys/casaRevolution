import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:casa/models/ServiceModel.dart';
import 'package:casa/utils/FancyNotification.dart';
import 'package:casa/utils/networkCheck.dart';
import 'package:casa/controllers/ServiceRequestController.dart';
import 'package:provider/provider.dart';
import 'package:get_storage/get_storage.dart';
import '../widgets/ModernModal.dart';

class QuickServiceRequestModal extends StatefulWidget {
  const QuickServiceRequestModal({Key? key}) : super(key: key);

  @override
  _QuickServiceRequestModalState createState() => _QuickServiceRequestModalState();
}

class _QuickServiceRequestModalState extends State<QuickServiceRequestModal> with SingleTickerProviderStateMixin {
  final Color _primaryColor = Color(0xFF1976D2);
  final Color _primaryDark = Color(0xFF1565C0);
  final Color _textPrimary = Color(0xFF1A1A1A);
  final Color _textSecondary = Color(0xFF666666);
  final Color _cardColor = Colors.white;
  final Color _borderColor = Color(0xFFEEEEEE);

  late TabController _tabController;
  final TextEditingController _messageController = TextEditingController();
  ServiceType? _selectedServiceType;
  bool _isUrgent = false;
  bool _isLoading = false;
  final GetStorage _storage = GetStorage();

  // Propriété demandée
  String _propertyType = 'location'; // 'location' ou 'vente'
  String? _propertyCategory;
  double? _minPrice;
  double? _maxPrice;
  int? _bedrooms;
  int? _bathrooms;
  String? _city;
  String? _commune;
  String? _quartier;

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
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submitServiceRequest() async {
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
      final controller = context.read<ServiceRequestController>();
      
      final result = await controller.createServiceRequest(
        serviceType: _selectedServiceType!.value,
        message: _messageController.text.trim(),
        isUrgent: _isUrgent,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (result.status) {
        _showSuccessDialog('Votre demande de service a été envoyée avec succès !');
      } else {
        FancyNotification.show(
          context,
          result.errorMsg ?? 'Erreur lors de l\'envoi de la demande',
          type: NotificationType.error,
        );
      }
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

  Future<void> _submitPropertyRequest() async {
    // TODO: Implémenter la création de demande de propriété
    // Pour l'instant, on simule
    if (!mounted || _isLoading) return;
    setState(() => _isLoading = true);

    await Future.delayed(Duration(seconds: 1));

    if (!mounted) return;
    setState(() => _isLoading = false);
    
    _showSuccessDialog('Votre demande de propriété a été envoyée avec succès !');
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
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
              SizedBox(height: 12),
              Text(
                message,
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
                    Navigator.pop(context); // Fermer le modal
                    setState(() => _isLoading = false);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
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

  Widget _buildServiceTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Type de service - Dropdown
        Text(
          'Type de service',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: _textPrimary,
          ),
        ),
        SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _borderColor),
            color: _cardColor,
          ),
          child: DropdownButtonFormField<ServiceType>(
            value: _selectedServiceType,
            isExpanded: true,
            decoration: InputDecoration(
              prefixIcon: _selectedServiceType != null
                  ? Padding(
                      padding: EdgeInsets.only(left: 12, right: 8),
                      child: Icon(
                        _serviceTypes.firstWhere((s) => s['type'] == _selectedServiceType)['icon'] as IconData,
                        color: _primaryColor,
                        size: 22,
                      ),
                    )
                  : Padding(
                      padding: EdgeInsets.only(left: 12, right: 8),
                      child: Icon(Icons.category_rounded, color: _textSecondary, size: 22),
                    ),
              hintText: 'Sélectionnez un type de service',
              hintStyle: GoogleFonts.inter(
                color: _textSecondary.withOpacity(0.6),
                fontSize: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _primaryColor, width: 2),
              ),
              filled: true,
              fillColor: _cardColor,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            ),
            style: GoogleFonts.inter(
              fontSize: 14,
              color: _textPrimary,
              fontWeight: FontWeight.w500,
            ),
            icon: Padding(
              padding: EdgeInsets.only(right: 8),
              child: Icon(Icons.arrow_drop_down_rounded, color: _primaryColor, size: 28),
            ),
            items: _serviceTypes.map((service) {
              final type = service['type'] as ServiceType;
              final label = service['label'] as String;
              final icon = service['icon'] as IconData;
              
              return DropdownMenuItem<ServiceType>(
                value: type,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: _primaryColor, size: 20),
                    SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        label,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: _textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            onChanged: (ServiceType? newValue) {
              setState(() {
                _selectedServiceType = newValue;
              });
            },
          ),
        ),

        SizedBox(height: 24),

        // Message
        Text(
          'Décrivez votre besoin',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: _textPrimary,
          ),
        ),
        SizedBox(height: 8),
        Text(
          '(Optionnel)',
          style: GoogleFonts.inter(
            fontSize: 12,
            color: _textSecondary,
            fontStyle: FontStyle.italic,
          ),
        ),
        SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _borderColor),
            color: _cardColor,
          ),
          child: TextField(
            controller: _messageController,
            maxLines: 5,
            decoration: InputDecoration(
              hintText: 'Ex: Fuite d\'eau dans la salle de bain, besoin urgent...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _primaryColor, width: 2),
              ),
              filled: true,
              fillColor: _cardColor,
              contentPadding: EdgeInsets.all(18),
              hintStyle: GoogleFonts.inter(
                color: _textSecondary.withOpacity(0.5),
                fontSize: 14,
              ),
            ),
            style: GoogleFonts.inter(
              fontSize: 14,
              color: _textPrimary,
              height: 1.5,
            ),
          ),
        ),

        SizedBox(height: 20),

        // Option Urgent
        Container(
          padding: EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.orange.withOpacity(0.1),
                Colors.orange.withOpacity(0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _isUrgent 
                  ? Colors.orange.withOpacity(0.4)
                  : Colors.orange.withOpacity(0.2),
              width: _isUrgent ? 2 : 1.5,
            ),
            boxShadow: _isUrgent
                ? [
                    BoxShadow(
                      color: Colors.orange.withOpacity(0.2),
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.priority_high_rounded,
                  color: Colors.orange.shade700,
                  size: 24,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Demande urgente',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.orange.shade900,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Notification prioritaire aux prestataires',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: _textSecondary,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              Transform.scale(
                scale: 1.1,
                child: Switch(
                  value: _isUrgent,
                  onChanged: (value) {
                    setState(() {
                      _isUrgent = value;
                    });
                  },
                  activeColor: Colors.orange,
                  activeTrackColor: Colors.orange.withOpacity(0.5),
                ),
              ),
            ],
          ),
        ),

        SizedBox(height: 32),

        // Bouton de soumission
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              colors: [_primaryColor, _primaryDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: _primaryColor.withOpacity(0.4),
                blurRadius: 12,
                offset: Offset(0, 6),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _isLoading ? null : _submitServiceRequest,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 18),
                child: _isLoading
                    ? Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.send_rounded, size: 22, color: Colors.white),
                          SizedBox(width: 12),
                          Text(
                            'ENVOYER MA DEMANDE',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              letterSpacing: 0.8,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
        SizedBox(height: 8),
        Center(
          child: Text(
            'Vous recevrez des réponses rapidement',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: _textSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPropertyTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Type de transaction
        Text(
          'Type de transaction',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: _textPrimary,
          ),
        ),
        SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildChoiceChip(
                label: 'Location',
                selected: _propertyType == 'location',
                icon: Icons.home_outlined,
                onSelected: (selected) {
                  if (selected) setState(() => _propertyType = 'location');
                },
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _buildChoiceChip(
                label: 'Vente',
                selected: _propertyType == 'vente',
                icon: Icons.sell_outlined,
                onSelected: (selected) {
                  if (selected) setState(() => _propertyType = 'vente');
                },
              ),
            ),
          ],
        ),

        SizedBox(height: 24),

        // Catégorie
        Text(
          'Type de bien',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: _textPrimary,
          ),
        ),
        SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _borderColor),
            color: _cardColor,
          ),
          child: DropdownButtonFormField<String>(
            value: _propertyCategory,
            isExpanded: true,
            decoration: InputDecoration(
              hintText: 'Sélectionnez un type de bien',
              hintStyle: GoogleFonts.inter(
                color: _textSecondary.withOpacity(0.6),
                fontSize: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _primaryColor, width: 2),
              ),
              filled: true,
              fillColor: _cardColor,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            items: ['Maison', 'Appartement', 'Villa', 'Studio', 'Terrain', 'Bureau', 'Local commercial']
                .map((type) => DropdownMenuItem(
                      value: type,
                      child: Text(type),
                    ))
                .toList(),
            onChanged: (value) {
              setState(() => _propertyCategory = value);
            },
          ),
        ),

        SizedBox(height: 24),

        // Budget
        Text(
          'Budget',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: _textPrimary,
          ),
        ),
        SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildNumberField(
                label: 'Min (CDF)',
                value: _minPrice,
                onChanged: (value) => setState(() => _minPrice = value),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _buildNumberField(
                label: 'Max (CDF)',
                value: _maxPrice,
                onChanged: (value) => setState(() => _maxPrice = value),
              ),
            ),
          ],
        ),

        SizedBox(height: 24),

        // Caractéristiques
        Text(
          'Caractéristiques',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: _textPrimary,
          ),
        ),
        SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildNumberField(
                label: 'Chambres',
                value: _bedrooms?.toDouble(),
                onChanged: (value) => setState(() => _bedrooms = value?.toInt()),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _buildNumberField(
                label: 'Salles de bain',
                value: _bathrooms?.toDouble(),
                onChanged: (value) => setState(() => _bathrooms = value?.toInt()),
              ),
            ),
          ],
        ),

        SizedBox(height: 24),

        // Localisation
        Text(
          'Localisation',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: _textPrimary,
          ),
        ),
        SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _borderColor),
            color: _cardColor,
          ),
          child: TextField(
            decoration: InputDecoration(
              labelText: 'Ville',
              hintText: 'Ex: Kinshasa',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _primaryColor, width: 2),
              ),
              filled: true,
              fillColor: _cardColor,
              contentPadding: EdgeInsets.all(16),
            ),
            onChanged: (value) => setState(() => _city = value),
          ),
        ),

        SizedBox(height: 32),

        // Bouton
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              colors: [_primaryColor, _primaryDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: _primaryColor.withOpacity(0.4),
                blurRadius: 12,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _isLoading ? null : _submitPropertyRequest,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 18),
                child: _isLoading
                    ? Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.send_rounded, size: 22, color: Colors.white),
                          SizedBox(width: 12),
                          Text(
                            'ENVOYER MA DEMANDE',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              letterSpacing: 0.8,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChoiceChip({
    required String label,
    required bool selected,
    required IconData icon,
    required Function(bool) onSelected,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onSelected(true),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: selected ? _primaryColor.withOpacity(0.1) : Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? _primaryColor : _borderColor,
              width: selected ? 2 : 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: selected ? _primaryColor : _textSecondary,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected ? _primaryColor : _textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNumberField({
    required String label,
    double? value,
    required Function(double?) onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor),
        color: _cardColor,
      ),
      child: TextField(
        keyboardType: TextInputType.number,
        controller: TextEditingController(
          text: value != null ? value.toInt().toString() : '',
        ),
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: _primaryColor, width: 2),
          ),
          filled: true,
          fillColor: _cardColor,
          contentPadding: EdgeInsets.all(16),
        ),
        onChanged: (text) => onChanged(double.tryParse(text)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ModernModal(
      title: 'Demander une intervention',
      subtitle: 'Remplissez le formulaire pour recevoir des propositions',
      icon: Icons.add_task_rounded,
      iconColor: _primaryColor,
      height: MediaQuery.of(context).size.height * 0.9,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Tabs
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: _primaryColor,
                borderRadius: BorderRadius.circular(12),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: Colors.white,
              unselectedLabelColor: _textSecondary,
              labelStyle: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              tabs: [
                Tab(
                  icon: Icon(Icons.build_rounded, size: 20),
                  text: 'Service',
                ),
                Tab(
                  icon: Icon(Icons.home_rounded, size: 20),
                  text: 'Propriété',
                ),
              ],
            ),
          ),

          SizedBox(height: 32),

          // Tab content
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.55,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildServiceTab(),
                _buildPropertyTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
