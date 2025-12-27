import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:casa/controllers/ServiceController.dart';
import 'package:casa/controllers/LocationController.dart';
import 'package:casa/models/CityModel.dart';
import 'package:casa/models/CommuneModel.dart';
import 'package:casa/models/DistrictModel.dart';
import 'package:casa/models/QuartierModel.dart';
import 'package:casa/utils/FancyNotification.dart';
import 'package:casa/utils/Routes.dart';
import 'package:casa/utils/networkCheck.dart';
import 'package:casa/utils/city_suggestions.dart';
import 'package:casa/utils/country_codes.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:casa/utils/requetes.dart';
import 'package:casa/controllers/AuthentificationCtrl.dart';
import 'package:casa/screens/auth/IdentityVerificationPage.dart';
import '../utils/StockageKeys.dart';

class CreateServicePostPage extends StatefulWidget {
  @override
  _CreateServicePostPageState createState() => _CreateServicePostPageState();
}

class _CreateServicePostPageState extends State<CreateServicePostPage> {
  // Modern color palette
  final Color _primaryColor = Color(0xFF1976D2);
  final Color _secondaryColor = Color(0xFF64B5F6);
  final Color _darkColor = Color(0xFF1A1D26);
  final Color _lightColor = Color(0xFFF8F9FA);
  final Color _greyColor = Color(0xFF6C757D);
  final Color _successColor = Color(0xFF38B000);
  final Color _cardColor = Colors.white;
  final Color _borderColor = Color(0xFFE9ECEF);
  final Color _errorColor = Color(0xFFD32F2F);

  // Tailles de texte
  final double _titleSize = 18.0;
  final double _bodySize = 14.0;
  final double _captionSize = 12.0;

  // Espacements
  final double _smallSpace = 8.0;
  final double _mediumSpace = 16.0;
  final double _largeSpace = 24.0;

  // Form controllers
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _priceMinController = TextEditingController();
  final TextEditingController _priceMaxController = TextEditingController();
  final TextEditingController _experienceController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _cityTextController = TextEditingController();
  final TextEditingController _communeTextController = TextEditingController();
  final TextEditingController _quartierTextController = TextEditingController();
  //final TextEditingController _plageJourController = TextEditingController(); // Remplacé par sélecteur de jours
  Set<String> _selectedDays = {}; // Jours sélectionnés
  final TextEditingController _plageHeureController = TextEditingController();
  
  // Country code for phone
  String _selectedCountryCode = '+243'; // RDC par défaut
  String _selectedCurrency = 'CDF'; // Devise par défaut : Franc Congolais
  File? _selectedCvFile; // Fichier CV sélectionné (PDF ou DOC)
  final Map<String, String> _countryFlags = Map<String, String>.from(countryFlags);
  final Map<String, String> _countryNames = Map<String, String>.from(countryNames);

  // State variables
  bool _isLoading = false;
  int _currentStep = 0;
  final ImagePicker _picker = ImagePicker();
  late PageController _pageController;
  
  // Images: Photo principale = visage, Photos de réalisations
  XFile? _profileImage; // Photo du visage (image principale)
  List<XFile> _portfolioImages = []; // Photos de réalisations
  
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

  // Validation
  Map<String, String> _fieldErrors = {};
  Map<int, bool> _stepValidations = {0: false, 1: false, 2: false};
  Map<int, Map<String, String>> _stepFieldErrors = {
    0: {},
    1: {},
    2: {},
  };
  Map<String, bool> _fieldTouched = {};
  bool _hasAttemptedSubmit = false;

  // User data
  String? _userServiceType;
  String? _userFullName;
  int? _userId;
  int? _serviceId;
  int? _deviseId = 1; // 1 for FC, 2 for USD

  final GetStorage _storage = GetStorage();

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _loadUserData();
    _loadLocationData();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkUserVerification();
    });
  }

  void _checkUserVerification() {
    final authCtrl = context.read<AuthentificationCtrl>();
    if (authCtrl.user.isCertified != true) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => IdentityVerificationPage()),
      ).then((result) {
        if (result != true) {
          Navigator.pop(context);
        }
      });
    }
  }

  Future<void> _loadUserData() async {
    try {
      final userData = _storage.read<Map<String, dynamic>>(StockageKeys.userKey);
      final profileData = _storage.read<Map<String, dynamic>>(StockageKeys.profileKey);
      
      // Robust userId retrieval as requested
      _userId = userData?['user']?['userId'] ;
      
      _userFullName = profileData?['fullname'] ?? 
                     userData?['username'] ?? 
                     'Prestataire';
      
      // Get serviceId from user accounts
      final userAccounts = _storage.read<List<dynamic>>('user_accounts');
      if (userAccounts != null) {
        for (var acc in userAccounts) {
          var typeAcc = acc['typeAccount'];
          int typeId = typeAcc is Map 
              ? (typeAcc['typeAccountId'] ?? typeAcc['TypeAccountId'] ?? 0)
              : (acc['typeAccountId'] ?? acc['TypeAccountId'] ?? 0);
          
          if (typeId == 3) {
            _serviceId = acc['id'] ?? acc['Id'];
            final accountName = typeAcc is Map ? typeAcc['name']?.toString().toLowerCase() : null;
            if (accountName != null) {
              _userServiceType = _mapAccountTypeToServiceType(accountName);
            }
            break;
          }
        }
      }
    } catch (e) {
      print("Erreur lors du chargement des données utilisateur: $e");
    }
  }

  String? _mapAccountTypeToServiceType(String accountName) {
    final map = {
      'majordome': 'majordhomme',
      'plombier': 'plomberie',
      'electricien': 'electricite',
      'salubrité': 'nettoyage',
      'peintre': 'peinture',
      'carreleur': 'carrelage',
      'menuisier': 'reparation',
      'frigoriste': 'reparation',
      'ajusteur': 'reparation',
      'architecte': 'renovation',
      'chauffeur': 'transport',
      'demenagement': 'demenagement',
    };
    return map[accountName];
  }

  Future<void> _loadLocationData() async {
    try {
      final locationCtrl = LocationController();
      print("📍 [CreateService] Début chargement des données de localisation...");
      
      // Charger TOUTES les données d'abord
      await locationCtrl.loadAllData();
      print("📍 [CreateService] loadAllData() terminé");
      
      _availableCities = await locationCtrl.getAllCities();
      print("📍 [CreateService] ${_availableCities.length} villes chargées");
      
      if (_availableCities.isNotEmpty) {
        _selectedCity = _availableCities.firstWhere(
          (c) => c.name?.toLowerCase() == 'kinshasa',
          orElse: () => _availableCities.first,
        );
        print("📍 [CreateService] Ville sélectionnée: ${_selectedCity?.name}");
        
        if (_selectedCity != null) {
          _availableDistricts = locationCtrl.getDistrictsForCity(_selectedCity!.cityId!);
          print("📍 [CreateService] ${_availableDistricts.length} districts pour ${_selectedCity?.name}");
          
          if (_availableDistricts.isNotEmpty) {
            _selectedDistrict = _availableDistricts.first;
            print("📍 [CreateService] District sélectionné: ${_selectedDistrict?.name}");
            
            _availableCommunes = locationCtrl.getCommunesForDistrict(_selectedDistrict!.districtId!);
            print("📍 [CreateService] ${_availableCommunes.length} communes pour ${_selectedDistrict?.name}");
          }
        }
      }
      
      if (mounted) setState(() {});
      print("📍 [CreateService] Chargement de localisation terminé avec succès");
    } catch (e, stackTrace) {
      print("❌ [CreateService] Erreur chargement localisation: $e");
      print("Stack trace: $stackTrace");
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _priceMinController.dispose();
    _priceMaxController.dispose();
    _experienceController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityTextController.dispose();
    _communeTextController.dispose();
    _quartierTextController.dispose();
    //_plageJourController.dispose(); // Plus utilisé
    _plageHeureController.dispose();
    super.dispose();
  }
  
  String _getCountryNameFromCode(String countryCode) {
    return _countryNames[countryCode] ?? _countryNames[_selectedCountryCode] ?? 'RDC';
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
        _availableCommunes = [];
        _selectedCommune = null;
        _availableQuartiers = [];
        _selectedQuartier = null;
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
        _availableQuartiers = [];
        _selectedQuartier = null;
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
  
  List<String> _filterSuggestions(String query, List<String> suggestions) {
    if (query.isEmpty) return suggestions;
    return suggestions.where((suggestion) =>
        suggestion.toLowerCase().contains(query.toLowerCase())).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _lightColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _primaryColor,
        title: Text(
          'Publier mon service',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          _buildProgressIndicator(),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: NeverScrollableScrollPhysics(),
              children: [
                _buildStep0(), // Photo principale (visage) + Réalisations
                _buildStep1(), // Détails (titre, description, prix)
                _buildStep2(), // Localisation
              ],
            ),
          ),
          _buildNavigationButtons(),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: _mediumSpace, vertical: _mediumSpace),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildStepIndicator(0, 'Photo', Icons.camera_alt_rounded),
          Container(
            width: 40,
            height: 2,
            color: _currentStep > 0 ? _primaryColor : _borderColor,
          ),
          _buildStepIndicator(1, 'Détails', Icons.description_rounded),
          Container(
            width: 40,
            height: 2,
            color: _currentStep > 1 ? _primaryColor : _borderColor,
          ),
          _buildStepIndicator(2, 'Localisation', Icons.location_on_rounded),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(int step, String label, IconData icon) {
    final isActive = _currentStep == step;
    final isCompleted = _currentStep > step;
    
    return GestureDetector(
      onTap: () async {
        if (_validateStep(_currentStep)) {
          setState(() => _currentStep = step);
          await _pageController.animateToPage(
            step,
            duration: Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      },
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive || isCompleted ? _primaryColor : Colors.grey[200],
              border: Border.all(
                color: isActive ? _primaryColor : Colors.transparent,
                width: 2,
              ),
            ),
            child: Icon(
              icon,
              color: isActive || isCompleted ? Colors.white : Colors.grey[600],
              size: 24,
            ),
          ),
          SizedBox(height: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: _captionSize,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              color: isActive ? _primaryColor : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep0() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(_mediumSpace),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            'Photo de profil',
            'Votre photo sera affichée comme image principale',
            Icons.face_rounded,
          ),
          SizedBox(height: _mediumSpace),
          
          // Photo principale (visage)
          _buildProfileImageSelector(),
          
          SizedBox(height: _largeSpace),
          _buildSectionHeader(
            'Réalisations',
            'Ajoutez des photos de vos précédentes réalisations',
            Icons.photo_library_rounded,
          ),
          SizedBox(height: _mediumSpace),
          
          // Galerie de réalisations
          _buildPortfolioImagesGrid(),
        ],
      ),
    );
  }

  Widget _buildStep1() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(_mediumSpace),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            'Informations du service',
            'Décrivez votre service en détail',
            Icons.info_outline_rounded,
          ),
          SizedBox(height: _mediumSpace),
          
          _buildModernTextField(
            controller: _titleController,
            label: 'Titre de l\'annonce',
            hint: 'Ex: Plombier professionnel avec 10 ans d\'expérience',
            icon: Icons.title_rounded,
            fieldKey: 'title',
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Titre requis';
              if (v.trim().length < 10) return 'Titre trop court (min 10 caractères)';
              return null;
            },
          ),
          
          SizedBox(height: _mediumSpace),
          
          _buildModernTextField(
            controller: _descriptionController,
            label: 'Description détaillée',
            hint: 'Décrivez votre service, vos compétences et votre expérience...',
            icon: Icons.description_rounded,
            maxLines: 6,
            fieldKey: 'description',
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Description requise';
              return null;
            },
          ),
          
          SizedBox(height: _mediumSpace),
          
          // Choix de la devise
          _buildCurrencyDropdown(),
          
          SizedBox(height: _mediumSpace),
          
          // Section Fourchette de prix avec description
          _buildSectionHeader(
            'Fourchette de prix',
            'Indiquez une fourchette de prix pour donner plus de flexibilité à vos clients',
            Icons.attach_money_rounded,
          ),
          SizedBox(height: _mediumSpace),
          
          // Prix Min et Max en ligne
          Row(
            children: [
              Expanded(
                child: _buildModernTextField(
                  controller: _priceMinController,
                  label: 'Prix minimum',
                  hint: '0',
                  icon: Icons.trending_down_rounded,
                  keyboardType: TextInputType.number,
                  fieldKey: 'price_min',
                  helperText: 'Le prix le plus bas pour votre service',
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Prix minimum requis';
                    if (double.tryParse(v) == null) return 'Nombre invalide';
                    return null;
                  },
                ),
              ),
              SizedBox(width: _smallSpace),
              Expanded(
                child: _buildModernTextField(
                  controller: _priceMaxController,
                  label: 'Prix maximum',
                  hint: '0',
                  icon: Icons.trending_up_rounded,
                  keyboardType: TextInputType.number,
                  fieldKey: 'price_max',
                  helperText: 'Le prix le plus élevé pour votre service',
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Prix maximum requis';
                    if (double.tryParse(v) == null) return 'Nombre invalide';
                    final minPrice = double.tryParse(_priceMinController.text);
                    final maxPrice = double.tryParse(v);
                    if (minPrice != null && maxPrice != null && maxPrice < minPrice) {
                      return 'Le prix max doit être >= au prix min';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          
          SizedBox(height: _largeSpace),
          
          // Année d'expérience
          _buildModernTextField(
            controller: _experienceController,
            label: 'Années d\'expérience',
            hint: 'Ex: 5',
            icon: Icons.work_history_rounded,
            keyboardType: TextInputType.number,
            fieldKey: 'experience',
            helperText: 'Nombre d\'années d\'expérience dans ce domaine',
            validator: (v) {
              if (v != null && v.trim().isNotEmpty && int.tryParse(v) == null) {
                return 'Nombre invalide';
              }
              return null;
            },
          ),
          SizedBox(height: _smallSpace),
          _buildPhoneField(),
          SizedBox(height: _smallSpace),
          SizedBox(height: _mediumSpace),
          
          // Plage Jours et Heures
          _buildSectionHeader(
            'Disponibilité',
            'Précisez vos jours et heures de disponibilité',
            Icons.access_time_rounded,
          ),
          SizedBox(height: _mediumSpace),
          
          _buildDaySelector(),
          
          _buildModernTextField(
            controller: _plageHeureController,
            label: 'Heures de prestation',
            hint: 'Ex: 08:00 - 17:00, ou 24h/24',
            icon: Icons.timer_outlined,
            fieldKey: 'plage_heure',
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Champs requis';
              return null;
            },
          ),
          
          SizedBox(height: _mediumSpace),
          
          _buildSectionHeader(
            'Curriculum Vitae (optionnel)',
            'Ajoutez votre CV pour renforcer votre crédibilité (PDF ou DOC)',
            Icons.description_rounded,
          ),
          SizedBox(height: _mediumSpace),
          _buildCvUploadSection(),
          SizedBox(height: _mediumSpace),
        ],
      ),
    );
  }

  Widget _buildStep2() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(_mediumSpace),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            'Localisation',
            'Où proposez-vous votre service ?',
            Icons.location_on_rounded,
          ),
          SizedBox(height: _mediumSpace),
          
          // Ville avec suggestions (typeahead)
          _buildCitySuggestionField(),
          
          SizedBox(height: _mediumSpace),
          
          if (_isKinshasaSelected) ...[
            // Mode Kinshasa : District et Commune en dropdowns, Quartier en suggestion
            LayoutBuilder(
              builder: (context, constraints) {
                return Row(
                  children: [
                    Container(
                      width: constraints.maxWidth * 0.48,
                      child: _buildPremiumDropdown<DistrictModel>(
                        label: 'District',
                        value: _selectedDistrict,
                        items: _availableDistricts,
                        displayText: (district) => district.name ?? '',
                        onChanged: (DistrictModel? newValue) {
                          if (mounted) {
                            setState(() {
                              _selectedDistrict = newValue;
                              _updateCommunesForDistrict();
                            });
                          }
                        },
                        icon: Icons.account_balance_rounded,
                        fieldKey: 'district',
                        hintText: 'Sélectionnez un district',
                      ),
                    ),
                    SizedBox(width: constraints.maxWidth * 0.04),
                    Container(
                      width: constraints.maxWidth * 0.48,
                      child: _buildPremiumDropdown<CommuneModel>(
                        label: 'Commune',
                        value: _selectedCommune,
                        items: _availableCommunes,
                        displayText: (commune) => commune.name ?? '',
                        onChanged: (CommuneModel? newValue) {
                          if (mounted) {
                            setState(() {
                              _selectedCommune = newValue;
                              _updateQuartiersForCommune();
                            });
                          }
                        },
                        icon: Icons.place_rounded,
                        fieldKey: 'commune',
                        hintText: 'Sélectionnez une commune',
                      ),
                    ),
                  ],
                );
              },
            ),
            SizedBox(height: _smallSpace),
            _buildSuggestionTextField(
              label: 'Quartier',
              controller: _quartierTextController,
              fieldKey: 'quartier',
              suggestions: _availableQuartiers.map((q) => q.name ?? '').where((n) => n.isNotEmpty).toList(),
            ),
            SizedBox(height: _mediumSpace),
          ] else ...[
            // Mode hors Kinshasa : champs avec suggestions/autocomplete
            _buildSuggestionTextField(
              label: 'Commune',
              controller: _communeTextController,
              fieldKey: 'commune',
              suggestions: _availableCommunes.map((c) => c.name ?? '').where((n) => n.isNotEmpty).toList(),
            ),
            SizedBox(height: _smallSpace),
            _buildSuggestionTextField(
              label: 'Quartier',
              controller: _quartierTextController,
              fieldKey: 'quartier',
              suggestions: _availableQuartiers.map((q) => q.name ?? '').where((n) => n.isNotEmpty).toList(),
            ),
            SizedBox(height: _mediumSpace),
          ],
          
          _buildModernTextField(
            controller: _addressController,
            label: 'Adresse complète',
            hint: 'Rue, numéro, etc.',
            icon: Icons.home_rounded,
            maxLines: 2,
            fieldKey: 'address',
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Adresse requise';
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildProfileImageSelector() {
    final hasError = _shouldShowError(0, 'profile_image') && _profileImage == null;
    final errorMsg = _getFieldError(0, 'profile_image');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 200,
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: hasError ? _errorColor : _borderColor, width: hasError ? 2 : 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: _profileImage != null
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.file(
                        File(_profileImage!.path),
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: IconButton(
                        icon: Icon(Icons.edit, color: Colors.white),
                        style: IconButton.styleFrom(
                          backgroundColor: _primaryColor.withOpacity(0.8),
                        ),
                        onPressed: () => _pickProfileImage(),
                      ),
                    ),
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: IconButton(
                        icon: Icon(Icons.delete, color: Colors.white),
                        style: IconButton.styleFrom(
                          backgroundColor: _errorColor.withOpacity(0.8),
                        ),
                        onPressed: () {
                          if (mounted) {
                            setState(() {
                              _profileImage = null;
                              _validateStep(0);
                            });
                          }
                        },
                      ),
                    ),
                  ],
                )
              : GestureDetector(
                  onTap: () => _pickProfileImage(),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: hasError ? _errorColor : _borderColor, style: BorderStyle.solid, width: 2),
                      color: _lightColor,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.camera_alt_rounded, size: 48, color: hasError ? _errorColor : _primaryColor),
                        SizedBox(height: _mediumSpace),
                        Text(
                          'Ajouter votre photo',
                          style: GoogleFonts.inter(
                            fontSize: _bodySize,
                            fontWeight: FontWeight.w600,
                            color: hasError ? _errorColor : _darkColor,
                          ),
                        ),
                        SizedBox(height: _smallSpace),
                        Text(
                          'Votre visage sera l\'image principale',
                          style: GoogleFonts.inter(
                            fontSize: _captionSize,
                            color: hasError ? _errorColor.withOpacity(0.7) : _greyColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
        if (hasError && errorMsg != null)
          Padding(
            padding: EdgeInsets.only(top: 8, left: 4),
            child: Row(
              children: [
                Icon(Icons.error_outline_rounded, size: 16, color: _errorColor),
                SizedBox(width: 8),
                Text(
                  errorMsg,
                  style: GoogleFonts.inter(
                    fontSize: _captionSize,
                    color: _errorColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildPortfolioImagesGrid() {
    final hasError = _shouldShowError(0, 'portfolio_images') && _portfolioImages.isEmpty;
    final errorMsg = _getFieldError(0, 'portfolio_images');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: hasError ? _errorColor : _borderColor, width: hasError ? 2 : 1),
          ),
          padding: EdgeInsets.all(_mediumSpace),
          child: GridView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: _smallSpace,
              mainAxisSpacing: _smallSpace,
            ),
            itemCount: _portfolioImages.length + 1,
            itemBuilder: (context, index) {
              if (index == _portfolioImages.length) {
                return GestureDetector(
                  onTap: () => _pickPortfolioImage(),
                  child: Container(
                    decoration: BoxDecoration(
                      color: _lightColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: hasError ? _errorColor : _borderColor, style: BorderStyle.solid, width: hasError ? 2 : 1),
                    ),
                    child: Icon(Icons.add_photo_alternate_rounded, color: hasError ? _errorColor : _primaryColor, size: 32),
                  ),
                );
              }
              return Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      File(_portfolioImages[index].path),
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () {
                        if (mounted) {
                          setState(() {
                            _markFieldTouched('portfolio_images');
                            _portfolioImages.removeAt(index);
                            _validateStep(0);
                          });
                        }
                      },
                      child: Container(
                        padding: EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: _errorColor,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.close, color: Colors.white, size: 16),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        if (hasError && errorMsg != null)
          Padding(
            padding: EdgeInsets.only(top: 8, left: 4),
            child: Row(
              children: [
                Icon(Icons.error_outline_rounded, size: 16, color: _errorColor),
                SizedBox(width: 8),
                Text(
                  errorMsg,
                  style: GoogleFonts.inter(
                    fontSize: _captionSize,
                    color: _errorColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _pickProfileImage() async {
    _showImageSourceModal(isProfile: true);
  }

  Future<void> _pickPortfolioImage() async {
    _showImageSourceModal(isProfile: false);
  }

  void _showImageSourceModal({required bool isProfile}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Choisir une source',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _darkColor,
              ),
            ),
            SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildImageSourceButton(
                    icon: Icons.photo_library_rounded,
                    label: 'Galerie',
                    onTap: () {
                      Navigator.pop(context);
                      _pickImageFromSource(ImageSource.gallery, isProfile: isProfile);
                    },
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: _buildImageSourceButton(
                    icon: Icons.camera_alt_rounded,
                    label: 'Caméra',
                    onTap: () {
                      Navigator.pop(context);
                      _pickImageFromSource(ImageSource.camera, isProfile: isProfile);
                    },
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Annuler', style: GoogleFonts.inter(color: _greyColor)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSourceButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: _lightColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _borderColor),
        ),
        child: Column(
          children: [
            Icon(icon, color: _primaryColor, size: 32),
            SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: _bodySize,
                fontWeight: FontWeight.w600,
                color: _darkColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImageFromSource(ImageSource source, {required bool isProfile}) async {
    try {
      // Attendre un peu pour s'assurer que le modal est bien fermé
      await Future.delayed(Duration(milliseconds: 300));
      
      if (!mounted) return;

      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1440,
      );

      // Vérifier à nouveau que le widget est toujours monté après la sélection
      if (!mounted) return;

      if (image != null) {
        // Vérifier que le fichier existe et est valide
        final file = File(image.path);
        
        // Attendre un peu pour que le fichier soit complètement écrit (important pour les captures caméra)
        await Future.delayed(Duration(milliseconds: 100));
        
        if (await file.exists()) {
          // Vérifier la taille du fichier
          final fileSize = await file.length();
          if (fileSize == 0) {
            if (mounted) {
              FancyNotification.show(
                context,
                "Erreur : fichier image vide",
                isError: true,
              );
            }
            return;
          }

          if (isProfile) {
            if (mounted) {
              setState(() {
                _profileImage = image;
                _validateStep(0);
              });
            }
          } else {
            // Pour le portfolio, si on est en galerie, on permet le multi-image
            if (source == ImageSource.gallery) {
              final List<XFile> images = await _picker.pickMultiImage(imageQuality: 85);
              if (images.isNotEmpty && mounted) {
                setState(() {
                  _markFieldTouched('portfolio_images');
                  _portfolioImages.addAll(images);
                  _validateStep(0);
                });
              }
            } else {
              // Caméra: une seule image
              if (mounted) {
                setState(() {
                  _markFieldTouched('portfolio_images');
                  _portfolioImages.add(image);
                  _validateStep(0);
                });
              }
            }
          }
        } else {
          if (mounted) {
            FancyNotification.show(
              context,
              "Erreur : fichier image introuvable",
              isError: true,
            );
          }
        }
      }
    } on PlatformException catch (e) {
      if (!mounted) return;
      print('Erreur lors de la sélection de l\'image: $e');
      String errorMessage = "Erreur lors de la sélection de l'image";
      if (e.code == 'photo_access_denied' || e.code == 'camera_access_denied') {
        errorMessage = "Permission refusée. Veuillez autoriser l'accès dans les paramètres de l'application.";
      } else if (e.code == 'camera_access_denied') {
        errorMessage = "Accès à la caméra refusé. Veuillez autoriser l'accès dans les paramètres.";
      }
      FancyNotification.show(context, errorMessage, type: NotificationType.error);
    } catch (e) {
      if (!mounted) return;
      print('Erreur inattendue lors de la sélection de l\'image: $e');
      FancyNotification.show(context, "Erreur lors de la sélection de l'image", type: NotificationType.error);
    }
  }

  Widget _buildSectionHeader(String title, String subtitle, IconData icon) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: _primaryColor, size: 24),
        ),
        SizedBox(width: _mediumSpace),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: _titleSize,
                  fontWeight: FontWeight.w700,
                  color: _darkColor,
                ),
              ),
              SizedBox(height: 4),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: _captionSize,
                  color: _greyColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? fieldKey,
    String? Function(String?)? validator,
    String? helperText,
  }) {
    final hasError = fieldKey != null && 
                     _shouldShowError(_currentStep, fieldKey) && 
                     (_getFieldError(_currentStep, fieldKey) != null);
    final errorText = hasError ? _getFieldError(_currentStep, fieldKey) : null;

    return Container(
      margin: EdgeInsets.only(bottom: _mediumSpace),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: _bodySize,
              fontWeight: FontWeight.w600,
              color: hasError ? _errorColor : _darkColor,
            ),
          ),
          SizedBox(height: _smallSpace),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            maxLines: maxLines,
            validator: validator,
            onChanged: (value) {
              if (mounted) {
                setState(() {
                  if (fieldKey != null) {
                    _markFieldTouched(fieldKey);
                  }
                  _validateStep(_currentStep);
                });
              }
            },
            onTap: () {
              if (mounted) {
                setState(() {
                  if (fieldKey != null) {
                    _markFieldTouched(fieldKey);
                  }
                  _validateStep(_currentStep);
                });
              }
            },
            decoration: InputDecoration(
              hintText: hint,
              prefixIcon: Icon(icon, color: hasError ? _errorColor : _primaryColor),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: hasError ? _errorColor : _borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: hasError ? _errorColor : _borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _primaryColor, width: 2),
              ),
              filled: true,
              fillColor: Colors.white,
              helperText: helperText,
              helperStyle: GoogleFonts.inter(
                fontSize: _captionSize - 1,
                color: _greyColor,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          if (hasError && errorText != null)
            Padding(
              padding: EdgeInsets.only(top: 6, left: 4),
              child: Text(
                errorText,
                style: GoogleFonts.inter(
                  fontSize: _captionSize,
                  color: _errorColor,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLocationDropdown<T>({
    required String label,
    required T? value,
    required List<T> items,
    required String Function(T) displayText,
    required void Function(T?) onChanged,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: _mediumSpace),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: _bodySize,
              fontWeight: FontWeight.w600,
              color: _darkColor,
            ),
          ),
          SizedBox(height: _smallSpace),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _borderColor),
            ),
            padding: EdgeInsets.symmetric(horizontal: _mediumSpace),
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              underline: SizedBox(),
              hint: Text('Sélectionner $label'),
              items: items.map((item) => 
                DropdownMenuItem(value: item, child: Text(displayText(item)))
              ).toList(),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return Container(
      padding: EdgeInsets.all(_mediumSpace),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
            child: OutlinedButton(
                onPressed: () {
                  setState(() {
                    _currentStep--;
                  });
                  _pageController.animateToPage(
                    _currentStep,
                    duration: Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                },
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: BorderSide(color: _primaryColor),
                ),
                child: Text(
                  'Précédent',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    color: _primaryColor,
                  ),
                ),
              ),
            ),
          if (_currentStep > 0) SizedBox(width: _mediumSpace),
          Expanded(
            flex: _currentStep == 0 ? 1 : 1,
            child: ElevatedButton(
              onPressed: _isLoading ? null : () async {
                setState(() {
                  _hasAttemptedSubmit = true;
                });
                if (_currentStep < 2) {
                  if (_validateStep(_currentStep)) {
                    setState(() {
                      _currentStep++;
                    });
                    await _pageController.animateToPage(
                      _currentStep,
                      duration: Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  }
                } else {
                  _handleSubmit();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: _isLoading
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      _currentStep == 2 ? 'Publier' : 'Suivant',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        fontSize: _bodySize,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  bool _validateStep(int step) {
    // Note: _hasAttemptedSubmit is now set only during navigation/submission
    
    switch (step) {
      case 0:
        _clearStepFieldErrors(0);
        if (_profileImage == null) {
          _setFieldError(0, 'profile_image', 'Photo de profil requise');
        }
        
        if (_portfolioImages.isEmpty) {
          _setFieldError(0, 'portfolio_images', 'Au moins une photo de réalisation est requise');
        } else if (_portfolioImages.length < 2) {
          // Proposition : encourager plus de photos
          // _setFieldError(0, 'portfolio_images', 'Idéalement, ajoutez au moins 2 photos');
        }

        _stepValidations[0] = _profileImage != null && _portfolioImages.isNotEmpty;
        return _stepValidations[0]!;
        
      case 1:
        _clearStepFieldErrors(1);
        final title = _titleController.text.trim();
        final description = _descriptionController.text.trim();
        final priceMin = _priceMinController.text.trim();
        final priceMax = _priceMaxController.text.trim();
        final phone = _phoneController.text.trim();
        
        if (title.isEmpty) {
          _setFieldError(1, 'title', 'Titre requis');
        } else if (title.length < 15) {
          _setFieldError(1, 'title', 'Titre trop court (min 15 car.)');
        }
        
        if (description.isEmpty) {
          _setFieldError(1, 'description', 'Description requise');
        } else if (description.length < 30) {
          _setFieldError(1, 'description', 'Description trop courte (min 30 car.)');
        }
        
        if (priceMin.isEmpty) {
          _setFieldError(1, 'price_min', 'Prix minimum requis');
        } else if (double.tryParse(priceMin) == null || double.parse(priceMin) < 1) {
          _setFieldError(1, 'price_min', 'Prix minimum invalide');
        }
        
        if (priceMax.isEmpty) {
          _setFieldError(1, 'price_max', 'Prix maximum requis');
        } else if (double.tryParse(priceMax) == null || double.parse(priceMax) < 1) {
          _setFieldError(1, 'price_max', 'Prix maximum invalide');
        } else {
          final minPrice = double.tryParse(priceMin);
          final maxPrice = double.tryParse(priceMax);
          if (minPrice != null && maxPrice != null && maxPrice < minPrice) {
            _setFieldError(1, 'price_max', 'Prix maximum doit être supérieur au minimum');
          }
        }
        
        if (phone.isEmpty) {
          _setFieldError(1, 'phone', 'Téléphone requis');
        } else {
          final digits = phone.replaceAll(RegExp(r'\D'), '');
          if (digits.length < 9) {
            _setFieldError(1, 'phone', 'Numéro invalide (min 9 chiffres)');
          }
        }

        if (_selectedDays.isEmpty) {
          _setFieldError(1, 'plage_jour', 'Veuillez sélectionner au moins un jour');
        }
        
        if (_plageHeureController.text.trim().isEmpty) {
          _setFieldError(1, 'plage_heure', 'Heures de prestation requises');
        }
        
        _stepValidations[1] = !_hasFieldErrors(1);
        return _stepValidations[1]!;
        
      case 2:
        _clearStepFieldErrors(2);
        final address = _addressController.text.trim();
        
        if (_isKinshasaSelected) {
          if (_selectedCity == null) _setFieldError(2, 'city', 'Ville requise');
          if (_selectedCommune == null) _setFieldError(2, 'commune', 'Commune requise');
          if (_selectedQuartier == null && _quartierTextController.text.trim().isEmpty) {
            _setFieldError(2, 'quartier', 'Quartier requis');
          } else if (_quartierTextController.text.trim().length < 3) {
            _setFieldError(2, 'quartier', 'Quartier trop court (min 3 car.)');
          }
        } else {
          if (_cityTextController.text.trim().isEmpty) _setFieldError(2, 'city', 'Ville requise');
          if (_communeTextController.text.trim().isEmpty) _setFieldError(2, 'commune', 'Commune requise');
          
          if (_quartierTextController.text.trim().isEmpty) {
            _setFieldError(2, 'quartier', 'Quartier requis');
          } else if (_quartierTextController.text.trim().length < 3) {
            _setFieldError(2, 'quartier', 'Quartier trop court (min 3 car.)');
          }
        }
        
        if (address.isEmpty) {
          _setFieldError(2, 'address', 'Adresse requise');
        } else if (address.length < 5) {
          _setFieldError(2, 'address', 'Adresse trop courte');
        }
        
        _stepValidations[2] = !_hasFieldErrors(2);
        return _stepValidations[2]!;
        
      default:
        return false;
    }
  }

  void _clearStepFieldErrors(int step) {
    if (_stepFieldErrors.containsKey(step)) {
      _stepFieldErrors[step]!.clear();
    }
  }

  void _setFieldError(int step, String field, String error) {
    if (!_stepFieldErrors.containsKey(step)) {
      _stepFieldErrors[step] = {};
    }
    _stepFieldErrors[step]![field] = error;
  }

  void _removeFieldError(int step, String field) {
    _stepFieldErrors[step]?.remove(field);
  }

  String? _getFieldError(int step, String field) {
    return _stepFieldErrors[step]?[field];
  }

  bool _hasFieldErrors(int step) {
    return _stepFieldErrors[step]?.isNotEmpty ?? false;
  }

  void _markFieldTouched(String field) {
    _fieldTouched[field] = true;
  }

  bool _shouldShowError(int step, String field) {
    return _hasAttemptedSubmit || _fieldTouched[field] == true;
  }

  Future<void> _handleSubmit() async {
    print("🚀 [CreateService] ========== DÉBUT _handleSubmit ==========");
    setState(() {
      _hasAttemptedSubmit = true;
    });
    
    if (!_validateStep(2)) {
      print("❌ [CreateService] Validation step 2 échouée");
      FancyNotification.show(
        context,
        "Veuillez corriger les erreurs avant de publier",
        isError: true,
      );
      return;
    }

    // Double check verification
    final authCtrl = context.read<AuthentificationCtrl>();
    print("👤 [CreateService] User ID: ${authCtrl.user.userId}, Certified: ${authCtrl.user.isCertified}");
    if (authCtrl.user.isCertified != true) {
      print("❌ [CreateService] Utilisateur non certifié");
      FancyNotification.show(context, "Vous devez être certifié pour publier un service.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Préparer les images en base64
      List<Map<String, String>> imagesPayload = [];
      
      print("📸 [CreateService] Préparation des images...");
      // Photo principale (visage)
      if (_profileImage != null) {
        final bytes = await File(_profileImage!.path).readAsBytes();
        final base64Image = base64Encode(bytes);
        imagesPayload.add({"image": base64Image});
        print("📸 [CreateService] Photo principale ajoutée (${bytes.length} bytes, base64: ${base64Image.length} chars)");
      } else {
        print("⚠️ [CreateService] Aucune photo principale");
      }
      
      // Photos de réalisations
      for (var i = 0; i < _portfolioImages.length; i++) {
        final img = _portfolioImages[i];
        final bytes = await File(img.path).readAsBytes();
        final base64Image = base64Encode(bytes);
        imagesPayload.add({"image": base64Image});
        print("📸 [CreateService] Photo portfolio ${i+1} ajoutée (${bytes.length} bytes)");
      }
      print("📸 [CreateService] Total images: ${imagesPayload.length}");

      // Convertir les jours sélectionnés en string
      final selectedDaysString = _selectedDays.join(', ');
      print("📅 [CreateService] Jours sélectionnés: $selectedDaysString");

      // Prepare payload following user request model
      final payload = {
        "prestation": {
          "userId": authCtrl.user.userId ?? 0,
          "serviceId": _serviceId ?? 0,
          "deviseId": _selectedCurrency == 'USD' ? 2 : 1,
          "title": _titleController.text.trim(),
          "description": _descriptionController.text.trim(),
          "experience": _experienceController.text.trim(),
          "plageJourPrestation": selectedDaysString,
          "plageHeurePrestation": _plageHeureController.text.trim(),
          "minPrice": double.tryParse(_priceMinController.text) ?? 0.0,
          "maxPrice": double.tryParse(_priceMaxController.text) ?? 0.0,
          "address": _addressController.text.trim(),
          "communeValue": _isKinshasaSelected ? (_selectedCommune?.name ?? "") : _communeTextController.text.trim(),
          "quartierValue": _isKinshasaSelected ? (_selectedQuartier?.name ?? "") : _quartierTextController.text.trim(),
          "cityValue": _isKinshasaSelected ? (_selectedCity?.name ?? "") : _cityTextController.text.trim(),
          "countryValue": "RDC",
          "cityId": _isKinshasaSelected && _selectedCity != null ? (_selectedCity?.cityId ?? 0) : 0,
          "communeId": _isKinshasaSelected && _selectedCommune != null ? (_selectedCommune?.communeId ?? 0) : 0,
          "quartierId": _isKinshasaSelected && _selectedQuartier != null ? (_selectedQuartier?.quartierId ?? 0) : 0,
          "districtId": _isKinshasaSelected && _selectedDistrict != null ? (_selectedDistrict?.districtId ?? 0) : 0
        },
        "images": imagesPayload
      };

      print("📦 [CreateService] Payload prestation (sans images base64):");
      final payloadSummary = Map<String, dynamic>.from(payload);
      if (payloadSummary.containsKey('images')) {
        payloadSummary['images'] = '[${(payloadSummary['images'] as List).length} images]';
      }
      print("📦 $payloadSummary");

      final ctrl = context.read<ServiceController>();
      print("📡 [CreateService] Appel à createPrestation...");
      final res = await ctrl.createPrestation(payload);
      print("📥 [CreateService] Réponse reçue - status: ${res.status}, errorMsg: ${res.errorMsg}");

      if (!mounted) {
        print("⚠️ [CreateService] Widget non monté après réponse");
        return;
      }

      if (res.status == true) {
        print("✅ [CreateService] Service publié avec succès!");
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
        String errorMessage = res.errorMsg ?? "Erreur lors de la publication";
        print("❌ [CreateService] Échec: $errorMessage");
        if (res.data != null) {
          print("❌ [CreateService] Response data: ${res.data}");
        }
        FancyNotification.show(context, errorMessage, type: NotificationType.error);
      }
    } catch (e, stackTrace) {
      print("❌ [CreateService] EXCEPTION: $e");
      print("📚 [CreateService] Stack trace: $stackTrace");
      FancyNotification.show(context, "Une erreur est survenue lors de la publication.", isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      print("🏁 [CreateService] ========== FIN _handleSubmit ==========");
    }
  }
  
   Widget _buildCitySuggestionField() {
    final hasError = _shouldShowError(2, 'city') && _getFieldError(2, 'city') != null;
    final errorText = hasError ? _getFieldError(2, 'city') : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: 6, left: 4),
          child: Row(
            children: [
              Text(
                'Ville',
                style: TextStyle(
                  fontSize: _bodySize,
                  fontWeight: FontWeight.w600,
                  color: hasError ? _errorColor : _darkColor,
                ),
              ),
              Text('*', style: TextStyle(color: _errorColor, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        Autocomplete<String>(
          initialValue: TextEditingValue(text: _cityTextController.text),
          optionsBuilder: (TextEditingValue textEditingValue) {
            return _filterSuggestions(textEditingValue.text, CitySuggestions.cities);
          },
          onSelected: (String selection) {
            _markFieldTouched('city');
            setState(() {
              _cityTextController.text = selection;
              // si Kinshasa, utiliser la sélection stricte et garder le workflow existant
              final kin = _availableCities.firstWhere(
                  (c) => (c.name ?? '').toLowerCase() == selection.toLowerCase(),
                  orElse: () => _selectedCity ?? (_availableCities.isNotEmpty ? _availableCities.first : CityModel(cityId: 1, name: 'Kinshasa')));
              if (selection.toLowerCase().trim() == 'kinshasa') {
                _selectedCity = kin.name == null ? _selectedCity : kin;
                _updateDistrictsForCity();
              } else {
                _selectedCity = null;
                _selectedDistrict = null;
                _selectedCommune = null;
                _selectedQuartier = null;
              }
              _validateStep(2);
            });
          },
          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
            _cityTextController.value = controller.value;
            return TextField(
              controller: controller,
              focusNode: focusNode,
              onChanged: (value) {
                if (mounted) {
                  setState(() {
                    _markFieldTouched('city');
                    _cityTextController.text = value;
                    _validateStep(2);
                  });
                }
              },
              decoration: InputDecoration(
                hintText: 'Ex: Kinshasa, Lubumbashi...',
                prefixIcon: Icon(Icons.location_city_rounded, color: hasError ? _errorColor : _primaryColor),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: hasError ? _errorColor : _borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: hasError ? _errorColor : _borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: hasError ? _errorColor : _primaryColor),
                ),
                errorText: null,
              ),
              onSubmitted: (_) => onFieldSubmitted(),
            );
          },
        ),
        if (hasError)
          Padding(
            padding: EdgeInsets.only(top: 6, left: 4),
            child: Row(
              children: [
                Icon(Icons.error_outline_rounded, size: 14, color: _errorColor),
                SizedBox(width: 6),
                Text(
                  errorText!,
                  style: TextStyle(
                    color: _errorColor,
                    fontSize: _captionSize,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
  
  Widget _buildSuggestionTextField({
    required String label,
    required TextEditingController controller,
    required String fieldKey,
    required List<String> suggestions,
  }) {
    final hasError = _shouldShowError(2, fieldKey) && _getFieldError(2, fieldKey) != null;
    final errorText = hasError ? _getFieldError(2, fieldKey) : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: 6, left: 4, top: _smallSpace),
          child: Row(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: _captionSize,
                  fontWeight: FontWeight.w600,
                  color: hasError ? _errorColor : _darkColor,
                ),
              ),
              Text('*', style: TextStyle(color: _errorColor, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        Autocomplete<String>(
          initialValue: TextEditingValue(text: controller.text),
          optionsBuilder: (TextEditingValue textEditingValue) {
            return _filterSuggestions(textEditingValue.text, suggestions);
          },
          onSelected: (String selection) {
            if (mounted) {
              setState(() {
                _markFieldTouched(fieldKey);
                controller.text = selection;
                _validateStep(2);
              });
            }
          },
          fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
            controller.value = textController.value;
            return TextField(
              controller: textController,
              focusNode: focusNode,
              onChanged: (value) {
                if (mounted) {
                  setState(() {
                    _markFieldTouched(fieldKey);
                    _validateStep(2);
                  });
                }
              },
              style: TextStyle(
                fontSize: _bodySize,
                color: _darkColor,
              ),
              decoration: InputDecoration(
                hintText: 'Saisir $label',
                hintStyle: TextStyle(
                  fontSize: _bodySize,
                  color: Colors.grey.shade500,
                ),
                prefixIcon: Icon(Icons.place_rounded, color: hasError ? _errorColor : _primaryColor),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: hasError ? _errorColor : _borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: hasError ? _errorColor : _borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: hasError ? _errorColor : _primaryColor, width: 2),
                ),
                errorText: null,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
              onSubmitted: (_) => onFieldSubmitted(),
            );
          },
        ),
        if (hasError)
          Padding(
            padding: EdgeInsets.only(top: 6, left: 4),
            child: Row(
              children: [
                Icon(Icons.error_outline_rounded, size: 14, color: _errorColor),
                SizedBox(width: 6),
                Text(
                  errorText!,
                  style: TextStyle(
                    color: _errorColor,
                    fontSize: _captionSize,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
  
  Widget _buildPremiumDropdown<T>({
    required String label,
    required T? value,
    required List<T> items,
    required String Function(T) displayText,
    required void Function(T?) onChanged,
    required IconData icon,
    String? fieldKey,
    String? hintText,
    bool isRequired = true,
  }) {
    final hasError = fieldKey != null && _shouldShowError(2, fieldKey) && _getFieldError(2, fieldKey) != null;
    final errorText = hasError ? _getFieldError(2, fieldKey) : null;

    return Container(
      margin: EdgeInsets.only(bottom: _smallSpace),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: 6, left: 4),
            child: Row(
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: _bodySize,
                    fontWeight: FontWeight.w600,
                    color: hasError ? _errorColor : _darkColor,
                  ),
                ),
                if (isRequired)
                  Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Text(
                      '*',
                      style: TextStyle(
                        color: _errorColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasError ? _errorColor : value != null ? _primaryColor.withOpacity(0.3) : _borderColor,
                width: hasError ? 1.5 : 1,
              ),
              color: Colors.white,
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<T>(
                value: value,
                isExpanded: true,
                items: [
                  DropdownMenuItem<T>(
                    value: null,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        hintText ?? 'Sélectionnez...',
                        style: TextStyle(
                          color: _greyColor,
                          fontSize: _bodySize,
                        ),
                      ),
                    ),
                  ),
                  ...items.map((T item) {
                    return DropdownMenuItem<T>(
                      value: item,
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Icon(icon, size: 18, color: _primaryColor),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                displayText(item),
                                style: TextStyle(
                                  fontSize: _bodySize,
                                  color: _darkColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ],
                onChanged: (T? newValue) {
                  if (mounted) {
                    setState(() {
                      if (newValue != null) {
                         _markFieldTouched(fieldKey ?? label.toLowerCase());
                      }
                      onChanged(newValue);
                      _validateStep(_currentStep);
                    });
                  }
                },
                icon: Icon(Icons.arrow_drop_down_rounded, color: _primaryColor),
              ),
            ),
          ),
          if (hasError)
            Padding(
              padding: EdgeInsets.only(top: 6, left: 4),
              child: Row(
                children: [
                  Icon(Icons.error_outline_rounded, size: 14, color: _errorColor),
                  SizedBox(width: 6),
                  Text(
                    errorText!,
                    style: TextStyle(
                      color: _errorColor,
                      fontSize: _captionSize,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildCurrencyDropdown() {
    return Container(
      margin: EdgeInsets.only(bottom: _mediumSpace),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Devise',
            style: GoogleFonts.inter(
              fontSize: _bodySize,
              fontWeight: FontWeight.w600,
              color: _darkColor,
            ),
          ),
          SizedBox(height: _smallSpace),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _borderColor),
            ),
            padding: EdgeInsets.symmetric(horizontal: _mediumSpace),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedCurrency,
                isExpanded: true,
                icon: Icon(Icons.currency_exchange_rounded, color: _primaryColor),
                items: [
                  DropdownMenuItem(
                    value: 'CDF',
                    child: Row(
                      children: [
                        Text('Franc Congolais (CDF)', style: TextStyle(fontSize: _bodySize)),
                        SizedBox(width: 8),
                        Text('FC', style: TextStyle(fontSize: _captionSize, color: _greyColor)),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'USD',
                    child: Row(
                      children: [
                        Text('Dollar Américain (USD)', style: TextStyle(fontSize: _bodySize)),
                        SizedBox(width: 8),
                        Text('\$', style: TextStyle(fontSize: _captionSize, color: _greyColor)),
                      ],
                    ),
                  ),
                ],
                onChanged: (value) {
                  if (value != null && mounted) {
                    setState(() {
                      _markFieldTouched('currency');
                      _selectedCurrency = value;
                      _validateStep(1);
                    });
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCvUploadSection() {
    return Container(
      margin: EdgeInsets.only(bottom: _mediumSpace),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _selectedCvFile != null ? _successColor : _borderColor,
          width: _selectedCvFile != null ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: _pickCvFile,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(_mediumSpace),
          child: Column(
            children: [
              Icon(
                _selectedCvFile != null ? Icons.check_circle_rounded : Icons.upload_file_rounded,
                color: _selectedCvFile != null ? _successColor : _primaryColor,
                size: 48,
              ),
              SizedBox(height: _smallSpace),
              Text(
                _selectedCvFile != null ? 'CV importé' : 'Importer un CV',
                style: GoogleFonts.inter(
                  color: _darkColor,
                  fontSize: _bodySize,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (_selectedCvFile != null) ...[
                SizedBox(height: 4),
                Text(
                  _selectedCvFile!.path.split('/').last,
                  style: GoogleFonts.inter(
                    color: _greyColor,
                    fontSize: _captionSize,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _removeCvFile,
                  icon: Icon(Icons.delete_outline_rounded, size: 16, color: _errorColor),
                  label: Text('Supprimer', style: GoogleFonts.inter(color: _errorColor, fontSize: _captionSize)),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    minimumSize: Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ] else ...[
                SizedBox(height: 4),
                Text(
                  'PDF ou DOC (max 5 MB)',
                  style: GoogleFonts.inter(
                    color: _greyColor,
                    fontSize: _captionSize,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickCvFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx'],
        withData: false,
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        
        // Vérifier la taille du fichier (max 5 MB)
        final fileSize = await file.length();
        if (fileSize > 5 * 1024 * 1024) {
          FancyNotification.show(
            context,
            "Le fichier est trop volumineux. Taille maximale: 5 MB",
            type: NotificationType.error,
          );
          return;
        }

        setState(() {
          _markFieldTouched('cv_file');
          _selectedCvFile = file;
          _validateStep(1);
        });

        SnackbarForCasa.success(context, "CV importé avec succès");
      }
    } catch (e) {
      print('Erreur lors de la sélection du CV: $e');
      FancyNotification.show(
        context,
        "Erreur lors de l'import du CV",
        type: NotificationType.error,
      );
    }
  }

  void _removeCvFile() {
    setState(() {
      _markFieldTouched('cv_file');
      _selectedCvFile = null;
      _validateStep(1);
    });
  }

  Widget _buildPhoneField() {
    final errorText = _getFieldError(1, 'phone');
    final hasError = errorText != null && errorText.isNotEmpty && _shouldShowError(1, 'phone');
    
    return Container(
      margin: EdgeInsets.only(bottom: _mediumSpace),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: 6, left: 4),
            child: Row(
              children: [
                Text(
                  'Téléphone',
                  style: TextStyle(
                    fontSize: _bodySize,
                    fontWeight: FontWeight.w600,
                    color: hasError ? _errorColor : _darkColor,
                  ),
                ),
                Text('*', style: TextStyle(color: _errorColor, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            onChanged: (value) {
              if (mounted) {
                setState(() {
                  _markFieldTouched('phone');
                  _validateStep(1);
                });
              }
            },
            onTap: () {
              if (mounted) {
                setState(() {
                  _markFieldTouched('phone');
                  _validateStep(1);
                });
              }
            },
            style: TextStyle(
              fontSize: _bodySize,
              color: _darkColor,
            ),
            decoration: InputDecoration(
              hintText: '810000000',
              hintStyle: TextStyle(
                fontSize: _bodySize,
                color: Colors.grey.shade500,
              ),
              prefixIcon: _buildCountryCodeDropdown(),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: hasError ? _errorColor : _borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: hasError ? _errorColor : _borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: hasError ? _errorColor : _primaryColor, width: 2),
              ),
              errorText: null,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
          if (hasError)
            Padding(
              padding: EdgeInsets.only(top: 6, left: 4),
              child: Row(
                children: [
                  Icon(Icons.error_outline_rounded, size: 14, color: _errorColor),
                  SizedBox(width: 6),
                  Text(
                    errorText!,
                    style: TextStyle(
                      color: _errorColor,
                      fontSize: _captionSize,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildCountryCodeDropdown() {
    return Container(
      width: 140,
      padding: EdgeInsets.only(left: 8, right: 4),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedCountryCode,
          isExpanded: true,
          icon: Icon(Icons.arrow_drop_down_rounded, color: _primaryColor, size: 20),
          style: TextStyle(color: _darkColor, fontSize: 14, fontWeight: FontWeight.w500),
          items: _countryFlags.entries.map((entry) {
            final countryName = _getCountryNameFromCode(entry.key);
            return DropdownMenuItem(
              value: entry.key,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(entry.value, style: TextStyle(fontSize: 16)),
                  SizedBox(width: 8),
                  Text(entry.key, style: TextStyle(fontSize: 13)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      countryName,
                      style: TextStyle(fontSize: 12, color: _greyColor),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (String? newValue) {
            if (newValue != null) {
              setState(() {
                _markFieldTouched('phone');
                _selectedCountryCode = newValue;
                _validateStep(1);
              });
            }
          },
        ),
      ),
    );
  }

  // Widget pour sélectionner les jours de la semaine
  Widget _buildDaySelector() {
    final days = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'];
    final hasError = _shouldShowError(1, 'plage_jour') && _selectedDays.isEmpty;
    
    return Container(
      margin: EdgeInsets.only(bottom: _mediumSpace),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_today_rounded, color: _primaryColor, size: 20),
              SizedBox(width: 8),
              Text(
                'Jours de prestation',
                style: GoogleFonts.inter(
                  fontSize: _bodySize,
                  fontWeight: FontWeight.w600,
                  color: _darkColor,
                ),
              ),
              Text(
                ' *',
                style: TextStyle(color: _errorColor, fontSize: _bodySize),
              ),
            ],
          ),
          SizedBox(height: _smallSpace),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: days.map((day) {
              final isSelected = _selectedDays.contains(day);
              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _selectedDays.remove(day);
                    } else {
                      _selectedDays.add(day);
                    }
                    _markFieldTouched('plage_jour');
                    _validateStep(1);
                  });
                },
                child: AnimatedContainer(
                  duration: Duration(milliseconds: 200),
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? _primaryColor : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? _primaryColor : (hasError ? _errorColor : _borderColor),
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: isSelected ? [
                      BoxShadow(
                        color: _primaryColor.withOpacity(0.3),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      )
                    ] : [],
                  ),
                  child: Text(
                    day.substring(0, 3), // Lun, Mar, Mer, etc.
                    style: GoogleFonts.inter(
                      fontSize: _captionSize + 1,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? Colors.white : _darkColor,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          if (hasError)
            Padding(
              padding: EdgeInsets.only(top: 8, left: 4),
              child: Row(
                children: [
                  Icon(Icons.error_outline_rounded, size: 14, color: _errorColor),
                  SizedBox(width: 6),
                  Text(
                    'Veuillez sélectionner au moins un jour',
                    style: GoogleFonts.inter(
                      fontSize: _captionSize,
                      color: _errorColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          SizedBox(height: 4),
          Text(
            'Sélectionnez les jours où vous proposez vos services',
            style: GoogleFonts.inter(
              fontSize: _captionSize - 1,
              color: _greyColor,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

