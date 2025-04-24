import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class CreatePropertyPostPage extends StatefulWidget {
  @override
  _CreatePropertyPostPageState createState() => _CreatePropertyPostPageState();
}

class _CreatePropertyPostPageState extends State<CreatePropertyPostPage> {
  // Couleurs du thème
  final Color _primaryColor = Color(0xFF1976D2);
  final Color darkBlue = Color(0xFF0D47A1);
  final Color _darkColor = Color(0xFF1A1D26);
  final Color _lightColor = Color(0xFFF8F9FA);
  final Color _greyColor = Color(0xFF6C757D);
  final Color _successColor = Color(0xFF00C897);

  // Contrôleurs de formulaire
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

  // Variables d'état
  bool _isForRent = true;
  bool _isLoading = false;
  List<XFile> _selectedImages = [];
  Set<String> _selectedAmenities = {};
  LatLng? _selectedLocation;
  final ImagePicker _picker = ImagePicker();
  int _currentStep = 0;

  // Liste des équipements disponibles
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
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      // Simuler un envoi de données
      Future.delayed(Duration(seconds: 2), () {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Annonce publiée avec succès!'),
            backgroundColor: _successColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        Navigator.pop(context);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _lightColor,
      appBar: AppBar(
        title: Text(
          'Nouvelle annonce',
          style: TextStyle(
            color: _darkColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: _darkColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Stepper horizontal en haut
            Container(
              padding: EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  )
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStepIndicator(0, 'Type'),
                  _buildStepIndicator(1, 'Détails'),
                  _buildStepIndicator(2, 'Équipements'),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: IndexedStack(
                  index: _currentStep,
                  children: [
                    // Étape 1 - Type d'annonce et photos
                    _buildStep1(),

                    // Étape 2 - Détails de la propriété
                    _buildStep2(),

                    // Étape 3 - Équipements
                    _buildStep3(),
                  ],
                ),
              ),
            ),

            // Boutons de navigation
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
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
                          side: BorderSide(color: _greyColor),
                          padding: EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text('Précédent'),
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
                        padding: EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                          : Text(
                        _currentStep == 2 ? 'Publier' : 'Continuer',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepIndicator(int stepIndex, String label) {
    final isActive = _currentStep == stepIndex;
    final isCompleted = _currentStep > stepIndex;

    return GestureDetector(
      onTap: () => setState(() => _currentStep = stepIndex),
      child: Column(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive || isCompleted ? _primaryColor : Colors.grey[200],
              border: Border.all(
                color: isActive ? _primaryColor : Colors.transparent,
                width: 2,
              ),
            ),
            child: Center(
              child: isCompleted
                  ? Icon(Icons.check, size: 18, color: Colors.white)
                  : Text(
                '${stepIndex + 1}',
                style: TextStyle(
                  color: isActive ? Colors.white : _greyColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isActive ? _primaryColor : _greyColor,
              fontSize: 12,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep1() {
    return Column(
      children: [
        // Sélection type d'annonce
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: Offset(0, 4),
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Type d\'annonce',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _darkColor,
                ),
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: Text('À louer'),
                      selected: _isForRent,
                      onSelected: (selected) {
                        setState(() {
                          _isForRent = selected;
                        });
                      },
                      selectedColor: _primaryColor,
                      labelStyle: TextStyle(
                        color: _isForRent ? Colors.white : _darkColor,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: ChoiceChip(
                      label: Text('À vendre'),
                      selected: !_isForRent,
                      onSelected: (selected) {
                        setState(() {
                          _isForRent = !selected;
                        });
                      },
                      selectedColor: _primaryColor,
                      labelStyle: TextStyle(
                        color: !_isForRent ? Colors.white : _darkColor,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: 16),
        // Upload de photos
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: Offset(0, 4),
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Photos de la propriété',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _darkColor,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Ajoutez au moins 3 photos de bonne qualité',
                style: TextStyle(
                  color: _greyColor,
                  fontSize: 13,
                ),
              ),
              SizedBox(height: 16),
              if (_selectedImages.isEmpty)
                GestureDetector(
                  onTap: _pickImages,
                  child: Container(
                    height: 180,
                    decoration: BoxDecoration(
                      color: _lightColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _primaryColor.withOpacity(0.3),
                        width: 1.5,
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.cloud_upload_outlined,
                          size: 40,
                          color: _primaryColor,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Ajouter des photos',
                          style: TextStyle(
                            color: _primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Column(
                  children: [
                    SizedBox(
                      height: 180,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _selectedImages.length + 1,
                        itemBuilder: (context, index) {
                          if (index == _selectedImages.length) {
                            return GestureDetector(
                              onTap: _pickImages,
                              child: Container(
                                width: 140,
                                margin: EdgeInsets.only(right: 12),
                                decoration: BoxDecoration(
                                  color: _lightColor,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: _primaryColor.withOpacity(0.3),
                                    width: 1.5,
                                  ),
                                ),
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.add_rounded,
                                        size: 30,
                                        color: _primaryColor,
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        'Ajouter',
                                        style: TextStyle(
                                          color: _primaryColor,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }
                          return Container(
                            width: 140,
                            margin: EdgeInsets.only(
                                right:
                                index < _selectedImages.length - 1 ? 12 : 0),
                            child: Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(
                                    File(_selectedImages[index].path),
                                    width: 140,
                                    height: 180,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Positioned(
                                  top: 8,
                                  right: 8,
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
                                        size: 18,
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
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStep2() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          // Titre
          _buildFormField(
            controller: _titleController,
            label: 'Titre de l\'annonce',
            hint: 'Ex: Magnifique appartement avec vue sur la tour Eiffel',
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Veuillez entrer un titre';
              }
              return null;
            },
            icon: Icons.title_rounded,
          ),
          SizedBox(height: 16),
          // Prix
          _buildFormField(
            controller: _priceController,
            label: _isForRent ? 'Prix mensuel (\$)' : 'Prix de vente (\$)',
            hint: _isForRent ? '1200' : '450000',
            keyboardType: TextInputType.number,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Veuillez entrer un prix';
              }
              if (double.tryParse(value) == null) {
                return 'Veuillez entrer un nombre valide';
              }
              return null;
            },
            icon: Icons.attach_money,
          ),
          SizedBox(height: 16),
          // Description
          _buildFormField(
            controller: _descriptionController,
            label: 'Description',
            hint: 'Décrivez en détail la propriété...',
            maxLines: 5,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Veuillez entrer une description';
              }
              if (value.length < 50) {
                return 'La description doit faire au moins 50 caractères';
              }
              return null;
            },
            icon: Icons.description_rounded,
          ),
          SizedBox(height: 16),
          // Adresse
          _buildFormField(
            controller: _addressController,
            label: 'Adresse complète',
            hint: 'Ex: 15 Rue de Rivoli, 75004 Paris, France',
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Veuillez entrer une adresse';
              }
              return null;
            },
            icon: Icons.location_on_rounded,
          ),
          SizedBox(height: 16),
          // Caractéristiques
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: Offset(0, 4),
                )
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildNumberField(
                        controller: _bedroomsController,
                        label: 'Chambres',
                        icon: FontAwesomeIcons.bed,
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: _buildNumberField(
                        controller: _bathroomsController,
                        label: 'Salles de bain',
                        icon: FontAwesomeIcons.bath,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildNumberField(
                        controller: _livingRoomsController,
                        label: 'Salons',
                        icon: FontAwesomeIcons.couch,
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: _buildNumberField(
                        controller: _kitchensController,
                        label: 'Cuisines',
                        icon: FontAwesomeIcons.kitchenSet,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildNumberField(
                        controller: _areaController,
                        label: 'Surface (m²)',
                        icon: FontAwesomeIcons.rulerCombined,
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: _buildNumberField(
                        controller: _floorController,
                        label: 'Étage',
                        icon: FontAwesomeIcons.building,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildStep3() {
    return Column(
      children: [
        // Équipements
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: Offset(0, 4),
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Équipements',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _darkColor,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Sélectionnez les équipements disponibles',
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
                    selectedColor: _primaryColor.withOpacity(0.1),
                    checkmarkColor: _primaryColor,
                    labelStyle: TextStyle(
                      color: isSelected ? _primaryColor : _darkColor,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: isSelected
                            ? _primaryColor
                            : Colors.grey.shade300,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        SizedBox(height: 24),
        // Localisation
        // Container(
        //   padding: EdgeInsets.all(16),
        //   decoration: BoxDecoration(
        //     color: Colors.white,
        //     borderRadius: BorderRadius.circular(12),
        //     boxShadow: [
        //       BoxShadow(
        //         color: Colors.black.withOpacity(0.05),
        //         blurRadius: 8,
        //         offset: Offset(0, 4),
        //       )
        //     ],
        //   ),
        //   child: Column(
        //     crossAxisAlignment: CrossAxisAlignment.start,
        //     children: [
        //       Text(
        //         'Localisation sur la carte',
        //         style: TextStyle(
        //           fontSize: 16,
        //           fontWeight: FontWeight.w600,
        //           color: _darkColor,
        //         ),
        //       ),
        //       SizedBox(height: 8),
        //       Text(
        //         'Positionnez le marqueur sur la carte',
        //         style: TextStyle(
        //           color: _greyColor,
        //           fontSize: 13,
        //         ),
        //       ),
        //       SizedBox(height: 16),
        //       Container(
        //         height: 200,
        //         decoration: BoxDecoration(
        //           borderRadius: BorderRadius.circular(12),
        //           color: _lightColor,
        //           border: Border.all(
        //             color: _primaryColor.withOpacity(0.3),
        //             width: 1.5,
        //           ),
        //         ),
        //         child: ClipRRect(
        //           borderRadius: BorderRadius.circular(12),
        //           child: Stack(
        //             children: [
        //               GoogleMap(
        //                 initialCameraPosition: CameraPosition(
        //                   target: _selectedLocation ?? LatLng(48.8566, 2.3522),
        //                   // Paris par défaut
        //                   zoom: 12,
        //                 ),
        //                 onTap: (latLng) {
        //                   setState(() {
        //                     _selectedLocation = latLng;
        //                   });
        //                 },
        //                 markers: _selectedLocation != null
        //                     ? {
        //                   Marker(
        //                     markerId: MarkerId('property'),
        //                     position: _selectedLocation!,
        //                     icon: BitmapDescriptor.defaultMarkerWithHue(
        //                         BitmapDescriptor.hueRed),
        //                   ),
        //                 }
        //                     : {},
        //                 mapType: MapType.normal,
        //                 myLocationEnabled: true,
        //                 zoomControlsEnabled: false,
        //               ),
        //               if (_selectedLocation == null)
        //                 Center(
        //                   child: Container(
        //                     padding: EdgeInsets.all(16),
        //                     decoration: BoxDecoration(
        //                       color: Colors.white,
        //                       borderRadius: BorderRadius.circular(8),
        //                     ),
        //                     child: Text(
        //                       'Cliquez sur la carte pour positionner',
        //                       style: TextStyle(
        //                         color: _darkColor,
        //                         fontWeight: FontWeight.w600,
        //                       ),
        //                     ),
        //                   ),
        //                 ),
        //             ],
        //           ),
        //         ),
        //       ),
        //       SizedBox(height: 12),
        //       if (_selectedLocation != null)
        //         Text(
        //           'Position sélectionnée',
        //           style: TextStyle(
        //             color: _greyColor,
        //             fontSize: 12,
        //           ),
        //         ),
        //     ],
        //   ),
        // ),
      ],
    );
  }

  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    String? hint,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    IconData? icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: TextFormField(
          controller: controller,
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            border: InputBorder.none,
            prefixIcon: icon != null ? Icon(icon, color: _primaryColor) : null,
          ),
          maxLines: maxLines,
          keyboardType: keyboardType,
          validator: validator,
        ),
      ),
    );
  }

  Widget _buildNumberField({
    required TextEditingController controller,
    required String label,
    IconData? icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: TextFormField(
          controller: controller,
          decoration: InputDecoration(
            labelText: label,
            border: InputBorder.none,
            prefixIcon: icon != null ? Icon(icon, color: _primaryColor) : null,
          ),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
      ),
    );
  }
}
