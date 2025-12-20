import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:casa/controllers/ServiceController.dart';
import 'package:casa/controllers/LocationController.dart';
import 'package:casa/models/CityModel.dart';
import 'package:casa/models/CommuneModel.dart';
import 'package:casa/models/DistrictModel.dart';
import 'package:casa/models/QuartierModel.dart';
import 'package:casa/models/ServiceModel.dart';
import 'package:casa/utils/Routes.dart';
import 'package:casa/utils/networkCheck.dart';
import 'package:casa/utils/city_suggestions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/FancyNotification.dart';
import '../utils/StockageKeys.dart';
// Firebase imports
import 'package:firebase_analytics/firebase_analytics.dart';

class CreateServicePage extends StatefulWidget {
  final ServiceType? initialServiceType;
  
  const CreateServicePage({Key? key, this.initialServiceType}) : super(key: key);
  
  @override
  _CreateServicePageState createState() => _CreateServicePageState();
}

class _CreateServicePageState extends State<CreateServicePage> {
  // Modern color palette - COULEURS HARMONISÉES
  final Color _primaryColor = Color(0xFF1976D2);
  final Color _secondaryColor = Color(0xFF64B5F6);
  final Color _darkColor = Color(0xFF1A1D26);
  final Color _lightColor = Color(0xFFF8F9FA);
  final Color _greyColor = Color(0xFF6C757D);
  final Color _successColor = Color(0xFF38B000);
  final Color _cardColor = Colors.white;
  final Color _borderColor = Color(0xFFE9ECEF);
  final Color _accentColor = Color(0xFFFF6B35);
  final Color _errorColor = Color(0xFFD32F2F);

  // Tailles de texte harmonisées
  final double _titleSize = 18.0;
  final double _subtitleSize = 14.0;
  final double _bodySize = 14.0;
  final double _captionSize = 12.0;
  final double _smallSize = 10.0;

  // Espacements harmonisés
  final double _smallSpace = 8.0;
  final double _mediumSpace = 16.0;
  final double _largeSpace = 24.0;

  // Form controllers
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _minPriceController = TextEditingController();
  final TextEditingController _maxPriceController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _whatsappController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _experienceController = TextEditingController();
  final TextEditingController _availableHoursController = TextEditingController();
  final TextEditingController _teamSizeController = TextEditingController();
  final TextEditingController _postalCodeController = TextEditingController();
  // Controllers pour les champs texte de localisation (hors Kinshasa)
  final TextEditingController _cityTextController = TextEditingController();
  final TextEditingController _districtTextController = TextEditingController();
  final TextEditingController _communeTextController = TextEditingController();
  final TextEditingController _quartierTextController = TextEditingController();
  
  // Controllers spécifiques pour les nouveaux types
  final TextEditingController _numberOfRoomsController = TextEditingController();
  final TextEditingController _surfaceAreaController = TextEditingController();
  final TextEditingController _numberOfDesksController = TextEditingController();
  final TextEditingController _meetingRoomsController = TextEditingController();
  final TextEditingController _capacityController = TextEditingController();
  final TextEditingController _landAreaController = TextEditingController();
  final TextEditingController _warehouseAreaController = TextEditingController();
  final TextEditingController _ceilingHeightController = TextEditingController();

  // State variables
  bool _isLoading = false;
  int _currentStep = 0;
  ServiceType? _selectedServiceType;
  String? _selectedPriceUnit;
  String? _selectedCurrency = 'CDF'; // Devise par défaut : Franc Congolais
  String? _selectedVacationType;
  String? _selectedLandType;
  String? _selectedWarehouseType;
  int? _selectedStarRating;
  LatLng? _selectedLocation;
  final ImagePicker _picker = ImagePicker();
  List<XFile> _selectedImages = [];
  File? _selectedCvFile; // Fichier CV sélectionné (PDF ou DOC)
  Set<String> _selectedSpecialties = {};
  Set<String> _selectedDays = {};
  Set<String> _selectedHotelServices = {};
  Set<String> _selectedVacationAmenities = {};
  Set<String> _selectedEventEquipment = {};
  Set<String> _selectedFuneralServices = {};
  Set<String> _selectedLandFeatures = {};
  Set<String> _selectedWarehouseFeatures = {};
  bool _hasVehicle = false;
  bool _hasTeam = false;
  bool _hasParking = false;
  bool _hasSecurity = false;
  bool _isAvailable = true;
  AutovalidateMode _autoValidateMode = AutovalidateMode.disabled;

  // Location variables
  CityModel? _selectedCity;
  DistrictModel? _selectedDistrict;
  CommuneModel? _selectedCommune;
  QuartierModel? _selectedQuartier;

  List<CityModel> _availableCities = [];
  List<DistrictModel> _availableDistricts = [];
  List<CommuneModel> _availableCommunes = [];
  List<QuartierModel> _availableQuartiers = [];

  // Validation errors
  Map<int, bool> _stepValidations = {0: false, 1: false, 2: false};
  Map<int, String> _stepErrorMessages = {};
  Map<int, Map<String, String>> _stepFieldErrors = {
    0: {}, // Erreurs par champ pour l'étape 0
    1: {}, // Erreurs par champ pour l'étape 1
    2: {}, // Erreurs par champ pour l'étape 2
  };
  Map<String, bool> _fieldTouched = {};
  bool _hasAttemptedSubmit = false;
  
  // Firebase Analytics
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  DateTime? _pageStartTime;
  Timer? _pageDurationTimer;
  int _totalPageTimeSeconds = 0;
  int _clickCount = 0;
  
  // Détection Kinshasa
  bool get _isKinshasaSelected =>
      (_selectedCity?.name?.toLowerCase().trim() ?? '') == 'kinshasa' ||
      (_cityTextController.text.toLowerCase().trim() == 'kinshasa');

  final stockage = GetStorage();
  late final profile = stockage.read(StockageKeys.profileKey);
  late var fullname = (profile is Map) ? (profile["fullname"] ?? "Utilisateur") : "Utilisateur";

  // Options
  final List<String> _priceUnits = ['Par heure', 'Par jour', 'Par nuit', 'Par semaine', 'Par mois', 'Sur devis'];
  
  final List<String> _majordhommeSpecialties = [
    'Nettoyage',
    'Cuisine',
    'Jardinage',
    'Repassage',
    'Garde d\'enfants',
    'Entretien général',
  ];

  final List<String> _hotelServices = [
    'Restaurant',
    'Spa',
    'Piscine',
    'Parking',
    'WiFi',
    'Climatisation',
    'Service de chambre',
    'Gym',
    'Bar',
    'Réception 24/7',
  ];

  final List<String> _vacationTypes = [
    'Villa',
    'Appartement',
    'Maison',
    'Studio',
    'Chalet',
  ];

  final List<String> _vacationAmenities = [
    'Piscine',
    'Plage',
    'WiFi',
    'Cuisine équipée',
    'Climatisation',
    'Parking',
    'Jardin',
    'Terrasse',
    'Machine à laver',
    'Télévision',
  ];

  final List<String> _eventEquipment = [
    'Sonorisation',
    'Éclairage',
    'Cuisine',
    'Parking',
    'WiFi',
    'Écran/Vidéoprojecteur',
    'Scène',
    'Climatisation',
  ];

  final List<String> _funeralServices = [
    'Chapelle',
    'Parking',
    'Salle de réception',
    'Wifi',
    'Climatisation',
    'Sonorisation',
    'Éclairage',
  ];

  final List<String> _landTypes = [
    'Constructible',
    'Agricole',
    'Commercial',
    'Résidentiel',
    'Industriel',
  ];

  final List<String> _landFeatures = [
    'Clôturé',
    'Accès route',
    'Eau',
    'Électricité',
    'Desservi',
    'Vue panoramique',
  ];

  final List<String> _warehouseTypes = [
    'Entrepôt',
    'Hangar',
    'Dépôt',
  ];

  final List<String> _warehouseFeatures = [
    'Quai de chargement',
    'Portes grandes',
    'Sécurité',
    'Climatisation',
    'Éclairage',
    'Parking',
    'Bureau intégré',
  ];

  final List<String> _daysOfWeek = [
    'Lundi',
    'Mardi',
    'Mercredi',
    'Jeudi',
    'Vendredi',
    'Samedi',
    'Dimanche',
  ];

  // SharedPreferences instance
  late SharedPreferences _prefs;

  @override
  void initState() {
    super.initState();
    
    // Pré-sélectionner le type de service si fourni
    if (widget.initialServiceType != null) {
      _selectedServiceType = widget.initialServiceType;
      // Ne pas changer l'étape, juste pré-sélectionner le type
    }
    _postalCodeController.text = '243';
    _cityTextController.text = '';
    _districtTextController.text = '';
    _communeTextController.text = '';
    _quartierTextController.text = '';
    
    _initSharedPreferences();
    
    // Démarrer le tracking Firebase
    _startPageTracking();
  }

  Future<void> _initSharedPreferences() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadLocationData();
  }

  Future<void> _loadLocationData() async {
    try {
      final locationCtrl = LocationController();
      await locationCtrl.loadAllData();

      if (mounted) {
        setState(() {
          _availableCities = locationCtrl.cities;
          // Charger toutes les communes et quartiers pour les suggestions
          _availableCommunes = locationCtrl.communes;
          _availableQuartiers = locationCtrl.quartiers;
          
          if (_availableCities.isNotEmpty) {
            // Ne pas pré-sélectionner automatiquement la première ville
            // L'utilisateur doit choisir
          }
        });
      }
    } catch (e) {
      print("Erreur lors du chargement des données de localisation: $e");
      _availableCities = [];
      _availableDistricts = [];
      _availableCommunes = [];
      _availableQuartiers = [];
    }
  }

  void _updateDistrictsForCity() {
    if (_selectedCity == null) return;
    final locationCtrl = LocationController();
    setState(() {
      try {
        _availableDistricts = locationCtrl.getDistrictsForCity(_selectedCity!.cityId!);
        _selectedDistrict = _availableDistricts.isNotEmpty ? _availableDistricts.first : null;
        _updateCommunesForDistrict();
      } catch (e) {
        _availableDistricts = [];
        _selectedDistrict = null;
      }
    });
  }

  void _updateCommunesForDistrict() {
    if (_selectedDistrict == null) return;
    final locationCtrl = LocationController();
    setState(() {
      try {
        _availableCommunes = locationCtrl.getCommunesForDistrict(_selectedDistrict!.districtId!);
        _selectedCommune = _availableCommunes.isNotEmpty ? _availableCommunes.first : null;
        _updateQuartiersForCommune();
      } catch (e) {
        _availableCommunes = [];
        _selectedCommune = null;
      }
    });
  }

  void _updateQuartiersForCommune() {
    if (_selectedCommune == null) return;
    final locationCtrl = LocationController();
    setState(() {
      try {
        _availableQuartiers = locationCtrl.getQuartiersForCommune(_selectedCommune!.communeId!);
        _selectedQuartier = _availableQuartiers.isNotEmpty ? _availableQuartiers.first : null;
      } catch (e) {
        _availableQuartiers = [];
        _selectedQuartier = null;
      }
    });
  }

  // =============================================
  // FIREBASE ANALYTICS METHODS
  // =============================================

  void _startPageTracking() {
    _pageStartTime = DateTime.now();
    _totalPageTimeSeconds = 0;
    _clickCount = 0;
    
    // Démarrer un timer pour suivre le temps passé sur la page
    _pageDurationTimer = Timer.periodic(Duration(seconds: 10), (timer) {
      if (mounted && _pageStartTime != null) {
        _totalPageTimeSeconds += 10;
        _trackEvent('page_time_update', {
          'page_name': 'create_service',
          'duration_seconds': _totalPageTimeSeconds,
          'step': _currentStep,
        });
      } else {
        timer.cancel();
      }
    });
    
    _trackEvent('page_view', {
      'page_name': 'create_service',
      'timestamp': _pageStartTime!.millisecondsSinceEpoch,
    });
    _trackPageView('create_service_page');
  }

  void _endPageTracking() {
    // Annuler le timer
    _pageDurationTimer?.cancel();
    _pageDurationTimer = null;
    
    if (_pageStartTime != null) {
      final duration = DateTime.now().difference(_pageStartTime!);
      _trackEvent('page_exit', {
        'page_name': 'create_service',
        'duration_seconds': duration.inSeconds,
        'total_time_tracked_seconds': _totalPageTimeSeconds,
        'steps_completed': _currentStep,
        'service_type': _selectedServiceType?.value ?? 'none',
        'click_count': _clickCount,
        'has_attempted_submit': _hasAttemptedSubmit,
      });
    }
  }

  Future<void> _trackEvent(String name, Map<String, dynamic> parameters) async {
    try {
      final Map<String, Object> convertedParams = {};

      parameters.forEach((key, value) {
        if (value is String) {
          convertedParams[key] = value;
        } else if (value is int) {
          convertedParams[key] = value;
        } else if (value is double) {
          convertedParams[key] = value;
        } else if (value is bool) {
          convertedParams[key] = value;
        } else if (value == null) {
          convertedParams[key] = 'null';
        } else {
          convertedParams[key] = value.toString();
        }
      });

      await _analytics.logEvent(
        name: name,
        parameters: convertedParams,
      );
      print('📊 Firebase Event: $name - $convertedParams');
    } catch (e) {
      print('❌ Firebase Analytics Error: $e');
    }
  }

  Future<void> _trackPageView(String pageName) async {
    try {
      await _analytics.logScreenView(
        screenName: pageName,
        screenClass: 'CreateServicePage',
      );
    } catch (e) {
      print('❌ Firebase Page View Error: $e');
    }
  }

  Future<void> _trackSelection(String type, String value) async {
    await _trackEvent('selection_$type', {
      'value': value,
      'step': _currentStep,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  // =============================================
  // VALIDATION HELPERS
  // =============================================

  List<String> _filterSuggestions(String query, List<String> source) {
    if (query.isEmpty) return source.take(15).toList();
    final lower = query.toLowerCase();
    return source
        .where((item) => item.toLowerCase().contains(lower))
        .take(15)
        .toList();
  }

  void _setFieldError(int step, String field, String error) {
    if (!_stepFieldErrors.containsKey(step)) {
      _stepFieldErrors[step] = {};
    }
    _stepFieldErrors[step]![field] = error;
  }
  
  void _markFieldTouched(String field) {
    _fieldTouched[field] = true;
    // Track field interaction
    _trackEvent('field_interaction', {
      'field_name': field,
      'step': _currentStep,
    });
  }
  
  bool _shouldShowError(int step, String field) {
    // Afficher l'erreur seulement si :
    // 1. L'utilisateur a tenté de soumettre, OU
    // 2. Le champ a été touché/interagi
    return _hasAttemptedSubmit || _fieldTouched[field] == true;
  }

  void _removeFieldError(int step, String field) {
    if (_stepFieldErrors.containsKey(step)) {
      _stepFieldErrors[step]!.remove(field);
    }
  }

  String? _getFieldError(int step, String field) {
    return _stepFieldErrors[step]?[field];
  }

  bool _hasFieldErrors(int step) {
    return _stepFieldErrors[step]?.isNotEmpty ?? false;
  }

  @override
  void dispose() {
    // Annuler le timer de tracking
    _pageDurationTimer?.cancel();
    _pageDurationTimer = null;
    _endPageTracking();
    
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _whatsappController.dispose();
    _addressController.dispose();
    _experienceController.dispose();
    _availableHoursController.dispose();
    _teamSizeController.dispose();
    _postalCodeController.dispose();
    _cityTextController.dispose();
    _districtTextController.dispose();
    _communeTextController.dispose();
    _quartierTextController.dispose();
    _minPriceController.dispose();
    _maxPriceController.dispose();
    _numberOfRoomsController.dispose();
    _surfaceAreaController.dispose();
    _numberOfDesksController.dispose();
    _meetingRoomsController.dispose();
    _capacityController.dispose();
    _landAreaController.dispose();
    _warehouseAreaController.dispose();
    _ceilingHeightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _lightColor,
      appBar: _buildAppBar(),
      body: Form(
        key: _formKey,
        autovalidateMode: _autoValidateMode,
        child: Column(
          children: [
            _buildProgressIndicator(),
            Expanded(
              child: _buildCurrentStepContent(),
            ),
            _buildBottomNavigation(),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildStep0();
      case 1:
        return _buildStep1();
      case 2:
        return _buildStep2();
      default:
        return _buildStep0();
    }
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text(
        'Nouveau service',
        style: TextStyle(
          color: _darkColor,
          fontWeight: FontWeight.w600,
          fontSize: _titleSize,
        ),
      ),
      centerTitle: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new_rounded, color: _darkColor, size: 22),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        Padding(
          padding: EdgeInsets.only(right: 16),
          child: Center(
            child: Text(
              '${_currentStep + 1}/3',
              style: TextStyle(
                color: _greyColor,
                fontWeight: FontWeight.w500,
                fontSize: _bodySize,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: _mediumSpace, horizontal: _largeSpace),
      decoration: BoxDecoration(
        color: _cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: Offset(0, 4),
          )
        ],
      ),
      child: Column(
        children: [
          LinearProgressIndicator(
            value: (_currentStep + 1) / 3,
            backgroundColor: _borderColor,
            color: _primaryColor,
            minHeight: 6,
            borderRadius: BorderRadius.circular(10),
          ),
          SizedBox(height: _smallSpace),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStepLabel(0, 'Type & Photos'),
              _buildStepLabel(1, 'Détails'),
              _buildStepLabel(2, 'Contact & Localisation'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepLabel(int stepIndex, String label) {
    final isActive = _currentStep == stepIndex;
    final isValid = _stepValidations[stepIndex] ?? false;

    return GestureDetector(
      onTap: () {
        if (mounted) {
          setState(() => _currentStep = stepIndex);
        }
      },
      child: Column(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive ? _primaryColor : isValid ? _successColor.withOpacity(0.1) : _borderColor,
              border: Border.all(
                color: isValid ? _successColor : isActive ? _primaryColor : _borderColor,
                width: isValid ? 2 : 1,
              ),
            ),
            child: Center(
              child: isValid
                  ? Icon(Icons.check, color: _successColor, size: 18)
                  : Text(
                      '${stepIndex + 1}',
                      style: TextStyle(
                        color: isActive ? Colors.white : _greyColor,
                        fontWeight: FontWeight.w600,
                        fontSize: _bodySize,
                      ),
                    ),
            ),
          ),
          SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: isActive ? _primaryColor : _greyColor,
              fontSize: _captionSize,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  // STEP 0: Type de service et photos
  Widget _buildStep0() {
    return SingleChildScrollView(
      physics: BouncingScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: _mediumSpace, vertical: _mediumSpace),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Afficher la sélection du type seulement si pas pré-sélectionné
          if (widget.initialServiceType == null) ...[
            _buildModernSectionHeader(
              title: 'Type de service',
              icon: Icons.category_rounded,
            ),
            SizedBox(height: _mediumSpace),
            _buildServiceTypeGrid(),
            SizedBox(height: _largeSpace),
          ] else ...[
            // Afficher le type sélectionné de manière informative
            Container(
              padding: EdgeInsets.all(_mediumSpace),
              decoration: BoxDecoration(
                color: _primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _primaryColor.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(_selectedServiceType?.icon ?? Icons.info_rounded, color: _primaryColor),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Service: ${_selectedServiceType?.displayName ?? ""}',
                      style: TextStyle(
                        color: _darkColor,
                        fontSize: _bodySize,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: _largeSpace),
          ],
          _buildModernSectionHeader(
            title: 'Photos du service',
            icon: Icons.photo_library_rounded,
          ),
          SizedBox(height: _smallSpace),
          Text(
            'Ajoutez au moins 2 photos pour présenter votre service',
            style: TextStyle(
              color: _greyColor,
              fontSize: _captionSize,
            ),
          ),
          SizedBox(height: _mediumSpace),
          _buildImagesGrid(),
          SizedBox(height: _largeSpace),
        ],
      ),
    );
  }

  Widget _buildServiceTypeGrid() {
    final allServiceTypes = [
      ServiceType.majordhomme,
      ServiceType.demenagement,
      ServiceType.hotel,
      ServiceType.bureau,
      ServiceType.vacances,
      ServiceType.salleFete,
      ServiceType.salleFuneraire,
      ServiceType.terrain,
      ServiceType.entrepot,
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.1,
      ),
      itemCount: allServiceTypes.length,
      itemBuilder: (context, index) {
        final serviceType = allServiceTypes[index];
        final isSelected = _selectedServiceType == serviceType;
        return _buildServiceTypeOption(
          serviceType.displayName,
          serviceType.icon,
          isSelected,
          () {
            setState(() {
              _selectedServiceType = serviceType;
              // Réinitialiser les sélections spécifiques
              _selectedSpecialties.clear();
              _selectedHotelServices.clear();
              _selectedVacationAmenities.clear();
              _selectedEventEquipment.clear();
              _selectedFuneralServices.clear();
              _selectedLandFeatures.clear();
              _selectedWarehouseFeatures.clear();
              _validateStep0();
            });
          },
        );
      },
    );
  }

  Widget _buildServiceTypeOption(String title, IconData icon, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 300),
        padding: EdgeInsets.all(_mediumSpace),
        decoration: BoxDecoration(
          color: isSelected ? _primaryColor.withOpacity(0.1) : _lightColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? _primaryColor : _borderColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isSelected ? _primaryColor : _greyColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 24, color: isSelected ? Colors.white : _greyColor),
            ),
            SizedBox(height: _smallSpace),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? _primaryColor : _darkColor,
                fontWeight: FontWeight.w600,
                fontSize: _bodySize,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagesGrid() {
    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: GridView.builder(
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: _selectedImages.length + 1,
        padding: EdgeInsets.all(8),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildAddImageButton();
          } else {
            return _buildImageItem(_selectedImages[index - 1], index - 1);
          }
        },
      ),
    );
  }

  Widget _buildAddImageButton() {
    return GestureDetector(
      onTap: _pickImages,
      child: Container(
        decoration: BoxDecoration(
          color: _lightColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _borderColor, style: BorderStyle.solid),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_photo_alternate_rounded, color: _greyColor, size: 32),
            SizedBox(height: 4),
            Text(
              'Ajouter',
              style: TextStyle(color: _greyColor, fontSize: _captionSize),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageItem(XFile image, int index) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(
            File(image.path),
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: () {
              setState(() {
                _selectedImages.removeAt(index);
                _validateStep0();
              });
            },
            child: Container(
              padding: EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.close, color: Colors.white, size: 16),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickImages() async {
    try {
      final List<XFile>? images = await _picker.pickMultiImage(
        imageQuality: 85,
        maxWidth: 1440,
      );

      if (images != null && images.isNotEmpty && mounted) {
        setState(() {
          _selectedImages.addAll(images);
          _validateStep0();
        });
      }
    } catch (e) {
      FancyNotification.show(context, "Erreur lors de la sélection des images", isError: true);
    }
  }

  // STEP 1: Détails du service
  Widget _buildStep1() {
    return SingleChildScrollView(
      physics: BouncingScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: _mediumSpace, vertical: _mediumSpace),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildModernSectionHeader(title: 'Informations de base', icon: Icons.info_rounded),
          SizedBox(height: _mediumSpace),
          _buildTextField(_titleController, 'Titre du service', Icons.title_rounded),
          SizedBox(height: _mediumSpace),
          _buildTextField(_descriptionController, 'Description détaillée', Icons.description_rounded, maxLines: 5),
          SizedBox(height: _mediumSpace),
          
          // Choix de la devise
          _buildCurrencyDropdown(),
          SizedBox(height: _mediumSpace),
          
          // Prix minimum et maximum
          _buildModernSectionHeader(title: 'Fourchette de prix', icon: Icons.attach_money_rounded),
          SizedBox(height: _smallSpace),
          Container(
            padding: EdgeInsets.all(_mediumSpace),
            decoration: BoxDecoration(
              color: _primaryColor.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _primaryColor.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, color: _primaryColor, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Indiquez une fourchette de prix pour donner plus de flexibilité à vos clients',
                    style: TextStyle(
                      color: _greyColor,
                      fontSize: _captionSize,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: _mediumSpace),
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  _minPriceController,
                  'Prix minimum',
                  Icons.trending_down_rounded,
                  keyboardType: TextInputType.number,
                  helperText: 'Le prix le plus bas pour votre service',
                ),
              ),
              SizedBox(width: _smallSpace),
              Expanded(
                child: _buildTextField(
                  _maxPriceController,
                  'Prix maximum',
                  Icons.trending_up_rounded,
                  keyboardType: TextInputType.number,
                  helperText: 'Le prix le plus élevé pour votre service',
                ),
              ),
            ],
          ),
          SizedBox(height: _mediumSpace),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _buildTextField(_priceController, 'Prix fixe (optionnel)', Icons.attach_money_rounded, keyboardType: TextInputType.number),
              ),
              SizedBox(width: _smallSpace),
              Expanded(
                child: _buildPriceUnitDropdown(),
              ),
            ],
          ),
          SizedBox(height: _largeSpace),
          
          // Année d'expérience (pour tous les services)
          _buildTextField(
            _experienceController,
            'Années d\'expérience',
            Icons.work_history_rounded,
            keyboardType: TextInputType.number,
            helperText: 'Nombre d\'années d\'expérience dans ce domaine',
          ),
          SizedBox(height: _largeSpace),
          
          // Import CV (optionnel)
          _buildModernSectionHeader(title: 'Curriculum Vitae (optionnel)', icon: Icons.description_rounded),
          SizedBox(height: _smallSpace),
          Container(
            padding: EdgeInsets.all(_mediumSpace),
            decoration: BoxDecoration(
              color: _primaryColor.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _primaryColor.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, color: _primaryColor, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Ajoutez votre CV pour renforcer votre crédibilité (PDF ou DOC)',
                    style: TextStyle(
                      color: _greyColor,
                      fontSize: _captionSize,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: _mediumSpace),
          _buildCvUploadSection(),
          SizedBox(height: _largeSpace),
          if (_selectedServiceType == ServiceType.majordhomme) ...[
            _buildModernSectionHeader(title: 'Spécialités', icon: Icons.star_rounded),
            SizedBox(height: _mediumSpace),
            _buildSpecialtiesGrid(),
            SizedBox(height: _largeSpace),
          ],
          if (_selectedServiceType == ServiceType.demenagement) ...[
            _buildModernSectionHeader(title: 'Informations supplémentaires', icon: Icons.info_rounded),
            SizedBox(height: _mediumSpace),
            _buildSwitchTile('Possédez-vous un véhicule ?', _hasVehicle, (value) {
              setState(() => _hasVehicle = value);
            }),
            _buildSwitchTile('Avez-vous une équipe ?', _hasTeam, (value) {
              setState(() => _hasTeam = value);
            }),
            if (_hasTeam) ...[
              SizedBox(height: _mediumSpace),
              _buildTextField(_teamSizeController, 'Taille de l\'équipe', Icons.group_rounded, keyboardType: TextInputType.number),
            ],
          ],
          if (_selectedServiceType == ServiceType.hotel) ...[
            _buildModernSectionHeader(title: 'Informations de l\'hôtel', icon: Icons.hotel_rounded),
            SizedBox(height: _mediumSpace),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(_numberOfRoomsController, 'Nombre de chambres', Icons.bed_rounded, keyboardType: TextInputType.number),
                ),
                SizedBox(width: _smallSpace),
                Expanded(
                  child: _buildStarRatingSelector(),
                ),
              ],
            ),
            SizedBox(height: _mediumSpace),
            _buildModernSectionHeader(title: 'Services disponibles', icon: Icons.room_service_rounded),
            SizedBox(height: _mediumSpace),
            _buildServicesGrid(_hotelServices, _selectedHotelServices, (value) {
              setState(() {
                if (_selectedHotelServices.contains(value)) {
                  _selectedHotelServices.remove(value);
                } else {
                  _selectedHotelServices.add(value);
                }
              });
            }),
          ],
          if (_selectedServiceType == ServiceType.bureau) ...[
            _buildModernSectionHeader(title: 'Informations du bureau', icon: Icons.business_rounded),
            SizedBox(height: _mediumSpace),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(_surfaceAreaController, 'Superficie (m²)', Icons.square_foot_rounded, keyboardType: TextInputType.number),
                ),
                SizedBox(width: _smallSpace),
                Expanded(
                  child: _buildTextField(_numberOfDesksController, 'Nombre de bureaux', Icons.desktop_windows_rounded, keyboardType: TextInputType.number),
                ),
              ],
            ),
            SizedBox(height: _mediumSpace),
            _buildTextField(_meetingRoomsController, 'Nombre de salles de réunion', Icons.meeting_room_rounded, keyboardType: TextInputType.number),
            SizedBox(height: _mediumSpace),
            _buildSwitchTile('Parking disponible', _hasParking, (value) {
              setState(() => _hasParking = value);
            }),
            _buildSwitchTile('Sécurité', _hasSecurity, (value) {
              setState(() => _hasSecurity = value);
            }),
          ],
          if (_selectedServiceType == ServiceType.vacances) ...[
            _buildModernSectionHeader(title: 'Informations du logement', icon: Icons.beach_access_rounded),
            SizedBox(height: _mediumSpace),
            _buildVacationTypeSelector(),
            SizedBox(height: _mediumSpace),
            _buildTextField(_capacityController, 'Capacité (nombre de personnes)', Icons.people_rounded, keyboardType: TextInputType.number),
            SizedBox(height: _mediumSpace),
            _buildModernSectionHeader(title: 'Équipements', icon: Icons.room_preferences_rounded),
            SizedBox(height: _mediumSpace),
            _buildServicesGrid(_vacationAmenities, _selectedVacationAmenities, (value) {
              setState(() {
                if (_selectedVacationAmenities.contains(value)) {
                  _selectedVacationAmenities.remove(value);
                } else {
                  _selectedVacationAmenities.add(value);
                }
              });
            }),
          ],
          if (_selectedServiceType == ServiceType.salleFete) ...[
            _buildModernSectionHeader(title: 'Informations de la salle', icon: Icons.celebration_rounded),
            SizedBox(height: _mediumSpace),
            _buildTextField(_capacityController, 'Capacité (nombre de personnes)', Icons.people_rounded, keyboardType: TextInputType.number),
            SizedBox(height: _mediumSpace),
            _buildModernSectionHeader(title: 'Équipements disponibles', icon: Icons.settings_rounded),
            SizedBox(height: _mediumSpace),
            _buildServicesGrid(_eventEquipment, _selectedEventEquipment, (value) {
              setState(() {
                if (_selectedEventEquipment.contains(value)) {
                  _selectedEventEquipment.remove(value);
                } else {
                  _selectedEventEquipment.add(value);
                }
              });
            }),
          ],
          if (_selectedServiceType == ServiceType.salleFuneraire) ...[
            _buildModernSectionHeader(title: 'Informations de la salle', icon: Icons.church_rounded),
            SizedBox(height: _mediumSpace),
            _buildTextField(_capacityController, 'Capacité (nombre de personnes)', Icons.people_rounded, keyboardType: TextInputType.number),
            SizedBox(height: _mediumSpace),
            _buildModernSectionHeader(title: 'Services disponibles', icon: Icons.miscellaneous_services_rounded),
            SizedBox(height: _mediumSpace),
            _buildServicesGrid(_funeralServices, _selectedFuneralServices, (value) {
              setState(() {
                if (_selectedFuneralServices.contains(value)) {
                  _selectedFuneralServices.remove(value);
                } else {
                  _selectedFuneralServices.add(value);
                }
              });
            }),
          ],
          if (_selectedServiceType == ServiceType.terrain) ...[
            _buildModernSectionHeader(title: 'Informations du terrain', icon: Icons.landscape_rounded),
            SizedBox(height: _mediumSpace),
            _buildTextField(_landAreaController, 'Superficie (m² ou hectares)', Icons.square_foot_rounded, keyboardType: TextInputType.number),
            SizedBox(height: _mediumSpace),
            _buildLandTypeSelector(),
            SizedBox(height: _mediumSpace),
            _buildModernSectionHeader(title: 'Caractéristiques', icon: Icons.checklist_rounded),
            SizedBox(height: _mediumSpace),
            _buildServicesGrid(_landFeatures, _selectedLandFeatures, (value) {
              setState(() {
                if (_selectedLandFeatures.contains(value)) {
                  _selectedLandFeatures.remove(value);
                } else {
                  _selectedLandFeatures.add(value);
                }
              });
            }),
          ],
          if (_selectedServiceType == ServiceType.entrepot) ...[
            _buildModernSectionHeader(title: 'Informations de l\'entrepôt', icon: Icons.warehouse_rounded),
            SizedBox(height: _mediumSpace),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(_warehouseAreaController, 'Superficie (m²)', Icons.square_foot_rounded, keyboardType: TextInputType.number),
                ),
                SizedBox(width: _smallSpace),
                Expanded(
                  child: _buildTextField(_ceilingHeightController, 'Hauteur sous plafond (m)', Icons.height_rounded, keyboardType: TextInputType.number),
                ),
              ],
            ),
            SizedBox(height: _mediumSpace),
            _buildWarehouseTypeSelector(),
            SizedBox(height: _mediumSpace),
            _buildModernSectionHeader(title: 'Équipements', icon: Icons.settings_rounded),
            SizedBox(height: _mediumSpace),
            _buildServicesGrid(_warehouseFeatures, _selectedWarehouseFeatures, (value) {
              setState(() {
                if (_selectedWarehouseFeatures.contains(value)) {
                  _selectedWarehouseFeatures.remove(value);
                } else {
                  _selectedWarehouseFeatures.add(value);
                }
              });
            }),
          ],
          SizedBox(height: _largeSpace),
          _buildModernSectionHeader(title: 'Disponibilité', icon: Icons.calendar_today_rounded),
          SizedBox(height: _mediumSpace),
          _buildDaysSelector(),
          SizedBox(height: _mediumSpace),
          _buildTextField(_availableHoursController, 'Heures de disponibilité (ex: 08:00-18:00)', Icons.access_time_rounded),
          SizedBox(height: _largeSpace),
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {int maxLines = 1, TextInputType? keyboardType, void Function(String)? onChanged, String? helperText}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _borderColor),
          ),
          child: TextField(
            controller: controller,
            maxLines: maxLines,
            keyboardType: keyboardType,
            style: TextStyle(color: _darkColor, fontSize: _bodySize),
            decoration: InputDecoration(
              labelText: label,
              prefixIcon: Icon(icon, color: _primaryColor),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              labelStyle: TextStyle(color: _greyColor),
              helperText: helperText,
              helperStyle: TextStyle(
                color: _greyColor,
                fontSize: _captionSize,
                fontStyle: FontStyle.italic,
              ),
            ),
            onChanged: onChanged ?? (_) => _validateStep1(),
          ),
        ),
      ],
    );
  }

  Widget _buildCurrencyDropdown() {
    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor),
      ),
      padding: EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedCurrency,
          hint: Text('Devise', style: TextStyle(color: _greyColor, fontSize: _bodySize)),
          isExpanded: true,
          items: [
            DropdownMenuItem(
              value: 'CDF',
              child: Row(
                children: [
                  Text('Franc Congolais (CDF)', style: TextStyle(fontSize: _bodySize)),
                  SizedBox(width: 8),
                  Text('FC', style: TextStyle(fontSize: _captionSize, color: _greyColor)),
                ],
              ),
            ),
            DropdownMenuItem(
              value: 'USD',
              child: Row(
                children: [
                  Text('Dollar Américain (USD)', style: TextStyle(fontSize: _bodySize)),
                  SizedBox(width: 8),
                  Text('\$', style: TextStyle(fontSize: _captionSize, color: _greyColor)),
                ],
              ),
            ),
          ],
          onChanged: (value) {
            setState(() {
              _selectedCurrency = value;
              _trackSelection('currency', value ?? 'unknown');
            });
          },
          icon: Icon(Icons.currency_exchange_rounded, color: _primaryColor),
        ),
      ),
    );
  }

  Widget _buildPriceUnitDropdown() {
    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor),
      ),
      padding: EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedPriceUnit,
          hint: Text('Unité', style: TextStyle(color: _greyColor, fontSize: _bodySize)),
          isExpanded: true,
          items: _priceUnits.map((unit) {
            return DropdownMenuItem(
              value: unit,
              child: Text(unit, style: TextStyle(fontSize: _bodySize)),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedPriceUnit = value;
              _validateStep1();
            });
          },
        ),
      ),
    );
  }

  Widget _buildCvUploadSection() {
    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _selectedCvFile != null ? _successColor : _borderColor,
          width: _selectedCvFile != null ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: _pickCvFile,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(_mediumSpace),
          child: Column(
            children: [
              Icon(
                _selectedCvFile != null ? Icons.check_circle_rounded : Icons.upload_file_rounded,
                color: _selectedCvFile != null ? _successColor : _primaryColor,
                size: 48,
              ),
              SizedBox(height: _smallSpace),
              Text(
                _selectedCvFile != null ? 'CV importé' : 'Importer un CV',
                style: TextStyle(
                  color: _darkColor,
                  fontSize: _bodySize,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (_selectedCvFile != null) ...[
                SizedBox(height: 4),
                Text(
                  _selectedCvFile!.path.split('/').last,
                  style: TextStyle(
                    color: _greyColor,
                    fontSize: _captionSize,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _removeCvFile,
                  icon: Icon(Icons.delete_outline_rounded, size: 16, color: _errorColor),
                  label: Text('Supprimer', style: TextStyle(color: _errorColor, fontSize: _captionSize)),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    minimumSize: Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ] else ...[
                SizedBox(height: 4),
                Text(
                  'PDF ou DOC (max 5 MB)',
                  style: TextStyle(
                    color: _greyColor,
                    fontSize: _captionSize,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickCvFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx'],
        withData: false,
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        
        // Vérifier la taille du fichier (max 5 MB)
        final fileSize = await file.length();
        if (fileSize > 5 * 1024 * 1024) {
          FancyNotification.show(
            context,
            "Le fichier est trop volumineux. Taille maximale: 5 MB",
            isError: true,
          );
          return;
        }

        setState(() {
          _selectedCvFile = file;
        });

        _trackEvent('cv_file_selected', {
          'file_name': file.path.split('/').last,
          'file_size_mb': (fileSize / (1024 * 1024)).toStringAsFixed(2),
        });

        FancyNotification.show(
          context,
          "CV importé avec succès",
          isError: false,
        );
      }
    } catch (e) {
      print('Erreur lors de la sélection du CV: $e');
      _trackEvent('cv_file_selection_error', {
        'error': e.toString(),
      });
      FancyNotification.show(
        context,
        "Erreur lors de l'import du CV",
        isError: true,
      );
    }
  }

  void _removeCvFile() {
    setState(() {
      _selectedCvFile = null;
    });
    _trackEvent('cv_file_removed', {});
  }

  Widget _buildSpecialtiesGrid() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _majordhommeSpecialties.map((specialty) {
        final isSelected = _selectedSpecialties.contains(specialty);
        return FilterChip(
          label: Text(specialty),
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              if (selected) {
                _selectedSpecialties.add(specialty);
              } else {
                _selectedSpecialties.remove(specialty);
              }
            });
          },
          selectedColor: _primaryColor.withOpacity(0.2),
          checkmarkColor: _primaryColor,
        );
      }).toList(),
    );
  }

  Widget _buildDaysSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _daysOfWeek.map((day) {
        final isSelected = _selectedDays.contains(day);
        return FilterChip(
          label: Text(day),
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              if (selected) {
                _selectedDays.add(day);
              } else {
                _selectedDays.remove(day);
              }
            });
          },
          selectedColor: _primaryColor.withOpacity(0.2),
          checkmarkColor: _primaryColor,
        );
      }).toList(),
    );
  }

  Widget _buildSwitchTile(String title, bool value, Function(bool) onChanged) {
    return Container(
      margin: EdgeInsets.only(bottom: _smallSpace),
      padding: EdgeInsets.all(_mediumSpace),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(color: _darkColor, fontSize: _bodySize)),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: _primaryColor,
          ),
        ],
      ),
    );
  }

  Widget _buildServicesGrid(List<String> services, Set<String> selectedServices, Function(String) onToggle) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: services.map((service) {
        final isSelected = selectedServices.contains(service);
        return FilterChip(
          label: Text(service),
          selected: isSelected,
          onSelected: (selected) => onToggle(service),
          selectedColor: _primaryColor.withOpacity(0.2),
          checkmarkColor: _primaryColor,
        );
      }).toList(),
    );
  }

  Widget _buildStarRatingSelector() {
    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor),
      ),
      padding: EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _selectedStarRating,
          hint: Text('Étoiles', style: TextStyle(color: _greyColor, fontSize: _bodySize)),
          isExpanded: true,
          items: List.generate(5, (index) => index + 1).map((stars) {
            return DropdownMenuItem(
              value: stars,
              child: Row(
                children: [
                  Text('$stars ', style: TextStyle(fontSize: _bodySize)),
                  ...List.generate(stars, (i) => Icon(Icons.star, size: 16, color: Colors.amber)),
                ],
              ),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedStarRating = value;
            });
          },
        ),
      ),
    );
  }

  Widget _buildVacationTypeSelector() {
    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor),
      ),
      padding: EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedVacationType,
          hint: Text('Type de logement', style: TextStyle(color: _greyColor, fontSize: _bodySize)),
          isExpanded: true,
          items: _vacationTypes.map((type) {
            return DropdownMenuItem(
              value: type,
              child: Text(type, style: TextStyle(fontSize: _bodySize)),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedVacationType = value;
            });
          },
        ),
      ),
    );
  }

  Widget _buildLandTypeSelector() {
    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor),
      ),
      padding: EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedLandType,
          hint: Text('Type de terrain', style: TextStyle(color: _greyColor, fontSize: _bodySize)),
          isExpanded: true,
          items: _landTypes.map((type) {
            return DropdownMenuItem(
              value: type,
              child: Text(type, style: TextStyle(fontSize: _bodySize)),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedLandType = value;
            });
          },
        ),
      ),
    );
  }

  Widget _buildWarehouseTypeSelector() {
    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor),
      ),
      padding: EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedWarehouseType,
          hint: Text('Type d\'entrepôt', style: TextStyle(color: _greyColor, fontSize: _bodySize)),
          isExpanded: true,
          items: _warehouseTypes.map((type) {
            return DropdownMenuItem(
              value: type,
              child: Text(type, style: TextStyle(fontSize: _bodySize)),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedWarehouseType = value;
            });
          },
        ),
      ),
    );
  }

  // STEP 2: Contact et localisation
  Widget _buildStep2() {
    return SingleChildScrollView(
      physics: BouncingScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: _mediumSpace, vertical: _mediumSpace),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildModernSectionHeader(title: 'Coordonnées', icon: Icons.contact_phone_rounded),
          SizedBox(height: _mediumSpace),
          _buildTextField(
            _phoneController, 
            'Téléphone', 
            Icons.phone_rounded, 
            keyboardType: TextInputType.phone,
            onChanged: (_) => _validateStep2(),
          ),
          SizedBox(height: _mediumSpace),
          _buildTextField(_emailController, 'Email (optionnel)', Icons.email_rounded, keyboardType: TextInputType.emailAddress),
          SizedBox(height: _mediumSpace),
          _buildTextField(_whatsappController, 'WhatsApp (optionnel)', FontAwesomeIcons.whatsapp, keyboardType: TextInputType.phone),
          SizedBox(height: _largeSpace),
          _buildModernSectionHeader(title: 'Localisation', icon: Icons.location_on_rounded),
          SizedBox(height: _mediumSpace),
          _buildLocationDropdowns(),
          SizedBox(height: _mediumSpace),
          _buildTextField(_addressController, 'Adresse détaillée', Icons.home_rounded, maxLines: 2),
          SizedBox(height: _mediumSpace),
          _buildTextField(_postalCodeController, 'Code postal', Icons.markunread_mailbox_rounded, keyboardType: TextInputType.number),
          SizedBox(height: _largeSpace),
        ],
      ),
    );
  }

  Widget _buildLocationDropdowns() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Ville avec suggestions (typeahead)
        _buildCitySuggestionField(),
        SizedBox(height: _mediumSpace),
        
        if (_isKinshasaSelected) ...[
          // Dropdowns premium pour Kinshasa
          LayoutBuilder(
            builder: (context, constraints) {
              return Row(
                children: [
                  Container(
                    width: constraints.maxWidth * 0.48,
                    child: _buildPremiumDropdown<DistrictModel>(
                      label: 'District',
                      value: _selectedDistrict,
                      items: _availableDistricts,
                      displayText: (district) => district.name ?? '',
                      onChanged: (DistrictModel? newValue) {
                        if (mounted) {
                          _markFieldTouched('district');
                          _clickCount++;
                          setState(() {
                            _selectedDistrict = newValue;
                            _removeFieldError(2, 'district');
                            _updateCommunesForDistrict();
                            _validateStep2();
                          });
                          _trackSelection('district', newValue?.name ?? 'unknown');
                        }
                      },
                      icon: Icons.account_balance_rounded,
                      errorText: _shouldShowError(2, 'district') ? _getFieldError(2, 'district') : null,
                      hintText: 'Sélectionnez un district',
                    ),
                  ),
                  SizedBox(width: constraints.maxWidth * 0.04),
                  Container(
                    width: constraints.maxWidth * 0.48,
                    child: _buildPremiumDropdown<CommuneModel>(
                      label: 'Commune',
                      value: _selectedCommune,
                      items: _availableCommunes,
                      displayText: (commune) => commune.name ?? '',
                      onChanged: (CommuneModel? newValue) {
                        if (mounted) {
                          _markFieldTouched('commune');
                          _clickCount++;
                          setState(() {
                            _selectedCommune = newValue;
                            _removeFieldError(2, 'commune');
                            _updateQuartiersForCommune();
                            _validateStep2();
                          });
                          _trackSelection('commune', newValue?.name ?? 'unknown');
                        }
                      },
                      icon: Icons.place_rounded,
                      errorText: _shouldShowError(2, 'commune') ? _getFieldError(2, 'commune') : null,
                      hintText: 'Sélectionnez une commune',
                    ),
                  ),
                ],
              );
            },
          ),
          SizedBox(height: _mediumSpace),
        ] else ...[
          // Mode hors Kinshasa : champs avec suggestions/autocomplete
          _buildSuggestionTextField(
            label: 'District',
            controller: _districtTextController,
            fieldKey: 'district',
            suggestions: _availableDistricts.map((d) => d.name ?? '').where((n) => n.isNotEmpty).toList(),
          ),
          SizedBox(height: _smallSpace),
          _buildSuggestionTextField(
            label: 'Commune',
            controller: _communeTextController,
            fieldKey: 'commune',
            suggestions: _availableCommunes.map((c) => c.name ?? '').where((n) => n.isNotEmpty).toList(),
          ),
          SizedBox(height: _smallSpace),
          _buildSuggestionTextField(
            label: 'Quartier',
            controller: _quartierTextController,
            fieldKey: 'quartier',
            suggestions: _availableQuartiers.map((q) => q.name ?? '').where((n) => n.isNotEmpty).toList(),
          ),
          SizedBox(height: _mediumSpace),
        ],
      ],
    );
  }

  Widget _buildCitySuggestionField() {
    final errorText = _getFieldError(2, 'city');
    final hasError = errorText != null && errorText.isNotEmpty && _shouldShowError(2, 'city');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: 6, left: 4),
          child: Row(
            children: [
              Text(
                'Ville',
                style: TextStyle(
                  fontSize: _bodySize,
                  fontWeight: FontWeight.w600,
                  color: hasError ? _errorColor : _darkColor,
                ),
              ),
              Text('*', style: TextStyle(color: _errorColor, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        Autocomplete<String>(
          initialValue: TextEditingValue(text: _cityTextController.text),
          optionsBuilder: (TextEditingValue textEditingValue) {
            return _filterSuggestions(textEditingValue.text, CitySuggestions.cities);
          },
          onSelected: (String selection) {
            _markFieldTouched('city');
            _clickCount++;
            setState(() {
              _cityTextController.text = selection;
              // si Kinshasa, utiliser la sélection stricte et garder le workflow existant
              final kin = _availableCities.firstWhere(
                  (c) => (c.name ?? '').toLowerCase() == selection.toLowerCase(),
                  orElse: () => _selectedCity ?? (_availableCities.isNotEmpty ? _availableCities.first : CityModel(cityId: 1, name: 'Kinshasa')));
              if (selection.toLowerCase().trim() == 'kinshasa') {
                _selectedCity = kin.name == null ? _selectedCity : kin;
                _updateDistrictsForCity();
              } else {
                _selectedCity = null;
                _selectedDistrict = null;
                _selectedCommune = null;
                _selectedQuartier = null;
              }
              _removeFieldError(2, 'city');
              _validateStep2();
            });
            _trackSelection('city', selection);
          },
          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
            _cityTextController.value = controller.value;
            return TextField(
              controller: controller,
              focusNode: focusNode,
              onChanged: (value) {
                _markFieldTouched('city');
                _removeFieldError(2, 'city');
                // Vérifier si Kinshasa est tapé
                if (value.toLowerCase().trim() == 'kinshasa') {
                  final kin = _availableCities.firstWhere(
                      (c) => (c.name ?? '').toLowerCase() == 'kinshasa',
                      orElse: () => _availableCities.isNotEmpty ? _availableCities.first : CityModel(cityId: 1, name: 'Kinshasa'));
                  _selectedCity = kin;
                  _updateDistrictsForCity();
                } else {
                  _selectedCity = null;
                  _selectedDistrict = null;
                  _selectedCommune = null;
                  _selectedQuartier = null;
                }
                _validateStep2();
              },
              decoration: InputDecoration(
                hintText: 'Ex: Kinshasa, Lubumbashi...',
                prefixIcon: Icon(Icons.location_city_rounded, color: hasError ? _errorColor : _primaryColor),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: hasError ? _errorColor : _borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: hasError ? _errorColor : _borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: hasError ? _errorColor : _primaryColor),
                ),
                errorText: null, // géré manuellement
              ),
              onSubmitted: (_) => onFieldSubmitted(),
            );
          },
        ),
        if (hasError)
          Padding(
            padding: EdgeInsets.only(top: 6, left: 4),
            child: Row(
              children: [
                Icon(Icons.error_outline_rounded, size: 14, color: _errorColor),
                SizedBox(width: 6),
                Text(
                  errorText!,
                  style: TextStyle(
                    color: _errorColor,
                    fontSize: _captionSize,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildSuggestionTextField({
    required String label,
    required TextEditingController controller,
    required String fieldKey,
    required List<String> suggestions,
  }) {
    final errorText = _getFieldError(2, fieldKey);
    final hasError = errorText != null && errorText.isNotEmpty && _shouldShowError(2, fieldKey);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: 6, left: 4, top: _smallSpace),
          child: Row(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: _captionSize,
                  fontWeight: FontWeight.w600,
                  color: hasError ? _errorColor : _darkColor,
                ),
              ),
            ],
          ),
        ),
        Autocomplete<String>(
          initialValue: TextEditingValue(text: controller.text),
          optionsBuilder: (TextEditingValue textEditingValue) {
            return _filterSuggestions(textEditingValue.text, suggestions);
          },
          onSelected: (String selection) {
            _markFieldTouched(fieldKey);
            _clickCount++;
            setState(() {
              controller.text = selection;
              _removeFieldError(2, fieldKey);
              _validateStep2();
            });
            _trackSelection(fieldKey, selection);
          },
          fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
            controller.value = textController.value;
            return TextField(
              controller: textController,
              focusNode: focusNode,
              onChanged: (value) {
                _markFieldTouched(fieldKey);
                _removeFieldError(2, fieldKey);
                _validateStep2();
              },
              style: TextStyle(
                fontSize: _bodySize,
                color: _darkColor,
              ),
              decoration: InputDecoration(
                hintText: 'Saisir $label',
                hintStyle: TextStyle(
                  fontSize: _bodySize,
                  color: Colors.grey.shade500,
                ),
                prefixIcon: Icon(Icons.place_rounded, color: hasError ? _errorColor : _primaryColor),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: hasError ? _errorColor : _borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: hasError ? _errorColor : _borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: hasError ? _errorColor : _primaryColor, width: 2),
                ),
                errorText: null,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
              onSubmitted: (_) => onFieldSubmitted(),
            );
          },
        ),
        if (hasError)
          Padding(
            padding: EdgeInsets.only(top: 6, left: 4),
            child: Row(
              children: [
                Icon(Icons.error_outline_rounded, size: 14, color: _errorColor),
                SizedBox(width: 6),
                Text(
                  errorText!,
                  style: TextStyle(
                    color: _errorColor,
                    fontSize: _captionSize,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildPremiumDropdown<T>({
    required String label,
    required T? value,
    required List<T> items,
    required String Function(T) displayText,
    required void Function(T?) onChanged,
    required IconData icon,
    String? errorText,
    String? hintText,
    bool isRequired = true,
  }) {
    final hasError = errorText != null && errorText.isNotEmpty;

    return Container(
      margin: EdgeInsets.only(bottom: _smallSpace),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: 6, left: 4),
            child: Row(
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: _bodySize,
                    fontWeight: FontWeight.w600,
                    color: hasError ? _errorColor : _darkColor,
                  ),
                ),
                if (isRequired)
                  Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Text(
                      '*',
                      style: TextStyle(
                        color: _errorColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasError ? _errorColor : value != null ? _primaryColor.withOpacity(0.3) : _borderColor,
                width: hasError ? 1.5 : 1,
              ),
              color: Colors.white,
              boxShadow: [
                if (value != null)
                  BoxShadow(
                    color: _primaryColor.withOpacity(0.05),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
              ],
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<T>(
                value: value,
                isExpanded: true,
                items: [
                  DropdownMenuItem<T>(
                    value: null,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        hintText ?? 'Sélectionnez...',
                        style: TextStyle(
                          color: _greyColor,
                          fontSize: _bodySize,
                        ),
                      ),
                    ),
                  ),
                  ...items.map((T item) {
                    return DropdownMenuItem<T>(
                      value: item,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                displayText(item),
                                style: TextStyle(
                                  fontSize: _bodySize,
                                  color: _darkColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            if (value == item)
                              Icon(
                                Icons.check_circle_rounded,
                                size: 16,
                                color: _successColor,
                              ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ],
                onChanged: onChanged,
                style: TextStyle(
                  fontSize: _bodySize,
                  color: _darkColor,
                ),
                icon: Padding(
                  padding: EdgeInsets.only(right: 16),
                  child: Icon(
                    Icons.arrow_drop_down_rounded,
                    color: hasError ? _errorColor : _greyColor,
                    size: 24,
                  ),
                ),
                dropdownColor: Colors.white,
                borderRadius: BorderRadius.circular(12),
                elevation: 4,
                menuMaxHeight: 300,
              ),
            ),
          ),

          if (hasError)
            Padding(
              padding: EdgeInsets.only(top: 6, left: 4),
              child: Row(
                children: [
                  Icon(Icons.error_outline_rounded, size: 14, color: _errorColor),
                  SizedBox(width: 6),
                  Text(
                    errorText!,
                    style: TextStyle(
                      color: _errorColor,
                      fontSize: _captionSize,
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

  Widget _buildLocationDropdown<T>(String label, String value, List<T> items, Function(T) onChanged, IconData icon) {
    T? selectedValue;
    if (items.isNotEmpty && value != 'Sélectionner') {
      try {
        selectedValue = items.firstWhere((item) {
          if (item is CityModel) return item.name == value;
          if (item is DistrictModel) return item.name == value;
          if (item is CommuneModel) return item.name == value;
          if (item is QuartierModel) return item.name == value;
          return false;
        });
      } catch (e) {
        selectedValue = null;
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor),
      ),
      padding: EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: selectedValue,
          hint: Row(
            children: [
              Icon(icon, color: _primaryColor, size: 20),
              SizedBox(width: 8),
              Text(value, style: TextStyle(color: _greyColor, fontSize: _bodySize)),
            ],
          ),
          isExpanded: true,
          items: items.map((item) {
            String name = '';
            if (item is CityModel) name = item.name ?? '';
            if (item is DistrictModel) name = item.name ?? '';
            if (item is CommuneModel) name = item.name ?? '';
            if (item is QuartierModel) name = item.name ?? '';
            return DropdownMenuItem(
              value: item,
              child: Text(name, style: TextStyle(fontSize: _bodySize)),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) onChanged(value);
          },
        ),
      ),
    );
  }

  Widget _buildModernSectionHeader({required String title, required IconData icon}) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: _primaryColor, size: 20),
        ),
        SizedBox(width: _smallSpace),
        Text(
          title,
          style: TextStyle(
            color: _darkColor,
            fontSize: _subtitleSize,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomNavigation() {
    return Container(
      padding: EdgeInsets.all(_mediumSpace),
      decoration: BoxDecoration(
        color: _cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, -2),
          )
        ],
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  setState(() => _currentStep--);
                },
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: BorderSide(color: _borderColor),
                ),
                child: Text('Précédent', style: TextStyle(color: _darkColor)),
              ),
            ),
          if (_currentStep > 0) SizedBox(width: _smallSpace),
          Expanded(
            flex: _currentStep == 0 ? 1 : 2,
            child: ElevatedButton(
              onPressed: _isLoading ? null : () {
                _clickCount++;
                _handleNextOrSubmit();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _isLoading 
                    ? _greyColor 
                    : (_hasFieldErrors(_currentStep) && _hasAttemptedSubmit 
                        ? _errorColor.withOpacity(0.7) 
                        : _primaryColor),
                padding: EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: _isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      _currentStep == 2 ? 'Publier le service' : 'Suivant',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleNextOrSubmit() {
    if (_currentStep < 2) {
      if (_validateCurrentStep()) {
        _trackEvent('step_completed', {
          'step': _currentStep,
          'step_name': _getStepName(_currentStep),
        });
        setState(() => _currentStep++);
      } else {
        _hasAttemptedSubmit = true;
        _showStepErrors();
        _trackEvent('step_validation_failed', {
          'step': _currentStep,
          'step_name': _getStepName(_currentStep),
          'errors': _stepErrorMessages[_currentStep] ?? '',
        });
      }
    } else {
      _hasAttemptedSubmit = true;
      if (_validateCurrentStep()) {
        _handleCreateService();
      } else {
        _showStepErrors();
        _trackEvent('submit_validation_failed', {
          'errors': _stepErrorMessages[_currentStep] ?? '',
        });
      }
    }
  }

  String _getStepName(int step) {
    switch (step) {
      case 0:
        return 'type_and_photos';
      case 1:
        return 'details';
      case 2:
        return 'contact_and_location';
      default:
        return 'unknown';
    }
  }

  bool _validateStep0() {
    final errors = <String>[];
    if (_selectedServiceType == null) {
      errors.add('Veuillez sélectionner un type de service');
    }
    if (_selectedImages.length < 2) {
      errors.add('Au moins 2 photos sont requises');
    }
    final isValid = errors.isEmpty;
    setState(() {
      _stepValidations[0] = isValid;
      _stepErrorMessages[0] = errors.join('\n');
    });
    return isValid;
  }

  bool _validateStep1() {
    final errors = <String>[];
    if (_titleController.text.trim().isEmpty) {
      errors.add('Le titre est requis');
    }
    if (_descriptionController.text.trim().isEmpty) {
      errors.add('La description est requise');
    }
    
    // Validation prix : soit prix fixe, soit min/max
    final hasFixedPrice = _priceController.text.trim().isNotEmpty;
    final hasMinPrice = _minPriceController.text.trim().isNotEmpty;
    final hasMaxPrice = _maxPriceController.text.trim().isNotEmpty;
    
    if (!hasFixedPrice && !hasMinPrice && !hasMaxPrice) {
      errors.add('Veuillez renseigner au moins un prix (fixe ou min/max)');
    }
    
    // Si min et max sont renseignés, vérifier que max >= min
    if (hasMinPrice && hasMaxPrice) {
      final minPrice = double.tryParse(_minPriceController.text.trim());
      final maxPrice = double.tryParse(_maxPriceController.text.trim());
      if (minPrice != null && maxPrice != null && maxPrice < minPrice) {
        errors.add('Le prix maximum doit être supérieur ou égal au prix minimum');
      }
    }
    
    if (_selectedPriceUnit == null) {
      errors.add('Veuillez sélectionner une unité de prix');
    }
    
    final isValid = errors.isEmpty;
    setState(() {
      _stepValidations[1] = isValid;
      _stepErrorMessages[1] = errors.join('\n');
    });
    return isValid;
  }

  bool _validateStep2() {
    final errors = <String>[];
    
    // Validation téléphone
    if (_phoneController.text.trim().isEmpty) {
      errors.add('Le numéro de téléphone est requis');
      _setFieldError(2, 'phone', 'Le numéro de téléphone est requis');
    } else {
      _removeFieldError(2, 'phone');
    }
    
    // Validation ville
    if (_selectedCity == null && _cityTextController.text.trim().isEmpty) {
      errors.add('Veuillez sélectionner ou saisir une ville');
      _setFieldError(2, 'city', 'Veuillez sélectionner ou saisir une ville');
    } else {
      _removeFieldError(2, 'city');
    }
    
    // Validation localisation selon si Kinshasa ou non
    if (_isKinshasaSelected) {
      // Pour Kinshasa : validation des dropdowns
      if (_selectedDistrict == null) {
        errors.add('Veuillez sélectionner un district');
        _setFieldError(2, 'district', 'Veuillez sélectionner un district');
      } else {
        _removeFieldError(2, 'district');
      }
      
      if (_selectedCommune == null) {
        errors.add('Veuillez sélectionner une commune');
        _setFieldError(2, 'commune', 'Veuillez sélectionner une commune');
      } else {
        _removeFieldError(2, 'commune');
      }
      
      if (_selectedQuartier == null) {
        errors.add('Veuillez sélectionner un quartier');
        _setFieldError(2, 'quartier', 'Veuillez sélectionner un quartier');
      } else {
        _removeFieldError(2, 'quartier');
      }
    } else {
      // Pour les autres villes : validation des champs texte
      if (_communeTextController.text.trim().isEmpty) {
        errors.add('Veuillez saisir une commune');
        _setFieldError(2, 'commune', 'Veuillez saisir une commune');
      } else {
        _removeFieldError(2, 'commune');
      }
      
      if (_quartierTextController.text.trim().isEmpty) {
        errors.add('Veuillez saisir un quartier');
        _setFieldError(2, 'quartier', 'Veuillez saisir un quartier');
      } else {
        _removeFieldError(2, 'quartier');
      }
    }
    
    final isValid = errors.isEmpty;
    setState(() {
      _stepValidations[2] = isValid;
      _stepErrorMessages[2] = errors.join('\n');
    });
    return isValid;
  }

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _validateStep0();
      case 1:
        return _validateStep1();
      case 2:
        return _validateStep2();
      default:
        return false;
    }
  }

  void _showStepErrors() {
    final error = _stepErrorMessages[_currentStep];
    if (error != null && error.isNotEmpty) {
      FancyNotification.show(context, error, isError: true);
    }
  }

  Future<void> _handleCreateService() async {
    if (!_validateStep2()) {
      _showStepErrors();
      _trackEvent('service_creation_validation_failed', {
        'errors': _stepErrorMessages[2] ?? '',
      });
      return;
    }

    setState(() {
      _autoValidateMode = AutovalidateMode.always;
      _isLoading = true;
    });

    FocusScope.of(context).unfocus();

    final isConnected = await NetworkUtils.checkInternetConnectivity();
    if (!isConnected) {
      FancyNotification.show(context, "Pas de connexion internet", isError: true);
      setState(() => _isLoading = false);
      _trackEvent('service_creation_no_internet', {});
      return;
    }

    // Track début de création
    await _trackEvent('service_api_call_start', {
      'service_type': _selectedServiceType?.value ?? 'unknown',
      'images_count': _selectedImages.length,
      'has_city': _selectedCity != null || _cityTextController.text.isNotEmpty,
      'is_kinshasa': _isKinshasaSelected,
      'has_district': _isKinshasaSelected ? (_selectedDistrict != null) : (_districtTextController.text.isNotEmpty),
      'has_commune': _isKinshasaSelected ? (_selectedCommune != null) : (_communeTextController.text.isNotEmpty),
    });

    try {
      final GetStorage storage = GetStorage();
      late final dynamic userData = storage.read(StockageKeys.userKey);
      late var userId = userData["userId"];

      // Préparer les images en base64
      List<String> imagesBase64 = [];
      for (var image in _selectedImages) {
        final file = File(image.path);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          final base64String = base64Encode(bytes);
          imagesBase64.add(base64String);
        }
      }

      // Préparer le CV en base64 s'il existe
      String? cvBase64;
      if (_selectedCvFile != null && await _selectedCvFile!.exists()) {
        final cvBytes = await _selectedCvFile!.readAsBytes();
        cvBase64 = base64Encode(cvBytes);
      }

      // Construire la map de base avec gestion Kinshasa
      final serviceData = <String, dynamic>{
        "title": _titleController.text.trim(),
        "description": _descriptionController.text.trim(),
        "serviceType": _selectedServiceType?.value,
        "price": _priceController.text.trim().isNotEmpty ? double.tryParse(_priceController.text) : null,
        "minPrice": _minPriceController.text.trim().isNotEmpty ? double.tryParse(_minPriceController.text) : null,
        "maxPrice": _maxPriceController.text.trim().isNotEmpty ? double.tryParse(_maxPriceController.text) : null,
        "currency": _selectedCurrency ?? 'CDF',
        "priceUnit": _selectedPriceUnit,
        "experienceYears": _experienceController.text.trim().isNotEmpty ? int.tryParse(_experienceController.text) : null,
        "phone": _phoneController.text.trim(),
        "email": _emailController.text.trim().isNotEmpty ? _emailController.text.trim() : null,
        "whatsapp": _whatsappController.text.trim().isNotEmpty ? _whatsappController.text.trim() : null,
        "address": _addressController.text.trim(),
        "cityId": _isKinshasaSelected && _selectedCity?.cityId != null ? _selectedCity!.cityId! : null,
        "communeId": _isKinshasaSelected && _selectedCommune?.communeId != null ? _selectedCommune!.communeId! : null,
        "quartierId": _isKinshasaSelected && _selectedQuartier?.quartierId != null ? _selectedQuartier!.quartierId! : null,
        "districtId": _isKinshasaSelected && _selectedDistrict?.districtId != null ? _selectedDistrict!.districtId! : null,
        "postalCode": _postalCodeController.text.trim().isNotEmpty ? _postalCodeController.text.trim() : "243",
        "isAvailable": _isAvailable,
        "availableDays": _selectedDays.toList(),
        "availableHours": _availableHoursController.text.trim(),
        "images": imagesBase64,
        "userId": userId ?? 1,
        "username": fullname,
        // Valeurs texte pour mode hors Kinshasa
        "cityValue": _isKinshasaSelected ? (_selectedCity?.name ?? 'Kinshasa') : (_cityTextController.text.trim().isNotEmpty ? _cityTextController.text.trim() : ""),
        "communeValue": _isKinshasaSelected ? (_selectedCommune?.name ?? "") : (_communeTextController.text.trim().isNotEmpty ? _communeTextController.text.trim() : ""),
        "districtValue": _isKinshasaSelected ? (_selectedDistrict?.name ?? "") : (_districtTextController.text.trim().isNotEmpty ? _districtTextController.text.trim() : ""),
        "quartierValue": _isKinshasaSelected ? (_selectedQuartier?.name ?? "") : (_quartierTextController.text.trim().isNotEmpty ? _quartierTextController.text.trim() : ""),
        // CV si disponible
        if (cvBase64 != null) "cv": cvBase64,
        if (_selectedCvFile != null) "cvFileName": _selectedCvFile!.path.split('/').last,
      };

      // Ajouter les champs spécifiques selon le type de service
      if (_selectedServiceType == ServiceType.majordhomme) {
        serviceData["specialties"] = _selectedSpecialties.toList();
      } else if (_selectedServiceType == ServiceType.demenagement) {
        serviceData["hasVehicle"] = _hasVehicle;
        serviceData["hasTeam"] = _hasTeam;
        serviceData["teamSize"] = _hasTeam ? (int.tryParse(_teamSizeController.text) ?? 0) : null;
      } else if (_selectedServiceType == ServiceType.hotel) {
        serviceData["numberOfRooms"] = int.tryParse(_numberOfRoomsController.text) ?? 0;
        serviceData["starRating"] = _selectedStarRating;
        serviceData["hotelServices"] = _selectedHotelServices.toList();
      } else if (_selectedServiceType == ServiceType.bureau) {
        serviceData["surfaceArea"] = double.tryParse(_surfaceAreaController.text);
        serviceData["numberOfDesks"] = int.tryParse(_numberOfDesksController.text) ?? 0;
        serviceData["meetingRooms"] = int.tryParse(_meetingRoomsController.text) ?? 0;
        serviceData["hasParking"] = _hasParking;
        serviceData["hasSecurity"] = _hasSecurity;
      } else if (_selectedServiceType == ServiceType.vacances) {
        serviceData["capacity"] = int.tryParse(_capacityController.text) ?? 0;
        serviceData["vacationType"] = _selectedVacationType;
        serviceData["vacationAmenities"] = _selectedVacationAmenities.toList();
      } else if (_selectedServiceType == ServiceType.salleFete) {
        serviceData["eventCapacity"] = int.tryParse(_capacityController.text) ?? 0;
        serviceData["eventEquipment"] = _selectedEventEquipment.toList();
      } else if (_selectedServiceType == ServiceType.salleFuneraire) {
        serviceData["funeralCapacity"] = int.tryParse(_capacityController.text) ?? 0;
        serviceData["funeralServices"] = _selectedFuneralServices.toList();
      } else if (_selectedServiceType == ServiceType.terrain) {
        serviceData["landArea"] = double.tryParse(_landAreaController.text);
        serviceData["landType"] = _selectedLandType;
        serviceData["landFeatures"] = _selectedLandFeatures.toList();
      } else if (_selectedServiceType == ServiceType.entrepot) {
        serviceData["warehouseArea"] = double.tryParse(_warehouseAreaController.text);
        serviceData["ceilingHeight"] = double.tryParse(_ceilingHeightController.text);
        serviceData["warehouseType"] = _selectedWarehouseType;
        serviceData["warehouseFeatures"] = _selectedWarehouseFeatures.toList();
      }

      final ctrl = context.read<ServiceController>();
      final res = await ctrl.createService(serviceData);

      if (!mounted) return;

      if (res.status == true || res.data['success'] == true || res.data['service'] != null) {
        // Track succès
        await _trackEvent('service_creation_success', {
          'service_type': _selectedServiceType?.value ?? 'unknown',
          'images_count': imagesBase64.length,
          'duration_seconds': _totalPageTimeSeconds,
        });
        
        SnackbarForCasa.success(context, "Service publié avec succès!");
        await Future.delayed(Duration(milliseconds: 1500));
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            Routes.bottomPageRoute,
            (route) => false,
          );
        }
      } else {
        String errorMessage = res.data['message'] ?? res.errorMsg ?? "Erreur lors de la publication du service";
        // Track erreur API
        await _trackEvent('service_creation_api_error', {
          'error_message': errorMessage,
          'service_type': _selectedServiceType?.value ?? 'unknown',
        });
        FancyNotification.show(context, errorMessage, isError: true);
      }
    } catch (e) {
      // Track erreur technique
      await _trackEvent('service_creation_error', {
        'error': e.toString(),
        'service_type': _selectedServiceType?.value ?? 'unknown',
      });
      FancyNotification.show(context, "Erreur technique lors de la publication du service: $e", isError: true);
      print("Service creation error: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}

