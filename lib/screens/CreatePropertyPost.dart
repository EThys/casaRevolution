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
  final Color darkBlue = Color(0xFF0D47A1);
  final Color _darkColor = Color(0xFF1A1D26);
  final Color _lightColor = Color(0xFFF8F9FA);
  final Color _greyColor = Color(0xFF6C757D);
  final Color _successColor = Color(0xFF38B000);
  final Color _cardColor = Colors.white;
  final Color _borderColor = Color(0xFFE9ECEF);

  // Form controllers
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _bedroomsController = TextEditingController();
  final TextEditingController _bathroomsController = TextEditingController();
  final TextEditingController _livingRoomsController = TextEditingController();
  final TextEditingController _kitchensController = TextEditingController();
  final TextEditingController _areaController = TextEditingController();
  final TextEditingController _floorController = TextEditingController();

  // State variables
  bool _isForRent = true;
  bool _isLoading = false;
  List<XFile> _selectedImages = [];
  Set<String> _selectedAmenities = {};
  LatLng? _selectedLocation;
  final ImagePicker _picker = ImagePicker();
  int _currentStep = 0;

  String? _selectedCategory;
  AutovalidateMode _autoValidateMode = AutovalidateMode.disabled;

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

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
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

  Future<void> _pickImages() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage(
        imageQuality: 85,
        maxWidth: 1440,
      );
      if (images.isNotEmpty) {
        setState(() {
          _selectedImages.addAll(images);
        });
      }
    } on PlatformException catch (e) {
      print('Failed to pick images: $e');
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  Future<void> _handleCreatePropertyPost() async {
    setState(() {
      _autoValidateMode = AutovalidateMode.always;
    });

    await Future.delayed(Duration(milliseconds: 50));

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    if (_selectedImages.length < 3) {
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
      for (var image in _selectedImages) {
        final bytes = await image.readAsBytes();
        final base64String = base64Encode(bytes);
        images.add({
          "base64": base64String,
          "isMain": images.isEmpty, // Set the first image as main
        });
      }

      final propertyData = {
        "title": _titleController.text,
        "description": _descriptionController.text,
        "price": double.tryParse(_priceController.text) ?? 0,
        "address": _addressController.text,
        "commune": "Lemba", // You can make this dynamic as well
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

      print("EEEEEEEEEEEEEEEE${res}");

      if (!mounted) return;

      if (res.data['success'] == true) {
        print("MATAMAAAAAA${res.data['success']}");
        FancyNotification.show(context, "Annonce publiée avec succès!", isError: false);
        await Future.delayed(const Duration(milliseconds: 1500));
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            Routes.homeRoute, // Replace with your desired route
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
    // Map the category to the corresponding ID
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
        return 1; // Default to appartement
    }
  }

  int _getFeatureId(String amenity) {
    // Map the amenity to the corresponding ID
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
        return 1; // Default to Wi-Fi
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
              _buildStepLabel(0, 'Type'),
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
        'label': 'Studio',
        'value': 'Studios',
        'color': Color(0xFF1976D2) // Couleur personnalisée pour chaque catégorie
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
        'value': 'Bureaux',
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
                  // Conteneur de l'image avec effet de sélection
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
                        // Image originale sans filtre de couleur
                        Center(
                          child: Padding(
                            padding: EdgeInsets.all(12),
                            child: Image.asset(
                              category['image'] as String,
                              fit: BoxFit.contain,
                              // Suppression du color filter pour voir les images en couleur
                            ),
                          ),
                        ),
                        // Overlay pour l'effet de sélection
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
        _buildSectionHeader('Photos de la propriété'),
        SizedBox(height: 8),
        Text(
          'Ajoutez au moins 3 photos de bonne qualité',
          style: TextStyle(
            color: _greyColor,
            fontSize: 13,
          ),
        ),
        SizedBox(height: 16),

        // Photo grid
        if (_selectedImages.isEmpty)
          _buildEmptyPhotoUpload()
        else
          _buildPhotoGrid(),
      ],
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

  Widget _buildEmptyPhotoUpload() {
    return GestureDetector(
      onTap: _pickImages,
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _borderColor,
            width: 1.5,
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: _primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.cloud_upload_outlined,
                size: 32,
                color: _primaryColor,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Ajouter des photos',
              style: TextStyle(
                color: _primaryColor,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Formats supportés: JPG, PNG',
              style: TextStyle(
                color: _greyColor,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoGrid() {
    return Column(
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1,
          ),
          itemCount: _selectedImages.length + 1,
          itemBuilder: (context, index) {
            if (index == _selectedImages.length) {
              return GestureDetector(
                onTap: _pickImages,
                child: Container(
                  decoration: BoxDecoration(
                    color: _lightColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _borderColor,
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.add_rounded,
                      size: 32,
                      color: _primaryColor,
                    ),
                  ),
                ),
              );
            }
            return ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  Image.file(
                    File(_selectedImages[index].path),
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () => _removeImage(index),
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
              ),
            );
          },
        ),
        SizedBox(height: 12),
        Text(
          '${_selectedImages.length} photo(s) sélectionnée(s)',
          style: TextStyle(
            color: _greyColor,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildStep2() {
    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Informations de base'),
          SizedBox(height: 12),
          _buildModernTextField(
            controller: _titleController,
            label: 'Titre de l\'annonce',
            hint: 'Magnifique appartement avec vue...',
            icon: Icons.title_rounded,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Veuillez entrer un titre';
              }
              return null;
            },
          ),
          SizedBox(height: 5),
          _buildModernTextField(
            controller: _priceController,
            label: _isForRent ? 'Prix mensuel' : 'Prix de vente',
            hint: _isForRent ? '1200' : '450000',
            icon: Icons.attach_money_rounded,
            keyboardType: TextInputType.number,
            suffixText: '\$',
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
          SizedBox(height: 5),
          _buildModernTextField(
            controller: _descriptionController,
            label: 'Description',
            hint: 'Décrivez en détail la propriété...',
            icon: Icons.description_rounded,
            maxLines: 4,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Veuillez entrer une description';
              }
              if (value.length < 50) {
                return 'La description doit faire au moins 50 caractères';
              }
              return null;
            },
          ),
          SizedBox(height: 5),
          _buildSectionHeader('Adresse'),
          SizedBox(height: 5),
          _buildModernTextField(
            controller: _addressController,
            label: 'Adresse complète',
            hint: '18eme Rue Limete, av de la foire',
            icon: Icons.location_on_rounded,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Veuillez entrer une adresse';
              }
              return null;
            },
          ),
          SizedBox(height: 5),
          _buildSectionHeader('Commune'),
          SizedBox(height: 5),
          _buildModernTextField(
            controller: _addressController,
            label: 'Commune',
            hint: 'Lemba',  
            icon: Icons.location_on_rounded,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Veuillez entrer une commune';
              }
              return null;
            },
          ),
          SizedBox(height: 5),
          _buildSectionHeader('Caractéristiques'),
          SizedBox(height: 5),
          GridView.count(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 3,
            children: [
              _buildFeatureInput(
                controller: _bedroomsController,
                label: 'Chambres',
                icon: FontAwesomeIcons.bed,
              ),
              _buildFeatureInput(
                controller: _bathroomsController,
                label: 'Salles de bain',
                icon: FontAwesomeIcons.bath,
              ),
              _buildFeatureInput(
                controller: _livingRoomsController,
                label: 'Salons',
                icon: FontAwesomeIcons.couch,
              ),
              _buildFeatureInput(
                controller: _kitchensController,
                label: 'Cuisines',
                icon: FontAwesomeIcons.kitchenSet,
              ),
              _buildFeatureInput(
                controller: _areaController,
                label: 'Surface (m²)',
                icon: FontAwesomeIcons.rulerCombined,
              ),
              _buildFeatureInput(
                controller: _floorController,
                label: 'Étage',
                icon: FontAwesomeIcons.building,
              ),
            ],
          ),
        ],
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

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    IconData? icon,
    int? maxLines = 1,
    TextInputType? keyboardType,
    String? suffixText,
    String? Function(String?)? validator,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(9),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: Offset(0, 4),
          )
        ],
      ),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        validator: validator,
        onChanged: (_) {
          // Revalide dynamiquement le champ à chaque frappe
          if (_formKey.currentState != null) {
            _formKey.currentState!.validate();
          }
        },
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: icon != null ? Icon(icon, color: _greyColor) : null,
          suffixText: suffixText,
          suffixStyle: TextStyle(color: _darkColor),

          filled: true,
          fillColor: _cardColor,
          contentPadding: EdgeInsets.symmetric(
            horizontal: 16,
            vertical: maxLines == 1 ? 0 : 16,
          ),

          // Label style
          labelStyle: TextStyle(color: _greyColor),

          // Bordures : normales, focus, erreur
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: BorderSide(color: _borderColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: BorderSide(color: _primaryColor, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: BorderSide(color: Colors.red),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: BorderSide(color: Colors.red, width: 1.5),
          ),
        ),
      ),
    );
  }


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