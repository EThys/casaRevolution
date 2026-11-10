import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:casa/controllers/ServiceController.dart';
import 'package:casa/controllers/LocationController.dart';
import 'package:casa/models/CityModel.dart';
import 'package:casa/models/CommuneModel.dart';
import 'package:casa/models/DistrictModel.dart';
import 'package:casa/models/QuartierModel.dart';
import 'package:casa/models/DeviseModel.dart';
import 'package:casa/utils/listing_form_chrome.dart';
import 'package:casa/widgets/casa_choice_sheet.dart';
import 'package:casa/models/PrestationModel.dart';
import 'package:casa/utils/FancyNotification.dart';
import 'package:casa/utils/SubscriptionHelper.dart';
import 'package:casa/utils/Routes.dart';
import 'package:casa/utils/networkCheck.dart';
import 'package:casa/utils/city_suggestions.dart';
import 'package:casa/utils/country_codes.dart';
import 'package:casa/utils/offline_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:casa/utils/requetes.dart';
import 'package:casa/utils/crashlytics_api.dart';
import 'package:casa/controllers/AuthentificationCtrl.dart';
import 'camera/SelfieCameraScreen.dart'; // FIX: path was incorrect
import '../utils/StockageKeys.dart';
import 'package:casa/widgets/profile_style_image_picker_sheet.dart';

class CreateServicePostPage extends StatefulWidget {
  @override
  _CreateServicePostPageState createState() => _CreateServicePostPageState();
}

class _CreateServicePostPageState extends State<CreateServicePostPage> {
  // Modern color palette
  final Color _primaryColor = Color(0xFF1976D2);
  final Color _secondaryColor = Color(0xFF64B5F6);
  final Color _darkColor = Color(0xFF1A1D26);
  final Color _lightColor = Color(0xFFF8F9FA);
  final Color _greyColor = Color(0xFF6C757D);
  final Color _successColor = Color(0xFF38B000);
  final Color _cardColor = Colors.white;
  final Color _borderColor = Color(0xFFE9ECEF);
  final Color _errorColor = Color(0xFFD32F2F);

  // Tailles de texte
  final double _titleSize = 18.0;
  final double _bodySize = 14.0;
  final double _captionSize = 12.0;

  // Espacements
  final double _smallSpace = 8.0;
  final double _mediumSpace = 16.0;
  final double _largeSpace = 24.0;

  // Form controllers
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController(); // Restauré
  // final TextEditingController _titleController = TextEditingController(); // Remplacé par affichage du type de compte (Ancien commentaire)
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _priceMinController = TextEditingController();
  final TextEditingController _priceMaxController = TextEditingController();
  final TextEditingController _experienceController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _cityTextController = TextEditingController();
  final TextEditingController _communeTextController = TextEditingController();
  final TextEditingController _quartierTextController = TextEditingController();
  //final TextEditingController _plageJourController = TextEditingController(); // Remplacé par sélecteur de jours
  Set<String> _selectedDays = {}; // Jours sélectionnés
  final TextEditingController _plageHeureController = TextEditingController();

  // Country code for phone
  String _selectedCountryCode = '+243'; // RDC par défaut
  DeviseModel? _selectedDevise; // Devise sélectionnée
  File? _selectedCvFile; // Fichier CV sélectionné (PDF ou DOC)
  final Map<String, String> _countryFlags = Map<String, String>.from(countryFlags);
  final Map<String, String> _countryNames = Map<String, String>.from(countryNames);

  // State variables
  bool _isLoading = false;
  int _currentStep = 0;
  final ImagePicker _picker = ImagePicker();

  Future<XFile> _persistPickedXFile(XFile x, {required String prefix}) async {
    final src = File(x.path);
    if (!await src.exists()) return x;

    final supportDir = await getApplicationSupportDirectory();
    final dir = Directory('${supportDir.path}/persisted_images');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final name = x.path.replaceAll('\\', '/').split('/').last;
    final dot = name.lastIndexOf('.');
    final ext = (dot >= 0 && dot < name.length - 1) ? name.substring(dot) : '.jpg';
    final dst = File('${dir.path}/${prefix}_${DateTime.now().millisecondsSinceEpoch}$ext');
    try {
      final copied = await src.copy(dst.path);
      return XFile(copied.path);
    } catch (_) {
      return x;
    }
  }
  late PageController _pageController;

  // Images: Photo principale = visage, Photos de réalisations
  XFile? _profileImage; // Photo du visage (image principale)
  List<XFile> _portfolioImages = []; // Photos de réalisations

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
  List<QuartierModel> _kinshasaQuartiers = []; // Liste dédiée pour Kinshasa (API flat)

  // Validation
  Map<String, String> _fieldErrors = {};
  Map<int, bool> _stepValidations = {0: false, 1: false, 2: false, 3: false};
  Map<int, Map<String, String>> _stepFieldErrors = {
    0: {},
    1: {},
    2: {},
    3: {},
  };
  Map<String, bool> _fieldTouched = {};
  bool _hasAttemptedSubmit = false;

  // Edit mode
  PrestationModel? _editingPrestation;
  bool get _isEditing => _editingPrestation != null;

  // User data
  String? _userServiceType;
  String? _userFullName;
  int? _userId;
  int? _serviceId;
  int? _deviseId = 1; // 1 for FC, 2 for USD

  final GetStorage _storage = GetStorage();

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _loadUserData();

    // Décaler le chargement des données de localisation après le build initial
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Check for editing prestation in arguments
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map<String, dynamic> && args.containsKey('prestation')) {
        if (mounted) {
          setState(() {
            _editingPrestation = args['prestation'] as PrestationModel;
            _prefillForm();
          });
        }
      }

      _checkUserVerification();
      _loadLocationData();
      context.read<ServiceController>().fetchDevises();
    });
  }

  void _prefillForm() {
    if (_editingPrestation == null) return;

    _serviceId = _editingPrestation!.serviceId;
    _titleController.text = _editingPrestation!.title ?? '';
    _descriptionController.text = _editingPrestation!.description ?? '';
    _priceMinController.text = _editingPrestation!.minPrice != null && _editingPrestation!.minPrice! > 0
        ? _editingPrestation!.minPrice!.toInt().toString()
        : '';
    _experienceController.text = _editingPrestation!.experience ?? '';
    _phoneController.text = _editingPrestation!.phone ?? '';
    _addressController.text = _editingPrestation!.address ?? '';
    _plageHeureController.text = _editingPrestation!.plageHeurePrestation ?? '';

    if (_editingPrestation!.plageJourPrestation != null && _editingPrestation!.plageJourPrestation!.isNotEmpty) {
      _selectedDays = _editingPrestation!.plageJourPrestation!.split(', ').toSet();
    }

    _cityTextController.text = _editingPrestation!.cityValue ?? '';
    _communeTextController.text = _editingPrestation!.communeValue ?? '';
    _quartierTextController.text = _editingPrestation!.quartierValue ?? '';

    // Location objects matching will happen in _loadLocationData or here if already loaded
    if (_editingPrestation!.cityId != null && _availableCities.isNotEmpty) {
      _selectedCity = _availableCities.firstWhere(
              (c) => c.cityId == _editingPrestation!.cityId,
          orElse: () => CityModel(cityId: _editingPrestation!.cityId, name: _editingPrestation!.cityValue)
      );
    }

    // Match Devise
    if (_editingPrestation!.deviseId != null) {
      final serviceCtrl = context.read<ServiceController>();
      if (serviceCtrl.devisesList.isNotEmpty) {
        _selectedDevise = serviceCtrl.devisesList.firstWhere(
                (d) => d.id == _editingPrestation!.deviseId,
            orElse: () => serviceCtrl.devisesList.first
        );
      }
    }

    // Mark steps as valid
    _stepValidations[0] = true;
    _stepValidations[1] = true;
    _stepValidations[2] = true;
    _stepValidations[3] = true;
  }

  void _checkUserVerification() {
    final authCtrl = context.read<AuthentificationCtrl>();
    // Check local storage if authCtrl user is not fully populated
    if (authCtrl.user.userId == null) {
      _loadUserData();
    }

    if (authCtrl.user.isCertified != true) {
      // Allow user to proceed if just verifying flow, but ideally should block
      // For now we just load data and let them continue, validation happens at submit
    }
  }
  void _onCityChanged(String selection) {
    if (selection.isEmpty) return;

    _markFieldTouched('city');
    setState(() {
      _cityTextController.text = selection;
      final query = selection.toLowerCase().trim();

      // Mapping to CityModel if possible
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
        // Reset related fields for other cities or partial input
        _selectedCity = null;
        _selectedDistrict = null;
        _selectedCommune = null;
        _selectedQuartier = null;
      }
      _validateStep(3);
    });
  }

  Future<void> _loadUserData() async {
    try {
      final userData = _storage.read<Map<String, dynamic>>(StockageKeys.userKey);
      final profileData = _storage.read<Map<String, dynamic>>(StockageKeys.profileKey);

      // Robust userId retrieval as requested
      _userId = userData?['user']?['userId'] ;

      _userFullName = profileData?['fullname'] ??
          userData?['username'] ??
          'Prestataire';

      // Get serviceId from user accounts
      final userAccounts = _storage.read<List<dynamic>>('user_accounts');
      if (userAccounts != null) {
        for (var acc in userAccounts) {
          var typeAcc = acc['typeAccount'];
          int typeId = typeAcc is Map
              ? (typeAcc['typeAccountId'] ?? typeAcc['TypeAccountId'] ?? 0)
              : (acc['typeAccountId'] ?? acc['TypeAccountId'] ?? 0);

          if (typeId == 3) {
            // Récupérer l'ID du compte (pas le typeAccountId)
            _serviceId = acc['id'] ?? acc['Id'];

            // Récupérer le nom du compte depuis acc['name'] (ex: "electricien")
            final accountName = acc['name']?.toString().toLowerCase();
            if (accountName != null) {
              // Stocker le nom brut pour l'affichage
              _userServiceType = accountName;
              print("✅ [CreateService] Service trouvé: $accountName, ID: $_serviceId");
            }
            break;
          }
        }
      }
    } catch (e) {
      print("Erreur lors du chargement des données utilisateur: $e");
    }
  }

  String? _mapAccountTypeToServiceType(String accountName) {
    final map = {
      'majordome': 'majordhomme',
      'plombier': 'plomberie',
      'electricien': 'electricite',
      'salubrité': 'nettoyage',
      'peintre': 'peinture',
      'coiffure': 'coiffure',
      'coiffeur': 'coiffure',
      'carreleur': 'coiffure',
      'menuisier': 'reparation',
      'frigoriste': 'reparation',
      'ajusteur': 'reparation',
      'architecte': 'renovation',
      'chauffeur': 'transport',
      'demenagement': 'demenagement',
    };
    return map[accountName];
  }

  Future<void> _loadLocationData() async {
    try {
      // Utiliser le LocationController du Provider au lieu d'en créer un nouveau
      final locationCtrl = Provider.of<LocationController>(context, listen: false);
      print("📍 [CreateService] Début chargement des données de localisation...");

      // Charger TOUTES les données d'abord
      await locationCtrl.loadAllData();
      print("📍 [CreateService] loadAllData() terminé");

      if (mounted) {
        _availableCities = await locationCtrl.getAllCities();
        print("📍 [CreateService] ${_availableCities.length} villes chargées");

        if (_availableCities.isNotEmpty) {
          _selectedCity = _availableCities.firstWhere(
                (c) => c.name?.toLowerCase() == 'kinshasa',
            orElse: () => _availableCities.first,
          );
          print("📍 [CreateService] Ville sélectionnée: ${_selectedCity?.name}");

          if (_selectedCity != null) {
            _availableDistricts = locationCtrl.getDistrictsForCity(_selectedCity!.cityId!);

            // Si Kinshasa, précharger les quartiers flat
            if (_selectedCity!.name?.toLowerCase().trim() == 'kinshasa') {
              _loadKinshasaQuartiers();
            }

            print("📍 [CreateService] ${_availableDistricts.length} districts pour ${_selectedCity?.name}");

            if (_availableDistricts.isNotEmpty) {
              _selectedDistrict = _availableDistricts.first;
              print("📍 [CreateService] District sélectionné: ${_selectedDistrict?.name}");

              _availableCommunes = locationCtrl.getCommunesForDistrict(_selectedDistrict!.districtId!);
              print("📍 [CreateService] ${_availableCommunes.length} communes pour ${_selectedDistrict?.name}");
            }
          }
        }

        if (mounted) setState(() {});
        print("📍 [CreateService] Chargement de localisation terminé avec succès");
      }
    } catch (e, stackTrace) {
      print("❌ [CreateService] Erreur chargement localisation: $e");
      print("Stack trace: $stackTrace");
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _priceMinController.dispose();
    _priceMaxController.dispose();
    _experienceController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityTextController.dispose();
    _communeTextController.dispose();
    _quartierTextController.dispose();
    //_plageHeureController.dispose(); // Plus utilisé manuellement
    _plageHeureController.dispose();
    super.dispose();
  }

  Future<void> _selectTimeRange(BuildContext context) async {
    // Sélection Heure de début
    final TimeOfDay? startTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: 8, minute: 0),
      helpText: "HEURE DE DÉBUT",
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: _primaryColor,
              onPrimary: Colors.white,
              onSurface: _darkColor,
            ),
          ),
          child: child!,
        );
      },
    );

    if (startTime == null) return;

    // Sélection Heure de fin
    final TimeOfDay? endTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: 17, minute: 0),
      helpText: "HEURE DE FIN",
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: _primaryColor,
              onPrimary: Colors.white,
              onSurface: _darkColor,
            ),
          ),
          child: child!,
        );
      },
    );

    if (endTime == null) return;

    // Formatage "08:00 - 17:00"
    final localizations = MaterialLocalizations.of(context);
    final formattedStart = localizations.formatTimeOfDay(startTime, alwaysUse24HourFormat: true);
    final formattedEnd = localizations.formatTimeOfDay(endTime, alwaysUse24HourFormat: true);

    setState(() {
      _plageHeureController.text = "$formattedStart - $formattedEnd";
      if (_plageHeureController.text.isNotEmpty) {
        _removeFieldError(2, 'plage_heure');
      }
    });
  }

  String _getCountryNameFromCode(String countryCode) {
    return _countryNames[countryCode] ?? _countryNames[_selectedCountryCode] ?? 'RDC';
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

  void _updateQuartiersForCommune() {
    if (_selectedCommune == null) return;

    final locationCtrl = LocationController();
    setState(() {
      try {
        _availableQuartiers = locationCtrl.getQuartiersForCommune(_selectedCommune!.communeId!);
        _selectedQuartier = _availableQuartiers.isNotEmpty ? _availableQuartiers.first : null;
        // Important: garder un état cohérent UI/payload.
        // Si l'utilisateur n'a rien tapé, on synchronise le champ texte avec la sélection par défaut.
        if (_quartierTextController.text.trim().isEmpty) {
          _quartierTextController.text = _selectedQuartier?.name ?? '';
        }
      } catch (e) {
        _availableQuartiers = [];
        _selectedQuartier = null;
      }
    });
  }

  List<String> _filterSuggestions(String query, List<String> suggestions) {
    if (query.isEmpty) return suggestions;
    return suggestions.where((suggestion) =>
        suggestion.toLowerCase().contains(query.toLowerCase())).toList();
  }

  Future<void> _loadKinshasaQuartiers() async {
    try {
      final locCtrl = Provider.of<LocationController>(context, listen: false);
      final quartiers = await locCtrl.getKinshasaQuartiers();
      if (mounted) {
        setState(() {
          _kinshasaQuartiers = quartiers;
        });
      }
    } catch (e) {
      print("Erreur chargement quartiers Kinshasa page: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _lightColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _primaryColor,
        title: Text(
          'Publier mon service',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
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
            child: Column(
              children: [
                _buildProgressIndicator(),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: NeverScrollableScrollPhysics(),
                    children: [
                      _buildStep0(),
                      _buildStep1(),
                      _buildStepOffer(),
                      _buildStep2(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: _mediumSpace, vertical: _mediumSpace),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildStepIndicator(0, 'Photo', Icons.camera_alt_rounded),
          _stepLink(0),
          _buildStepIndicator(1, 'Infos', Icons.description_rounded),
          _stepLink(1),
          _buildStepIndicator(2, 'Offre', Icons.payments_rounded),
          _stepLink(2),
          _buildStepIndicator(3, 'Lieu', Icons.location_on_rounded),
        ],
      ),
    );
  }

  Widget _stepLink(int beforeStep) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 22),
        color: _currentStep > beforeStep ? _primaryColor : _borderColor,
      ),
    );
  }

  Widget _buildStepIndicator(int step, String label, IconData icon) {
    final isActive = _currentStep == step;
    final isCompleted = _currentStep > step;

    return GestureDetector(
      onTap: () async {
        if (_validateStep(_currentStep)) {
          setState(() => _currentStep = step);
          await _pageController.animateToPage(
            step,
            duration: Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      },
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive || isCompleted ? _primaryColor : Colors.grey[200],
              border: Border.all(
                color: isActive ? _primaryColor : Colors.transparent,
                width: 2,
              ),
            ),
            child: Icon(
              icon,
              color: isActive || isCompleted ? Colors.white : Colors.grey[600],
              size: 18,
            ),
          ),
          SizedBox(height: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: _captionSize,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              color: isActive ? _primaryColor : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildStep0() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(_mediumSpace),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            'Média',
            'Ajoutez votre photo de profil et des photos pour illustrer votre service',
            Icons.camera_alt_rounded,
          ),
          SizedBox(height: _mediumSpace),

          // Photo de profil (en premier, obligatoire)
          Padding(
            padding: EdgeInsets.only(bottom: _smallSpace),
            child: Row(
              children: [
                Icon(Icons.person_rounded, color: _primaryColor, size: 20),
                SizedBox(width: 8),
                Text(
                  'Photo de profil *',
                  style: GoogleFonts.inter(
                    fontSize: _bodySize,
                    fontWeight: FontWeight.w600,
                    color: _darkColor,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: _smallSpace),
          _buildProfileImageSelector(),

          SizedBox(height: _largeSpace),

          // Images de portfolio
          Padding(
            padding: EdgeInsets.only(bottom: _smallSpace),
            child: Row(
              children: [
                Icon(Icons.photo_library_rounded, color: _primaryColor, size: 20),
                SizedBox(width: 8),
                Text(
                  'Photos de réalisations',
                  style: GoogleFonts.inter(
                    fontSize: _bodySize,
                    fontWeight: FontWeight.w600,
                    color: _darkColor,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: _smallSpace),
          _buildPortfolioImagesGrid(), // Gestion améliorée des images multiples

          SizedBox(height: _largeSpace),
          _buildBottomNavigation(),
          SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildStep1() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(_mediumSpace),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            'Informations du service',
            'Décrivez votre service en détail',
            Icons.info_outline_rounded,
          ),
          SizedBox(height: _mediumSpace),

          // Affichage du type de service (READ ONLY)
          _buildReadOnlyServiceTypeField(),

          SizedBox(height: _mediumSpace),

          // Champ Titre (RESTAURÉ)
          _buildModernTextField(
            controller: _titleController,
            label: 'Titre de l\'annonce',
            hint: 'Ex: Plombier professionnel (Optionnel)',
            icon: Icons.title_rounded,
            fieldKey: 'title',
            validator: (v) {
              // Validation relaxée : le titre n'est plus strictement requis si le type de service est là,
              // mais on peut le laisser obligatoire sans contrainte de longueur.
              // Le user a dit "enleve les verifications des nombres des caracteres".
              if (v == null || v.trim().isEmpty) return 'Titre requis';
              return null;
            },
          ),

          SizedBox(height: _mediumSpace),

          _buildModernTextField(
            controller: _descriptionController,
            label: 'Description détaillée',
            hint: 'Décrivez votre service...',
            icon: Icons.description_rounded,
            maxLines: 6,
            fieldKey: 'description',
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Description requise';
              return null;
            },
          ),

          SizedBox(height: _mediumSpace),

          _buildModernTextField(
            controller: _experienceController,
            label: 'Années d\'expérience',
            hint: 'Ex: 5',
            icon: Icons.work_history_rounded,
            keyboardType: TextInputType.number,
            fieldKey: 'experience',
            helperText: 'Nombre d\'années d\'expérience dans ce domaine',
            validator: (v) {
              if (v != null && v.trim().isNotEmpty && int.tryParse(v) == null) {
                return 'Nombre invalide';
              }
              return null;
            },
          ),
          SizedBox(height: _mediumSpace),
          _buildPhoneField(),

          SizedBox(height: _largeSpace),
          _buildBottomNavigation(),
          SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildStepOffer() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(_mediumSpace),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            'Prix',
            'Indiquez le tarif de départ de votre service',
            Icons.attach_money_rounded,
          ),
          SizedBox(height: _mediumSpace),
          ListingFormChrome.priceDeviseRow(
            controller: _priceMinController,
            priceLabel: 'Prix',
            priceHint: '0',
            priceError: _shouldShowError(2, 'price_min') ? _getFieldError(2, 'price_min') : null,
            deviseValue: (_selectedDevise?.displaySymbol ?? '').trim().isEmpty
                ? 'Devise'
                : _selectedDevise!.displaySymbol,
            onPriceChanged: (_) {
              if (!mounted) return;
              setState(() {
                _markFieldTouched('price_min');
                _validateStep(2);
              });
            },
            onDeviseTap: _pickDevise,
          ),
          SizedBox(height: _mediumSpace),
          _buildSectionHeader(
            'Disponibilité',
            'Choisissez les jours et les heures où vous êtes disponible',
            Icons.access_time_rounded,
          ),
          SizedBox(height: _mediumSpace),
          _buildDaySelector(),
          GestureDetector(
            onTap: () => _selectTimeRange(context),
            child: AbsorbPointer(
              child: _buildModernTextField(
                controller: _plageHeureController,
                label: 'Heures de prestation',
                hint: 'Appuyez pour sélectionner une plage',
                icon: Icons.access_time_rounded,
                fieldKey: 'plage_heure',
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Plage horaire requise';
                  return null;
                },
              ),
            ),
          ),
          SizedBox(height: _mediumSpace),
          _buildSectionHeader(
            'Curriculum Vitae (optionnel)',
            'Ajoutez votre CV pour renforcer votre crédibilité (PDF ou DOC)',
            Icons.description_rounded,
          ),
          SizedBox(height: _mediumSpace),
          _buildCvUploadSection(),
          SizedBox(height: _largeSpace),
          _buildBottomNavigation(),
          SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildStep2() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(_mediumSpace),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            'Localisation',
            'Où proposez-vous votre service ?',
            Icons.location_on_rounded,
          ),
          SizedBox(height: _mediumSpace),

          // Ville avec suggestions (typeahead)
          _buildCitySuggestionField(),

          SizedBox(height: _mediumSpace),

          if (_isKinshasaSelected) ...[
            // Mode Kinshasa : District et Commune en dropdowns, Quartier en suggestion
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
                              _updateCommunesForDistrict();
                            });
                          }
                        },
                        icon: Icons.account_balance_rounded,
                        fieldKey: 'district',
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
                              _updateQuartiersForCommune();
                            });
                          }
                        },
                        icon: Icons.place_rounded,
                        fieldKey: 'commune',
                        hintText: 'Sélectionnez une commune',
                      ),
                    ),
                  ],
                );
              },
            ),
            SizedBox(height: _smallSpace),
            _buildSuggestionTextField(
              label: 'Quartier',
              controller: _quartierTextController,
              fieldKey: 'quartier',
              // Utiliser les quartiers chargés en local pour Kinshasa (API flat) + ceux liés à la commune si disp
              suggestions: _kinshasaQuartiers.isNotEmpty
                  ? _kinshasaQuartiers.map((q) => q.name ?? '').toList()
                  : _availableQuartiers.map((q) => q.name ?? '').where((n) => n.isNotEmpty).toList(),
            ),
            SizedBox(height: _mediumSpace),
          ] else ...[
            // Mode hors Kinshasa
            _buildSuggestionTextField(
              label: 'Commune',
              controller: _communeTextController,
              fieldKey: 'commune',
              // Filtre spécial : Si Matadi, afficher ses communes, sinon vide (pas de suggestions Kinshasa)
              suggestions: (_selectedCity?.name?.toLowerCase().trim() == 'matadi' ||
                  _cityTextController.text.toLowerCase().trim() == 'matadi')
                  ? ['Matadi', 'Mvuzi', 'Nzanza']
                  : [], // Désactiver suggestions pour les autres villes car elles pointent vers Kinshasa
            ),
            SizedBox(height: _smallSpace),
            _buildSuggestionTextField(
              label: 'Quartier',
              controller: _quartierTextController,
              fieldKey: 'quartier',
              suggestions: [], // Pas de suggestions locales connues hors Kinshasa
            ),
            SizedBox(height: _mediumSpace),
          ],

          _buildModernTextField(
            controller: _addressController,
            label: 'Adresse complète',
            hint: 'Rue, numéro, etc.',
            icon: Icons.home_rounded,
            maxLines: 2,
            fieldKey: 'address',
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Adresse requise';
              return null;
            },
          ),

          SizedBox(height: _largeSpace),
          _buildBottomNavigation(),
          SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildProfileImageSelector() {
    final hasError = _shouldShowError(0, 'profile_image') && _profileImage == null && !(_isEditing && _editingPrestation?.profile != null);

    if (_profileImage != null || (_isEditing && _editingPrestation?.profile != null && _editingPrestation!.profile!.isNotEmpty)) {
      return Stack(
        children: [
          Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              image: DecorationImage(
                image: _profileImage != null
                    ? FileImage(File(_profileImage!.path)) as ImageProvider
                    : OfflineImageProvider(_editingPrestation!.profile!),
                fit: BoxFit.cover,
              ),
              boxShadow: [
                BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4)),
              ],
            ),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: GestureDetector(
              onTap: () => _pickProfileImage(),
              child: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.edit_rounded, color: _primaryColor, size: 20),
              ),
            ),
          ),
        ],
      );
    }

    return GestureDetector(
      onTap: () => _pickProfileImage(),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: hasError ? _errorColor : _borderColor, width: 1.5),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: Offset(0, 4)),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_primaryColor, _secondaryColor],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: _primaryColor.withOpacity(0.25), blurRadius: 8, offset: Offset(0, 4)),
                ],
              ),
              child: Icon(Icons.camera_front_rounded, color: Colors.white, size: 28),
            ),
            SizedBox(height: 12),
            Text(
              "Photo de profil",
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: _darkColor),
            ),
            SizedBox(height: 4),
            Text(
              "Une photo claire de vous",
              style: GoogleFonts.inter(fontSize: 12, color: _greyColor),
            ),
            SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildPortfolioImagesGrid() {
    final hasError = _shouldShowError(0, 'portfolio_images') && _portfolioImages.isEmpty && !(_isEditing && _editingPrestation?.images != null && _editingPrestation!.images!.isNotEmpty);

    final allImagesCount = _portfolioImages.length + (_isEditing ? (_editingPrestation?.images?.length ?? 0) : 0);

    if (_portfolioImages.isEmpty && !(_isEditing && _editingPrestation?.images != null && _editingPrestation!.images!.isNotEmpty)) {
      return GestureDetector(
        onTap: () => _pickPortfolioImages(),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: hasError ? _errorColor : _borderColor, width: 1.5),
          ),
          child: Column(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: _primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.add_a_photo_rounded, color: _primaryColor, size: 24),
              ),
              SizedBox(height: 12),
              Text(
                "Photos de réalisations",
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: _darkColor),
              ),
              SizedBox(height: 4),
              Text(
                "Ajoutez vos meilleures photos",
                style: GoogleFonts.inter(fontSize: 11, color: _greyColor),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "$allImagesCount réalisation(s) ajoutée(s)",
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: _greyColor),
            ),
            if (allImagesCount < 10)
              TextButton.icon(
                onPressed: () => _pickPortfolioImages(),
                icon: Icon(Icons.add_a_photo_rounded, size: 16),
                label: Text("Ajouter"),
                style: TextButton.styleFrom(foregroundColor: _primaryColor),
              ),
          ],
        ),
        SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: allImagesCount,
          itemBuilder: (context, index) {
            // Logic to display existing images first, then new ones
            final existingCount = _isEditing ? (_editingPrestation?.images?.length ?? 0) : 0;

            if (index < existingCount) {
              final imageUrl = _editingPrestation!.images![index];
              return Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: OfflineNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(color: Colors.grey[200]),
                      errorWidget: (context, url, error) => Icon(Icons.error),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _editingPrestation!.images!.removeAt(index);
                          _validateStep(0);
                        });
                      },
                      child: Container(
                        padding: EdgeInsets.all(4),
                        decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                        child: Icon(Icons.close, color: Colors.white, size: 12),
                      ),
                    ),
                  ),
                ],
              );
            }

            final newIndex = index - existingCount;
            return Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(File(_portfolioImages[newIndex].path), fit: BoxFit.cover),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _portfolioImages.removeAt(newIndex);
                        _validateStep(0);
                      });
                    },
                    child: Container(
                      padding: EdgeInsets.all(4),
                      decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                      child: Icon(Icons.close, color: Colors.white, size: 12),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Future<void> _pickProfileImage() async {
    if (!mounted) return;
    await showProfileStyleImagePickerSheet(
      context,
      primaryColor: _primaryColor,
      sheetTitle: 'Photo de profil',
      headerIcon: Icons.account_circle_rounded,
      showPreview: _profileImage != null,
      previewTitle: 'Aperçu en plein écran',
      previewSubtitle: 'Voir votre photo actuelle.',
      onPreview: () async {
        if (_profileImage == null || !mounted) return;
        await showDialog<void>(
          context: context,
          builder: (ctx) => Dialog(
            backgroundColor: Colors.black87,
            child: InteractiveViewer(
              child: Image.file(File(_profileImage!.path), fit: BoxFit.contain),
            ),
          ),
        );
      },
      cameraTitle: 'Prendre une photo (selfie)',
      cameraSubtitle: 'Selfie guidé pour votre visage.',
      onCamera: () async {
        try {
          final imagePath = await Navigator.push<String>(
            context,
            MaterialPageRoute(
              builder: (context) => SelfieCameraScreen(
                onImageCaptured: (path) {},
              ),
            ),
          );
          if (mounted && imagePath != null && imagePath.isNotEmpty) {
            setState(() {
              _profileImage = XFile(imagePath);
              _validateStep(0);
            });
            try {
              final persisted = await _persistPickedXFile(_profileImage!, prefix: 'service_profile');
              if (!mounted) return;
              setState(() => _profileImage = persisted);
            } catch (_) {}
          }
        } catch (e) {
          print('Erreur lors de la capture du selfie: $e');
          if (mounted) {
            FancyNotification.show(
              context,
              "La photo n’a pas pu être prise. Réessayez ou choisissez la galerie.",
              type: NotificationType.error,
            );
          }
        }
      },
      galleryTitle: 'Choisir depuis la galerie',
      gallerySubtitle: 'Sélectionner une image existante.',
      onGallery: () async {
        try {
          final XFile? file = await _picker.pickImage(
            source: ImageSource.gallery,
            imageQuality: 70,
          );
          if (mounted && file != null) {
            setState(() {
              _profileImage = file;
              _validateStep(0);
            });
            try {
              final persisted = await _persistPickedXFile(file, prefix: 'service_profile');
              if (!mounted) return;
              setState(() => _profileImage = persisted);
            } catch (_) {}
          }
        } catch (e) {
          print('Erreur lors du choix en galerie: $e');
          if (mounted) {
            FancyNotification.show(
              context,
              "L’image n’a pas pu être sélectionnée. Réessayez avec une autre photo.",
              type: NotificationType.error,
            );
          }
        }
      },
    );
  }

  Future<void> _pickPortfolioImages() async {
    final existingCount = _isEditing ? (_editingPrestation?.images?.length ?? 0) : 0;
    const maxTotal = 10;
    final remaining = maxTotal - _portfolioImages.length - existingCount;
    if (remaining <= 0) {
      if (mounted) {
        FancyNotification.show(
          context,
          'Vous avez atteint la limite de 10 photos de réalisations.',
          isError: true,
        );
      }
      return;
    }

    await showProfileStyleImagePickerSheet(
      context,
      primaryColor: _primaryColor,
      sheetTitle: 'Photos de réalisations',
      headerIcon: Icons.photo_library_rounded,
      cameraTitle: 'Prendre des photos',
      cameraSubtitle: 'Plusieurs prises d’affilée. Fermez l’appareil pour terminer.',
      onCamera: () async {
        try {
          while (mounted) {
            final existingCount = _isEditing ? (_editingPrestation?.images?.length ?? 0) : 0;
            if (_portfolioImages.length + existingCount >= 10) break;
            final image = await _picker.pickImage(
              source: ImageSource.camera,
              imageQuality: 85,
              maxWidth: 1440,
            );
            if (!mounted || image == null) break;
            final persisted = await _persistPickedXFile(image, prefix: 'service_portfolio');
            if (!mounted) return;
            setState(() {
              _markFieldTouched('portfolio_images');
              _portfolioImages.add(persisted);
              _validateStep(0);
            });
          }
        } catch (e) {
          if (mounted) {
            FancyNotification.show(
              context,
              'La photo n’a pas pu être prise. Réessayez.',
              isError: true,
            );
          }
        }
      },
      galleryTitle: 'Choisir depuis la galerie',
      gallerySubtitle: 'Plusieurs photos — jusqu’à $remaining place(s) restante(s).',
      onGallery: () async {
        try {
          final list = await _picker.pickMultiImage(
            imageQuality: 85,
            maxWidth: 1440,
          );
          if (!mounted || list.isEmpty) return;
          final n = list.length > remaining ? remaining : list.length;
          final persisted = <XFile>[];
          for (var i = 0; i < n; i++) {
            try {
              persisted.add(await _persistPickedXFile(list[i], prefix: 'service_portfolio'));
            } catch (_) {
              persisted.add(list[i]);
            }
          }
          if (!mounted) return;
          setState(() {
            _markFieldTouched('portfolio_images');
            _portfolioImages.addAll(persisted);
            _validateStep(0);
          });
          if (list.length > remaining && mounted) {
            FancyNotification.show(
              context,
              'Seules $remaining photo(s) ont été ajoutées (limite 10 au total).',
              type: NotificationType.info,
            );
          }
        } catch (e) {
          if (mounted) {
            FancyNotification.show(
              context,
              'La sélection multiple n’est pas disponible. Réessayez ou choisissez la caméra.',
              isError: true,
            );
          }
        }
      },
    );
  }

  Widget _buildSectionHeader(String title, String subtitle, IconData icon) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: _primaryColor, size: 24),
        ),
        SizedBox(width: _mediumSpace),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: _titleSize,
                  fontWeight: FontWeight.w700,
                  color: _darkColor,
                ),
              ),
              SizedBox(height: 4),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: _captionSize,
                  color: _greyColor,
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
    int maxLines = 1,
    String? fieldKey,
    String? Function(String?)? validator,
    String? helperText,
    String? suffixText,
  }) {
    final hasError = fieldKey != null &&
        _shouldShowError(_currentStep, fieldKey) &&
        (_getFieldError(_currentStep, fieldKey) != null);
    final errorText = hasError ? _getFieldError(_currentStep, fieldKey) : null;

    return Container(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: _bodySize,
              fontWeight: FontWeight.w600,
              color: hasError ? _errorColor : _darkColor,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: maxLines == 1 ? 56 : null,
            child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            maxLines: maxLines,
            validator: validator,
            style: TextStyle(color: Colors.black87, fontSize: _bodySize),
            onChanged: (value) {
              if (mounted) {
                setState(() {
                  if (fieldKey != null) {
                    _markFieldTouched(fieldKey);
                  }
                  _validateStep(_currentStep);
                });
              }
            },
            onTap: () {
              if (mounted) {
                setState(() {
                  if (fieldKey != null) {
                    _markFieldTouched(fieldKey);
                  }
                  _validateStep(_currentStep);
                });
              }
            },
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 15),
              prefixIcon: Icon(icon, color: hasError ? _errorColor : _primaryColor, size: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: hasError ? _errorColor : const Color(0xFFE6E8EC)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: hasError ? _errorColor : const Color(0xFFE6E8EC)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: hasError ? _errorColor : _primaryColor, width: 1.5),
              ),
              filled: true,
              fillColor: Colors.white,
              isDense: maxLines == 1,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: maxLines == 1 ? 0 : 16),
              suffixText: suffixText,
              suffixStyle: TextStyle(
                color: _darkColor,
                fontWeight: FontWeight.w600,
                fontSize: _bodySize,
              ),
            ),
          ),
          ),
          if (helperText != null && helperText.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 2),
              child: Text(
                helperText,
                style: GoogleFonts.inter(
                  fontSize: _captionSize - 1,
                  color: _greyColor,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          if (hasError && errorText != null)
            Padding(
              padding: EdgeInsets.only(top: 6, left: 4),
              child: Text(
                errorText,
                style: GoogleFonts.inter(
                  fontSize: _captionSize,
                  color: _errorColor,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLocationDropdown<T>({
    required String label,
    required T? value,
    required List<T> items,
    required String Function(T) displayText,
    required void Function(T?) onChanged,
  }) {
    return Container(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: _bodySize,
              fontWeight: FontWeight.w600,
              color: _darkColor,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 56,
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE6E8EC)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              isDense: true,
              underline: SizedBox(),
              hint: Text('Sélectionner $label'),
              items: items.map((item) =>
                  DropdownMenuItem(value: item, child: Text(displayText(item)))
              ).toList(),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigation() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: _mediumSpace), // Keep vertical spacing if needed or remove entirely if spacing is handled by parent column.
      // Removed decoration (white background + shadow)
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  setState(() {
                    _currentStep--;
                  });
                  _pageController.animateToPage(
                    _currentStep,
                    duration: Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                },
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: BorderSide(color: _primaryColor),
                ),
                child: Text(
                  'Précédent',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    color: _primaryColor,
                  ),
                ),
              ),
            ),
          if (_currentStep > 0) SizedBox(width: _mediumSpace),
          Expanded(
            flex: _currentStep == 0 ? 1 : 1,
            child: ElevatedButton(
              onPressed: _isLoading ? null : () async {
                if (_currentStep < 3) {
                  final isValid = _validateStep(_currentStep);
                  if (isValid) {
                    setState(() {
                      _hasAttemptedSubmit = false;
                      _currentStep++;
                    });
                    await _pageController.animateToPage(
                      _currentStep,
                      duration: Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  } else {
                    setState(() => _hasAttemptedSubmit = true);
                    final errors = _stepFieldErrors[_currentStep];
                    if (errors != null && errors.isNotEmpty) {
                      final firstError = errors.values.first;
                      FancyNotification.show(
                        context,
                        firstError,
                        isError: true,
                      );
                    }
                  }
                } else {
                  _handleSubmit();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: _isLoading
                  ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
                  : Text(
                _currentStep == 3 ? 'Publier' : 'Suivant',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  fontSize: _bodySize,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _validateStep(int step) {
    // Note: _hasAttemptedSubmit is now set only during navigation/submission

    switch (step) {
      case 0:
        _clearStepFieldErrors(0);

        // Validation de la photo de profil (obligatoire)
        if (_profileImage == null) {
          _setFieldError(0, 'profile_image', 'La photo de profil est requise');
        }

        // Validation des images de portfolio (optionnelles mais recommandées)
        if (_portfolioImages.isEmpty) {
          _setFieldError(0, 'portfolio_images', 'Au moins une photo de réalisation est recommandée');
        }

        _stepValidations[0] = _profileImage != null; // Photo de profil obligatoire
        return _stepValidations[0]!;

      case 1:
        _clearStepFieldErrors(1);
        final title = _titleController.text.trim();
        final description = _descriptionController.text.trim();
        final phone = _phoneController.text.trim();

        if (title.isEmpty) {
          _setFieldError(1, 'title', 'Titre requis');
        }

        if (description.isEmpty) {
          _setFieldError(1, 'description', 'Description requise');
        }

        if (phone.isEmpty) {
          _setFieldError(1, 'phone', 'Téléphone requis');
        } else {
          final digits = phone.replaceAll(RegExp(r'\D'), '');
          if (digits.length < 9) {
            _setFieldError(1, 'phone', 'Numéro invalide (min 9 chiffres)');
          }
        }

        _stepValidations[1] = !_hasFieldErrors(1);
        return _stepValidations[1]!;

      case 2:
        _clearStepFieldErrors(2);
        final priceMin = _priceMinController.text.trim();

        if (priceMin.isEmpty) {
          _setFieldError(2, 'price_min', 'Prix requis');
        } else if (double.tryParse(priceMin) == null || double.parse(priceMin) < 1) {
          _setFieldError(2, 'price_min', 'Prix invalide');
        }

        if (_selectedDays.isEmpty) {
          _setFieldError(2, 'plage_jour', 'Veuillez sélectionner au moins un jour');
        }

        if (_plageHeureController.text.trim().isEmpty) {
          _setFieldError(2, 'plage_heure', 'Heures de prestation requises');
        }

        _stepValidations[2] = !_hasFieldErrors(2);
        return _stepValidations[2]!;

      case 3:
        _clearStepFieldErrors(3);
        final address = _addressController.text.trim();
        final quartierEffective = (() {
          final t = _quartierTextController.text.trim();
          if (t.isNotEmpty) return t;
          return (_selectedQuartier?.name ?? '').trim();
        })();

        if (_isKinshasaSelected) {
          if (_selectedCity == null) _setFieldError(3, 'city', 'Ville requise');
          if (_selectedCommune == null) _setFieldError(3, 'commune', 'Commune requise');
          if (quartierEffective.isEmpty) {
            _setFieldError(3, 'quartier', 'Quartier requis');
          } else if (quartierEffective.length < 3) {
            _setFieldError(3, 'quartier', 'Quartier trop court (min 3 car.)');
          }
        } else {
          if (_cityTextController.text.trim().isEmpty) _setFieldError(3, 'city', 'Ville requise');
          if (_communeTextController.text.trim().isEmpty) _setFieldError(3, 'commune', 'Commune requise');

          if (quartierEffective.isEmpty) {
            _setFieldError(3, 'quartier', 'Quartier requis');
          } else if (quartierEffective.length < 3) {
            _setFieldError(3, 'quartier', 'Quartier trop court (min 3 car.)');
          }
        }

        if (address.isEmpty) {
          _setFieldError(3, 'address', 'Adresse requise');
        } else if (address.length < 5) {
          _setFieldError(3, 'address', 'Adresse trop courte');
        }

        _stepValidations[3] = !_hasFieldErrors(3);
        return _stepValidations[3]!;

      default:
        return false;
    }
  }

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
  }

  void _removeFieldError(int step, String field) {
    _stepFieldErrors[step]?.remove(field);
  }

  String? _getFieldError(int step, String field) {
    return _stepFieldErrors[step]?[field];
  }

  bool _hasFieldErrors(int step) {
    return _stepFieldErrors[step]?.isNotEmpty ?? false;
  }

  void _markFieldTouched(String field) {
    _fieldTouched[field] = true;
  }

  bool _shouldShowError(int step, String field) {
    return _hasAttemptedSubmit || _fieldTouched[field] == true;
  }

  Future<void> _handleSubmit() async {
    FocusScope.of(context).unfocus(); // Fermer le clavier
    print("🚀 [CreateService] ========== DÉBUT _handleSubmit ==========");
    setState(() {
      _hasAttemptedSubmit = true;
    });

    for (final step in [1, 2, 3]) {
      if (_validateStep(step)) continue;
      setState(() => _currentStep = step);
      await _pageController.animateToPage(
        step,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      FancyNotification.show(
        context,
        "Complétez ou corrigez les champs indiqués avant de publier.",
        isError: true,
      );
      return;
    }

    final authCtrl = context.read<AuthentificationCtrl>();
    print("👤 [CreateService] User ID: ${authCtrl.user.userId}, Certified: ${authCtrl.user.isCertified}");

    final subscriptionOk =
    await SubscriptionHelper.ensurePremiumForSubmit(context: context);
    if (!subscriptionOk || !mounted) return;

    setState(() => _isLoading = true);

    try {
      // Préparer les images en base64
      List<Map<String, String>> imagesPayload = [];

      // Récupération ID depuis local storage pour robustesse
      final storageData = _storage.read<Map<String, dynamic>>(StockageKeys.userKey);
      final storedUserId = storageData?['user']?['userId'] ?? authCtrl.user.userId ?? 0;

      print("📸 [CreateService] Préparation des images...");

      // Photo de profil (obligatoire, en base64)
      String? profileBase64;
      if (_profileImage != null) {
        final f = File(_profileImage!.path);
        if (!await f.exists()) {
          FancyNotification.show(
            context,
            "La photo de profil n'est plus disponible. Reprenez-la puis réessayez.",
            isError: true,
          );
          setState(() => _isLoading = false);
          return;
        }
        final profileBytes = await f.readAsBytes();
        profileBase64 = base64Encode(profileBytes);
        print("✅ [CreateService] Photo de profil convertie en base64");
      } else {
        print("❌ [CreateService] Aucune photo de profil sélectionnée");
        FancyNotification.show(
          context,
          "Ajoutez une photo de profil pour présenter votre service.",
          isError: true,
        );
        setState(() => _isLoading = false);
        return;
      }

      // Images de portfolio (multiples)
      for (var img in _portfolioImages) {
        final f = File(img.path);
        if (!await f.exists()) {
          // Ne pas crasher si une image a été nettoyée du cache.
          continue;
        }
        try {
          final bytes = await f.readAsBytes();
          final base64Image = base64Encode(bytes);
          imagesPayload.add({"image": base64Image});
        } catch (_) {}
      }

      // Si aucune image de portfolio n'est ajoutée, ajouter une image vide pour éviter erreur backend si requis
      if (imagesPayload.isEmpty) {
        imagesPayload.add({"image": ""});
      }

      print("📸 [CreateService] Photo de profil: ${profileBase64 != null ? 'Oui' : 'Non'}, Images portfolio: ${imagesPayload.length}");

      // Convertir les jours sélectionnés en string
      final selectedDaysString = _selectedDays.join(', ');
      print("📅 [CreateService] Jours sélectionnés: $selectedDaysString");

      // Vérifier que serviceId est bien défini (ID du compte, pas typeAccountId)
      if (_serviceId == null) {
        print("❌ [CreateService] serviceId est null, tentative de récupération...");
        // Réessayer de charger les données
        await _loadUserData();
        if (_serviceId == null) {
          FancyNotification.show(
            context,
            "Nous ne retrouvons pas votre type de compte. Déconnectez-vous puis reconnectez-vous, puis réessayez.",
            isError: true,
          );
          setState(() => _isLoading = false);
          return;
        }
      }

      print("📤 [CreateService] Envoi avec serviceId (ID du compte): $_serviceId");

      dynamic finalResponse;
      final ctrl = context.read<ServiceController>();

      if (_isEditing) {
        final qText = _quartierTextController.text.trim();
        final quartierValue = qText.isNotEmpty ? qText : (_selectedQuartier?.name ?? '');
        final matchedSelected = _selectedQuartier != null &&
            (qText.isNotEmpty) &&
            (( _selectedQuartier?.name ?? '').trim().toLowerCase() == qText.toLowerCase());
        final updateData = {
          "id": _editingPrestation!.id,
          "userId": storedUserId,
          "serviceId": _serviceId!,
          "deviseId": _selectedDevise?.id ?? 1,
          "title": _titleController.text.trim(),
          "description": _descriptionController.text.trim(),
          "experience": _experienceController.text.trim(),
          "profile": profileBase64 ?? _editingPrestation!.profile ?? "",
          "cvFile": "", // Non géré pour l'instant
          "plageJourPrestation": selectedDaysString,
          "plageHeurePrestation": _plageHeureController.text.trim(),
          "minPrice": double.tryParse(_priceMinController.text) ?? 0.0,
          "maxPrice": double.tryParse(_priceMinController.text) ?? 0.0,
          "address": _addressController.text.trim(),
          "communeValue": _isKinshasaSelected ? (_selectedCommune?.name ?? "") : _communeTextController.text.trim(),
          // Si l'utilisateur tape un quartier absent de la liste, c'est **quartierValue** qui doit porter la valeur.
          "quartierValue": quartierValue,
          "cityValue": _isKinshasaSelected ? (_selectedCity?.name ?? "") : _cityTextController.text.trim(),
          "countryValue": "RDC",
          "cityId": _isKinshasaSelected && _selectedCity != null ? (_selectedCity?.cityId ?? 0) : 0,
          "communeId": _isKinshasaSelected && _selectedCommune != null ? (_selectedCommune?.communeId ?? 0) : 0,
          // On ne remplit quartierId que si la sélection correspond bien au texte (évite mismatch).
          "quartierId": _isKinshasaSelected && matchedSelected ? (_selectedQuartier?.quartierId ?? 0) : 0,
          // Champs sensibles non modifiables
          "isCertified": _editingPrestation!.isCertified ?? true,
          "isActive": _editingPrestation!.isActive ?? true,
          "certified": _editingPrestation!.isCertified ?? true,
        };

        print("📡 [CreateService] Appel à updatePrestation (id: ${_editingPrestation!.id})...");
        finalResponse = await ctrl.updatePrestation(_editingPrestation!.id!, updateData);
      } else {
        final qText = _quartierTextController.text.trim();
        final quartierValue = qText.isNotEmpty ? qText : (_selectedQuartier?.name ?? '');
        final matchedSelected = _selectedQuartier != null &&
            (qText.isNotEmpty) &&
            (( _selectedQuartier?.name ?? '').trim().toLowerCase() == qText.toLowerCase());
        final payload = {
          "prestation": {
            "userId": storedUserId,
            "serviceId": _serviceId!,
            "deviseId": _selectedDevise?.id ?? 1,
            "title": _titleController.text.trim(),
            "profile": profileBase64 ?? "",
            "description": _descriptionController.text.trim(),
            "experience": _experienceController.text.trim(),
            "plageJourPrestation": selectedDaysString,
            "plageHeurePrestation": _plageHeureController.text.trim(),
            "minPrice": double.tryParse(_priceMinController.text) ?? 0.0,
            "maxPrice": double.tryParse(_priceMinController.text) ?? 0.0,
            "address": _addressController.text.trim(),
            "communeValue": _isKinshasaSelected ? (_selectedCommune?.name ?? "") : _communeTextController.text.trim(),
            // Si l'utilisateur tape un quartier absent de la liste, c'est **quartierValue** qui doit porter la valeur.
            "quartierValue": quartierValue,
            "cityValue": _isKinshasaSelected ? (_selectedCity?.name ?? "") : _cityTextController.text.trim(),
            "countryValue": "RDC",
            "cityId": _isKinshasaSelected && _selectedCity != null ? (_selectedCity?.cityId ?? 0) : 0,
            "communeId": _isKinshasaSelected && _selectedCommune != null ? (_selectedCommune?.communeId ?? 0) : 0,
            // On ne remplit quartierId que si la sélection correspond bien au texte (évite mismatch).
            "quartierId": _isKinshasaSelected && matchedSelected ? (_selectedQuartier?.quartierId ?? 0) : 0,
            "districtId": _isKinshasaSelected && _selectedDistrict != null ? (_selectedDistrict?.districtId ?? 0) : 0
          },
          "images": imagesPayload
        };

        print("📡 [CreateService] Appel à createPrestation...");
        finalResponse = await ctrl.createPrestation(payload);
      }

      print("📥 [CreateService] Réponse reçue - status: ${finalResponse.status}");

      if (!mounted) return;

      if (finalResponse.status == true) {
        print("✅ [CreateService] Succès!");
        SnackbarForCasa.success(
          context,
          _isEditing ? "Modifications enregistrées." : "Votre annonce de service est publiée.",
        );
        await Future.delayed(Duration(milliseconds: 1500));
        if (mounted) {
          if (_isEditing) {
            Navigator.pop(context, true);
          } else {
            Navigator.pushNamedAndRemoveUntil(
              context,
              Routes.bottomPageRoute,
                  (route) => false,
              arguments: {'shouldRefresh': true},
            );
          }
        }
      } else {
        reportApiFailureToCrashlytics(
          'CreateServicePostPage',
          response: finalResponse,
          reason: _isEditing ? 'update_prestation' : 'create_prestation',
        );
        String errorMessage = finalResponse.errorMsg ??
            "La publication n’a pas abouti. Vérifiez les champs et réessayez.";
        print("❌ [CreateService] Échec: $errorMessage");
        FancyNotification.show(context, _sanitizeError(errorMessage), type: NotificationType.error);
      }
    } catch (e, stackTrace) {
      reportApiFailureToCrashlytics(
        'CreateServicePostPage',
        error: e,
        stackTrace: stackTrace,
        reason: 'create_prestation_exception',
      );
      print("❌ [CreateService] EXCEPTION: $e");
      print("📚 [CreateService] Stack trace: $stackTrace");
      FancyNotification.show(
        context,
        "L’envoi a été interrompu. Vérifiez la connexion et réessayez.",
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      print("🏁 [CreateService] ========== FIN _handleSubmit ==========");
    }
  }

  Widget _buildCitySuggestionField() {
    final hasError = _shouldShowError(3, 'city') && _getFieldError(3, 'city') != null;
    final errorText = hasError ? _getFieldError(3, 'city') : null;

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
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: hasError ? _errorColor : const Color(0xFFE6E8EC)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: hasError ? _errorColor : const Color(0xFFE6E8EC)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: hasError ? _errorColor : _primaryColor, width: 1.5),
                ),
                isDense: true,
                constraints: const BoxConstraints(minHeight: 56, maxHeight: 56),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                errorText: null,
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
    final hasError = _shouldShowError(3, fieldKey) && _getFieldError(3, fieldKey) != null;
    final errorText = hasError ? _getFieldError(3, fieldKey) : null;

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
            if (mounted) {
              setState(() {
                _markFieldTouched(fieldKey);
                controller.text = selection;
                if (fieldKey == 'quartier') {
                  // Associer aussi l'objet Quartier quand on peut (utile pour quartierId).
                  final lower = selection.trim().toLowerCase();
                  final pool = _kinshasaQuartiers.isNotEmpty ? _kinshasaQuartiers : _availableQuartiers;
                  final match = pool.where((q) => (q.name ?? '').trim().toLowerCase() == lower).toList();
                  _selectedQuartier = match.isNotEmpty ? match.first : null;
                }
                _validateStep(3);
              });
            }
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
                if (mounted) {
                  setState(() {
                    _markFieldTouched(fieldKey);
                    if (fieldKey == 'quartier') {
                      final v = value.trim().toLowerCase();
                      final curName = (_selectedQuartier?.name ?? '').trim().toLowerCase();
                      if (v.isEmpty || (curName.isNotEmpty && v != curName)) {
                        _selectedQuartier = null;
                      } else if (v.isNotEmpty && _selectedQuartier == null) {
                        // Si le texte correspond exactement à un quartier connu, lier l'objet.
                        final pool = _kinshasaQuartiers.isNotEmpty ? _kinshasaQuartiers : _availableQuartiers;
                        final match = pool.where((q) => (q.name ?? '').trim().toLowerCase() == v).toList();
                        _selectedQuartier = match.isNotEmpty ? match.first : null;
                      }
                    }
                    _validateStep(3);
                  });
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
                prefixIcon: Icon(Icons.place_rounded, color: hasError ? _errorColor : _primaryColor, size: 20),
                filled: true,
                fillColor: Colors.white,
                isDense: true,
                constraints: const BoxConstraints(minHeight: 56, maxHeight: 56),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: hasError ? _errorColor : const Color(0xFFE6E8EC)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: hasError ? _errorColor : const Color(0xFFE6E8EC)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: hasError ? _errorColor : _primaryColor, width: 1.5),
                ),
                errorText: null,
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
    String? fieldKey,
    String? hintText,
    bool isRequired = true,
  }) {
    final hasError = fieldKey != null && _shouldShowError(3, fieldKey) && _getFieldError(3, fieldKey) != null;
    final errorText = hasError ? _getFieldError(3, fieldKey) : null;

    return Container(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8, left: 2),
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
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: items.isEmpty
                  ? null
                  : () async {
                      final picked = await showCasaChoiceSheet<T>(
                        context: context,
                        title: label,
                        icon: icon,
                        selected: value,
                        options: casaChoicesFromLabels(items, displayText),
                      );
                      if (!mounted || picked == null) return;
                      setState(() {
                        _markFieldTouched(fieldKey ?? label.toLowerCase());
                        onChanged(picked as T);
                        _validateStep(_currentStep);
                      });
                    },
              child: Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: hasError ? _errorColor : const Color(0xFFE6E8EC),
                    width: hasError ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(icon, size: 18, color: hasError ? _errorColor : _primaryColor),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        value == null ? (hintText ?? 'Sélectionnez...') : displayText(value),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: value == null ? _greyColor : _darkColor,
                          fontSize: _bodySize,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Icon(Icons.keyboard_arrow_down_rounded, color: _primaryColor),
                  ],
                ),
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

  Future<void> _pickDevise() async {
    final devises = context.read<ServiceController>().devisesList;
    if (devises.isEmpty) return;
    final picked = await showCasaChoiceSheet<int>(
      context: context,
      title: 'Devise',
      icon: Icons.payments_rounded,
      selected: _selectedDevise?.id,
      options: [
        for (final devise in devises)
          if (devise.id != null)
            CasaChoice<int>(
              value: devise.id!,
              title: devise.displaySymbol.trim().isEmpty ? (devise.name ?? 'Devise') : devise.displaySymbol,
              subtitle: devise.name,
            ),
      ],
    );
    if (picked == null || !mounted) return;
    final match = devises.where((devise) => devise.id == picked);
    if (match.isEmpty) return;
    setState(() {
      _markFieldTouched('currency');
      _selectedDevise = match.first;
      _validateStep(2);
    });
  }

  Widget _buildCvUploadSection() {
    return Container(
      margin: EdgeInsets.zero,
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _selectedCvFile != null ? _successColor : const Color(0xFFE6E8EC),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: _pickCvFile,
        borderRadius: BorderRadius.circular(14),
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
                style: GoogleFonts.inter(
                  color: _darkColor,
                  fontSize: _bodySize,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (_selectedCvFile != null) ...[
                SizedBox(height: 4),
                Text(
                  _selectedCvFile!.path.split('/').last,
                  style: GoogleFonts.inter(
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
                  label: Text('Supprimer', style: GoogleFonts.inter(color: _errorColor, fontSize: _captionSize)),
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
                  style: GoogleFonts.inter(
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
            "Ce fichier dépasse 5 Mo. Choisissez un document plus léger ou compressez-le, puis réessayez.",
            type: NotificationType.error,
          );
          return;
        }

        setState(() {
          _markFieldTouched('cv_file');
          _selectedCvFile = file;
          _validateStep(2);
        });

        SnackbarForCasa.success(context, "Votre CV a bien été ajouté.");
      }
    } catch (e) {
      print('Erreur lors de la sélection du CV: $e');
      FancyNotification.show(
        context,
        "Le fichier CV n’a pas pu être ajouté. Réessayez avec un PDF ou un document plus léger.",
        type: NotificationType.error,
      );
    }
  }

  void _removeCvFile() {
    setState(() {
      _markFieldTouched('cv_file');
      _selectedCvFile = null;
      _validateStep(2);
    });
  }

  Widget _buildPhoneField() {
    final errorText = _getFieldError(1, 'phone');
    final hasError = errorText != null && errorText.isNotEmpty && _shouldShowError(1, 'phone');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8, left: 2),
          child: Row(
            children: [
              Text(
                'Téléphone',
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
        SizedBox(
          height: 56,
          child: TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            onChanged: (value) {
              if (mounted) {
                setState(() {
                  _markFieldTouched('phone');
                  _validateStep(1);
                });
              }
            },
            onTap: () {
              if (mounted) {
                setState(() {
                  _markFieldTouched('phone');
                  _validateStep(1);
                });
              }
            },
            style: TextStyle(
              fontSize: _bodySize,
              color: _darkColor,
            ),
            decoration: InputDecoration(
              hintText: '810000000',
              hintStyle: TextStyle(
                fontSize: _bodySize,
                color: Colors.grey.shade500,
              ),
              prefixIcon: _buildCountryCodeDropdown(),
              filled: true,
              fillColor: Colors.white,
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: hasError ? _errorColor : const Color(0xFFE6E8EC)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: hasError ? _errorColor : const Color(0xFFE6E8EC)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: hasError ? _errorColor : _primaryColor, width: 1.5),
              ),
              errorText: null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
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
    );
  }

  Widget _buildCountryCodeDropdown() {
    return Container(
      width: 140,
      padding: EdgeInsets.only(left: 8, right: 4),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedCountryCode,
          isExpanded: true,
          isDense: true,
          icon: Icon(Icons.arrow_drop_down_rounded, color: _primaryColor, size: 20),
          style: TextStyle(color: _darkColor, fontSize: 14, fontWeight: FontWeight.w500),
          items: _countryFlags.entries.map((entry) {
            final countryName = _getCountryNameFromCode(entry.key);
            return DropdownMenuItem(
              value: entry.key,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(entry.value, style: TextStyle(fontSize: 16)),
                  SizedBox(width: 8),
                  Text(entry.key, style: TextStyle(fontSize: 13)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      countryName,
                      style: TextStyle(fontSize: 12, color: _greyColor),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (String? newValue) {
            if (newValue != null) {
              setState(() {
                _markFieldTouched('phone');
                _selectedCountryCode = newValue;
                _validateStep(1);
              });
            }
          },
        ),
      ),
    );
  }

  static const List<String> _weekDays = [
    'Lundi',
    'Mardi',
    'Mercredi',
    'Jeudi',
    'Vendredi',
    'Samedi',
    'Dimanche',
  ];

  Widget _buildDaySelector() {
    final hasError = _shouldShowError(2, 'plage_jour') && _selectedDays.isEmpty;
    final ordered = _weekDays.where(_selectedDays.contains).toList();
    final label = ordered.isEmpty ? 'Choisir les jours' : ordered.join(', ');

    return Container(
      margin: EdgeInsets.only(bottom: _mediumSpace),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Jours',
            style: GoogleFonts.inter(
              fontSize: _bodySize,
              fontWeight: FontWeight.w600,
              color: hasError ? _errorColor : _darkColor,
            ),
          ),
          const SizedBox(height: 8),
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: _openAvailabilitySheet,
              child: Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: hasError ? _errorColor : const Color(0xFFE6E8EC),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today_rounded, color: _primaryColor, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: _bodySize,
                          fontWeight: FontWeight.w600,
                          color: ordered.isEmpty ? _greyColor : _primaryColor,
                        ),
                      ),
                    ),
                    Icon(Icons.keyboard_arrow_down_rounded, color: _primaryColor),
                  ],
                ),
              ),
            ),
          ),
          if (hasError)
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 4),
              child: Text(
                'Veuillez sélectionner au moins un jour',
                style: GoogleFonts.inter(
                  fontSize: _captionSize,
                  color: _errorColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _openAvailabilitySheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModal) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE6E8EC),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Disponibilité',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    ..._weekDays.map((day) {
                      final on = _selectedDays.contains(day);
                      return InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          setState(() {
                            if (on) {
                              _selectedDays.remove(day);
                            } else {
                              _selectedDays.add(day);
                            }
                            _markFieldTouched('plage_jour');
                            _validateStep(2);
                          });
                          setModal(() {});
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  day,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: on ? _primaryColor : const Color(0xFF1A1D26),
                                  ),
                                ),
                              ),
                              Container(
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: on ? _primaryColor : Colors.white,
                                  border: Border.all(
                                    color: on ? _primaryColor : const Color(0xFFD0D5DD),
                                    width: 1.5,
                                  ),
                                ),
                                child: on
                                    ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text(
                          'Terminé',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }


  Widget _buildReadOnlyServiceTypeField() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE6E8EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.workspace_premium_rounded, color: _primaryColor, size: 20),
              SizedBox(width: 8),
              Text(
                'Catégorie de Service (Type de Compte)',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _greyColor,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            _userServiceType != null
                ? _userServiceType![0].toUpperCase() + _userServiceType!.substring(1)
                : 'Non défini',
            style: GoogleFonts.inter( // Utilisation de Inter
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _darkColor,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Vous vous êtes inscrit avec un compte ${_userServiceType ?? "Prestataire"}, donc vous ne pouvez proposer qu\'un service lié à ce compte ${_userServiceType ?? "Prestataire"}, pas un autre.',
            style: GoogleFonts.inter(
              fontSize: 11,
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
  String _sanitizeError(String? error) {
    if (error == null || error.isEmpty) {
      return "Impossible de publier pour l’instant. Réessayez dans quelques instants.";
    }
    final lower = error.toLowerCase();

    if (lower.contains("internal server error") ||
        lower.contains("exception") ||
        lower.contains("status")) {
      return "Le service est momentanément indisponible. Patientez un peu puis réessayez.";
    }
    return error;
  }
}