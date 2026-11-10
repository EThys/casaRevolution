import 'dart:convert';
import 'dart:io';

import 'package:casa/controllers/AgenceController.dart';
import 'package:casa/utils/FancyNotification.dart';
import 'package:casa/utils/networkCheck.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:get_storage/get_storage.dart';
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
import 'package:casa/widgets/casa_choice_sheet.dart';

class CreateAgencePage extends StatefulWidget {
  @override
  _CreateAgencePageState createState() => _CreateAgencePageState();
}

class _CreateAgencePageState extends State<CreateAgencePage> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _phone1Controller = TextEditingController();
  final _phone2Controller = TextEditingController();
  final _addressController = TextEditingController();
  
  File? _logoImage;
  final _picker = ImagePicker();
  bool _isLoading = false;

  Future<File> _persistPickedImage(File source, {required String prefix}) async {
    final supportDir = await getApplicationSupportDirectory();
    final imgDir = Directory('${supportDir.path}/persisted_images');
    if (!await imgDir.exists()) {
      await imgDir.create(recursive: true);
    }
    final name = source.path.replaceAll('\\', '/').split('/').last;
    final dot = name.lastIndexOf('.');
    final ext = (dot >= 0 && dot < name.length - 1) ? name.substring(dot) : '.jpg';
    final dst = File('${imgDir.path}/${prefix}_${DateTime.now().millisecondsSinceEpoch}$ext');
    try {
      return await source.copy(dst.path);
    } catch (_) {
      return source;
    }
  }
  
  // Location variables
  List<CityModel> _availableCities = [];
  List<DistrictModel> _availableDistricts = [];
  List<CommuneModel> _availableCommunes = [];
  List<QuartierModel> _kinshasaQuartiers = [];

  CityModel? _selectedCity;
  DistrictModel? _selectedDistrict;
  CommuneModel? _selectedCommune;
  QuartierModel? _selectedQuartier;
  QuartierModel? _selectedKinshasaQuartier;

  final TextEditingController _cityTextController = TextEditingController();
  final TextEditingController _communeTextController = TextEditingController();
  final TextEditingController _quartierTextController = TextEditingController();
  final FocusNode _quartierFocus = FocusNode();
  final FocusNode _cityFocus = FocusNode();

  bool _isLoadingQuartiers = false;
  Map<String, bool> _fieldTouched = {};
  final Map<String, String> _errors = {};
  int _currentStep = 0;
  bool _hasAttemptedSubmit = false;

  static const List<String> _stepLabels = ['Agence', 'Lieu'];
  static const List<String> _matadiCommunes = ['Matadi', 'Nzanza', 'Mvuzi'];

  bool get _isKinshasaSelected =>
      (_selectedCity?.name ?? _cityTextController.text).toLowerCase().trim() == 'kinshasa';

  bool get _isMatadiSelected =>
      (_selectedCity?.name ?? _cityTextController.text).toLowerCase().trim() == 'matadi';

  final Color primaryColor = Color(0xFF1976D2);

  @override
  void initState() {
    super.initState();
    _loadLocationData();
  }

  Future<void> _loadLocationData() async {
    try {
      final locationCtrl = Provider.of<LocationController>(context, listen: false);
      await locationCtrl.loadAllData();
      final cities = await locationCtrl.getAllCities();
      if (!mounted) return;
      CityModel? kinshasa;
      for (final city in cities) {
        if ((city.name ?? '').toLowerCase().trim() == 'kinshasa') {
          kinshasa = city;
          break;
        }
      }
      setState(() {
        _availableCities = cities;
        _selectedCity = kinshasa ?? (cities.isNotEmpty ? cities.first : null);
        _cityTextController.text = _selectedCity?.name ?? '';
        _refreshDistricts();
      });
      if (_isKinshasaSelected) {
        await _loadKinshasaQuartiers();
      }
    } catch (e) {
      print("Erreur chargement localisation Agence: $e");
    }
  }

  void _refreshDistricts() {
    if (_selectedCity?.cityId == null) {
      _availableDistricts = [];
      _availableCommunes = [];
      _selectedDistrict = null;
      _selectedCommune = null;
      return;
    }
    final locationCtrl = Provider.of<LocationController>(context, listen: false);
    _availableDistricts = locationCtrl.getDistrictsForCity(_selectedCity!.cityId!);
    if (_selectedDistrict != null &&
        !_availableDistricts.any((d) => d.districtId == _selectedDistrict!.districtId)) {
      _selectedDistrict = null;
      _selectedCommune = null;
      _availableCommunes = [];
    } else if (_selectedDistrict?.districtId != null) {
      _availableCommunes = locationCtrl.getCommunesForDistrict(_selectedDistrict!.districtId!);
    }
  }

  void _onDistrictChanged(DistrictModel? district) {
    final locationCtrl = Provider.of<LocationController>(context, listen: false);
    setState(() {
      _markTouched('district');
      _selectedDistrict = district;
      _selectedCommune = null;
      _availableCommunes = district?.districtId == null
          ? []
          : locationCtrl.getCommunesForDistrict(district!.districtId!);
      _errors.remove('district');
      _errors.remove('commune');
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
    _markTouched('city');
    final query = selection.trim().toLowerCase();
    CityModel? match;
    for (final city in _availableCities) {
      if ((city.name ?? '').trim().toLowerCase() == query) {
        match = city;
        break;
      }
    }
    final sameCity = match?.cityId == _selectedCity?.cityId;
    setState(() {
      if (_cityTextController.text != selection) {
        _cityTextController.text = selection;
      }
      _selectedCity = match;
      if (!sameCity) {
        _selectedDistrict = null;
        _selectedCommune = null;
        _selectedQuartier = null;
        _selectedKinshasaQuartier = null;
        _availableCommunes = [];
        if (query != 'kinshasa') {
          _quartierTextController.clear();
          _communeTextController.clear();
          _availableDistricts = [];
        }
      }
      if (query == 'kinshasa') {
        _refreshDistricts();
      }
      _errors.remove('city');
    });
    if (query == 'kinshasa' && !sameCity) {
      _loadKinshasaQuartiers();
    }
  }

  void _markTouched(String field) {
    _fieldTouched[field] = true;
  }

  bool _showError(String field) =>
      _hasAttemptedSubmit || _fieldTouched[field] == true;

  String? _errorOf(String field) {
    if (!_showError(field)) return null;
    final value = _errors[field];
    if (value == null || value.isEmpty) return null;
    return value;
  }

  void _putError(String field, String? message) {
    if (message == null || message.isEmpty) {
      _errors.remove(field);
    } else {
      _errors[field] = message;
    }
  }

  bool _validateInfos() {
    _putError('name', () {
      final v = _nameController.text.trim();
      if (v.isEmpty) return "Le nom est obligatoire";
      if (v.length < 2) return "Le nom doit contenir au moins 2 caractères";
      return null;
    }());
    _putError('description', () {
      final v = _descriptionController.text.trim();
      if (v.isEmpty) return "La description est obligatoire";
      if (v.length < 15) return "Décrivez votre agence (au moins 15 caractères)";
      return null;
    }());
    _putError('phone1', () {
      final v = _phone1Controller.text.trim();
      if (v.isEmpty) return "Le téléphone est obligatoire";
      if (v.replaceAll(RegExp(r'\D'), '').length < 9) {
        return "Numéro incomplet (au moins 9 chiffres)";
      }
      return null;
    }());
    _putError('phone2', () {
      final v = _phone2Controller.text.trim();
      if (v.isEmpty) return null;
      if (v.replaceAll(RegExp(r'\D'), '').length < 9) {
        return "Numéro incomplet (au moins 9 chiffres)";
      }
      return null;
    }());
    _putError('logo', _logoImage == null ? "Ajoutez le logo de l'agence" : null);
    return !_errors.keys.any((k) => const {'name', 'description', 'phone1', 'phone2', 'logo'}.contains(k));
  }

  bool _validateLocation() {
    _putError('city', _cityTextController.text.trim().isEmpty ? 'La ville est obligatoire' : null);
    if (_isKinshasaSelected) {
      _putError('district', _selectedDistrict == null ? 'Le district est obligatoire' : null);
      _putError('commune', _selectedCommune == null ? 'La commune est obligatoire' : null);
      _putError(
        'quartier',
        _quartierTextController.text.trim().isEmpty ? 'Le quartier est obligatoire' : null,
      );
    } else if (_isMatadiSelected) {
      _putError('commune', _communeTextController.text.trim().isEmpty ? 'La commune est obligatoire' : null);
      _putError(
        'quartier',
        _quartierTextController.text.trim().isEmpty ? 'Le quartier est obligatoire' : null,
      );
    } else {
      _putError('commune', _communeTextController.text.trim().isEmpty ? 'La commune est obligatoire' : null);
      _putError(
        'quartier',
        _quartierTextController.text.trim().isEmpty ? 'Le quartier est obligatoire' : null,
      );
    }
    final address = _addressController.text.trim();
    _putError('address', address.length < 5 ? "L'adresse est obligatoire (au moins 5 caractères)" : null);
    return !_errors.keys.any(
      (k) => const {'city', 'district', 'commune', 'quartier', 'address'}.contains(k),
    );
  }

  void _goNext() {
    FocusScope.of(context).unfocus();
    final ok = _validateInfos();
    setState(() => _hasAttemptedSubmit = !ok);
    if (!ok) {
      final logo = _errorOf('logo');
      if (logo != null) {
        FancyNotification.show(context, logo);
      }
      return;
    }
    setState(() {
      _hasAttemptedSubmit = false;
      _currentStep = 1;
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
    _communeTextController.dispose();
    _quartierTextController.dispose();
    _quartierFocus.dispose();
    _cityFocus.dispose();
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
            final persisted = await _persistPickedImage(File(pickedFile.path), prefix: 'agency_logo');
            if (!mounted) return;
            setState(() {
              _logoImage = persisted;
              _errors.remove('logo');
            });
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
            final persisted = await _persistPickedImage(File(pickedFile.path), prefix: 'agency_logo');
            if (!mounted) return;
            setState(() {
              _logoImage = persisted;
              _errors.remove('logo');
            });
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
      if (!await image.exists()) {
        return null;
      }
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

    final infosOk = _validateInfos();
    final placeOk = _validateLocation();
    if (!infosOk || !placeOk) {
      setState(() {
        _hasAttemptedSubmit = true;
        if (!infosOk) _currentStep = 0;
      });
      final logo = _errorOf('logo');
      if (logo != null) FancyNotification.show(context, logo);
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
        FancyNotification.show(
          context,
          "Le logo n'est plus disponible. Reprenez la photo puis réessayez.",
          isError: true,
        );
        setState(() => _isLoading = false);
        return;
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
        "quartierId": _selectedKinshasaQuartier?.quartierId ?? _selectedQuartier?.quartierId ?? 0,
        "cityValue": _cityTextController.text.trim(),
        "communeValue": _isKinshasaSelected
            ? (_selectedCommune?.name ?? '')
            : _communeTextController.text.trim(),
        "quartierValue": _quartierTextController.text.trim(),
      };

      final agenceCtrl = Provider.of<AgenceController>(context, listen: false);
      final response = await agenceCtrl.createAgence(payload);

      if (response.status == true) {
        String message = "Agence créée avec succès. Vous pouvez maintenant publier votre annonce.";
        if (response.data != null && response.data is Map && response.data.containsKey('message')) {
            message = response.data['message'];
        }
        FancyNotification.show(
          context,
          message,
          isError: false,
          type: NotificationType.success,
        );
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
      backgroundColor: const Color(0xFFF8F9FF),
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1D26),
        title: const Text(
          'Créer une agence',
          style: TextStyle(
            color: Color(0xFF1A1D26),
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '${_currentStep + 1}/${_stepLabels.length}',
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildProgress(),
          Expanded(
            child: _currentStep == 0 ? _buildInfosStep() : _buildLocationStep(),
          ),
        ],
      ),
      bottomNavigationBar: Builder(
        builder: (context) {
          final keyboard = MediaQuery.viewInsetsOf(context).bottom;
          final systemBar = keyboard > 0 ? 0.0 : MediaQuery.viewPaddingOf(context).bottom;
          return Material(
            color: Colors.white,
            elevation: 12,
            shadowColor: Colors.black26,
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 10, 16, 12 + systemBar),
              child: _buildActions(),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProgress() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _stepLabels[_currentStep],
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
              color: Color(0xFF111111),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: List.generate(_stepLabels.length, (i) {
              final on = i <= _currentStep;
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    if (i < _currentStep) {
                      setState(() {
                        _currentStep = i;
                        _hasAttemptedSubmit = false;
                      });
                    } else if (i > _currentStep) {
                      _goNext();
                    }
                  },
                  child: Container(
                    height: 4,
                    margin: EdgeInsets.only(right: i == _stepLabels.length - 1 ? 0 : 6),
                    decoration: BoxDecoration(
                      color: on ? const Color(0xFF111111) : const Color(0xFFE6E8EC),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    final last = _currentStep >= _stepLabels.length - 1;
    return Row(
      children: [
        if (_currentStep > 0)
          Expanded(
            child: SizedBox(
              height: 52,
              child: OutlinedButton(
                onPressed: _isLoading
                    ? null
                    : () => setState(() {
                          _currentStep = 0;
                          _hasAttemptedSubmit = false;
                        }),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF64748B),
                  side: const BorderSide(color: Color(0xFFE6E8EC)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Précédent', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        if (_currentStep > 0) const SizedBox(width: 12),
        Expanded(
          flex: _currentStep > 0 ? 2 : 1,
          child: SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _isLoading ? null : (last ? _submitForm : _goNext),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _isLoading && last
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      last ? "Enregistrer l'agence" : 'Suivant',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfosStep() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      physics: const BouncingScrollPhysics(),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: primaryColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: primaryColor.withOpacity(0.25)),
          ),
          child: const Text(
            "Pour publier des sites touristiques ou des lieux de vacances, enregistrez d'abord votre agence.",
            style: TextStyle(color: Color(0xFF1A1D26), fontSize: 14, height: 1.4),
          ),
        ),
        _buildLogoUpload(),
        if (_errorOf('logo') != null) ...[
          const SizedBox(height: 8),
          _errorLine(_errorOf('logo')!),
        ],
        const SizedBox(height: 20),
        _buildTextField(
          controller: _nameController,
          label: "Nom de l'agence",
          fieldKey: 'name',
          icon: Icons.business_rounded,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _descriptionController,
          label: 'Description',
          fieldKey: 'description',
          icon: Icons.description_rounded,
          maxLines: 4,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _phone1Controller,
          label: 'Téléphone',
          fieldKey: 'phone1',
          icon: Icons.phone_rounded,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _phone2Controller,
          label: 'Téléphone 2',
          fieldKey: 'phone2',
          icon: Icons.phone_android_rounded,
          keyboardType: TextInputType.phone,
          required: false,
        ),
      ],
    );
  }

  Widget _buildLocationStep() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      physics: const BouncingScrollPhysics(),
      children: [
        const Text(
          'Localisation',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF111111)),
        ),
        const SizedBox(height: 6),
        const Text(
          'Indiquez la ville, puis le district, la commune et le quartier.',
          style: TextStyle(fontSize: 13, height: 1.35, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 16),
        _buildCitySuggestionField(),
        const SizedBox(height: 16),
        if (_isKinshasaSelected) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildChoiceField<DistrictModel>(
                  label: 'District',
                  fieldKey: 'district',
                  value: _selectedDistrict,
                  items: _availableDistricts,
                  displayText: (d) => d.name ?? '',
                  hintText: 'District',
                  icon: Icons.account_balance_rounded,
                  onChanged: _onDistrictChanged,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildChoiceField<CommuneModel>(
                  label: 'Commune',
                  fieldKey: 'commune',
                  value: _selectedCommune,
                  items: _availableCommunes,
                  displayText: (c) {
                    final name = c.name ?? '';
                    if (name.toLowerCase() == 'bandalungwa') return 'Bandal';
                    return name;
                  },
                  hintText: 'Commune',
                  icon: Icons.place_rounded,
                  onChanged: (commune) {
                    setState(() {
                      _markTouched('commune');
                      _selectedCommune = commune;
                      _errors.remove('commune');
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildQuartierSuggestionField(),
          const SizedBox(height: 16),
        ] else if (_isMatadiSelected) ...[
          _buildChoiceField<String>(
            label: 'Commune',
            fieldKey: 'commune',
            value: _communeTextController.text.trim().isEmpty ? null : _communeTextController.text.trim(),
            items: _matadiCommunes,
            displayText: (c) => c,
            hintText: 'Commune',
            icon: Icons.place_rounded,
            onChanged: (value) {
              setState(() {
                _markTouched('commune');
                _communeTextController.text = value ?? '';
                _errors.remove('commune');
              });
            },
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _quartierTextController,
            label: 'Quartier',
            fieldKey: 'quartier',
            icon: Icons.location_city_rounded,
          ),
          const SizedBox(height: 16),
        ] else ...[
          _buildTextField(
            controller: _communeTextController,
            label: 'Commune',
            fieldKey: 'commune',
            icon: Icons.place_rounded,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _quartierTextController,
            label: 'Quartier',
            fieldKey: 'quartier',
            icon: Icons.location_city_rounded,
          ),
          const SizedBox(height: 16),
        ],
        _buildTextField(
          controller: _addressController,
          label: 'Adresse complète',
          fieldKey: 'address',
          icon: Icons.home_work_rounded,
        ),
      ],
    );
  }

  Widget _buildCitySuggestionField() {
    final error = _errorOf('city');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel('Ville', error != null),
        RawAutocomplete<String>(
          textEditingController: _cityTextController,
          focusNode: _cityFocus,
          optionsBuilder: (value) {
            final q = value.text.trim().toLowerCase();
            final source = CitySuggestions.cities;
            if (q.isEmpty) return source.take(12);
            return source.where((city) => city.toLowerCase().contains(q)).take(12);
          },
          onSelected: _onCityChanged,
          fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
            return TextField(
              controller: controller,
              focusNode: focusNode,
              onTapOutside: (_) => focusNode.unfocus(),
              style: const TextStyle(color: Color(0xFF1A1D26), fontSize: 15, fontWeight: FontWeight.w600),
              onChanged: _onCityChanged,
              decoration: _inputDecoration(
                hint: 'Ex: Kinshasa, Lubumbashi...',
                icon: Icons.location_city_rounded,
                hasError: error != null,
              ),
              onSubmitted: (_) => onSubmitted(),
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            return _suggestionList(options.toList(), onSelected, (city) => city);
          },
        ),
        if (error != null) _errorLine(error),
      ],
    );
  }

  Widget _buildQuartierSuggestionField() {
    final error = _errorOf('quartier');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel('Quartier', error != null),
        RawAutocomplete<QuartierModel>(
          textEditingController: _quartierTextController,
          focusNode: _quartierFocus,
          displayStringForOption: (option) => option.name ?? '',
          optionsBuilder: (value) {
            final q = value.text.trim().toLowerCase();
            if (q.isEmpty) return _kinshasaQuartiers.take(12);
            return _kinshasaQuartiers.where((item) {
              return (item.name ?? '').toLowerCase().contains(q);
            }).take(12);
          },
          onSelected: (selection) {
            setState(() {
              _markTouched('quartier');
              _selectedKinshasaQuartier = selection;
              _selectedQuartier = selection;
              _quartierTextController.text = selection.name ?? '';
              _errors.remove('quartier');
            });
          },
          fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
            return TextField(
              controller: controller,
              focusNode: focusNode,
              onTapOutside: (_) => focusNode.unfocus(),
              style: const TextStyle(color: Color(0xFF1A1D26), fontSize: 15, fontWeight: FontWeight.w600),
              decoration: _inputDecoration(
                hint: _isLoadingQuartiers ? 'Chargement...' : 'Tapez ou choisissez un quartier…',
                icon: Icons.search_rounded,
                hasError: error != null,
              ),
              onChanged: (value) {
                _markTouched('quartier');
                final selected = (_selectedKinshasaQuartier?.name ?? '').trim();
                if (selected.isNotEmpty && value.trim() != selected) {
                  setState(() {
                    _selectedKinshasaQuartier = null;
                    _selectedQuartier = null;
                  });
                }
                if (value.trim().isNotEmpty) _errors.remove('quartier');
              },
              onSubmitted: (_) => onSubmitted(),
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            return _suggestionList(options.toList(), onSelected, (item) => item.name ?? '');
          },
        ),
        if (error != null) _errorLine(error),
      ],
    );
  }

  Widget _suggestionList<T extends Object>(
    List<T> options,
    AutocompleteOnSelected<T> onSelected,
    String Function(T) label,
  ) {
    return Align(
      alignment: Alignment.topLeft,
      child: Material(
        elevation: 8,
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 280, maxWidth: 360),
          child: ListView.builder(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            itemCount: options.length,
            itemBuilder: (context, index) {
              final option = options[index];
              return InkWell(
                onTap: () => onSelected(option),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Text(
                    label(option),
                    style: const TextStyle(color: Colors.black, fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildChoiceField<T>({
    required String label,
    required String fieldKey,
    required T? value,
    required List<T> items,
    required String Function(T) displayText,
    required String hintText,
    required IconData icon,
    required ValueChanged<T?> onChanged,
  }) {
    final error = _errorOf(fieldKey);
    final shown = value == null ? hintText : displayText(value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(label, error != null),
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: items.isEmpty
                ? null
                : () async {
                    _markTouched(fieldKey);
                    final picked = await showCasaChoiceSheet<T>(
                      context: context,
                      title: label,
                      icon: icon,
                      selected: value,
                      options: casaChoicesFromLabels(items, displayText),
                    );
                    if (!mounted || picked == null) return;
                    onChanged(picked as T);
                  },
            child: Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: error != null ? const Color(0xFFD32F2F) : const Color(0xFFE6E8EC),
                  width: error != null ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(icon, size: 18, color: error != null ? const Color(0xFFD32F2F) : primaryColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      shown,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: value == null ? const Color(0xFF64748B) : Colors.black,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Icon(Icons.keyboard_arrow_down_rounded, color: error != null ? const Color(0xFFD32F2F) : const Color(0xFF64748B)),
                ],
              ),
            ),
          ),
        ),
        if (error != null) _errorLine(error),
      ],
    );
  }

  Widget _buildLogoUpload() {
    return Center(
      child: GestureDetector(
        onTap: _pickImage,
        child: Container(
          width: 112,
          height: 112,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(
              color: _errorOf('logo') != null ? const Color(0xFFD32F2F) : primaryColor,
              width: 2,
            ),
            image: _logoImage != null
                ? DecorationImage(image: FileImage(_logoImage!), fit: BoxFit.cover)
                : null,
          ),
          child: _logoImage == null
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.camera_alt_rounded, size: 32, color: Colors.grey[400]),
                    const SizedBox(height: 4),
                    Text('Logo', style: TextStyle(color: Colors.grey[600], fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                )
              : null,
        ),
      ),
    );
  }

  Widget _fieldLabel(String label, bool hasError, {bool required = true}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 2),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: hasError ? const Color(0xFFD32F2F) : const Color(0xFF1A1D26),
            ),
          ),
          if (required)
            const Text(' *', style: TextStyle(color: Color(0xFFD32F2F), fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _errorLine(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, left: 2),
      child: Text(
        text,
        style: const TextStyle(color: Color(0xFFD32F2F), fontSize: 12, fontWeight: FontWeight.w500),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    required bool hasError,
  }) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(
        color: hasError ? const Color(0xFFD32F2F) : const Color(0xFFE6E8EC),
        width: hasError ? 1.5 : 1,
      ),
    );
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
      prefixIcon: Icon(icon, color: hasError ? const Color(0xFFD32F2F) : primaryColor, size: 20),
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      constraints: const BoxConstraints(minHeight: 56, maxHeight: 56),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      border: border,
      enabledBorder: border,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: hasError ? const Color(0xFFD32F2F) : primaryColor, width: 1.5),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String fieldKey,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    bool required = true,
  }) {
    final error = _errorOf(fieldKey);
    final multiline = maxLines > 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(label, error != null, required: required),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: multiline ? maxLines : 1,
          onTapOutside: (_) => FocusScope.of(context).unfocus(),
          style: const TextStyle(color: Color(0xFF1A1D26), fontSize: 15, fontWeight: FontWeight.w600),
          onChanged: (_) {
            _markTouched(fieldKey);
            if (_errors.containsKey(fieldKey)) {
              setState(() => _errors.remove(fieldKey));
            }
          },
          decoration: _inputDecoration(
            hint: label,
            icon: icon,
            hasError: error != null,
          ).copyWith(
            constraints: multiline ? const BoxConstraints(minHeight: 56) : const BoxConstraints(minHeight: 56, maxHeight: 56),
          ),
        ),
        if (error != null) _errorLine(error),
      ],
    );
  }
}
