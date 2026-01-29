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
  final _contactController = TextEditingController(); // Unified email/phone
  final _passwordController = TextEditingController();
  final _cityController = TextEditingController();

  // Focus nodes pour la navigation au clavier
  final _firstNameFocus = FocusNode();
  final _lastNameFocus = FocusNode();
  final _contactFocus = FocusNode(); // Unified email/phone focus
  final _cityFocus = FocusNode();
  final _passwordFocus = FocusNode();

  // Unified contact field state
  bool _isPhoneInput = false;

  bool _isLoading = false;
  bool _showPassword = false;
  bool _isLocataireSelected = false;
  int? _selectedOwnerAccountId;
  int? _selectedPrestataireAccountId;
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
  bool _contactTouched = false; // Unified email/phone touched
  bool _cityTouched = false;
  bool _passwordTouched = false;
  String? _selectedCountryName;

  // États pour le sélecteur de pays
  String _selectedCountryCode = '+243'; // RDC par défaut
  final Map<String, String> _countryFlags = Map<String, String>.from(countryFlags);
  final Map<String, String> _countryNames = Map<String, String>.from(countryNames);

  // Types de compte dynamiques

  final Color primaryColor = Color(0xFF1976D2);
  final Color accentColor = Color(0xFF64B5F6);
  final Color darkBlue = Color(0xFF0D47A1);
  final Color lightBlue = Color(0xFFE3F2FD);
  final Color textColor = Color(0xFF1A237E);
  final Color secondaryTextColor = Color(0xFF5C6BC0);
  final Color errorColor = Color(0xFFD63031);
  final Color successColor = Color(0xFF38B000);

  bool _acceptConditions = false;

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
    });

    _passwordController.addListener(_updatePasswordStrength);
    _setupFocusNavigation();

    _selectedCountryName = _getCountryNameFromCode(_selectedCountryCode);
    _passwordController.addListener(_updatePasswordStrength);
    _setupFocusNavigation();


    // Ajouter des listeners pour tous les contrôleurs
    _firstNameController.addListener(_updateButtonState);
    _lastNameController.addListener(_updateButtonState);
    _contactController.addListener(_updateContactType); // Unified listener
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
    _contactFocus.addListener(() => _onFieldFocusChange(_contactFocus, () => _contactTouched = true));
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

  // Détecter si l'utilisateur saisit un numéro de téléphone
  void _updateContactType() {
    if (mounted) {
      setState(() {
        final text = _contactController.text.trim();
        _isPhoneInput = _looksLikePhoneNumber(text);
      });
    }
  }

  bool _looksLikePhoneNumber(String text) {
    if (text.isEmpty) return false;
    final hasDigits = RegExp(r'\d').hasMatch(text);
    final hasAtSymbol = text.contains('@');
    final startsWithPlus = text.startsWith('+');
    final startsWithDigit = text.isNotEmpty && RegExp(r'^\d').hasMatch(text);
    return hasDigits && !hasAtSymbol && (startsWithPlus || startsWithDigit || text.length >= 8);
  }

  @override
  void dispose() {
    _passwordController.removeListener(_updatePasswordStrength);
    _firstNameController.removeListener(_updateButtonState);
    _lastNameController.removeListener(_updateButtonState);
    _contactController.removeListener(_updateContactType);
    _cityController.removeListener(_updateButtonState);
    _passwordController.removeListener(_updateButtonState);

    _firstNameFocus.dispose();
    _lastNameFocus.dispose();
    _contactFocus.dispose();
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
            nextFocus: _contactFocus,
            isTouched: _lastNameTouched,
          ),
          SizedBox(height: 15),
          // Email ou Téléphone (champ unifié)
          _buildContactField(),
          SizedBox(height: 15),
          // Ville
          _buildCityField(),
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
        style: TextStyle(color: Colors.black87, fontSize: 16), // Force black text on light background
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
          labelStyle: TextStyle(color: Colors.black87), // Force black label on light background
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

  // Champ unifié Email ou Téléphone (comme LoginScreen)
  Widget _buildContactField() {
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
        controller: _contactController,
        focusNode: _contactFocus,
        autovalidateMode: AutovalidateMode.disabled,
        style: TextStyle(color: Colors.black87, fontSize: 16),
        textInputAction: TextInputAction.next,
        onFieldSubmitted: (_) => _goToNextField(_contactFocus, _cityFocus),
        decoration: InputDecoration(
          labelText: 'Email ou Téléphone*',
          labelStyle: TextStyle(color: Colors.black87),
          prefixIcon: _isPhoneInput && _contactController.text.isNotEmpty
              ? _buildCountryCodeDropdown()
              : Container(
                  padding: EdgeInsets.all(12),
                  child: Icon(Icons.email_rounded, color: primaryColor),
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
          hintText: 'exemple@email.com ou 810000000',
          hintStyle: TextStyle(color: Colors.grey.shade500),
          errorText: _contactTouched ? _validateContact(_contactController.text) : null,
        ),
        keyboardType: _isPhoneInput ? TextInputType.phone : TextInputType.emailAddress,
        onChanged: (String value) {
          bool isPhone = _looksLikePhoneNumber(value);
          if (isPhone) {
            String cleaned = value.replaceAll(RegExp(r'[^\d]'), '');
            if (cleaned.startsWith('0') && cleaned.length > 1) {
              cleaned = cleaned.substring(1);
              _contactController.value = TextEditingValue(
                text: cleaned,
                selection: TextSelection.collapsed(offset: cleaned.length),
              );
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _updateContactType();
                if (_contactTouched) _forceRevalidation();
              });
              return;
            }
          }
          _updateContactType();
          if (_contactTouched) _forceRevalidation();
        },
        onEditingComplete: () {
          setState(() => _contactTouched = true);
        },
        validator: null,
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
            FocusScope.of(context).requestFocus(_passwordFocus);
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
            style: TextStyle(
              color: Colors.black87,
              fontSize: 16,
            ),
            onFieldSubmitted: (String value) {
              onFieldSubmitted();
              _goToNextField(focusNode, _passwordFocus);
            },
            onChanged: (String value) {
              setState(() {
                _cityController.text = value;
                _cityTouched = true;
              });
            },
            decoration: InputDecoration(
              labelText: 'Ville*',
              labelStyle: TextStyle(
                color: Colors.black87,
              ),
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
              hintStyle: TextStyle(
                color: Colors.grey.shade500,
              ),
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
                                      color: Colors.black87,
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
    final typeCtrl = context.watch<TypeAccountController>();
    if (typeCtrl.loading && typeCtrl.allAccounts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(primaryColor)),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Type de compte*',
          style: TextStyle(
            color: secondaryTextColor,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 16),

        // SECTION 1: LOCATAIRE (CLIENT)
        _buildCategoryHeader(
          title: "Vous êtes Locataire ?",
          icon: Icons.person_pin_rounded,
          isSelected: _isLocataireSelected,
          onTap: () {
            setState(() {
              _isLocataireSelected = !_isLocataireSelected;
              if (_isLocataireSelected) {
                _selectedOwnerAccountId = null; // Exclusivité
              }
            });
          },
        ),
        if (_isLocataireSelected)
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 4, bottom: 8),
            child: Text(
              "Compte client activé (Locataire)",
              style: TextStyle(color: primaryColor, fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        
        SizedBox(height: 12),

        // SECTION 2: PROPRIÉTAIRE (IMMOBILIER)
        _buildCategoryHeader(
          title: "Vous proposez de l'immobilier ?",
          icon: Icons.home_work_rounded,
          isSelected: _selectedOwnerAccountId != null,
          showBadge: true,
          onTap: () async {
            if (typeCtrl.ownerTypes.isEmpty) {
               await typeCtrl.fetchTypeAccounts();
               if (typeCtrl.ownerTypes.isEmpty) {
                  if (mounted) SnackbarForCasa.error(context, "Aucun type de compte immobilier disponible");
                  return;
               }
            }
            setState(() {
              if (_selectedOwnerAccountId != null) {
                _selectedOwnerAccountId = null;
              } else {
                _isLocataireSelected = false; // Exclusivité
                _selectedOwnerAccountId = typeCtrl.ownerTypes.isNotEmpty ? typeCtrl.ownerTypes[0]['id'] : null;
              }
            });
          },
        ),
        if (_selectedOwnerAccountId != null)
          _buildSubOptionsGrid(
            options: typeCtrl.ownerTypes,
            selectedId: _selectedOwnerAccountId,
            onSelected: (id) => setState(() => _selectedOwnerAccountId = id),
          ),

        SizedBox(height: 12),

        // SECTION 3: PRESTATAIRE DE SERVICE
        _buildCategoryHeader(
          title: "Vous proposez des services ?",
          icon: Icons.handyman_rounded,
          isSelected: _selectedPrestataireAccountId != null,
          onTap: () async {
            if (typeCtrl.serviceTypes.isEmpty) {
               await typeCtrl.fetchTypeAccounts();
               if (typeCtrl.serviceTypes.isEmpty) {
                  if (mounted) SnackbarForCasa.error(context, "Aucun type de service disponible");
                  return;
               }
            }
            setState(() {
              if (_selectedPrestataireAccountId != null) {
                _selectedPrestataireAccountId = null;
              } else {
                _selectedPrestataireAccountId = typeCtrl.serviceTypes.isNotEmpty ? typeCtrl.serviceTypes[0]['id'] : null;
              }
            });
          },
        ),
        if (_selectedPrestataireAccountId != null)
          _buildSubOptionsGrid(
            options: typeCtrl.serviceTypes,
            selectedId: _selectedPrestataireAccountId,
            onSelected: (id) => setState(() => _selectedPrestataireAccountId = id),
          ),

        if (_autoValidateMode == AutovalidateMode.always &&
            !_isLocataireSelected &&
            _selectedOwnerAccountId == null &&
            _selectedPrestataireAccountId == null)
          Padding(
            padding: const EdgeInsets.only(top: 12, left: 8),
            child: Row(
              children: [
                Icon(Icons.error_outline_rounded, color: errorColor, size: 16),
                SizedBox(width: 8),
                Text(
                  'Sélectionnez au moins une catégorie',
                  style: TextStyle(color: errorColor, fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildCategoryHeader({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    bool showBadge = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 300),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor.withOpacity(0.08) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? primaryColor : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? primaryColor : secondaryTextColor, size: 24),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? primaryColor : textColor,
                ),
              ),
            ),
            Icon(
              isSelected ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded,
              color: isSelected ? primaryColor : Colors.grey.shade400,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubOptionsGrid({
    required List<dynamic> options,
    required int? selectedId,
    required Function(int) onSelected,
  }) {
    return Container(
      margin: EdgeInsets.only(top: 8, left: 8, right: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: lightBlue.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: options.map((opt) {
          final id = opt['id'] as int;
          final name = opt['name'] as String;
          final isSelected = selectedId == id;
          
          return InkWell(
            onTap: () => onSelected(id),
            borderRadius: BorderRadius.circular(20),
            child: AnimatedContainer(
              duration: Duration(milliseconds: 200),
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? primaryColor : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? primaryColor : Colors.grey.shade300,
                ),
                boxShadow: isSelected ? [
                  BoxShadow(color: primaryColor.withOpacity(0.3), blurRadius: 4, offset: Offset(0, 2))
                ] : [],
              ),
              child: Text(
                name.toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : secondaryTextColor,
                ),
              ),
            ),
          );
        }).toList(),
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
        style: TextStyle(color: Colors.black87, fontSize: 16), // Force black text on light background
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
          labelStyle: TextStyle(color: Colors.black87), // Force black label on light background
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
      _contactTouched = true;
      _cityTouched = true;
      _passwordTouched = true;
      _autoValidateMode = AutovalidateMode.always;
    });

    // Vérifier si le formulaire est valide
    final hasSelectedAccount = _isLocataireSelected || 
                               _selectedOwnerAccountId != null || 
                               _selectedPrestataireAccountId != null;

    final hasRequiredFields = _firstNameController.text.isNotEmpty &&
        _lastNameController.text.isNotEmpty &&
        _contactController.text.isNotEmpty &&
        _cityController.text.isNotEmpty &&
        _passwordController.text.isNotEmpty &&
        hasSelectedAccount;

    final isFirstNameValid = _validateName(_firstNameController.text, 'prénom') == null;
    final isLastNameValid = _validateName(_lastNameController.text, 'nom') == null;
    final isContactValid = _validateContact(_contactController.text) == null;
    final isCityValid = _validateCity(_cityController.text) == null;
    final isPasswordValid = _validatePassword(_passwordController.text) == null;

    final isFormValid = isFirstNameValid &&
        isLastNameValid &&
        isContactValid &&
        isCityValid &&
        isPasswordValid;

    final isButtonEnabled = hasRequiredFields && isFormValid && _acceptConditions && !_isLoading;

    if (isButtonEnabled) {
      _handleRegister();
    } else {
      // Afficher un message d'erreur si le formulaire n'est pas valide
      String message = "Veuillez remplir tous les champs obligatoires";
      if (!hasSelectedAccount) message = "Veuillez sélectionner au moins un type de compte";
      else if (!_acceptConditions) message = "Veuillez accepter les conditions d'utilisation";
      
      SnackbarForCasa.error(context, message);
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
                else if (_passwordStrength <= 4) color = accentColor;
                else color = darkBlue;
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
            color: isMet ? darkBlue : Colors.grey.shade400,
            size: 12,
          ),
          SizedBox(width: 4),
          Text(
            criterion['text'] as String,
            style: TextStyle(
              fontSize: 10,
              color: isMet ? darkBlue : Colors.grey.shade600,
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
    if (strength <= 4) return accentColor;
    return darkBlue;
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
    final hasSelectedAccount = _isLocataireSelected || 
                               _selectedOwnerAccountId != null || 
                               _selectedPrestataireAccountId != null;
    final hasRequiredFields = _firstNameController.text.isNotEmpty &&
        _lastNameController.text.isNotEmpty &&
        _contactController.text.isNotEmpty &&
        _cityController.text.isNotEmpty &&
        _passwordController.text.isNotEmpty &&
        hasSelectedAccount;

    // Always validate when fields have content
    final isFirstNameValid = _firstNameController.text.isEmpty || _validateName(_firstNameController.text, 'prénom') == null;
    final isLastNameValid = _lastNameController.text.isEmpty || _validateName(_lastNameController.text, 'nom') == null;
    final isContactValid = _contactController.text.isEmpty || _validateContact(_contactController.text) == null;
    final isCityValid = _cityController.text.isEmpty || _validateCity(_cityController.text) == null;
    final isPasswordValid = _passwordController.text.isEmpty || _validatePassword(_passwordController.text) == null;

    final isFormValid = isFirstNameValid &&
        isLastNameValid &&
        isContactValid &&
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

  // Unified Email/Phone validator (like LoginScreen)
  String? _validateContact(String? value) {
    if (value == null || value.isEmpty) {
      return 'Veuillez entrer un email ou un numéro de téléphone';
    }

    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    final cleanedValue = value.replaceAll(RegExp(r'[\s\-\+\(\)]'), '');
    final isPhone = _looksLikePhoneNumber(value);

    // If it looks like a phone, validate as phone
    if (isPhone) {
      final cleanedValue = value.replaceAll(RegExp(r'[\s\-\+\(\)]'), '');
      if (_selectedCountryCode == '+243') {
        if (cleanedValue.length != 9) {
          return 'Le numéro RDC doit avoir 9 chiffres';
        }
        if (!RegExp(r'^[89]').hasMatch(cleanedValue)) {
          return 'Le numéro RDC doit commencer par 8 ou 9';
        }
      } else {
        if (cleanedValue.length < 8) {
          return 'Numéro de téléphone trop court';
        }
      }
    } else {
      if (!emailRegex.hasMatch(value)) {
        return 'Email invalide';
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
     setState(() {
      _firstNameTouched = true;
      _lastNameTouched = true;
      _contactTouched = true;
      _cityTouched = true;
      _passwordTouched = true;
      _autoValidateMode = AutovalidateMode.always;
    });

    await Future.delayed(Duration(milliseconds: 50));

    if (_validateName(_firstNameController.text, 'prénom') != null || 
        _validateName(_lastNameController.text, 'nom') != null || 
        _validateContact(_contactController.text) != null || 
        _validateCity(_cityController.text) != null || 
        _validatePassword(_passwordController.text) != null) {
      SnackbarForCasa.error(context, "Veuillez corriger les erreurs");
      return;
    }

    if (!_isLocataireSelected && _selectedOwnerAccountId == null && _selectedPrestataireAccountId == null) {
      SnackbarForCasa.error(context, "Veuillez sélectionner un type de compte");
      return;
    }

    if (!_acceptConditions) {
      SnackbarForCasa.error(context, "Veuillez accepter les conditions");
      return;
    }

    setState(() => _isLoading = true);
    FocusScope.of(context).unfocus();

    if (!await NetworkUtils.checkInternetConnectivity()) {
      SnackbarForCasa.error(context, "Pas de connexion internet");
      setState(() => _isLoading = false);
      return;
    }

    try {
    // Trouver les IDs des comptes sélectionnés
    List<Map<String, int>> accountsPayload = [];
    final typeCtrl = context.read<TypeAccountController>();

    if (_isLocataireSelected) {
      accountsPayload.add({"typeAccount": 1}); // ID du typeClient
    }
    if (_selectedOwnerAccountId != null) {
      accountsPayload.add({"typeAccount": 2}); // ID du typeProprietaire
    }
    if (_selectedPrestataireAccountId != null) {
      accountsPayload.add({"typeAccount": 3}); // ID du typePrestataire
    }
    
    // NOTE: Si l'API attend l'ID du ROLE (l'id à la racine du JSON) 
    // et non l'ID de CATEGORIE (typeAccountId), il faudra ajuster ici.
    // D'après le code précédent, il envoyait typeAccountId.
    // Mais le JSON suggère que l'id à la racine est l'ID du compte spécifique.
    // L'utilisateur dit: "si une personne choisi proprietaire il peut ensuite choisir Bailleur..."
    // Donc on va envoyer l'ID du rôle spécifique.
    
    accountsPayload.clear();
    if (_isLocataireSelected) {
      accountsPayload.add({"typeAccount": 4}); // Locataire
    }
    if (_selectedOwnerAccountId != null) {
      accountsPayload.add({"typeAccount": _selectedOwnerAccountId!}); 
    }
    if (_selectedPrestataireAccountId != null) {
      accountsPayload.add({"typeAccount": _selectedPrestataireAccountId!});
    }
      
      if (accountsPayload.isEmpty) {
          SnackbarForCasa.error(context, "Type de compte invalide");
          setState(() => _isLoading = false);
          return;
      }

      // Préparer les données de contact selon le type (email ou téléphone)
      String phoneField = '';
      String emailField = '';
      
      // Recalculer si c'est un téléphone ou email pour la soumission
      final contactValue = _contactController.text.trim();
      final isPhone = _looksLikePhoneNumber(contactValue);

      if (isPhone) {
        // C'est un numéro de téléphone
        final cleanedPhone = contactValue.replaceAll(RegExp(r'[^\d]'), '');
        phoneField = cleanedPhone.startsWith('0') 
            ? '${_selectedCountryCode}${cleanedPhone.substring(1)}'
            : '${_selectedCountryCode}$cleanedPhone';
        // S'assurer que le champ phone ne soit pas vide s'il y a un souci de parsing
        if (phoneField == _selectedCountryCode) phoneField = contactValue;
      } else {
        // C'est un email
        emailField = contactValue;
      }

      final Map<String, dynamic> userData = {
        "password": _passwordController.text,
        "city": _cityController.text.trim(),
        "country": _selectedCountryName ?? "RDC",
        "username": "${_firstNameController.text.trim()}${_lastNameController.text.trim()}".replaceAll(' ', '').toLowerCase(),
      };
      
      if (isPhone) {
        userData["phone"] = phoneField; 
        userData["email"] = "";
      } else {
        userData["phone"] = "";
        userData["email"] = emailField;
      }

      final actorData = {
          "lastName": _lastNameController.text.trim(),
          "firstName": _firstNameController.text.trim(),
          "address": _cityController.text.trim(),
          "images": "",
          "cardFront": "",
          "cardBack": "",
          "typeCardId": 0,
          "parrainId": 0,
          "numberCard": ""
      };
      
      // Payload unifié
      final Map<String, dynamic> payload = {
        "user": userData,
        "account": accountsPayload,
        "actor": actorData
      };

      final authCtrl = context.read<AuthentificationCtrl>();
      final response = await authCtrl.register(payload, url: '');

      if (response.status == true) {
         SnackbarForCasa.success(context, "Inscription réussie !");
         await Future.delayed(Duration(milliseconds: 500));
         Navigator.of(context).pushReplacementNamed(Routes.loginRoute);
      } else {
         String errorMessage = response.errorMsg ?? response.data?['message'] ?? "Une erreur est survenue. Veuillez réessayer";
         SnackbarForCasa.error(context, _sanitizeError(errorMessage));
      }

    } catch (e) {
      print("Erreur inscription: $e");
      SnackbarForCasa.error(context, "Une erreur est survenue. Veuillez réessayer.");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _sanitizeError(String? error) {
    if (error == null || error.isEmpty) return "Erreur lors de l'inscription. Veuillez réessayer.";
    final lower = error.toLowerCase();
    
    // Masquer les erreurs techniques
    if (lower.contains("internal server error") || 
        lower.contains("exception") || 
        lower.contains("status") || 
        lower.contains("timeout") ||
        lower.contains("connection refused") ||
        error.startsWith("{") ||
        error.startsWith("<html>")) {
      return "Une erreur est survenue. Veuillez réessayer.";
    }
    return error; 
  }
}