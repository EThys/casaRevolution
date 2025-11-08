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
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Firebase imports
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_performance/firebase_performance.dart';

class CreatePropertyPostPage extends StatefulWidget {
  @override
  _CreatePropertyPostPageState createState() => _CreatePropertyPostPageState();
}

class _CreatePropertyPostPageState extends State<CreatePropertyPostPage> {
  // Modern color palette
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

  // Validation errors storage
  Map<String, String> _fieldErrors = {};
  Map<int, bool> _stepValidations = {0: false, 1: false, 2: false};
  Map<int, String> _stepErrorMessages = {};

  final GetStorage storage = GetStorage();
  late final userData = storage.read('user_data');
  late var userId=userData["userId"];

  // Categories d'images par pièces
  final List<ImageCategory> _imageCategories = [
    ImageCategory(
      id: 'propertyImage',
      name: 'Photos principales',
      icon: FontAwesomeIcons.home,
      color: Color(0xFF2196F3),
      description: 'Photos principales de la propriété',
    ),
    ImageCategory(
      id: 'propertyImageRoom',
      name: 'Chambres',
      icon: FontAwesomeIcons.bed,
      color: Color(0xFF2196F3),
      description: 'Photos des chambres',
    ),
    ImageCategory(
      id: 'propertyImageLivingRoom',
      name: 'Salon',
      icon: FontAwesomeIcons.couch,
      color: Color(0xFF2196F3),
      description: 'Photos du salon',
    ),
    ImageCategory(
      id: 'propertyImageKitchen',
      name: 'Cuisine',
      icon: FontAwesomeIcons.kitchenSet,
      color: Color(0xFF2196F3),
      description: 'Photos de la cuisine',
    ),
  ];

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

    _bedroomsController.addListener(_updateTotalRooms);
    _bathroomsController.addListener(_updateTotalRooms);
    _livingRoomsController.addListener(_updateTotalRooms);
    _kitchensController.addListener(_updateTotalRooms);

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
      // Convertir Map<String, dynamic> en Map<String, Object>
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
          // Convertir tout autre type en String
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

  Future<void> _trackValidationError(int step, String errors) async {
    await _trackEvent('validation_error', {
      'step_number': step,
      'step_name': _getStepName(step),
      'errors': errors,
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
  // EXISTING METHODS (with Firebase tracking added)
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
    final errors = <String>[];

    if (_selectedCategory == null) {
      errors.add('Veuillez sélectionner un type de propriété');
    }

    if (_totalImagesCount < 3) {
      errors.add('Au moins 3 photos sont requises');
    }

    final isValid = errors.isEmpty;
    final errorMessage = errors.isNotEmpty ? errors.join('\n') : '';

    setState(() {
      _stepValidations[0] = isValid;
      _stepErrorMessages[0] = errorMessage;
    });

    // Track validation result
    if (!isValid) {
      _trackValidationError(0, errorMessage);
    }

    return isValid;
  }

  bool _validateStep1() {
    final errors = <String>[];
    final fieldErrors = <String, String>{};

    // Title validation
    if (_titleController.text.trim().isEmpty) {
      errors.add('Le titre est requis');
      fieldErrors['title'] = 'Veuillez entrer un titre';
    }

    // Price validation
    if (_priceController.text.trim().isEmpty) {
      errors.add('Le prix est requis');
      fieldErrors['price'] = 'Veuillez entrer un prix';
    } else if (double.tryParse(_priceController.text) == null) {
      errors.add('Le prix doit être un nombre valide');
      fieldErrors['price'] = 'Veuillez entrer un nombre valide';
    }

    // Description validation
    if (_descriptionController.text.trim().isEmpty) {
      errors.add('La description est requise');
      fieldErrors['description'] = 'Veuillez entrer une description';
    } else if (_descriptionController.text.length < 50) {
      errors.add('La description doit faire au moins 50 caractères');
      fieldErrors['description'] = 'Description trop courte (${_descriptionController.text.length}/50)';
    }

    // Location validation
    if (_selectedCity == null) {
      errors.add('La ville est requise');
      fieldErrors['city'] = 'Veuillez sélectionner une ville';
    }
    if (_selectedDistrict == null) {
      errors.add('Le district est requis');
      fieldErrors['district'] = 'Veuillez sélectionner un district';
    }
    if (_selectedCommune == null) {
      errors.add('La commune est requise');
      fieldErrors['commune'] = 'Veuillez sélectionner une commune';
    }

    // Address validation
    if (_addressController.text.trim().isEmpty) {
      errors.add('L\'adresse est requise');
      fieldErrors['address'] = 'Veuillez entrer une adresse';
    } else if (_addressController.text.length < 10) {
      errors.add('L\'adresse doit être plus détaillée');
      fieldErrors['address'] = 'Adresse trop courte (${_addressController.text.length}/10)';
    }

    // Guarantee validation (only for rent)
    if (_isForRent && _guaranteeController.text.isNotEmpty && int.tryParse(_guaranteeController.text) == null) {
      errors.add('La garantie doit être un nombre valide');
      fieldErrors['guarantee'] = 'Veuillez entrer un nombre valide';
    }

    final isValid = errors.isEmpty;
    final errorMessage = errors.isNotEmpty ? errors.join('\n') : '';

    setState(() {
      _stepValidations[1] = isValid;
      _stepErrorMessages[1] = errorMessage;
      _fieldErrors = fieldErrors;
    });

    // Track validation result
    if (!isValid) {
      _trackValidationError(1, errorMessage);
    }

    return isValid;
  }

  bool _validateStep2() {
    final errors = <String>[];

    // Services essentiels maintenant OBLIGATOIRES
    if (_selectedElectric == null) {
      errors.add('La disponibilité du courant est requise');
    }
    if (_selectedWater == null) {
      errors.add('La disponibilité de l\'eau est requise');
    }

    final isValid = errors.isEmpty;
    final errorMessage = errors.isNotEmpty ? errors.join('\n') : '';

    setState(() {
      _stepValidations[2] = isValid;
      _stepErrorMessages[2] = errorMessage;
    });

    // Track validation result
    if (!isValid) {
      _trackValidationError(2, errorMessage);
    }

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

  Future<void> _handleCreatePropertyPost() async {
    print("🎯 DEBUT _handleCreatePropertyPost");

    // Track début de publication
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

    // Validation finale des étapes obligatoires
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

      // Track échec validation
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
      // Track erreur connexion
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
      // Préparer d'abord les données de base
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
        "quartierId": _selectedQuartier?.quartierId ?? 1,
        "electric": _selectedElectric != null ? int.tryParse(_selectedElectric!) ?? 40 : 40,
        "water": _selectedWater != null ? int.tryParse(_selectedWater!) ?? 50 : 50,
        "postalCode": _postalCodeController.text.trim().isNotEmpty
            ? _postalCodeController.text.trim()
            : "243",
        "quartier": _selectedQuartier?.name ?? _addressController.text.split(',').last.trim(),
        "sold": false,
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

      // Track avant l'appel API
      await _trackEvent('property_api_call_start', {
        'images_count': _totalImagesCount,
        'has_amenities': _selectedAmenities.isNotEmpty,
        'has_essential_services': _selectedElectric != null && _selectedWater != null,
        'property_type': _selectedCategory,
        'price': double.tryParse(_priceController.text),
      });

      // Préparer les images
      final imagesData = await _prepareImagesData();
      print("🖼️ Données images préparées: $imagesData");

      // Fusionner les données
      propertyData.addAll(imagesData);

      // S'assurer que tous les tableaux d'images existent
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
        // Track succès
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
        FancyNotification.show(context, "Annonce publiée avec succès!", isError: false);

        // Track redirection
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
        // Track erreur API
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
      // Track erreur technique
      print("❌ Erreur lors de la publication: $e");

      await _trackEvent('property_creation_technical_error', {
        'error': e.toString(),
        'step': _currentStep,
        'property_type': _selectedCategory,
      });

      FancyNotification.show(context, "Erreur technique lors de la publication de l'annonce: $e", isError: true);
    } finally {
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
      // Track suppression brouillon
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
          fontSize: 20,
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
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
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
          SizedBox(height: 12),
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
              fontSize: 12,
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
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Type d\'annonce'),
          SizedBox(height: 12),
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 8,
                  offset: Offset(0, 4),
                )
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildTypeOption(
                    'À louer',
                    Icons.home_work_outlined,
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
                SizedBox(width: 16),
                Expanded(
                  child: _buildTypeOption(
                    'À vendre',
                    Icons.sell_outlined,
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
          SizedBox(height: 20),

          // Catégories de propriété
          Text(
            'Type de propriété',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: 8),
          _buildPropertyCategoryCarousel(),

          // Photos
          _buildSectionHeader('Photos par pièces'),
          SizedBox(height: 8),
          Text(
            'Organisez vos photos par pièces pour une meilleure présentation',
            style: TextStyle(
              color: _greyColor,
              fontSize: 13,
            ),
          ),
          SizedBox(height: 16),

          ..._imageCategories.map((category) => _buildImageCategoryCard(category)),

          // Compteur total
          Container(
            margin: EdgeInsets.only(top: 16),
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 8,
                  offset: Offset(0, 4),
                )
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total des photos',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: _darkColor,
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _totalImagesCount >= 3 ? _successColor.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$_totalImagesCount/3 min',
                    style: TextStyle(
                      color: _totalImagesCount >= 3 ? _successColor : Colors.orange,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildPropertyCategoryCarousel() {
    final categories = [
      {
        'image': 'assets/images/studio.png',
        'label': 'Studios',
        'value': 'Studio',
        'color': Color(0xFF1976D2)
      },
      {
        'image': 'assets/images/apart.png',
        'label': 'Apparts',
        'value': 'Apparts',
        'color': Color(0xFF1976D2),
      },
      {
        'image': 'assets/images/maisons.png',
        'label': 'Maisons',
        'value': 'Maisons',
        'color': Color(0xFF1976D2),
      },
      {
        'image': 'assets/images/office.png',
        'label': 'Bureaux',
        'value': 'Bureau',
        'color': Color(0xFF1976D2),
      },
      {
        'image': 'assets/images/hotel.png',
        'label': 'Hotels',
        'value': 'Hotels',
        'color': Color(0xFF1976D2),
      },
      {
        'image': 'assets/images/plage.png',
        'label': 'Vacances',
        'value': 'Vacances',
        'color': Color(0xFF1976D2),
      },
    ];

    return Container(
      height: 110,
      margin: EdgeInsets.only(bottom: 20),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16),
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
                  _validateStep0();
                  _saveDraft();
                });
                _trackSelection('property_type', category['value'] as String);
              }
            },
            child: Container(
              width: 85,
              margin: EdgeInsets.only(right: 5),
              child: Column(
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? categoryColor.withOpacity(0.15)
                          : Colors.grey[100],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? categoryColor : Colors.transparent,
                        width: 2.5,
                      ),
                      boxShadow: isSelected
                          ? [
                        BoxShadow(
                          color: categoryColor.withOpacity(0.3),
                          blurRadius: 8,
                          offset: Offset(0, 3),
                        )
                      ]
                          : [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 4,
                          offset: Offset(0, 2),
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
                                  Icons.home,
                                  color: categoryColor,
                                  size: 30,
                                );
                              },
                            ),
                          ),
                        ),
                        if (isSelected)
                          Container(
                            decoration: BoxDecoration(
                              color: categoryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    category['label'] as String,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? categoryColor : Colors.grey[700],
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

  Widget _buildImageCategoryCard(ImageCategory category) {
    final images = _selectedImages[category.id] ?? [];

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: category.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    category.icon,
                    color: category.color,
                    size: 20,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: _darkColor,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        category.description,
                        style: TextStyle(
                          color: _greyColor,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: images.isEmpty ? Colors.orange.withOpacity(0.1) : _successColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${images.length} photo(s)',
                    style: TextStyle(
                      color: images.isEmpty ? Colors.orange : _successColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (images.isNotEmpty)
            Padding(
              padding: EdgeInsets.all(16),
              child: GridView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 1,
                ),
                itemCount: images.length,
                itemBuilder: (context, index) {
                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          File(images[index].path),
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
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => _removeImage(category.id, index),
                          child: Container(
                            padding: EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.5),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.close_rounded,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

          Padding(
            padding: EdgeInsets.all(16),
            child: ElevatedButton.icon(
              onPressed: () => _pickImages(category.id),
              style: ElevatedButton.styleFrom(
                backgroundColor: category.color.withOpacity(0.1),
                foregroundColor: category.color,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              ),
              icon: Icon(Icons.add_photo_alternate_outlined, size: 20),
              label: Text(
                'Ajouter des photos ${category.name.toLowerCase()}',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeOption(String title, IconData icon, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? _primaryColor.withOpacity(0.1) : _lightColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? _primaryColor : _borderColor,
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 32,
              color: isSelected ? _primaryColor : _greyColor,
            ),
            SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? _primaryColor : _darkColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep2() {
    return SingleChildScrollView(
      physics: BouncingScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildModernSectionHeader(
            title: 'Informations de base',
            icon: Icons.info_outline_rounded,
          ),
          SizedBox(height: 16),

          _buildModernTextField(
            controller: _titleController,
            label: 'Titre de l\'annonce *',
            hint: 'Magnifique appartement avec vue panoramique...',
            icon: Icons.title_rounded,
            focusNode: _focusNodes[0],
            nextFocusNode: _focusNodes[1],
            errorText: _fieldErrors['title'],
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Veuillez entrer un titre';
              }
              return null;
            },
          ),
          SizedBox(height: 12),

          _buildModernTextField(
            controller: _priceController,
            label: _isForRent ? 'Prix mensuel *' : 'Prix de vente *',
            hint: _isForRent ? '1200' : '450000',
            icon: Icons.attach_money_rounded,
            keyboardType: TextInputType.number,
            suffixText: '${_isForRent ? '/mois' : '\$'}',
            prefixIconColor: _isForRent ? Colors.blue : Colors.green,
            focusNode: _focusNodes[1],
            nextFocusNode: _isForRent ? _focusNodes[2] : _focusNodes[3],
            errorText: _fieldErrors['price'],
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
          SizedBox(height: 12),

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
              errorText: _fieldErrors['guarantee'],
              validator: (value) {
                if (value != null && value.isNotEmpty && int.tryParse(value) == null) {
                  return 'Veuillez entrer un nombre valide';
                }
                return null;
              },
            ),
            SizedBox(height: 12),
          ],

          _buildModernTextField(
            controller: _descriptionController,
            label: 'Description détaillée *',
            hint: 'Décrivez en détail les avantages, l\'emplacement, les équipements...',
            icon: Icons.description_rounded,
            maxLines: 4,
            focusNode: _focusNodes[3],
            nextFocusNode: _focusNodes[4],
            errorText: _fieldErrors['description'],
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

          SizedBox(height: 24),
          _buildModernSectionHeader(
            title: 'Localisation',
            icon: Icons.location_on_outlined,
          ),
          SizedBox(height: 16),

          _buildModernCityDropdown(),
          SizedBox(height: 12),

          LayoutBuilder(
            builder: (context, constraints) {
              return Row(
                children: [
                  Container(
                    width: constraints.maxWidth * 0.48,
                    child: _buildModernDistrictDropdown(),
                  ),
                  SizedBox(width: constraints.maxWidth * 0.04),
                  Container(
                    width: constraints.maxWidth * 0.48,
                    child: _buildModernCommuneDropdown(),
                  ),
                ],
              );
            },
          ),
          SizedBox(height: 12),

          _buildModernTextField(
            controller: _addressController,
            label: 'Adresse complète *',
            hint: 'Numéro, rue, avenue...',
            icon: Icons.home_work_rounded,
            focusNode: _focusNodes[4],
            nextFocusNode: null,
            errorText: _fieldErrors['address'],
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
          SizedBox(height: 12),

          _buildModernQuartierDropdown(),
          SizedBox(height: 12),

          _buildModernSectionHeader(
            title: 'Caractéristiques',
            icon: Icons.apartment_rounded,
          ),
          SizedBox(height: 16),

          GridView.count(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 3.2,
            children: [
              _buildModernFeatureInput(
                controller: _bedroomsController,
                label: 'Chambres',
                icon: FontAwesomeIcons.bed,
                color: Colors.blue.shade100,
                iconColor: Colors.blue,
              ),
              _buildModernFeatureInput(
                controller: _bathroomsController,
                label: 'Salles de bain',
                icon: FontAwesomeIcons.bath,
                color: Colors.blue.shade100,
                iconColor: Colors.blue,
              ),
              _buildModernFeatureInput(
                controller: _livingRoomsController,
                label: 'Salons',
                icon: FontAwesomeIcons.couch,
                color: Colors.blue.shade100,
                iconColor: Colors.blue,
              ),
              _buildModernFeatureInput(
                controller: _kitchensController,
                label: 'Cuisines',
                icon: FontAwesomeIcons.kitchenSet,
                color: Colors.blue.shade100,
                iconColor: Colors.blue,
              ),
              _buildModernFeatureInput(
                controller: _areaController,
                label: 'Surface (m²)',
                icon: FontAwesomeIcons.rulerCombined,
                color: Colors.blue.shade100,
                iconColor: Colors.blue,
              ),
              _buildModernFeatureInput(
                controller: _floorController,
                label: 'Étage',
                icon: FontAwesomeIcons.building,
                color: Colors.blue.shade100,
                iconColor: Colors.blue,
              ),
            ],
          ),
          SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildModernQuartierDropdown() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300, width: 1),
      ),
      child: DropdownButtonFormField<QuartierModel>(
        value: _selectedQuartier,
        items: _availableQuartiers.map((QuartierModel quartier) {
          return DropdownMenuItem<QuartierModel>(
            value: quartier,
            child: Text(
              quartier.name ?? "Quartier non spécifié",
              style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
              overflow: TextOverflow.ellipsis,
            ),
          );
        }).toList(),
        onChanged: (QuartierModel? newValue) {
          if (mounted) {
            setState(() {
              _selectedQuartier = newValue;
              _validateStep1();
              _saveDraft();
            });
            _trackSelection('quartier', newValue?.name ?? 'unknown');
          }
        },
        decoration: InputDecoration(
          labelText: 'Quartier (optionnel)',
          labelStyle: TextStyle(color: Colors.grey.shade600),
          prefixIcon: Icon(Icons.explore_rounded, color: Colors.blue.shade600, size: 20),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        icon: Icon(Icons.arrow_drop_down_rounded, color: Colors.grey.shade600),
        dropdownColor: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  Widget _buildModernElectricDropdown() {
    final hasError = _fieldErrors['electric'] != null;

    return Container(
      height: 75,
      constraints: BoxConstraints(
        minHeight: 75,
        maxHeight: 75,
      ),
      child: DropdownButtonFormField<String>(
        value: _selectedElectric,
        isExpanded: true,
        items: [
          DropdownMenuItem<String>(
            value: null,
            child: Text(
              'Sélectionnez...',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
          ),
          ..._electricOptions.map((option) {
            final percentage = int.parse(option['value']);
            Color getColorForPercentage(int percent) {
              if (percent >= 80) return Colors.green;
              if (percent >= 60) return Colors.lightGreen;
              if (percent >= 40) return Colors.orange;
              return Colors.red;
            }

            return DropdownMenuItem<String>(
              value: option['value'],
              child: Container(
                height: 65,
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 65,
                      decoration: BoxDecoration(
                        color: getColorForPercentage(percentage),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            option['label'],
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade800,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            option['description'],
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: getColorForPercentage(percentage).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: getColorForPercentage(percentage).withOpacity(0.3)),
                      ),
                      child: Text(
                        '${percentage}%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: getColorForPercentage(percentage),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ],
        onChanged: (String? newValue) {
          if (mounted) {
            setState(() {
              _selectedElectric = newValue;
              _validateStep2();
              _saveDraft();
            });
            _trackSelection('electric_service', newValue ?? 'none');
          }
        },
        validator: (value) {
          if (value == null) {
            return 'Veuillez sélectionner la disponibilité du courant';
          }
          return null;
        },
        decoration: InputDecoration(
          labelText: 'Disponibilité du courant *',
          labelStyle: TextStyle(
              color: hasError ? _errorColor : Colors.grey.shade600
          ),
          prefixIcon: Icon(
              Icons.electrical_services_rounded,
              color: hasError ? _errorColor : Colors.amber.shade700,
              size: 20
          ),
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
              color: hasError ? _errorColor : _primaryColor,
              width: 1.5,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: _errorColor,
              width: 1.5,
            ),
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          errorText: hasError ? _fieldErrors['electric'] : null,
          errorStyle: TextStyle(
            color: _errorColor,
            fontSize: 12,
          ),
        ),
        icon: Icon(
            Icons.arrow_drop_down_rounded,
            color: hasError ? _errorColor : Colors.grey.shade600
        ),
        dropdownColor: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  Widget _buildModernWaterDropdown() {
    final hasError = _fieldErrors['water'] != null;

    return Container(
      height: 75,
      constraints: BoxConstraints(
        minHeight: 75,
        maxHeight: 75,
      ),
      child: DropdownButtonFormField<String>(
        value: _selectedWater,
        isExpanded: true,
        items: [
          DropdownMenuItem<String>(
            value: null,
            child: Text(
              'Sélectionnez...',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
          ),
          ..._waterOptions.map((option) {
            final percentage = int.parse(option['value']);
            Color getColorForPercentage(int percent) {
              if (percent >= 80) return Colors.blue;
              if (percent >= 60) return Colors.lightBlue;
              if (percent >= 40) return Colors.orange;
              return Colors.red;
            }

            return DropdownMenuItem<String>(
              value: option['value'],
              child: Container(
                height: 65,
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 65,
                      decoration: BoxDecoration(
                        color: getColorForPercentage(percentage),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            option['label'],
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade800,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            option['description'],
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: getColorForPercentage(percentage).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: getColorForPercentage(percentage).withOpacity(0.3)),
                      ),
                      child: Text(
                        '${percentage}%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: getColorForPercentage(percentage),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ],
        onChanged: (String? newValue) {
          if (mounted) {
            setState(() {
              _selectedWater = newValue;
              _validateStep2();
              _saveDraft();
            });
            _trackSelection('water_service', newValue ?? 'none');
          }
        },
        validator: (value) {
          if (value == null) {
            return 'Veuillez sélectionner la disponibilité de l\'eau';
          }
          return null;
        },
        decoration: InputDecoration(
          labelText: 'Disponibilité de l\'eau *',
          labelStyle: TextStyle(
              color: hasError ? _errorColor : Colors.grey.shade600
          ),
          prefixIcon: Icon(
              Icons.water_drop_rounded,
              color: hasError ? _errorColor : Colors.blue.shade600,
              size: 20
          ),
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
              color: hasError ? _errorColor : _primaryColor,
              width: 1.5,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: _errorColor,
              width: 1.5,
            ),
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          errorText: hasError ? _fieldErrors['water'] : null,
          errorStyle: TextStyle(
            color: _errorColor,
            fontSize: 12,
          ),
        ),
        icon: Icon(
            Icons.arrow_drop_down_rounded,
            color: hasError ? _errorColor : Colors.grey.shade600
        ),
        dropdownColor: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  Widget _buildModernSectionHeader({required String title, required IconData icon}) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade50, Colors.blue.shade50],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade100, width: 1),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.blue.shade700, size: 20),
          SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.blue.shade800,
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
          ),
          prefixIcon: Icon(icon, color: iconColor, size: 18),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          floatingLabelBehavior: FloatingLabelBehavior.never,
          filled: false,
        ),
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Colors.grey.shade800,
        ),
      ),
    );
  }

  Widget _buildModernCityDropdown() {
    final hasError = _fieldErrors['city'] != null;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: hasError ? _errorColor : Colors.grey.shade300,
            width: hasError ? 1.5 : 1
        ),
      ),
      child: DropdownButtonFormField<CityModel>(
        value: _selectedCity,
        items: _availableCities.map((CityModel city) {
          return DropdownMenuItem<CityModel>(
            value: city,
            child: Text(
              city.name ?? "",
              style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
            ),
          );
        }).toList(),
        onChanged: (CityModel? newValue) {
          if (mounted) {
            setState(() {
              _selectedCity = newValue;
              _updateDistrictsForCity();
              _validateStep1();
              _saveDraft();
            });
            _trackSelection('city', newValue?.name ?? 'unknown');
          }
        },
        validator: (value) {
          if (value == null) {
            return 'Veuillez sélectionner une ville';
          }
          return null;
        },
        decoration: InputDecoration(
          labelText: 'Ville *',
          labelStyle: TextStyle(
              color: hasError ? _errorColor : Colors.grey.shade600
          ),
          prefixIcon: Icon(
              Icons.location_city_rounded,
              color: hasError ? _errorColor : Colors.blue.shade600,
              size: 20
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          errorText: hasError ? _fieldErrors['city'] : null,
          errorStyle: TextStyle(
            color: _errorColor,
            fontSize: 12,
          ),
        ),
        icon: Icon(
            Icons.arrow_drop_down_rounded,
            color: hasError ? _errorColor : Colors.grey.shade600
        ),
        dropdownColor: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  Widget _buildModernDistrictDropdown() {
    final hasError = _fieldErrors['district'] != null;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: hasError ? _errorColor : Colors.grey.shade300,
            width: hasError ? 1.5 : 1
        ),
      ),
      child: DropdownButtonFormField<DistrictModel>(
        value: _selectedDistrict,
        items: _availableDistricts.map((DistrictModel district) {
          return DropdownMenuItem<DistrictModel>(
            value: district,
            child: Text(
              district.name ?? "",
              style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
              overflow: TextOverflow.ellipsis,
            ),
          );
        }).toList(),
        onChanged: (DistrictModel? newValue) {
          if (mounted) {
            setState(() {
              _selectedDistrict = newValue;
              _updateCommunesForDistrict();
              _validateStep1();
              _saveDraft();
            });
            _trackSelection('district', newValue?.name ?? 'unknown');
          }
        },
        validator: (value) {
          if (value == null) {
            return 'Veuillez sélectionner un district';
          }
          return null;
        },
        decoration: InputDecoration(
          labelText: 'District *',
          labelStyle: TextStyle(
              color: hasError ? _errorColor : Colors.grey.shade600
          ),
          prefixIcon: Icon(
              Icons.account_balance_rounded,
              color: hasError ? _errorColor : Colors.blue.shade600,
              size: 20
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          errorText: hasError ? _fieldErrors['district'] : null,
          errorStyle: TextStyle(
            color: _errorColor,
            fontSize: 12,
          ),
        ),
        icon: Icon(
            Icons.arrow_drop_down_rounded,
            color: hasError ? _errorColor : Colors.grey.shade600
        ),
        dropdownColor: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  Widget _buildModernCommuneDropdown() {
    final hasError = _fieldErrors['commune'] != null;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: hasError ? _errorColor : Colors.grey.shade300,
            width: hasError ? 1.5 : 1
        ),
      ),
      child: DropdownButtonFormField<CommuneModel>(
        value: _selectedCommune,
        items: _availableCommunes.map((CommuneModel commune) {
          return DropdownMenuItem<CommuneModel>(
            value: commune,
            child: Text(
              commune.name ?? "",
              style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
              overflow: TextOverflow.ellipsis,
            ),
          );
        }).toList(),
        onChanged: (CommuneModel? newValue) {
          if (mounted) {
            setState(() {
              _selectedCommune = newValue;
              _validateStep1();
              _saveDraft();
            });
            _trackSelection('commune', newValue?.name ?? 'unknown');
          }
        },
        validator: (value) {
          if (value == null) {
            return 'Veuillez sélectionner une commune';
          }
          return null;
        },
        decoration: InputDecoration(
          labelText: 'Commune *',
          labelStyle: TextStyle(
              color: hasError ? _errorColor : Colors.grey.shade600
          ),
          prefixIcon: Icon(
              Icons.place_rounded,
              color: hasError ? _errorColor : Colors.blue.shade600,
              size: 20
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          errorText: hasError ? _fieldErrors['commune'] : null,
          errorStyle: TextStyle(
            color: _errorColor,
            fontSize: 12,
          ),
        ),
        icon: Icon(
            Icons.arrow_drop_down_rounded,
            color: hasError ? _errorColor : Colors.grey.shade600
        ),
        dropdownColor: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
    final hasError = errorText != null;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: hasError ? _errorColor : Colors.grey.shade300,
            width: hasError ? 1.5 : 1
        ),
        color: Colors.white,
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        focusNode: focusNode,
        validator: validator,
        onChanged: (value) {
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
          labelText: label,
          labelStyle: TextStyle(
            color: hasError ? _errorColor : Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey.shade400),
          prefixIcon: Icon(
              icon,
              color: hasError ? _errorColor : prefixIconColor,
              size: 20
          ),
          suffixText: suffixText,
          suffixStyle: TextStyle(
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          floatingLabelBehavior: FloatingLabelBehavior.auto,
          errorText: errorText,
          errorStyle: TextStyle(
            color: _errorColor,
            fontSize: 12,
          ),
        ),
        style: TextStyle(
          fontSize: 14,
          color: Colors.grey.shade800,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildStep3() {
    return SingleChildScrollView(
      physics: BouncingScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Équipements (optionnels)'),
          SizedBox(height: 8),
          Text(
            'Sélectionnez les équipements disponibles dans votre propriété',
            style: TextStyle(
              color: _greyColor,
              fontSize: 13,
            ),
          ),
          SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _amenitiesList.map((amenity) {
              final isSelected = _selectedAmenities.contains(amenity);
              return ChoiceChip(
                label: Text(amenity),
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

          SizedBox(height: 24),
          _buildSectionHeader('Services essentiels *'),
          SizedBox(height: 8),
          Text(
            'Ces informations sont obligatoires pour aider les locataires',
            style: TextStyle(
              color: _greyColor,
              fontSize: 13,
            ),
          ),
          SizedBox(height: 16),

          // Dropdown Électricité avec hauteur réduite
          Container(
            height: 70,
            child: _buildModernElectricDropdown(),
          ),
          SizedBox(height: 16),

          // Dropdown Eau avec hauteur réduite
          Container(
            height: 70,
            child: _buildModernWaterDropdown(),
          ),

          // Message d'information pour les champs obligatoires
          Container(
            margin: EdgeInsets.only(top: 16),
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade100),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade600, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Les services essentiels sont obligatoires pour compléter votre annonce.',
                    style: TextStyle(
                      color: Colors.blue.shade800,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 24),
          _buildSectionHeader('Localisation sur la carte (optionnelle)'),
          SizedBox(height: 12),
          Container(
            height: 150,
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _borderColor),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.map_outlined,
                    size: 40,
                    color: _greyColor.withOpacity(0.5),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Carte interactive',
                    style: TextStyle(
                      color: _greyColor,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Fonctionnalité à venir',
                    style: TextStyle(
                      color: _greyColor,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildBottomNavigation() {
    final isLastStep = _currentStep == 2;
    final canProceed = !_isLoading;
    final canPublish = _stepValidations[0]! && _stepValidations[1]! && _stepValidations[2]! && !_isLoading;

    return Container(
      padding: EdgeInsets.all(20),
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
                    // Track fin d'étape actuelle
                    _endStepTracking(_currentStep, _getStepName(_currentStep), false);
                    setState(() => _currentStep--);
                    // Track début nouvelle étape
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
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          if (_currentStep > 0) SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: isLastStep
                  ? (canPublish ? _handleCreatePropertyPost : null)
                  : (canProceed ? () {
                // Valider l'étape actuelle avant de continuer
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
                  // Track fin d'étape actuelle
                  _endStepTracking(_currentStep, _getStepName(_currentStep), true);
                  setState(() => _currentStep++);
                  // Track début nouvelle étape
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
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: _darkColor,
      ),
    );
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