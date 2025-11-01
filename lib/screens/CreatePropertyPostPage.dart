import 'dart:convert';
import 'package:casa/controllers/PropertyCtrl.dart';
import 'package:casa/controllers/LocationController.dart';
import 'package:casa/utils/Endpoints.dart';
import 'package:casa/utils/FancyNotification.dart';
import 'package:casa/utils/Routes.dart';
import 'package:casa/utils/networkCheck.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'dart:io';

import '../models/CityModel.dart';
import '../models/CommuneModel.dart';
import '../models/DistrictModel.dart';

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

  // Form controllers
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _guaranteeController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
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
  AutovalidateMode _autoValidateMode = AutovalidateMode.disabled;

  // Location variables
  CityModel? _selectedCity;
  DistrictModel? _selectedDistrict;
  CommuneModel? _selectedCommune;

  List<CityModel> _availableCities = [];
  List<DistrictModel> _availableDistricts = [];
  List<CommuneModel> _availableCommunes = [];

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
      color: Color(0xFF4CAF50),
      description: 'Photos des chambres',
    ),
    ImageCategory(
      id: 'propertyImageLivingRoom',
      name: 'Salon',
      icon: FontAwesomeIcons.couch,
      color: Color(0xFFFF9800),
      description: 'Photos du salon',
    ),
    ImageCategory(
      id: 'propertyImageKitchen',
      name: 'Cuisine',
      icon: FontAwesomeIcons.kitchenSet,
      color: Color(0xFFF44336),
      description: 'Photos de la cuisine',
    ),
  ];

  Map<String, List<XFile>> _selectedImages = {};
  Map<String, String> _otherRoomDescriptions = {};

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
  void _updateTotalRooms() {
    if (mounted) {
      setState(() {});
    }
  }
  @override
  void initState() {
    super.initState();

    _bedroomsController.addListener(_updateTotalRooms);
    _bathroomsController.addListener(_updateTotalRooms);
    _livingRoomsController.addListener(_updateTotalRooms);
    _kitchensController.addListener(_updateTotalRooms);


    for (var category in _imageCategories) {
      _selectedImages[category.id] = [];
    }

    // Initialiser le code postal
    _postalCodeController.text = '243';

    // Chargez les données de localisation
    _loadLocationData();
  }

  Future<void> _loadLocationData() async {
    final locationCtrl = LocationController();

    try {
      // Chargez toutes les données
      await locationCtrl.loadAllData();

      if (mounted) {
        setState(() {
          _availableCities = locationCtrl.cities;

          // Sélectionnez la première ville par défaut
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
      _availableDistricts = locationCtrl.getDistrictsForCity(_selectedCity!.cityId!);
      _selectedDistrict = _availableDistricts.isNotEmpty ? _availableDistricts.first : null;
      _updateCommunesForDistrict();
    });
  }

  void _updateCommunesForDistrict() {
    if (_selectedDistrict == null) return;

    final locationCtrl = LocationController();
    setState(() {
      _availableCommunes = locationCtrl.getCommunesForDistrict(_selectedDistrict!.districtId!);
      _selectedCommune = _availableCommunes.isNotEmpty ? _availableCommunes.first : null;
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    _guaranteeController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _bedroomsController.dispose();
    _bathroomsController.dispose();
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

    super.dispose();
  }

  Future<void> _pickImages(String categoryId) async {
    try {
      final List<XFile> images = await _picker.pickMultiImage(
        imageQuality: 85,
        maxWidth: 1440,
      );
      if (images.isNotEmpty) {
        setState(() {
          _selectedImages[categoryId]!.addAll(images);
        });
      }
    } on PlatformException catch (e) {
      print('Failed to pick images: $e');
    }
  }

  void _removeImage(String categoryId, int index) {
    setState(() {
      _selectedImages[categoryId]!.removeAt(index);
    });
  }

  int get _totalImagesCount {
    return _selectedImages.values.fold(0, (sum, images) => sum + images.length);
  }

  Future<void> _handleCreatePropertyPost() async {
    print("🎯 DEBUT _handleCreatePropertyPost");
    print("📱 Mounted: $mounted");
    print("🔄 Current loading state: $_isLoading");

    if (!mounted || _isLoading) {
      print("❌ Arrêt: Déjà en cours ou non monté");
      return;
    }

    setState(() {
      _autoValidateMode = AutovalidateMode.always;
    });

    await Future.delayed(Duration(milliseconds: 50));

    // Validation spécifique par étape
    bool isStepValid = true;
    String? errorMessage;

    switch (_currentStep) {
      case 0: // Type & Photos
        if (_selectedCategory == null) {
          isStepValid = false;
          errorMessage = "Veuillez sélectionner un type de propriété";
        } else if (_totalImagesCount < 3) {
          isStepValid = false;
          errorMessage = "Veuillez ajouter au moins 3 photos";
        }
        break;

      case 1: // Détails
        if (!(_formKey.currentState?.validate() ?? false)) {
          isStepValid = false;
          errorMessage = "Veuillez corriger les erreurs dans le formulaire";
        }
        // Validation supplémentaire pour la localisation
        if (_selectedCity == null || _selectedDistrict == null || _selectedCommune == null) {
          isStepValid = false;
          errorMessage = "Veuillez compléter la localisation";
        }
        break;

      case 2: // Équipements
        if (_selectedAmenities.isEmpty) {
          isStepValid = false;
          errorMessage = "Veuillez sélectionner au moins un équipement";
        }
        break;
    }

    if (!isStepValid) {
      print("❌ Validation échouée: $errorMessage");
      if (errorMessage != null) {
        FancyNotification.show(context, errorMessage, isError: true);
      }
      return;
    }

    print("✅ Validation réussie, début du chargement...");

    setState(() => _isLoading = true);

    FocusScope.of(context).unfocus();

    final isConnected = await NetworkUtils.checkInternetConnectivity();
    if (!isConnected) {
      FancyNotification.show(context, "Pas de connexion internet");
      setState(() => _isLoading = false);
      return;
    }

    try {
      // Préparer les données avec les vrais IDs
      final propertyData = {
        "title": _titleController.text,
        "description": _descriptionController.text,
        "price": double.tryParse(_priceController.text) ?? 0,
        "surface": double.tryParse(_areaController.text) ?? 0,
        "rooms": _calculateTotalRooms(),
        "bedrooms": int.tryParse(_bedroomsController.text) ?? 0,
        "kitchen": int.tryParse(_kitchensController.text) ?? 0,
        "livingRoom": int.tryParse(_livingRoomsController.text) ?? 0,
        "bathroom": int.tryParse(_bathroomsController.text) ?? 0,
        "floor": int.tryParse(_floorController.text) ?? 0,
        "quartier": _addressController.text,
        "address": _addressController.text,
        "cityId": _selectedCity!.cityId,
        "districtId": _selectedDistrict!.districtId,
        "communeId": _selectedCommune!.communeId,
        "postalCode": _postalCodeController.text,
        "sold": false,
        "transactionType": _isForRent ? "location" : "vente",
        "propertyTypeId": _getPropertyTypeId(_selectedCategory),
        "userId": 1,
        "latitude": _selectedLocation?.latitude ?? 0.0,
        "longitude": _selectedLocation?.longitude ?? 0.0,
        "features": _selectedAmenities.map((amenity) => {
          "featureId": _getFeatureId(amenity),
          "name": amenity
        }).toList(),
        "propertyImage": [],
        "propertyImageRoom": [],
        "propertyImageLivingRoom": [],
        "propertyImageKitchen": [],
      };

      // Préparer et mettre à jour les images
      final imagesData = await _prepareImagesData();
      propertyData.addAll(imagesData);

      print("📤 Données envoyées à l'API: ${jsonEncode(propertyData)}");

      final ctrl = context.read<PropertyController>();
      print("🔄 Appel de l'API...");
      final res = await ctrl.createProperty(propertyData);

      if (!mounted) return;

      print("📥 Réponse reçue: ${res.data}");

      if ((res.data['properties'] != null || res.data['data'] != null)) {
        print("✅ Annonce publiée avec succès!");
        FancyNotification.show(context, "Annonce publiée avec succès!", isError: false);
        await Future.delayed(const Duration(milliseconds: 1500));
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            Routes.bottomPageRoute,
                (route) => false,
          );
        }
      } else {
        String errorMessage = res.data['message'] ?? "Erreur lors de la publication de l'annonce";
        print("❌ Erreur API: $errorMessage");
        FancyNotification.show(context, errorMessage, isError: true);
      }
    } catch (e) {
      print("💥 Erreur technique: $e");
      FancyNotification.show(context, "Erreur technique lors de la publication de l'annonce", isError: true);
    } finally {
      print("🏁 Fin du processus de publication");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<Map<String, dynamic>> _prepareImagesData() async {
    Map<String, dynamic> imagesData = {};

    for (var category in _imageCategories) {
      final categoryImages = _selectedImages[category.id] ?? [];
      List<Map<String, String>> imageList = [];

      for (var image in categoryImages) {
        final bytes = await image.readAsBytes();
        final base64String = base64Encode(bytes);
        imageList.add({
          "image": base64String
        });
      }

      // Mettre à jour la catégorie avec les images
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
            // Progress indicator
            _buildProgressIndicator(),

            // Main content
            Expanded(
              child: _buildCurrentStepContent(),
            ),

            // Navigation buttons
            _buildBottomNavigation(),
          ],
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
        onPressed: () => Navigator.pop(context),
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
          // Step progress bar
          LinearProgressIndicator(
            value: (_currentStep + 1) / 3,
            backgroundColor: _borderColor,
            color: _primaryColor,
            minHeight: 6,
            borderRadius: BorderRadius.circular(10),
          ),
          SizedBox(height: 12),
          // Step labels
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
    return GestureDetector(
      onTap: () => setState(() => _currentStep = stepIndex),
      child: Column(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive ? _primaryColor : _borderColor,
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
          // Property type selection
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
                        () => setState(() => _isForRent = true),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: _buildTypeOption(
                    'À vendre',
                    Icons.sell_outlined,
                    !_isForRent,
                        () => setState(() => _isForRent = false),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 20),

          // Nouvelle section de catégories
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

          // Photo upload section
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

          // Image categories
          ..._imageCategories.map((category) => _buildImageCategoryCard(category)),

          // Total images counter
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
                    color: _primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$_totalImagesCount',
                    style: TextStyle(
                      color: _primaryColor,
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
        'color': Color(0xFF10B981),
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
        'color': Color(0xFFF59E0B),
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
        'color': Color(0xFFEC4899),
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
            onTap: () => setState(() => _selectedCategory = category['value'] as String),
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
          // Category header
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

          // Images grid
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

          // Add photos button
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
          // Section Informations de base
          _buildModernSectionHeader(
            title: 'Informations de base',
            icon: Icons.info_outline_rounded,
          ),
          SizedBox(height: 16),
          _buildModernTextField(
            controller: _titleController,
            label: 'Titre de l\'annonce',
            hint: 'Magnifique appartement avec vue panoramique...',
            icon: Icons.title_rounded,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Veuillez entrer un titre';
              }
              return null;
            },
          ),
          SizedBox(height: 12),

          // Prix avec condition pour la location/vente
          _buildModernTextField(
            controller: _priceController,
            label: _isForRent ? 'Prix mensuel' : 'Prix de vente',
            hint: _isForRent ? '1200' : '450000',
            icon: Icons.attach_money_rounded,
            keyboardType: TextInputType.number,
            suffixText: '${_isForRent ? '/mois' : '\$'}',
            prefixIconColor: _isForRent ? Colors.blue : Colors.green,
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

          // Garantie (uniquement pour la location)
          if (_isForRent) ...[
            _buildModernTextField(
              controller: _guaranteeController,
              label: 'Garantie (mois)',
              hint: '2',
              icon: Icons.security_rounded,
              keyboardType: TextInputType.number,
              suffixText: 'mois',
              prefixIconColor: Colors.orange,
              validator: (value) {
                if (_isForRent && (value == null || value.isEmpty)) {
                  return 'Veuillez spécifier la durée de garantie';
                }
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
            label: 'Description détaillée',
            hint: 'Décrivez en détail les avantages, l\'emplacement, les équipements...',
            icon: Icons.description_rounded,
            maxLines: 4,
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

          // Section Localisation
          SizedBox(height: 24),
          _buildModernSectionHeader(
            title: 'Localisation',
            icon: Icons.location_on_outlined,
          ),
          SizedBox(height: 16),

          // Ville
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

          // Quartier
          _buildModernTextField(
            controller: _addressController,
            label: 'Quartier',
            hint: 'Nom du quartier, secteur...',
            icon: Icons.location_city_rounded,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Veuillez entrer le nom du quartier';
              }
              return null;
            },
          ),

          // Section Caractéristiques
          SizedBox(height: 24),
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
              _buildTotalRoomsIndicator()
            ],
          ),
          SizedBox(height: 20),
        ],
      ),
    );
  }

  int _calculateTotalRooms() {
    int bedrooms = int.tryParse(_bedroomsController.text) ?? 0;
    int bathrooms = int.tryParse(_bathroomsController.text) ?? 0;
    int livingRooms = int.tryParse(_livingRoomsController.text) ?? 0;
    int kitchens = int.tryParse(_kitchensController.text) ?? 0;

    return bedrooms + bathrooms + livingRooms + kitchens;
  }

  Widget _buildTotalRoomsIndicator() {
    final totalRooms = _calculateTotalRooms();

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.green.shade50,
        border: Border.all(color: Colors.green.shade200, width: 1),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              FontAwesomeIcons.home,
              color: Colors.green.shade600,
              size: 18,
            ),
            SizedBox(height: 4),
            Text(
              'Total: $totalRooms',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.green.shade700,
              ),
            ),
            Text(
              'pièces',
              style: TextStyle(
                fontSize: 10,
                color: Colors.green.shade600,
              ),
            ),
          ],
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
          _buildSectionHeader('Équipements'),
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
                  setState(() {
                    if (selected) {
                      _selectedAmenities.add(amenity);
                    } else {
                      _selectedAmenities.remove(amenity);
                    }
                  });
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
          _buildSectionHeader('Localisation sur la carte'),
          SizedBox(height: 12),
          Container(
            height: 200,
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
                  print("⬅️ Retour à l'étape ${_currentStep - 1}");
                  setState(() => _currentStep--);
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
              onPressed: _isLoading ? null : () {
                print("🔄 Bouton cliqué - Step: $_currentStep, Loading: $_isLoading");

                if (_currentStep < 2) {
                  print("➡️ Navigation vers l'étape ${_currentStep + 1}");
                  setState(() => _currentStep++);
                } else {
                  print("🚀 Lancement de la publication...");
                  _handleCreatePropertyPost();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _isLoading ? _greyColor : _primaryColor,
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
                _currentStep == 2 ? 'Publier l\'annonce' : 'Continuer',
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
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300, width: 1),
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
          setState(() {
            _selectedCity = newValue;
            _updateDistrictsForCity();
          });
        },
        validator: (value) {
          if (value == null) {
            return 'Veuillez sélectionner une ville';
          }
          return null;
        },
        decoration: InputDecoration(
          labelText: 'Ville',
          labelStyle: TextStyle(color: Colors.grey.shade600),
          prefixIcon: Icon(Icons.location_city_rounded, color: Colors.blue.shade600, size: 20),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        icon: Icon(Icons.arrow_drop_down_rounded, color: Colors.grey.shade600),
        dropdownColor: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  Widget _buildModernDistrictDropdown() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300, width: 1),
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
          setState(() {
            _selectedDistrict = newValue;
            _updateCommunesForDistrict();
          });
        },
        validator: (value) {
          if (value == null) {
            return 'Veuillez sélectionner un district';
          }
          return null;
        },
        decoration: InputDecoration(
          labelText: 'District',
          labelStyle: TextStyle(color: Colors.grey.shade600),
          prefixIcon: Icon(Icons.account_balance_rounded, color: Colors.blue.shade600, size: 20),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        icon: Icon(Icons.arrow_drop_down_rounded, color: Colors.grey.shade600),
        dropdownColor: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  Widget _buildModernCommuneDropdown() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300, width: 1),
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
          setState(() {
            _selectedCommune = newValue;
          });
        },
        validator: (value) {
          if (value == null) {
            return 'Veuillez sélectionner une commune';
          }
          return null;
        },
        decoration: InputDecoration(
          labelText: 'Commune',
          labelStyle: TextStyle(color: Colors.grey.shade600),
          prefixIcon: Icon(Icons.place_rounded, color: Colors.blue.shade600, size: 20),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        icon: Icon(Icons.arrow_drop_down_rounded, color: Colors.grey.shade600),
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
    required String? Function(String?) validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300, width: 1),
        color: Colors.white,
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey.shade400),
          prefixIcon: Icon(icon, color: prefixIconColor, size: 20),
          suffixText: suffixText,
          suffixStyle: TextStyle(
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          floatingLabelBehavior: FloatingLabelBehavior.auto,
        ),
        style: TextStyle(
          fontSize: 14,
          color: Colors.grey.shade800,
          fontWeight: FontWeight.w500,
        ),
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