import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:casa/controllers/PropertyCtrl.dart';
import 'package:casa/controllers/LocationController.dart';
import 'package:casa/models/CityModel.dart';
import 'package:casa/models/CommuneModel.dart';
import 'package:casa/models/DistrictModel.dart';
import 'package:casa/models/QuartierModel.dart';
import 'package:casa/models/PropertyModel.dart';
import 'package:casa/utils/FancyNotification.dart';
import 'package:casa/utils/Routes.dart';
import 'package:casa/utils/networkCheck.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:casa/widgets/SnackbarHelper.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:casa/utils/city_suggestions.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';

import '../utils/StockageKeys.dart';
import '../utils/requetes.dart' show HttpResponse;

class EditPropertyPage extends StatefulWidget {
  final PropertyModel property;

  const EditPropertyPage({Key? key, required this.property}) : super(key: key);

  @override
  _EditPropertyPageState createState() => _EditPropertyPageState();
}

class _EditPropertyPageState extends State<EditPropertyPage> {
  // Couleurs Premium & Audacieuses
  final Color _primaryColor = Color(0xFF1976D2);
  final Color _secondaryColor = Color(0xFF0D47A1);
  final Color _accentColor = Color(0xFF2196F3);
  final Color _darkColor = Color(0xFF0F172A);
  final Color _lightColor = Color(0xFFF8FAFC);
  final Color _greyColor = Color(0xFF64748B);
  final Color _successColor = Color(0xFF10B981);
  final Color _warningColor = Color(0xFFF59E0B);
  final Color _errorColor = Color(0xFFEF4444);
  final Color _cardColor = Colors.white;
  final Color _borderColor = Color(0xFFE2E8F0);

  // Styles de texte
  late final TextStyle _titleStyle = GoogleFonts.outfit(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: _darkColor,
  );

  late final TextStyle _subtitleStyle = GoogleFonts.outfit(
    fontSize: 16,
    color: _greyColor,
    fontWeight: FontWeight.w500,
  );

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
  final TextEditingController _cityTextController = TextEditingController();
  final TextEditingController _communeTextController = TextEditingController();
  final TextEditingController _quartierTextController = TextEditingController();

  // State variables
  bool _isForRent = true;
  bool _isLoading = false;
  Set<String> _selectedAmenities = {};
  LatLng? _selectedLocation;
  final ImagePicker _picker = ImagePicker();
  int _currentStep = 0;

  String? _selectedCategory;
  String? _selectedElectric;
  String? _selectedWater;

  // Location variables
  CityModel? _selectedCity;
  DistrictModel? _selectedDistrict;
  CommuneModel? _selectedCommune;
  QuartierModel? _selectedQuartier;
  bool get _isKinshasaSelected =>
      (_selectedCity?.cityId == 1) ||
      (_selectedCity?.name?.toLowerCase().trim() ?? '') == 'kinshasa' ||
      (_cityTextController.text.toLowerCase().trim() == 'kinshasa');

  List<CityModel> _availableCities = [];
  List<DistrictModel> _availableDistricts = [];
  List<CommuneModel> _availableCommunes = [];
  List<QuartierModel> _availableQuartiers = [];

  // Categories d'images
  final List<ImageCategory> _imageCategories = [
    ImageCategory(
      id: 'propertyImage',
      name: 'Photos principales',
      icon: FontAwesomeIcons.home,
      color: Color(0xFF1976D2),
    ),
    ImageCategory(
      id: 'propertyImageRoom',
      name: 'Chambres',
      icon: FontAwesomeIcons.bed,
      color: Color(0xFF1976D2),
    ),
    ImageCategory(
      id: 'propertyImageLivingRoom',
      name: 'Salon',
      icon: FontAwesomeIcons.couch,
      color: Color(0xFF1976D2),
    ),
    ImageCategory(
      id: 'propertyImageKitchen',
      name: 'Cuisine',
      icon: FontAwesomeIcons.kitchenSet,
      color: Color(0xFF1976D2),
    ),
  ];

  final stockage = GetStorage();
  late final profile = stockage.read(StockageKeys.profileKey);
  late var fullname = (profile is Map) ? (profile["fullname"] ?? "Utilisateur") : "Utilisateur";

  // Images: Map pour stocker les nouvelles images (XFile) et les URLs existantes
  Map<String, List<XFile>> _newImages = {}; // Nouvelles images à uploader
  Map<String, List<String>> _existingImageUrls = {}; // URLs des images existantes

  final List<Map<String, dynamic>> _electricOptions = [
    {'value': '80', 'label': 'Élevée'},
    {'value': '60', 'label': 'Bonne'},
    {'value': '40', 'label': 'Moyenne'},
    {'value': '20', 'label': 'Faible'},
  ];

  final List<Map<String, dynamic>> _waterOptions = [
    {'value': '80', 'label': 'Excellente'},
    {'value': '60', 'label': 'Bonne'},
    {'value': '40', 'label': 'Moyenne'},
    {'value': '20', 'label': 'Faible'},
  ];

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

  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPropertyData();
      _loadLocationData();
    });
  }

  void _loadPropertyData() {
    final property = widget.property;

    // Informations de base
    _titleController.text = property.title ?? '';
    _descriptionController.text = property.description ?? '';
    _priceController.text = property.price?.toStringAsFixed(0) ?? '';
    _addressController.text = property.address ?? '';
    _postalCodeController.text = property.postalCode ?? '243';
    _areaController.text = property.surface?.toStringAsFixed(1) ?? '';
    _bedroomsController.text = property.bedrooms?.toString() ?? '';
    _bathroomsController.text = property.bathroom?.toString() ?? '';
    _livingRoomsController.text = property.livingRoom?.toString() ?? '';
    _kitchensController.text = property.kitchen?.toString() ?? '';
    _roomsController.text = property.rooms?.toString() ?? '';
    _floorController.text = property.floor?.toString() ?? '';
    _electricController.text = property.electric?.toString() ?? '';
    _guaranteeController.text = property.guarantee ?? '';

    // Type de transaction
    _isForRent = property.transactionType?.toLowerCase() == 'location';

    // Type de propriété - convertir l'ID en nom
    if (property.propertyTypeId != null) {
      final Map<int, String> typeMap = {
        1: 'Studio',
        2: 'Apparts',
        3: 'Maisons',
        4: 'Bureau',
        5: 'Hotels',
        6: 'Vacances',
      };
      _selectedCategory = typeMap[property.propertyTypeId] ?? 'Apparts';
    }

    // Services
    if (property.electric != null) {
      _selectedElectric = property.electric.toString();
    }
    if (property.water != null) {
      _selectedWater = property.water.toString();
    }

    // Features/Amenities
    if (property.features != null && property.features!.isNotEmpty) {
      _selectedAmenities = property.features!
          .map((f) => f.name ?? '')
          .where((name) => name.isNotEmpty)
          .toSet();
    }

    // Coordonnées GPS
    if (property.latitude != null && property.longitude != null) {
      _selectedLocation = LatLng(property.latitude!, property.longitude!);
    }

    // Location textuelle
    _cityTextController.text = property.cityValue ?? '';
    _communeTextController.text = property.communeValue ?? '';
    _quartierTextController.text = property.quartierValue ?? '';

    // Images existantes (URLs)
    _existingImageUrls['propertyImage'] = property.propertyImage
            ?.map((img) => img.path ?? '')
            .where((url) => url.isNotEmpty)
            .toList() ??
        [];
    _existingImageUrls['propertyImageRoom'] = property.propertyImageRoom
            ?.map((img) => img.path ?? '')
            .where((url) => url.isNotEmpty)
            .toList() ??
        [];
    _existingImageUrls['propertyImageLivingRoom'] = property.propertyImageLivingRoom
            ?.map((img) => img.path ?? '')
            .where((url) => url.isNotEmpty)
            .toList() ??
        [];
    _existingImageUrls['propertyImageKitchen'] = property.propertyImageKitchen
            ?.map((img) => img.path ?? '')
            .where((url) => url.isNotEmpty)
            .toList() ??
        [];

    // Initialiser les nouvelles images
    _imageCategories.forEach((category) {
      _newImages[category.id] = [];
    });

    setState(() {});
  }

  Future<void> _loadLocationData() async {
    final locationCtrl = Provider.of<LocationController>(context, listen: false);
    
    // Charger les villes
    await locationCtrl.getAllCities();
    _availableCities = locationCtrl.cities;

    // Sélectionner la ville si c'est Kinshasa
    if (widget.property.cityValue?.toLowerCase() == 'kinshasa' || 
        widget.property.cityId == 1) {
      try {
        _selectedCity = _availableCities.firstWhere(
          (c) => c.cityId == 1 || c.name?.toLowerCase() == 'kinshasa',
        );
        // Charger districts pour Kinshasa
        await locationCtrl.getAllDistricts();
        _availableDistricts = locationCtrl.getDistrictsForCity(1);

        // Charger commune si disponible
        if (widget.property.communeId != null) {
          await locationCtrl.getAllCommunes();
          _availableCommunes = locationCtrl.communes;
          
          try {
            _selectedCommune = _availableCommunes.firstWhere(
              (c) => c.communeId == widget.property.communeId,
            );
            // Charger quartiers
            if (widget.property.quartierId != null) {
              await locationCtrl.getAllQuartiers();
              _availableQuartiers = locationCtrl.getQuartiersForCommune(widget.property.communeId!);
              
              try {
                _selectedQuartier = _availableQuartiers.firstWhere(
                  (q) => q.quartierId == widget.property.quartierId,
                );
              } catch (e) {
                print("Quartier non trouvé: ${widget.property.quartierId}");
              }
            }
          } catch (e) {
            print("Commune non trouvée: ${widget.property.communeId}");
          }
        }
      } catch (e) {
        print("Ville Kinshasa non trouvée");
      }
    } else {
      // Pour les autres villes, utiliser les champs texte
      _selectedCity = null;
    }

    if (mounted) {
      setState(() {});
    }
  }

  PropertyModel get property => widget.property;


  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    _guaranteeController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _electricController.dispose();
    _bedroomsController.dispose();
    _bathroomsController.dispose();
    _livingRoomsController.dispose();
    _kitchensController.dispose();
    _areaController.dispose();
    _floorController.dispose();
    _roomsController.dispose();
    _postalCodeController.dispose();
    _cityTextController.dispose();
    _communeTextController.dispose();
    _quartierTextController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _lightColor,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(
            child: _buildProgressIndicator(),
          ),
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            sliver: SliverToBoxAdapter(
              child: Form(
                key: _formKey,
                child: AnimatedSwitcher(
                  duration: Duration(milliseconds: 400),
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: Offset(0.05, 0),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: _buildCurrentStep(),
                ),
              ),
            ),
          ),
          // Espace pour le bouton du bas
          SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
      bottomSheet: _buildBottomActionBar(),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: _primaryColor,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: EdgeInsets.only(left: _currentStep == 0 ? 56 : 20, bottom: 16),
        title: Text(
          'Modifier l\'annonce',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w600,
            color: Colors.white,
            fontSize: 20,
          ),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_primaryColor, _secondaryColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -50,
                top: -50,
                child: Icon(Icons.edit_note_rounded, size: 200, color: Colors.white10),
              ),
            ],
          ),
        ),
      ),
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: EdgeInsets.fromLTRB(25, 20, 25, 10),
      child: Column(
        children: [
          Row(
            children: [
              _buildProgressStep(0, "Photos", Icons.photo_library_outlined),
              _buildProgressLine(0),
              _buildProgressStep(1, "Infos", Icons.info_outline_rounded),
              _buildProgressLine(1),
              _buildProgressStep(2, "Lieu", Icons.location_on_outlined),
            ],
          ),
          SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStepLabel(0, "Photos"),
                _buildStepLabel(1, "Détails"),
                _buildStepLabel(2, "Localisation"),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressStep(int step, String title, IconData icon) {
    bool isActive = _currentStep == step;
    bool isCompleted = _currentStep > step;

    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: isActive ? _primaryColor : (isCompleted ? _successColor : Colors.white),
        shape: BoxShape.circle,
        border: Border.all(
          color: isActive || isCompleted ? Colors.transparent : _borderColor,
          width: 2,
        ),
        boxShadow: isActive ? [
          BoxShadow(
            color: _primaryColor.withOpacity(0.3),
            blurRadius: 10,
            spreadRadius: 2,
          )
        ] : null,
      ),
      child: Center(
        child: Icon(
          isCompleted ? Icons.check_rounded : icon,
          size: 18,
          color: isActive || isCompleted ? Colors.white : _greyColor,
        ),
      ),
    );
  }

  Widget _buildProgressLine(int step) {
    bool isCompleted = _currentStep > step;
    return Expanded(
      child: Container(
        height: 3,
        margin: EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: isCompleted ? _successColor : _borderColor,
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  Widget _buildStepLabel(int step, String label) {
    bool isActive = _currentStep == step;
    return Text(
      label,
      style: GoogleFonts.outfit(
        fontSize: 11,
        fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
        color: isActive ? _primaryColor : _greyColor,
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0: return _buildStep0();
      case 1: return _buildStep1();
      case 2: return _buildStep2();
      default: return _buildStep0();
    }
  }

  Widget _buildBottomActionBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 15, 20, 30),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: Offset(0, -5))
        ],
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            Container(
              margin: EdgeInsets.only(right: 12),
              child: IconButton(
                onPressed: () {
                   setState(() {
                    _currentStep--;
                  });
                },
                icon: Icon(Icons.arrow_back_ios_new_rounded, color: _primaryColor),
                style: IconButton.styleFrom(
                  backgroundColor: _primaryColor.withOpacity(0.1),
                  padding: EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          Expanded(
            child: Container(
              height: 58,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: _isLoading ? null : LinearGradient(
                  colors: [_primaryColor, _secondaryColor],
                ),
                boxShadow: [
                  BoxShadow(
                    color: _primaryColor.withOpacity(0.3),
                    blurRadius: 12,
                    offset: Offset(0, 6)
                  )
                ],
              ),
              child: ElevatedButton(
                onPressed: _isLoading ? null : (_currentStep < 2 ? () => setState(() => _currentStep++) : _handleUpdate),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
                child: _isLoading ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(
                        _currentStep < 2 ? "Continuer" : "Enregistrer",
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep0() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildModernSectionHeader(
          icon: Icons.photo_camera_rounded,
          title: 'Gestion des visuels',
          subtitle: 'Les annonces avec photos sont 5x plus consultées',
        ),
        SizedBox(height: 25),
        ..._imageCategories.map((category) => _buildModernImageCategorySection(category)),
      ],
    );
  }

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildModernSectionHeader(
          icon: Icons.info_outline_rounded,
          title: 'Informations de base',
          subtitle: 'Définissez le type de transaction et les détails',
        ),
        SizedBox(height: 25),
        
        Text(
          "Type de transaction",
          style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: _darkColor),
        ),
        SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildAudaciousTypeCard(
                title: "À louer",
                subtitle: "Location",
                isSelected: _isForRent,
                iconPath: Icons.key_rounded,
                onTap: () => setState(() => _isForRent = true),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _buildAudaciousTypeCard(
                title: "À vendre",
                subtitle: "Vente directe",
                isSelected: !_isForRent,
                iconPath: Icons.sell_rounded,
                onTap: () => setState(() => _isForRent = false),
              ),
            ),
          ],
        ),
        
        SizedBox(height: 25),
        _buildSectionHeader(
          icon: Icons.notes_rounded,
          title: 'Description',
        ),
        SizedBox(height: 16),
        _buildModernTextField(_titleController, 'Titre accrocheur', Icons.title_rounded, isRequired: true),
        SizedBox(height: 16),
        _buildModernTextField(_descriptionController, 'Description complète', Icons.description_rounded,
            maxLines: 4, isRequired: true),
            
        SizedBox(height: 25),
        _buildSectionHeader(
          icon: Icons.payments_outlined,
          title: 'Aspects financiers',
        ),
        SizedBox(height: 16),
        _buildModernTextField(_priceController, 'Prix (${_isForRent ? "\$/mois" : "\$"})', Icons.attach_money_rounded,
            keyboardType: TextInputType.number, isRequired: true),
        if (_isForRent) ...[
          SizedBox(height: 16),
          _buildModernTextField(_guaranteeController, 'Mois de garantie', Icons.security_rounded,
              keyboardType: TextInputType.number),
        ],
        
        SizedBox(height: 25),
        _buildSectionHeader(
          icon: Icons.home_work_outlined,
          title: 'Type de bien',
        ),
        SizedBox(height: 16),
        _buildPropertyTypeSelector(),
        
        SizedBox(height: 25),
        _buildSectionHeader(
          icon: Icons.straighten_rounded,
          title: 'Espaces & Dimensions',
        ),
        SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildModernTextField(_areaController, 'Surface m²', Icons.square_foot_rounded,
                keyboardType: TextInputType.number)),
            SizedBox(width: 16),
            Expanded(child: _buildModernTextField(_roomsController, 'Pièces', Icons.meeting_room_rounded,
                keyboardType: TextInputType.number)),
          ],
        ),
        SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildModernTextField(_bedroomsController, 'Chambres', Icons.bed_rounded,
                keyboardType: TextInputType.number)),
            SizedBox(width: 16),
            Expanded(child: _buildModernTextField(_bathroomsController, 'Salles de bain',
                Icons.bathroom_rounded, keyboardType: TextInputType.number)),
          ],
        ),
        
        SizedBox(height: 30),
        _buildModernSectionHeader(
          icon: Icons.checklist_rounded,
          title: 'Services & Équipements',
          subtitle: 'Améliorez l\'attractivité de votre bien',
        ),
        SizedBox(height: 16),
        _buildElectricWaterSelector(),
        SizedBox(height: 20),
        _buildAmenitiesSection(),
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildModernSectionHeader(
          icon: Icons.location_on_rounded,
          title: 'Emplacement',
          subtitle: 'La localisation exacte aide les clients à se projeter',
        ),
        SizedBox(height: 25),
        _buildModernTextField(_addressController, 'Adresse physique exact', Icons.home_rounded,
            isRequired: true),
        SizedBox(height: 20),
        
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _primaryColor.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _primaryColor.withOpacity(0.1)),
          ),
          child: Column(
            children: [
              if (_isKinshasaSelected) ...[
                _buildModernLocationDropdown<CityModel>(
                  'Ville',
                  _selectedCity,
                  _availableCities,
                  (city) => city.name ?? '',
                  (city) async {
                    setState(() { _selectedCity = city; _selectedDistrict = null; _selectedCommune = null; _selectedQuartier = null; });
                    if (city?.name?.toLowerCase() == 'kinshasa') _loadDistricts();
                  },
                  Icons.location_city_rounded,
                ),
                if (_selectedCity != null) ...[
                  SizedBox(height: 12),
                  _buildModernLocationDropdown<DistrictModel>(
                    'District', _selectedDistrict, _availableDistricts, (d) => d.name ?? '',
                    (d) async { setState(() { _selectedDistrict = d; _selectedCommune = null; _selectedQuartier = null; }); await _loadCommunes(); },
                    Icons.map_rounded,
                  ),
                ],
                if (_selectedDistrict != null) ...[
                  SizedBox(height: 12),
                  _buildModernLocationDropdown<CommuneModel>(
                    'Commune', _selectedCommune, _availableCommunes, (c) => c.name ?? '',
                    (c) async { setState(() { _selectedCommune = c; _selectedQuartier = null; }); await _loadQuartiers(); },
                    Icons.location_on_rounded,
                  ),
                ],
                if (_selectedCommune != null) ...[
                  SizedBox(height: 12),
                  _buildModernLocationDropdown<QuartierModel>(
                    'Quartier', _selectedQuartier, _availableQuartiers, (q) => q.name ?? '',
                    (q) => setState(() => _selectedQuartier = q),
                    Icons.place_rounded,
                  ),
                ],
              ] else ...[
                _buildModernTextField(_cityTextController, 'Ville', Icons.location_city_rounded),
                SizedBox(height: 12),
                _buildModernTextField(_communeTextController, 'Commune', Icons.map_rounded),
                SizedBox(height: 12),
                _buildModernTextField(_quartierTextController, 'Quartier', Icons.place_rounded),
              ],
            ],
          ),
        ),
        SizedBox(height: 20),
        _buildModernTextField(_postalCodeController, 'Code postal', Icons.markunread_mailbox_rounded),
      ],
    );
  }

  Widget _buildModernSectionHeader({required IconData icon, required String title, required String subtitle}) {
    return Column(
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
              child: Icon(icon, color: _primaryColor, size: 24),
            ),
            SizedBox(width: 12),
            Text(title, style: _titleStyle.copyWith(fontSize: 20)),
          ],
        ),
        SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 48),
          child: Text(subtitle, style: _subtitleStyle.copyWith(fontSize: 14)),
        ),
      ],
    );
  }

  Widget _buildSectionHeader({required IconData icon, required String title}) {
    return Row(
      children: [
        Icon(icon, color: _primaryColor, size: 20),
        SizedBox(width: 10),
        Text(
          title, 
          style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: _darkColor.withOpacity(0.8))
        ),
      ],
    );
  }

  Widget _buildModernTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    int maxLines = 1,
    TextInputType? keyboardType,
    bool isRequired = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: Offset(0, 4))
        ],
      ),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        style: GoogleFonts.outfit(fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          labelText: label + (isRequired ? ' *' : ''),
          labelStyle: GoogleFonts.outfit(color: _greyColor, fontSize: 14),
          prefixIcon: Icon(icon, color: _primaryColor, size: 20),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: _borderColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: _borderColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: _primaryColor, width: 2),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        validator: isRequired ? (v) => v == null || v.isEmpty ? 'Champ requis' : null : null,
      ),
    );
  }

  Widget _buildAudaciousTypeCard({
    required String title,
    required String subtitle,
    required bool isSelected,
    required IconData iconPath,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 300),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        height: 80,
        decoration: BoxDecoration(
          color: isSelected ? _primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? _primaryColor : _borderColor, width: 2),
          boxShadow: isSelected ? [
            BoxShadow(color: _primaryColor.withOpacity(0.3), blurRadius: 12, offset: Offset(0, 6))
          ] : null,
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white24 : _primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(iconPath, color: isSelected ? Colors.white : _primaryColor, size: 22),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      color: isSelected ? Colors.white : _darkColor,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.outfit(
                      color: isSelected ? Colors.white70 : _greyColor,
                      fontSize: 11,
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
    );
  }

  Widget _buildPropertyTypeSelector() {
    final types = [
      {'val': 'Studio', 'lab': 'Studio', 'icon': Icons.home_outlined},
      {'val': 'Apparts', 'lab': 'Appart', 'icon': Icons.apartment_rounded},
      {'val': 'Maisons', 'lab': 'Maison', 'icon': Icons.cottage_outlined},
      {'val': 'Bureau', 'lab': 'Bureau', 'icon': Icons.work_outline_rounded},
    ];

    return Container(
      height: 90,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: types.length,
        separatorBuilder: (_, __) => SizedBox(width: 12),
        itemBuilder: (context, index) {
          final t = types[index];
          final sel = _selectedCategory == t['val'];
          return GestureDetector(
            onTap: () => setState(() => _selectedCategory = t['val'] as String),
            child: AnimatedContainer(
              duration: Duration(milliseconds: 200),
              width: 85,
              decoration: BoxDecoration(
                color: sel ? _primaryColor : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: sel ? _primaryColor : _borderColor),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(t['icon'] as IconData, color: sel ? Colors.white : _primaryColor, size: 24),
                  SizedBox(height: 6),
                  Text(
                    t['lab'] as String,
                    style: GoogleFonts.outfit(
                      fontSize: 12, 
                      fontWeight: sel ? FontWeight.bold : FontWeight.w500,
                      color: sel ? Colors.white : _darkColor
                    ),
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildElectricWaterSelector() {
    return Row(
      children: [
        Expanded(
          child: _buildModernLocationDropdown<String>(
            'Électricité', _selectedElectric, _electricOptions.map((e) => e['value'] as String).toList(),
            (v) => _electricOptions.firstWhere((e) => e['value'] == v)['label'],
            (v) => setState(() => _selectedElectric = v),
            Icons.bolt_rounded,
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: _buildModernLocationDropdown<String>(
            'Eau', _selectedWater, _waterOptions.map((e) => e['value'] as String).toList(),
            (v) => _waterOptions.firstWhere((e) => e['value'] == v)['label'],
            (v) => setState(() => _selectedWater = v),
            Icons.water_drop_rounded,
          ),
        ),
      ],
    );
  }

  Widget _buildAmenitiesSection() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _amenitiesList.map((amenity) {
        final isSelected = _selectedAmenities.contains(amenity);
        return FilterChip(
          label: Text(amenity),
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              if (selected) {
                _selectedAmenities.add(amenity);
              } else {
                _selectedAmenities.remove(amenity);
              }
            });
          },
          selectedColor: _primaryColor.withOpacity(0.2),
          checkmarkColor: _primaryColor,
        );
      }).toList(),
    );
  }

  Widget _buildModernImageCategorySection(ImageCategory category) {
    final existingUrls = _existingImageUrls[category.id] ?? [];
    final newImages = _newImages[category.id] ?? [];

    return Container(
      margin: EdgeInsets.only(bottom: 20),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _borderColor.withOpacity(0.5)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(color: _primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: Icon(category.icon, color: _primaryColor, size: 18),
              ),
              SizedBox(width: 12),
              Text(category.name, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: _darkColor)),
              Spacer(),
              Text("${existingUrls.length + newImages.length} photos", style: GoogleFonts.outfit(fontSize: 12, color: _greyColor)),
            ],
          ),
          SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Bouton AJOUTER au début
                GestureDetector(
                  onTap: () => _pickImages(category.id),
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: _primaryColor.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: _primaryColor.withOpacity(0.2), style: BorderStyle.none),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_photo_alternate_rounded, color: _primaryColor, size: 30),
                        SizedBox(height: 4),
                        Text("Ajouter", style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: _primaryColor)),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: 12),
                // Nouvelles images
                ...newImages.asMap().entries.map((e) => _buildImageThumbnail(File(e.value.path), isFile: true, onDelete: () {
                  setState(() { _newImages[category.id]!.removeAt(e.key); });
                })),
                // Images existantes
                ...existingUrls.map((url) => _buildImageThumbnail(url, isFile: false)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageThumbnail(dynamic source, {bool isFile = false, VoidCallback? onDelete}) {
    return Container(
      margin: EdgeInsets.only(right: 12),
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 5)],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: isFile ? Image.file(source as File, fit: BoxFit.cover, width: 100, height: 100)
                : CachedNetworkImage(imageUrl: source as String, fit: BoxFit.cover, width: 100, height: 100),
          ),
          if (onDelete != null)
            Positioned(
              top: -8,
              right: -8,
              child: GestureDetector(
                onTap: onDelete,
                child: Container(
                  padding: EdgeInsets.all(4),
                  decoration: BoxDecoration(color: _errorColor, shape: BoxShape.circle),
                  child: Icon(Icons.close_rounded, color: Colors.white, size: 14),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _pickImages(String categoryId) async {
    try {
      final List<XFile> images = await _picker.pickMultiImage(imageQuality: 85);
      if (images.isNotEmpty) {
        setState(() {
          _newImages[categoryId]!.addAll(images);
        });
      }
    } catch (e) {
      FancyNotification.show(context, "Erreur lors de la sélection des images", type: NotificationType.error);
    }
  }

  Widget _buildModernLocationDropdown<T>(
    String label, T? val, List<T> items, String Function(T) getLab, Function(T?) onChanged, IconData icon
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: DropdownButtonFormField<T>(
        value: val,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.outfit(color: _greyColor, fontSize: 13),
          prefixIcon: Icon(icon, color: _primaryColor, size: 18),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        items: items.map((i) => DropdownMenuItem(value: i, child: Text(getLab(i), style: GoogleFonts.outfit(fontSize: 14)))).toList(),
        onChanged: onChanged,
        icon: Icon(Icons.expand_more_rounded, color: _greyColor),
      ),
    );
  }



  Future<void> _handleUpdate() async {
    if (!_formKey.currentState!.validate()) {
       SnackBarHelper.show(context, "Veuillez remplir correctement tous les champs obligatoires", isError: true);
       return;
    }

    setState(() => _isLoading = true);

    try {
      final GetStorage storage = GetStorage();
      final dynamic userData = storage.read(StockageKeys.userKey);
      final dynamic profileData = storage.read(StockageKeys.profileKey);
      
      final userId = userData?['userId'] ?? userData?['user']?['userId'] ?? profileData?['id'] ?? userData?['profile']?['id'];
      final uId = userId != null ? (userId is int ? userId : int.tryParse(userId.toString()) ?? 0) : 0;
      
      print("🛠️ DEBUG UPDATE - uId: $uId, propertyId: ${widget.property.propertyId}");

      if (uId == 0 || widget.property.propertyId == null) {
        SnackBarHelper.show(context, "Erreur Fatale: Impossible de déterminer votre identité ou ID propriété", isError: true);
        setState(() => _isLoading = false);
        return;
      }

      // Préparer les données
      final propertyData = await _prepareUpdateData();
      print("📤 PAYLOAD ENVOYÉ: ${jsonEncode(propertyData).substring(0, 200)}...");

      // Appeler l'API
      final ctrl = Provider.of<PropertyController>(context, listen: false);
      final res = await ctrl.updatePropertyByOwner(
        uId,
        widget.property.propertyId!,
        propertyData,
      );

      print("📥 REPONSE API: ${res.status}, Error: ${res.errorMsg}");

      if (res.status == true) {
        SnackBarHelper.show(context, "Succès ! Votre annonce a été mise à jour.");
        Navigator.pop(context, true);
      } else {
        // Afficher plus de détails sur l'erreur
        String errorDetail = res.errorMsg ?? "Erreur inconnue";
        if (res.data != null && res.data is Map) {
           errorDetail += " Details: ${res.data['message'] ?? res.data['error'] ?? ''}";
        }
        
        SnackBarHelper.show(context, errorDetail, isError: true);
      }
    } catch (e, stackTrace) {
      print("❌ CRITICAL ERROR DURING UPDATE: $e");
      print("🔍 STACKTRACE: $stackTrace");
      SnackBarHelper.show(context, "Erreur Critique: ${e.toString()}", isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Suppression de _showErrorDialog car on utilise SnackBarHelper désormais


  Future<Map<String, dynamic>> _prepareUpdateData() async {
    final GetStorage storage = GetStorage();
    final dynamic userData = storage.read(StockageKeys.userKey);
    final dynamic profile = storage.read(StockageKeys.profileKey);
    final String fullname = (profile is Map) ? (profile["fullname"] ?? "Utilisateur") : "Utilisateur";

    final propertyData = <String, dynamic>{
      "property": {
        "title": _titleController.text.trim(),
        "description": _descriptionController.text.trim(),
        "price": double.tryParse(_priceController.text) ?? 5000.0,
        "surface": double.tryParse(_areaController.text) ?? 0.1,
        "rooms": int.tryParse(_roomsController.text) ?? 1,
        "bedrooms": int.tryParse(_bedroomsController.text) ?? 1,
        "kitchen": int.tryParse(_kitchensController.text) ?? 1,
        "livingRoom": int.tryParse(_livingRoomsController.text) ?? 1,
        "bathroom": int.tryParse(_bathroomsController.text) ?? 1,
        "floor": int.tryParse(_floorController.text) ?? 1,
        "electric": int.tryParse(_selectedElectric ?? '0') ?? 0,
        "water": int.tryParse(_selectedWater ?? '0') ?? 0,
        "guarantee": _guaranteeController.text.trim().isNotEmpty ? _guaranteeController.text.trim() : "0",
        "sold": widget.property.sold ?? false,
        "transactionType": _isForRent ? "location" : "vente",
        "available": true,
      },
      "postBy": fullname,
      "address": {
        "address": _addressController.text.trim(),
        "cityId": _isKinshasaSelected && _selectedCity?.cityId != null ? _selectedCity!.cityId! : (widget.property.cityId ?? 1),
        "communeId": _isKinshasaSelected && _selectedCommune?.communeId != null ? _selectedCommune!.communeId! : widget.property.communeId,
        "quartierId": _isKinshasaSelected && _selectedQuartier?.quartierId != null ? _selectedQuartier!.quartierId! : widget.property.quartierId,
        "cityValue": _isKinshasaSelected ? "Kinshasa" : _cityTextController.text.trim(),
        "communeValue": _isKinshasaSelected ? (_selectedCommune?.name ?? "") : _communeTextController.text.trim(),
        "quartierValue": _isKinshasaSelected ? (_selectedQuartier?.name ?? "") : _quartierTextController.text.trim(),
        "postalCode": _postalCodeController.text.trim(),
        "countryValue": "RDC",
      },
      "geoZone": {
        "lat": _selectedLocation?.latitude ?? widget.property.latitude ?? 0.1,
        "lng": _selectedLocation?.longitude ?? widget.property.longitude ?? 0.1,
      },
      "typeProperty": {
        "propertyTypeId": _getPropertyTypeId(_selectedCategory) ?? 2,
      },
      "features": _selectedAmenities.map((amenity) {
        return {
          "featureId": _getFeatureId(amenity),
          "name": amenity,
        };
      }).toList(),
    };

    // Images
    Map<String, dynamic> imagesPayload = {};
    for (var category in _imageCategories) {
      final categoryId = category.id;
      final List<Map<String, String>> imageList = [];

      // Ajouter les URLs existantes (elles restent telles quelles)
      final existingUrls = _existingImageUrls[categoryId] ?? [];
      for (var url in existingUrls) {
        if (url.isNotEmpty) {
          imageList.add({"image": url});
        }
      }

      // Ajouter les nouvelles images (converties en base64)
      final newImages = _newImages[categoryId] ?? [];
      for (var imageFile in newImages) {
        try {
          final file = File(imageFile.path);
          if (await file.exists()) {
            final bytes = await file.readAsBytes();
            final base64String = base64Encode(bytes);
            imageList.add({"image": base64String});
          }
        } catch (e) {
          print("❌ Erreur lors de la conversion de l'image ${imageFile.path}: $e");
        }
      }

      // Mapper les catégories Flutter aux clés API
      switch (categoryId) {
        case 'propertyImage':
          imagesPayload['main'] = imageList;
          break;
        case 'propertyImageRoom':
          imagesPayload['room'] = imageList;
          break;
        case 'propertyImageLivingRoom':
          imagesPayload['living'] = imageList;
          break;
        case 'propertyImageKitchen':
          imagesPayload['kitchen'] = imageList;
          break;
      }
    }

    // S'assurer que tous les champs d'images existent
    const requiredImageKeys = ['main', 'room', 'living', 'kitchen'];
    for (var key in requiredImageKeys) {
      if (!imagesPayload.containsKey(key)) {
        imagesPayload[key] = [];
      }
    }
    
    propertyData["images"] = imagesPayload;

    // Ajout userId si disponible
    final dynamic profileData = storage.read(StockageKeys.profileKey);
    final userId = userData?['userId'] ?? userData?['user']?['userId'] ?? profileData?['id'] ?? userData?['profile']?['id'] ?? widget.property.userId;
    if (userId != null) {
      (propertyData["property"] as Map<String, dynamic>)["userId"] = userId;
    }

    return propertyData;
  }

  Future<void> _loadDistricts() async {
    final locationCtrl = Provider.of<LocationController>(context, listen: false);
    await locationCtrl.getAllDistricts();
    if (mounted) {
      setState(() {
        _availableDistricts = locationCtrl.getDistrictsForCity(_selectedCity?.cityId ?? 1);
      });
    }
  }

  Future<void> _loadCommunes() async {
    if (_selectedDistrict?.districtId == null) return;
    final locationCtrl = Provider.of<LocationController>(context, listen: false);
    await locationCtrl.getAllCommunes();
    if (mounted) {
      setState(() {
        _availableCommunes = locationCtrl.getCommunesForDistrict(_selectedDistrict!.districtId!);
      });
    }
  }

  Future<void> _loadQuartiers() async {
    if (_selectedCommune?.communeId == null) return;
    final locationCtrl = Provider.of<LocationController>(context, listen: false);
    await locationCtrl.getAllQuartiers();
    if (mounted) {
      setState(() {
        _availableQuartiers = locationCtrl.getQuartiersForCommune(_selectedCommune!.communeId!);
      });
    }
  }

  int? _getPropertyTypeId(String? category) {
    if (category == null) return widget.property.propertyTypeId ?? 2;
    
    final Map<String, int> typeMap = {
      'Studio': 1,
      'Apparts': 2,
      'Maisons': 3,
      'Bureau': 4,
      'Hotels': 5,
      'Vacances': 6,
    };
    
    return typeMap[category] ?? widget.property.propertyTypeId ?? 2;
  }

  int _getFeatureId(String amenity) {
    final Map<String, int> featureMap = {
      'WiFi': 1,
      'Climatisation': 2,
      'Chauffage': 3,
      'Cuisine équipée': 4,
      'Lave-linge': 5,
      'Parking': 6,
      'Ascenseur': 7,
      'Piscine': 8,
      'Jardin': 9,
      'Terrasse': 10,
      'Gym': 11,
      'Sécurité': 12,
      'Animaux acceptés': 13,
    };
    return featureMap[amenity] ?? 1;
  }
}

class ImageCategory {
  final String id;
  final String name;
  final IconData icon;
  final Color color;

  ImageCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
  });
}

