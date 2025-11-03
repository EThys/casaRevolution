import 'package:casa/controllers/AuthentificationCtrl.dart';
import 'package:casa/controllers/RegisterBailleurCtrl.dart';
import 'package:casa/utils/Endpoints.dart';
import 'package:casa/utils/FancyNotification.dart';
import 'package:casa/utils/Routes.dart';
import 'package:casa/utils/networkCheck.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../controllers/RegisterCommissionnaireCtrl.dart';
import '../../controllers/RegisterLocataireCtrl.dart';
import '../../utils/requetes.dart';
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
  AutovalidateMode _autoValidateMode = AutovalidateMode.disabled;

  // Suivi de la force du mot de passe en temps réel
  int _passwordStrength = 0;

  // Couleurs cohérentes avec le login
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
      'color': Color(0xFF4CAF50),
    },
    'Bailleur': {
      'value': 3,
      'icon': Icons.house_siding_rounded,
      'description': 'Je propose un logement en location',
      'color': Color(0xFF2196F3),
    },
    'Commissionnaire': {
      'value': 2,
      'icon': Icons.handshake_rounded,
      'description': 'Je facilite les transactions immobilières',
      'color': Color(0xFFFF9800),
    },
  };

  @override
  void initState() {
    super.initState();

    _passwordController.addListener(_updatePasswordStrength);
    _setupFocusNavigation();

    // Ajouter des listeners pour tous les contrôleurs
    _firstNameController.addListener(_updateButtonState);
    _lastNameController.addListener(_updateButtonState);
    _phoneController.addListener(_updateButtonState);
    _cityController.addListener(_updateButtonState);
    _passwordController.addListener(_updateButtonState);
  }

// Nouvelle méthode pour mettre à jour l'état du bouton
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
  void _setupFocusNavigation() {
    _firstNameFocus.addListener(() {});
    _lastNameFocus.addListener(() {});
    _phoneFocus.addListener(() {});
    _emailFocus.addListener(() {});
    _cityFocus.addListener(() {});
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
              padding: EdgeInsets.all(24),
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
                  Icon(Icons.home_rounded, size: 40, color: Colors.white),
                  Positioned(
                    top: 4,
                    left: 4,
                    child: Icon(Icons.home_rounded, size: 40, color: Colors.white.withOpacity(0.3)),
                  ),
                ],
              ),
            ),
            // Badge premium
            Positioned(
              top: -2,
              right: -2,
              child: Container(
                padding: EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.amber,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Icon(Icons.star, size: 12, color: Colors.white),
              ),
            ),
          ],
        ).animate()
            .scale(delay: 500.ms, duration: 800.ms, curve: Curves.elasticOut)
            .shake(delay: 1500.ms, duration: 1000.ms),

        SizedBox(width: 16),

        // Texte avec séparateur
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
                  'Casa',
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
        borderRadius: BorderRadius.circular(20),
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
          _buildAuthButton(),
          SizedBox(height: 20),
          _buildLoginLink(),
          SizedBox(height: 25),
          _buildPrivacyText(),
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
          ),
          SizedBox(height: 15),
          _buildNameField(
            controller: _lastNameController,
            label: 'Nom',
            hint: 'Baka',
            focusNode: _lastNameFocus,
            nextFocus: _phoneFocus,
          ),
          SizedBox(height: 15),
          // Téléphone
          _buildPhoneField(),
          SizedBox(height: 15),
          // Email
          _buildEmailField(),
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
        autovalidateMode: AutovalidateMode.onUserInteraction,
        style: TextStyle(color: textColor, fontSize: 16),
        textInputAction: nextFocus != null ? TextInputAction.next : TextInputAction.done,
        onFieldSubmitted: nextFocus != null ? (_) => _goToNextField(focusNode, nextFocus!) : null,
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
        ),
        validator: (value) => _validateName(value, label.toLowerCase()),
        onChanged: (_) => _forceRevalidation(),
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
        autovalidateMode: AutovalidateMode.onUserInteraction,
        style: TextStyle(color: textColor, fontSize: 16),
        keyboardType: TextInputType.phone,
        textInputAction: TextInputAction.next,
        onFieldSubmitted: (_) => _goToNextField(_phoneFocus, _emailFocus),
        decoration: InputDecoration(
          labelText: 'Téléphone*',
          labelStyle: TextStyle(color: secondaryTextColor),
          prefixIcon: Container(
            padding: EdgeInsets.all(12),
            child: Icon(Icons.phone_iphone_rounded, color: primaryColor),
          ),
          suffixIcon: _buildNextButton(() => _goToNextField(_phoneFocus, _emailFocus)),
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
          hintText: '+243 81 000 0000',
          hintStyle: TextStyle(color: Colors.grey.shade500),
        ),
        validator: _validatePhone,
        onChanged: (_) => _forceRevalidation(),
      ),
    ).animate().slideX(
      begin: 0.3,
      duration: 500.ms,
      delay: 1400.ms,
      curve: Curves.easeOut,
    );
  }

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
        autovalidateMode: AutovalidateMode.onUserInteraction,
        style: TextStyle(color: textColor, fontSize: 16),
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.next,
        onFieldSubmitted: (_) => _goToNextField(_emailFocus, _cityFocus),
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
        ),
        validator: _validateEmail,
        onChanged: (_) => _forceRevalidation(),
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
      child: TextFormField(
        controller: _cityController,
        focusNode: _cityFocus,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        style: TextStyle(color: textColor, fontSize: 16),
        textInputAction: TextInputAction.next,
        onFieldSubmitted: (_) => _cityFocus.unfocus(),
        decoration: InputDecoration(
          labelText: 'Ville*',
          labelStyle: TextStyle(color: secondaryTextColor),
          prefixIcon: Container(
            padding: EdgeInsets.all(12),
            child: Icon(Icons.location_city_rounded, color: primaryColor),
          ),
          suffixIcon: _buildNextButton(() => _cityFocus.unfocus()),
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
          hintText: 'Kinshasa',
          hintStyle: TextStyle(color: Colors.grey.shade500),
        ),
        validator: _validateCity,
        onChanged: (_) => _forceRevalidation(),
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
        SizedBox(height: 8),
        ..._accountTypes.entries.map((entry) =>
            _buildAccountTypeOption(entry.key, entry.value)
        ),
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
        autovalidateMode: AutovalidateMode.onUserInteraction,
        textInputAction: TextInputAction.done,
        onFieldSubmitted: (_) => _passwordFocus.unfocus(),
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
                _buildDoneButton(),
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
        ),
        validator: _validatePassword,
      ),
    ).animate().slideX(
      begin: 0.3,
      duration: 500.ms,
      delay: 1700.ms,
      curve: Curves.easeOut,
    );
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

  Widget _buildDoneButton() {
    return Container(
      margin: EdgeInsets.only(left: 4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: primaryColor.withOpacity(0.1),
      ),
      child: IconButton(
        icon: Icon(Icons.done_rounded, size: 18, color: primaryColor),
        onPressed: () => _passwordFocus.unfocus(),
        padding: EdgeInsets.zero,
        constraints: BoxConstraints(minWidth: 36, minHeight: 36),
      ),
    );
  }

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
  Widget _buildAuthButton() {
    // Vérifier si tous les champs obligatoires sont remplis et valides
    final hasRequiredFields = _firstNameController.text.isNotEmpty &&
        _lastNameController.text.isNotEmpty &&
        _phoneController.text.isNotEmpty &&
        _cityController.text.isNotEmpty &&
        _passwordController.text.isNotEmpty &&
        _selectedAccountType != null;

    // Vérifier si le formulaire est valide (sans erreurs de validation)
    final isFormValid = _formKey.currentState?.validate() ?? false;

    // Le bouton est activé seulement si tous les champs sont remplis,
    // le formulaire est valide ET les conditions sont acceptées
    final isButtonEnabled = hasRequiredFields && isFormValid && _acceptConditions && !_isLoading;

    print("🔍 État du bouton - "
        "Champs remplis: $hasRequiredFields, "
        "Formulaire valide: $isFormValid, "
        "Conditions: $_acceptConditions, "
        "Loading: $_isLoading, "
        "Bouton activé: $isButtonEnabled");

    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: isButtonEnabled
            ? LinearGradient(
          colors: [primaryColor, darkBlue],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        )
            : LinearGradient(
          colors: [Colors.grey.shade400, Colors.grey.shade600],
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
            : null,
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
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(width: 10),
            Icon(Icons.person_add_rounded, size: 20, color: Colors.white),
          ],
        ),
      ),
    ).animate().scale(
      delay: 1900.ms,
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
    ).animate().fadeIn(delay: 2000.ms);
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
                            text: ' de Casa',
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
        // ... le reste du code reste inchangé ...
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
    String cleanedPhone = value.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleanedPhone.length < 9) {
      return 'Le numéro doit contenir au moins 9 chiffres';
    }
    if (!RegExp(r'^(\+243|243|0)[1-9]\d{8}$').hasMatch(cleanedPhone)) {
      return 'Format invalide. Ex: +243810000000';
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
    if (value.length < 2) {
      return 'La ville doit contenir au moins 2 caractères';
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
    if (_formKey.currentState != null) {
      _formKey.currentState!.validate();
    }
  }

  Future<void> _handleRegister() async {

    setState(() {
      _autoValidateMode = AutovalidateMode.always;
    });

    await Future.delayed(Duration(milliseconds: 50));

    if (!(_formKey.currentState?.validate() ?? false)) {
      FancyNotification.show(context, "Veuillez corriger les erreurs ci-dessus");
      return;
    }

    if (_selectedAccountType == null) {
      _showSnackbar("Veuillez sélectionner un type de compte", isError: true);
      return;
    }


    if (!_acceptConditions) {
      _showSnackbar("Veuillez accepter les conditions d'utilisation", isError: true);
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
      final accountType = _accountTypes[_selectedAccountType]!;

      // Structure de base pour l'utilisateur
      final userData = {
        "phone": _phoneController.text,
        "password": _passwordController.text,
        "typeAccountId": accountType['value'],
        "email": _emailController.text.isNotEmpty ? _emailController.text : "",
        "cityId": 1, // À adapter selon votre système de villes
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
        default:
          final ctrl = context.read<AuthentificationCtrl>();
          response = await ctrl.register(payload, url: Endpoints.register);
      }

      if (!mounted) return;

      if (response.status == true) {
        FancyNotification.show(context, "Inscription réussie!", isError: false);
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
        FancyNotification.show(context, errorMessage);
      }
    } catch (e) {
      FancyNotification.show(context, "Erreur technique lors de l'inscription");
      print("Register error: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showValidationError() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Expanded(child: Text('Veuillez corriger les erreurs ci-dessus')),
          ],
        ),
        backgroundColor: errorColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showSnackbar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? errorColor : successColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}