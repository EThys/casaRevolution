import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:casa/controllers/AgenceController.dart';
import 'package:casa/utils/FancyNotification.dart';
import 'package:casa/utils/networkCheck.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:get_storage/get_storage.dart';
import 'package:casa/controllers/TypeAccountController.dart';
import 'package:casa/utils/Constantes.dart';
import 'package:casa/controllers/LocationController.dart';
import 'package:casa/models/CityModel.dart';
import 'package:casa/models/CommuneModel.dart';
import 'package:casa/models/DistrictModel.dart';
import 'package:casa/models/QuartierModel.dart';
import 'package:casa/utils/city_suggestions.dart';
import 'package:casa/utils/StockageKeys.dart';
import 'package:casa/utils/api_error_message.dart';
import 'package:casa/utils/crashlytics_api.dart';
import 'package:casa/utils/SubscriptionHelper.dart';
import 'package:casa/widgets/profile_style_image_picker_sheet.dart';

class CreateAgencePage extends StatefulWidget {
  @override
  _CreateAgencePageState createState() => _CreateAgencePageState();
}

class _CreateAgencePageState extends State<CreateAgencePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _phone1Controller = TextEditingController();
  final _phone2Controller = TextEditingController();
  final _addressController = TextEditingController();
  
  File? _logoImage;
  final _picker = ImagePicker();
  bool _isLoading = false;
  
  // Location variables
  List<CityModel> _availableCities = [];
  List<DistrictModel> _availableDistricts = [];
  List<CommuneModel> _availableCommunes = [];
  List<QuartierModel> _availableQuartiers = [];
  List<QuartierModel> _kinshasaQuartiers = [];

  CityModel? _selectedCity;
  DistrictModel? _selectedDistrict;
  CommuneModel? _selectedCommune;
  QuartierModel? _selectedQuartier;
  QuartierModel? _selectedKinshasaQuartier;

  final TextEditingController _cityTextController = TextEditingController();
  final TextEditingController _quartierTextController = TextEditingController();
  
  bool _isLoadingQuartiers = false;
  Map<String, bool> _fieldTouched = {};

  final Color primaryColor = Color(0xFF1976D2);
  final Color secondaryColor = Color(0xFF64B5F6);

  @override
  void initState() {
    super.initState();
    _loadLocationData();
  }

  Future<void> _loadLocationData() async {
    try {
      final locationCtrl = Provider.of<LocationController>(context, listen: false);
      await locationCtrl.loadAllData();
      
      if (mounted) {
        setState(() async {
          _availableCities = await locationCtrl.getAllCities();
          if (_availableCities.isNotEmpty) {
            _selectedCity = _availableCities.firstWhere(
              (c) => c.name?.toLowerCase() == 'kinshasa',
              orElse: () => _availableCities.first,
            );
            
            if (_selectedCity != null) {
              _cityTextController.text = _selectedCity!.name ?? '';
              _updateDistrictsForCity();
              if (_selectedCity!.name?.toLowerCase().trim() == 'kinshasa') {
                _loadKinshasaQuartiers();
              }
            }
          }
        });
      }
    } catch (e) {
      print("Erreur chargement localisation Agence: $e");
    }
  }

  void _updateDistrictsForCity() {
    if (_selectedCity == null) return;
    final locationCtrl = Provider.of<LocationController>(context, listen: false);
    
    setState(() {
      _availableDistricts = locationCtrl.getDistrictsForCity(_selectedCity!.cityId!);
      if (_availableDistricts.isNotEmpty) {
        _selectedDistrict = _availableDistricts.first;
        _availableCommunes = locationCtrl.getCommunesForDistrict(_selectedDistrict!.districtId!);
        if (_availableCommunes.isNotEmpty) {
          _selectedCommune = _availableCommunes.first;
          _availableQuartiers = locationCtrl.getQuartiersForCommune(_selectedCommune!.communeId!);
          if (_availableQuartiers.isNotEmpty) {
            _selectedQuartier = _availableQuartiers.first;
          } else {
            _selectedQuartier = null;
          }
        } else {
          _selectedCommune = null;
          _availableQuartiers = [];
          _selectedQuartier = null;
        }
      } else {
        _selectedDistrict = null;
        _availableCommunes = [];
        _selectedCommune = null;
        _availableQuartiers = [];
        _selectedQuartier = null;
      }
    });
  }

  Future<void> _loadKinshasaQuartiers() async {
    if (_selectedCity?.name?.toLowerCase().trim() != 'kinshasa') return;
    
    setState(() => _isLoadingQuartiers = true);
    try {
      final locationCtrl = Provider.of<LocationController>(context, listen: false);
      final list = await locationCtrl.getKinshasaQuartiers();
      if (mounted) {
        setState(() {
          _kinshasaQuartiers = list;
          _isLoadingQuartiers = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingQuartiers = false);
    }
  }

  void _onCityChanged(String selection) {
    if (selection.isEmpty) return;
    
    _fieldTouched['city'] = true;
    setState(() {
      _cityTextController.text = selection;
      final query = selection.toLowerCase().trim();
      
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
        _selectedCity = null;
        _selectedDistrict = null;
        _selectedCommune = null;
        _selectedQuartier = null;
      }
    });
  }

  void _markFieldTouched(String field) {
    setState(() {
      _fieldTouched[field] = true;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _phone1Controller.dispose();
    _phone2Controller.dispose();
    _addressController.dispose();
    _cityTextController.dispose();
    _quartierTextController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (!mounted) return;
    await showProfileStyleImagePickerSheet(
      context,
      primaryColor: primaryColor,
      sheetTitle: 'Logo de l’agence',
      headerIcon: Icons.storefront_rounded,
      showPreview: _logoImage != null,
      previewTitle: 'Aperçu du logo',
      previewSubtitle: 'Voir le logo actuel.',
      onPreview: () async {
        if (_logoImage == null || !mounted) return;
        await showDialog<void>(
          context: context,
          builder: (ctx) => Dialog(
            backgroundColor: Colors.black87,
            child: InteractiveViewer(
              child: Image.file(_logoImage!, fit: BoxFit.contain),
            ),
          ),
        );
      },
      cameraTitle: 'Prendre une photo',
      cameraSubtitle: 'Utiliser la caméra.',
      onCamera: () async {
        try {
          final XFile? pickedFile = await _picker.pickImage(
            source: ImageSource.camera,
            maxWidth: 800,
            maxHeight: 800,
            imageQuality: 85,
          );
          if (pickedFile != null && mounted) {
            setState(() => _logoImage = File(pickedFile.path));
          }
        } catch (e) {
          if (mounted) {
            FancyNotification.show(
              context,
              "La photo n’a pas pu être prise. Réessayez ou choisissez la galerie.",
              isError: true,
            );
          }
        }
      },
      galleryTitle: 'Choisir depuis la galerie',
      gallerySubtitle: 'Sélectionner une image existante.',
      onGallery: () async {
        try {
          final XFile? pickedFile = await _picker.pickImage(
            source: ImageSource.gallery,
            maxWidth: 800,
            maxHeight: 800,
            imageQuality: 85,
          );
          if (pickedFile != null && mounted) {
            setState(() => _logoImage = File(pickedFile.path));
          }
        } catch (e) {
          if (mounted) {
            FancyNotification.show(
              context,
              "Nous n’avons pas pu ouvrir la galerie. Réessayez ou choisissez une autre photo.",
              isError: true,
            );
          }
        }
      },
    );
  }

  Future<String?> _imageToBase64(File image) async {
    try {
      final bytes = await image.readAsBytes();
      return base64Encode(bytes);
    } catch (e) {
      print('Error converting image to base64: $e');
      return null;
    }
  }



  Future<void> _submitForm() async {
    // 1. Dismiss keyboard and prevent double clicks
    FocusScope.of(context).unfocus();
    if (_isLoading) return;

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_logoImage == null) {
      FancyNotification.show(context, "Veuillez sélectionner un logo pour l'agence");
      return;
    }

    final subscriptionOk =
        await SubscriptionHelper.ensurePremiumForSubmit(context: context);
    if (!subscriptionOk || !mounted) return;

    setState(() {
      _isLoading = true;
    });

    if (!await NetworkUtils.checkInternetConnectivity()) {
      FancyNotification.show(
        context,
        "Connexion internet indisponible. Réessayez dès que vous êtes en ligne.",
        isError: true,
      );
      setState(() { _isLoading = false; });
      return;
    }

    final sessionToken =
        GetStorage().read<String>(StockageKeys.tokenKey)?.trim();
    if (sessionToken == null || sessionToken.isEmpty) {
      FancyNotification.show(
        context,
        "Vous devez être connecté pour créer une agence. Reconnectez-vous.",
        isError: true,
      );
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      // Convert image to base64
      final logoBase64 = await _imageToBase64(_logoImage!);
      if (logoBase64 == null) {
        throw Exception("logo_encode_failed");
      }
      
      // Retrieve userId from Storage
      final storage = GetStorage();
      final userData = storage.read(StockageKeys.userKey);
      int userId = 0;
      if (userData != null) {
          // Essayer différentes clés possibles pour l'ID utilisateur
          userId = userData['user']?['userId'] ?? userData['userId'] ?? userData['id'] ?? 0;
      }

      final payload = {
        "userId": userId, 
        "name": _nameController.text.trim(),
        "description": _descriptionController.text.trim(),
        "phone1": _phone1Controller.text.trim(),
        "phone2": _phone2Controller.text.trim(),
        "address": _addressController.text.trim(),
        "logo": logoBase64,
        "cityId": _selectedCity?.cityId ?? 0,
        "communeId": _selectedCommune?.communeId ?? 0,
        "districtId": _selectedDistrict?.districtId ?? 0,
        "quartierId": _selectedQuartier?.quartierId ?? _selectedKinshasaQuartier?.quartierId ?? 0,
        "cityValue": _cityTextController.text,
        "communeValue": _selectedCommune?.name ?? "",
        "quartierValue": _selectedQuartier?.name ?? _quartierTextController.text,
      };

      final agenceCtrl = Provider.of<AgenceController>(context, listen: false);
      final response = await agenceCtrl.createAgence(payload);

      if (response.status == true) {
        String message = "Agence créée avec succès. Vous pouvez maintenant publier votre annonce.";
        if (response.data != null && response.data is Map && response.data.containsKey('message')) {
            message = response.data['message'];
        }
        FancyNotification.show(context, message, isError: false);
        // Retour avec un résultat pour informer la page précédente
        Navigator.pop(context, true);
      } else {
        reportApiFailureToCrashlytics(
          'CreateAgencePage',
          response: response,
          reason: 'create_agence',
        );
        String msg = ApiErrorMessages.fromResponse(response);
        if (response.data is Map) {
          final errs = response.data['errors'];
          if (errs is Map && errs.isNotEmpty) {
            final firstVal = errs.values.first;
            if (firstVal is List && firstVal.isNotEmpty) {
              msg = firstVal.first.toString();
            } else if (firstVal != null) {
              msg = firstVal.toString();
            }
          }
        }
        FancyNotification.show(context, msg, isError: true);
      }
    } catch (e, st) {
      reportApiFailureToCrashlytics(
        'CreateAgencePage',
        error: e,
        stackTrace: st,
        reason: 'create_agence_exception',
      );
      print("Erreur création agence: $e");
      String friendlyError =
          "Nous n’avons pas pu enregistrer l’agence. Vérifiez la connexion et réessayez.";
      if (e.toString().contains("logo_encode_failed")) {
        friendlyError =
            "Le logo n’a pas pu être préparé. Essayez une autre image ou une photo plus légère.";
      } else if (e.toString().contains("Internal Server Error")) {
        friendlyError =
            "Le service est momentanément saturé. Patientez un peu et réessayez.";
      }
      FancyNotification.show(context, friendlyError, isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Créer une agence",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: primaryColor,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // --- START PREMIUM BACKGROUND ---
          Positioned.fill(
            child: Container(
              color: const Color(0xFFF8F9FF), // Ultra-clean premium base
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
                    primaryColor.withOpacity(0.08),
                    primaryColor.withOpacity(0.0),
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
                    secondaryColor.withOpacity(0.06),
                    secondaryColor.withOpacity(0.0),
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
            child: SingleChildScrollView(
              physics: BouncingScrollPhysics(),
              padding: EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Friendly Text
                    Container(
                      padding: EdgeInsets.all(16),
                      margin: EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: primaryColor.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline_rounded, color: primaryColor, size: 28),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              "Pour publier des sites touristiques ou des lieux de vacances, vous devez d'abord avoir une agence enregistrée.",
                              style: TextStyle(
                                  color: Colors.black87, 
                                  fontSize: 14,
                                  height: 1.4
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    _buildLogoUpload(),
                    SizedBox(height: 24),
                    _buildTextField(
                      controller: _nameController,
                      label: "Nom de l'agence",
                      icon: Icons.business,
                      validator: (value) {
                        final v = value?.trim() ?? '';
                        if (v.isEmpty) return "Le nom est obligatoire";
                        if (v.length < 2) {
                          return "Le nom doit contenir au moins 2 caractères";
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),
                    _buildTextField(
                      controller: _descriptionController,
                      label: "Description",
                      icon: Icons.description,
                      maxLines: 3,
                      validator: (value) {
                        final v = value?.trim() ?? '';
                        if (v.isEmpty) return "La description est obligatoire";
                        if (v.length < 15) {
                          return "Décrivez votre agence (au moins 15 caractères)";
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),
                    _buildTextField(
                      controller: _phone1Controller,
                      label: "Téléphone 1",
                      icon: Icons.phone,
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        final v = value?.trim() ?? '';
                        if (v.isEmpty) return "Le téléphone est obligatoire";
                        final digits = v.replaceAll(RegExp(r'\D'), '');
                        if (digits.length < 9) {
                          return "Numéro incomplet (au moins 9 chiffres)";
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),
                    _buildTextField(
                      controller: _phone2Controller,
                      label: "Téléphone 2 (Optionnel)",
                      icon: Icons.phone_android,
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        final v = value?.trim() ?? '';
                        if (v.isEmpty) return null;
                        final digits = v.replaceAll(RegExp(r'\D'), '');
                        if (digits.length < 9) {
                          return "Numéro incomplet (au moins 9 chiffres)";
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),
                    _buildCitySuggestionField(),
                    SizedBox(height: 16),
                    if (_selectedCity?.name?.toLowerCase().trim() == 'kinshasa') ...[
                       _buildLocationDropdowns(),
                       SizedBox(height: 16),
                       _buildKinshasaQuartierDropdown(),
                       SizedBox(height: 16),
                    ],
                    _buildTextField(
                      controller: _addressController,
                      label: "Adresse complète",
                      icon: Icons.location_on,
                      validator: (value) =>
                          value!.isEmpty ? "L'adresse est obligatoire" : null,
                    ),
                    SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submitForm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 5,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                "Enregistrer l'agence",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoUpload() {
    return Center(
      child: GestureDetector(
        onTap: _pickImage,
        child: Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: Colors.grey[100],
            shape: BoxShape.circle,
            border: Border.all(color: primaryColor, width: 2),
            image: _logoImage != null
                ? DecorationImage(
                    image: FileImage(_logoImage!),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: _logoImage == null
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.camera_alt, size: 40, color: Colors.grey[400]),
                    SizedBox(height: 4),
                    Text(
                      "Logo",
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildCitySuggestionField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Autocomplete<String>(
          initialValue: TextEditingValue(text: _cityTextController.text),
          optionsBuilder: (TextEditingValue textEditingValue) {
            if (textEditingValue.text.isEmpty) return const Iterable<String>.empty();
            return CitySuggestions.cities.where((String option) {
              return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
            });
          },
          onSelected: (String selection) {
            _onCityChanged(selection);
          },
          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
            if (controller.text.isEmpty && _cityTextController.text.isNotEmpty) {
               controller.text = _cityTextController.text;
            }
            return TextField(
              controller: controller,
              focusNode: focusNode,
              onTapOutside: (event) => focusNode.unfocus(),
              onChanged: (value) => _onCityChanged(value),
              style: TextStyle(color: Colors.black87),
              decoration: InputDecoration(
                labelText: "Ville*",
                prefixIcon: Icon(Icons.location_city_rounded, color: primaryColor),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                filled: true,
                fillColor: Colors.grey[50],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildLocationDropdowns() {
    return Column(
      children: [
        _buildPremiumDropdown<DistrictModel>(
          label: "District*",
          value: _selectedDistrict,
          items: _availableDistricts,
          displayText: (d) => d.name ?? "",
          onChanged: (val) {
             setState(() {
                _selectedDistrict = val;
                if (val != null) {
                  final locationCtrl = Provider.of<LocationController>(context, listen: false);
                  _availableCommunes = locationCtrl.getCommunesForDistrict(val.districtId!);
                  _selectedCommune = _availableCommunes.isNotEmpty ? _availableCommunes.first : null;
                }
             });
          },
        ),
        SizedBox(height: 16),
        _buildPremiumDropdown<CommuneModel>(
          label: "Commune*",
          value: _selectedCommune,
          items: _availableCommunes,
          displayText: (c) => c.name ?? "",
          onChanged: (val) {
             setState(() => _selectedCommune = val);
          },
        ),
      ],
    );
  }

  Widget _buildKinshasaQuartierDropdown() {
    return Autocomplete<QuartierModel>(
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text.isEmpty) return const Iterable<QuartierModel>.empty();
        return _kinshasaQuartiers.where((option) {
          return (option.name ?? '').toString().toLowerCase().contains(textEditingValue.text.toLowerCase());
        });
      },
      displayStringForOption: (option) => option.name ?? '',
      onSelected: (selection) {
        setState(() {
          _selectedKinshasaQuartier = selection;
          _quartierTextController.text = selection.name ?? '';
        });
      },
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          onTapOutside: (event) => focusNode.unfocus(),
          onChanged: (value) => _quartierTextController.text = value,
          decoration: InputDecoration(
            labelText: "Quartier*",
            prefixIcon: Icon(Icons.place_rounded, color: primaryColor),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            filled: true,
            fillColor: Colors.grey[50],
            hintText: _isLoadingQuartiers ? "Chargement..." : "Rechercher...",
          ),
        );
      },
    );
  }

  Widget _buildPremiumDropdown<T>({
    required String label,
    required T? value,
    required List<T> items,
    required String Function(T) displayText,
    required void Function(T?) onChanged,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(Icons.map_rounded, color: primaryColor),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: Colors.grey[50],
      ),
      items: items.map((T item) {
        return DropdownMenuItem<T>(
          value: item,
          child: Text(displayText(item)),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: primaryColor),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: primaryColor),
        ),
        filled: true,
        fillColor: Colors.grey[50],
      ),
      onTapOutside: (event) {
        FocusScope.of(context).unfocus();
      },
    );
  }

}
