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
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/FancyNotification.dart';
import '../utils/StockageKeys.dart';

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
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _whatsappController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _experienceController = TextEditingController();
  final TextEditingController _availableHoursController = TextEditingController();
  final TextEditingController _teamSizeController = TextEditingController();
  final TextEditingController _postalCodeController = TextEditingController();
  
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
  String? _selectedVacationType;
  String? _selectedLandType;
  String? _selectedWarehouseType;
  int? _selectedStarRating;
  LatLng? _selectedLocation;
  final ImagePicker _picker = ImagePicker();
  List<XFile> _selectedImages = [];
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

  final stockage = GetStorage();
  late final profile = stockage.read(StockageKeys.profileKey);
  late var fullname = profile["fullname"];

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
    _initSharedPreferences();
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
          if (_availableCities.isNotEmpty) {
            _selectedCity = _availableCities.first;
            _updateDistrictsForCity();
          }
        });
      }
    } catch (e) {
      print("Erreur lors du chargement des données de localisation: $e");
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

  @override
  void dispose() {
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
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _buildTextField(_priceController, 'Prix', Icons.attach_money_rounded, keyboardType: TextInputType.number),
              ),
              SizedBox(width: _smallSpace),
              Expanded(
                child: _buildPriceUnitDropdown(),
              ),
            ],
          ),
          SizedBox(height: _largeSpace),
          if (_selectedServiceType == ServiceType.majordhomme) ...[
            _buildModernSectionHeader(title: 'Spécialités', icon: Icons.star_rounded),
            SizedBox(height: _mediumSpace),
            _buildSpecialtiesGrid(),
            SizedBox(height: _largeSpace),
            _buildTextField(_experienceController, 'Années d\'expérience', Icons.work_history_rounded, keyboardType: TextInputType.number),
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

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {int maxLines = 1, TextInputType? keyboardType}) {
    return Container(
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
        ),
        onChanged: (_) => _validateStep1(),
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
          _buildTextField(_phoneController, 'Téléphone', Icons.phone_rounded, keyboardType: TextInputType.phone),
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
      children: [
        _buildLocationDropdown<CityModel>(
          'Ville',
          _selectedCity?.name ?? 'Sélectionner une ville',
          _availableCities,
          (city) => setState(() {
            _selectedCity = city;
            _updateDistrictsForCity();
          }),
          Icons.location_city_rounded,
        ),
        SizedBox(height: _mediumSpace),
        if (_availableDistricts.isNotEmpty)
          _buildLocationDropdown<DistrictModel>(
            'District',
            _selectedDistrict?.name ?? 'Sélectionner un district',
            _availableDistricts,
            (district) => setState(() {
              _selectedDistrict = district;
              _updateCommunesForDistrict();
            }),
            Icons.map_rounded,
          ),
        SizedBox(height: _mediumSpace),
        if (_availableCommunes.isNotEmpty)
          _buildLocationDropdown<CommuneModel>(
            'Commune',
            _selectedCommune?.name ?? 'Sélectionner une commune',
            _availableCommunes,
            (commune) => setState(() {
              _selectedCommune = commune;
              _updateQuartiersForCommune();
            }),
            Icons.business_rounded,
          ),
        SizedBox(height: _mediumSpace),
        if (_availableQuartiers.isNotEmpty)
          _buildLocationDropdown<QuartierModel>(
            'Quartier',
            _selectedQuartier?.name ?? 'Sélectionner un quartier',
            _availableQuartiers,
            (quartier) => setState(() => _selectedQuartier = quartier),
            Icons.home_work_rounded,
          ),
      ],
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
              onPressed: _isLoading ? null : _handleNextOrSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
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
        setState(() => _currentStep++);
      } else {
        _showStepErrors();
      }
    } else {
      _handleCreateService();
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
    if (_priceController.text.trim().isEmpty) {
      errors.add('Le prix est requis');
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
    if (_phoneController.text.trim().isEmpty) {
      errors.add('Le numéro de téléphone est requis');
    }
    if (_selectedCity == null) {
      errors.add('Veuillez sélectionner une ville');
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
      return;
    }

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

      // Construire la map de base
      final serviceData = <String, dynamic>{
        "title": _titleController.text.trim(),
        "description": _descriptionController.text.trim(),
        "serviceType": _selectedServiceType?.value,
        "price": double.tryParse(_priceController.text) ?? 0.0,
        "priceUnit": _selectedPriceUnit,
        "phone": _phoneController.text.trim(),
        "email": _emailController.text.trim().isNotEmpty ? _emailController.text.trim() : null,
        "whatsapp": _whatsappController.text.trim().isNotEmpty ? _whatsappController.text.trim() : null,
        "address": _addressController.text.trim(),
        "cityId": _selectedCity?.cityId,
        "communeId": _selectedCommune?.communeId,
        "quartierId": _selectedQuartier?.quartierId,
        "districtId": _selectedDistrict?.districtId,
        "postalCode": _postalCodeController.text.trim(),
        "isAvailable": _isAvailable,
        "availableDays": _selectedDays.toList(),
        "availableHours": _availableHoursController.text.trim(),
        "images": imagesBase64,
        "userId": userId ?? 1,
        "username": fullname,
      };

      // Ajouter les champs spécifiques selon le type de service
      if (_selectedServiceType == ServiceType.majordhomme) {
        serviceData["experienceYears"] = int.tryParse(_experienceController.text) ?? 0;
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
        FancyNotification.show(context, errorMessage, isError: true);
      }
    } catch (e) {
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

