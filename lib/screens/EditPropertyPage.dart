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
  // Couleurs modernes
  final Color _primaryColor = Color(0xFF1976D2);
  final Color _secondaryColor = Color(0xFF64B5F6);
  final Color _darkColor = Color(0xFF1A1D26);
  final Color _lightColor = Color(0xFFF8F9FA);
  final Color _greyColor = Color(0xFF6C757D);
  final Color _successColor = Color(0xFF38B000);
  final Color _cardColor = Colors.white;
  final Color _borderColor = Color(0xFFE9ECEF);
  final Color _errorColor = Color(0xFFD32F2F);

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
  late var fullname = profile["fullname"];

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
    _loadPropertyData();
    _loadLocationData();
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
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _primaryColor,
        title: Text(
          'Modifier la propriété',
          style: GoogleFonts.roboto(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Form(
        key: _formKey,
        child: PageView(
          controller: _pageController,
          physics: NeverScrollableScrollPhysics(),
          children: [
            _buildStep0(), // Images
            _buildStep1(), // Détails
            _buildStep2(), // Localisation
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildStep0() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            icon: Icons.photo_library_rounded,
            title: 'Photos',
            subtitle: 'Ajoutez des photos pour illustrer votre propriété',
          ),
          SizedBox(height: 24),
          ..._imageCategories.map((category) => _buildImageCategorySection(category)),
        ],
      ),
    );
  }

  Widget _buildStep1() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            icon: Icons.info_outline_rounded,
            title: 'Détails de la propriété',
            subtitle: 'Remplissez les informations principales',
          ),
          SizedBox(height: 24),
          _buildTextField(_titleController, 'Titre', Icons.title_rounded, isRequired: true),
          SizedBox(height: 16),
          _buildTextField(_descriptionController, 'Description', Icons.description_rounded,
              maxLines: 4, isRequired: true),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildTextField(_priceController, 'Prix', Icons.attach_money_rounded,
                    keyboardType: TextInputType.number, isRequired: true),
              ),
              SizedBox(width: 16),
              Expanded(
                child: _buildToggleButtons(),
              ),
            ],
          ),
          SizedBox(height: 16),
          _buildPropertyTypeDropdown(),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildTextField(_bedroomsController, 'Chambres', Icons.bed_rounded,
                  keyboardType: TextInputType.number)),
              SizedBox(width: 16),
              Expanded(child: _buildTextField(_bathroomsController, 'Salles de bain',
                  Icons.bathroom_rounded, keyboardType: TextInputType.number)),
            ],
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildTextField(_areaController, 'Surface (m²)', Icons.square_foot_rounded,
                  keyboardType: TextInputType.number)),
              SizedBox(width: 16),
              Expanded(child: _buildTextField(_floorController, 'Étage', Icons.layers_rounded,
                  keyboardType: TextInputType.number)),
            ],
          ),
          SizedBox(height: 24),
          _buildSectionHeader(
            icon: Icons.checklist_rounded,
            title: 'Services et équipements',
            subtitle: 'Sélectionnez les services disponibles',
          ),
          SizedBox(height: 16),
          _buildElectricWaterSection(),
          SizedBox(height: 24),
          _buildAmenitiesSection(),
        ],
      ),
    );
  }

  Widget _buildStep2() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            icon: Icons.location_on_rounded,
            title: 'Localisation',
            subtitle: 'Indiquez l\'emplacement de la propriété',
          ),
          SizedBox(height: 24),
          _buildTextField(_addressController, 'Adresse complète', Icons.home_rounded,
              isRequired: true),
          SizedBox(height: 16),
          if (_isKinshasaSelected) ...[
            _buildCityDropdown(),
            if (_selectedCity != null) ...[
              SizedBox(height: 16),
              _buildDistrictDropdown(),
            ],
            if (_selectedDistrict != null) ...[
              SizedBox(height: 16),
              _buildCommuneDropdown(),
            ],
            if (_selectedCommune != null) ...[
              SizedBox(height: 16),
              _buildQuartierDropdown(),
            ],
          ] else ...[
            _buildTextField(_cityTextController, 'Ville', Icons.location_city_rounded),
            SizedBox(height: 16),
            _buildTextField(_communeTextController, 'Commune', Icons.map_rounded),
            SizedBox(height: 16),
            _buildTextField(_quartierTextController, 'Quartier', Icons.place_rounded),
          ],
          SizedBox(height: 16),
          _buildTextField(_postalCodeController, 'Code postal', Icons.markunread_mailbox_rounded),
          SizedBox(height: 24),
          _buildTextField(_guaranteeController, 'Garantie (optionnel)', Icons.shield_rounded),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({required IconData icon, required String title, String? subtitle}) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_primaryColor, _secondaryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withOpacity(0.3),
            blurRadius: 12,
            offset: Offset(0, 4),
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
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.roboto(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                if (subtitle != null) ...[
                  SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.roboto(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    int maxLines = 1,
    TextInputType? keyboardType,
    bool isRequired = false,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label + (isRequired ? ' *' : ''),
        prefixIcon: Icon(icon, color: _primaryColor),
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
      ),
      validator: isRequired
          ? (value) {
              if (value == null || value.isEmpty) {
                return 'Ce champ est requis';
              }
              return null;
            }
          : null,
    );
  }

  Widget _buildToggleButtons() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor),
        color: _cardColor,
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => setState(() => _isForRent = true),
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: _isForRent ? _primaryColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    'Location',
                    style: GoogleFonts.roboto(
                      color: _isForRent ? Colors.white : _greyColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: () => setState(() => _isForRent = false),
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: !_isForRent ? _primaryColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    'Vente',
                    style: GoogleFonts.roboto(
                      color: !_isForRent ? Colors.white : _greyColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown(String label, String? value, List<String> items, Function(String?) onChanged, IconData icon) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor),
        color: _cardColor,
      ),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: _primaryColor),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        items: items.map((item) {
          return DropdownMenuItem(
            value: item,
            child: Text(item),
          );
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildElectricWaterSection() {
    return Row(
      children: [
        Expanded(
          child: _buildDropdown(
            'Électricité',
            _selectedElectric,
            _electricOptions.map((e) => e['value'] as String).toList(),
            (value) => setState(() => _selectedElectric = value),
            Icons.flash_on_rounded,
          ),
        ),
        SizedBox(width: 16),
        Expanded(
          child: _buildDropdown(
            'Eau',
            _selectedWater,
            _waterOptions.map((e) => e['value'] as String).toList(),
            (value) => setState(() => _selectedWater = value),
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

  Widget _buildImageCategorySection(ImageCategory category) {
    final existingUrls = _existingImageUrls[category.id] ?? [];
    final newImages = _newImages[category.id] ?? [];

    return Container(
      margin: EdgeInsets.only(bottom: 24),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(category.icon, color: category.color, size: 20),
              SizedBox(width: 8),
              Text(
                category.name,
                style: GoogleFonts.roboto(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _darkColor,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          // Images existantes
          if (existingUrls.isNotEmpty) ...[
            Text(
              'Images existantes',
              style: GoogleFonts.roboto(fontSize: 12, color: _greyColor),
            ),
            SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: existingUrls.map((url) {
                  return Container(
                    margin: EdgeInsets.only(right: 8),
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _borderColor),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        imageUrl: url,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: _lightColor,
                          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                        ),
                        errorWidget: (context, url, error) => Icon(Icons.error),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            SizedBox(height: 16),
          ],
          // Nouvelles images
          if (newImages.isNotEmpty) ...[
            Text(
              'Nouvelles images',
              style: GoogleFonts.roboto(fontSize: 12, color: _greyColor),
            ),
            SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: newImages.asMap().entries.map((entry) {
                final index = entry.key;
                final image = entry.value;
                return Stack(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _borderColor),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          File(image.path),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      top: -8,
                      right: -8,
                      child: IconButton(
                        icon: Icon(Icons.close_rounded, color: _errorColor),
                        onPressed: () {
                          setState(() {
                            _newImages[category.id]!.removeAt(index);
                          });
                        },
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
            SizedBox(height: 16),
          ],
          // Bouton ajouter
          ElevatedButton.icon(
            onPressed: () => _pickImages(category.id),
            icon: Icon(Icons.add_photo_alternate_rounded),
            label: Text('Ajouter des photos'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
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

  // Location dropdowns
  Widget _buildCityDropdown() {
    return _buildLocationDropdown<CityModel>(
      'Ville',
      _selectedCity,
      _availableCities,
      (city) => city.name ?? '',
      (city) async {
        setState(() {
          _selectedCity = city;
          _selectedDistrict = null;
          _selectedCommune = null;
          _selectedQuartier = null;
        });
        
        // Charger districts si Kinshasa
        if (city?.name?.toLowerCase() == 'kinshasa') {
          _loadDistricts();
        }
      },
      Icons.location_city_rounded,
    );
  }

  Widget _buildDistrictDropdown() {
    return _buildLocationDropdown<DistrictModel>(
      'District',
      _selectedDistrict,
      _availableDistricts,
      (district) => district.name ?? '',
      (district) async {
        setState(() {
          _selectedDistrict = district;
          _selectedCommune = null;
          _selectedQuartier = null;
        });
        await _loadCommunes();
      },
      Icons.map_rounded,
    );
  }

  Widget _buildCommuneDropdown() {
    return _buildLocationDropdown<CommuneModel>(
      'Commune',
      _selectedCommune,
      _availableCommunes,
      (commune) => commune.name ?? '',
      (commune) async {
        setState(() {
          _selectedCommune = commune;
          _selectedQuartier = null;
        });
        await _loadQuartiers();
      },
      Icons.location_on_rounded,
    );
  }

  Widget _buildQuartierDropdown() {
    return _buildLocationDropdown<QuartierModel>(
      'Quartier',
      _selectedQuartier,
      _availableQuartiers,
      (quartier) => quartier.name ?? '',
      (quartier) => setState(() => _selectedQuartier = quartier),
      Icons.place_rounded,
    );
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

  Widget _buildLocationDropdown<T>(
    String label,
    T? selected,
    List<T> items,
    String Function(T) getLabel,
    Function(T?) onChanged,
    IconData icon,
  ) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor),
        color: _cardColor,
      ),
      child: DropdownButtonFormField<T>(
        value: selected,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: _primaryColor),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        items: items.map((item) {
          return DropdownMenuItem(
            value: item,
            child: Text(getLabel(item)),
          );
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            OutlinedButton(
              onPressed: () {
                _pageController.previousPage(
                  duration: Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
                setState(() => _currentStep--);
              },
              child: Text('Précédent'),
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              ),
            ),
          SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: _currentStep < 2
                  ? () {
                      _pageController.nextPage(
                        duration: Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                      setState(() => _currentStep++);
                    }
                  : _isLoading
                      ? null
                      : _handleUpdate,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
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
                      _currentStep < 2 ? 'Suivant' : 'Enregistrer les modifications',
                      style: GoogleFonts.roboto(fontWeight: FontWeight.w600),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleUpdate() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final GetStorage storage = GetStorage();
      final dynamic userData = storage.read(StockageKeys.userKey);
      final userId = userData?['userId'] ?? userData?['user']?['userId'];

      if (userId == null || widget.property.propertyId == null) {
        FancyNotification.show(context, "Erreur: Données manquantes", type: NotificationType.error);
        return;
      }

      // Préparer les données
      final propertyData = await _prepareUpdateData();

      // Appeler l'API de mise à jour
      final ctrl = Provider.of<PropertyController>(context, listen: false);
      final res = await ctrl.updatePropertyByOwner(
        int.parse(userId.toString()),
        widget.property.propertyId!,
        propertyData,
      );

      if (res.status == true) {
        FancyNotification.show(
          context,
          "Propriété modifiée avec succès!",
          type: NotificationType.success,
        );
        Navigator.pop(context, true); // Retourner avec succès
      } else {
        FancyNotification.show(
          context,
          res.errorMsg ?? "Erreur lors de la modification",
          type: NotificationType.error,
        );
      }
    } catch (e) {
      FancyNotification.show(
        context,
        "Erreur: ${e.toString()}",
        type: NotificationType.error,
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<Map<String, dynamic>> _prepareUpdateData() async {
    final propertyData = <String, dynamic>{
      "title": _titleController.text.trim(),
      "description": _descriptionController.text.trim(),
      "price": double.tryParse(_priceController.text) ?? 0.0,
      "surface": double.tryParse(_areaController.text) ?? 0.0,
      "rooms": int.tryParse(_roomsController.text) ?? 0,
      "bedrooms": int.tryParse(_bedroomsController.text) ?? 0,
      "kitchen": int.tryParse(_kitchensController.text) ?? 0,
      "livingRoom": int.tryParse(_livingRoomsController.text) ?? 0,
      "bathroom": int.tryParse(_bathroomsController.text) ?? 0,
      "floor": int.tryParse(_floorController.text) ?? 0,
      "address": _addressController.text.trim(),
      "guarantee": _guaranteeController.text.trim(),
      "postalCode": _postalCodeController.text.trim(),
      "transactionType": _isForRent ? "location" : "vente",
      "propertyTypeId": _getPropertyTypeId(_selectedCategory),
      "electric": int.tryParse(_selectedElectric ?? '0') ?? 0,
      "water": int.tryParse(_selectedWater ?? '0') ?? 0,
      "sold": widget.property.sold ?? false,
      "latitude": _selectedLocation?.latitude ?? widget.property.latitude ?? 0.1,
      "longitude": _selectedLocation?.longitude ?? widget.property.longitude ?? 0.1,
      "features": _selectedAmenities.map((amenity) {
        return {
          "featureId": _getFeatureId(amenity),
          "name": amenity,
        };
      }).toList(),
    };

    // Location
    if (_isKinshasaSelected && _selectedCity != null) {
      propertyData["cityId"] = _selectedCity!.cityId;
      propertyData["communeValue"] = _selectedCommune?.name;
      propertyData["quartierValue"] = _selectedQuartier?.name;
      propertyData["communeId"] = _selectedCommune?.communeId;
      propertyData["quartierId"] = _selectedQuartier?.quartierId;
      propertyData["quartier"] = _selectedQuartier?.name ?? '';
      propertyData["cityValue"] = "Kinshasa";
      propertyData["countryValue"] = "RDC";
    } else {
      propertyData["cityValue"] = _cityTextController.text.trim();
      propertyData["communeValue"] = _communeTextController.text.trim();
      propertyData["quartierValue"] = _quartierTextController.text.trim();
      propertyData["quartier"] = _quartierTextController.text.trim();
      propertyData["cityId"] = widget.property.cityId ?? 1;
      propertyData["communeId"] = widget.property.communeId;
      propertyData["quartierId"] = widget.property.quartierId;
    }

    // Images: combiner URLs existantes et nouvelles images
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

      propertyData[categoryId] = imageList;
    }

    // S'assurer que tous les champs d'images existent
    for (var category in _imageCategories) {
      if (!propertyData.containsKey(category.id)) {
        propertyData[category.id] = [];
      }
    }

    // userId
    final GetStorage storage = GetStorage();
    final dynamic userData = storage.read(StockageKeys.userKey);
    final userId = userData?['userId'] ?? userData?['user']?['userId'];
    propertyData["userId"] = userId ?? widget.property.userId ?? 0;

    return propertyData;
  }

  Widget _buildPropertyTypeDropdown() {
    final propertyTypes = [
      {'value': 'Studio', 'label': 'Studios', 'id': 1},
      {'value': 'Apparts', 'label': 'Apparts', 'id': 2},
      {'value': 'Maisons', 'label': 'Maisons', 'id': 3},
      {'value': 'Bureau', 'label': 'Bureaux', 'id': 4},
      {'value': 'Hotels', 'label': 'Hotels', 'id': 5},
      {'value': 'Vacances', 'label': 'Vacances', 'id': 6},
    ];

    // Trouver le type actuel depuis propertyTypeId
    String? currentValue = _selectedCategory;
    if (currentValue == null && widget.property.propertyTypeId != null) {
      try {
        final currentType = propertyTypes.firstWhere(
          (type) => type['id'] == widget.property.propertyTypeId,
        );
        currentValue = currentType['value'] as String;
        _selectedCategory = currentValue;
      } catch (e) {
        currentValue = 'Apparts'; // Par défaut
        _selectedCategory = currentValue;
      }
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor),
        color: _cardColor,
      ),
      child: DropdownButtonFormField<String>(
        value: currentValue,
        decoration: InputDecoration(
          labelText: 'Type de propriété *',
          prefixIcon: Icon(Icons.category_rounded, color: _primaryColor),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        items: propertyTypes.map((type) {
          return DropdownMenuItem(
            value: type['value'] as String,
            child: Text(type['label'] as String),
          );
        }).toList(),
        onChanged: (value) => setState(() => _selectedCategory = value),
      ),
    );
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

