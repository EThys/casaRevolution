import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:casa/controllers/PropertyCtrl.dart';
import 'package:casa/controllers/LocationController.dart';
import 'package:casa/models/CityModel.dart';
import 'package:casa/models/CommuneModel.dart';
import 'package:casa/models/DistrictModel.dart';
import 'package:casa/models/QuartierModel.dart';
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
import '../utils/requetes.dart' show HttpResponse;

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
  final TextEditingController _floorController = TextEditingController();
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
  bool _isEquip = false; // Meublé ou non

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

  // Location variables
  CityModel? _selectedCity;
  DistrictModel? _selectedDistrict;
  CommuneModel? _selectedCommune;
  QuartierModel? _selectedQuartier;
  bool get _isKinshasaSelected =>
      (_selectedCity?.name?.toLowerCase().trim() ?? '') == 'kinshasa' ||
      (_cityTextController.text.toLowerCase().trim() == 'kinshasa');

  List<CityModel> _availableCities = [];
  List<DistrictModel> _availableDistricts = [];
  List<CommuneModel> _availableCommunes = [];
  List<QuartierModel> _availableQuartiers = [];

  // Validation errors storage - PAR ÉTAPE ET PAR CHAMP
  Map<String, String> _fieldErrors = {};
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

  @override
  void initState() {
    super.initState();
    _selectedElectric = null;
    _selectedWater = null;

    _bedroomsController.addListener(_updateTotalRooms);
    _bathroomsController.addListener(_updateTotalRooms);
    _livingRoomsController.addListener(_updateTotalRooms);
    _kitchensController.addListener(_updateTotalRooms);

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
      }
    });
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

  void _updateTotalRooms() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
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
    _floorController.dispose();
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
        'title': _titleController.text,
        'price': _priceController.text,
        'guarantee': _guaranteeController.text,
        'description': _descriptionController.text,
        'address': _addressController.text,
        'bedrooms': _bedroomsController.text,
        'selectedElectric': _selectedElectric,
        'selectedWater': _selectedWater,
        'bathrooms': _bathroomsController.text,
        'livingRooms': _livingRoomsController.text,
        'kitchens': _kitchensController.text,
        'area': _areaController.text,
        'floor': _floorController.text,
        'selectedAmenities': _selectedAmenities.toList(),
        'selectedCityId': _selectedCity?.cityId,
        'selectedDistrictId': _selectedDistrict?.districtId,
        'selectedCommuneId': _selectedCommune?.communeId,
        'selectedQuartierId': _selectedQuartier?.quartierId,
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
          _titleController.text = draft['title'] ?? '';
          _priceController.text = draft['price'] ?? '';
          _guaranteeController.text = draft['guarantee'] ?? '';
          _descriptionController.text = draft['description'] ?? '';
          _selectedElectric = draft['selectedElectric'];
          _selectedWater = draft['selectedWater'];
          _addressController.text = draft['address'] ?? '';
          _bedroomsController.text = draft['bedrooms'] ?? '';
          _bathroomsController.text = draft['bathrooms'] ?? '';
          _livingRoomsController.text = draft['livingRooms'] ?? '';
          _kitchensController.text = draft['kitchens'] ?? '';
          _areaController.text = draft['area'] ?? '';
          _floorController.text = draft['floor'] ?? '';
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
    if (isFestive || isFuneraire) {
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
      if (_selectedQuartier == null) _setFieldError(1, 'quartier', 'Quartier requis');
    } else {
      if (_cityTextController.text.trim().isEmpty) _setFieldError(1, 'city', 'Ville requise');
      if (_communeTextController.text.trim().isEmpty) _setFieldError(1, 'commune', 'Commune requise');
      if (_quartierTextController.text.trim().isEmpty) _setFieldError(1, 'quartier', 'Quartier requis');
    }

    // Address validation
    if (_addressController.text.trim().isEmpty) {
      _setFieldError(1, 'address', 'Adresse requise');
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

    // Validation des photos (Maintenant à l'étape 3 - index 2)
    final mainImages = _selectedImages['propertyImage'] ?? [];
    if (mainImages.length < 3) {
      errors.add('Au moins 3 photos principales sont requises');
      _setFieldError(2, 'photos', 'Min. 3 photos');
    }

    // Services essentiels
    if (_selectedElectric == null) {
      _setFieldError(2, 'electric', 'Courant requis');
    }
    if (_selectedWater == null) {
      _setFieldError(2, 'water', 'Eau requise');
    }

    final isValid = !_hasFieldErrors(2);
    final errorMessage = _hasFieldErrors(2) ? 'Veuillez compléter les champs obligatoires' : '';

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
            _validateStep0();
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
        _validateStep0();
        _saveDraft();
      });

      // Track suppression
      _trackImageAction('removed', categoryId, 1);
    }
  }

  int get _totalImagesCount {
    return _selectedImages.values.fold(0, (sum, images) => sum + (images?.length ?? 0));
  }

  // =============================================
  // WIDGETS HARMONISÉS
  // =============================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _lightColor,
      appBar: _buildAppBar(),
      body: WillPopScope(
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
              _buildBottomNavigation(),
            ],
          ),
        ),
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
              _buildStepLabel(0, 'Type & Photos'),
              _buildStepLabel(1, 'Détails'),
              _buildStepLabel(2, 'Équipements'),
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
          setState(() => _currentStep = stepIndex);
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
          _buildModernSectionHeader(
            title: 'Type de propriété',
            icon: Icons.category_rounded,
          ),
          SizedBox(height: _smallSpace),
          Text(
            'Sélectionnez la catégorie qui correspond le mieux à votre bien. Cette étape est cruciale pour la suite.',
            style: TextStyle(
              color: _greyColor,
              fontSize: _captionSize,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: _mediumSpace),
          _buildModernPropertyTypeGrid(),
          SizedBox(height: _largeSpace),
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

    final categories = _propertyTypes.map((type) {
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
    final categories = _propertyTypes.map((type) {
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
    final hasError = _getFieldError(0, 'photos') != null;

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
        subtitle: Text(
          'Chambres, cuisine, salon, salle de bain...',
          style: TextStyle(
            color: _greyColor,
            fontSize: _captionSize,
          ),
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
            label: _isForRent ? 'Prix mensuel' : 'Prix de vente',
            hint: _isForRent ? '1200' : '450000',
            icon: Icons.attach_money_rounded,
            keyboardType: TextInputType.number,
            suffixText: '${_isForRent ? '/mois' : '\$'}',
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

          if (_isForRent) ...[
            _buildModernTextField(
              controller: _guaranteeController,
              label: 'Garantie (mois)',
              hint: '2 (optionnel)',
              icon: Icons.security_rounded,
              keyboardType: TextInputType.number,
              suffixText: 'mois',
              prefixIconColor: Colors.orange,
              focusNode: _focusNodes[2],
              nextFocusNode: _focusNodes[3],
              errorText: _getFieldError(1, 'guarantee'),
              fieldKey: 'guarantee',
              validator: (value) {
                if (value != null && value.isNotEmpty && int.tryParse(value) == null) {
                  return 'Veuillez entrer un nombre valide';
                }
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
            // Dropdowns premium pour la localisation
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
                        displayText: (commune) => commune.name ?? '',
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
            _buildPremiumQuartierDropdown(),
            SizedBox(height: _mediumSpace), // Espace entre quartier et adresse
          ] else ...[
            // Mode hors Kinshasa : champs avec suggestions/autocomplete
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
            SizedBox(height: _mediumSpace), // Espace entre quartier et adresse
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

              if (isFestive) {
                return Column(
                  children: [
                    GridView.count(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      crossAxisSpacing: _smallSpace,
                      mainAxisSpacing: _smallSpace,
                      childAspectRatio: 3.2,
                      children: [
                        _buildModernFeatureInput(
                          controller: _capacityController,
                          label: 'Capacité (pers.)',
                          icon: Icons.groups_rounded,
                          color: Color(0xFFE11D48).withOpacity(0.1),
                          iconColor: Color(0xFFE11D48),
                        ),
                        _buildModernFeatureInput(
                          controller: _priceController, // On réutilise le prix ici si besoin ou autre
                          label: 'Prix/Jour', // Juste visuel, le vrai champ prix est plus haut
                          icon: Icons.monetization_on_rounded,
                          color: Colors.green.withOpacity(0.1),
                          iconColor: Colors.green,
                          readOnly: true, // Juste pour l'info
                        ),
                      ],
                    ),
                    SizedBox(height: _smallSpace),
                    // Dropdown Usage
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _borderColor),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedUsage,
                          hint: Text('Type d\'événement', style: TextStyle(fontSize: _bodySize)),
                          isExpanded: true,
                          items: ['Mariage', 'Conférence', 'Anniversaire', 'Concert', 'Autre']
                              .map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                          onChanged: (val) => setState(() => _selectedUsage = val),
                        ),
                      ),
                    ),
                    SizedBox(height: _smallSpace),
                    // Toggles
                    Row(
                      children: [
                        Expanded(child: _buildSwitchTile('Décoration incluse ?', _isDecore, (v) => setState(() => _isDecore = v))),
                        SizedBox(width: _smallSpace),
                        Expanded(child: _buildSwitchTile('Piste de danse ?', _pisteDanse, (v) => setState(() => _pisteDanse = v))),
                      ],
                    ),
                  ],
                );
              } else if (isFuneraire) {
                 return GridView.count(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      crossAxisSpacing: _smallSpace,
                      mainAxisSpacing: _smallSpace,
                      childAspectRatio: 3.2,
                      children: [
                        _buildModernFeatureInput(
                          controller: _capacityController,
                          label: 'Capacité (pers.)',
                          icon: Icons.groups_rounded,
                          color: Color(0xFF4B5563).withOpacity(0.1),
                          iconColor: Color(0xFF4B5563),
                        ),
                      ],
                    );
              } else if (isBureau) {
                 return Column(
                   children: [
                     GridView.count(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      crossAxisSpacing: _smallSpace,
                      mainAxisSpacing: _smallSpace,
                      childAspectRatio: 3.2,
                      children: [
                        _buildModernFeatureInput(
                          controller: _areaController,
                          label: 'Surface (m²)',
                          icon: FontAwesomeIcons.rulerCombined,
                          color: Color(0xFF0891B2).withOpacity(0.1),
                          iconColor: Color(0xFF0891B2),
                        ),
                        _buildModernFeatureInput(
                          controller: _floorController,
                          label: 'Étage',
                          icon: FontAwesomeIcons.building,
                          color: Color(0xFF7C3AED).withOpacity(0.1),
                          iconColor: Color(0xFF7C3AED),
                        ),
                        _buildModernFeatureInput(
                          controller: _roomMeetController,
                          label: 'Salles réunion',
                          icon: FontAwesomeIcons.handshake,
                          color: Color(0xFF6B46C1).withOpacity(0.1),
                          iconColor: Color(0xFF6B46C1),
                        ),
                        _buildModernFeatureInput(
                          controller: _numberPieceController,
                          label: 'Nbr. Pièces',
                          icon: FontAwesomeIcons.doorOpen,
                          color: Color(0xFFEA580C).withOpacity(0.1),
                          iconColor: Color(0xFFEA580C),
                        ),
                      ],
                    ),
                    SizedBox(height: _smallSpace),
                    _buildSwitchTile('Meublé ?', _isEquip, (v) => setState(() => _isEquip = v)),
                   ],
                 );
              } else if (isTerrain) {
                   return GridView.count(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      crossAxisSpacing: _smallSpace,
                      mainAxisSpacing: _smallSpace,
                      childAspectRatio: 3.2,
                      children: [
                        _buildModernFeatureInput(
                          controller: _areaController,
                          label: 'Surface (m²)',
                          icon: FontAwesomeIcons.rulerCombined,
                          color: Color(0xFF0891B2).withOpacity(0.1),
                          iconColor: Color(0xFF0891B2),
                        ),
                      ],
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
                    _buildModernFeatureInput(
                      controller: _floorController,
                      label: 'Étage',
                      icon: FontAwesomeIcons.building,
                      color: Color(0xFF7C3AED).withOpacity(0.1),
                      iconColor: Color(0xFF7C3AED),
                    ),
                  ],
                );
              }
            }
          ),
          SizedBox(height: _mediumSpace),
        ],
      ),
    );
  }

  Widget _buildStep3() {
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
          _buildAdditionalRoomsExpansion(),

          SizedBox(height: _mediumSpace),
          _buildModernImageCounter(),
          SizedBox(height: _largeSpace),
          
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

          _buildModernSectionHeader(
            title: 'Équipements (optionnels)',
            icon: Icons.emoji_objects_outlined,
          ),
          SizedBox(height: _smallSpace),
          Text(
            'Sélectionnez les équipements disponibles dans votre propriété',
            style: TextStyle(
              color: _greyColor,
              fontSize: _captionSize,
            ),
          ),
          SizedBox(height: _mediumSpace),
          
          // Show loading indicator while fetching features
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
        ],
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

    return Container(
      padding: EdgeInsets.all(_mediumSpace),
      decoration: BoxDecoration(
        color: _cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 16,
            offset: Offset(0, -4),
          )
        ],
      ),
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
                  ? (canPublish ? _handleCreatePropertyPost : null)
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

                if (currentStepValid && mounted) {
                  _endStepTracking(_currentStep, _getStepName(_currentStep), true);
                  setState(() => _currentStep++);
                  _startStepTracking(_currentStep, _getStepName(_currentStep));
                } else {
                  _showStepErrorNotification(_currentStep);
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
                shadowColor: Colors.transparent,
              ),
              child: _isLoading
                  ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: Colors.white,
                ),
              )
                  : Text(
                isLastStep ? 'Publier l\'annonce' : 'Continuer',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: _bodySize,
                ),
              ),
            ),
          ),
        ],
      ),
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
              _removeFieldError(1, 'city');
              _validateStep1();
              _saveDraft();
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
                _removeFieldError(1, 'city');
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
    required String? Function(String?) validator,
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
              // Marquer le champ comme touché
              if (fieldKey != null) {
                _markFieldTouched(fieldKey);
              }
              
              if (value.isNotEmpty) {
                switch (label) {
                  case 'Titre de l\'annonce':
                    _removeFieldError(1, 'title');
                    break;
                  case 'Prix mensuel':
                  case 'Prix de vente':
                    _removeFieldError(1, 'price');
                    break;
                  case 'Description détaillée':
                    _removeFieldError(1, 'description');
                    break;
                  case 'Adresse complète':
                    _removeFieldError(1, 'address');
                    break;
                }
              }
              _validateStep1();
              _saveDraft();
            },
            onTap: () {
              // Track click/interaction
              if (fieldKey != null) {
                _clickCount++;
                _markFieldTouched(fieldKey);
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
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      readOnly: readOnly,
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
        color: _darkColor,
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

          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasError ? _errorColor :
                _selectedQuartier != null ? _primaryColor.withOpacity(0.3) : _borderColor,
                width: hasError ? 1.5 : 1,
              ),
              color: Colors.white,
              boxShadow: [
                if (_selectedQuartier != null)
                  BoxShadow(
                    color: _primaryColor.withOpacity(0.05),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: DropdownButtonHideUnderline(
                child: DropdownButton<QuartierModel>(
                  value: _selectedQuartier,
                  isExpanded: true,
                  items: [
                    DropdownMenuItem<QuartierModel>(
                      value: QuartierModel(quartierId: -1, name: "Saisir manuellement..."),
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: _borderColor.withOpacity(0.3),
                              width: 0.5,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.edit_rounded, size: 18, color: _accentColor),
                            SizedBox(width: 12),
                            Text(
                              "Saisir manuellement...",
                              style: TextStyle(
                                fontSize: _bodySize,
                                color: _accentColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    DropdownMenuItem<QuartierModel>(
                      value: null,
                      enabled: false,
                      child: Container(
                        height: 1,
                        margin: EdgeInsets.symmetric(horizontal: 8),
                        color: _borderColor,
                      ),
                    ),
                    ..._availableQuartiers.map((QuartierModel quartier) {
                      return DropdownMenuItem<QuartierModel>(
                        value: quartier,
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: _borderColor.withOpacity(0.3),
                                width: 0.5,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  quartier.name ?? "Quartier non spécifié",
                                  style: TextStyle(
                                    fontSize: _bodySize,
                                    color: _darkColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (_selectedQuartier?.quartierId == quartier.quartierId)
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
                  onChanged: (QuartierModel? newValue) {
                    if (mounted) {
                      _markFieldTouched('quartier');
                      _clickCount++;
                      setState(() {
                        if (newValue?.quartierId == -1) {
                          _showPremiumQuartierDialog();
                        } else {
                          _selectedQuartier = newValue;
                          _removeFieldError(1, 'quartier');
                          _validateStep1();
                          _saveDraft();
                          _trackSelection('quartier', newValue?.name ?? 'unknown');
                        }
                      });
                    }
                  },
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
          ),

          if (_selectedQuartier != null && _selectedQuartier!.quartierId == null)
            Container(
              margin: EdgeInsets.only(top: 8),
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _accentColor.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _accentColor.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.edit_rounded, size: 16, color: _accentColor),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Quartier saisi: ${_selectedQuartier!.name}',
                      style: TextStyle(
                        color: _accentColor,
                        fontSize: _captionSize,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      if (mounted) {
                        setState(() {
                          _selectedQuartier = null;
                          _validateStep1();
                          _saveDraft();
                        });
                      }
                    },
                    child: Icon(Icons.close_rounded, size: 16, color: _accentColor),
                  ),
                ],
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
        quartierValue = _selectedQuartier?.name ?? 
                       (_addressController.text.split(',').isNotEmpty ? _addressController.text.split(',').last.trim() : "") ?? 
                       "Non spécifié";
        quartier = quartierValue;
      } else {
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

      final GetStorage storage = GetStorage();
      final dynamic userData = storage.read(StockageKeys.userKey);
      final userId = userData?['userId'] ?? userData?['user']?['userId'];
      final uId = userId != null ? (userId is int ? userId : int.tryParse(userId.toString()) ?? 0) : 0;
      final ctrl = context.read<PropertyController>();
      
      // Determine Type
      final typeName = _selectedCategory?.toLowerCase() ?? '';
      final isFestive = typeName.contains('fête') || typeName.contains('festive');
      final isFuneraire = typeName.contains('funéra') || typeName.contains('deuil');
      final isBureau = typeName.contains('bureau') || (_selectedPropertyTypeId == 4);

      // Prepare Images (Base64)
      final imagesData = await _prepareImagesData();
      List<String> allImagesBase64 = [];
      
      // Collect all images for flat arrays
      if (imagesData['propertyImage'] != null) allImagesBase64.addAll(imagesData['propertyImage']!.map((e) => e['base64']!).toList());
      if (imagesData['propertyImageRoom'] != null) allImagesBase64.addAll(imagesData['propertyImageRoom']!.map((e) => e['base64']!).toList());
      if (imagesData['propertyImageLivingRoom'] != null) allImagesBase64.addAll(imagesData['propertyImageLivingRoom']!.map((e) => e['base64']!).toList());
      if (imagesData['propertyImageKitchen'] != null) allImagesBase64.addAll(imagesData['propertyImageKitchen']!.map((e) => e['base64']!).toList());

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
          "userId": uId,
          "deviseId": 1, 
          "title": title,
          "description": description,
          "usage": _selectedUsage ?? "Autre",
          "capacityPeople": int.tryParse(_capacityController.text) ?? 0,
          "electric": electric,
          "price": price,
          "address": address,
          "latitude": _selectedLocation?.latitude ?? 0.0,
          "longitude": _selectedLocation?.longitude ?? 0.0,
          "isAvailable": true,
          "isDecore": _isDecore,
          "pisteDanse": _pisteDanse,
          "images": allImagesBase64
        };
        res = await ctrl.createFestive(festiveData);

      } else if (isFuneraire) {
        print("⚰️ Création de Salle Funéraire");
        final funeraireData = {
          "userId": uId,
          "deviseId": 1,
          "title": title,
          "description": description,
          "capacityPeople": int.tryParse(_capacityController.text) ?? 0,
          "price": price,
          "address": address,
          "latitude": _selectedLocation?.latitude ?? 0.0,
          "longitude": _selectedLocation?.longitude ?? 0.0,
          "isAvailable": true,
          "images": allImagesBase64
        };
        res = await ctrl.createFuneraire(funeraireData);

      } else if (isBureau) {
        print("💼 Création de Bureau");
        // Re-construct Map list for Bureau
        List<Map<String, String>> allImagesMaps = [];
        if (imagesData['propertyImage'] != null) allImagesMaps.addAll(List<Map<String, String>>.from(imagesData['propertyImage']!));
        if (imagesData['propertyImageRoom'] != null) allImagesMaps.addAll(List<Map<String, String>>.from(imagesData['propertyImageRoom']!));

        final bureauData = {
          "bureau": {
            "userId": uId,
            "deviseId": 0,
            "title": title,
            "description": description,
            "price": price,
            "roomMeet": int.tryParse(_roomMeetController.text) ?? 0,
            "numberPiece": int.tryParse(_numberPieceController.text) ?? 0,
            "isEquip": _isEquip,
            "address": address
          },
          "images": allImagesMaps
        };
        res = await ctrl.createBureau(bureauData);

      } else {
        print("🏠 Création Standard (Résidentiel/Autre)");
        // Standard code...
        final propertyData = {
            "property": {
              "title": title,
              "description": description,
              "price": price,
              "surface": double.tryParse(_areaController.text) ?? 0.1,
              "rooms": _calculateTotalRooms(),
              "bedrooms": int.tryParse(_bedroomsController.text) ?? 1,
              "kitchen": int.tryParse(_kitchensController.text) ?? 1,
              "livingRoom": int.tryParse(_livingRoomsController.text) ?? 1,
              "bathroom": int.tryParse(_bathroomsController.text) ?? 1,
              "floor": int.tryParse(_floorController.text) ?? 1,
              "electric": electric,
              "water": _selectedWater != null ? int.tryParse(_selectedWater!) : 0,
              "guarantee": _guaranteeController.text.trim().isNotEmpty ? _guaranteeController.text.trim() : "0",
              "sold": false,
              "transactionType": _isForRent ? "location" : "vente",
              "available": true,
            },
            "postBy": fullname,
            "address": {
              "address": address,
              "cityId": _isKinshasaSelected && _selectedCity?.cityId != null ? _selectedCity!.cityId! : "",
              "communeId": _isKinshasaSelected && _selectedCommune?.communeId != null ? _selectedCommune!.communeId! : "",
              "quartierId": _isKinshasaSelected && _selectedQuartier?.quartierId != null ? _selectedQuartier!.quartierId! : "",
              "cityValue": _isKinshasaSelected ? (_selectedCity?.name ?? 'Kinshasa') : (_cityTextController.text.trim().isNotEmpty ? _cityTextController.text.trim() : "Ville non spécifiée"),
              "communeValue": _isKinshasaSelected ? (_selectedCommune?.name ?? "") : (_communeTextController.text.trim().isNotEmpty ? _communeTextController.text.trim() : ""),
              "quartierValue": quartierValue,
              "postalCode": _postalCodeController.text.trim().isNotEmpty ? _postalCodeController.text.trim() : "243",
              "countryValue": "RDC",
            },
            "geoZone": {
              "lat": _selectedLocation?.latitude ?? 0.1,
              "lng": _selectedLocation?.longitude ?? 0.1,
            },
            "typeProperty": {
              "propertyTypeId": _selectedPropertyTypeId ?? 2,
            },
            "features": _selectedFeatureIds.map((id) => {"featureId": id}).toList(),
            "images": {
               "main": imagesData["propertyImage"] ?? [],
               "room": imagesData["propertyImageRoom"] ?? [],
               "living": imagesData["propertyImageLivingRoom"] ?? [],
               "kitchen": imagesData["propertyImageKitchen"] ?? []
            }
        };
        
        if (userId != null) {
            (propertyData["property"] as Map<String, dynamic>)["userId"] = uId;
        }

        res = await ctrl.createProperty(propertyData);
      }

      print("📡 Réponse API: ${res.status} - ${res.errorMsg}");

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
          );
        }
      } else {
        // Erreur API
        String errorMessage = "Une erreur est survenue lors de la publication";
        if (res.errorMsg != null && res.errorMsg!.isNotEmpty) {
          errorMessage = res.errorMsg!;
        } else if (res.data != null && res.data is Map) {
          errorMessage = res.data['detailMessage'] ?? res.data['message'] ?? res.data['error'] ?? "Erreur lors de la publication de l'annonce";
        }
        
        FancyNotification.show(context, errorMessage, isError: true);
      }
    } catch (e) {
      _clearImageCache();
      print("❌ Erreur lors de la publication: $e");
      FancyNotification.show(context, "Une erreur est survenue. Veuillez réessayer.", isError: true);
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