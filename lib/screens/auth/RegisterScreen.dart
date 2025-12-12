import 'package:casa/controllers/AuthentificationCtrl.dart';
import 'package:casa/controllers/RegisterBailleurCtrl.dart';
import 'package:casa/utils/Endpoints.dart';
import 'package:casa/utils/Routes.dart';
import 'package:casa/utils/networkCheck.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../controllers/LocationController.dart';
import '../../controllers/RegisterCommissionnaireCtrl.dart';
import '../../controllers/RegisterLocataireCtrl.dart';
import '../../controllers/RegisterMajordomeCtrl.dart';
import '../../controllers/RegisterPlombierCtrl.dart';
import '../../controllers/RegisterElectricienCtrl.dart';
import '../../controllers/RegisterSalubriteCtrl.dart';
import '../../controllers/RegisterPeintreCtrl.dart';
import '../../controllers/RegisterCarreleurCtrl.dart';
import '../../controllers/RegisterMenuisierCtrl.dart';
import '../../controllers/RegisterFrigoristeCtrl.dart';
import '../../controllers/RegisterAjusteurCtrl.dart';
import '../../controllers/RegisterArchitecteCtrl.dart';
import '../../controllers/RegisterChauffeurCtrl.dart';
import '../../controllers/RegisterDemenagementCtrl.dart';
import '../../models/CityModel.dart';
import '../../models/ServiceModel.dart';
import '../../utils/FancyNotification.dart';
import '../../utils/country_codes.dart';
import '../../utils/city_suggestions.dart';
import '../../utils/requetes.dart';
import '../../controllers/TypeAccountController.dart';
import '../termsAndPrivacy/TermsAndPrivacyPage.dart';

class UserRegistrationPage extends StatefulWidget {
  @override
  _UserRegistrationPageState createState() => _UserRegistrationPageState();
}

class _UserRegistrationPageState extends State<UserRegistrationPage> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _cityController = TextEditingController();

  // Focus nodes pour la navigation au clavier
  final _firstNameFocus = FocusNode();
  final _lastNameFocus = FocusNode();
  final _phoneFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _cityFocus = FocusNode();
  final _passwordFocus = FocusNode();

  bool _isLoading = false;
  bool _showPassword = false;
  String? _selectedAccountType;
  ServiceType? _selectedServiceType;
  AutovalidateMode _autoValidateMode = AutovalidateMode.disabled;
  bool _isServicesDropdownOpen = false;
  bool _isImmobilierDropdownOpen = false;

  // Suivi de la force du mot de passe en temps réel

  int _passwordStrength = 0;
  List<CityModel> _cities = [];
  
  // Liste de villes pour l'autocomplete (extraite dans un fichier utilitaire)
  static final List<String> _allCities = List<String>.from(citySuggestions);


  // États pour la gestion de la validation
  bool _firstNameTouched = false;
  bool _lastNameTouched = false;
  bool _phoneTouched = false;
  bool _emailTouched = false;
  bool _cityTouched = false;
  bool _passwordTouched = false;
  String? _selectedCountryName;

  // États pour le sélecteur de pays
  String _selectedCountryCode = '+243'; // RDC par défaut
  final Map<String, String> _countryFlags = Map<String, String>.from(countryFlags);
  final Map<String, String> _countryNames = Map<String, String>.from(countryNames);

  // Types de compte dynamiques
  List<dynamic> _typeAccounts = [];

  final Color primaryColor = Color(0xFF1976D2);
  final Color accentColor = Color(0xFF64B5F6);
  final Color darkBlue = Color(0xFF0D47A1);
  final Color lightBlue = Color(0xFFE3F2FD);
  final Color textColor = Color(0xFF1A237E);
  final Color secondaryTextColor = Color(0xFF5C6BC0);
  final Color errorColor = Color(0xFFD63031);
  final Color successColor = Color(0xFF38B000);

  bool _acceptConditions = false;

  // Types de compte
  final Map<String, Map<String, dynamic>> _accountTypes = {
    'Locataire': {
      'value': 4,
      'icon': Icons.home_work_rounded,
      'description': 'Je cherche un logement à louer',
      'color': Color(0xFF1976D2),
      'category': 'immobilier',
    },
    'Bailleur': {
      'value': 3,
      'icon': Icons.house_siding_rounded,
      'description': 'Je propose un logement en location',
      'color': Color(0xFF1976D2),
      'category': 'immobilier',
    },
    'Commissionnaire': {
      'value': 2,
      'icon': Icons.handshake_rounded,
      'description': 'Je facilite les transactions immobilières',
      'color': Color(0xFF1976D2),
      'category': 'immobilier',
    },
    'Majordome': {
      'value': 5,
      'icon': Icons.cleaning_services_rounded,
      'description': 'Service de majordome',
      'color': Color(0xFF1976D2),
      'category': 'services',
    },
    'Plombier': {
      'value': 6,
      'icon': Icons.plumbing_rounded,
      'description': 'Service de plomberie',
      'color': Color(0xFF1976D2),
      'category': 'services',
    },
    'Électricien': {
      'value': 7,
      'icon': Icons.electrical_services_rounded,
      'description': 'Service d\'électricité',
      'color': Color(0xFF1976D2),
      'category': 'services',
    },
    'Salubrité': {
      'value': 8,
      'icon': Icons.cleaning_services_rounded,
      'description': 'Service de salubrité',
      'color': Color(0xFF1976D2),
      'category': 'services',
    },
    'Peintre': {
      'value': 9,
      'icon': Icons.format_paint_rounded,
      'description': 'Service de peinture',
      'color': Color(0xFF1976D2),
      'category': 'services',
    },
    'Carreleur': {
      'value': 10,
      'icon': Icons.square_foot_rounded,
      'description': 'Service de carrelage',
      'color': Color(0xFF1976D2),
      'category': 'services',
    },
    'Menuisier': {
      'value': 11,
      'icon': Icons.carpenter_rounded,
      'description': 'Service de menuiserie',
      'color': Color(0xFF1976D2),
      'category': 'services',
    },
    'Frigoriste': {
      'value': 12,
      'icon': Icons.ac_unit_rounded,
      'description': 'Service de frigoristerie',
      'color': Color(0xFF1976D2),
      'category': 'services',
    },
    'Ajusteur': {
      'value': 13,
      'icon': Icons.build_rounded,
      'description': 'Service d\'ajustage',
      'color': Color(0xFF1976D2),
      'category': 'services',
    },
    'Architecte': {
      'value': 14,
      'icon': Icons.architecture_rounded,
      'description': 'Service d\'architecture',
      'color': Color(0xFF1976D2),
      'category': 'services',
    },
    'Chauffeur': {
      'value': 15,
      'icon': Icons.drive_eta_rounded,
      'description': 'Service de conduite',
      'color': Color(0xFF1976D2),
      'category': 'services',
    },
    'Déménagement': {
      'value': 16,
      'icon': Icons.local_shipping_rounded,
      'description': 'Service de déménagement',
      'color': Color(0xFF1976D2),
      'category': 'services',
    },
  };

  Future<void> _loadCities() async {
    // Utilisation uniquement des données locales pour les suggestions.
    if (mounted) {
      setState(() {
        _cities = _allCities.map((name) => CityModel(name: name)).toList();
      });
    }
  }



  @override
  void initState() {
    super.initState();

    // Charger les types de compte depuis l'API via le TypeAccountController
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final typeCtrl = context.read<TypeAccountController>();
      await typeCtrl.fetchTypeAccounts();
      if (mounted) {
        setState(() {
          _typeAccounts = typeCtrl.typeAccounts;
        });
      }
    });

    _passwordController.addListener(_updatePasswordStrength);
    _setupFocusNavigation();

    _selectedCountryName = _getCountryNameFromCode(_selectedCountryCode);
    _passwordController.addListener(_updatePasswordStrength);
    _setupFocusNavigation();


    // Ajouter des listeners pour tous les contrôleurs
    _firstNameController.addListener(_updateButtonState);
    _lastNameController.addListener(_updateButtonState);
    _phoneController.addListener(_updateButtonState);
    _cityController.addListener(_updateButtonState);
    _passwordController.addListener(_updateButtonState);
    
    // Charger les villes après le premier frame pour éviter setState() pendant build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCities();
    });
  }


  void _setupFocusNavigation() {
    _firstNameFocus.addListener(() => _onFieldFocusChange(_firstNameFocus, () => _firstNameTouched = true));
    _lastNameFocus.addListener(() => _onFieldFocusChange(_lastNameFocus, () => _lastNameTouched = true));
    _phoneFocus.addListener(() => _onFieldFocusChange(_phoneFocus, () => _phoneTouched = true));
    _emailFocus.addListener(() => _onFieldFocusChange(_emailFocus, () => _emailTouched = true));
    _cityFocus.addListener(() => _onFieldFocusChange(_cityFocus, () => _cityTouched = true));
    _passwordFocus.addListener(() => _onFieldFocusChange(_passwordFocus, () => _passwordTouched = true));
  }

  void _onFieldFocusChange(FocusNode focusNode, VoidCallback onLostFocus) {
    if (!focusNode.hasFocus) {
      onLostFocus();
      if (mounted) setState(() {});
    }
  }

  // Méthode pour mettre à jour l'état du bouton
  void _updateButtonState() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _passwordController.removeListener(_updatePasswordStrength);
    _firstNameController.removeListener(_updateButtonState);
    _lastNameController.removeListener(_updateButtonState);
    _phoneController.removeListener(_updateButtonState);
    _cityController.removeListener(_updateButtonState);
    _passwordController.removeListener(_updateButtonState);

    _firstNameFocus.dispose();
    _lastNameFocus.dispose();
    _phoneFocus.dispose();
    _emailFocus.dispose();
    _cityFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  void _updatePasswordStrength() {
    final password = _passwordController.text;
    int strength = 0;

    if (password.length >= 6) strength++;
    if (password.length >= 8) strength++;
    if (RegExp(r'[A-Z]').hasMatch(password)) strength++;
    if (RegExp(r'[a-z]').hasMatch(password)) strength++;
    if (RegExp(r'[0-9]').hasMatch(password)) strength++;
    if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) strength++;

    if (mounted && _passwordStrength != strength) {
      setState(() {
        _passwordStrength = strength;
      });
    }
  }

  void _goToNextField(FocusNode currentFocus, FocusNode nextFocus) {
    currentFocus.unfocus();
    FocusScope.of(context).requestFocus(nextFocus);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Arrière-plan identique au login
          _buildBackground(),

          // Contenu principal
          SafeArea(
            child: SingleChildScrollView(
              physics: BouncingScrollPhysics(),
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 24),
              child: Column(
                children: [
                  SizedBox(height: 20),
                  _buildLogo(),
                  SizedBox(height: 30),
                  _buildAuthCard(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getCountryNameFromCode(String countryCode) {
    return _countryNames[countryCode] ?? _countryNames[_selectedCountryCode] ?? 'RDC';
  }

  Widget _buildCountryCodeDropdown() {
    return Container(
      width: 140, // Légèrement plus large pour accommoder le nom
      padding: EdgeInsets.only(left: 8, right: 4),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedCountryCode,
          isExpanded: true,
          icon: Icon(Icons.arrow_drop_down_rounded, color: primaryColor, size: 20),
          style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w500),
          items: _countryFlags.entries.map((entry) {
            final countryName = _getCountryNameFromCode(entry.key);
            return DropdownMenuItem(
              value: entry.key,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(entry.value, style: TextStyle(fontSize: 16)), // Drapeau
                  SizedBox(width: 8),
                  Text(entry.key, style: TextStyle(fontSize: 13)), // Indicatif
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      countryName,
                      style: TextStyle(fontSize: 12, color: secondaryTextColor),
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
                _selectedCountryCode = newValue;
                _selectedCountryName = _getCountryNameFromCode(newValue);
              });
            }
          },
        ),
      ),
    );
  }


  Widget _buildBackground() {
    return Stack(
      children: [
        // Grand cercle en haut à droite
        Positioned(
          top: -100,
          right: -100,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  primaryColor.withOpacity(0.08),
                  primaryColor.withOpacity(0.02),
                ],
              ),
            ),
          ).animate().fadeIn(delay: 100.ms),
        ),

        // Petit cercle en haut à gauche
        Positioned(
          top: 50,
          left: -50,
          child: Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  accentColor.withOpacity(0.06),
                  accentColor.withOpacity(0.02),
                ],
              ),
            ),
          ).animate().fadeIn(delay: 200.ms),
        ),

        // Cercle en bas au centre
        Positioned(
          bottom: -150,
          left: MediaQuery.of(context).size.width / 2 - 150,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  darkBlue.withOpacity(0.05),
                  darkBlue.withOpacity(0.01),
                ],
              ),
            ),
          ).animate().fadeIn(delay: 300.ms),
        ),
      ],
    );
  }

  Widget _buildLogo() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Logo container
        Stack(
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [accentColor, primaryColor],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withOpacity(0.3),
                    blurRadius: 25,
                    spreadRadius: 2,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      image: DecorationImage(
                        image: AssetImage('assets/images/icon.png'),
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ).animate()
            .scale(delay: 500.ms, duration: 800.ms, curve: Curves.elasticOut)
            .shake(delay: 1500.ms, duration: 1000.ms),

        SizedBox(width: 8),
        Container(
          height: 40,
          width: 1,
          color: Colors.grey.withOpacity(0.3),
          margin: EdgeInsets.symmetric(horizontal: 8),
        ).animate().fadeIn(delay: 650.ms),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  colors: [primaryColor, darkBlue],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ).createShader(bounds),
                child: Text(
                  'CasaNayo',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Rejoignez notre communauté',
                style: TextStyle(
                  color: secondaryTextColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ).animate().slideX(
            begin: 0.3,
            duration: 600.ms,
            delay: 700.ms,
            curve: Curves.easeOutCubic,
          ),
        ),
      ],
    );
  }

  Widget _buildAuthCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 30,
            spreadRadius: 5,
            offset: Offset(0, 10),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100, width: 1),
      ),
      child: Column(
        children: [
          Text(
            'Inscription',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ).animate().fadeIn(delay: 1100.ms),

          SizedBox(height: 10),

          Text(
            'Créez votre compte en quelques étapes',
            style: TextStyle(
              color: secondaryTextColor,
              fontSize: 14,
            ),
          ).animate().fadeIn(delay: 1200.ms),

          SizedBox(height: 30),

          _buildAuthForm(),
          SizedBox(height: 25),
          _buildPrivacyText(), // CONDITIONS PLACÉES ICI, AVANT LE BOUTON
          SizedBox(height: 25),
          _buildAuthButton(),
          SizedBox(height: 20),
          _buildLoginLink(),
        ],
      ),
    ).animate().slideY(
      begin: 0.5,
      duration: 600.ms,
      delay: 1000.ms,
      curve: Curves.easeOutCubic,
    );
  }

  Widget _buildAuthForm() {
    return Form(
      key: _formKey,
      autovalidateMode: _autoValidateMode,
      child: Column(
        children: [
          _buildNameField(
            controller: _firstNameController,
            label: 'Prénom',
            hint: 'Jean',
            focusNode: _firstNameFocus,
            nextFocus: _lastNameFocus,
            isFirstField: true,
            isTouched: _firstNameTouched,
          ),
          SizedBox(height: 15),
          _buildNameField(
            controller: _lastNameController,
            label: 'Nom',
            hint: 'Baka',
            focusNode: _lastNameFocus,
            nextFocus: _phoneFocus,
            isTouched: _lastNameTouched,
          ),
          SizedBox(height: 15),
          // Téléphone
          _buildPhoneField(),
          SizedBox(height: 15),
          // Ville
          _buildCityField(),
          SizedBox(height: 15),
          // Email
          _buildEmailField(),
          SizedBox(height: 15),
          // Type de compte
          _buildAccountTypeField(),
          SizedBox(height: 20),
          // Mot de passe
          _buildPasswordField(),
          SizedBox(height: 8),
          // Indicateur de force du mot de passe en temps réel
          _buildPasswordStrengthIndicator(),
        ],
      ),
    );
  }

  Widget _buildNameField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required FocusNode focusNode,
    FocusNode? nextFocus,
    bool isFirstField = false,
    required bool isTouched,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        autovalidateMode: AutovalidateMode.disabled,
        style: TextStyle(color: textColor, fontSize: 16),
        textInputAction: nextFocus != null ? TextInputAction.next : TextInputAction.done,
        onFieldSubmitted: nextFocus != null ? (_) => _goToNextField(focusNode, nextFocus!) : null,
        onChanged: (_) {
          if (isTouched) _forceRevalidation();
        },
        onEditingComplete: () {
          setState(() {
            switch (label) {
              case 'Prénom':
                _firstNameTouched = true;
                break;
              case 'Nom':
                _lastNameTouched = true;
                break;
            }
          });
        },
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: secondaryTextColor),
          prefixIcon: Container(
            padding: EdgeInsets.all(12),
            child: Icon(Icons.person_rounded, color: primaryColor),
          ),
          suffixIcon: nextFocus != null ? _buildNextButton(() => _goToNextField(focusNode, nextFocus!)) : null,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: primaryColor, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.red),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.red, width: 2),
          ),
          filled: true,
          fillColor: lightBlue.withOpacity(0.3),
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey.shade500),
          errorText: isTouched ? _validateName(controller.text, label.toLowerCase()) : null,
        ),
        validator: null, // Désactivé car on utilise errorText
      ),
    ).animate().slideX(
      begin: -0.3,
      duration: 500.ms,
      delay: 1300.ms,
      curve: Curves.easeOut,
    );
  }

  Widget _buildPhoneField() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: TextFormField(
        controller: _phoneController,
        focusNode: _phoneFocus,
        autovalidateMode: AutovalidateMode.disabled,
        style: TextStyle(color: textColor, fontSize: 16),
        keyboardType: TextInputType.phone,
        textInputAction: TextInputAction.next, // Garder la navigation clavier
        onFieldSubmitted: (_) => _goToNextField(_phoneFocus, _emailFocus),
        onChanged: (String value) {
          // Gérer automatiquement le 0 initial
          String cleaned = value.replaceAll(RegExp(r'[^\d]'), '');
          if (cleaned.startsWith('0') && cleaned.length > 1) {
            // Supprimer le 0 et garder les chiffres suivants
            cleaned = cleaned.substring(1);
            _phoneController.value = TextEditingValue(
              text: cleaned,
              selection: TextSelection.collapsed(offset: cleaned.length),
            );
          }
          if (_phoneTouched) _forceRevalidation();
        },
        onEditingComplete: () {
          setState(() {
            _phoneTouched = true;
          });
        },
        decoration: InputDecoration(
          labelText: 'Téléphone*',
          labelStyle: TextStyle(color: secondaryTextColor),
          prefixIcon: _buildCountryCodeDropdown(),
          // SUPPRIMER le suffixIcon pour avoir plus d'espace
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: primaryColor, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.red),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.red, width: 2),
          ),
          filled: true,
          fillColor: lightBlue.withOpacity(0.3),
          hintText: '810000000',
          hintStyle: TextStyle(color: Colors.grey.shade500),
          errorText: _phoneTouched ? _validatePhone(_phoneController.text) : null,
        ),
        validator: null, // Désactivé car on utilise errorText
      ),
    ).animate().slideX(
      begin: 0.3,
      duration: 500.ms,
      delay: 1400.ms,
      curve: Curves.easeOut,
    );
  }

  // Widget _buildCountryCodeDropdown() {
  //   return Container(
  //     width: 120,
  //     padding: EdgeInsets.only(left: 8, right: 4),
  //     child: DropdownButtonHideUnderline(
  //       child: DropdownButton<String>(
  //         value: _selectedCountryCode,
  //         isExpanded: true,
  //         icon: Icon(Icons.arrow_drop_down_rounded, color: primaryColor, size: 20),
  //         style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w500),
  //         items: _countryFlags.entries.map((entry) {
  //           return DropdownMenuItem(
  //             value: entry.key,
  //             child: Row(
  //               mainAxisSize: MainAxisSize.min,
  //               children: [
  //                 Text(entry.value, style: TextStyle(fontSize: 16)),
  //                 SizedBox(width: 6),
  //                 Text(entry.key, style: TextStyle(fontSize: 13)),
  //               ],
  //             ),
  //           );
  //         }).toList(),
  //         onChanged: (String? newValue) {
  //           if (newValue != null) {
  //             setState(() {
  //               _selectedCountryCode = newValue;
  //             });
  //           }
  //         },
  //       ),
  //     ),
  //   );
  // }

  Widget _buildEmailField() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: TextFormField(
        controller: _emailController,
        focusNode: _emailFocus,
        autovalidateMode: AutovalidateMode.disabled,
        style: TextStyle(color: textColor, fontSize: 16),
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.next,
        onFieldSubmitted: (_) => _goToNextField(_emailFocus, _cityFocus),
        onChanged: (_) {
          if (_emailTouched) _forceRevalidation();
        },
        onEditingComplete: () {
          setState(() {
            _emailTouched = true;
          });
        },
        decoration: InputDecoration(
          labelText: 'Email (optionnel)',
          labelStyle: TextStyle(color: secondaryTextColor),
          prefixIcon: Container(
            padding: EdgeInsets.all(12),
            child: Icon(Icons.email_rounded, color: primaryColor),
          ),
          suffixIcon: _buildNextButton(() => _goToNextField(_emailFocus, _cityFocus)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: primaryColor, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.red),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.red, width: 2),
          ),
          filled: true,
          fillColor: lightBlue.withOpacity(0.3),
          hintText: 'exemple@email.com',
          hintStyle: TextStyle(color: Colors.grey.shade500),
          errorText: _emailTouched ? _validateEmail(_emailController.text) : null,
        ),
        validator: null, // Désactivé car on utilise errorText
      ),
    ).animate().slideX(
      begin: -0.3,
      duration: 500.ms,
      delay: 1500.ms,
      curve: Curves.easeOut,
    );
  }

  Widget _buildCityField() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Autocomplete<CityModel>(
        optionsBuilder: (TextEditingValue textEditingValue) {
          if (textEditingValue.text.isEmpty) {
            return const Iterable<CityModel>.empty();
          }
          final query = textEditingValue.text.toLowerCase();
          final baseCities = _allCities.map((name) => CityModel(name: name)).toList();
          return baseCities.where((CityModel city) {
            final cityName = city.name?.toLowerCase() ?? '';
            return cityName.contains(query);
          }).take(10); // Limiter à 10 résultats comme Google
        },
        displayStringForOption: (CityModel city) => city.name ?? '',
        onSelected: (CityModel city) {
          setState(() {
            _cityController.text = city.name ?? '';
            _cityTouched = true;
            FocusScope.of(context).requestFocus(_emailFocus);
          });
        },
        fieldViewBuilder: (
          BuildContext context,
          TextEditingController textEditingController,
          FocusNode focusNode,
          VoidCallback onFieldSubmitted,
        ) {
          // Synchroniser avec _cityController après le build
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (textEditingController.text != _cityController.text && mounted) {
              textEditingController.text = _cityController.text;
            }
          });
          
          return TextFormField(
            controller: textEditingController,
            focusNode: focusNode,
            textInputAction: TextInputAction.next,
            onFieldSubmitted: (String value) {
              onFieldSubmitted();
              _goToNextField(focusNode, _emailFocus);
            },
            onChanged: (String value) {
              setState(() {
                _cityController.text = value;
                _cityTouched = true;
              });
            },
            decoration: InputDecoration(
              labelText: 'Ville*',
              labelStyle: TextStyle(color: secondaryTextColor),
              prefixIcon: Container(
                padding: EdgeInsets.all(12),
                child: Icon(Icons.search_rounded, color: primaryColor),
              ),
              suffixIcon: _cityController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear_rounded, color: Colors.grey.shade400),
                      onPressed: () {
                        setState(() {
                          _cityController.clear();
                          textEditingController.clear();
                        });
                      },
                    )
                  : null,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: primaryColor, width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.red),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.red, width: 2),
              ),
              filled: true,
              fillColor: lightBlue.withOpacity(0.3),
              hintText: 'Rechercher une ville...',
              hintStyle: TextStyle(color: Colors.grey.shade500),
              errorText: _cityTouched ? _validateCity(_cityController.text) : null,
            ),
            validator: null,
          );
        },
        optionsViewBuilder: (BuildContext context, AutocompleteOnSelected<CityModel> onSelected, Iterable<CityModel> options) {
          if (options.isEmpty) {
            return SizedBox.shrink();
          }

          return Align(
            alignment: Alignment.topLeft,
            child: Material(
              elevation: 8.0,
              borderRadius: BorderRadius.circular(12),
              shadowColor: Colors.black.withOpacity(0.2),
              child: Container(
                constraints: BoxConstraints(maxHeight: 300),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.white,
                ),
                child: ListView.separated(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  shrinkWrap: true,
                  itemCount: options.length > 8 ? 8 : options.length,
                  separatorBuilder: (context, index) => Divider(height: 1, thickness: 1),
                  itemBuilder: (BuildContext context, int index) {
                    final CityModel city = options.elementAt(index);
                    final cityName = city.name ?? '';
                    
                    return InkWell(
                      onTap: () => onSelected(city),
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.location_city_rounded,
                                size: 20,
                                color: primaryColor,
                              ),
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    cityName,
                                    style: TextStyle(
                                      color: textColor,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  if (city.country?.name != null && city.country!.name!.isNotEmpty)
                                  if (city.country?.name != null && city.country!.name!.isNotEmpty)
                                    Padding(
                                      padding: EdgeInsets.only(top: 2),
                                      child: Text(
                                        city.country!.name!,
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 16,
                              color: Colors.grey.shade400,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    ).animate().slideX(
      begin: 0.3,
      duration: 500.ms,
      delay: 1550.ms,
      curve: Curves.easeOut,
    );
  }

  Widget _buildNextButton(VoidCallback onPressed) {
    return Container(
      margin: EdgeInsets.all(8),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: primaryColor.withOpacity(0.1),
      ),
      child: IconButton(
        icon: Icon(Icons.arrow_forward_rounded, size: 18, color: primaryColor),
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        constraints: BoxConstraints(minWidth: 36, minHeight: 36),
      ),
    );
  }

  Widget _buildAccountTypeField() {
    // Séparer les types par catégorie
    final immobilierTypes = _accountTypes.entries.where((e) => e.value['category'] == 'immobilier').toList();
    final servicesTypes = _accountTypes.entries.where((e) => e.value['category'] == 'services').toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Type de compte*',
          style: TextStyle(
            color: secondaryTextColor,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 12),
        
        // Section Immobilier avec dropdown
        if (immobilierTypes.isNotEmpty) ...[
          _buildSectionHeader('Immobilier', Icons.home_rounded),
          SizedBox(height: 8),
          _buildImmobilierDropdown(immobilierTypes),
          SizedBox(height: 16),
        ],
        
        // Section Services avec dropdown
        if (servicesTypes.isNotEmpty) ...[
          _buildSectionHeader('Services', Icons.business_center_rounded),
          SizedBox(height: 8),
          _buildServicesDropdown(servicesTypes),
        ],
        
        // Message d'erreur de validation
        if (_autoValidateMode == AutovalidateMode.always && _selectedAccountType == null)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 8),
            child: Row(
              children: [
                Icon(Icons.error_outline_rounded, color: errorColor, size: 16),
                SizedBox(width: 6),
                Text(
                  'Veuillez sélectionner un type de compte',
                  style: TextStyle(
                    color: errorColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
      ],
    ).animate().slideY(
      begin: 0.2,
      duration: 500.ms,
      delay: 1600.ms,
      curve: Curves.easeOut,
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: primaryColor),
        SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: textColor,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildImmobilierDropdown(List<MapEntry<String, Map<String, dynamic>>> immobilierTypes) {
    // Trouver le type immobilier sélectionné
    final selectedImmobilier = immobilierTypes.firstWhere(
      (entry) => _selectedAccountType == entry.key,
      orElse: () => immobilierTypes.first,
    );
    final isImmobilierSelected = immobilierTypes.any((entry) => _selectedAccountType == entry.key);

    return Column(
      children: [
        // Bouton dropdown avec le design actuel
        InkWell(
          onTap: () {
            setState(() {
              _isImmobilierDropdownOpen = !_isImmobilierDropdownOpen;
            });
          },
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: Duration(milliseconds: 300),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: isImmobilierSelected
                  ? LinearGradient(
                      colors: [
                        Color(0xFF1976D2).withOpacity(0.15),
                        Color(0xFF1976D2).withOpacity(0.05),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              border: Border.all(
                color: isImmobilierSelected ? Color(0xFF1976D2) : Colors.grey.shade300,
                width: isImmobilierSelected ? 2 : 1.5,
              ),
              boxShadow: isImmobilierSelected
                  ? [
                      BoxShadow(
                        color: Color(0xFF1976D2).withOpacity(0.2),
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Container(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: Duration(milliseconds: 300),
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isImmobilierSelected
                          ? Color(0xFF1976D2)
                          : lightBlue.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isImmobilierSelected
                          ? (selectedImmobilier.value['icon'] as IconData)
                          : Icons.home_rounded,
                      color: isImmobilierSelected ? Colors.white : Color(0xFF1976D2),
                      size: 20,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isImmobilierSelected
                              ? selectedImmobilier.key
                              : 'Sélectionner un type',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isImmobilierSelected ? Color(0xFF1976D2) : textColor,
                            fontSize: 15,
                          ),
                        ),
                        if (isImmobilierSelected) ...[
                          SizedBox(height: 2),
                          Text(
                            selectedImmobilier.value['description'] as String,
                            style: TextStyle(
                              color: Color(0xFF1976D2).withOpacity(0.8),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: _isImmobilierDropdownOpen ? 0.5 : 0,
                    duration: Duration(milliseconds: 300),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: isImmobilierSelected ? Color(0xFF1976D2) : Colors.grey.shade600,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        
        // Liste déroulante des types immobiliers
        if (_isImmobilierDropdownOpen) ...[
          SizedBox(height: 8),
          Container(
            constraints: BoxConstraints(
              maxHeight: 300,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200, width: 1),
              color: Colors.white,
            ),
            child: Column(
              children: immobilierTypes.asMap().entries.map((mapEntry) {
                final index = mapEntry.key;
                final entry = mapEntry.value;
                final isSelected = _selectedAccountType == entry.key;
                final isLast = index == immobilierTypes.length - 1;
                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedAccountType = entry.key;
                      _isImmobilierDropdownOpen = false;
                    });
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Color(0xFF1976D2).withOpacity(0.1)
                          : Colors.transparent,
                      border: isLast ? null : Border(
                        bottom: BorderSide(
                          color: Colors.grey.shade200,
                          width: 0.5,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Color(0xFF1976D2)
                                : lightBlue.withOpacity(0.5),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            entry.value['icon'] as IconData,
                            color: isSelected ? Colors.white : Color(0xFF1976D2),
                            size: 18,
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                entry.key,
                                style: TextStyle(
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? Color(0xFF1976D2)
                                      : textColor,
                                  fontSize: 14,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                entry.value['description'] as String,
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          Icon(
                            Icons.check_circle_rounded,
                            color: Color(0xFF1976D2),
                            size: 20,
                          ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildServicesDropdown(List<MapEntry<String, Map<String, dynamic>>> servicesTypes) {
    // Trouver le type de service sélectionné
    final selectedService = servicesTypes.firstWhere(
      (entry) => _selectedAccountType == entry.key,
      orElse: () => servicesTypes.first,
    );
    final isServiceSelected = servicesTypes.any((entry) => _selectedAccountType == entry.key);

    return Column(
      children: [
        // Bouton dropdown avec le design actuel
        InkWell(
          onTap: () {
            setState(() {
              _isServicesDropdownOpen = !_isServicesDropdownOpen;
            });
          },
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: Duration(milliseconds: 300),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: isServiceSelected
                  ? LinearGradient(
                      colors: [
                        Color(0xFF1976D2).withOpacity(0.15),
                        Color(0xFF1976D2).withOpacity(0.05),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              border: Border.all(
                color: isServiceSelected ? Color(0xFF1976D2) : Colors.grey.shade300,
                width: isServiceSelected ? 2 : 1.5,
              ),
              boxShadow: isServiceSelected
                  ? [
                      BoxShadow(
                        color: Color(0xFF1976D2).withOpacity(0.2),
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Container(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: Duration(milliseconds: 300),
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isServiceSelected
                          ? Color(0xFF1976D2)
                          : lightBlue.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isServiceSelected
                          ? (selectedService.value['icon'] as IconData)
                          : Icons.business_center_rounded,
                      color: isServiceSelected ? Colors.white : Color(0xFF1976D2),
                      size: 20,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isServiceSelected
                              ? selectedService.key
                              : 'Sélectionner un service',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isServiceSelected ? Color(0xFF1976D2) : textColor,
                            fontSize: 15,
                          ),
                        ),
                        if (isServiceSelected) ...[
                          SizedBox(height: 2),
                          Text(
                            selectedService.value['description'] as String,
                            style: TextStyle(
                              color: Color(0xFF1976D2).withOpacity(0.8),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: _isServicesDropdownOpen ? 0.5 : 0,
                    duration: Duration(milliseconds: 300),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: isServiceSelected ? Color(0xFF1976D2) : Colors.grey.shade600,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        
        // Liste déroulante des services
        if (_isServicesDropdownOpen) ...[
          SizedBox(height: 8),
          Container(
            constraints: BoxConstraints(
              maxHeight: 400,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200, width: 1),
              color: Colors.white,
            ),
            child: SingleChildScrollView(
              physics: BouncingScrollPhysics(),
              child: Column(
                children: servicesTypes.asMap().entries.map((mapEntry) {
                  final index = mapEntry.key;
                  final entry = mapEntry.value;
                  final isSelected = _selectedAccountType == entry.key;
                  final isLast = index == servicesTypes.length - 1;
                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedAccountType = entry.key;
                        _isServicesDropdownOpen = false;
                      });
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Color(0xFF1976D2).withOpacity(0.1)
                            : Colors.transparent,
                        border: isLast ? null : Border(
                          bottom: BorderSide(
                            color: Colors.grey.shade200,
                            width: 0.5,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Color(0xFF1976D2)
                                  : lightBlue.withOpacity(0.5),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              entry.value['icon'] as IconData,
                              color: isSelected ? Colors.white : Color(0xFF1976D2),
                              size: 18,
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  entry.key,
                                  style: TextStyle(
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? Color(0xFF1976D2)
                                        : textColor,
                                    fontSize: 14,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  entry.value['description'] as String,
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            Icon(
                              Icons.check_circle_rounded,
                              color: Color(0xFF1976D2),
                              size: 20,
                            ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildServiceTypeSelection() {
    final allServiceTypes = [
      ServiceType.majordhomme,
      ServiceType.demenagement,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Color(0xFFE91E63).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Color(0xFFE91E63).withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 20, color: Color(0xFFE91E63)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Sélectionnez le type de service que vous proposez',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 16),
        Row(
          children: allServiceTypes.map((serviceType) {
            final isSelected = _selectedServiceType == serviceType;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: allServiceTypes.indexOf(serviceType) == 0 ? 8 : 0),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedServiceType = serviceType;
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? Color(0xFFE91E63) : Colors.grey.shade300,
                        width: isSelected ? 2 : 1.5,
                      ),
                      color: isSelected ? Color(0xFFE91E63).withOpacity(0.1) : Colors.transparent,
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          serviceType.icon,
                          size: 24,
                          color: isSelected ? Color(0xFFE91E63) : Colors.grey.shade600,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            serviceType.displayName,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                              color: isSelected ? Color(0xFFE91E63) : textColor,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildAccountTypeOption(String type, Map<String, dynamic> config) {
    final isSelected = _selectedAccountType == type;
    final Color color = config['color'] as Color;

    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: isSelected
            ? LinearGradient(
          colors: [color.withOpacity(0.15), color.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        )
            : null,
        border: Border.all(
          color: isSelected ? color : Colors.grey.shade300,
          width: isSelected ? 2 : 1.5,
        ),
        boxShadow: [
          if (isSelected)
            BoxShadow(
              color: color.withOpacity(0.2),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            setState(() {
              _selectedAccountType = type;
              // Fermer les dropdowns si un type est sélectionné
              if (_accountTypes[type]!['category'] == 'immobilier') {
                _isServicesDropdownOpen = false;
              } else if (_accountTypes[type]!['category'] == 'services') {
                _isImmobilierDropdownOpen = false;
              }
            });
          },
          child: Container(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: Duration(milliseconds: 300),
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isSelected ? color : lightBlue.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    config['icon'] as IconData,
                    color: isSelected ? Colors.white : color,
                    size: 20,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        type,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isSelected ? color : textColor,
                          fontSize: 15,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        config['description'] as String,
                        style: TextStyle(
                          color: isSelected ? color.withOpacity(0.8) : secondaryTextColor,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedContainer(
                  duration: Duration(milliseconds: 300),
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? color : Colors.grey.shade400,
                      width: 2,
                    ),
                    color: isSelected ? color : Colors.transparent,
                  ),
                  child: isSelected
                      ? Icon(Icons.check_rounded, color: Colors.white, size: 12)
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordField() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: TextFormField(
        controller: _passwordController,
        focusNode: _passwordFocus,
        style: TextStyle(color: textColor, fontSize: 16),
        obscureText: !_showPassword,
        autovalidateMode: AutovalidateMode.disabled,
        textInputAction: TextInputAction.go, // ← CHANGER EN "go"
        onFieldSubmitted: (_) => _triggerRegistrationIfValid(), // ← AJOUTER CETTE LIGNE
        onChanged: (_) {
          if (_passwordTouched) _forceRevalidation();
        },
        onEditingComplete: () {
          setState(() {
            _passwordTouched = true;
          });
          _triggerRegistrationIfValid(); // ← AJOUTER CETTE LIGNE
        },
        decoration: InputDecoration(
          labelText: 'Mot de passe*',
          labelStyle: TextStyle(color: secondaryTextColor),
          prefixIcon: Container(
            padding: EdgeInsets.all(12),
            child: Icon(Icons.lock_rounded, color: primaryColor),
          ),
          suffixIcon: Container(
            padding: EdgeInsets.all(8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_passwordController.text.isNotEmpty)
                  _buildPasswordVisibilityButton(),
              ],
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: primaryColor, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.red),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.red, width: 2),
          ),
          filled: true,
          fillColor: lightBlue.withOpacity(0.3),
          errorText: _passwordTouched ? _validatePassword(_passwordController.text) : null,
        ),
        validator: null,
      ),
    ).animate().slideX(
      begin: 0.3,
      duration: 500.ms,
      delay: 1700.ms,
      curve: Curves.easeOut,
    );
  }

  Widget _buildDoneButton() {
    return Container(
      margin: EdgeInsets.only(left: 4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: primaryColor.withOpacity(0.1),
      ),
      child: IconButton(
        icon: Icon(Icons.done_rounded, size: 18, color: primaryColor),
        onPressed: () {
          _passwordFocus.unfocus();
          _triggerRegistrationIfValid();
        },
        padding: EdgeInsets.zero,
        constraints: BoxConstraints(minWidth: 36, minHeight: 36),
      ),
    );
  }

  void _triggerRegistrationIfValid() {
    // Marquer tous les champs comme touchés
    setState(() {
      _firstNameTouched = true;
      _lastNameTouched = true;
      _phoneTouched = true;
      _emailTouched = true;
      _cityTouched = true;
      _passwordTouched = true;
      _autoValidateMode = AutovalidateMode.always;
    });

    // Vérifier si le formulaire est valide
    final hasRequiredFields = _firstNameController.text.isNotEmpty &&
        _lastNameController.text.isNotEmpty &&
        _phoneController.text.isNotEmpty &&
        _cityController.text.isNotEmpty &&
        _passwordController.text.isNotEmpty &&
        _selectedAccountType != null;

    final isFirstNameValid = _validateName(_firstNameController.text, 'prénom') == null;
    final isLastNameValid = _validateName(_lastNameController.text, 'nom') == null;
    final isPhoneValid = _validatePhone(_phoneController.text) == null;
    final isEmailValid = _emailController.text.isEmpty || _validateEmail(_emailController.text) == null;
    final isCityValid = _validateCity(_cityController.text) == null;
    final isPasswordValid = _validatePassword(_passwordController.text) == null;

    final isFormValid = isFirstNameValid &&
        isLastNameValid &&
        isPhoneValid &&
        isEmailValid &&
        isCityValid &&
        isPasswordValid;

    final isButtonEnabled = hasRequiredFields && isFormValid && _acceptConditions && !_isLoading;

    if (isButtonEnabled) {
      _handleRegister();
    } else {
      // Afficher un message d'erreur si le formulaire n'est pas valide
      SnackbarForCasa.error(context, "Veuillez remplir tous les champs obligatoires correctement");
    }
  }

  Widget _buildPasswordVisibilityButton() {
    return IconButton(
      icon: Icon(
        _showPassword ? Icons.visibility_rounded : Icons.visibility_off_rounded,
        color: secondaryTextColor,
        size: 20,
      ),
      onPressed: () => setState(() => _showPassword = !_showPassword),
      padding: EdgeInsets.zero,
      constraints: BoxConstraints(minWidth: 36, minHeight: 36),
    );
  }

  // Widget _buildDoneButton() {
  //   return Container(
  //     margin: EdgeInsets.only(left: 4),
  //     decoration: BoxDecoration(
  //       shape: BoxShape.circle,
  //       color: primaryColor.withOpacity(0.1),
  //     ),
  //     child: IconButton(
  //       icon: Icon(Icons.done_rounded, size: 18, color: primaryColor),
  //       onPressed: () => _passwordFocus.unfocus(),
  //       padding: EdgeInsets.zero,
  //       constraints: BoxConstraints(minWidth: 36, minHeight: 36),
  //     ),
  //   );
  // }

  Widget _buildPasswordStrengthIndicator() {
    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 8),
          Row(
            children: List.generate(6, (index) {
              Color color;
              if (index < _passwordStrength) {
                if (_passwordStrength <= 2) color = errorColor;
                else if (_passwordStrength <= 4) color = Colors.orange;
                else color = successColor;
              } else {
                color = Colors.grey.shade300;
              }

              return Expanded(
                child: AnimatedContainer(
                  duration: Duration(milliseconds: 300),
                  height: 4,
                  margin: EdgeInsets.only(right: index < 5 ? 4 : 0),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
          SizedBox(height: 8),
          AnimatedSwitcher(
            duration: Duration(milliseconds: 300),
            child: Text(
              _getPasswordStrengthText(_passwordStrength),
              key: ValueKey(_passwordStrength),
              style: TextStyle(
                fontSize: 12,
                color: _getPasswordStrengthColor(_passwordStrength),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (_passwordController.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: _buildPasswordCriteria(),
              ),
            ),
        ],
      ),
    ).animate().fadeIn(delay: 1800.ms);
  }

  List<Widget> _buildPasswordCriteria() {
    final password = _passwordController.text;
    final criteria = [
      {'text': '6+ caractères', 'met': password.length >= 6},
      {'text': '8+ caractères', 'met': password.length >= 8},
      {'text': 'Majuscule', 'met': RegExp(r'[A-Z]').hasMatch(password)},
      {'text': 'Minuscule', 'met': RegExp(r'[a-z]').hasMatch(password)},
      {'text': 'Chiffre', 'met': RegExp(r'[0-9]').hasMatch(password)},
      {'text': 'Spécial', 'met': RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)},
    ];

    return criteria.map((criterion) {
      final isMet = criterion['met'] as bool;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isMet ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            color: isMet ? successColor : Colors.grey.shade400,
            size: 12,
          ),
          SizedBox(width: 4),
          Text(
            criterion['text'] as String,
            style: TextStyle(
              fontSize: 10,
              color: isMet ? successColor : Colors.grey.shade600,
              fontWeight: isMet ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      );
    }).toList();
  }

  String _getPasswordStrengthText(int strength) {
    if (strength == 0) return 'Commencez à taper votre mot de passe';
    if (strength <= 2) return 'Faible - Ajoutez des chiffres et caractères spéciaux';
    if (strength <= 4) return 'Moyen - Presque là !';
    return 'Fort - Excellent mot de passe !';
  }

  Color _getPasswordStrengthColor(int strength) {
    if (strength == 0) return secondaryTextColor;
    if (strength <= 2) return errorColor;
    if (strength <= 4) return Colors.orange;
    return successColor;
  }

  Widget _buildPrivacyText() {
    return Column(
      children: [
        // Case à cocher pour les conditions
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Case à cocher
              Transform.scale(
                scale: 1.2,
                child: Checkbox(
                  value: _acceptConditions,
                  onChanged: (bool? value) {
                    setState(() {
                      _acceptConditions = value ?? false;
                    });
                  },
                  activeColor: primaryColor,
                  checkColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              SizedBox(width: 8),
              // Texte des conditions
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: 'J\'accepte les ',
                            style: TextStyle(
                              color: secondaryTextColor,
                              fontSize: 14,
                            ),
                          ),
                          TextSpan(
                            text: 'conditions d\'utilisation',
                            style: TextStyle(
                              color: primaryColor,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => TermsAndPrivacyPage(initialTabIndex: 0),
                                  ),
                                );
                              },
                          ),
                          TextSpan(
                            text: ' et la ',
                            style: TextStyle(
                              color: secondaryTextColor,
                              fontSize: 14,
                            ),
                          ),
                          TextSpan(
                            text: 'politique de confidentialité',
                            style: TextStyle(
                              color: primaryColor,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => TermsAndPrivacyPage(initialTabIndex: 1),
                                  ),
                                );
                              },
                          ),
                          TextSpan(
                            text: ' de CasaNayo',
                            style: TextStyle(
                              color: secondaryTextColor,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Message d'erreur amélioré
                    if (_autoValidateMode == AutovalidateMode.always && !_acceptConditions)
                      Container(
                        margin: EdgeInsets.only(top: 6),
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: errorColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: errorColor.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline_rounded, color: errorColor, size: 14),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Vous devez accepter les conditions pour créer votre compte',
                                style: TextStyle(
                                  color: errorColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 15),
        // Texte informatif supplémentaire
        Wrap(
          spacing: 4,
          children: [
            Text(
              'En continuant, vous acceptez nos',
              style: TextStyle(
                color: secondaryTextColor,
                fontSize: 12,
              ),
            ),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TermsAndPrivacyPage(initialTabIndex: 0),
                    ),
                  );
                },
                child: Text(
                  'Conditions',
                  style: TextStyle(
                    color: primaryColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            Text(
              'et',
              style: TextStyle(
                color: secondaryTextColor,
                fontSize: 12,
              ),
            ),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TermsAndPrivacyPage(initialTabIndex: 1),
                    ),
                  );
                },
                child: Text(
                  'Politique de confidentialité',
                  style: TextStyle(
                    color: primaryColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    ).animate().fadeIn(delay: 1900.ms);
  }

  Widget _buildAuthButton() {
    final hasRequiredFields = _firstNameController.text.isNotEmpty &&
        _lastNameController.text.isNotEmpty &&
        _phoneController.text.isNotEmpty &&
        _cityController.text.isNotEmpty &&
        _passwordController.text.isNotEmpty &&
        _selectedAccountType != null;


    final shouldValidate = _autoValidateMode == AutovalidateMode.always ||
        (_firstNameTouched && _lastNameTouched && _phoneTouched && _cityTouched && _passwordTouched);

    final isFirstNameValid = shouldValidate ? _validateName(_firstNameController.text, 'prénom') == null : true;
    final isLastNameValid = shouldValidate ? _validateName(_lastNameController.text, 'nom') == null : true;
    final isPhoneValid = shouldValidate ? _validatePhone(_phoneController.text) == null : true;
    final isEmailValid = _emailController.text.isEmpty || _validateEmail(_emailController.text) == null;
    final isCityValid = shouldValidate ? _validateCity(_cityController.text) == null : true;
    final isPasswordValid = shouldValidate ? _validatePassword(_passwordController.text) == null : true;

    final isFormValid = isFirstNameValid &&
        isLastNameValid &&
        isPhoneValid &&
        isEmailValid &&
        isCityValid &&
        isPasswordValid;

    final isButtonEnabled = hasRequiredFields && isFormValid && _acceptConditions && !_isLoading;

    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          colors: isButtonEnabled
              ? [primaryColor, darkBlue]
              : [primaryColor.withOpacity(0.4), darkBlue.withOpacity(0.4)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: isButtonEnabled
            ? [
          BoxShadow(
            color: primaryColor.withOpacity(0.4),
            blurRadius: 15,
            spreadRadius: 2,
            offset: Offset(0, 5),
          ),
        ]
            : [
          BoxShadow(
            color: primaryColor.withOpacity(0.2),
            blurRadius: 8,
            spreadRadius: 1,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: isButtonEnabled ? _handleRegister : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
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
            valueColor: AlwaysStoppedAnimation(Colors.white),
          ),
        )
            : Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Créer mon compte',
              style: TextStyle(
                fontSize: 16,
                color: isButtonEnabled ? Colors.white : Colors.white.withOpacity(0.7),
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(width: 10),
            Icon(
              Icons.person_add_rounded,
              size: 20,
              color: isButtonEnabled ? Colors.white : Colors.white.withOpacity(0.7),
            ),
          ],
        ),
      ),
    ).animate().scale(
      delay: 2100.ms,
      duration: 500.ms,
    ).then().shake(
      delay: 100.ms,
      duration: 400.ms,
    );
  }

  Widget _buildLoginLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Déjà un compte ? ',
          style: TextStyle(
            color: secondaryTextColor,
            fontSize: 14,
          ),
        ),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: TextButton(
            onPressed: () {
              Navigator.pushNamed(context, Routes.loginRoute);
            },
            style: TextButton.styleFrom(
              foregroundColor: primaryColor,
              padding: EdgeInsets.zero,
            ),
            child: Text(
              'Se connecter',
              style: TextStyle(
                color: primaryColor,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    ).animate().fadeIn(delay: 2200.ms);
  }

  // Validators
  String? _validateName(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return 'Le $fieldName est obligatoire';
    }
    if (value.length < 2) {
      return 'Le $fieldName doit contenir au moins 2 caractères';
    }
    if (!RegExp(r'^[a-zA-ZÀ-ÿ\s\-]+$').hasMatch(value)) {
      return 'Le $fieldName ne doit contenir que des lettres';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Le numéro de téléphone est obligatoire';
    }

    // Nettoyer le numéro (garder seulement les chiffres)
    String cleanedPhone = value.replaceAll(RegExp(r'[^\d]'), '');

    // Validation pour les numéros congolais (RDC)
    if (_selectedCountryCode == '+243') {
      if (cleanedPhone.length != 9) {
        return 'Le numéro RDC doit avoir 9 chiffres';
      }
      if (!RegExp(r'^[89]').hasMatch(cleanedPhone)) {
        return 'Le numéro RDC doit commencer par 8 ou 9';
      }
    }

    // Validation générale pour les autres pays
    if (cleanedPhone.length < 8) {
      return 'Le numéro doit contenir au moins 8 chiffres';
    }

    return null;
  }

  String? _validateEmail(String? value) {
    if (value != null && value.isNotEmpty) {
      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
        return 'Adresse email invalide. Ex: exemple@mail.com';
      }
      if (value.length > 100) {
        return 'L\'email ne peut pas dépasser 100 caractères';
      }
    }
    return null;
  }

  String? _validateCity(String? value) {
    if (value == null || value.isEmpty) {
      return 'La ville est obligatoire';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Le mot de passe est obligatoire';
    }
    if (value.length < 6) {
      return 'Le mot de passe doit contenir au moins 6 caractères';
    }
    if (value.length > 50) {
      return 'Le mot de passe ne peut pas dépasser 50 caractères';
    }
    if (!RegExp(r'^(?=.*[a-zA-Z]).{6,}$').hasMatch(value)) {
      return 'Le mot de passe doit contenir au moins une lettre';
    }
    return null;
  }

  void _forceRevalidation() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _handleRegister() async {
    // Marquer tous les champs comme touchés pour afficher les erreurs
    setState(() {
      _firstNameTouched = true;
      _lastNameTouched = true;
      _phoneTouched = true;
      _emailTouched = true;
      _cityTouched = true;
      _passwordTouched = true;
      _autoValidateMode = AutovalidateMode.always;
    });

    await Future.delayed(Duration(milliseconds: 50));

    // Valider tous les champs
    final firstNameError = _validateName(_firstNameController.text, 'prénom');
    final lastNameError = _validateName(_lastNameController.text, 'nom');
    final phoneError = _validatePhone(_phoneController.text);
    final emailError = _validateEmail(_emailController.text);
    final cityError = _validateCity(_cityController.text);
    final passwordError = _validatePassword(_passwordController.text);

    if (firstNameError != null || lastNameError != null || phoneError != null ||
        emailError != null || cityError != null || passwordError != null) {
      SnackbarForCasa.error(context, "Veuillez corriger les erreurs ci-dessus");
      return;
    }

    if (_selectedAccountType == null) {
      SnackbarForCasa.error(context, "Veuillez sélectionner un type de compte");
      return;
    }

    // Plus besoin de vérifier le type de service car chaque service est maintenant un type de compte séparé

    if (!_acceptConditions) {
      SnackbarForCasa.error(context, "Veuillez accepter les conditions d'utilisation");
      return;
    }

    if (!mounted || _isLoading) return;
    setState(() => _isLoading = true);

    FocusScope.of(context).unfocus();

    final isConnected = await NetworkUtils.checkInternetConnectivity();
    if (!isConnected) {
      SnackbarForCasa.error(context, "Pas de connexion internet");
      setState(() => _isLoading = false);
      return;
    }

    try {
      // Déterminer l'ID de type de compte à partir de la source dynamique, sinon fallback statique.
      Map<String, dynamic> accountType;
      if (_typeAccounts.isNotEmpty) {
        final match = _typeAccounts.firstWhere(
          (e) => (e['name'] as String?)?.toLowerCase() == _selectedAccountType?.toLowerCase(),
          orElse: () => {},
        );
        if (match.isNotEmpty) {
          accountType = {
            'value': match['typeAccountId'],
            'name': match['name'],
          };
        } else {
          accountType = _accountTypes[_selectedAccountType]!;
        }
      } else {
        accountType = _accountTypes[_selectedAccountType]!;
      }

      // MODIFICATION ICI : Préparer le numéro de téléphone AVEC l'indicatif pays
      String phoneNumber = _phoneController.text.trim();

      // Nettoyer le numéro (supprimer les espaces, tirets, etc.) - garder seulement les chiffres
      final cleanedPhone = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');

      // AJOUTER L'INDICATIF AU NUMÉRO
      String phoneWithCountryCode;

      // Si le numéro commence par 0 (cas typique RDC), on supprime le 0 avant d'ajouter l'indicatif
      if (cleanedPhone.startsWith('0')) {
        final numberWithoutZero = cleanedPhone.substring(1);
        phoneWithCountryCode = '${_selectedCountryCode}$numberWithoutZero';
      } else {
        // Sinon on ajoute directement l'indicatif
        phoneWithCountryCode = '${_selectedCountryCode}$cleanedPhone';
      }

      final username = '${_firstNameController.text}${_lastNameController.text}';

      // MODIFICATION ICI : Utiliser phoneWithCountryCode au lieu de cleanedPhone
      final userData = {
        "phone": phoneWithCountryCode, // ← CHANGÉ ICI : Envoi avec l'indicatif
        "password": _passwordController.text,
        "typeAccountId": accountType['value'],
        "email": _emailController.text.isNotEmpty ? _emailController.text : "",
        "city": _cityController.text.trim(),
        "country": _selectedCountryName,
        "username": username,
      };

      Map<String, dynamic> payload;

      // Construction du payload selon le type de compte
      switch (_selectedAccountType) {
        case 'Bailleur':
          payload = {
            "user": userData,
            "bailleur": {
              "lastName": _lastNameController.text,
              "firstName": _firstNameController.text,
              "address": _cityController.text,
              "images": "",
              "cardFront": "",
              "cardBack": "",
              "parrainId": 0,
              "typeCardId": 1,
              "numberCard": "",
              "note": "Nouveau bailleur"
            }
          };
          break;

        case 'Locataire':
          payload = {
            "user": userData,
            "locataire": {
              "lastName": _lastNameController.text,
              "firstName": _firstNameController.text,
              "address": _cityController.text,
              "images": "",
              "cardFront": "",
              "cardBack": "",
              "typeCardId": 1,
              "numberCard": "",
            }
          };
          break;

        case 'Commissionnaire':
          payload = {
            "user": userData,
            "commissionnaire": {
              "lastName": _lastNameController.text,
              "firstName": _firstNameController.text,
              "address": _cityController.text,
              "images": "",
              "cardFront": "",
              "cardBack": "",
              "typeCardId": 1,
              "numberCard": "",
            }
          };
          break;

        // Tous les types de services (majordome, plombier, électricien, etc.)
        case 'Majordome':
        case 'Plombier':
        case 'Électricien':
        case 'Salubrité':
        case 'Peintre':
        case 'Carreleur':
        case 'Menuisier':
        case 'Frigoriste':
        case 'Ajusteur':
        case 'Architecte':
        case 'Chauffeur':
        case 'Déménagement':
          final roleKey = {
            'Majordome':  'majordome',
            'Plombier': 'plombier',
            'Électricien': 'electricien',
            'Salubrité': 'salubrite',
            'Peintre': 'peintre',
            'Carreleur': 'carreleur',
            'Menuisier': 'menuisier',
            'Frigoriste': 'frigoriste',
            'Ajusteur': 'ajusteur',
            'Architecte': 'architecte',
            'Chauffeur': 'chauffeur',
            'Déménagement': 'demenagement',
          }[_selectedAccountType]!;

          payload = {
            "user": userData,
            roleKey: {
              "lastName": _lastNameController.text,
              "firstName": _firstNameController.text,
              "address": _cityController.text,
              "serviceType": accountType['value'],
              "images": "",
              "cardFront": "",
              "cardBack": "",
              "typeCardId": 1,
              "numberCard": "",
            }
          };
          break;

        default:
          payload = {"user": userData};
      }

      HttpResponse response;

      // Redirection vers le contrôleur approprié selon le type de compte
      switch (_selectedAccountType) {
        case 'Bailleur':
          final ctrl = context.read<RegisterBailleurCtrl>();
          response = await ctrl.registerBailleur(
            payload,
            typeCompteId: accountType['value'],
          );
          break;
        case 'Locataire':
          final ctrl = context.read<RegisterLocataireCtrl>();
          response = await ctrl.registerLocataire(
            payload,
            typeCompteId: accountType['value'],
          );
          break;
        case 'Commissionnaire':
          final ctrl = context.read<RegisterCommissionnaireCtrl>();
          response = await ctrl.registerCommissionnaire(
            payload,
            typeCompteId: accountType['value'],
          );
          break;
        // Tous les types de services utilisent leur contrôleur dédié
        case 'Majordome':
          response = await context.read<RegisterMajordomeCtrl>().registerMajordome(
            payload,
            typeCompteId: accountType['value'],
          );
          break;
        case 'Plombier':
          response = await context.read<RegisterPlombierCtrl>().registerPlombier(
            payload,
            typeCompteId: accountType['value'],
          );
          break;
        case 'Électricien':
          response = await context.read<RegisterElectricienCtrl>().registerElectricien(
            payload,
            typeCompteId: accountType['value'],
          );
          break;
        case 'Salubrité':
          response = await context.read<RegisterSalubriteCtrl>().registerSalubrite(
            payload,
            typeCompteId: accountType['value'],
          );
          break;
        case 'Peintre':
          response = await context.read<RegisterPeintreCtrl>().registerPeintre(
            payload,
            typeCompteId: accountType['value'],
          );
          break;
        case 'Carreleur':
          response = await context.read<RegisterCarreleurCtrl>().registerCarreleur(
            payload,
            typeCompteId: accountType['value'],
          );
          break;
        case 'Menuisier':
          response = await context.read<RegisterMenuisierCtrl>().registerMenuisier(
            payload,
            typeCompteId: accountType['value'],
          );
          break;
        case 'Frigoriste':
          response = await context.read<RegisterFrigoristeCtrl>().registerFrigoriste(
            payload,
            typeCompteId: accountType['value'],
          );
          break;
        case 'Ajusteur':
          response = await context.read<RegisterAjusteurCtrl>().registerAjusteur(
            payload,
            typeCompteId: accountType['value'],
          );
          break;
        case 'Architecte':
          response = await context.read<RegisterArchitecteCtrl>().registerArchitecte(
            payload,
            typeCompteId: accountType['value'],
          );
          break;
        case 'Chauffeur':
          response = await context.read<RegisterChauffeurCtrl>().registerChauffeur(
            payload,
            typeCompteId: accountType['value'],
          );
          break;
        case 'Déménagement':
          response = await context.read<RegisterDemenagementCtrl>().registerDemenagement(
            payload,
            typeCompteId: accountType['value'],
          );
          break;
        default:
          final ctrl = context.read<AuthentificationCtrl>();
          response = await ctrl.register(payload, url: Endpoints.register);
      }

      if (!mounted) return;

      if (response.status == true) {
        SnackbarForCasa.success(context, "Inscription réussie!");
        await Future.delayed(const Duration(milliseconds: 1500));

        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            Routes.loginRoute,
                (route) => false,
          );
        }
      } else {
        String errorMessage = response.errorMsg ?? "Erreur lors de l'inscription";
        print("Register error: $errorMessage");
        // Ne pas afficher les erreurs techniques du serveur
        SnackbarForCasa.error(context, "Une erreur est survenue lors de l'inscription. Veuillez vérifier vos informations et réessayer.");
      }
    } catch (e) {
      print("Register error: $e");
      // Ne pas afficher les erreurs techniques
      SnackbarForCasa.error(context, "Une erreur est survenue lors de l'inscription. Veuillez réessayer.");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}