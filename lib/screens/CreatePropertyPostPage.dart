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
// Firebase imports
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_performance/firebase_performance.dart';

import '../utils/StockageKeys.dart';

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

  // State variables
  bool _isForRent = true;
  bool _isLoading = false;
  Set<String> _selectedAmenities = {};
  LatLng? _selectedLocation;
  final ImagePicker _picker = ImagePicker();
  int _currentStep = 0;

  String? _selectedCategory;
  String? _selectedElectric = null;
  String? _selectedWater = null;
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
  late var fullname = profile["fullname"];
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

    // Setup focus node listeners
    _setupFocusNodes();

    // Initialiser SharedPreferences et charger les données
    _initSharedPreferences();

    // Démarrer le tracking Firebase
    _startPageTracking();
  }

  // =============================================
  // FIREBASE ANALYTICS METHODS
  // =============================================

  void _startPageTracking() {
    _pageStartTime = DateTime.now();
    _trackEvent('page_view', {
      'page_name': 'create_property',
      'timestamp': _pageStartTime!.millisecondsSinceEpoch,
    });
    _trackPageView('create_property_page');
  }

  void _endPageTracking() {
    if (_pageStartTime != null) {
      final duration = DateTime.now().difference(_pageStartTime!);
      _trackEvent('page_exit', {
        'page_name': 'create_property',
        'duration_seconds': duration.inSeconds,
        'steps_completed': _currentStep,
        'total_images': _totalImagesCount,
        'property_type': _selectedCategory ?? 'none',
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

  Future<void> _trackValidationError(int step, String field, String error) async {
    await _trackEvent('validation_error', {
      'step_number': step,
      'step_name': _getStepName(step),
      'field': field,
      'error': error,
      'total_images': _totalImagesCount,
    });
  }

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

  void _setFieldError(int step, String field, String error) {
    if (!_stepFieldErrors.containsKey(step)) {
      _stepFieldErrors[step] = {};
    }
    _stepFieldErrors[step]![field] = error;

    _trackValidationError(step, field, error);
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
  void dispose() {
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
        'totalImagesCount': _totalImagesCount,
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
        final city = _availableCities.firstWhere(
              (city) => city.cityId == cityId,
          orElse: () => _availableCities.first,
        );

        setState(() {
          _selectedCity = city;
          _updateDistrictsForCity();

          if (districtId != null && _availableDistricts.isNotEmpty) {
            try {
              final district = _availableDistricts.firstWhere(
                    (district) => district.districtId == districtId,
                orElse: () => _availableDistricts.first,
              );
              _selectedDistrict = district;
              _updateCommunesForDistrict();

              if (communeId != null && _availableCommunes.isNotEmpty) {
                try {
                  final commune = _availableCommunes.firstWhere(
                        (commune) => commune.communeId == communeId,
                    orElse: () => _availableCommunes.first,
                  );
                  _selectedCommune = commune;
                  _updateQuartiersForCommune();

                  if (quartierId != null && _availableQuartiers.isNotEmpty) {
                    try {
                      final quartier = _availableQuartiers.firstWhere(
                            (quartier) => quartier.quartierId == quartierId,
                        orElse: () => _availableQuartiers.first,
                      );
                      _selectedQuartier = quartier;
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

    // Validation du type de propriété
    if (_selectedCategory == null) {
      errors.add('Veuillez sélectionner un type de propriété');
      _setFieldError(0, 'property_type', 'Type de propriété requis');
    }

    // Validation des photos principales seulement
    final mainImages = _selectedImages['propertyImage'] ?? [];
    if (mainImages.length < 3) {
      errors.add('Au moins 3 photos principales sont requises');
      _setFieldError(0, 'photos', 'Minimum 3 photos principales requises');
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

    // Title validation
    if (_titleController.text.trim().isEmpty) {
      _setFieldError(1, 'title', 'Veuillez entrer un titre');
    } else if (_titleController.text.trim().length < 10) {
      _setFieldError(1, 'title', 'Titre trop court (min 10 caractères)');
    }

    // Price validation
    if (_priceController.text.trim().isEmpty) {
      _setFieldError(1, 'price', 'Veuillez entrer un prix');
    } else if (double.tryParse(_priceController.text) == null) {
      _setFieldError(1, 'price', 'Veuillez entrer un nombre valide');
    }

    // Description validation
    if (_descriptionController.text.trim().isEmpty) {
      _setFieldError(1, 'description', 'Veuillez entrer une description');
    } else if (_descriptionController.text.trim().length < 50) {
      _setFieldError(1, 'description', 'Description trop courte (min 50 caractères)');
    }

    // Location validation
    if (_selectedCity == null) {
      _setFieldError(1, 'city', 'Veuillez sélectionner une ville');
    }
    if (_selectedDistrict == null) {
      _setFieldError(1, 'district', 'Veuillez sélectionner un district');
    }
    if (_selectedCommune == null) {
      _setFieldError(1, 'commune', 'Veuillez sélectionner une commune');
    }

    if (_selectedQuartier == null || _selectedQuartier!.name == null || _selectedQuartier!.name!.isEmpty) {
      _setFieldError(1, 'quartier', 'Veuillez sélectionner ou saisir un quartier');
    }

    // Address validation
    if (_addressController.text.trim().isEmpty) {
      _setFieldError(1, 'address', 'Veuillez entrer une adresse');
    } else if (_addressController.text.length < 10) {
      _setFieldError(1, 'address', 'Adresse trop courte (${_addressController.text.length}/10)');
    }

    // Guarantee validation (only for rent)
    if (_isForRent && _guaranteeController.text.isNotEmpty && int.tryParse(_guaranteeController.text) == null) {
      _setFieldError(1, 'guarantee', 'Veuillez entrer un nombre valide');
    }

    final isValid = !_hasFieldErrors(1);
    final errorMessage = _hasFieldErrors(1) ? 'Veuillez corriger les erreurs ci-dessus' : '';

    setState(() {
      _stepValidations[1] = isValid;
      _stepErrorMessages[1] = errorMessage;
    });

    return isValid;
  }

  bool _validateStep2() {
    _clearStepFieldErrors(2);
    final errors = <String>[];

    // Services essentiels maintenant OBLIGATOIRES
    if (_selectedElectric == null) {
      _setFieldError(2, 'electric', 'Veuillez sélectionner la disponibilité du courant');
    }
    if (_selectedWater == null) {
      _setFieldError(2, 'water', 'Veuillez sélectionner la disponibilité de l\'eau');
    }

    final isValid = !_hasFieldErrors(2);
    final errorMessage = _hasFieldErrors(2) ? 'Veuillez sélectionner les services essentiels' : '';

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
      physics: BouncingScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: _mediumSpace, vertical: _mediumSpace),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Type d'annonce
          _buildModernSectionHeader(
            title: 'Type d\'annonce',
            icon: Icons.business_center_rounded,
          ),
          SizedBox(height: _mediumSpace),

          Container(
            padding: EdgeInsets.all(_mediumSpace),
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
              border: Border.all(color: _borderColor.withOpacity(0.5)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildModernTypeOption(
                    'À louer',
                    Icons.home_work_outlined,
                    'Location à durée déterminée',
                    _isForRent,
                        () {
                      if (mounted) {
                        setState(() {
                          _isForRent = true;
                          _saveDraft();
                        });
                        _trackSelection('transaction_type', 'location');
                      }
                    },
                  ),
                ),
                SizedBox(width: _smallSpace),
                Expanded(
                  child: _buildModernTypeOption(
                    'À vendre',
                    Icons.sell_outlined,
                    'Achat définitif',
                    !_isForRent,
                        () {
                      if (mounted) {
                        setState(() {
                          _isForRent = false;
                          _saveDraft();
                        });
                        _trackSelection('transaction_type', 'sale');
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: _largeSpace),

          // Type de propriété
          _buildModernSectionHeader(
            title: 'Type de propriété',
            icon: Icons.category_rounded,
          ),
          SizedBox(height: _smallSpace),
          Text(
            'Sélectionnez la catégorie qui correspond le mieux à votre bien',
            style: TextStyle(
              color: _greyColor,
              fontSize: _captionSize,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: _mediumSpace),
          _buildModernPropertyCategoryCarousel(),

          // Photos principales
          SizedBox(height: _largeSpace),
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

          // Photos principales
          _buildMainImagesCard(),

          // Autres pièces
          SizedBox(height: _mediumSpace),
          _buildAdditionalRoomsExpansion(),

          // Compteur total
          SizedBox(height: _mediumSpace),
          _buildModernImageCounter(),
          SizedBox(height: _mediumSpace),
        ],
      ),
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
    final categories = [
      {
        'image': 'assets/images/studio.png',
        'label': 'Studios',
        'value': 'Studio',
        'color': _primaryColor,
        'icon': Icons.apartment_rounded,
      },
      {
        'image': 'assets/images/apart.png',
        'label': 'Apparts',
        'value': 'Apparts',
        'color': _primaryColor,
        'icon': Icons.home_work_rounded,
      },
      {
        'image': 'assets/images/maisons.png',
        'label': 'Maisons',
        'value': 'Maisons',
        'color': _primaryColor,
        'icon': Icons.house_rounded,
      },
      {
        'image': 'assets/images/office.png',
        'label': 'Bureaux',
        'value': 'Bureau',
        'color': _primaryColor,
        'icon': Icons.business_center_rounded,
      },
      {
        'image': 'assets/images/hotel.png',
        'label': 'Hotels',
        'value': 'Hotels',
        'color': _primaryColor,
        'icon': Icons.hotel_rounded,
      },
      {
        'image': 'assets/images/plage.png',
        'label': 'Vacances',
        'value': 'Vacances',
        'color': _primaryColor,
        'icon': Icons.beach_access_rounded,
      },
    ];

    return Container(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 4),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = _selectedCategory == category['value'];
          final categoryColor = category['color'] as Color;

          return GestureDetector(
            onTap: () {
              if (mounted) {
                setState(() {
                  _selectedCategory = category['value'] as String;
                  _removeFieldError(0, 'property_type');
                  _validateStep0();
                  _saveDraft();
                });
                _trackSelection('property_type', category['value'] as String);
              }
            },
            child: Container(
              width: 100,
              margin: EdgeInsets.symmetric(horizontal: 6),
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
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
                                  size: 32,
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
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Veuillez entrer une description';
              }
              if (value.length < 50) {
                return 'La description doit faire au moins 50 caractères (${value.length}/50)';
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

          // Dropdowns premium pour la localisation
          _buildPremiumDropdown<CityModel>(
            label: 'Ville',
            value: _selectedCity,
            items: _availableCities,
            displayText: (city) => city.name ?? '',
            onChanged: (CityModel? newValue) {
              if (mounted) {
                setState(() {
                  _selectedCity = newValue;
                  _removeFieldError(1, 'city');
                  _updateDistrictsForCity();
                  _validateStep1();
                  _saveDraft();
                });
                _trackSelection('city', newValue?.name ?? 'unknown');
              }
            },
            icon: Icons.location_city_rounded,
            errorText: _getFieldError(1, 'city'),
            hintText: 'Sélectionnez une ville',
          ),

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

          _buildModernTextField(
            controller: _addressController,
            label: 'Adresse complète',
            hint: 'Numéro, rue, avenue...',
            icon: Icons.home_work_rounded,
            focusNode: _focusNodes[4],
            nextFocusNode: null,
            errorText: _getFieldError(1, 'address'),
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

          GridView.count(
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
                color: _primaryColor.withOpacity(0.1),
                iconColor: _primaryColor,
              ),
              _buildModernFeatureInput(
                controller: _bathroomsController,
                label: 'Salles de bain',
                icon: FontAwesomeIcons.bath,
                color: _primaryColor.withOpacity(0.1),
                iconColor: _primaryColor,
              ),
              _buildModernFeatureInput(
                controller: _livingRoomsController,
                label: 'Salons',
                icon: FontAwesomeIcons.couch,
                color: _primaryColor.withOpacity(0.1),
                iconColor: _primaryColor,
              ),
              _buildModernFeatureInput(
                controller: _kitchensController,
                label: 'Cuisines',
                icon: FontAwesomeIcons.kitchenSet,
                color: _primaryColor.withOpacity(0.1),
                iconColor: _primaryColor,
              ),
              _buildModernFeatureInput(
                controller: _areaController,
                label: 'Surface (m²)',
                icon: FontAwesomeIcons.rulerCombined,
                color: _primaryColor.withOpacity(0.1),
                iconColor: _primaryColor,
              ),
              _buildModernFeatureInput(
                controller: _floorController,
                label: 'Étage',
                icon: FontAwesomeIcons.building,
                color: _primaryColor.withOpacity(0.1),
                iconColor: _primaryColor,
              ),
            ],
          ),
          SizedBox(height: _mediumSpace),
        ],
      ),
    );
  }

  Widget _buildStep3() {
    return SingleChildScrollView(
      physics: BouncingScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: _mediumSpace, vertical: _mediumSpace),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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

          Container(
            margin: EdgeInsets.only(top: _mediumSpace),
            padding: EdgeInsets.all(_smallSpace),
            decoration: BoxDecoration(
              color: _infoColor.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _infoColor.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: _infoColor, size: 16),
                SizedBox(width: _smallSpace),
                Expanded(
                  child: Text(
                    'Les services essentiels sont obligatoires pour compléter votre annonce.',
                    style: TextStyle(
                      color: _infoColor,
                      fontSize: _captionSize,
                    ),
                  ),
                ),
              ],
            ),
          ),

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
          Wrap(
            spacing: _smallSpace,
            runSpacing: _smallSpace,
            children: _amenitiesList.map((amenity) {
              final isSelected = _selectedAmenities.contains(amenity);
              return ChoiceChip(
                label: Text(
                  amenity,
                  style: TextStyle(fontSize: _captionSize),
                ),
                selected: isSelected,
                onSelected: (selected) {
                  if (mounted) {
                    setState(() {
                      if (selected) {
                        _selectedAmenities.add(amenity);
                      } else {
                        _selectedAmenities.remove(amenity);
                      }
                      _validateStep2();
                      _saveDraft();
                    });
                    _trackSelection('amenity', amenity);
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
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: color.withOpacity(0.3),
        border: Border.all(color: color.withOpacity(0.5), width: 1),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: TextInputType.number,
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
          prefixIcon: Icon(icon, color: iconColor, size: 18),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          floatingLabelBehavior: FloatingLabelBehavior.never,
          filled: false,
        ),
        style: TextStyle(
          fontSize: _bodySize,
          fontWeight: FontWeight.w500,
          color: Colors.grey.shade800,
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
        final option = _electricOptions.firstWhere(
              (opt) => opt['value'] == value,
          orElse: () => _electricOptions[0],
        );
        return '${option['label']} - ${option['description']}';
      },
      onChanged: (String? newValue) {
        if (mounted) {
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
        final option = _waterOptions.firstWhere(
              (opt) => opt['value'] == value,
          orElse: () => _waterOptions[0],
        );
        return '${option['label']} - ${option['description']}';
      },
      onChanged: (String? newValue) {
        if (mounted) {
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
    final GetStorage storage = GetStorage();
    late final dynamic userData = storage.read(StockageKeys.userKey);
    late var userId = userData["userId"];

    print("🎯 DEBUT _handleCreatePropertyPost");

    await _trackEvent('property_creation_start', {
      'step': _currentStep,
      'total_images': _totalImagesCount,
      'property_type': _selectedCategory,
      'is_for_rent': _isForRent,
      'has_amenities': _selectedAmenities.isNotEmpty,
    });

    if (!mounted || _isLoading) {
      return;
    }

    setState(() {
      _autoValidateMode = AutovalidateMode.always;
    });

    await Future.delayed(Duration(milliseconds: 50));

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
      final propertyData = {
        "title": _titleController.text.trim(),
        "description": _descriptionController.text.trim().isNotEmpty
            ? _descriptionController.text.trim()
            : "Description de la propriété",
        "price": double.tryParse(_priceController.text) ?? 5000.0,
        "surface": double.tryParse(_areaController.text) ?? 0.1,
        "rooms": _calculateTotalRooms(),
        "bedrooms": int.tryParse(_bedroomsController.text) ?? 1,
        "kitchen": int.tryParse(_kitchensController.text) ?? 1,
        "livingRoom": int.tryParse(_livingRoomsController.text) ?? 1,
        "bathroom": int.tryParse(_bathroomsController.text) ?? 1,
        "floor": int.tryParse(_floorController.text) ?? 1,
        "address": _addressController.text.trim().isNotEmpty
            ? _addressController.text.trim()
            : "Adresse non spécifiée",
        "guarantee": _guaranteeController.text.trim().isNotEmpty
            ? _guaranteeController.text.trim()
            : "0",
        "cityId": _selectedCity?.cityId ?? 1,
        "communeId": _selectedCommune?.communeId ?? 1,
        "quartierId": _selectedQuartier?.quartierId,
        "electric": _selectedElectric != null ? int.tryParse(_selectedElectric!) : 0,
        "water": _selectedWater != null ? int.tryParse(_selectedWater!) : 0,
        "postalCode": _postalCodeController.text.trim().isNotEmpty
            ? _postalCodeController.text.trim()
            : "243",
        "quartierValue": _selectedQuartier?.name ?? _addressController.text.split(',').last.trim(),
        "sold": false,
        "username": fullname,
        "transactionType": _isForRent ? "location" : "vente",
        "propertyTypeId": _getPropertyTypeId(_selectedCategory) ?? 2,
        "userId": userId ?? 1,
        "latitude": _selectedLocation?.latitude ?? 0.1,
        "longitude": _selectedLocation?.longitude ?? 0.1,
        "features": _selectedAmenities.isNotEmpty
            ? _selectedAmenities.map((amenity) => {
          "featureId": _getFeatureId(amenity),
          "name": amenity
        }).toList()
            : [
          {
            "featureId": 1,
            "name": "Wifi"
          }
        ]
      };

      print("📦 Données de base SANS images: $propertyData");

      await _trackEvent('property_api_call_start', {
        'images_count': _totalImagesCount,
        'has_amenities': _selectedAmenities.isNotEmpty,
        'has_essential_services': _selectedElectric != null && _selectedWater != null,
        'property_type': _selectedCategory,
        'price': double.tryParse(_priceController.text),
      });

      final imagesData = await _prepareImagesData();
      print("🖼️ Données images préparées: $imagesData");

      _clearImageCache();
      propertyData.addAll(imagesData);

      final requiredImageFields = [
        "propertyImage",
        "propertyImageRoom",
        "propertyImageLivingRoom",
        "propertyImageKitchen"
      ];

      for (var field in requiredImageFields) {
        if (!propertyData.containsKey(field) || propertyData[field] == null) {
          propertyData[field] = [];
        }
      }

      print("📤 Données FINALES avec images:");
      propertyData.forEach((key, value) {
        if (key.contains('Image')) {
          print("$key: ${value is List ? '${value.length} images' : value}");
        } else {
          print("$key: $value");
        }
      });

      final ctrl = context.read<PropertyController>();
      final res = await ctrl.createProperty(propertyData);

      print("Réponse API: ${res.data}");

      if (!mounted) return;

      if ((res.data['properties'] != null || res.data['data'] != null || res.data['success'] == true)) {
        await _trackEvent('property_creation_success', {
          'property_type': _selectedCategory,
          'is_for_rent': _isForRent,
          'price': double.tryParse(_priceController.text),
          'total_rooms': _calculateTotalRooms(),
          'total_images': _totalImagesCount,
          'amenities_count': _selectedAmenities.length,
          'completion_time_seconds': DateTime.now().difference(_pageStartTime!).inSeconds,
        });

        await _clearDraft();
        SnackbarForCasa.success(context, "Annonce publiée avec succès!");

        await _trackEvent('property_creation_redirect', {
          'destination': 'home_page',
        });

        await Future.delayed(const Duration(milliseconds: 1500));
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            Routes.bottomPageRoute,
                (route) => false,
          );
        }
      } else {
        String errorMessage = res.data['detailMessage'] ?? res.data['message'] ?? "Erreur lors de la publication de l'annonce";
        print("❌ Erreur API: $errorMessage");

        await _trackEvent('property_creation_api_error', {
          'error_message': errorMessage,
          'step': _currentStep,
          'property_type': _selectedCategory,
        });

        FancyNotification.show(context, errorMessage, isError: true);
      }
    } catch (e) {
      _clearImageCache();
      print("❌ Erreur lors de la publication: $e");

      await _trackEvent('property_creation_technical_error', {
        'error': e.toString(),
        'step': _currentStep,
        'property_type': _selectedCategory,
      });

      FancyNotification.show(context, "Erreur technique lors de la publication de l'annonce: $e", isError: true);
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

  Future<Map<String, dynamic>> _prepareImagesData() async {
    Map<String, dynamic> imagesData = {};

    print("🖼️ Début préparation des images...");

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