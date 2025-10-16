import 'dart:convert';

import 'package:casa/controllers/PropertyCtrl.dart';
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

import '../widgets/SnackbarHelper.dart';

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
  final TextEditingController _communeController = TextEditingController();
  final TextEditingController _bedroomsController = TextEditingController();
  final TextEditingController _bathroomsController = TextEditingController();
  final TextEditingController _livingRoomsController = TextEditingController();
  final TextEditingController _kitchensController = TextEditingController();
  final TextEditingController _areaController = TextEditingController();
  final TextEditingController _floorController = TextEditingController();

  // State variables
  bool _isForRent = true;
  bool _isLoading = false;
  Set<String> _selectedAmenities = {};
  LatLng? _selectedLocation;
  final ImagePicker _picker = ImagePicker();
  int _currentStep = 0;

  String? _selectedCategory;
  AutovalidateMode _autoValidateMode = AutovalidateMode.disabled;

  // Categories d'images par pièces
  final List<ImageCategory> _imageCategories = [
    ImageCategory(
      id: 'bedroom',
      name: 'Chambre',
      icon: FontAwesomeIcons.bed,
      color: Color(0xFF2196F3),
      description: 'Photos des chambres',
    ),
    ImageCategory(
      id: 'living_room',
      name: 'Salon',
      icon: FontAwesomeIcons.couch,
      color: Color(0xFF2196F3),
      description: 'Photos du salon',
    ),
    ImageCategory(
      id: 'kitchen',
      name: 'Cuisine',
      icon: FontAwesomeIcons.kitchenSet,
      color: Color(0xFF2196F3),
      description: 'Photos de la cuisine',
    ),
    ImageCategory(
      id: 'bathroom',
      name: 'Salle de bain',
      icon: FontAwesomeIcons.bath,
      color: Color(0xFF2196F3),
      description: 'Photos de la salle de bain',
    ),
    ImageCategory(
      id: 'exterior_front',
      name: 'Devant maison',
      icon: FontAwesomeIcons.home,
      color: Color(0xFF2196F3),
      description: 'Photos de la façade',
    ),
    ImageCategory(
      id: 'exterior_back',
      name: 'Arrière maison',
      icon: FontAwesomeIcons.tree,
      color: Color(0xFF2196F3),
      description: 'Photos de l\'arrière',
    ),
    ImageCategory(
      id: 'other',
      name: 'Autres pièces',
      icon: FontAwesomeIcons.plus,
      color: Color(0xFF607D8B),
      description: 'Autres photos',
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

  String? _selectedDistrict;
  String? _selectedCommune;
  String? _selectedQuartier;

  final Map<String, List<String>> _districtCommunes = {
    'Funa': ['Bandalungwa', 'Bumbu', 'Kalamu', 'Kasa-Vubu', 'Makala', 'Ngiri-Ngiri', 'Selembao'],
    'Mont-Amba': ['Kisenso', 'Lemba', 'Limete', 'Matete', 'Mont-Ngafula', 'Ngaba'],
    'Lukunga': ['Barumbu', 'Gombe', 'Kinshasa', 'Kintambo', 'Lingwala', 'Ngaliema'],
    'Tshangu': ['Kimbanseke', 'Maluku', 'Masina', 'Ndjili', 'Nsele'],
  };

  final Map<String, List<String>> _communeQuartiers = {
    'Bandalungwa': ['TSHIBANGU', 'MAKELELE', 'KASA-VUBU', 'BISENGO', 'ADOULA', 'LUBUNDI', 'MOLAERT', 'LUMUMBA'],
    'Barumbu': ['BITSHAKA', 'FUNA I', 'FUNA II', 'KAPINGA BAPU', 'KASAFI', 'LIBULU', 'MOZINDO', 'N\'DOLO', 'TSHIMANGA'],
    'Bumbu': ['DIPIYA', 'MONGALA', 'UBANGI', 'LOKORO', 'KASAI', 'KWANGO', 'LUKENIE', 'MAI-NDOMBE', 'MATADI', 'LIEUTENANT MBAKI', 'MBANDAKA', 'MFIMI', 'NTOMBA'],
    'Gombe': ['BATETELA', 'HAUT COMMANDEMENT', 'CROIX-ROUGE', 'LEMERA', 'GOLF', 'FLEUVE', 'COMMERCE', 'GARE', 'REVOLUTION', 'CLINIQUE'],
    'Kalamu': ['MATONGE I', 'MATONGE II', 'MATONGE III', 'YOLO NORD I', 'YOLO NORD II', 'YOLO NORD III', 'YOLO SUD I', 'YOLO SUD II', 'YOLO SUD III', 'YOLO SUD IV', 'KAUKA I', 'KAUKA II', 'KAUKA III', 'PINZI', 'IMMO CONGO'],
    'Kasa-Vubu': ['ANCIENS COMBATTANTS', 'ASSOSSA', 'KATANGA', 'LODJA', 'LUBUMBASHI', 'ONC', 'SALANGO'],
    'Kimbanseke': ['17 MAI', 'BAHUMBI', 'BAMBOMA', 'BIYELA', 'BOMA', 'DISSASI', 'ESANGA', 'KAMBA MULUMBA', 'KASA-VUBU', 'KIKIMI', 'KISANGANI', 'KISANTU IR BEN', 'KUTU', 'LUEBO', 'MALONDA', 'MANGANA', 'MAVIOKELE', 'MBUALA', 'MFUMU NKENTO', 'MIKONDO', 'MOKALI', 'MULIE', 'NGAMAZIDA', 'NGAMPANI', 'NGANDU', 'NGANGA', 'NSUMABWA', 'REVOLUTION', 'SAKOMBI', 'SALONGO'],
    'Kinshasa': ['AKETI', 'BOYOMA', 'DJALO', 'MADIMBA', 'MONGALA', 'NGBAKA', 'PENDE'],
    'Kintambo': ['ITIMBIRI', 'KILIMANI', 'LISALA', 'LUBUDILUKA', 'NGANDA', 'SALONGO', 'TSHINKELA', 'WENZE'],
    'Kisenso': ['REGIDESO', 'KUMBU', 'MBUKU', 'AMBA', 'MISSION MUJINGA', 'LIBERATION', '17 MAI', 'NSOLA', 'BIKANGA'],
    'Lemba': ['MADRANDELLE', 'MASANO', 'KIMPWANZA', 'COMMERCIALE', 'MOLO', 'FOIRE', 'DE L\'ECOLE', 'ECHANGEUR', 'GOMBELI', 'SALONGO', 'LIVULU', 'KEMI', 'MBANZA-LEMBA'],
    'Limete': ['AGRICOLE', 'FUNA', 'INDUSTRIEL', 'KINGABWA', 'MASIALA', 'MAYULU', 'MBAMU', 'MOMBELE', 'MOSOSO', 'MOTEBA', 'NDANU', 'NZADI', 'RESIDENTIEL', 'SALONGO'],
    'Lingwala': ['LUFUNGULA', 'SINGA', 'MOPEPE', 'WENZE', 'PLC', '30 JUIN', 'LOKOLE', 'PAKA-DJUMA', 'VOIX DU PEUPLE', 'NGUNDA-LOKOMBE'],
    'Makala': ['BAGOTA', 'BAHUMBU', 'BOLIMA', 'KABILA', 'KISANTU', 'KWANGO', 'LEMBA VILLAGE', 'MABULU'],
    'Maluku': ['BU', 'DUMI', 'KIKIMI', 'KIMPONGO', 'KINGAKATI', 'KINGONO', 'KINZONO', 'MBANKANA', 'MALUKU', 'MAI-DOMBE', 'MANGE-NGENGE', 'MENKAO', 'MONACO', 'MONGATA', 'MWE', 'NGAMA', 'NGUMA', 'YOSO', 'YO'],
    'Masina': ['ABBATOIR', 'BOBA', 'LONGO', 'EFOLOKO', 'KASAI', 'KIMBANGU', 'MAFUTA-KIZOLA', 'MATADI', 'MFUMU-SUKA', 'NZUNZI WA MBOMBO', 'PELENDE', 'SANS-FIL', 'TSHANGO', 'TSHUENZE', 'TELEVISION'],
    'Matete': ['MANDINA', 'MAI-NDOMBE', 'MBOKOLO', 'KWENGE I', 'KWENGE II', 'NGILIMA I', 'NGILIMA II', 'LOKORO', 'ANUNGA', 'NGUFU', 'KINDA I', 'KINDA II', 'KUNDA I', 'KUNDA II', 'VIAZA', 'BANUNU I', 'BANUNU II', 'BATANDU I', 'BATANDU II', 'DEBONHOMME', 'PULULU I', 'PULULU II', 'BABOMA', 'KINZAZI', 'TOMBA', 'MONGO', 'VITAMINE I', 'VITAMINE II', 'BATENDE', 'KINSATU', 'MUTOTO', 'MPUNDI', 'BAHUMBU I', 'BAHUMBU II', 'MALANDI I', 'MALANDI II', 'LOKELE I', 'LOKELE II', 'BATEKE', 'SINGA', 'KINSIMBU'],
    'Mont-Ngafula': ['CPA MUSHIE', 'KIMBONDO', 'KIMBUTA', 'KIMWENZO', 'KIMBUALA', 'KINDELE', 'LUTUNDELE', 'MAMA MOBUTU', 'MAMA YEMO', 'MASANGA MBILA', 'MUSAGU-TELECOM', 'MAZAMBA', 'MATADI KIBALA', 'MATADI MAYO', 'MITENDI', 'MBUKI', 'NDJILI-KILAMBA', 'NGANSELE', 'PLATEAU I', 'PLATEAU II', 'VUNDA-MANENGA'],
    'Ndjili': ['QUARTIER 1', 'QUARTIER 2', 'QUARTIER 3', 'QUARTIER 4', 'QUARTIER 5', 'QUARTIER 6', 'QUARTIER 7', 'QUARTIER 8', 'QUARTIER 9', 'QUARTIER 10', 'QUARTIER 11', 'QUARTIER 12', 'QUARTIER 13'],
    'Ngaba': ['MUKULUA', 'BULA-MBEMBA', 'MATEBA', 'LUYI', 'MPILA', 'BAOBAB'],
    'Ngaliema': ['LUKUNGA', 'NGOMBA KIKUSA', 'BUMBA', 'BINZA PIGEON DJELO BINZA', 'BANGU', 'PUNDA', 'KIMPE', 'ANCIENS COMBATTANTS', 'BASOKO', 'CONGO', 'JOLI PARC', 'KINKENDA', 'KINSUKA PECHEUR', 'LONZO', 'MUSEYI', 'MAMAN-YEMO', 'MANENGA', 'MFINDA', 'MONGANYA', 'LUBUDI'],
    'Ngiri-Ngiri': ['DIANGENDA', '24 NOVEMBRE', 'SAIO', 'PETIT-PETIT', 'ASSOSSA', 'DIOMI', 'KARTHOUM', 'ELENGESA'],
    'Nsele': ['BADARA', 'BIBWA', 'D.I.C', 'DINGI-DINGI', 'DOMAINE', 'MIKALA I', 'MIKALA II', 'KINKOLE', 'PECHEURS', 'BAHUMBU I', 'BAHUMBU II', 'SICOTRA/COKALI', 'MIKONDO(BRASSERIE)', 'MIKONGA(CITE DE MPASA)', 'MAI-NDOMBE(VILLAGE)', 'MPASSA MABA', 'KINZONO', 'MANGENGE', 'MOBA NSE', 'MENKAO(VILLAGE)', 'MONACO', 'NGIMA(VILLAGE)', 'KINGAKATI(VILLAGE)', 'TALANGAI'],
    'Selembao': ['BADIADING', 'CITE VERTE', 'INGA', 'HERADY', 'KALUNGA', 'KINGU', 'KONDE', 'LIBERATION', 'LUBUDI', 'MADIATA', 'MBOLA', 'MOLENDE', 'MUANA', 'NTUNU', 'NDOBE', 'NGAFANI', 'KOMBE', 'NKULU', 'PULULU MBAMBU'],
  };

  List<String> _availableCommunes = [];
  List<String> _availableQuartiers = [];

  @override
  void initState() {
    super.initState();
    // Initialize image categories
    for (var category in _imageCategories) {
      _selectedImages[category.id] = [];
      if (category.id == 'other') {
        _otherRoomDescriptions[category.id] = '';
      }
    }

    // Initialize available communes based on first district
    if (_districtCommunes.isNotEmpty) {
      _selectedDistrict = _districtCommunes.keys.first;
      _availableCommunes = _districtCommunes[_selectedDistrict]!;

      if (_availableCommunes.isNotEmpty) {
        _selectedCommune = _availableCommunes.first;
        _updateAvailableQuartiers();
      }
    }
  }

  void _updateAvailableCommunes() {
    setState(() {
      _availableCommunes = _districtCommunes[_selectedDistrict] ?? [];
      _selectedCommune = _availableCommunes.isNotEmpty ? _availableCommunes.first : null;
      _updateAvailableQuartiers();
    });
  }

  void _updateAvailableQuartiers() {
    setState(() {
      _availableQuartiers = _communeQuartiers[_selectedCommune] ?? [];
      _selectedQuartier = _availableQuartiers.isNotEmpty ? _availableQuartiers.first : null;
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
    setState(() {
      _autoValidateMode = AutovalidateMode.always;
    });

    await Future.delayed(Duration(milliseconds: 50));

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    if (_totalImagesCount < 3) {
      FancyNotification.show(context, "Veuillez ajouter au moins 3 photos", isError: true);
      return;
    }

    if (_currentStep == 2 && _selectedAmenities.isEmpty) {
      FancyNotification.show(context, "Veuillez sélectionner au moins un équipement", isError: true);
      return;
    }

    if (!mounted || _isLoading) return;

    setState(() => _isLoading = true);

    FocusScope.of(context).unfocus();

    final isConnected = await NetworkUtils.checkInternetConnectivity();
    if (!isConnected) {
      FancyNotification.show(context, "Pas de connexion internet");
      setState(() => _isLoading = false);
      return;
    }

    try {
      List<Map<String, dynamic>> images = [];
      bool isFirstImage = true;

      // Process images by category
      for (var category in _imageCategories) {
        final categoryImages = _selectedImages[category.id] ?? [];
        for (var image in categoryImages) {
          final bytes = await image.readAsBytes();
          final base64String = base64Encode(bytes);
          images.add({
            "base64": base64String,
            "isMain": isFirstImage,
            "category": category.name,
            "description": category.id == 'other' ?
            _otherRoomDescriptions[category.id] ?? category.description :
            category.description,
          });
          isFirstImage = false;
        }
      }

      final propertyData = {
        "title": _titleController.text,
        "description": _descriptionController.text,
        "price": double.tryParse(_priceController.text) ?? 0,
        "address": "${_selectedDistrict},${_selectedCommune},${_selectedQuartier}",
        "guarantie":_guaranteeController.text,
        "commune": _selectedCommune,
        "quartier":_selectedQuartier,
        "district":_selectedDistrict,
        "city": "Kinshasa",
        "postalCode": "243",
        "latitude": _selectedLocation?.latitude ?? 0.0,
        "longitude": _selectedLocation?.longitude ?? 0.0,
        "surface": double.tryParse(_areaController.text) ?? 0,
        "rooms": (int.tryParse(_livingRoomsController.text) ?? 0) +
            (int.tryParse(_bedroomsController.text) ?? 0) +
            (int.tryParse(_kitchensController.text) ?? 0),
        "bedrooms": int.tryParse(_bedroomsController.text) ?? 0,
        "floor": int.tryParse(_floorController.text) ?? 0,
        "bathroom":int.tryParse(_bathroomsController.text) ?? 0,
        "kitchen":int.tryParse(_kitchensController.text) ?? 0,
        "living_room":int.tryParse(_livingRoomsController.text) ?? 0,
        "sold": false,
        "transactionType": _isForRent ? "location" : "vente",
        "isAvailable": true,
        "PropertyTypeId": _getPropertyTypeId(_selectedCategory),
        "UserId": 1,
        "features": _selectedAmenities.map((amenity) => _getFeatureId(amenity)).toList(),
        "images": images,
      };

      final ctrl = context.read<PropertyController>();
      final res = await ctrl.createProperty(propertyData);

      if (!mounted) return;

      if (res.data['success'] == true) {
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
        FancyNotification.show(context, errorMessage);
      }
    } catch (e) {
      FancyNotification.show(context, "Erreur technique lors de la publication de l'annonce");
      print("Create property error: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  int _getPropertyTypeId(String? category) {
    switch (category) {
      case 'appartement':
        return 1;
      case 'maison':
        return 2;
      case 'villa':
        return 3;
      case 'office':
        return 4;
      case 'studio':
        return 5;
      case 'terrain':
        return 6;
      case 'hotel':
        return 7;
      case 'warehouse':
        return 8;
      default:
        return 1;
    }
  }

  int _getFeatureId(String amenity) {
    switch (amenity) {
      case 'Wi-Fi':
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
      body: Column(
        children: [
          // Progress indicator
          _buildProgressIndicator(),

          // Main content
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: IndexedStack(
                index: _currentStep,
                children: [
                  _buildStep1(), // Property type and photos
                  _buildStep2(), // Property details
                  _buildStep3(), // Amenities
                ],
              ),
            ),
          ),

          // Navigation buttons
          _buildBottomNavigation(),
        ],
      ),
    );
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
        'value': 'Appart',
        'color': Color(0xFF10B981),
      },
      {
        'image': 'assets/images/maisons.png',
        'label': 'Maisons',
        'value': 'Maison',
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
        'value': 'Hotel',
        'color': Color(0xFF1976D2),
      },
      {
        'image': 'assets/images/plage.png',
        'label': 'Vacances',
        'value': 'Vacance',
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

  Widget _buildStep1() {
    return Column(
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
      ],
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

          // Description field for "other" category
          if (category.id == 'other')
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextFormField(
                onChanged: (value) => _otherRoomDescriptions[category.id] = value,
                decoration: InputDecoration(
                  hintText: 'Décrivez ces pièces (ex: garage, buanderie, etc.)',
                  filled: true,
                  fillColor: _lightColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _borderColor),
                  ),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                maxLines: 2,
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
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
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

            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                Expanded(
                  child: _buildModernDropdown(
                    label: 'District',
                    value: _selectedDistrict,
                    items: _districtCommunes.keys.toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedDistrict = newValue;
                        _updateAvailableCommunes();
                      });
                    },
                    icon: Icons.location_city_rounded,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Veuillez sélectionner un district';
                      }
                      return null;
                    },
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _buildModernDropdown(
                    label: 'Commune',
                    value: _selectedCommune,
                    items: _availableCommunes,
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedCommune = newValue;
                        _updateAvailableQuartiers();
                      });
                    },
                    icon: Icons.account_balance_rounded,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Veuillez sélectionner une commune';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            _buildModernDropdown(
              label: 'Quartier',
              value: _selectedQuartier,
              items: _availableQuartiers,
              onChanged: (String? newValue) {
                setState(() {
                  _selectedQuartier = newValue;
                });
              },
              icon: Icons.place_rounded,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Veuillez sélectionner un quartier';
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
              ],
            ),
          ],
        ),
      ),
    );
  }

// Nouvelle méthode pour les en-têtes de section modernes
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

// Méthode améliorée pour les inputs de caractéristiques
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

// Méthode améliorée pour les dropdowns
  Widget _buildModernDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required Function(String?) onChanged,
    required IconData icon,
    required String? Function(String?) validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300, width: 1),
      ),
      child: DropdownButtonFormField<String>(
        value: value,
        items: items.map((String item) {
          return DropdownMenuItem<String>(
            value: item,
            child: Text(
              item,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
            ),
          );
        }).toList(),
        onChanged: onChanged,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey.shade600),
          prefixIcon: Icon(icon, color: Colors.blue.shade600, size: 20),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        icon: Icon(Icons.arrow_drop_down_rounded, color: Colors.grey.shade600),
        dropdownColor: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

// Méthode améliorée pour les text fields
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

  Widget _buildStep3() {
    return Column(
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
          runSpacing: 2,
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
        SizedBox(height: 16),
        _buildSectionHeader('Localisation'),
        SizedBox(height: 12),
        Container(
          height: 180,
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
              ],
            ),
          ),
        ),
      ],
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
                onPressed: () => setState(() => _currentStep--),
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
              onPressed: () {
                if (_currentStep < 2) {
                  setState(() => _currentStep++);
                } else {
                  _handleCreatePropertyPost();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
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

  // Widget _buildModernDropdown({
  //   required String label,
  //   required String? value,
  //   required List<String> items,
  //   required Function(String?) onChanged,
  //   IconData? icon,
  //   String? Function(String?)? validator,
  //   String? hintText,
  //   bool isRequired = false,
  // }) {
  //   return Container(
  //     margin: const EdgeInsets.only(bottom: 10),
  //     decoration: BoxDecoration(
  //       borderRadius: BorderRadius.circular(12),
  //       boxShadow: [
  //         BoxShadow(
  //           color: Colors.black.withOpacity(0.05),
  //           blurRadius: 12,
  //           offset: const Offset(0, 6),
  //         ),
  //       ],
  //     ),
  //     child: DropdownButtonFormField<String>(
  //       value: value,
  //       onChanged: onChanged,
  //       items: items.map((String item) {
  //         return DropdownMenuItem<String>(
  //           value: item,
  //           child: Text(
  //             item,
  //             style: const TextStyle(
  //               fontSize: 15,
  //               fontWeight: FontWeight.w500,
  //             ),
  //           ),
  //         );
  //       }).toList(),
  //       decoration: InputDecoration(
  //         labelText: label,
  //         hintText: hintText,
  //         hintStyle: TextStyle(color: Colors.grey[500], fontSize: 15),
  //         prefixIcon: icon != null
  //             ? Icon(icon, color: Colors.grey[600], size: 22)
  //             : null,
  //         filled: true,
  //         fillColor: Colors.white,
  //         contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
  //         labelStyle: TextStyle(
  //           color: Colors.grey[700],
  //           fontSize: 15,
  //           fontWeight: FontWeight.w500,
  //         ),
  //         floatingLabelStyle: TextStyle(
  //           color: _primaryColor,
  //           fontSize: 16,
  //           fontWeight: FontWeight.w600,
  //         ),
  //         enabledBorder: OutlineInputBorder(
  //           borderRadius: BorderRadius.circular(12),
  //           borderSide: BorderSide(color: Colors.grey[300]!, width: 1.5),
  //         ),
  //         focusedBorder: OutlineInputBorder(
  //           borderRadius: BorderRadius.circular(12),
  //           borderSide: BorderSide(color: _primaryColor, width: 2),
  //         ),
  //         errorBorder: OutlineInputBorder(
  //           borderRadius: BorderRadius.circular(12),
  //           borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
  //         ),
  //         focusedErrorBorder: OutlineInputBorder(
  //           borderRadius: BorderRadius.circular(12),
  //           borderSide: const BorderSide(color: Colors.redAccent, width: 2),
  //         ),
  //         suffixIcon: isRequired
  //             ? const Padding(
  //           padding: EdgeInsets.only(right: 12),
  //           child: Text(
  //             '*',
  //             style: TextStyle(
  //               color: Colors.redAccent,
  //               fontSize: 18,
  //               fontWeight: FontWeight.bold,
  //             ),
  //           ),
  //         )
  //             : null,
  //       ),
  //       validator: validator,
  //       icon: Icon(Icons.keyboard_arrow_down_rounded,
  //           color: Colors.grey[600], size: 24),
  //       borderRadius: BorderRadius.circular(12),
  //       isExpanded: true,
  //       dropdownColor: Colors.white,
  //       style: TextStyle(
  //         color: Colors.grey[800],
  //         fontSize: 15,
  //         fontWeight: FontWeight.w500,
  //       ),
  //       menuMaxHeight: 300,
  //       selectedItemBuilder: (BuildContext context) {
  //         return items.map<Widget>((String item) {
  //           return Container(
  //             alignment: Alignment.centerLeft,
  //             child: Text(
  //               value ?? '',
  //               style: TextStyle(
  //                 color: Colors.grey[800],
  //                 fontSize: 15,
  //                 fontWeight: FontWeight.w600,
  //               ),
  //             ),
  //           );
  //         }).toList();
  //       },
  //     ),
  //   );
  // }

  // Widget _buildModernTextField({
  //   required TextEditingController controller,
  //   required String label,
  //   String? hint,
  //   IconData? icon,
  //   int? maxLines = 1,
  //   TextInputType? keyboardType,
  //   String? suffixText,
  //   String? Function(String?)? validator,
  // }) {
  //   return Container(
  //     margin: EdgeInsets.only(bottom: 16),
  //     decoration: BoxDecoration(
  //       color: _cardColor,
  //       borderRadius: BorderRadius.circular(9),
  //       boxShadow: [
  //         BoxShadow(
  //           color: Colors.black.withOpacity(0.03),
  //           blurRadius: 8,
  //           offset: Offset(0, 4),
  //         )
  //       ],
  //     ),
  //     child: TextFormField(
  //       controller: controller,
  //       maxLines: maxLines,
  //       keyboardType: keyboardType,
  //       validator: validator,
  //       onChanged: (_) {
  //         if (_formKey.currentState != null) {
  //           _formKey.currentState!.validate();
  //         }
  //       },
  //       decoration: InputDecoration(
  //         labelText: label,
  //         hintText: hint,
  //         prefixIcon: icon != null ? Icon(icon, color: _greyColor) : null,
  //         suffixText: suffixText,
  //         suffixStyle: TextStyle(color: _darkColor),
  //
  //         filled: true,
  //         fillColor: _cardColor,
  //         contentPadding: EdgeInsets.symmetric(
  //           horizontal: 16,
  //           vertical: maxLines == 1 ? 0 : 16,
  //         ),
  //
  //         labelStyle: TextStyle(color: _greyColor),
  //
  //         enabledBorder: OutlineInputBorder(
  //           borderRadius: BorderRadius.circular(9),
  //           borderSide: BorderSide(color: _borderColor),
  //         ),
  //         focusedBorder: OutlineInputBorder(
  //           borderRadius: BorderRadius.circular(9),
  //           borderSide: BorderSide(color: _primaryColor, width: 1.5),
  //         ),
  //         errorBorder: OutlineInputBorder(
  //           borderRadius: BorderRadius.circular(9),
  //           borderSide: BorderSide(color: Colors.red),
  //         ),
  //         focusedErrorBorder: OutlineInputBorder(
  //           borderRadius: BorderRadius.circular(9),
  //           borderSide: BorderSide(color: Colors.red, width: 1.5),
  //         ),
  //       ),
  //     ),
  //   );
  // }

  Widget _buildFeatureInput({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
            ),
            child: Icon(
              icon,
              color: _primaryColor,
              size: 20,
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: TextFormField(
                controller: controller,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: label,
                  border: InputBorder.none,
                  labelStyle: TextStyle(
                    color: _greyColor,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
        ],
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