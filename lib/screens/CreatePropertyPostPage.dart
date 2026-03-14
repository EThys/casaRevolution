 import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:casa/controllers/PropertyCtrl.dart';
import 'package:casa/controllers/AuthentificationCtrl.dart';
import 'package:casa/screens/auth/IdentityVerificationPage.dart';
import 'package:casa/controllers/LocationController.dart';
import 'package:casa/models/CityModel.dart';
import 'package:casa/models/CommuneModel.dart';
import 'package:casa/models/DistrictModel.dart';
import 'package:casa/models/QuartierModel.dart';
import 'package:casa/models/DeviseModel.dart';
import 'package:casa/utils/FancyNotification.dart';
import 'package:casa/utils/Routes.dart';
import 'package:casa/utils/networkCheck.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as stockage;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:casa/utils/city_suggestions.dart';
// Firebase imports
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_performance/firebase_performance.dart';

import '../utils/StockageKeys.dart';
import '../utils/requetes.dart' show HttpResponse, getData;
import 'package:casa/controllers/AgenceController.dart';
import 'package:casa/screens/forms/TerrainFormFields.dart';
import 'package:casa/screens/forms/BureauFormFields.dart';
import 'package:casa/screens/forms/VacanceFormFields.dart';
import 'package:casa/screens/forms/FuneraireFormFields.dart';
import 'package:casa/screens/forms/FestiveFormFields.dart';

class CreatePropertyPostPage extends StatefulWidget {
  @override
  _CreatePropertyPostPageState createState() => _CreatePropertyPostPageState();
}

class _CreatePropertyPostPageState extends State<CreatePropertyPostPage> {
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
  final Color _warningColor = Color(0xFFFFA000);
  final Color _infoColor = Color(0xFF1976D2);

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
  final double _xLargeSpace = 32.0;

  // Firebase Analytics
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  final FirebasePerformance _performance = FirebasePerformance.instance;

  // Tracking variables
  DateTime? _pageStartTime;
  DateTime? _stepStartTime;
  String? _currentStepName;
  Timer? _pageDurationTimer;
  int _totalPageTimeSeconds = 0;
  int _clickCount = 0;
  
  // Validation state
  bool _hasAttemptedSubmit = false;
  Map<String, bool> _fieldTouched = {}; // Track which fields have been interacted with

  // Form controllers
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _guaranteeController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _electricController = TextEditingController();
  final TextEditingController _bedroomsController = TextEditingController();
  final TextEditingController _bathroomsController = TextEditingController();
  final TextEditingController _livingRoomsController = TextEditingController();
  final TextEditingController _kitchensController = TextEditingController();
  final TextEditingController _areaController = TextEditingController();
  final TextEditingController _roomsController = TextEditingController();
  final TextEditingController _postalCodeController = TextEditingController();
  // Champs texte pour mode hors Kinshasa
  final TextEditingController _cityTextController = TextEditingController();
  final TextEditingController _communeTextController = TextEditingController();
  final TextEditingController _quartierTextController = TextEditingController();
  // Champs spécifiques Bureau
  final TextEditingController _roomMeetController = TextEditingController();
  final TextEditingController _numberPieceController = TextEditingController();
  final TextEditingController _capacityController = TextEditingController(); 
  String? _selectedUsage; 
  bool _isDecore = false;
  bool _pisteDanse = false;
  bool _isEquip = true; // Meublé par défaut (true pour éviter null)
  bool _hasFloor = false; // Pour le champ Étage (0/1)
  
  // Champs spécifiques Vacances
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _dateVacanceController = TextEditingController();
  final TextEditingController _heureVacanceController = TextEditingController();
  final TextEditingController _offreController = TextEditingController();
  String? _selectedPriceCombo;

  // State variables
  bool _isForRent = true;
  bool _isLoading = false;
  Set<String> _selectedAmenities = {};
  LatLng? _selectedLocation;
  final ImagePicker _picker = ImagePicker();
  int _currentStep = 0;

  String? _selectedCategory;
  int? _selectedPropertyTypeId; // Store the ID instead of name
  Set<int> _selectedFeatureIds = {}; // Store feature IDs
  String? _selectedElectric = null;
  String? _selectedWater = null;
  AutovalidateMode _autoValidateMode = AutovalidateMode.disabled;
  
  // Dynamic data from API
  List<Map<String, dynamic>> _propertyTypes = [];
  List<Map<String, dynamic>> _features = [];
  bool _loadingTypes = false;
  bool _loadingFeatures = false;
  int _selectedDeviseId = 2; // Par défaut USD (2), FC (1)


  // Location variables
  CityModel? _selectedCity;
  DistrictModel? _selectedDistrict;
  CommuneModel? _selectedCommune;
  QuartierModel? _selectedQuartier;
  bool get _isKinshasaSelected =>
      (_selectedCity?.name?.toLowerCase().trim() ?? '') == 'kinshasa' ||
      (_cityTextController.text.toLowerCase().trim() == 'kinshasa');
  
  bool get _isMatadiSelected =>
      (_selectedCity?.name?.toLowerCase().trim() ?? '') == 'matadi' ||
      (_cityTextController.text.toLowerCase().trim() == 'matadi');

  List<CityModel> _availableCities = [];
  List<DistrictModel> _availableDistricts = [];
  List<CommuneModel> _availableCommunes = [];
  List<QuartierModel> _availableQuartiers = [];
  
  // Kinshasa quartiers from API
  List<Map<String, dynamic>> _kinshasaQuartiers = [];
  Map<String, dynamic>? _selectedKinshasaQuartier;
  bool _isLoadingQuartiers = false;
  
  // Matadi communes
  final List<String> _matadiCommunes = ['Matadi', 'Nzanza', 'Mvuzi'];


  // Validation errors storage - PAR ÉTAPE ET PAR CHAMP
  Map<String, String> _fieldErrors = {};

  @override
  void initState() {
    super.initState();
    _pageStartTime = DateTime.now();
    _stepStartTime = DateTime.now();
    _currentStepName = 'Category Selection';
    _selectedElectric = null;
    _selectedWater = null;

    _bedroomsController.addListener(_updateTotalRooms);
    _bathroomsController.addListener(_updateTotalRooms);
    _livingRoomsController.addListener(_updateTotalRooms);
    _kitchensController.addListener(_updateTotalRooms);
    
    // Ajout de listeners pour la validation en temps réel des champs critiques
    _areaController.addListener(_validateCurrentStepFields);
    _capacityController.addListener(_validateCurrentStepFields);
    _quartierTextController.addListener(_validateCurrentStepFields);
    _cityTextController.addListener(_validateCurrentStepFields);
    _communeTextController.addListener(_validateCurrentStepFields);
    _titleController.addListener(_validateCurrentStepFields);
    _priceController.addListener(_validateCurrentStepFields);
    _addressController.addListener(_validateCurrentStepFields);

    PaintingBinding.instance.imageCache.maximumSize = 100;
    PaintingBinding.instance.imageCache.maximumSizeBytes = 50 << 20;

    // Initialiser les images sélectionnées
    for (var category in _imageCategories) {
      _selectedImages[category.id] = [];
    }

    // Initialiser le code postal
    _postalCodeController.text = '243';
    _cityTextController.text = '';
    _communeTextController.text = '';
    _quartierTextController.text = '';

    // Setup focus node listeners
    _setupFocusNodes();

    // Initialiser SharedPreferences et charger les données
    _initSharedPreferences();
    
    // Charger les types de propriétés et les caractéristiques
    _loadPropertyTypesAndFeatures();

    // Démarrer le tracking Firebase
    _startPageTracking();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkConnectivity();
      _restoreDraft();
      _loadLocationData(); // Was _loadCities
      _checkUserVerification();
      context.read<PropertyController>().fetchDevises();
    });
  }

  Future<void> _checkConnectivity() async {
    try {
        // Simple check or use a package if available
        // For now logging it
        print("Checking connectivity...");
    } catch (e) {
      print("Connectivity check failed: $e");
    }
  }

  void _checkUserVerification() {
    final authCtrl = context.read<AuthentificationCtrl>();
    // Check if user is logged in first
    if (!authCtrl.isLoggedIn) {
       // Usually handled by route guard, but safety check
       return; 
    }
    
    // Check if user is certified - rediriger directement vers la vérification
    if (authCtrl.user.isCertified != true) {
      print("🔒 User not certified, redirecting to verification");
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.push(
          context, 
          MaterialPageRoute(builder: (context) => IdentityVerificationPage())
        ).then((result) {
          // Si la vérification réussit, on peut revenir à la création de propriété
          if (result == true && mounted) {
            // L'utilisateur peut maintenant créer une propriété
          }
        });
      });
    }
  }

  Map<int, bool> _stepValidations = {0: false, 1: false, 2: false};
  Map<int, Map<String, String>> _stepFieldErrors = {
    0: {}, // Erreurs par champ pour l'étape 1
    1: {}, // Erreurs par champ pour l'étape 2
    2: {}, // Erreurs par champ pour l'étape 3
  };
  Map<int, String> _stepErrorMessages = {};

  // Categories d'images par pièces
  final List<ImageCategory> _imageCategories = [
    ImageCategory(
      id: 'propertyImage',
      name: 'Photos principales',
      icon: FontAwesomeIcons.home,
      color: Color(0xFF1976D2),
      description: 'Photos principales de la propriété',
    ),
    ImageCategory(
      id: 'propertyImageRoom',
      name: 'Chambres',
      icon: FontAwesomeIcons.bed,
      color: Color(0xFF1976D2),
      description: 'Photos des chambres',
    ),
    ImageCategory(
      id: 'propertyImageLivingRoom',
      name: 'Salon',
      icon: FontAwesomeIcons.couch,
      color: Color(0xFF1976D2),
      description: 'Photos du salon',
    ),
    ImageCategory(
      id: 'propertyImageKitchen',
      name: 'Cuisine',
      icon: FontAwesomeIcons.kitchenSet,
      color: Color(0xFF1976D2),
      description: 'Photos de la cuisine',
    ),
  ];

  final stockage = GetStorage();
  late final profile = stockage.read(StockageKeys.profileKey);
  late var fullname = (profile is Map) ? (profile["fullname"] ?? "Utilisateur") : "Utilisateur";
  Map<String, List<XFile>> _selectedImages = {};
  Map<String, String> _otherRoomDescriptions = {};

  final List<Map<String, dynamic>> _electricOptions = [
    {'value': '80', 'label': 'Élevée', 'description': '80% - Coupe rarement'},
    {'value': '60', 'label': 'Bonne', 'description': '60% - Quelques coupures'},
    {'value': '40', 'label': 'Moyenne', 'description': '40% - Coupures régulières'},
    {'value': '20', 'label': 'Faible', 'description': '20% - Coupe souvent'},
  ];

  final List<Map<String, dynamic>> _waterOptions = [
    {'value': '80', 'label': 'Excellente', 'description': 'Coupures très rares'},
    {'value': '60', 'label': 'Bonne', 'description': 'Quelques coupures'},
    {'value': '40', 'label': 'Moyenne', 'description': 'Coupures régulières'},
    {'value': '20', 'label': 'Faible', 'description': 'Coupures fréquentes'},
  ];

  // Amenities list
  final List<String> _amenitiesList = [
    'WiFi',
    'Climatisation',
    'Chauffage',
    'Cuisine équipée',
    'Lave-linge',
    'Parking',
    'Ascenseur',
    'Piscine',
    'Jardin',
    'Terrasse',
    'Gym',
    'Sécurité',
    'Animaux acceptés'
  ];

  // Focus nodes for navigation
  final List<FocusNode> _focusNodes = [
    FocusNode(), // Title
    FocusNode(), // Price
    FocusNode(), // Guarantee
    FocusNode(), // Description
    FocusNode(), // Address
  ];

  // SharedPreferences instance
  late SharedPreferences _prefs;



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
          'page_name': 'create_property',
          'duration_seconds': _totalPageTimeSeconds,
          'step': _currentStep,
        });
      } else {
        timer.cancel();
      }
    });
    
    _trackEvent('page_view', {
      'page_name': 'create_property',
      'timestamp': _pageStartTime!.millisecondsSinceEpoch,
    });
    _trackPageView('create_property_page');
  }

  void _endPageTracking() {
    // Annuler le timer
    _pageDurationTimer?.cancel();
    _pageDurationTimer = null;
    
    if (_pageStartTime != null) {
      final duration = DateTime.now().difference(_pageStartTime!);
      _trackEvent('page_exit', {
        'page_name': 'create_property',
        'duration_seconds': duration.inSeconds,
        'total_time_tracked_seconds': _totalPageTimeSeconds,
        'steps_completed': _currentStep,
        'total_images': _totalImagesCount,
        'property_type': _selectedCategory ?? 'none',
        'click_count': _clickCount,
        'has_attempted_submit': _hasAttemptedSubmit,
      });
    }
  }

  void _startStepTracking(int step, String stepName) {
    _stepStartTime = DateTime.now();
    _currentStepName = stepName;

    _trackEvent('step_start', {
      'step_number': step,
      'step_name': stepName,
      'timestamp': _stepStartTime!.millisecondsSinceEpoch,
      'total_images': _totalImagesCount,
      'property_type': _selectedCategory ?? 'none',
    });
  }

  void _endStepTracking(int step, String stepName, bool completed) {
    if (_stepStartTime != null) {
      final duration = DateTime.now().difference(_stepStartTime!);
      _trackEvent('step_complete', {
        'step_number': step,
        'step_name': stepName,
        'duration_seconds': duration.inSeconds,
        'completed': completed,
        'total_images': _totalImagesCount,
        'has_location': _selectedCity != null,
        'has_category': _selectedCategory != null,
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
        screenClass: 'CreatePropertyPostPage',
      );
    } catch (e) {
      print('❌ Firebase Page View Error: $e');
    }
  }

  Future<void> _trackImageAction(String action, String category, int count) async {
    await _trackEvent('image_$action', {
      'category': category,
      'image_count': count,
      'total_images': _totalImagesCount,
      'step': _currentStep,
    });
  }

  Future<void> _trackSelection(String type, String value) async {
    await _trackEvent('selection_$type', {
      'value': value,
      'step': _currentStep,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  // Méthode supprimée - on ne track plus les erreurs de validation
  // Seules les erreurs API sont trackées

  String _getStepName(int step) {
    switch (step) {
      case 0:
        return 'type_and_photos';
      case 1:
        return 'details';
      case 2:
        return 'amenities';
      default:
        return 'unknown';
    }
  }

  // =============================================
  // GESTION DES ERREURS PAR ÉTAPE ET PAR CHAMP
  // =============================================

  void _clearStepFieldErrors(int step) {
    if (_stepFieldErrors.containsKey(step)) {
      _stepFieldErrors[step]!.clear();
    }
  }

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
    // NE PAS tracker les erreurs de validation - seulement les erreurs API
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

  List<String> _getStepErrorFields(int step) {
    return _stepFieldErrors[step]?.keys.toList() ?? [];
  }

  void _showFieldErrorNotification(int step, String field) {
    final error = _getFieldError(step, field);
    if (error != null && error.isNotEmpty) {
      FancyNotification.show(
        context,
        error,
        isError: true,
        duration: 3,
      );
    }
  }

  // =============================================
  // EXISTING METHODS (with enhanced error handling)
  // =============================================

  void _setupFocusNodes() {
    for (int i = 0; i < _focusNodes.length; i++) {
      _focusNodes[i].addListener(() {
        if (!_focusNodes[i].hasFocus) {
          _validateCurrentStepFields();
        }
      });
    }
  }

  Future<void> _initSharedPreferences() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadLocationData();
    await _restoreDraft();
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
            _selectedCity = _availableCities.first;
            _updateDistrictsForCity();
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
          _selectedQuartier = null;
      }
    });
  }

  void _onCityChanged(String selection) {
    if (selection.isEmpty) return;
    
    _markFieldTouched('city');
    setState(() {
      _cityTextController.text = selection;
      final query = selection.toLowerCase().trim();
      
      final kin = _availableCities.firstWhere(
          (c) => (c.name ?? '').toLowerCase() == query,
          orElse: () => _availableCities.isNotEmpty 
              ? _availableCities.first 
              : CityModel(cityId: 1, name: 'Kinshasa'));
          
      if (query == 'kinshasa') {
        _selectedCity = kin;
        _updateDistrictsForCity();
        _loadKinshasaQuartiers();
      } else {
        _selectedCity = null;
        _selectedDistrict = null;
        _selectedCommune = null;
        _selectedQuartier = null;
        _selectedKinshasaQuartier = null;
        _kinshasaQuartiers = [];
      }
      _removeFieldError(1, 'city');
      _validateStep1();
      _saveDraft();
    });
    _trackSelection('city', selection);
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
        _availableCommunes = [];
        _selectedCommune = null;
        _availableQuartiers = [];
        _selectedQuartier = null;
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
        _availableQuartiers = [];
        _selectedQuartier = null;
      }
    });
  }

  Future<void> _loadKinshasaQuartiers() async {
    if (_isLoadingQuartiers || _kinshasaQuartiers.isNotEmpty) return;
    
    setState(() => _isLoadingQuartiers = true);
    
    try {
      final response = await getData('quartiers'); // Endpoint corrigé, getData ajoute déjà /api
      
      if (response != null && response is Map) {
        if (mounted) {
          setState(() {
            _kinshasaQuartiers = List<Map<String, dynamic>>.from(response['quartiers'] ?? []);
          });
          print('✅ ${_kinshasaQuartiers.length} quartiers de Kinshasa chargés depuis l\'API');
        }
      } else {
        print('⚠️ Erreur API quartiers: réponse null ou invalide');
      }
    } catch (e) {
      print('❌ Erreur chargement quartiers Kinshasa: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingQuartiers = false);
      }
    }
  }

  void _updateTotalRooms() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    // Annuler le timer de tracking
    _pageDurationTimer?.cancel();
    _pageDurationTimer = null;
    
    _endPageTracking();

    _titleController.dispose();
    _priceController.dispose();
    _guaranteeController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _bedroomsController.dispose();
    _bathroomsController.dispose();
    _electricController.dispose();
    _livingRoomsController.dispose();
    _kitchensController.dispose();
    _areaController.dispose();
    _roomsController.dispose();
    _postalCodeController.dispose();
    _cityTextController.dispose();
    _communeTextController.dispose();
    _quartierTextController.dispose();
    _roomMeetController.dispose();
    _numberPieceController.dispose();

    _bedroomsController.removeListener(_updateTotalRooms);
    _bathroomsController.removeListener(_updateTotalRooms);
    _livingRoomsController.removeListener(_updateTotalRooms);
    _kitchensController.removeListener(_updateTotalRooms);

    for (var focusNode in _focusNodes) {
      focusNode.dispose();
    }

    super.dispose();
  }

  // Sauvegarder le brouillon
  Future<void> _saveDraft() async {
    try {
      final draft = {
        'currentStep': _currentStep,
        'isForRent': _isForRent,
        'selectedCategory': _selectedCategory,
        'selectedPropertyTypeId': _selectedPropertyTypeId,
        'title': _titleController.text,
        'price': _priceController.text,
        'guarantee': _guaranteeController.text,
        'description': _descriptionController.text,
        'address': _addressController.text,
        'cityText': _cityTextController.text,
        'communeText': _communeTextController.text,
        'quartierText': _quartierTextController.text,
        'bedrooms': _bedroomsController.text,
        'selectedElectric': _selectedElectric,
        'selectedWater': _selectedWater,
        'bathrooms': _bathroomsController.text,
        'livingRooms': _livingRoomsController.text,
        'kitchens': _kitchensController.text,
        'area': _areaController.text,
        'hasFloor': _hasFloor,
        // New fields
        'roomMeet': _roomMeetController.text,
        'numberPiece': _numberPieceController.text,
        'note': _noteController.text,
        'dateVacance': _dateVacanceController.text,
        'heureVacance': _heureVacanceController.text,
        'capacity': _capacityController.text,
        'offre': _offreController.text,
        'isEquip': _isEquip,
        'pri ceCombo': _selectedPriceCombo,
        'usage': _selectedUsage,
        'isDecore': _isDecore,
        'pisteDanse': _pisteDanse,
        
        'selectedAmenities': _selectedAmenities.toList(),
        'selectedCityId': _selectedCity?.cityId,
        'selectedDistrictId': _selectedDistrict?.districtId,
        'selectedCommuneId': _selectedCommune?.communeId,
        'selectedQuartierId': _selectedQuartier?.quartierId,
        'totalImagesCount': _totalImagesCount,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      };

      await _prefs.setString('property_draft', jsonEncode(draft));
    } catch (e) {
      print('❌ Erreur lors de la sauvegarde du brouillon: $e');
    }
  }

  Future<void> _restoreDraft() async {
    try {
      final draftData = _prefs.getString('property_draft');

      if (draftData != null && mounted) {
        final draft = jsonDecode(draftData) as Map<String, dynamic>;

        setState(() {
          _currentStep = draft['currentStep'] ?? 0;
          _isForRent = draft['isForRent'] ?? true;
          _selectedCategory = draft['selectedCategory'];
          _selectedPropertyTypeId = draft['selectedPropertyTypeId'];
          _titleController.text = draft['title'] ?? '';
          _priceController.text = draft['price'] ?? '';
          _guaranteeController.text = draft['guarantee'] ?? '';
          _descriptionController.text = draft['description'] ?? '';
          _cityTextController.text = draft['cityText'] ?? '';
          _communeTextController.text = draft['communeText'] ?? '';
          _quartierTextController.text = draft['quartierText'] ?? '';
          _selectedElectric = draft['selectedElectric'];
          _selectedWater = draft['selectedWater'];
          _addressController.text = draft['address'] ?? '';
          _bedroomsController.text = draft['bedrooms'] ?? '';
          _bathroomsController.text = draft['bathrooms'] ?? '';
          _livingRoomsController.text = draft['livingRooms'] ?? '';
          _kitchensController.text = draft['kitchens'] ?? '';
          _areaController.text = draft['area'] ?? '';
          _hasFloor = draft['hasFloor'] ?? false;
        
        // Restore new fields
        _roomMeetController.text = draft['roomMeet'] ?? '';
        _numberPieceController.text = draft['numberPiece'] ?? '';
        _noteController.text = draft['note'] ?? '';
        _dateVacanceController.text = draft['dateVacance'] ?? '';
        _heureVacanceController.text = draft['heureVacance'] ?? '';
        _capacityController.text = draft['capacity'] ?? '';
        _offreController.text = draft['offre'] ?? '';
        _isEquip = draft['isEquip'] ?? false;
        _selectedPriceCombo = draft['priceCombo'];
        _selectedUsage = draft['usage'];
        _isDecore = draft['isDecore'] ?? false;
        _pisteDanse = draft['pisteDanse'] ?? false;

        _selectedAmenities = Set<String>.from(draft['selectedAmenities'] ?? []);
        });

        if (draft['selectedCityId'] != null) {
          _restoreLocation(
            draft['selectedCityId'],
            draft['selectedDistrictId'],
            draft['selectedCommuneId'],
            draft['selectedQuartierId'],
          );
        }

        _validateAllSteps();
      }
    } catch (e) {
      print('❌ Erreur lors de la restauration du brouillon: $e');
    }
  }

  void _restoreLocation(int? cityId, int? districtId, int? communeId, int? quartierId) {
    if (cityId != null && _availableCities.isNotEmpty) {
      try {
        final city = _availableCities.isNotEmpty
            ? _availableCities.firstWhere(
                (city) => city.cityId == cityId,
                orElse: () => _availableCities.first,
              )
            : null;

        setState(() {
          if (city != null) {
            _selectedCity = city;
            _updateDistrictsForCity();
          }

          if (districtId != null && _availableDistricts.isNotEmpty) {
            try {
              final district = _availableDistricts.isNotEmpty
                  ? _availableDistricts.firstWhere(
                      (district) => district.districtId == districtId,
                      orElse: () => _availableDistricts.first,
                    )
                  : null;
              if (district != null) {
                _selectedDistrict = district;
                _updateCommunesForDistrict();
              }

              if (communeId != null && _availableCommunes.isNotEmpty) {
                try {
                  final commune = _availableCommunes.isNotEmpty
                      ? _availableCommunes.firstWhere(
                          (commune) => commune.communeId == communeId,
                          orElse: () => _availableCommunes.first,
                        )
                      : null;
                  if (commune != null) {
                    _selectedCommune = commune;
                    _updateQuartiersForCommune();
                  }

                  if (quartierId != null && _availableQuartiers.isNotEmpty) {
                    try {
                      final quartier = _availableQuartiers.isNotEmpty
                          ? _availableQuartiers.firstWhere(
                              (quartier) => quartier.quartierId == quartierId,
                              orElse: () => _availableQuartiers.first,
                            )
                          : null;
                      if (quartier != null) {
                        _selectedQuartier = quartier;
                      }
                    } catch (e) {
                      _selectedQuartier = _availableQuartiers.isNotEmpty ? _availableQuartiers.first : null;
                    }
                  } else if (_availableQuartiers.isNotEmpty) {
                    _selectedQuartier = _availableQuartiers.first;
                  } else {
                    _selectedQuartier = null;
                  }
                } catch (e) {
                  _selectedCommune = _availableCommunes.isNotEmpty ? _availableCommunes.first : null;
                  _updateQuartiersForCommune();
                }
              } else if (_availableCommunes.isNotEmpty) {
                _selectedCommune = _availableCommunes.first;
                _updateQuartiersForCommune();
              } else {
                _selectedCommune = null;
                _availableQuartiers = [];
                _selectedQuartier = null;
              }
            } catch (e) {
              _selectedDistrict = _availableDistricts.isNotEmpty ? _availableDistricts.first : null;
              _updateCommunesForDistrict();
            }
          } else if (_availableDistricts.isNotEmpty) {
            _selectedDistrict = _availableDistricts.first;
            _updateCommunesForDistrict();
          } else {
            _selectedDistrict = null;
            _availableCommunes = [];
            _selectedCommune = null;
            _availableQuartiers = [];
            _selectedQuartier = null;
          }
        });
      } catch (e) {
        print('Erreur lors de la restauration de la localisation: $e');
      }
    }
  }

  void _validateAllSteps() {
    _validateStep0();
    _validateStep1();
    _validateStep2();
  }

  void _validateCurrentStepFields() {
    if (mounted) {
      setState(() {
        switch (_currentStep) {
          case 0:
            _validateStep0();
            break;
          case 1:
            _validateStep1();
            break;
          case 2:
            _validateStep2();
            break;
        }
      });
    }
    _saveDraft();
  }

  bool _validateStep0() {
    _clearStepFieldErrors(0);
    final errors = <String>[];

    // Validation du type de propriété uniquement
    if (_selectedCategory == null) {
      errors.add('Veuillez sélectionner un type de propriété');
      _setFieldError(0, 'property_type', 'Type de propriété requis');
    }

    final isValid = errors.isEmpty;
    final errorMessage = errors.isNotEmpty ? errors.join('\n') : '';

    setState(() {
      _stepValidations[0] = isValid;
      _stepErrorMessages[0] = errorMessage;
    });

    return isValid;
  }

  bool _validateStep1() {
    _clearStepFieldErrors(1);
    final errors = <String>[];
    final typeName = _selectedCategory?.toLowerCase() ?? '';
    final isFestive = typeName.contains('fête') || typeName.contains('festive');
    final isFuneraire = typeName.contains('funéra') || typeName.contains('deuil');
    final isVacances = typeName.contains('vacance');

    final isBureau = typeName.contains('bureau') || (_selectedPropertyTypeId == 4);
  final isTerrain = typeName.contains('terrain');

  // Vacances validation
  if (isVacances) {
      if (_dateVacanceController.text.trim().isEmpty) {
         _setFieldError(1, 'date', 'Date requise');
         errors.add('Date requise');
      }
      if (_heureVacanceController.text.trim().isEmpty) {
         _setFieldError(1, 'time', 'Heure requise');
         errors.add('Heure requise');
      }
      if (_capacityController.text.trim().isEmpty) {
        _setFieldError(1, 'capacity', 'Capacité requise');
        errors.add('Capacité requise');
      }
  }

  // Bureau validation
  if (isBureau) {
      if (_numberPieceController.text.trim().isEmpty) {
         _setFieldError(1, 'numberPiece', 'Nombre de pièces requis');
      }
      if (_areaController.text.trim().isEmpty) {
         _setFieldError(1, 'area', 'Superficie requise');
      }
  }

  // Terrain validation
  if (isTerrain) {
      if (_areaController.text.trim().isEmpty) {
         _setFieldError(1, 'area', 'Superficie requise');
      }
  }

  // Title validation
  if (_titleController.text.trim().isEmpty) {
      _setFieldError(1, 'title', 'Veuillez entrer un titre');
    } else if (_titleController.text.trim().length < 5) { // Reduced constraint
      _setFieldError(1, 'title', 'Titre trop court (min 5 caractères)');
    }

    // Price validation
    if (_priceController.text.trim().isEmpty) {
      _setFieldError(1, 'price', 'Prix requis'); // Shortened
    }

    // Capacity validation for specific types
    if (isFestive) {
      if (_capacityController.text.trim().isEmpty) {
         _setFieldError(1, 'capacity', 'Capacité requise');
         errors.add('Capacité requise');
      }
    }
    
    // Funeraire validation
    if (isFuneraire) {
       if (_capacityController.text.trim().isEmpty) {
         _setFieldError(1, 'capacity', 'Capacité requise');
         errors.add('Capacité requise');
      }
    }

    // Location validation
    if (_isKinshasaSelected) {
      if (_selectedCity == null) _setFieldError(1, 'city', 'Ville requise');
      if (_selectedDistrict == null) _setFieldError(1, 'district', 'District requis');
      if (_selectedCommune == null) _setFieldError(1, 'commune', 'Commune requise');
      // Fix: Accepter soit le quartier de la BD locale, soit celui de l'API Kinshasa, soit le texte saisi manuellement
      if (_selectedQuartier == null && _selectedKinshasaQuartier == null && _quartierTextController.text.trim().isEmpty) {
        _setFieldError(1, 'quartier', 'Quartier requis');
      }
    } else {
      if (_cityTextController.text.trim().isEmpty) _setFieldError(1, 'city', 'Ville requise');
      if (_communeTextController.text.trim().isEmpty) _setFieldError(1, 'commune', 'Commune requise');
      if (_quartierTextController.text.trim().isEmpty) _setFieldError(1, 'quartier', 'Quartier requis');
    }

    // Address validation
    if (_addressController.text.trim().isEmpty) {
      _setFieldError(1, 'address', 'Adresse requise');
    }
    // Only check length for standard properties if needed, or remove completely as requested
    // User asked to NOT be strict about 10 chars for terrain, bureau, salle de fete, funeraire, vacance
    final isSpecial = isFestive || isFuneraire || isTerrain || isBureau || isVacances;
    if (!isSpecial && _addressController.text.trim().length < 5) {
       _setFieldError(1, 'address', 'Adresse trop courte');
    }

    final isValid = !_hasFieldErrors(1) && errors.isEmpty;
    final errorMessage = _hasFieldErrors(1) || errors.isNotEmpty ? 'Veuillez corriger les erreurs' : '';

    setState(() {
      _stepValidations[1] = isValid;
      _stepErrorMessages[1] = errorMessage;
    });

    return isValid;
  }

  bool _validateStep2() {
    _clearStepFieldErrors(2);
    final errors = <String>[];

    // 1. Validation des photos (Toujours requises)
    final mainImages = _selectedImages['propertyImage'] ?? [];
    if (mainImages.length < 3) {
      errors.add('Au moins 3 photos principales sont requises');
      _setFieldError(2, 'photos', 'Min. 3 photos');
    }

    // 2. Validation des services essentiels si affichés
    final typeName = _selectedCategory?.toLowerCase() ?? '';
    final isFestive = typeName.contains('fête') || typeName.contains('festive');
    final isFuneraire = typeName.contains('funéra') || typeName.contains('deuil');
    final isTerrain = typeName.contains('terrain');
    
    // Services required for Festive and Funeraire, but not Terrain or Vacances (handled in VacanceFormFields or excluded)
    // Actually Vacances has its own form, so this logic covers the main step 2 services (Electric/Water)
    // User wants Festive to have services.
    final isExcluded = isTerrain;

    if (!isExcluded) {
      if (_selectedElectric == null) {
         _setFieldError(2, 'electric', 'Requis');
         errors.add("Electricité requise");
      }
      if (_selectedWater == null) {
         _setFieldError(2, 'water', 'Requis');
         errors.add("Eau requise");
      }
    }

    // Les équipements (features) restent optionnels comme demandé

    final isValid = !_hasFieldErrors(2) && errors.isEmpty;
    final errorMessage = _hasFieldErrors(2) || errors.isNotEmpty ? 'Veuillez compléter les informations requises' : '';

    setState(() {
      _stepValidations[2] = isValid;
      _stepErrorMessages[2] = errorMessage;
    });

    return isValid;
  }

  void _showStepErrorNotification(int step) {
    final errorMessage = _stepErrorMessages[step];
    if (errorMessage != null && errorMessage.isNotEmpty) {
      FancyNotification.show(
        context,
        errorMessage,
        isError: true,
        duration: 4,
      );
    }
  }

  void _clearImageCache() {
    try {
      // Méthodes natives de Flutter
      imageCache.clear();
      imageCache.clearLiveImages();

      // Forcer le garbage collector (si disponible)
      if (Platform.isAndroid) {
        SystemChannels.platform.invokeMethod('System.gc');
      }

      // Libérer les ressources des images affichées
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            // Rebuild forcé pour libérer la mémoire
          });
        }
      });

      print("🧹 Cache d'images nettoyé intensivement");
    } catch (e) {
      print("⚠️ Erreur nettoyage cache: $e");
    }
  }

  Future<void> _pickImages(String categoryId) async {
    // Track début de sélection
    _trackEvent('image_pick_start', {
      'category': categoryId,
      'current_count': _selectedImages[categoryId]?.length ?? 0,
    });

    try {
      final List<XFile>? images = await _picker.pickMultiImage(
        imageQuality: 85,
        maxWidth: 1440,
      );

      if (images != null && images.isNotEmpty && mounted) {
        // Vérifier la disponibilité des fichiers immédiatement
        List<XFile> validImages = [];
        for (var image in images) {
          final file = File(image.path);
          if (await file.exists()) {
            validImages.add(image);
            print("✅ Image valide: ${image.path}");
          } else {
            print("❌ Image non valide (fichier manquant): ${image.path}");
          }
        }

        if (mounted) {
          setState(() {
            _selectedImages[categoryId]!.addAll(validImages);
            _validateCurrentStepFields();
            _saveDraft();
          });

          // Track succès
          _trackImageAction('added', categoryId, validImages.length);
        }
      }
    } on PlatformException catch (e) {
      print('Failed to pick images: $e');
      // Track erreur
      _trackEvent('image_pick_error', {
        'category': categoryId,
        'error': e.toString(),
      });
      FancyNotification.show(
        context,
        "Erreur lors de la sélection des images",
        isError: true,
      );
    } catch (e) {
      print('Erreur inattendue lors de la sélection des images: $e');
      // Track erreur
      _trackEvent('image_pick_error', {
        'category': categoryId,
        'error': e.toString(),
      });
      FancyNotification.show(
        context,
        "Erreur lors de la sélection des images",
        isError: true,
      );
    }
  }





  bool _isSupportedImageFormat(String path) {
    final supportedFormats = ['.jpg', '.jpeg', '.png', '.webp'];
    final extension = path.toLowerCase().substring(path.lastIndexOf('.'));
    return supportedFormats.contains(extension);
  }






  void _removeImage(String categoryId, int index) {
    if (mounted) {
      setState(() {
        _selectedImages[categoryId]!.removeAt(index);
        _validateCurrentStepFields();
        _saveDraft();
      });

      // Track suppression
      _trackImageAction('removed', categoryId, 1);
    }
  }

  int get _totalImagesCount {
    return _selectedImages.values.fold(0, (sum, images) => sum + (images?.length ?? 0));
  }

  bool _isUserGerant() {
    final storage = GetStorage();
    final userData = storage.read(StockageKeys.userKey);
    String currentAccountType = 'Non spécifié';
        
    // 1. Check main typeAccount
    if (userData != null && userData['typeAccount'] != null) {
          currentAccountType = userData['typeAccount']['name']?.toString() ?? 'Non spécifié';
    }

    print("🔍 VERIFICATION ROLE GERANT:");
    print("👤 Compte principal: $currentAccountType");

    // 2. Check user_accounts list
    bool hasGerantRole = currentAccountType.toLowerCase().contains('gérant') || 
                          currentAccountType.toLowerCase().contains('gerant');

    if (!hasGerantRole) {
        final accounts = storage.read('user_accounts');
        print("📋 Liste des comptes additionnels: ${accounts?.length ?? 0}");
        if (accounts != null && accounts is List) {
            for (var acc in accounts) {
                  if (acc is Map) {
                    final name = acc['name']?.toString()?.toLowerCase() ?? '';
                    final typeName = acc['typeAccount']?['name']?.toString()?.toLowerCase() ?? '';
                    
                    print("  - Compte: name=$name, type=$typeName");

                    if (name.contains('gérant') || name.contains('gerant') ||
                        typeName.contains('gérant') || typeName.contains('gerant')) {
                            hasGerantRole = true;
                            print("  ✅ Rôle Gérant trouvé dans les comptes secondaires");
                            break;
                    }
                  }
            }
        }
    } else {
        print("✅ Rôle Gérant trouvé dans le compte principal");
    }
    
    print("🏁 HasGerantRole final: $hasGerantRole");
    return hasGerantRole;
  }

  Future<void> _checkAgencyRequirement(String categoryName) async {
    // Logic specifically for Vacances
    if (categoryName.toLowerCase().contains('vacance')) {
        print("🏖️ [CreatePropertyPost] Vérification agence pour Vacances...");
        
        final authCtrl = Provider.of<AuthentificationCtrl>(context, listen: false);
        final agenceCtrl = Provider.of<AgenceController>(context, listen: false);
        final storage = GetStorage();
        final userData = storage.read(StockageKeys.userKey);
        
        // Get userId
        final userId = authCtrl.user.userId;
        if (userId == null) {
            print("❌ [CreatePropertyPost] UserId non trouvé");
            FancyNotification.show(
                context,
                "Erreur: Impossible de vérifier votre compte",
                isError: true
            );
            return;
        }
        
        // Check if user is Gérant
        String currentAccountType = 'Non spécifié';
        if (userData != null && userData['typeAccount'] != null) {
             currentAccountType = userData['typeAccount']['name']?.toString() ?? 'Non spécifié';
        }

        bool hasGerantRole = currentAccountType.toLowerCase().contains('gérant') || 
                             currentAccountType.toLowerCase().contains('gerant');

        if (!hasGerantRole) {
            final accounts = storage.read('user_accounts');
            if (accounts != null && accounts is List) {
                for (var acc in accounts) {
                     if (acc is Map) {
                        final name = acc['name']?.toString()?.toLowerCase() ?? '';
                        final typeName = acc['typeAccount']?['name']?.toString()?.toLowerCase() ?? '';
                        
                        if (name.contains('gérant') || name.contains('gerant') ||
                            typeName.contains('gérant') || typeName.contains('gerant')) {
                                hasGerantRole = true;
                                break;
                        }
                     }
                }
            }
        }
        
        if (!hasGerantRole) {
            print("❌ [CreatePropertyPost] Utilisateur n'est pas Gérant");
            FancyNotification.show(
                context,
                "Cette catégorie nécessite un compte Gérant",
                isError: true
            );
            return;
        }
        
        print("✅ [CreatePropertyPost] Utilisateur est Gérant, vérification agence...");
        
        // Fetch user's agencies
        await agenceCtrl.fetchAgencesByUser(userId);
        
        // Check if user has agencies
        if (agenceCtrl.agences.isNotEmpty) {
            print("✅ [CreatePropertyPost] Agence trouvée: ${agenceCtrl.agences.first.name}");
            // User has agency, proceed automatically
            return;
        }
        
        print("⚠️ [CreatePropertyPost] Aucune agence trouvée, affichage dialogue création");
        // No agency found, show creation dialog
        _showCreateAgencyDialog();
    }
  }


  void _showCreateAgencyDialog() {
      // Informer l'utilisateur avant la redirection
      FancyNotification.show(
        context, 
        "Pour des raisons de qualité, la publication d'offres 'Vacances' nécessite un compte Agence. Créons-le ensemble !", 
        isError: false, 
        type: NotificationType.info,
        duration: 4
      );
      
      // Petit délai pour laisser lire le message
      Future.delayed(Duration(seconds: 2), () {
          if (mounted) {
             // Désélectionner pour éviter l'état incohérent
             setState(() { _selectedCategory = null; _selectedPropertyTypeId = null; });
             
             Navigator.pushNamed(context, Routes.createAgenceRoute).then((result) {
                 if (result == true) {
                     // Si l'agence a été créée, on laisse l'utilisateur réessayer ou on re-check
                     final authCtrl = Provider.of<AuthentificationCtrl>(context, listen: false);
                     if (authCtrl.user.userId != null) {
                        authCtrl.checkUserAgency(authCtrl.user.userId!);
                     }
                 }
             });
          }
      });
  }

  // =============================================
  // WIDGETS HARMONISÉS
  // =============================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _lightColor,
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          // --- START PREMIUM BACKGROUND ---
          Positioned.fill(
            child: Container(
              color: const Color(0xFFF8F9FF),
            ),
          ),
          
          // Mesh Gradient Blobs
          Positioned(
            top: -100,
            right: -80,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _primaryColor.withOpacity(0.08),
                    _primaryColor.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),
          
          Positioned(
            bottom: 100,
            left: -100,
            child: Container(
              width: 450,
              height: 450,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _secondaryColor.withOpacity(0.06),
                    _secondaryColor.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),

          // GLASS EFFECT: Backdrop Blur
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
              child: Container(color: Colors.transparent),
            ),
          ),

          // Texture Overlay
          Positioned.fill(
            child: Opacity(
              opacity: 0.03, 
              child: Image.asset(
                "assets/images/abstract.jpg",
                fit: BoxFit.cover,
                colorBlendMode: BlendMode.overlay,
              ),
            ),
          ),
          // --- END PREMIUM BACKGROUND ---

          AbsorbPointer(
            absorbing: _isLoading,
            child: WillPopScope(
              onWillPop: () async {
                await _saveDraft();
                return true;
              },
              child: Form(
                key: _formKey,
                autovalidateMode: _autoValidateMode,
                child: Column(
                  children: [
                    _buildProgressIndicator(),
                    Expanded(
                      child: _buildCurrentStepContent(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildStep1();
      case 1:
        return _buildStep2();
      case 2:
        return _buildStep3();
      default:
        return _buildStep1();
    }
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text(
        'Nouvelle annonce',
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
        icon: Icon(Icons.arrow_back_ios_new_rounded,
            color: _darkColor, size: 22),
        onPressed: () async {
          await _saveDraft();
          if (mounted) {
            Navigator.pop(context);
          }
        },
      ),
      actions: [
        if (_currentStep > 0)
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
              _buildStepLabel(0, 'Type'),
              _buildStepLabel(1, 'Détails'),
              _buildStepLabel(2, 'Photos'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepLabel(int stepIndex, String label) {
    final isActive = _currentStep == stepIndex;
    final isValid = _stepValidations[stepIndex] ?? false;
    final hasError = _stepErrorMessages[stepIndex]?.isNotEmpty ?? false;

    return GestureDetector(
      onTap: () {
        if (mounted) {
          // Validation avant de changer d'étape
          bool canNavigate = true;
          
          // On ne valide que si on essaie d'avancer
          if (stepIndex > _currentStep) {
            // Si on veut aller vers une étape future, on valide toutes les étapes jusqu'à l'étape actuelle incluse
            for (int i = 0; i <= _currentStep; i++) {
              bool stepValid = false;
              if (i == 0) stepValid = _validateStep0();
              else if (i == 1) stepValid = _validateStep1();
              else if (i == 2) stepValid = _validateStep2();

              if (!stepValid) {
                _showStepErrorNotification(i);
                canNavigate = false;
                // Si une étape est invalide, on reste sur cette étape
                setState(() => _currentStep = i);
                break;
              }
            }
          }

          if (canNavigate) {
            setState(() => _currentStep = stepIndex);
            _trackEvent('step_navigation_click', {
              'target_step': stepIndex,
              'from_step': _currentStep,
            });
          }
        }
      },
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive
                      ? _primaryColor
                      : hasError
                      ? _errorColor.withOpacity(0.1)
                      : _borderColor,
                  border: Border.all(
                    color: hasError
                        ? _errorColor
                        : isValid
                        ? _successColor
                        : isActive
                        ? _primaryColor
                        : _borderColor,
                    width: hasError || isValid ? 2 : 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    '${stepIndex + 1}',
                    style: TextStyle(
                      color: isActive ? Colors.white : _greyColor,
                      fontWeight: FontWeight.w600,
                      fontSize: _bodySize,
                    ),
                  ),
                ),
              ),
              if (isValid)
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _successColor,
                      border: Border.all(color: Colors.white, width: 1),
                    ),
                    child: Icon(
                      Icons.check,
                      size: 8,
                      color: Colors.white,
                    ),
                  ),
                ),
              if (hasError)
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _errorColor,
                      border: Border.all(color: Colors.white, width: 1),
                    ),
                    child: Icon(
                      Icons.close,
                      size: 8,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
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

  Widget _buildStep1() {
    return SingleChildScrollView(
      key: ValueKey('step0_scroll'),
      physics: BouncingScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: _mediumSpace, vertical: _mediumSpace),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Mode de Transaction
          _buildModernSectionHeader(
            title: 'Quel est votre projet ?',
            icon: Icons.ads_click_rounded,
          ),
          SizedBox(height: _smallSpace),
          Text(
            'Choisissez le type d\'annonce que vous souhaitez publier.',
            style: TextStyle(
              color: _greyColor,
              fontSize: _captionSize,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: _mediumSpace),
          _buildTransactionTypeSelector(),
          
          SizedBox(height: _largeSpace),
          
          // Section Type de Propriété
          _buildModernSectionHeader(
            title: 'Type de propriété',
            icon: Icons.category_rounded,
          ),
          SizedBox(height: _smallSpace),
          Text(
            'Sélectionnez la catégorie qui correspond le mieux à votre bien pour une expérience personnalisée.',
            style: TextStyle(
              color: _greyColor,
              fontSize: _captionSize,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: _mediumSpace),
          _buildModernPropertyTypeGrid(),
          SizedBox(height: _largeSpace),
          _buildBottomNavigation(),
          SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildModernPropertyTypeGrid() {
    if (_loadingTypes) {
      return Container(
        height: 300,
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
          ),
        ),
      );
    }

    // Use dynamic property types from API
    // FILTRAGE STRICT PAR RÔLE
    final categories = _propertyTypes.where((type) {
      final typeName = type['name']?.toString().toLowerCase();
      // Types "Basiques" pour Commissionnaire/Bailleur (incluant Terrain)
      final isBasicType = ['studio', 'apparts', 'maisons', 'bureau', 'terrain', 'terrains'].contains(typeName);
      
      // Récupérer les rôles depuis le stockage
      final userAccounts = stockage.read('user_accounts');
      bool isGerant = false;
      bool isSimpleProprietaire = false;

      if (userAccounts != null && userAccounts is List) {
        // Check Gérant
        isGerant = userAccounts.any((acc) {
           final typeId = (acc['typeAccount']?['typeAccountId'] ?? (acc['typeAccountId'] ?? acc['TypeAccountId']));
           final name = (acc['name'] ?? acc['Name'])?.toString().toLowerCase() ?? '';
           return typeId == 2 && (name.contains('gerant') || acc['id'] == 3);
        });
        
        // Check Simple Propriétaire (Commissionnaire/Bailleur)
        // On vérifie TOUJOURS, même si Gérant (pour détecter les comptes mixtes)
        isSimpleProprietaire = userAccounts.any((acc) {
          final typeId = (acc['typeAccount']?['typeAccountId'] ?? (acc['typeAccountId'] ?? acc['TypeAccountId']));
          final name = (acc['name'] ?? acc['Name'])?.toString().toLowerCase() ?? '';
          // Propriétaire (typeId 2) MAIS PAS Gérant
          return typeId == 2 && !name.contains('gerant');
        });
      }

      // Si l'utilisateur a LES DEUX rôles -> Afficher TOUT
      if (isGerant && isSimpleProprietaire) {
        return true;
      }
      
      // Si UNIQUEMENT Gérant -> Types spécialisés seulement
      if (isGerant && !isSimpleProprietaire) {
        return !isBasicType;
      }
      
      // Si UNIQUEMENT Propriétaire simple -> Types basiques seulement
      if (isSimpleProprietaire && !isGerant) {
        return isBasicType;
      }
      
      // Fallback (pas de rôle détecté) -> Afficher tout par sécurité
      return true;
    }).map((type) {
      IconData icon;
      String imagePath;
      
      switch (type['name']?.toString().toLowerCase()) {
        case 'studio':
          icon = Icons.apartment_rounded;
          imagePath = 'assets/images/studio.png';
          break;
        case 'apparts':
          icon = Icons.home_work_rounded;
          imagePath = 'assets/images/apart.png';
          break;
        case 'maisons':
          icon = Icons.house_rounded;
          imagePath = 'assets/images/maisons.png';
          break;
        case 'bureau':
          icon = Icons.business_center_rounded;
          imagePath = 'assets/images/office.png';
          break;
        case 'hotels':
          icon = Icons.hotel_rounded;
          imagePath = 'assets/images/hotel.png';
          break;
        case 'vacances':
          icon = Icons.beach_access_rounded;
          imagePath = 'assets/images/plage.png';
          break;
        case 'fêtes':
        case 'salle de fêtes':
        case 'festives':
           icon = Icons.celebration_rounded;
           imagePath = 'assets/images/party.png'; 
           break;
        case 'funérarium':
        case 'salle funéraire':
        case 'funéraires':
           icon = Icons.volunteer_activism_rounded;
           imagePath = 'assets/images/funeral.png'; 
           break;
        case 'terrain':
           icon = Icons.landscape_rounded;
           imagePath = 'assets/images/terrain.png';
           break;
        default:
          icon = Icons.home_rounded;
          imagePath = 'assets/images/maisons.png';
      }
      
      return {
        'id': type['propertyTypeId'],
        'name': type['name'],
        'image': imagePath,
        'label': type['name'],
        'color': _primaryColor,
        'icon': icon,
      };
    }).toList();

    if (categories.isEmpty) {
      return Center(
        child: Text(
          'Aucun type de propriété disponible',
          style: TextStyle(color: _greyColor),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.1, // Aspect ratio ajusté pour une forme plus compacte et élégante
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        final isSelected = _selectedPropertyTypeId == category['id'];
        final categoryColor = category['color'] as Color;

        return GestureDetector(
          onTap: () {
            if (mounted) {
              setState(() {
                _selectedPropertyTypeId = category['id'] as int;
                _selectedCategory = category['name'] as String;
              });
              
              // Force validator re-check
              if (_fieldTouched.containsKey('type')) {
                _validateStep0();
              }
              
              print("🔹 Type sélectionné: $_selectedCategory (ID: $_selectedPropertyTypeId)");
              _checkAgencyRequirement(_selectedCategory!);
            }
          },
          child: AnimatedContainer(
            duration: Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: isSelected ? categoryColor.withOpacity(0.08) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? categoryColor : Colors.grey.shade200,
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: categoryColor.withOpacity(0.25),
                        blurRadius: 14,
                        offset: Offset(0, 8),
                      ),
                      BoxShadow(
                        color: categoryColor.withOpacity(0.1),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      )
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Indicateur de sélection
                if (isSelected)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: categoryColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                           BoxShadow(
                             color: categoryColor.withOpacity(0.4),
                             blurRadius: 6,
                             offset: Offset(0, 2),
                           )
                        ]
                      ),
                      child: Icon(
                        Icons.check,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),

                // Contenu principal
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Icône dans un cercle
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected 
                            ? categoryColor.withOpacity(0.15) 
                            : Colors.grey.shade50,
                        ),
                        child: Icon(
                          category['icon'] as IconData,
                          size: 30,
                          color: isSelected ? categoryColor : _greyColor,
                        ),
                      ),
                      
                      SizedBox(height: 16),
                      
                      // Label
                      Text(
                        category['label'] as String,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                          color: isSelected ? _darkColor : _greyColor,
                          letterSpacing: -0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }


  Widget _buildModernTypeOption(String title, IconData icon, String subtitle, bool isSelected, VoidCallback onTap) {
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
          boxShadow: isSelected ? [
            BoxShadow(
              color: _primaryColor.withOpacity(0.2),
              blurRadius: 8,
              offset: Offset(0, 3),
            )
          ] : null,
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
              child: Icon(
                icon,
                size: 24,
                color: isSelected ? Colors.white : _greyColor,
              ),
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
            ),
            SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: isSelected ? _primaryColor.withOpacity(0.8) : _greyColor,
                fontSize: _smallSize,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernPropertyCategoryCarousel() {
    // Show loading indicator while fetching types
    if (_loadingTypes) {
      return Container(
        height: 120,
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
          ),
        ),
      );
    }

    // Use dynamic property types from API
    // FILTRAGE STRICT PAR RÔLE
    final categories = _propertyTypes.where((type) {
      final typeName = type['name']?.toString().toLowerCase();
      // Types "Basiques" pour Commissionnaire/Bailleur (incluant Terrain)
      final isBasicType = ['studio', 'apparts', 'maisons', 'bureau', 'terrain', 'terrains'].contains(typeName);
      
      // Récupérer les rôles depuis le stockage
      final userAccounts = stockage.read('user_accounts');
      bool isGerant = false;
      bool isSimpleProprietaire = false;

      if (userAccounts != null && userAccounts is List) {
        // Check Gérant
        isGerant = userAccounts.any((acc) {
           final typeId = (acc['typeAccount']?['typeAccountId'] ?? (acc['typeAccountId'] ?? acc['TypeAccountId']));
           final name = (acc['name'] ?? acc['Name'])?.toString().toLowerCase() ?? '';
           return typeId == 2 && (name.contains('gerant') || acc['id'] == 3);
        });
        
        // Check Simple Propriétaire (Commissionnaire/Bailleur)
        // On vérifie TOUJOURS, même si Gérant (pour détecter les comptes mixtes)
        isSimpleProprietaire = userAccounts.any((acc) {
          final typeId = (acc['typeAccount']?['typeAccountId'] ?? (acc['typeAccountId'] ?? acc['TypeAccountId']));
          final name = (acc['name'] ?? acc['Name'])?.toString().toLowerCase() ?? '';
          // Propriétaire (typeId 2) MAIS PAS Gérant
          return typeId == 2 && !name.contains('gerant');
        });
      }

      // Si l'utilisateur a LES DEUX rôles -> Afficher TOUT
      if (isGerant && isSimpleProprietaire) {
        return true;
      }
      
      // Si UNIQUEMENT Gérant -> Types spécialisés seulement
      if (isGerant && !isSimpleProprietaire) {
        return !isBasicType;
      }
      
      // Si UNIQUEMENT Propriétaire simple -> Types basiques seulement
      if (isSimpleProprietaire && !isGerant) {
        return isBasicType;
      }
      
      // Fallback (pas de rôle détecté) -> Afficher tout par sécurité
      return true;
    }).map((type) {
      // Map property type names to icons and images
      IconData icon;
      String imagePath;
      
      switch (type['name']?.toString().toLowerCase()) {
        case 'studio':
          icon = Icons.apartment_rounded;
          imagePath = 'assets/images/studio.png';
          break;
        case 'apparts':
          icon = Icons.home_work_rounded;
          imagePath = 'assets/images/apart.png';
          break;
        case 'maisons':
          icon = Icons.house_rounded;
          imagePath = 'assets/images/maisons.png';
          break;
        case 'bureau':
          icon = Icons.business_center_rounded;
          imagePath = 'assets/images/office.png';
          break;
        case 'hotels':
          icon = Icons.hotel_rounded;
          imagePath = 'assets/images/hotel.png';
          break;
        case 'vacances':
          icon = Icons.beach_access_rounded;
          imagePath = 'assets/images/plage.png';
          break;
        case 'fêtes':
        case 'salle de fêtes':
        case 'festives':
           icon = Icons.celebration_rounded;
           imagePath = 'assets/images/party.png'; 
           break;
        case 'funérarium':
        case 'salle funéraire':
        case 'funéraires':
           icon = Icons.volunteer_activism_rounded;
           imagePath = 'assets/images/funeral.png'; 
           break;
        case 'terrain':
        case 'terrains':
           icon = Icons.landscape_rounded;
           imagePath = 'assets/images/terrain.png';
           break;
        default:
          icon = Icons.home_rounded;
          imagePath = 'assets/images/maisons.png';
      }
      
      return {
        'id': type['propertyTypeId'],
        'name': type['name'],
        'image': imagePath,
        'label': type['name'],
        'color': _primaryColor,
        'icon': icon,
      };
    }).toList();

    if (categories.isEmpty) {
      return Container(
        height: 120,
        child: Center(
          child: Text(
            'Aucun type de propriété disponible',
            style: TextStyle(color: _greyColor),
          ),
        ),
      );
    }

    return Container(
      height: 110,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 4),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = _selectedPropertyTypeId == category['id'];
          final categoryColor = category['color'] as Color;

          return GestureDetector(
            onTap: () {
              if (mounted) {
                setState(() {
                  _selectedPropertyTypeId = category['id'] as int;
                  _selectedCategory = category['name'] as String; // Keep for backward compatibility
                  _removeFieldError(0, 'property_type');
                  _validateStep0();
                  _saveDraft();
                });
                _trackSelection('property_type', category['name'] as String);
                _checkAgencyRequirement(_selectedCategory!);
              }
            },
            child: Container(
              width: 90,
              margin: EdgeInsets.symmetric(horizontal: 5),
              child: Column(
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: isSelected ? categoryColor.withOpacity(0.15) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? categoryColor : _borderColor,
                        width: isSelected ? 2.5 : 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isSelected ? categoryColor.withOpacity(0.3) : Colors.black12,
                          blurRadius: isSelected ? 12 : 6,
                          offset: Offset(0, isSelected ? 4 : 2),
                        )
                      ],
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: Padding(
                            padding: EdgeInsets.all(12),
                            child: Image.asset(
                              category['image'] as String,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                return Icon(
                                  category['icon'] as IconData,
                                  color: isSelected ? categoryColor : _greyColor,
                                  size: 28,
                                );
                              },
                            ),
                          ),
                        ),
                        if (isSelected)
                          Positioned(
                            top: 6,
                            right: 6,
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: categoryColor,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: Icon(
                                Icons.check,
                                size: 12,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(height: _smallSpace),
                  Text(
                    category['label'] as String,
                    style: TextStyle(
                      fontSize: _captionSize,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? categoryColor : _darkColor,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMainImagesCard() {
    final mainImages = _selectedImages['propertyImage'] ?? [];
    final hasError = _getFieldError(2, 'photos') != null || (_hasAttemptedSubmit && mainImages.length < 3);

    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: Offset(0, 6),
          )
        ],
        border: hasError ? Border.all(color: _errorColor, width: 1.5) : Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(_mediumSpace),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_primaryColor, _secondaryColor],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.photo_library_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                SizedBox(width: _mediumSpace),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Photos principales',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: _darkColor,
                          fontSize: _subtitleSize,
                        ),
                      ),
                      Text(
                        'Vue extérieure, salon, pièces principales',
                        style: TextStyle(
                          color: _greyColor,
                          fontSize: _captionSize,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: mainImages.length >= 3 ? _successColor.withOpacity(0.1) : _warningColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: mainImages.length >= 3 ? _successColor : _warningColor,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    '${mainImages.length}/3 min',
                    style: TextStyle(
                      color: mainImages.length >= 3 ? _successColor : _warningColor,
                      fontWeight: FontWeight.w700,
                      fontSize: _captionSize,
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (mainImages.isNotEmpty)
            Padding(
              padding: EdgeInsets.all(_mediumSpace),
              child: GridView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: _smallSpace,
                  mainAxisSpacing: _smallSpace,
                  childAspectRatio: 1,
                ),
                itemCount: mainImages.length,
                itemBuilder: (context, index) {
                  return _buildImageThumbnail('propertyImage', index, mainImages[index]);
                },
              ),
            ),

          Padding(
            padding: EdgeInsets.all(_mediumSpace),
            child: ElevatedButton.icon(
              onPressed: () => _pickImages('propertyImage'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor.withOpacity(0.1),
                foregroundColor: _primaryColor,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                minimumSize: Size(double.infinity, 50),
              ),
              icon: Icon(Icons.add_photo_alternate_rounded, size: 24),
              label: Text(
                'Ajouter des photos principales',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: _bodySize,
                ),
              ),
            ),
          ),

          if (hasError)
            Padding(
              padding: EdgeInsets.fromLTRB(_mediumSpace, 0, _mediumSpace, _mediumSpace),
              child: Container(
                padding: EdgeInsets.all(_smallSpace),
                decoration: BoxDecoration(
                  color: _errorColor.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _errorColor.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline_rounded, color: _errorColor, size: 18),
                    SizedBox(width: _smallSpace),
                    Expanded(
                      child: Text(
                        'Au moins 3 photos principales sont requises',
                        style: TextStyle(
                          color: _errorColor,
                          fontWeight: FontWeight.w600,
                          fontSize: _captionSize,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAdditionalRoomsExpansion() {
    final additionalCategories = _imageCategories.where((cat) => cat.id != 'propertyImage').toList();

    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: Offset(0, 6),
          )
        ],
        border: Border.all(color: _borderColor),
      ),
      child: ExpansionTile(
        tilePadding: EdgeInsets.symmetric(horizontal: _mediumSpace, vertical: _smallSpace),
        collapsedIconColor: _greyColor,
        iconColor: _primaryColor,
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.room_preferences_rounded, color: _primaryColor),
        ),
        title: Text(
          'Photos par pièces (optionnel)',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: _darkColor,
            fontSize: _bodySize,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Chambres, cuisine, salon, salle de bain...',
              style: TextStyle(
                color: _greyColor,
                fontSize: _captionSize,
              ),
            ),
            SizedBox(height: _smallSpace),
            Row(
              children: [
                Icon(Icons.touch_app_rounded, size: 14, color: _primaryColor),
                SizedBox(width: 4),
                Text(
                  'Appuyez ici pour dérouler',
                  style: TextStyle(
                    color: _primaryColor,
                    fontSize: _captionSize - 2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '${additionalCategories.length} types',
            style: TextStyle(
              color: _primaryColor,
              fontWeight: FontWeight.w600,
              fontSize: _captionSize,
            ),
          ),
        ),
        children: [
          Divider(height: 1, color: _borderColor),
          ...additionalCategories.map((category) => _buildRoomImageCard(category)),
        ],
      ),
    );
  }

  Widget _buildRoomImageCard(ImageCategory category) {
    final images = _selectedImages[category.id] ?? [];

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: _mediumSpace, vertical: _smallSpace),
      child: Container(
        decoration: BoxDecoration(
          color: _lightColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _borderColor),
        ),
        child: Column(
          children: [
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: category.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(category.icon, color: category.color, size: 20),
              ),
              title: Text(
                category.name,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: _darkColor,
                  fontSize: _bodySize,
                ),
              ),
              subtitle: Text(
                category.description,
                style: TextStyle(
                  color: _greyColor,
                  fontSize: _captionSize,
                ),
              ),
              trailing: Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: images.isNotEmpty ? _successColor.withOpacity(0.1) : _greyColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${images.length}',
                  style: TextStyle(
                    color: images.isNotEmpty ? _successColor : _greyColor,
                    fontWeight: FontWeight.w700,
                    fontSize: _captionSize,
                  ),
                ),
              ),
            ),

            if (images.isNotEmpty)
              Padding(
                padding: EdgeInsets.all(_smallSpace),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: _smallSpace,
                    mainAxisSpacing: _smallSpace,
                    childAspectRatio: 1,
                  ),
                  itemCount: images.length,
                  itemBuilder: (context, index) {
                    return _buildImageThumbnail(category.id, index, images[index]);
                  },
                ),
              ),

            Padding(
              padding: EdgeInsets.all(_mediumSpace),
              child: OutlinedButton.icon(
                onPressed: () => _pickImages(category.id),
                style: OutlinedButton.styleFrom(
                  foregroundColor: category.color,
                  side: BorderSide(color: category.color),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  minimumSize: Size(double.infinity, 44),
                ),
                icon: Icon(Icons.add_rounded, size: 18),
                label: Text(
                  'Ajouter des ${category.name.toLowerCase()}',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: _bodySize),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageThumbnail(String categoryId, int index, XFile image) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(
            File(image.path),
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: Colors.grey[200],
                child: Icon(Icons.error, color: Colors.grey),
              );
            },
          ),
        ),
        // Overlay avec bouton de suppression
        Positioned.fill(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {}, // Vide pour l'effet visuel
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withOpacity(0.3),
                    ],
                  ),
                ),
                child: Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: EdgeInsets.all(6),
                    child: GestureDetector(
                      onTap: () => _removeImage(categoryId, index),
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModernImageCounter() {
    final totalImages = _totalImagesCount;
    final hasMinimumImages = totalImages >= 3;

    return Container(
      padding: EdgeInsets.all(_mediumSpace),
      decoration: BoxDecoration(
        color: hasMinimumImages ? _successColor.withOpacity(0.05) : _warningColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasMinimumImages ? _successColor.withOpacity(0.3) : _warningColor.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: hasMinimumImages ? _successColor : _warningColor,
              shape: BoxShape.circle,
            ),
            child: Icon(
              hasMinimumImages ? Icons.check_rounded : Icons.photo_library_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          SizedBox(width: _mediumSpace),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasMinimumImages ? 'Photos suffisantes' : 'Photos requises',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: hasMinimumImages ? _successColor : _warningColor,
                    fontSize: _bodySize,
                  ),
                ),
                Text(
                  hasMinimumImages
                      ? 'Vous avez ajouté $totalImages photos. Excellente présentation !'
                      : 'Ajoutez au moins 3 photos principales ($totalImages/3)',
                  style: TextStyle(
                    color: _greyColor,
                    fontSize: _captionSize,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: hasMinimumImages ? _successColor : _warningColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$totalImages',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: _bodySize,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep2() {
    // Detect property type
    final typeName = _selectedCategory?.toLowerCase() ?? '';
    final isVacances = typeName.contains('vacance');
    final isBureau = typeName.contains('bureau') || (_selectedPropertyTypeId == 4);
    final isTerrain = typeName.contains('terrain');
    final isFestive = typeName.contains('fête') || typeName.contains('festive');
    final isFuneraire = typeName.contains('funéra') || typeName.contains('deuil');
    
    return SingleChildScrollView(
      key: ValueKey('step1_scroll'),
      physics: BouncingScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: _mediumSpace, vertical: _mediumSpace),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildModernSectionHeader(
            title: 'Informations de base',
            icon: Icons.info_outline_rounded,
          ),
          SizedBox(height: _mediumSpace),

          _buildModernTextField(
            controller: _titleController,
            label: 'Titre de l\'annonce',
            hint: 'Magnifique appartement avec vue panoramique...',
            icon: Icons.title_rounded,
            focusNode: _focusNodes[0],
            nextFocusNode: _focusNodes[1],
            errorText: _getFieldError(1, 'title'),
            fieldKey: 'title',
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Veuillez entrer un titre';
              }
              if (value.length < 10) {
                return 'Le titre doit faire au moins 10 caractères';
              }
              return null;
            },
          ),
          SizedBox(height: _smallSpace),

          _buildModernTextField(
            controller: _priceController,
            label: (isFestive || isFuneraire) ? 'Prix' : (_isForRent ? 'Prix mensuel' : 'Prix de vente'),
            hint: (isFestive || isFuneraire) ? '500' : (_isForRent ? '1200' : '450000'),
            icon: Icons.attach_money_rounded,
            keyboardType: TextInputType.number,
            suffixText: (isFestive || isFuneraire) ? null : (_isForRent ? '/mois' : '\$'),
            prefixIconColor: _isForRent ? Colors.blue : Colors.green,
            focusNode: _focusNodes[1],
            nextFocusNode: _isForRent ? _focusNodes[2] : _focusNodes[3],
            errorText: _getFieldError(1, 'price'),
            fieldKey: 'price',
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Veuillez entrer un prix';
              }
              if (double.tryParse(value) == null) {
                return 'Veuillez entrer un nombre valide';
              }
              return null;
            },
          ),
          SizedBox(height: _smallSpace),

          // SÉLECTEUR DE DEVISE DYNAMIQUE
          Consumer<PropertyController>(
            builder: (context, ctrl, child) {
              final devises = ctrl.devisesList;
              
              // Si pas de devises chargées, on affiche quand même avec fallback ou loader
              if (devises.isEmpty) {
                 return SizedBox.shrink(); // Ou un loader
              }

              // Conversion des modèles en DropdownMenuItem
              final List<DropdownMenuItem<int>> dropdownItems = devises.map((devise) {
                return DropdownMenuItem<int>(
                  value: devise.id,
                  child: Row(
                    children: [
                       Text(
                        devise.code ?? "", 
                        style: TextStyle(
                          color: _darkColor,
                          fontWeight: FontWeight.w600,
                          fontSize: _bodySize
                        )
                       ),
                       SizedBox(width: 8),
                       Text(
                        devise.name ?? "",
                        style: TextStyle(
                          color: _greyColor,
                          fontSize: _captionSize
                        )
                       )
                    ],
                  ),
                );
              }).toList();

              // Safeguard: Ensure selected value exists in list
              int? validValue = _selectedDeviseId;
              if (devises.isNotEmpty && !devises.any((d) => d.id == _selectedDeviseId)) {
                  validValue = devises.first.id;
                  // Optional: Schedule a microtask to update state if needed, but for display this is enough
              }

              return Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _borderColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    )
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(left: 4, bottom: 4, top: 4),
                      child: Text(
                        'Devise',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _darkColor,
                        ),
                      ),
                    ),
                    DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: validValue,
                        isExpanded: true,
                        icon: Icon(Icons.keyboard_arrow_down_rounded, color: _primaryColor),
                        items: dropdownItems,
                        onChanged: (int? newValue) {
                           if (newValue != null) {
                             setState(() {
                               _selectedDeviseId = newValue;
                             });
                           }
                        },
                      ),
                    )
                  ],
                ),
              );
            }
          ),
          SizedBox(height: _smallSpace),

          // Guarantee field - only show for rent and NOT for Vacances, Bureau, Terrain, Festive, or Funeraire
          if (_isForRent && !isVacances && !isBureau && !isTerrain && !isFestive && !isFuneraire) ...[
            _buildModernTextField(
              controller: _guaranteeController,
              label: 'Garantie',
              hint: '3+1 (optionnel)',
              icon: Icons.security_rounded,
              keyboardType: TextInputType.text, // Changed to text to allow "3+1" format
              suffixText: '/mois',
              prefixIconColor: Colors.orange,
              focusNode: _focusNodes[2],
              nextFocusNode: _focusNodes[3],
              errorText: _getFieldError(1, 'guarantee'),
              fieldKey: 'guarantee',
              validator: (value) {
                // No validation needed - allow any string format
                return null;
              },
            ),
            SizedBox(height: _smallSpace),
          ],

          _buildModernTextField(
            controller: _descriptionController,
            label: 'Description détaillée',
            hint: 'Décrivez en détail les avantages, l\'emplacement, les équipements...',
            icon: Icons.description_rounded,
            maxLines: 4,
            focusNode: _focusNodes[3],
            nextFocusNode: _focusNodes[4],
            errorText: _getFieldError(1, 'description'),
            fieldKey: 'description',
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Veuillez entrer une description';
              }
              return null;
            },
          ),

          SizedBox(height: _largeSpace),
          _buildModernSectionHeader(
            title: 'Localisation',
            icon: Icons.location_on_outlined,
          ),
          SizedBox(height: _mediumSpace),

          // Ville avec suggestions (typeahead)
          _buildCitySuggestionField(),

          SizedBox(height: _mediumSpace),

          if (_isKinshasaSelected) ...[
            // Dropdowns premium pour la localisation Kinshasa
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
                              _removeFieldError(1, 'district');
                              _updateCommunesForDistrict();
                              _validateStep1();
                              _saveDraft();
                            });
                            _trackSelection('district', newValue?.name ?? 'unknown');
                          }
                        },
                        icon: Icons.account_balance_rounded,
                        errorText: _getFieldError(1, 'district'),
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
                        displayText: (commune) {
                          final name = commune.name ?? '';
                          if (name.toLowerCase() == 'bandalungwa') return 'Bandal';
                          return name;
                        },
                        onChanged: (CommuneModel? newValue) {
                          if (mounted) {
                            _markFieldTouched('commune');
                            _clickCount++;
                            setState(() {
                              _selectedCommune = newValue;
                              _removeFieldError(1, 'commune');
                              _updateQuartiersForCommune();
                              _validateStep1();
                              _saveDraft();
                            });
                            _trackSelection('commune', newValue?.name ?? 'unknown');
                          }
                        },
                        icon: Icons.place_rounded,
                        errorText: _getFieldError(1, 'commune'),
                        hintText: 'Sélectionnez une commune',
                      ),
                    ),
                  ],
                );
              },
            ),
            SizedBox(height: _smallSpace),
            // Quartier dropdown avec données de l'API
            _buildKinshasaQuartierDropdown(),
            SizedBox(height: _mediumSpace),
          ] else if (_isMatadiSelected) ...[
            // Mode Matadi : dropdown pour communes spécifiques
            _buildMatadiCommuneDropdown(),
            SizedBox(height: _smallSpace),
            // Champ texte libre pour quartier
            _buildModernTextField(
              controller: _quartierTextController,
              label: 'Quartier',
              hint: 'Entrez le quartier',
              icon: Icons.location_city,
              fieldKey: 'quartier',
            ),
            SizedBox(height: _mediumSpace),
          ] else ...[
            // Mode autres villes : champs texte libres
            _buildModernTextField(
              controller: _communeTextController,
              label: 'Commune',
              hint: 'Entrez la commune',
              icon: Icons.place_rounded,
              fieldKey: 'commune',
            ),
            SizedBox(height: _smallSpace),
            _buildModernTextField(
              controller: _quartierTextController,
              label: 'Quartier',
              hint: 'Entrez le quartier',
              icon: Icons.location_city,
              fieldKey: 'quartier',
            ),
            SizedBox(height: _mediumSpace),
          ],

          _buildModernTextField(
            controller: _addressController,
            label: 'Adresse complète',
            hint: 'Numéro, rue, avenue...',
            icon: Icons.home_work_rounded,
            focusNode: _focusNodes[4],
            nextFocusNode: null,
            errorText: _getFieldError(1, 'address'),
            fieldKey: 'address',
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Veuillez entrer une adresse complète';
              }
              if (value.length < 10) {
                return 'L\'adresse doit être plus détaillée (${value.length}/10)';
              }
              return null;
            },
          ),
          SizedBox(height: _largeSpace),

          _buildModernSectionHeader(
            title: 'Caractéristiques',
            icon: Icons.apartment_rounded,
          ),
          SizedBox(height: _mediumSpace),

          // LOGIQUE DYNAMIQUE DES CHAMPS SELON LE TYPE
          Builder(
            builder: (context) {
              final typeName = _selectedCategory?.toLowerCase() ?? '';
              final isFestive = typeName.contains('fête') || typeName.contains('festive');
              final isFuneraire = typeName.contains('funéra') || typeName.contains('deuil');
              final isBureau = typeName.contains('bureau') || (_selectedPropertyTypeId == 4);
              final isTerrain = typeName.contains('terrain');
              final isVacances = typeName.contains('vacance');

              if (isFestive) {
                 return FestiveFormFields(
                   capacityController: _capacityController,
                   usageError: _getFieldError(1, 'usage'),
                   capacityError: _getFieldError(1, 'capacity'),
                   isDecore: _isDecore,
                   pisteDanse: _pisteDanse,
                   initUsage: _selectedUsage,
                   onUsageChanged: (val) => setState(() => _selectedUsage = val),
                   onDecoreChanged: (val) => setState(() => _isDecore = val),
                   onPisteDanseChanged: (val) => setState(() => _pisteDanse = val),
                 );
              } else if (isFuneraire) {
                 return FuneraireFormFields(
                   capacityController: _capacityController,
                   capacityError: _getFieldError(1, 'capacity'),
                 );
              } else if (isBureau) {
                 return BureauFormFields(
                   areaController: _areaController,
                   roomMeetController: _roomMeetController,
                   numberPieceController: _numberPieceController,
                   isEquip: _isEquip,
                   hasFloor: _hasFloor,
                   areaError: _getFieldError(1, 'area'),
                   roomMeetError: _getFieldError(1, 'roomMeet'),
                   numberPieceError: _getFieldError(1, 'numberPiece'),
                   onEquipChanged: (val) {
                     setState(() {
                       _isEquip = val;
                       _saveDraft();
                     });
                   },
                   onFloorChanged: (val) {
                     setState(() {
                       _hasFloor = val;
                       _saveDraft();
                     });
                   },
                 );
              } else if (isTerrain) {
                   return TerrainFormFields(
                     surfaceController: _areaController,
                     surfaceError: _getFieldError(1, 'area'),
                   );
              } else if (isVacances) {
                 return VacanceFormFields(
                   dateController: _dateVacanceController,
                   heureController: _heureVacanceController,
                   capacityController: _capacityController,
                   noteController: _noteController,
                   offreController: _offreController,
                   selectedPriceCombo: _selectedPriceCombo,
                   dateError: _getFieldError(1, 'date'),
                   timeError: _getFieldError(1, 'time'),
                   capacityError: _getFieldError(1, 'capacity'),
                   onPriceComboChanged: (val) {
                     setState(() {
                       _selectedPriceCombo = val;
                       _saveDraft();
                     });
                   },
                 );
              } else {
                // Résidentiel (Standard)
                 return GridView.count(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: _smallSpace,
                  mainAxisSpacing: _smallSpace,
                  childAspectRatio: 3.2,
                  children: [
                    _buildModernFeatureInput(
                      controller: _bedroomsController,
                      label: 'Chambres',
                      icon: FontAwesomeIcons.bed,
                      color: Color(0xFF6B46C1).withOpacity(0.1),
                      iconColor: Color(0xFF6B46C1),
                    ),
                    _buildModernFeatureInput(
                      controller: _bathroomsController,
                      label: 'Salles de bain',
                      icon: FontAwesomeIcons.bath,
                      color: Color(0xFF059669).withOpacity(0.1),
                      iconColor: Color(0xFF059669),
                    ),
                    _buildModernFeatureInput(
                      controller: _livingRoomsController,
                      label: 'Salons',
                      icon: FontAwesomeIcons.couch,
                      color: Color(0xFFDC2626).withOpacity(0.1),
                      iconColor: Color(0xFFDC2626),
                    ),
                    _buildModernFeatureInput(
                      controller: _kitchensController,
                      label: 'Cuisines',
                      icon: FontAwesomeIcons.kitchenSet,
                      color: Color(0xFFEA580C).withOpacity(0.1),
                      iconColor: Color(0xFFEA580C),
                    ),
                    _buildModernFeatureInput(
                      controller: _areaController,
                      label: 'Surface (m²)',
                      icon: FontAwesomeIcons.rulerCombined,
                      color: Color(0xFF0891B2).withOpacity(0.1),
                      iconColor: Color(0xFF0891B2),
                    ),
                    _buildSwitchTile(
                      'Étage ?', 
                      _hasFloor, 
                      (v) => setState(() => _hasFloor = v)
                    ),
                  ],
                );
              }
            }
          ),
          SizedBox(height: _mediumSpace),
          _buildBottomNavigation(),
          SizedBox(height: 20),
        ],
      ),
    );
  }

Widget _buildStep3() {
    final typeName = _selectedCategory?.toLowerCase() ?? '';
    final isTerrain = typeName.contains('terrain');
    final isVacances = typeName.contains('vacances') || typeName.contains('hotel');

    return SingleChildScrollView(
      key: ValueKey('step2_scroll'),
      physics: BouncingScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: _mediumSpace, vertical: _mediumSpace),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           // PHOTOS SECTION (Moved from old Step 0)
          _buildModernSectionHeader(
            title: 'Photos principales',
            icon: Icons.photo_library_rounded,
          ),
          SizedBox(height: _smallSpace),
          Text(
            'Ajoutez au moins 3 photos de qualité pour attirer plus d\'attention',
            style: TextStyle(
              color: _greyColor,
              fontSize: _captionSize,
            ),
          ),
          SizedBox(height: _mediumSpace),
          _buildMainImagesCard(),

          SizedBox(height: _mediumSpace),
          SizedBox(height: _mediumSpace),
          Builder(
            builder: (context) {
              final typeName = _selectedCategory?.toLowerCase() ?? '';
              final isExcluded = typeName.contains('bureau') || 
                               typeName.contains('fête') || 
                               typeName.contains('festive') ||
                               typeName.contains('funéra') || 
                               typeName.contains('deuil') || 
                               typeName.contains('terrain') || 
                               typeName.contains('hotel') || 
                               typeName.contains('vacances');
              
              if (isExcluded) return SizedBox.shrink();
              
              return _buildAdditionalRoomsExpansion();
            }
          ),

          SizedBox(height: _mediumSpace),
          _buildModernImageCounter(),
          SizedBox(height: _largeSpace),
          
          if (!isTerrain && !isVacances) ...[
            // SERVICES ESSENTIELS
            _buildModernSectionHeader(
              title: 'Services essentiels',
              icon: Icons.engineering_rounded,
            ),
            SizedBox(height: _smallSpace),
            Text(
              'Ces informations sont obligatoires pour aider les locataires',
              style: TextStyle(
                color: _greyColor,
                fontSize: _captionSize,
              ),
            ),
            SizedBox(height: _mediumSpace),
            _buildModernElectricDropdown(),
            SizedBox(height: _smallSpace),
            _buildModernWaterDropdown(),
            SizedBox(height: _largeSpace),
          ],

          if (!isTerrain && !isVacances)
            _buildModernSectionHeader(
              title: 'Équipements (optionnels)',
              icon: Icons.emoji_objects_outlined,
            ),
          if (!isTerrain && !isVacances) ...[
            SizedBox(height: _smallSpace),
            Text(
              'Sélectionnez les équipements disponibles dans votre propriété',
              style: TextStyle(
                color: _greyColor,
                fontSize: _captionSize,
              ),
            ),
            SizedBox(height: _mediumSpace),
          ],
          
          
          // Show loading indicator while fetching features
          if (!isTerrain && !isVacances)
            if (_loadingFeatures)
            Center(
              child: Padding(
                padding: EdgeInsets.all(_mediumSpace),
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
                ),
              ),
            )
          else if (_features.isEmpty)
            Center(
              child: Padding(
                padding: EdgeInsets.all(_mediumSpace),
                child: Text(
                  'Aucune caractéristique disponible',
                  style: TextStyle(color: _greyColor),
                ),
              ),
            )
          else
            Wrap(
              spacing: _smallSpace,
              runSpacing: _smallSpace,
              children: _features.map((feature) {
                final featureId = feature['featureId'] as int;
                final featureName = feature['name'] as String;
                final isSelected = _selectedFeatureIds.contains(featureId);
                
                return ChoiceChip(
                  label: Text(
                    featureName,
                    style: TextStyle(fontSize: _captionSize),
                  ),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (mounted) {
                      setState(() {
                        if (selected) {
                          _selectedFeatureIds.add(featureId);
                          _selectedAmenities.add(featureName); // Keep for backward compatibility
                        } else {
                          _selectedFeatureIds.remove(featureId);
                          _selectedAmenities.remove(featureName);
                        }
                        _validateStep2();
                        _saveDraft();
                      });
                      _trackSelection('amenity', featureName);
                    }
                  },
                  selectedColor: _primaryColor.withOpacity(0.1),
                  backgroundColor: _lightColor,
                  labelStyle: TextStyle(
                    color: isSelected ? _primaryColor : _darkColor,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(
                    color: isSelected ? _primaryColor : _borderColor,
                  ),
                ),
              );
            }).toList(),
          ),
          SizedBox(height: _largeSpace),
          _buildBottomNavigation(),
          SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildDeviseOption({required String label, required int value, required bool isSelected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? _primaryColor.withOpacity(0.05) : _lightColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? _primaryColor : _borderColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? _primaryColor : _greyColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchTile(String title, bool value, Function(bool) onChanged) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor),
      ),
      child: SwitchListTile(
        title: Text(title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: _bodySize - 2, color: _darkColor)),
        value: value,
        onChanged: onChanged,
        activeColor: _primaryColor,
        contentPadding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        dense: true,
      ),
    );
  }



  Widget _buildBottomNavigation() {
    final isLastStep = _currentStep == 2;
    final canProceed = !_isLoading;
    final canPublish = _stepValidations[0]! && _stepValidations[1]! && _stepValidations[2]! && !_isLoading;
    
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(_mediumSpace),
          child: Row(
            children: [
              if (_currentStep > 0)
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : () {
                      if (mounted) {
                        _endStepTracking(_currentStep, _getStepName(_currentStep), false);
                        setState(() => _currentStep--);
                        _startStepTracking(_currentStep, _getStepName(_currentStep));
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _greyColor,
                      side: BorderSide(color: _borderColor),
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Précédent',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: _bodySize),
                    ),
                  ),
                ),
              if (_currentStep > 0) SizedBox(width: _mediumSpace),
              Expanded(
                child: ElevatedButton(
                  onPressed: isLastStep
                      ? (canPublish && !_isLoading ? _handleCreatePropertyPost : null)
                      : (canProceed ? () {
                    bool currentStepValid = false;
                    switch (_currentStep) {
                      case 0:
                        currentStepValid = _validateStep0();
                        break;
                      case 1:
                        currentStepValid = _validateStep1();
                        break;
                      case 2:
                        currentStepValid = _validateStep2();
                        break;
                    }
                    
                    if (currentStepValid) {
                      _endStepTracking(_currentStep, _getStepName(_currentStep), true);
                      setState(() => _currentStep++);
                      _startStepTracking(_currentStep, _getStepName(_currentStep));
                    } else {
                       _hasAttemptedSubmit = true;
                    }
                  } : null),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isLastStep 
                        ? (canPublish ? _primaryColor : _greyColor)
                        : (canProceed ? _primaryColor : _greyColor),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading && isLastStep
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                    isLastStep ? 'Publier l\'annonce' : 'Suivant',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: _bodySize),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 8),
        Text(
          "La publication est soumise à validation.",
          style: TextStyle(
            color: Colors.grey[500],
            fontSize: 12,
            fontStyle: FontStyle.italic,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }


  // =============================================
  // WIDGETS DE BASE HARMONISÉS
  // =============================================

  Widget _buildModernSectionHeader({required String title, required IconData icon}) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: _smallSpace, horizontal: _mediumSpace),
      decoration: BoxDecoration(
        color: _primaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _primaryColor.withOpacity(0.1), width: 1),
      ),
      child: Row(
        children: [
          Icon(icon, color: _primaryColor, size: 20),
          SizedBox(width: _smallSpace),
          Text(
            title,
            style: TextStyle(
              fontSize: _bodySize,
              fontWeight: FontWeight.w600,
              color: _primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCitySuggestionField() {
    final errorText = _getFieldError(1, 'city');
    final hasError = errorText != null && errorText.isNotEmpty;

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
            _onCityChanged(selection);
          },
          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
            _cityTextController.value = controller.value;
            return TextField(
              controller: controller,
              focusNode: focusNode,
              onTapOutside: (event) {
                focusNode.unfocus();
              },
              style: TextStyle(color: Colors.black87, fontSize: _bodySize),
              onChanged: (value) {
                _onCityChanged(value);
              },
              decoration: InputDecoration(
                hintText: 'Ex: Kinshasa, Lubumbashi...',
                hintStyle: TextStyle(color: Colors.grey[600]),
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

  Widget _buildKinshasaQuartierDropdown() {
    final hasError = _getFieldError(1, 'quartier') != null;

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
                  'Quartier',
                  style: TextStyle(
                    fontSize: _bodySize,
                    fontWeight: FontWeight.w600,
                    color: hasError ? _errorColor : _darkColor,
                  ),
                ),
                Text(
                  '*',
                  style: TextStyle(
                    color: _errorColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Autocomplete<Map<String, dynamic>>(
            optionsBuilder: (TextEditingValue textEditingValue) {
              if (textEditingValue.text.isEmpty) {
                return const Iterable<Map<String, dynamic>>.empty();
              }
              return _kinshasaQuartiers.where((option) {
                return (option['name'] ?? '').toString().toLowerCase()
                    .contains(textEditingValue.text.toLowerCase());
              });
            },
            displayStringForOption: (option) => option['name'] ?? '',
            onSelected: (selection) {
              _markFieldTouched('quartier');
              _clickCount++;
              setState(() {
                _selectedKinshasaQuartier = selection;
                _quartierTextController.text = selection['name'] ?? '';
                _removeFieldError(1, 'quartier');
                _validateStep1();
                _saveDraft();
              });
              _trackSelection('quartier', selection['name'] ?? 'unknown');
            },
            fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
              // Préremplir si une sélection existe déjà
              if (_selectedKinshasaQuartier != null && controller.text.isEmpty) {
                controller.text = _selectedKinshasaQuartier!['name'];
              }
              
              return TextField(
                controller: controller,
                focusNode: focusNode,
                onTapOutside: (event) {
                  focusNode.unfocus();
                },
                style: TextStyle(fontSize: _bodySize),
                decoration: InputDecoration(
                  hintText: _isLoadingQuartiers ? 'Chargement...' : 'Rechercher un quartier...',
                  prefixIcon: Icon(Icons.search, color: hasError ? _errorColor : _primaryColor),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: hasError ? _errorColor : _borderColor,
                      width: hasError ? 1.5 : 1,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: hasError ? _errorColor : _borderColor,
                      width: hasError ? 1.5 : 1,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: hasError ? _errorColor : _primaryColor,
                      width: 2,
                    ),
                  ),
                ),
                onChanged: (val) {
                  // Mettre à jour le contrôleur principal pour la validation
                  _quartierTextController.text = val;
                  
                  // Si l'utilisateur efface, on invalide la sélection
                  if (val.isEmpty && _selectedKinshasaQuartier != null) {
                    setState(() {
                      _selectedKinshasaQuartier = null;
                    });
                  }
                  
                  // Déclencher la validation
                  _validateCurrentStepFields();
                },
                onSubmitted: (val) => onFieldSubmitted(),
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
                    _getFieldError(1, 'quartier')!,
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

  Widget _buildMatadiCommuneDropdown() {
    final hasError = _getFieldError(1, 'commune') != null;
    final currentValue = _communeTextController.text.isNotEmpty ? _communeTextController.text : null;

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
                  'Commune',
                  style: TextStyle(
                    fontSize: _bodySize,
                    fontWeight: FontWeight.w600,
                    color: hasError ? _errorColor : _darkColor,
                  ),
                ),
                Text(
                  '*',
                  style: TextStyle(
                    color: _errorColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          DropdownButtonFormField<String>(
            value: _matadiCommunes.contains(currentValue) ? currentValue : null,
            decoration: InputDecoration(
              hintText: 'Sélectionnez une commune',
              hintStyle: TextStyle(fontSize: _bodySize, color: Colors.grey.shade500),
              prefixIcon: Icon(
                Icons.place_rounded,
                color: hasError ? _errorColor : _primaryColor,
                size: 20,
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: hasError ? _errorColor : _borderColor,
                  width: hasError ? 1.5 : 1,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: hasError ? _errorColor : _borderColor,
                  width: hasError ? 1.5 : 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: hasError ? _errorColor : _primaryColor,
                  width: 2,
                ),
              ),
            ),
            items: _matadiCommunes.map((commune) {
              return DropdownMenuItem<String>(
                value: commune,
                child: Text(
                  commune,
                  style: TextStyle(fontSize: _bodySize),
                ),
              );
            }).toList(),
            onChanged: (String? newValue) {
              _markFieldTouched('commune');
              _clickCount++;
              setState(() {
                _communeTextController.text = newValue ?? '';
                _removeFieldError(1, 'commune');
                _validateStep1();
                _saveDraft();
              });
              _trackSelection('commune', newValue ?? 'unknown');
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
                    _getFieldError(1, 'commune')!,
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

  Widget _buildSuggestionTextField({
    required String label,
    required TextEditingController controller,
    required String fieldKey,
    required List<String> suggestions,
  }) {
    final errorText = _getFieldError(1, fieldKey);
    final hasError = errorText != null && errorText.isNotEmpty;

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
              Text('*', style: TextStyle(color: _errorColor, fontWeight: FontWeight.bold)),
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
              _removeFieldError(1, fieldKey);
              _validateStep1();
              _saveDraft();
            });
            _trackSelection(fieldKey, selection);
          },
          fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
            controller.value = textController.value;
            return TextField(
              controller: textController,
              focusNode: focusNode,
              onTapOutside: (event) {
                focusNode.unfocus();
              },
              onChanged: (value) {
                _markFieldTouched(fieldKey);
                _removeFieldError(1, fieldKey);
                // Validate immediately when user types
                if (value.trim().isNotEmpty) {
                  _validateStep1();
                }
              },
              style: TextStyle(
                fontSize: _bodySize,
                color: Colors.black87, // Force black text on white background
              ),
              decoration: InputDecoration(
                hintText: 'Saisir $label',
                hintStyle: TextStyle(
                  fontSize: _bodySize,
                  color: Colors.grey[600],
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


  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? suffixText,
    int maxLines = 1,
    Color prefixIconColor = Colors.blue,
    FocusNode? focusNode,
    FocusNode? nextFocusNode,
    String? errorText,
    String? Function(String?)? validator,
    String? fieldKey, // Clé unique pour identifier le champ
  }) {
    // Afficher l'erreur seulement si nécessaire
    final shouldShow = fieldKey != null ? _shouldShowError(_currentStep, fieldKey) : true;
    final displayError = shouldShow && (errorText != null && errorText.isNotEmpty);
    final hasError = displayError;

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
                Text(
                  '*',
                  style: TextStyle(
                    color: _errorColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            maxLines: maxLines,
            focusNode: focusNode,
            validator: validator,
            onChanged: (value) {
              if (mounted) {
                setState(() {
                  if (fieldKey != null) {
                    _markFieldTouched(fieldKey);
                  }
                  _validateCurrentStepFields();
                });
              }
            },
            onTap: () {
              if (fieldKey != null && mounted) {
                setState(() {
                  _clickCount++;
                  _markFieldTouched(fieldKey);
                  _validateCurrentStepFields();
                });
              }
            },
            onFieldSubmitted: (value) {
              if (nextFocusNode != null) {
                nextFocusNode.requestFocus();
              }
            },
            textInputAction: nextFocusNode != null ? TextInputAction.next : TextInputAction.done,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: _bodySize),
              prefixIcon: Icon(
                icon,
                color: hasError ? _errorColor : prefixIconColor,
                size: 20,
              ),
              suffixText: suffixText,
              suffixStyle: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
                fontSize: _bodySize,
              ),
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              floatingLabelBehavior: FloatingLabelBehavior.never,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: hasError ? _errorColor : Colors.grey.shade300,
                  width: hasError ? 1.5 : 1,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: hasError ? _errorColor : Colors.grey.shade300,
                  width: hasError ? 1.5 : 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: hasError ? _errorColor : Colors.blue,
                  width: 2,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: _errorColor,
                  width: 1.5,
                ),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: _errorColor,
                  width: 2,
                ),
              ),
            ),
            style: TextStyle(
              fontSize: _bodySize,
              color: Colors.grey.shade800,
              fontWeight: FontWeight.w500,
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



  Widget _buildModernFeatureInput({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required Color color,
    required Color iconColor,
    bool readOnly = false,
    VoidCallback? onTap,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      readOnly: readOnly,
      onTap: onTap,
      onChanged: (value) {
        _validateStep1();
        _saveDraft();
      },
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: Colors.grey.shade700,
          fontWeight: FontWeight.w500,
          fontSize: _captionSize,
        ),
        prefixIcon: Icon(icon, color: _greyColor, size: 18),
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
        fillColor: Colors.white,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      style: TextStyle(
        fontSize: _bodySize,
        fontWeight: FontWeight.w500,
        color: Colors.black87, // Force black text on white background
      ),
    );
  }

  Widget _buildTransactionTypeSelector() {
    return Row(
      children: [
        _buildAudaciousTypeCard(
          title: 'LOCATION',
          subtitle: 'Mettre en loyer',
          icon: Icons.key_rounded,
          isSelected: _isForRent,
          onTap: () {
            if (mounted) {
              setState(() {
                _isForRent = true;
                _saveDraft();
              });
            }
          },
        ),
        SizedBox(width: _mediumSpace),
        _buildAudaciousTypeCard(
          title: 'VENTE',
          subtitle: 'Vendre le bien',
          icon: Icons.auto_graph_rounded,
          isSelected: !_isForRent,
          onTap: () {
            if (mounted) {
              setState(() {
                _isForRent = false;
                _saveDraft();
              });
            }
          },
        ),
      ],
    );
  }

  Widget _buildAudaciousTypeCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: Duration(milliseconds: 350),
          curve: Curves.elasticOut,
          height: 80, // Légèrement réduit pour éviter l'overflow
          decoration: BoxDecoration(
            gradient: isSelected
                ? LinearGradient(
                    colors: [_primaryColor, _primaryColor.withBlue(255)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : LinearGradient(
                    colors: [Colors.white, _cardColor],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? _primaryColor : _borderColor.withOpacity(0.5),
              width: isSelected ? 2.5 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: _primaryColor.withOpacity(0.3),
                      blurRadius: 15,
                      offset: Offset(0, 8),
                    )
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    )
                  ],
          ),
          child: Stack(
            children: [
              // Background Decorative Icon (Plus petite pour éviter l'overflow)
              Positioned(
                right: -5,
                bottom: -5,
                child: Icon(
                  icon,
                  size: 45,
                  color: isSelected ? Colors.white.withOpacity(0.12) : _greyColor.withOpacity(0.05),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    // Icon Container
                    Container(
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.white.withOpacity(0.2) : _primaryColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        icon,
                        size: 20,
                        color: isSelected ? Colors.white : _primaryColor,
                      ),
                    ),
                    SizedBox(width: 10),
                    // Text Column
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              color: isSelected ? Colors.white : _darkColor,
                              fontWeight: FontWeight.w900,
                              fontSize: _bodySize,
                              letterSpacing: 0.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            subtitle,
                            style: TextStyle(
                              color: isSelected ? Colors.white.withOpacity(0.8) : _greyColor,
                              fontSize: _captionSize * 0.9,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Icon(
                    Icons.check_circle,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
            ],
          ),
        ),
      ),
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

  Widget _buildPremiumQuartierDropdown() {
    final hasError = _getFieldError(1, 'quartier') != null;

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
                  'Quartier',
                  style: TextStyle(
                    fontSize: _bodySize,
                    fontWeight: FontWeight.w600,
                    color: hasError ? _errorColor : _darkColor,
                  ),
                ),
                Text(
                  '*',
                  style: TextStyle(
                    color: _errorColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Autocomplete<QuartierModel>(
            // Si on a déjà sélectionné un quartier, on l'affiche comme valeur initiale
            initialValue: TextEditingValue(text: _selectedQuartier?.name ?? ''),
            optionsBuilder: (TextEditingValue textEditingValue) {
              if (textEditingValue.text.isEmpty) {
                return _availableQuartiers;
              }
              return _availableQuartiers.where((QuartierModel option) {
                return (option.name ?? '')
                    .toLowerCase()
                    .contains(textEditingValue.text.toLowerCase());
              });
            },
            displayStringForOption: (QuartierModel option) => option.name ?? '',
            onSelected: (QuartierModel selection) {
              _markFieldTouched('quartier');
              _clickCount++;
              setState(() {
                _selectedQuartier = selection;
                _quartierTextController.text = selection.name ?? '';
                _removeFieldError(1, 'quartier');
                _validateStep1();
                _saveDraft();
              });
              _trackSelection('quartier', selection.name ?? 'unknown');
            },
            fieldViewBuilder: (BuildContext context,
                TextEditingController fieldTextEditingController,
                FocusNode fieldFocusNode,
                VoidCallback onFieldSubmitted) {
              
              // Synchroniser le controller interne avec notre controller global si besoin
              // (Surtout utile si on change de step et revient)
              if (_selectedQuartier != null && fieldTextEditingController.text.isEmpty) {
                 fieldTextEditingController.text = _selectedQuartier!.name ?? '';
              }

              return TextField(
                controller: fieldTextEditingController,
                focusNode: fieldFocusNode,
                style: TextStyle(
                  fontSize: _bodySize,
                  color: _darkColor,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText: 'Saisir ou sélectionner un quartier',
                  hintStyle: TextStyle(
                    fontSize: _bodySize,
                    color: Colors.grey.shade500,
                  ),
                  prefixIcon: Icon(
                    Icons.map_outlined,
                    color: hasError ? _errorColor : _primaryColor,
                    size: 20,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: hasError ? _errorColor : _borderColor,
                      width: hasError ? 1.5 : 1,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: hasError ? _errorColor : _borderColor,
                      width: hasError ? 1.5 : 1,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: hasError ? _errorColor : _primaryColor,
                      width: 2,
                    ),
                  ),
                ),
                onChanged: (String value) {
                   _markFieldTouched('quartier');
                   setState(() {
                     // Vérifier si la saisie correspond à un quartier existant
                     try {
                        final existing = _availableQuartiers.firstWhere(
                          (q) => (q.name ?? '').toLowerCase() == value.trim().toLowerCase()
                        );
                        _selectedQuartier = existing;
                     } catch (e) {
                        // Pas trouvé, on crée un modèle temporaire avec ID null
                        _selectedQuartier = QuartierModel(
                          quartierId: null,
                          name: value,
                        );
                     }
                     _quartierTextController.text = value;

                     if (value.isNotEmpty) {
                       _removeFieldError(1, 'quartier');
                     }
                     _validateStep1();
                   });
                },
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
                    _getFieldError(1, 'quartier')!,
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

  Widget _buildModernElectricDropdown() {
    return _buildPremiumDropdown<String>(
      label: 'Disponibilité du courant',
      value: _selectedElectric,
      items: _electricOptions.map((opt) => opt['value'] as String).toList(),
      displayText: (value) {
        final option = _electricOptions.isNotEmpty
            ? _electricOptions.firstWhere(
                (opt) => opt['value'] == value,
                orElse: () => _electricOptions[0],
              )
            : _electricOptions.isNotEmpty ? _electricOptions[0] : {'label': '', 'description': '', 'value': ''};
        return '${option['label']} - ${option['description']}';
      },
      onChanged: (String? newValue) {
        if (mounted) {
          _markFieldTouched('electric');
          _clickCount++;
          setState(() {
            _selectedElectric = newValue;
            _removeFieldError(2, 'electric');
            _validateStep2();
            _saveDraft();
          });
          _trackSelection('electric_service', newValue ?? 'none');
        }
      },
      icon: Icons.electrical_services_rounded,
      errorText: _getFieldError(2, 'electric'),
      hintText: 'Sélectionnez la disponibilité',
    );
  }

  Widget _buildModernWaterDropdown() {
    return _buildPremiumDropdown<String>(
      label: 'Disponibilité de l\'eau',
      value: _selectedWater,
      items: _waterOptions.map((opt) => opt['value'] as String).toList(),
      displayText: (value) {
        final option = _waterOptions.isNotEmpty
            ? _waterOptions.firstWhere(
                (opt) => opt['value'] == value,
                orElse: () => _waterOptions[0],
              )
            : _waterOptions.isNotEmpty ? _waterOptions[0] : {'label': '', 'description': '', 'value': ''};
        return '${option['label']} - ${option['description']}';
      },
      onChanged: (String? newValue) {
        if (mounted) {
          _markFieldTouched('water');
          _clickCount++;
          setState(() {
            _selectedWater = newValue;
            _removeFieldError(2, 'water');
            _validateStep2();
            _saveDraft();
          });
          _trackSelection('water_service', newValue ?? 'none');
        }
      },
      icon: Icons.water_drop_rounded,
      errorText: _getFieldError(2, 'water'),
      hintText: 'Sélectionnez la disponibilité',
    );
  }

  void _showPremiumQuartierDialog() {
    final TextEditingController customQuartierController = TextEditingController();
    final FocusNode focusNode = FocusNode();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 8,
        child: Container(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _accentColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.edit_rounded, color: _accentColor, size: 20),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Nom du quartier',
                      style: TextStyle(
                        fontSize: _subtitleSize,
                        fontWeight: FontWeight.w700,
                        color: _darkColor,
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(height: 20),

              Text(
                'Entrez le nom du quartier',
                style: TextStyle(
                  fontSize: _bodySize,
                  fontWeight: FontWeight.w600,
                  color: _darkColor,
                ),
              ),
              SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _borderColor),
                  color: _lightColor,
                ),
                child: TextField(
                  controller: customQuartierController,
                  focusNode: focusNode,
                  decoration: InputDecoration(
                    hintText: 'Ex: Quartier Matonge, Quartier Bandal...',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    hintStyle: TextStyle(color: _greyColor, fontSize: _bodySize),
                  ),
                  style: TextStyle(
                    fontSize: _bodySize,
                    color: _darkColor,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLength: 100,
                  onSubmitted: (value) {
                    _validateAndSaveCustomQuartier(value);
                    Navigator.pop(context);
                  },
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Minimum 2 caractères',
                style: TextStyle(
                  color: _greyColor,
                  fontSize: _captionSize,
                ),
              ),

              SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _greyColor,
                        side: BorderSide(color: _borderColor),
                        padding: EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text('Annuler', style: TextStyle(fontSize: _bodySize)),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        _validateAndSaveCustomQuartier(customQuartierController.text.trim());
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accentColor,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Text('Valider', style: TextStyle(fontSize: _bodySize)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ).then((_) {
      focusNode.dispose();
    });

    Future.delayed(Duration(milliseconds: 300), () {
      focusNode.requestFocus();
    });
  }

  void _validateAndSaveCustomQuartier(String quartierName) {
    if (quartierName.isNotEmpty && quartierName.length >= 2) {
      if (mounted) {
        setState(() {
          _selectedQuartier = QuartierModel(
            quartierId: null,
            name: quartierName,
          );
          _removeFieldError(1, 'quartier');
          _validateStep1();
          _saveDraft();
        });

        _trackEvent('custom_quartier_entered', {
          'quartier_name': quartierName,
          'commune': _selectedCommune?.name,
          'district': _selectedDistrict?.name,
          'city': _selectedCity?.name,
        });
      }
    } else {
      FancyNotification.show(
          context,
          'Veuillez saisir un nom de quartier valide (min 2 caractères)',
          isError: true
      );
    }
  }

  // =============================================
  // EXISTING METHODS FOR PROPERTY CREATION
  // =============================================

  Future<void> _handleCreatePropertyPost() async {
    print("🎯 DEBUT _handleCreatePropertyPost");

    // Marquer qu'on a tenté de soumettre - afficher toutes les erreurs maintenant
    _hasAttemptedSubmit = true;
    _clickCount++; // Track submit click

    await _trackEvent('property_creation_start', {
      'step': _currentStep,
      'total_images': _totalImagesCount,
      'property_type': _selectedCategory,
      'click_count': _clickCount,
    });

    if (!mounted || _isLoading) {
      return;
    }

    // Double check verification before proceeding
    final authCtrl = context.read<AuthentificationCtrl>();
    if (authCtrl.user.isCertified != true) {
      Navigator.push(
        context, 
        MaterialPageRoute(builder: (context) => IdentityVerificationPage())
      ).then((result) {
        // Si la vérification réussit, on peut revenir à la création de propriété
        if (result == true && mounted) {
          // L'utilisateur peut maintenant créer une propriété
        }
      });
      return;
    }

    setState(() {
      _autoValidateMode = AutovalidateMode.always;
    });

    await Future.delayed(Duration(milliseconds: 50));

    // Refaire la validation complète
    bool allStepsValid = _validateStep0() && _validateStep1() && _validateStep2();

    if (!allStepsValid) {
      int firstInvalidStep = 0;
      for (int i = 0; i < 3; i++) {
        if (!_stepValidations[i]!) {
          firstInvalidStep = i;
          break;
        }
      }

      if (mounted) {
        setState(() {
          _currentStep = firstInvalidStep;
        });
      }

      await _trackEvent('property_creation_validation_failed', {
        'failed_step': firstInvalidStep,
        'step_name': _getStepName(firstInvalidStep),
        'errors': _stepErrorMessages[firstInvalidStep],
      });

      _showStepErrorNotification(firstInvalidStep);
      return;
    }

    print("✅ Validation réussie, début du chargement...");

    if (mounted) {
      setState(() => _isLoading = true);
    }
    FocusScope.of(context).unfocus();

    final isConnected = await NetworkUtils.checkInternetConnectivity();
    if (!isConnected) {
      await _trackEvent('property_creation_network_error', {
        'step': _currentStep,
      });
      FancyNotification.show(context, "Pas de connexion internet");
      if (mounted) {
        setState(() => _isLoading = false);
      }
      return;
    }

    try {
      // Calculer les valeurs du quartier
      String quartierValue;
      String quartier;
      
      if (_isKinshasaSelected) {
        // Pour Kinshasa, utiliser le quartier sélectionné depuis l'API
        quartierValue = _selectedKinshasaQuartier?['name'] ?? 
                       _selectedQuartier?.name ?? 
                       (_addressController.text.split(',').isNotEmpty ? _addressController.text.split(',').last.trim() : "") ?? 
                       "Non spécifié";
        quartier = quartierValue;
      } else {
        // Pour autres villes, utiliser le champ texte
        quartierValue = _quartierTextController.text.trim().isNotEmpty 
            ? _quartierTextController.text.trim() 
            : (_addressController.text.split(',').isNotEmpty ? _addressController.text.split(',').last.trim() : "") ?? 
              "Non spécifié";
        quartier = quartierValue;
      }
      
      if (quartier.isEmpty) {
        quartier = "Non spécifié";
        quartierValue = quartier;
      }

      final authCtrl = context.read<AuthentificationCtrl>();
      final uId = authCtrl.user.userId ?? 0;
      final ctrl = context.read<PropertyController>();
      
      // Determine Type
      final typeName = _selectedCategory?.toLowerCase() ?? '';
      final isFestive = typeName.contains('fête') || typeName.contains('festive');
      final isFuneraire = typeName.contains('funéra') || typeName.contains('deuil');
      final isBureau = typeName.contains('bureau') || (_selectedPropertyTypeId == 4);
      final isVacances = typeName.contains('vacance');
      final isTerrain = typeName.contains('terrain');

      // Prepare Images (Base64)
      final imagesData = await _prepareImagesData();
      List<String> allImagesBase64 = [];
      
      // Collect all images for flat arrays if it's a Map structure
      if (imagesData is Map) {
         void addImages(String key) {
            if (imagesData[key] != null) {
              allImagesBase64.addAll(
                (imagesData[key] as List).map((e) {
                   String b64 = e['image'] as String;
                   // Nettoyage préventif
                   if (b64.contains(',')) {
                      b64 = b64.split(',').last; // Enlever data:image/png;base64,...
                   }
                   return b64.replaceAll(RegExp(r'\s+'), ''); // Enlever espaces/retours ligne
                }).toList()
              );
            }
         }
         addImages('propertyImage');
         addImages('propertyImageRoom');
         addImages('propertyImageLivingRoom');
         addImages('propertyImageKitchen');

      } else if (imagesData is List) {
         // For festive/funeraire types - already a List<String>
         allImagesBase64 = (imagesData as List).map((e) {
             String b64 = e.toString();
             if (b64.contains(',')) {
                b64 = b64.split(',').last;
             }
             return b64.replaceAll(RegExp(r'\s+'), '');
         }).toList();
      }

      HttpResponse res;

      // Common fields
      final String title = _titleController.text.trim();
      final String description = _descriptionController.text.trim().isNotEmpty ? _descriptionController.text.trim() : "Description";
      final double price = double.tryParse(_priceController.text) ?? 5000.0;
      final String address = _addressController.text.trim();
      final int electric = _selectedElectric != null ? (int.tryParse(_selectedElectric!) ?? 0) : 0;
      
      if (isFestive) {
        print("🎉 Création de Salle de Fête");
        final festiveData = {
          "festive": {
            "userId": uId,
            "deviseId": _selectedDeviseId,
            "title": title,
            "description": description,
            "usage": _selectedUsage ?? "Autre",
            "capacityPeople": int.tryParse(_capacityController.text) ?? 0,
            "electric": electric,
            "water": _selectedWater != null ? (int.tryParse(_selectedWater!) ?? 0) : 0,
            "price": price,
            "address": address,
            "transactionType": _isForRent ? "location" : "vente",
            "propertyTypeId": _selectedPropertyTypeId ?? 8,
            "cityId": _isKinshasaSelected && _selectedCity?.cityId != null ? _selectedCity!.cityId! : 0,
            "communeId": _isKinshasaSelected && _selectedCommune?.communeId != null ? _selectedCommune!.communeId! : 0,
            "quartierId": _isKinshasaSelected && _selectedQuartier?.quartierId != null ? _selectedQuartier!.quartierId! : 0,
            "cityValue": _isKinshasaSelected ? (_selectedCity?.name ?? 'Kinshasa') : (_cityTextController.text.trim().isNotEmpty ? _cityTextController.text.trim() : "Ville non spécifiée"),
            "communeValue": _isKinshasaSelected ? (_selectedCommune?.name ?? "") : (_communeTextController.text.trim().isNotEmpty ? _communeTextController.text.trim() : ""),
            "quartierValue": quartierValue,
            "postalCode": _postalCodeController.text.trim().isNotEmpty ? _postalCodeController.text.trim() : "243",
            "countryValue": "RDC",
            "latitude": _selectedLocation?.latitude ?? 0.1,
            "longitude": _selectedLocation?.longitude ?? 0.1,
            "isAvailable": true,
            "isActive": true,
            "isVerified": false,
            "isFeatured": false,
            "sold": false,
            "isDecore": _isDecore,
            "pisteDanse": _pisteDanse,
            "available": true,
            "decore": _isDecore
          },
          "images": allImagesBase64.map((b64) => {"image": b64}).toList(),
          "features": _selectedFeatureIds.map((id) => {"featureId": id}).toList()
        };
        res = await ctrl.createFestive(festiveData);

      } else if (isFuneraire) {
        print("⚰️ Création de Salle Funéraire");
        final funeraireData = {
          "funeraire": {
            "userId": uId,
            "deviseId": _selectedDeviseId,
            "title": title,
            "description": description,
            "capacityPeople": int.tryParse(_capacityController.text) ?? 0,
            "transactionType": _isForRent ? "location" : "vente",
            "propertyTypeId": _selectedPropertyTypeId ?? 7,
            "price": price,
            "address": address,
            "cityId": _isKinshasaSelected && _selectedCity?.cityId != null ? _selectedCity!.cityId! : 0,
            "communeId": _isKinshasaSelected && _selectedCommune?.communeId != null ? _selectedCommune!.communeId! : 0,
            "quartierId": _isKinshasaSelected && _selectedQuartier?.quartierId != null ? _selectedQuartier!.quartierId! : 0,
            "cityValue": _isKinshasaSelected ? (_selectedCity?.name ?? 'Kinshasa') : (_cityTextController.text.trim().isNotEmpty ? _cityTextController.text.trim() : "Ville non spécifiée"),
            "communeValue": _isKinshasaSelected ? (_selectedCommune?.name ?? "") : (_communeTextController.text.trim().isNotEmpty ? _communeTextController.text.trim() : ""),
            "quartierValue": quartierValue,
            "postalCode": _postalCodeController.text.trim().isNotEmpty ? _postalCodeController.text.trim() : "243",
            "countryValue": "RDC",
            "latitude": _selectedLocation?.latitude ?? 0.1,
            "longitude": _selectedLocation?.longitude ?? 0.1,
            "isAvailable": true,
            "available": true,
            "electric": electric,
            "water": _selectedWater != null ? (int.tryParse(_selectedWater!) ?? 0) : 0
          },
          "images": allImagesBase64.map((b64) => {"image": b64}).toList(),
          "features": _selectedFeatureIds.map((id) => {"featureId": id}).toList()
        };
        
        print("⚰️ PAYLOAD FUNERAIRE:");
        print("📦 Funeraire Data: ${jsonEncode(funeraireData)}");
        
        res = await ctrl.createFuneraire(funeraireData);

      } else if (isBureau) {
        print("💼 Création de Bureau");
        // Convert all base64 to Map list for Bureau
        List<Map<String, String>> imagesList = allImagesBase64.map((b64) => {"image": b64}).toList();

        final bureauData = {
          "bureau": {
            "userId": uId,
            "deviseId": _selectedDeviseId,
            "title": title,
            "description": description,
            "price": price,
            "transactionType": _isForRent ? "location" : "vente",
            "propertyTypeId": 4,
            "roomMeet": int.tryParse(_roomMeetController.text) ?? 0,
            "electric": electric,
            "water": _selectedWater != null ? (int.tryParse(_selectedWater!) ?? 0) : 0,
            "numberPiece": int.tryParse(_numberPieceController.text) ?? 0,
            "equip": _isEquip, // Corrected field name (was isEquip)
            "postalCode": _postalCodeController.text.trim().isNotEmpty ? _postalCodeController.text.trim() : "243",
            "cityId": _isKinshasaSelected && _selectedCity?.cityId != null ? _selectedCity!.cityId! : 0,
            "communeId": _isKinshasaSelected && _selectedCommune?.communeId != null ? _selectedCommune!.communeId! : 0,
            "quartierId": _isKinshasaSelected && _selectedQuartier?.quartierId != null ? _selectedQuartier!.quartierId! : 0,
            "cityValue": _isKinshasaSelected ? (_selectedCity?.name ?? 'Kinshasa') : (_cityTextController.text.trim().isNotEmpty ? _cityTextController.text.trim() : "Ville non spécifiée"),
            "communeValue": _isKinshasaSelected ? (_selectedCommune?.name ?? "") : (_communeTextController.text.trim().isNotEmpty ? _communeTextController.text.trim() : ""),
            "quartierValue": quartierValue,
            "countryValue": "RDC",
            "latitude": _selectedLocation?.latitude ?? 0.1,
            "longitude": _selectedLocation?.longitude ?? 0.1,
            "address": address,
            "available": true,
            "isAvailable": true,
            "sold": false
          },
          "images": imagesList,
          "features": _selectedFeatureIds.map((id) => {"featureId": id}).toList()
        };
        
        try {
           print("📦 ACTIVE PAYLOAD BUREAU: ${jsonEncode(bureauData)}");
        } catch(e) {
           print("❌ Error printing payload: $e");
        }
        res = await ctrl.createBureau(bureauData);

      } else if (isVacances) {
        print("🏖️ Création de Vacances");
        
        // Fetch Agence ID
        final agenceCtrl = context.read<AgenceController>();
        if (agenceCtrl.agences.isEmpty && uId != 0) {
            print("🔄 Récupération des agences pour l'utilisateur $uId...");
            await agenceCtrl.fetchAgencesByUser(uId);
        }
        print("📊 Nombre d'agences trouvées: ${agenceCtrl.agences.length}");
        if (agenceCtrl.agences.isNotEmpty) {
           print("🏢 Première agence: ID=${agenceCtrl.agences.first.id}, Nom=${agenceCtrl.agences.first.name}");
        }
        
        final agenceId = (agenceCtrl.agences.isNotEmpty) ? agenceCtrl.agences.first.id : 0; // Utiliser first.id car c'est un modèle AgenceModel qui contient id

        // Fallback safety if agenceId is 0 (should be caught by checkAgencyRequirement but just in case)
        if (agenceId == 0 || agenceId == null) {
            print("⚠️ Aucune agence trouvée pour l'utilisateur, impossible de créer Vacance");
            FancyNotification.show(
                context, 
                "Erreur: Compte Agence requis pour cette catégorie.", 
                isError: true
            );
            setState(() => _isLoading = false);
            return;
        }

        final vacancesData = {
           "agenceId": agenceId,
           "userId": uId,
           "title": title,
           "description": description,
           "note": _noteController.text,
           "dateVacance": _dateVacanceController.text,
           "heureVacance": _heureVacanceController.text,
           "price": price,
           "priceCombo": _selectedPriceCombo ?? "Par Nuit",
           "offre": _offreController.text,
           "capacity": int.tryParse(_capacityController.text) ?? 0,
           "address": address,
           "cityValue": _isKinshasaSelected ? (_selectedCity?.name ?? 'Kinshasa') : (_cityTextController.text.trim().isNotEmpty ? _cityTextController.text.trim() : "Ville non spécifiée"),
           "countryValue": "RDC",
           "isAvailable": true,
           "available": true,
           "images": allImagesBase64.map((b64) => {
             "name": b64
           }).toList()
        };
        
        print("🚀 Envoi de la création Vacance...");
        res = await ctrl.createVacance(vacancesData);
        print("🏁 Retour CreateVacance - Status: ${res.status}");
        print("📄 Data: ${res.data}");
        if (res.errorMsg != null) print("❌ ErrorMsg: ${res.errorMsg}");

      } else if (isTerrain) {
        print("🏞️ Création de Terrain (FLAT)");
        
        final terrainData = {
          "userId": uId,
          "title": title,
          "description": description,
          "deviseId": _selectedDeviseId ?? 1,
          "price": price,
          "surface": _areaController.text.trim().isNotEmpty ? _areaController.text.trim() : "0",
          "address": address,
          "communeValue": _isKinshasaSelected ? (_selectedCommune?.name ?? "") : (_communeTextController.text.trim().isNotEmpty ? _communeTextController.text.trim() : ""),
          "quartierValue": quartierValue,
          "cityValue": _isKinshasaSelected ? (_selectedCity?.name ?? "Kinshasa") : (_cityTextController.text.trim().isNotEmpty ? _cityTextController.text.trim() : "Ville non spécifiée"),
          "countryValue": "RDC",
          "cityId": _isKinshasaSelected && _selectedCity?.cityId != null ? _selectedCity!.cityId! : 0,
          "postalCode": _postalCodeController.text.trim().isNotEmpty ? _postalCodeController.text.trim() : "243",
          "communeId": _isKinshasaSelected && _selectedCommune?.communeId != null ? _selectedCommune!.communeId! : 0,
          "quartierId": _isKinshasaSelected && _selectedQuartier?.quartierId != null ? _selectedQuartier!.quartierId! : 0,
          "transactionType": _isForRent ? "Location" : "Vente",
          "propertyTypeId": _selectedPropertyTypeId,
          "isAvailable": true,
          "latitude": _selectedLocation?.latitude ?? 0.0,
          "longitude": _selectedLocation?.longitude ?? 0.0,
          "images": allImagesBase64.map((b64) => {"image": b64}).toList(),
          "available": true
        };
        
        print("🚀 Envoi de la création Terrain...");
        res = await ctrl.createTerrain(terrainData);
        print("🏁 Retour CreateTerrain - Status: ${res.status}");
        print("📄 Data: ${res.data}");
        if (res.errorMsg != null) print("❌ ErrorMsg: ${res.errorMsg}");



      } else if (isFuneraire) {
         Map<String, dynamic> localAddress = {};
         if (_isKinshasaSelected) {
            localAddress = {
              "city": {"cityId": _selectedCity?.cityId ?? 0, "name": _selectedCity?.name ?? ""},
              "commune": {
                "communeId": _selectedCommune?.communeId ?? 0, 
                "district": 0,
                "quartiers": [{"quartierId": _selectedQuartier?.quartierId ?? 0, "name": _selectedQuartier?.name ?? ""}],
                "name": _selectedCommune?.name ?? ""
              },
              "quartier": {"quartierId": _selectedQuartier?.quartierId ?? 0, "name": _selectedQuartier?.name ?? ""}
            };
         }

         final funeraireData = {
              "id": 0,
              "userId": uId,
              "deviseId": 1, 
              "title": title,
              "description": description,
              "capacityPeople": _capacityController.text,
              "transactionType": _isForRent ? "For Rent" : "For Sale",
              "propertyTypeId": _selectedPropertyTypeId,
              "price": price,
              "sold": false,
              "address": address,
              "communeValue": _isKinshasaSelected ? (_selectedCommune?.name ?? '') : _communeTextController.text,
              "quartierValue": _isKinshasaSelected ? (_selectedQuartier?.name ?? '') : _quartierTextController.text,
              "cityValue": _isKinshasaSelected ? (_selectedCity?.name ?? 'Kinshasa') : _cityTextController.text,
              "electric": _selectedElectric == 'Oui' ? 1 : 0,
              "water": _selectedWater == 'Oui' ? 1 : 0,
              "countryValue": "RDC",
              "cityId": _selectedCity?.cityId ?? 0,
              "postalCode": _postalCodeController.text.isNotEmpty ? _postalCodeController.text : "0000",
              "communeId": _selectedCommune?.communeId ?? 0,
              "quartierId": _selectedQuartier?.quartierId ?? 0,
              "latitude": 0.1,
              "longitude": 0.1,
              "isAvailable": true,
              "createdAt": DateTime.now().toIso8601String(),
              "updatedAt": DateTime.now().toIso8601String()
          };

          final payload = {
            "funeraire": funeraireData,
            "devise": {"id": 1, "name": "Dollars Américain", "code": "USD", "tauxLocal": 2800.0},
            "postBy": "owner",
            "images": allImagesBase64.map((b64) => {
              "id": 0,
              "salleFuneraireId": 0,
              "name": "image_${DateTime.now().millisecondsSinceEpoch}", 
              "path": b64, 
              "isAvailable": true, 
              "createdAt": DateTime.now().toIso8601String()
            }).toList(),
            "feature": _selectedAmenities.map((f) => {"featureId": 0, "name": f}).toList(),
            "address": {
               "address": address,
               "communeValue": funeraireData["communeValue"],
               "quartierValue": funeraireData["quartierValue"],
               "cityValue": funeraireData["cityValue"],
               "countryValue": "RDC",
               "postalCode": funeraireData["postalCode"]
            },
            "geoZone": {"lat": 0.1, "lng": 0.1},
            "localAddress": localAddress,
            "typeProperty": {"propertyTypeId": _selectedPropertyTypeId, "name": _selectedCategory}
          };
          
          print("⚰️ Envoi de la création Funeraire...");
          
          res = await ctrl.createFuneraire(payload);

      } else if (isBureau) {
        print("🏢 Création de Bureau");
        
        final bureauData = {
          "bureau": {
            "userId": uId,
            "deviseId": _selectedDeviseId ?? 1,
            "title": title,
            "description": description,
            "price": price,
            "transactionType": _isForRent ? "Location" : "Vente",
            "propertyTypeId": 4, // Bureau type ID
            "roomMeet": int.tryParse(_roomMeetController.text) ?? 0,
            "electric": electric,
            "water": _selectedWater != null ? (int.tryParse(_selectedWater!) ?? 0) : 0,
            "numberPiece": int.tryParse(_numberPieceController.text) ?? 0,
            "equip": _isEquip, // Renamed from isEquip to match GET response
            "postalCode": _postalCodeController.text.trim().isNotEmpty ? _postalCodeController.text.trim() : "243",
            "communeId": _isKinshasaSelected && _selectedCommune?.communeId != null ? _selectedCommune!.communeId! : 0,
            "isAvailable": true,
            "quartierId": _isKinshasaSelected && _selectedQuartier?.quartierId != null ? _selectedQuartier!.quartierId! : 0,
            "communeValue": _isKinshasaSelected ? (_selectedCommune?.name ?? "") : (_communeTextController.text.trim().isNotEmpty ? _communeTextController.text.trim() : ""),
            "quartierValue": quartierValue,
            "cityValue": _isKinshasaSelected ? (_selectedCity?.name ?? "Kinshasa") : (_cityTextController.text.trim().isNotEmpty ? _cityTextController.text.trim() : "Ville non spécifiée"),
            "countryValue": "RDC",
            "cityId": _isKinshasaSelected && _selectedCity?.cityId != null ? _selectedCity!.cityId! : 0,
            "latitude": _selectedLocation?.latitude ?? 0.0,
            "longitude": _selectedLocation?.longitude ?? 0.0,
            "address": address,
            "available": true,
            "sold": false
          },
          "images": allImagesBase64.map((b64) => {"image": b64}).toList(),
          // "feature": _selectedFeatureIds.map((id) => {"featureId": id}).toList(),
        };
        
        print("🚀 Envoi de la création Bureau...");
        try {
          print("DEBUG: isEquip=${_isEquip} (${_isEquip.runtimeType})");
          print("DEBUG: isAvailable=true");
          print("DEBUG: available=true");
          print("📦 PAYLOAD BUREAU: ${jsonEncode(bureauData)}");
        } catch (e) {
          print("❌ ERREUR LORS DU LOGGING DU PAYLOAD: $e");
        }
        
        res = await ctrl.createBureau(bureauData);
        print("🏁 Retour CreateBureau - Status: ${res.status}");
        print("📄 Data: ${res.data}");
        if (res.errorMsg != null) print("❌ ErrorMsg: ${res.errorMsg}");

      } else {
        print("🏠 Création Standard (Résidentiel/Autre)");
        
        // Get user's full name from storage
        final GetStorage storage = GetStorage();
        final dynamic userData = storage.read(StockageKeys.userKey);
        final dynamic profileData = storage.read(StockageKeys.profileKey);
        final String fullname = profileData?['fullName'] ??
                               profileData?['fullname'] ??
                               userData?['profile']?['fullName'] ??
                               userData?['profile']?['fullname'] ??
                               userData?['fullname'] ?? 
                               userData?['user']?['fullname'] ?? 
                               userData?['name'] ?? 
                               userData?['user']?['name'] ?? 
                               "Utilisateur";
        
        print("👤 PostBy: $fullname");
        
        // Standard code - FLAT STRUCTURE to match API expectations
        final propertyData = {
            "title": title,
            "description": description,
            "price": price,
            "deviseId": _selectedDeviseId ?? 1, // Default to 1 (usually USD or FC)
            "surface": double.tryParse(_areaController.text) ?? 0.0,
            "rooms": _calculateTotalRooms(),
            "bedrooms": int.tryParse(_bedroomsController.text) ?? 1,
            "kitchen": int.tryParse(_kitchensController.text) ?? 1,
            "livingRoom": int.tryParse(_livingRoomsController.text) ?? 1,
            "bathroom": int.tryParse(_bathroomsController.text) ?? 1,
            "floor": _hasFloor ? 1 : 0,
            "electric": electric,
            "water": _selectedWater != null ? int.tryParse(_selectedWater!) : 0,
            "guarantee": _guaranteeController.text.trim().isNotEmpty ? _guaranteeController.text.trim() : "0",
            "guarantee": _guaranteeController.text.trim().isNotEmpty ? _guaranteeController.text.trim() : "0",
            "sold": false, // Explicit boolean
            "isActive": true,
            "isVerified": false,
            "isFeatured": false,
            "isAvailable": true, // Add isAvailable for consistency
            "available": true,
            "transactionType": _isForRent ? "location" : "vente",
            "address": address,
            "cityId": _isKinshasaSelected && _selectedCity?.cityId != null ? _selectedCity!.cityId! : 0,
            "communeId": _isKinshasaSelected && _selectedCommune?.communeId != null ? _selectedCommune!.communeId! : 0,
            "quartierId": _isKinshasaSelected && _selectedQuartier?.quartierId != null ? _selectedQuartier!.quartierId! : 0,
            "cityValue": _isKinshasaSelected ? (_selectedCity?.name ?? 'Kinshasa') : (_cityTextController.text.trim().isNotEmpty ? _cityTextController.text.trim() : "Ville non spécifiée"),
            "communeValue": _isKinshasaSelected ? (_selectedCommune?.name ?? "") : (_communeTextController.text.trim().isNotEmpty ? _communeTextController.text.trim() : ""),
            "quartierValue": quartierValue,
            "postalCode": _postalCodeController.text.trim().isNotEmpty ? _postalCodeController.text.trim() : "243",
            "countryValue": "RDC",
            "quartier": quartierValue,
            "latitude": _selectedLocation?.latitude ?? 0.1,
            "longitude": _selectedLocation?.longitude ?? 0.1,
            "propertyTypeId": _selectedPropertyTypeId ?? 2,
            "userId": uId,
            "features": _selectedFeatureIds.map((id) => {"featureId": id}).toList(),
            "propertyImage": (imagesData is Map) ? (imagesData["propertyImage"] ?? []) : [],
            "propertyImageRoom": (imagesData is Map) ? (imagesData["propertyImageRoom"] ?? []) : [],
            "propertyImageLivingRoom": (imagesData is Map) ? (imagesData["propertyImageLivingRoom"] ?? []) : [],
            "propertyImageKitchen": (imagesData is Map) ? (imagesData["propertyImageKitchen"] ?? []) : []
        };
        
        // Log payload structure before sending
        print("📦 PAYLOAD STRUCTURE (FLAT):");
        print("  - Title: $title");
        print("  - Price: $price");
        print("  - Address: $address");
        print("  - CityId: ${propertyData['cityId']}");
        print("  - PropertyTypeId: ${propertyData['propertyTypeId']}");
        print("  - UserId: ${propertyData['userId']}");
        print("  - Features count: ${(propertyData['features'] as List).length}");
        print("  - Images propertyImage: ${(propertyData['propertyImage'] as List).length}");
        print("  - Images propertyImageRoom: ${(propertyData['propertyImageRoom'] as List).length}");
        print("  - Images propertyImageLivingRoom: ${(propertyData['propertyImageLivingRoom'] as List).length}");
        print("  - Images propertyImageKitchen: ${(propertyData['propertyImageKitchen'] as List).length}");

        res = await ctrl.createProperty(propertyData);
      }

      print("📡 Réponse API: ${res.status} - ${res.errorMsg}");
      print("📡 Réponse API data: ${res.data}");
      print("📡 Réponse API data type: ${res.data.runtimeType}");

      if (!mounted) return;

      if (res.status == true) {
         _clearDraft();
         
         await _trackEvent('property_creation_success', {
           'property_type': _selectedCategory,
         });

        FancyNotification.show(context, "Annonce publiée avec succès !", type: NotificationType.success);
        
        await Future.delayed(Duration(seconds: 1));
        if (mounted) {
           Navigator.pushNamedAndRemoveUntil(
            context,
            Routes.bottomPageRoute,
                (route) => false,
            arguments: {'shouldRefresh': true},
          );
        }
      } else {
        // Erreur API
        print("❌ API Error - Status: ${res.status}");
        print("❌ API Error - ErrorMsg: ${res.errorMsg}");
        print("❌ API Error - Data: ${res.data}");
        
        String errorMessage = "Une erreur est survenue lors de la publication";
        if (res.errorMsg != null && res.errorMsg!.isNotEmpty) {
          errorMessage = res.errorMsg!;
        } else if (res.data != null && res.data is Map) {
          errorMessage = res.data['detailMessage'] ?? res.data['message'] ?? res.data['error'] ?? "Erreur lors de la publication de l'annonce";
        }
        
        // Sanitize technical errors
        if (errorMessage.toLowerCase().contains("internal server error") || 
            errorMessage.toLowerCase().contains("socketexception") ||
            errorMessage.toLowerCase().contains("connection timed out") ||
            errorMessage.toLowerCase().contains("impossible de se connecter")) {
              errorMessage = "Connexion instable ou service indisponible. Veuillez réessayer.";
        }
        
        print("📢 Message d'erreur final: $errorMessage");
        FancyNotification.show(context, errorMessage, isError: true);
      }
    } catch (e, stackTrace) {
      _clearImageCache();
      print("❌ EXCEPTION lors de la publication: $e");
      print("❌ STACK TRACE: $stackTrace");
      print("❌ Exception Type: ${e.runtimeType}");
      
      String detailedError = "Erreur: $e";
      FancyNotification.show(context, detailedError, isError: true);
    } finally {
      _clearImageCache();
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _clearDraft() async {
    try {
      await _prefs.remove('property_draft');
      await _trackEvent('draft_cleared', {
        'reason': 'publication_success',
      });
    } catch (e) {

      print('❌ Erreur lors de la suppression du brouillon: $e');
    }
  }

  Future<dynamic> _prepareImagesData() async { // Return dynamic to allow Map or List
    print("🖼️ Début de la préparation des images...");
    
    final typeName = _selectedCategory?.toLowerCase() ?? '';
    // Pour Festive/Funeraire, on veut une liste plate d'images ou une structure simplifiée
    bool isFestiveOrFuneraire = typeName.contains('fête') || 
                               typeName.contains('festive') ||
                               typeName.contains('funéra') || 
                               typeName.contains('deuil');

    if (isFestiveOrFuneraire) {
         // Collecter toutes les images dans une seule liste pour ces types
         List<String> allImages = [];
         
         for (var category in _imageCategories) {
            final images = _selectedImages[category.id] ?? [];
            for (var image in images) {
               if (image.path.isNotEmpty) {
                  final file = File(image.path);
                  if (await file.exists()) {
                     final bytes = await file.readAsBytes();
                     allImages.add(base64Encode(bytes));
                  }
               }
            }
         }
         return allImages;
    }

    // Structure standard pour Property/Bureau
    Map<String, List<Map<String, String>>> imagesData = {};
    for (var category in _imageCategories) {
      final categoryImages = _selectedImages[category.id] ?? [];
      List<Map<String, String>> imageList = [];

      print("📸 Traitement catégorie ${category.id}: ${categoryImages.length} images");

      for (var image in categoryImages) {
        try {
          print("🔄 Conversion de l'image: ${image.name}");
          print("📁 Chemin de l'image: ${image.path}");

          // Vérifier si le fichier existe
          final file = File(image.path);
          if (await file.exists()) {
            final bytes = await file.readAsBytes();
            final base64String = base64Encode(bytes);

            print("✅ Image ${image.name} convertie (${base64String.length} caractères)");

            imageList.add({
              "image": base64String
            });
          } else {
            print("❌ Fichier introuvable: ${image.path}");
            // Essayer avec le chemin original si disponible
            try {
              final originalFile = File(image.path.replaceFirst('scaled_', ''));
              if (await originalFile.exists()) {
                final bytes = await originalFile.readAsBytes();
                final base64String = base64Encode(bytes);
                imageList.add({"image": base64String});
                print("✅ Image récupérée depuis le chemin original");
              }
            } catch (e) {
              print("❌ Impossible de récupérer l'image originale: $e");
            }
          }
        } catch (e) {
          print("❌ Erreur lors de la conversion de l'image ${image.name}: $e");
        }
      }

      print("🎯 Catégorie ${category.id}: ${imageList.length} images converties");

      // CORRECTION: Toujours inclure les tableaux, même vides
      switch (category.id) {
        case 'propertyImage':
          imagesData['propertyImage'] = imageList;
          break;
        case 'propertyImageRoom':
          imagesData['propertyImageRoom'] = imageList;
          break;
        case 'propertyImageLivingRoom':
          imagesData['propertyImageLivingRoom'] = imageList;
          break;
        case 'propertyImageKitchen':
          imagesData['propertyImageKitchen'] = imageList;
          break;
      }
    }

    print("🖼️ Préparation terminée. Total des données: ${imagesData.length} catégories");
    return imagesData;
  }

  int _getPropertyTypeId(String? category) {
    switch (category) {
      case 'Studio':
        return 1;
      case 'Apparts':
        return 2;
      case 'Maisons':
        return 3;
      case 'Bureau':
        return 4;
      case 'Hotels':
        return 5;
      case 'Vacances':
        return 6;
      default:
        return 1;
    }
  }

  int _getFeatureId(String amenity) {
    switch (amenity) {
      case 'WiFi':
        return 1;
      case 'Climatisation':
        return 2;
      case 'Chauffage':
        return 3;
      case 'Cuisine équipée':
        return 4;
      case 'Lave-linge':
        return 5;
      case 'Parking':
        return 6;
      case 'Ascenseur':
        return 7;
      case 'Piscine':
        return 8;
      case 'Jardin':
        return 9;
      case 'Terrasse':
        return 10;
      case 'Gym':
        return 11;
      case 'Sécurité':
        return 12;
      case 'Animaux acceptés':
        return 13;
      default:
        return 1;
    }
  }

  int _calculateTotalRooms() {
    int bedrooms = int.tryParse(_bedroomsController.text) ?? 0;
    int bathrooms = int.tryParse(_bathroomsController.text) ?? 0;
    int livingRooms = int.tryParse(_livingRoomsController.text) ?? 0;
    int kitchens = int.tryParse(_kitchensController.text) ?? 0;

    return bedrooms + bathrooms + livingRooms + kitchens;
  }
  
  // =============================================
  // LOAD PROPERTY TYPES AND FEATURES
  // =============================================
  
  Future<void> _loadPropertyTypesAndFeatures() async {
    if (!mounted) return;
    
    setState(() {
      _loadingTypes = true;
      _loadingFeatures = true;
    });

    try {
      final propertyCtrl = Provider.of<PropertyController>(context, listen: false);
      
      // Load property types
      final types = await propertyCtrl.getPropertyTypes();
      
      // Load features
      final features = await propertyCtrl.getFeatures();
      
      if (mounted) {
        setState(() {
          _propertyTypes = types;
          _features = features;
          _loadingTypes = false;
          _loadingFeatures = false;
        });
        
        print("✅ ${_propertyTypes.length} types et ${_features.length} caractéristiques chargés");
      }
    } catch (e) {
      print("❌ Erreur chargement types/features: $e");
      if (mounted) {
        setState(() {
          _loadingTypes = false;
          _loadingFeatures = false;
        });
      }
    }
  }
}

class ImageCategory {
  final String id;
  final String name;
  final IconData icon;
  final Color color;
  final String description;

  ImageCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.description,
  });
}