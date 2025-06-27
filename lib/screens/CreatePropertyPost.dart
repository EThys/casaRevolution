import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
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

  // Amenities list
  final List<String> _amenitiesList = [
    'Wi-Fi',
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

  void _submitForm() {
    // Vérifie si le formulaire est valide
    if (_formKey.currentState!.validate()) {
      // Vérifie qu'au moins 3 photos sont sélectionnées
      if (_selectedImages.length < 3) {
        SnackBarHelper.show(context, "Veuillez ajouter au moins 3 photos", isError: true);
        return;
      }

      if (_currentStep == 2 && _selectedAmenities.isEmpty) {
        SnackBarHelper.show(context, "Veuillez sélectionner au moins un équipement", isError: true);
        return;
      }

      setState(() {
        _isLoading = true;
      });

      Future.delayed(Duration(seconds: 2), () {
        setState(() {
          _isLoading = false;
        });
        // final propertyData = {
        //   // Informations principales
        //   "title": _titleController.text,
        //   "description": _descriptionController.text,
        //   "price": double.tryParse(_priceController.text) ?? 0,
        //
        //   // Adresse et localisation
        //   "address": _addressController.text,
        //   "commune": _selectedCommune, // Variable à définir selon votre implémentation
        //   "city": _selectedCity, // Variable à définir
        //   "postalCode": _postalCodeController.text,
        //   "latitude": _latitude, // Variable à définir
        //   "longitude": _longitude, // Variable à définir
        //
        //   // Caractéristiques techniques
        //   "surface": double.tryParse(_areaController.text) ?? 0,
        //   "rooms": int.tryParse(_livingRoomsController.text) ?? 0 +
        //       int.tryParse(_bedroomsController.text) ?? 0 +
        //       int.tryParse(_kitchensController.text) ?? 0,
        //   "bedrooms": int.tryParse(_bedroomsController.text) ?? 0,
        //   "floor": int.tryParse(_floorController.text) ?? 0,
        //
        //   // Transaction et disponibilité
        //   "sold": false, // Par défaut à la création
        //   "transactionType": _isForRent ? "location" : "avendre",
        //   "isAvailable": true, // Par défaut à la création
        //
        //   // Relations
        //   "PropertyTypeId": _selectedPropertyTypeId, // ID du type sélectionné
        //   "UserId": currentUserId, // ID de l'utilisateur connecté
        //   "features": _selectedFeatures.map((f) => f.id).toList(), // Liste des IDs des features
        // };



        SnackBarHelper.show(context, "Annonce publiée avec succès!", isError: false);
        Navigator.pop(context);
      });
    } else {
      SnackBarHelper.show(context, "Veuillez remplir tous les champs obligatoires", isError: true);
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
      {'icon': FontAwesomeIcons.building, 'label': 'Appartement','value':'appartement'},
      {'icon': FontAwesomeIcons.house, 'label': 'Maison','value':'maison'},
      {'icon': FontAwesomeIcons.building, 'label': 'Villas','value':'villa'},
      {'icon': FontAwesomeIcons.buildingColumns, 'label': 'Bureaux','value':'office'},
      {'icon': FontAwesomeIcons.houseCrack, 'label': 'Studio','value':'studio'},
      {'icon': FontAwesomeIcons.mountain, 'label': 'Terrain','value':'terrain'},
      {'icon': FontAwesomeIcons.hotel, 'label': 'Hôtel', 'value': 'hotel'},
      {'icon': FontAwesomeIcons.warehouse, 'label': 'Entrepôt', 'value': 'warehouse'},
    ];

    return Container(
      height: 100,
      margin: EdgeInsets.only(bottom: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = _selectedCategory == category['value'];

          return GestureDetector(
            onTap: () => setState(() => _selectedCategory = category['value'] as String),
            child: Container(
              width: 80,
              margin: EdgeInsets.only(right: 12),
              child: Column(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: isSelected ? _primaryColor.withOpacity(0.2) : Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? _primaryColor : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      category['icon'] as IconData,
                      size: 24,
                      color: isSelected ? _primaryColor : Colors.grey[700],
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    category['label'] as String,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? _primaryColor : Colors.grey[800],
                    ),
                    textAlign: TextAlign.center,
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
          SizedBox(height: 16),
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
          SizedBox(height: 16),
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
          SizedBox(height: 24),
          _buildSectionHeader('Adresse'),
          SizedBox(height: 12),
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
          SizedBox(height: 20),
          _buildSectionHeader('Commune'),
          SizedBox(height: 12),
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
          SizedBox(height: 24),
          _buildSectionHeader('Caractéristiques'),
          SizedBox(height: 12),
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
                  _submitForm();
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
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: icon != null ? Icon(icon, color: _greyColor) : null,
          suffixText: suffixText,
          suffixStyle: TextStyle(color: _darkColor),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: BorderSide(color: _borderColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: BorderSide(color: _borderColor),
          ),
          filled: true,
          fillColor: _cardColor,
          contentPadding: EdgeInsets.symmetric(
            horizontal: 16,
            vertical: maxLines == 1 ? 0 : 16,
          ),
          labelStyle: TextStyle(color: _greyColor),
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