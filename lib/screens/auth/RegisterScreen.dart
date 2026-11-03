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
import '../../utils/api_error_message.dart';
import '../../utils/crashlytics_api.dart';
import '../../utils/login_route_args.dart';
import '../../controllers/TypeAccountController.dart';
import '../termsAndPrivacy/TermsAndPrivacyPage.dart';
import '../../widgets/step_appear.dart';

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
  bool _showConditionsError = false;
  static const int _stepCount = 5;
  int _step = 0;

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
    final strength = _passwordController.text.length;
    if (mounted && _passwordStrength != strength) {
      setState(() => _passwordStrength = strength);
    }
  }

  void _goToNextField(FocusNode currentFocus, FocusNode nextFocus) {
    currentFocus.unfocus();
    FocusScope.of(context).requestFocus(nextFocus);
  }

  void _previousStep() {
    FocusScope.of(context).unfocus();
    if (_step == 0) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _step -= 1);
  }

  void _continueStep() {
    FocusScope.of(context).unfocus();
    if (_step == 0) {
      setState(() {
        _firstNameTouched = true;
        _lastNameTouched = true;
      });
      if (_validateName(_firstNameController.text, 'prénom') != null ||
          _validateName(_lastNameController.text, 'nom') != null) {
        return;
      }
    } else if (_step == 1) {
      setState(() => _contactTouched = true);
      if (_validateContact(_contactController.text) != null) return;
    } else if (_step == 2) {
      setState(() => _cityTouched = true);
      if (_validateCity(_cityController.text) != null) return;
    } else if (_step == 3) {
      final hasAccount = _isLocataireSelected ||
          _selectedOwnerAccountId != null ||
          _selectedPrestataireAccountId != null;
      if (!hasAccount) {
        setState(() => _autoValidateMode = AutovalidateMode.always);
        return;
      }
    } else {
      setState(() {
        _passwordTouched = true;
        _autoValidateMode = AutovalidateMode.always;
      });
      if (_validatePassword(_passwordController.text) != null) return;
      if (!_acceptConditions) {
        setState(() => _showConditionsError = true);
        return;
      }
      _handleRegister();
      return;
    }
    setState(() => _step += 1);
  }

  @override
  Widget build(BuildContext context) {
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          _buildBackground(),
          PopScope(
            canPop: _step == 0 && !_isLoading,
            onPopInvokedWithResult: (didPop, result) {
              if (didPop || _isLoading) return;
              _previousStep();
            },
            child: SafeArea(
              child: AbsorbPointer(
                absorbing: _isLoading,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildStepHeader(),
                    Expanded(
                      child: Form(
                        key: _formKey,
                        autovalidateMode: _autoValidateMode,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 280),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          child: SingleChildScrollView(
                            key: ValueKey<int>(_step),
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                            child: _buildStepContent(),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildStepButton(),
                          if (!keyboardOpen) ...[
                            const SizedBox(height: 4),
                            _buildLoginLink(),
                          ],
                        ],
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

  Widget _buildStepHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
      child: Column(
        children: [
          SizedBox(
            height: 48,
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back_ios_new, color: textColor, size: 20),
                  onPressed: _isLoading ? null : _previousStep,
                ),
                Expanded(
                  child: Text(
                    'CasaNayo',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                Text(
                  '${_step + 1}/$_stepCount',
                  style: TextStyle(
                    color: secondaryTextColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: List.generate(_stepCount, (index) {
                final filled = index <= _step;
                return Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    height: 4,
                    margin: EdgeInsets.only(right: index == _stepCount - 1 ? 0 : 6),
                    decoration: BoxDecoration(
                      color: filled ? primaryColor : const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepContent() {
    late final String title;
    late final String subtitle;
    late final Widget fields;
    switch (_step) {
      case 0:
        title = 'Comment vous appelez-vous ?';
        subtitle = 'Ces informations apparaîtront sur votre profil.';
        fields = Column(
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
            const SizedBox(height: 16),
            _buildNameField(
              controller: _lastNameController,
              label: 'Nom',
              hint: 'Baka',
              focusNode: _lastNameFocus,
              isTouched: _lastNameTouched,
            ),
          ],
        );
        break;
      case 1:
        title = 'Comment peut-on vous joindre ?';
        subtitle = 'Un email ou un numéro de téléphone suffit.';
        fields = _buildContactField();
        break;
      case 2:
        title = 'Dans quelle ville êtes-vous ?';
        subtitle = 'Pour vous proposer des biens près de chez vous.';
        fields = _buildCityField();
        break;
      case 3:
        title = 'Que venez-vous faire ?';
        subtitle = 'Choisissez le type de compte qui vous correspond.';
        fields = _buildAccountTypeField();
        break;
      default:
        title = 'Choisissez un mot de passe';
        subtitle = '6 caractères suffisent. Pas besoin d’un mot de passe compliqué.';
        fields = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPasswordField(),
            _buildPasswordStrengthIndicator(),
            const SizedBox(height: 20),
            _buildPrivacyText(),
          ],
        );
    }

    return StepAppear(
      key: ValueKey<int>(_step),
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 28,
            height: 1.15,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF111827),
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 15,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 28),
        fields,
      ],
    ),
    );
  }

  Widget _buildStepButton() {
    final isLast = _step == _stepCount - 1;
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _continueStep,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: primaryColor,
          disabledBackgroundColor: primaryColor.withOpacity(0.45),
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              )
            : Text(
                isLast ? 'Créer mon compte' : 'Suivant',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
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

          AbsorbPointer(
            absorbing: _isLoading,
            child: Column(
              children: [
                _buildAuthForm(),
                SizedBox(height: 25),
                _buildPrivacyText(),
                SizedBox(height: 25),
                _buildAuthButton(),
                SizedBox(height: 20),
                _buildLoginLink(),
              ],
            ),
          ),
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
        onChanged: (val) {
          if (!isTouched && val.isNotEmpty) {
            setState(() {
              if (label == 'Prénom') _firstNameTouched = true;
              else if (label == 'Nom') _lastNameTouched = true;
            });
          }
          _forceRevalidation();
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
        onFieldSubmitted: (_) => _continueStep(),
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
          if (!_contactTouched && value.isNotEmpty) {
            setState(() => _contactTouched = true);
          }
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
                _forceRevalidation();
              });
              return;
            }
          }
          _updateContactType();
          _forceRevalidation();
        },
        onEditingComplete: () {
          setState(() => _contactTouched = true);
        },
        validator: null,
      ),
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
              _continueStep();
            },
            onTapOutside: (event) {
              focusNode.unfocus();
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
                constraints: BoxConstraints(maxHeight: 250),
                width: MediaQuery.of(context).size.width - 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.white,
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: ListView.separated(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  shrinkWrap: true,
                  itemCount: options.length > 8 ? 8 : options.length,
                  separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade100),
                  itemBuilder: (BuildContext context, int index) {
                    final CityModel city = options.elementAt(index);
                    final cityName = city.name ?? '';
                    
                    return InkWell(
                      onTap: () => onSelected(city),
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                                size: 18,
                                color: primaryColor,
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                cityName,
                                style: TextStyle(
                                  color: Colors.black87,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 14,
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

  int? _optionId(dynamic opt) {
    if (opt is! Map) return null;
    final raw = opt['id'] ?? opt['typeAccountId'] ?? opt['TypeAccountId'];
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? '');
  }

  String _optionName(dynamic opt) {
    if (opt is! Map) return '';
    return (opt['name'] ?? opt['Name'] ?? opt['libelle'] ?? '').toString().trim();
  }

  String? _labelFor(List<dynamic> options, int? id) {
    if (id == null) return null;
    for (final opt in options) {
      if (_optionId(opt) == id) {
        final name = _optionName(opt);
        if (name.isNotEmpty) return name;
      }
    }
    return null;
  }

  Widget _buildAccountTypeField() {
    final typeCtrl = context.watch<TypeAccountController>();
    if (typeCtrl.loading && typeCtrl.allAccounts.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    final ownerLabel = _labelFor(typeCtrl.ownerTypes, _selectedOwnerAccountId);
    final serviceLabel = _labelFor(typeCtrl.serviceTypes, _selectedPrestataireAccountId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLocataireChoice(),
        const SizedBox(height: 12),
        _buildExpandingDropdown(
          title: 'Immobilier',
          hint: 'Choisir un type',
          icon: Icons.home_work_rounded,
          open: _isImmobilierDropdownOpen,
          selectedLabel: ownerLabel,
          onToggle: () => _toggleTypeMenu(immobilier: true, typeCtrl: typeCtrl),
          options: typeCtrl.ownerTypes,
          selectedId: _selectedOwnerAccountId,
          onSelected: (id) {
            setState(() {
              _selectedOwnerAccountId = id;
              _isLocataireSelected = false;
              _isImmobilierDropdownOpen = false;
            });
          },
        ),
        const SizedBox(height: 12),
        _buildExpandingDropdown(
          title: 'Services',
          hint: 'Choisir un métier',
          icon: Icons.handyman_rounded,
          expandDuration: const Duration(milliseconds: 780),
          open: _isServicesDropdownOpen,
          selectedLabel: serviceLabel,
          onToggle: () => _toggleTypeMenu(immobilier: false, typeCtrl: typeCtrl),
          options: typeCtrl.serviceTypes,
          selectedId: _selectedPrestataireAccountId,
          onSelected: (id) {
            setState(() {
              _selectedPrestataireAccountId =
                  _selectedPrestataireAccountId == id ? null : id;
              _isServicesDropdownOpen = false;
            });
          },
        ),
        if (_autoValidateMode == AutovalidateMode.always &&
            !_isLocataireSelected &&
            _selectedOwnerAccountId == null &&
            _selectedPrestataireAccountId == null)
          Padding(
            padding: const EdgeInsets.only(top: 12, left: 4),
            child: Row(
              children: [
                Icon(Icons.error_outline_rounded, color: errorColor, size: 16),
                const SizedBox(width: 8),
                const Text(
                  'Sélectionnez au moins une catégorie',
                  style: TextStyle(color: Color(0xFFD63031), fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildLocataireChoice() {
    final selected = _isLocataireSelected;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        setState(() {
          _isLocataireSelected = !_isLocataireSelected;
          if (_isLocataireSelected) {
            _selectedOwnerAccountId = null;
            _isImmobilierDropdownOpen = false;
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? primaryColor.withOpacity(0.06) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? primaryColor : const Color(0xFFE5E7EB),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.person_pin_rounded, color: primaryColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Locataire',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Je cherche un logement',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            Icon(
              selected ? Icons.check_circle_rounded : Icons.circle_outlined,
              color: selected ? primaryColor : const Color(0xFFD1D5DB),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleTypeMenu({
    required bool immobilier,
    required TypeAccountController typeCtrl,
  }) async {
    final options = immobilier ? typeCtrl.ownerTypes : typeCtrl.serviceTypes;
    if (options.isEmpty) {
      await typeCtrl.fetchTypeAccounts();
      if (!mounted) return;
      final refreshed = immobilier ? typeCtrl.ownerTypes : typeCtrl.serviceTypes;
      if (refreshed.isEmpty) {
        SnackbarForCasa.error(
          context,
          immobilier
              ? "Les types de compte immobilier ne sont pas disponibles pour le moment. Réessayez plus tard."
              : "Les types de service ne sont pas disponibles pour le moment. Réessayez plus tard.",
        );
        return;
      }
    }
    setState(() {
      if (immobilier) {
        _isImmobilierDropdownOpen = !_isImmobilierDropdownOpen;
        if (_isImmobilierDropdownOpen) _isServicesDropdownOpen = false;
      } else {
        _isServicesDropdownOpen = !_isServicesDropdownOpen;
        if (_isServicesDropdownOpen) _isImmobilierDropdownOpen = false;
      }
    });
  }

  Widget _buildExpandingDropdown({
    required String title,
    required String hint,
    required IconData icon,
    Duration expandDuration = const Duration(milliseconds: 480),
    required bool open,
    required String? selectedLabel,
    required VoidCallback onToggle,
    required List<dynamic> options,
    required int? selectedId,
    required ValueChanged<int> onSelected,
  }) {
    final hasSelection = selectedLabel != null && selectedLabel.isNotEmpty;
    final highlighted = open || hasSelection;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: highlighted ? primaryColor.withOpacity(0.08) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: highlighted ? primaryColor : const Color(0xFFE5E7EB),
          width: highlighted ? 1.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: primaryColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          hasSelection ? selectedLabel : hint,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: hasSelection
                                ? const Color(0xFF111827)
                                : const Color(0xFF9CA3AF),
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: open ? 0.5 : 0,
                    duration: expandDuration,
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: open ? primaryColor : Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: expandDuration,
            curve: Curves.easeInOutCubic,
            alignment: Alignment.topCenter,
            child: open
                ? Column(
                    children: [
                      const Divider(height: 1, thickness: 1, color: Color(0xFFE5E7EB)),
                      if (options.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'Aucun choix disponible',
                            style: TextStyle(color: Colors.grey[600], fontSize: 14),
                          ),
                        )
                      else
                        for (var i = 0; i < options.length; i++)
                          _dropdownOption(
                            label: _optionName(options[i]),
                            selected: _optionId(options[i]) == selectedId,
                            onTap: () {
                              final id = _optionId(options[i]);
                              if (id != null) onSelected(id);
                            },
                          ),
                    ],
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    ),
    );
  }

  Widget _dropdownOption({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        color: selected ? primaryColor.withOpacity(0.14) : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
              color: selected ? primaryColor : const Color(0xFFD1D5DB),
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label.isEmpty ? 'Type' : label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: const Color(0xFF111827),
                ),
              ),
            ),
          ],
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
        style: TextStyle(color: Colors.black87, fontSize: 16), // Force black text on light background
        obscureText: !_showPassword,
        autovalidateMode: AutovalidateMode.disabled,
        textInputAction: TextInputAction.go, // ← CHANGER EN "go"
        onFieldSubmitted: (_) => _triggerRegistrationIfValid(), // ← AJOUTER CETTE LIGNE
        onChanged: (val) {
          if (!_passwordTouched && val.isNotEmpty) {
            setState(() => _passwordTouched = true);
          }
          _forceRevalidation();
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
      if (!_acceptConditions && hasRequiredFields && isFormValid) {
        setState(() => _showConditionsError = true);
        return;
      }
      String message = "Veuillez remplir tous les champs obligatoires";
      if (!hasSelectedAccount) message = "Veuillez sélectionner au moins un type de compte";
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
    final length = _passwordController.text.length;
    final filled = length.clamp(0, 6);
    final ready = length >= 6;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Row(
          children: List.generate(6, (index) {
            return Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                height: 4,
                margin: EdgeInsets.only(right: index < 5 ? 4 : 0),
                decoration: BoxDecoration(
                  color: index < filled
                      ? (ready ? const Color(0xFF16A34A) : primaryColor)
                      : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Text(
          length == 0
              ? '6 caractères suffisent'
              : (ready ? 'Mot de passe valide' : 'Encore ${6 - length} caractère${length == 5 ? '' : 's'}'),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: ready ? const Color(0xFF16A34A) : secondaryTextColor,
          ),
        ),
      ],
    );
  }

  Widget _buildPrivacyText() {
    final showError = _showConditionsError && !_acceptConditions;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(4, 8, 12, 12),
      decoration: BoxDecoration(
        color: showError ? errorColor.withOpacity(0.06) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: showError ? errorColor : const Color(0xFFE5E7EB),
          width: showError ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: _acceptConditions,
                onChanged: (bool? value) {
                  setState(() {
                    _acceptConditions = value ?? false;
                    if (_acceptConditions) _showConditionsError = false;
                  });
                },
                activeColor: primaryColor,
                checkColor: Colors.white,
                side: BorderSide(
                  color: showError ? errorColor : const Color(0xFF94A3B8),
                  width: showError ? 1.8 : 1.4,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: 'J\'accepte les ',
                          style: TextStyle(
                            color: const Color(0xFF334155),
                            fontSize: 14,
                            height: 1.35,
                          ),
                        ),
                        TextSpan(
                          text: 'conditions d\'utilisation',
                          style: TextStyle(
                            color: primaryColor,
                            fontSize: 14,
                            height: 1.35,
                            fontWeight: FontWeight.w700,
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
                        const TextSpan(
                          text: ' et la ',
                          style: TextStyle(
                            color: Color(0xFF334155),
                            fontSize: 14,
                            height: 1.35,
                          ),
                        ),
                        TextSpan(
                          text: 'politique de confidentialité',
                          style: TextStyle(
                            color: primaryColor,
                            fontSize: 14,
                            height: 1.35,
                            fontWeight: FontWeight.w700,
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
                        const TextSpan(
                          text: ' de CasaNayo',
                          style: TextStyle(
                            color: Color(0xFF334155),
                            fontSize: 14,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (showError)
            Padding(
              padding: const EdgeInsets.only(left: 12, right: 4, top: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.error_outline_rounded, color: errorColor, size: 18),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Cochez la case pour créer votre compte.',
                      style: TextStyle(
                        color: Color(0xFFD63031),
                        fontSize: 13,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
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
      SnackbarForCasa.error(context, "Certains champs doivent être corrigés avant de continuer.");
      return;
    }

    if (!_isLocataireSelected && _selectedOwnerAccountId == null && _selectedPrestataireAccountId == null) {
      SnackbarForCasa.error(context, "Choisissez le type de compte qui vous correspond.");
      return;
    }

    if (!_acceptConditions) {
      setState(() => _showConditionsError = true);
      return;
    }

    setState(() => _isLoading = true);
    FocusScope.of(context).unfocus();

    if (!await NetworkUtils.checkInternetConnectivity()) {
      SnackbarForCasa.error(
        context,
        "Connexion internet indisponible. Réessayez lorsque le réseau est stable.",
      );
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
          SnackbarForCasa.error(
            context,
            "Le type de compte choisi n’est pas reconnu. Sélectionnez à nouveau une option.",
          );
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
        var sessionReady = authCtrl.isSessionEstablished;
        if (!sessionReady) {
          sessionReady = await authCtrl.completeSessionAfterRegistration(
            contactTrimmed: contactValue,
            countryCode: _selectedCountryCode,
            isPhone: isPhone,
            password: _passwordController.text,
          );
        }

        if (!mounted) return;

        if (sessionReady) {
          SnackbarForCasa.success(
            context,
            "Bienvenue ! Votre compte est prêt.",
          );
          Navigator.pushNamedAndRemoveUntil(
            context,
            Routes.bottomPageRoute,
            (route) => false,
          );
        } else {
          SnackbarForCasa.success(
            context,
            "Votre compte est créé. Connectez-vous pour continuer.",
          );
          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted) {
            Navigator.of(context).pushReplacementNamed(
              Routes.loginRoute,
              arguments: LoginRouteArgs(
                contact: contactValue,
                countryCode: _selectedCountryCode,
                isPhone: isPhone,
              ),
            );
          }
        }
      } else {
         reportApiFailureToCrashlytics(
           'RegisterScreen',
           response: response,
           reason: 'register',
         );
         SnackbarForCasa.error(context, ApiErrorMessages.fromResponse(response));
      }

    } catch (e, st) {
      reportApiFailureToCrashlytics(
        'RegisterScreen',
        error: e,
        stackTrace: st,
        reason: 'register_exception',
      );
      print("Erreur inscription: $e");
      SnackbarForCasa.error(
        context,
        "L’inscription n’a pas abouti. Vérifiez les informations et réessayez.",
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
}